package com.sens.lush;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URLEncoder;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.Base64;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.SQLStateSQLExceptionTranslator;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 공지사항(게시판) 등록 · 수정 · 삭제 · 첨부파일 받기 — GROUP_NEWS
 *  - 화면은 기존 s_news.jsp (목록은 loginController /s_news.do 그대로)
 *  - /s_news/save     등록 · 수정 (JSON, 첨부파일은 base64 로 같이 받음)
 *  - /s_news/delete   삭제 (JSON) — 첨부파일도 지움
 *  - /s_news/file     첨부파일 받기
 *  - /s_news/mine     우리 매장 공지 키 목록 (화면에서 수정 · 삭제 버튼 표시용)
 *
 *  등록 : NEWS_KEY = SHOPNO + yyMMddHHmmss, NEWS_DATE = 오늘 yyyyMMdd, NEWS_TIME = HHmm,
 *         SHOPNO · SHOPNAME = 로그인 매장, KIND = '', FILENAME = 첨부파일 이름
 *  수정 · 삭제는 우리 매장이 등록한 공지만
 *  첨부파일은 UPLOAD_DIR 에 "NEWS_KEY_파일이름" 으로 저장
 */
@Controller
public class s_news_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    /** 첨부파일 저장 폴더 (톰캣 서버) — 서버에 맞게 바꾸세요 */
    private static final String UPLOAD_DIR = "C:/sens_upload/news";
    /** 첨부파일 최대 크기 */
    private static final long MAX_FILE = 10L * 1024 * 1024;   // 10MB

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public s_news_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 등록 · 수정 (news_key 가 비어 있으면 등록)
    //   body : { news_key, title, content, end_date(yyyy-MM-dd 또는 yyyyMMdd),
    //            file_name, file_data(base64), remove_file(true/false) }
    // ------------------------------------------------------------------
    @RequestMapping(value = "/s_news/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            String shop    = shopNo(session);
            String key     = str(body.get("news_key"));
            String title   = str(body.get("title"));
            String content = body.get("content") == null ? "" : body.get("content").toString();
            String endDate = str(body.get("end_date")).replace("-", "");
            String fName   = safeName(str(body.get("file_name")));
            String fData   = str(body.get("file_data"));
            boolean removeFile = "true".equalsIgnoreCase(str(body.get("remove_file")));

            if (title.isEmpty()) throw new IllegalArgumentException("제목을 입력하세요.");
            if (!endDate.matches("\\d{8}")) throw new IllegalArgumentException("게시 종료일을 입력하세요.");
            String today = new SimpleDateFormat("yyyyMMdd").format(new Date());
            boolean isNew = key.isEmpty();
            if (isNew && endDate.compareTo(today) < 0) throw new IllegalArgumentException("게시 종료일이 오늘보다 앞입니다.");

            byte[] bytes = null;
            if (!fData.isEmpty()) {
                if (fName.isEmpty()) throw new IllegalArgumentException("첨부파일 이름이 없습니다.");
                bytes = Base64.getDecoder().decode(fData);
                if (bytes.length > MAX_FILE) throw new IllegalArgumentException("첨부파일은 10MB 까지 올릴 수 있습니다.");
            }

            if (isNew) {
                Date now = new Date();
                key = shop + new SimpleDateFormat("yyMMddHHmmss").format(now);
                Integer dup = jdbc.queryForObject("SELECT COUNT(*) FROM group_news WHERE news_key = :key",
                    new MapSqlParameterSource("key", key), Integer.class);
                if (dup != null && dup > 0) throw new IllegalStateException("잠시 후 다시 등록하세요. (같은 시각 등록)");

                if (bytes != null) writeFile(key, fName, bytes);
                MapSqlParameterSource p = new MapSqlParameterSource()
                    .addValue("key", key)
                    .addValue("shop", shop)
                    .addValue("shopname", shopName(session))
                    .addValue("ndate", today)
                    .addValue("ntime", new SimpleDateFormat("HHmm").format(now))
                    .addValue("title", title)
                    .addValue("content", content)
                    .addValue("edate", endDate)
                    .addValue("fname", bytes != null ? fName : "");
                jdbc.update(
                    "INSERT INTO group_news (news_key, shopno, shopname, news_date, news_time, title, content, end_date, kind, filename)" +
                    " VALUES (:key, :shop, :shopname, :ndate, :ntime, :title, :content, :edate, '', :fname)", p);
            } else {
                Map<String, Object> old = mine(key, shop);
                String oldFile = str(old.get("filename"));
                String newFile = oldFile;
                if (bytes != null) {                       // 새 파일로 바꿈
                    writeFile(key, fName, bytes);
                    if (!oldFile.isEmpty() && !oldFile.equals(fName)) deleteFile(key, oldFile);
                    newFile = fName;
                } else if (removeFile && !oldFile.isEmpty()) {   // 첨부 삭제
                    deleteFile(key, oldFile);
                    newFile = "";
                }
                jdbc.update(
                    "UPDATE group_news SET title = :title, content = :content, end_date = :edate, filename = :fname" +
                    " WHERE news_key = :key AND shopno = :shop",
                    new MapSqlParameterSource()
                        .addValue("title", title).addValue("content", content).addValue("edate", endDate)
                        .addValue("fname", newFile).addValue("key", key).addValue("shop", shop));
            }
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("news_key", key);
            r.put("isNew", isNew);
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 우리 매장이 등록한 공지 키 목록 — 목록 조회(mapper)에 NEWS_KEY 가 없어도
    // 화면에서 등록일 + 제목 + 종료일로 짝을 맞춰 수정 · 삭제 · 첨부 표시
    // ------------------------------------------------------------------
    @RequestMapping(value = "/s_news/mine", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> mine(HttpSession session) {
        try {
            List<Map<String, Object>> l = jdbc.queryForList(
                "SELECT news_key, news_date, news_time, title, content, end_date, filename FROM group_news" +
                " WHERE shopno = :shop ORDER BY news_date DESC, news_time DESC",
                new MapSqlParameterSource("shop", shopNo(session)));
            List<Map<String, Object>> out = new java.util.ArrayList<Map<String, Object>>();
            for (Map<String, Object> m : l) {
                Map<String, Object> r = new LinkedHashMap<String, Object>();
                for (Map.Entry<String, Object> e : m.entrySet()) r.put(e.getKey().toLowerCase(), str(e.getValue()));
                // 날짜 컬럼이 date 타입이면 "2026-10-29" 로 오므로 yyyyMMdd 로 맞춤
                for (String k : new String[] { "news_date", "end_date" }) {
                    String v = str(r.get(k)).replaceAll("\\D", "");
                    r.put(k, v.length() > 8 ? v.substring(0, 8) : v);
                }
                out.add(r);
            }
            return ok(out);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 삭제
    // ------------------------------------------------------------------
    @RequestMapping(value = "/s_news/delete", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> delete(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            String shop = shopNo(session);
            String key  = str(body.get("news_key"));
            if (key.isEmpty()) throw new IllegalArgumentException("삭제할 공지를 선택하세요.");
            Map<String, Object> old = mine(key, shop);
            jdbc.update("DELETE FROM group_news WHERE news_key = :key AND shopno = :shop",
                new MapSqlParameterSource().addValue("key", key).addValue("shop", shop));
            String f = str(old.get("filename"));
            if (!f.isEmpty()) deleteFile(key, f);
            return ok(1);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 첨부파일 받기
    // ------------------------------------------------------------------
    @RequestMapping(value = "/s_news/file", method = RequestMethod.GET)
    public void file(@RequestParam("key") String key, HttpSession session, HttpServletResponse res) throws Exception {
        shopNo(session);   // 로그인 확인
        List<Map<String, Object>> l = jdbc.queryForList("SELECT filename FROM group_news WHERE news_key = :key",
            new MapSqlParameterSource("key", key.trim()));
        String name = l.isEmpty() ? "" : str(l.get(0).get("filename"));
        File f = name.isEmpty() ? null : new File(UPLOAD_DIR, key.trim() + "_" + name);
        if (f == null || !f.isFile()) {
            res.setContentType("text/html; charset=UTF-8");
            res.getWriter().print("<script>alert('첨부파일을 찾을 수 없습니다.');history.back();</script>");
            return;
        }
        String enc = URLEncoder.encode(name, "UTF-8").replace("+", "%20");
        res.setContentType("application/octet-stream");
        res.setHeader("Content-Disposition", "attachment; filename=\"" + enc + "\"; filename*=UTF-8''" + enc);
        res.setContentLength((int) f.length());
        InputStream in = new FileInputStream(f);
        try {
            OutputStream out = res.getOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            out.flush();
        } finally {
            in.close();
        }
    }

    // ------------------------------------------------------------------
    // 공통
    // ------------------------------------------------------------------
    /** 우리 매장이 등록한 공지인지 확인 */
    private Map<String, Object> mine(String key, String shop) {
        List<Map<String, Object>> l = jdbc.queryForList(
            "SELECT news_key, shopno, filename FROM group_news WHERE news_key = :key",
            new MapSqlParameterSource("key", key));
        if (l.isEmpty()) throw new IllegalArgumentException("공지를 찾을 수 없습니다. 다시 조회하세요.");
        Map<String, Object> m = l.get(0);
        // queryForList 키 대소문자가 드라이버마다 달라서 소문자로 맞춤
        Map<String, Object> r = new LinkedHashMap<String, Object>();
        for (Map.Entry<String, Object> e : m.entrySet()) r.put(e.getKey().toLowerCase(), e.getValue());
        if (!shop.equals(str(r.get("shopno")))) throw new IllegalArgumentException("다른 매장에서 등록한 공지는 고칠 수 없습니다.");
        return r;
    }

    private void writeFile(String key, String name, byte[] bytes) throws Exception {
        File dir = new File(UPLOAD_DIR);
        if (!dir.isDirectory() && !dir.mkdirs()) throw new IllegalStateException("첨부파일 폴더를 만들 수 없습니다 : " + UPLOAD_DIR);
        OutputStream out = new FileOutputStream(new File(dir, key + "_" + name));
        try { out.write(bytes); } finally { out.close(); }
    }

    private void deleteFile(String key, String name) {
        File f = new File(UPLOAD_DIR, key + "_" + name);
        if (f.isFile() && !f.delete()) logger.warn("첨부파일 삭제 실패 : " + f);
    }

    /** 경로 문자 제거 (폴더 밖으로 못 나가게) */
    private static String safeName(String s) {
        s = s.replace("\\", "/");
        s = s.substring(s.lastIndexOf('/') + 1);
        s = s.replaceAll("[:*?\"<>|\\x00-\\x1f]", "_").trim();
        if (s.equals(".") || s.equals("..")) s = "";
        return s.length() > 100 ? s.substring(s.length() - 100) : s;
    }

    @SuppressWarnings("rawtypes")
    private Map user(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map) u;
    }

    private String shopNo(HttpSession session) {
        Object v = user(session).get("SHOPNO");
        if (v == null || v.toString().trim().isEmpty()) throw new IllegalStateException("로그인 정보(매장코드)가 없습니다.");
        return v.toString().trim();
    }

    private String shopName(HttpSession session) {
        Object v = user(session).get("SHOPNAME");
        return v == null ? "" : v.toString().trim();
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("s_news error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String str(Object o) { return o == null ? "" : o.toString().trim(); }
}
