package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.SQLStateSQLExceptionTranslator;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 직원 관리 (ai002)
 *  - 화면 : /ai002.do → ai002.jsp
 *  - 데이터 : /ai002/shops (매장 목록), /ai002/list (직원 목록), /ai002/save (등록·수정)
 *  - 테이블 : user_info
 *        buseo('0001'), code(MAX + 1, 4자리), name(성명), remk(비고), prdate(등록일), moddate(수정일),
 *        handno(전화), position('메니저'/'직원', 기본 직원), grade(기본 5), userid, userpass,
 *        shopno·shopname(user_mst 에서), chk('Y' 사용 / 'N' 미사용)
 *  - 삭제는 하지 않음 → chk = 'N' 으로 미사용 처리
 *  - 로그인 매장(세션 USER.SHOPNO) 직원만 조회·등록·수정
 */
@Controller
public class ai002_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 / 사용자ID 키 이름 — ai101 과 동일 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";
    private static final String USER_ID_FIELD   = "USERID";

    private static final String BUSEO = "0001";
    private static final String TODAY = "DATEFORMAT(GETDATE(), 'YYYYMMDD')";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ai002_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai002.do")
    public String ai002(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai002");
        return "ai002";
    }

    // ------------------------------------------------------------------
    // 로그인 매장 (user_mst)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai002/shops", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> shops(HttpSession session) {
        try {
            List<Map<String, Object>> list = jdbc.query(
                "SELECT DISTINCT shopno, shopname FROM user_mst WHERE shopno = :shop",
                new MapSqlParameterSource("shop", shopNo(session)),
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("shopno",   trim(rs.getString("shopno")));
                        m.put("shopname", trim(rs.getString("shopname")));
                        return m;
                    }
                });
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("myShop", shopNo(session));
            r.put("shops", list);
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 직원 목록 : 로그인 매장 직원만, 성명·아이디·전화 검색, 사용중만
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai002/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "keyword", defaultValue = "") String keyword,
                                    @RequestParam(value = "useOnly", defaultValue = "N") String useOnly,
                                    HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(SELECT_USER).append(" WHERE shopno = :shop");
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            if (!isEmpty(keyword)) {
                sql.append(" AND (name LIKE :kw OR userid LIKE :kw OR REPLACE(handno, '-', '') LIKE :kw)");
                p.addValue("kw", "%" + keyword.replace("-", "").trim() + "%");
            }
            if ("Y".equals(useOnly)) sql.append(" AND ISNULL(chk, 'Y') = 'Y'");
            sql.append(" ORDER BY shopno, code");
            return ok(jdbc.query(sql.toString(), p, USER_MAPPER));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 암호(userpass)는 화면으로 보내지 않음 */
    private static final String SELECT_USER =
        "SELECT buseo, code, name, remk, prdate, moddate, handno, position, grade, userid, shopno, shopname, chk FROM user_info";

    private static final RowMapper<Map<String, Object>> USER_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("buseo",    trim(rs.getString("buseo")));
            m.put("code",     trim(rs.getString("code")));
            m.put("name",     trim(rs.getString("name")));
            m.put("remk",     trim(rs.getString("remk")));
            m.put("prdate",   dateFmt(trim(rs.getString("prdate"))));
            m.put("moddate",  dateFmt(trim(rs.getString("moddate"))));
            m.put("handno",   trim(rs.getString("handno")));
            m.put("position", trim(rs.getString("position")));
            m.put("grade",    trim(rs.getString("grade")));
            m.put("userid",   trim(rs.getString("userid")));
            m.put("shopno",   trim(rs.getString("shopno")));
            m.put("shopname", trim(rs.getString("shopname")));
            String chk = trim(rs.getString("chk"));
            m.put("chk",      isEmpty(chk) ? "Y" : chk);
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 등록·수정 : code 가 비어 있으면 신규 (code = MAX + 1, 4자리)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai002/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String myShop   = shopNo(session);
            String code     = str(req.get("code"));
            String buseo    = isEmpty(str(req.get("buseo"))) ? BUSEO : str(req.get("buseo"));
            String userid   = cut(str(req.get("userid")), 20);
            String pass     = cut(str(req.get("pass")), 20);
            String shopno   = myShop;                          // 로그인 매장으로 고정
            String name     = cut(str(req.get("name")), 20);
            String position = "메니저".equals(str(req.get("position"))) ? "메니저" : "직원";
            String chk      = "N".equals(str(req.get("chk"))) ? "N" : "Y";
            int grade;
            try { grade = Integer.parseInt(str(req.get("grade"))); } catch (NumberFormatException e) { grade = 5; }
            boolean isNew = isEmpty(code);

            // 아이디는 선택 입력 (로그인 안 하는 직원은 비워 둠) / 아이디를 넣고 신규 등록할 때만 암호 필수
            if (isNew && !isEmpty(userid) && isEmpty(pass)) throw new IllegalArgumentException("아이디를 넣으면 암호도 입력하세요.");
            if (isEmpty(shopno)) throw new IllegalArgumentException("매장을 선택하세요.");
            if (isEmpty(name)) throw new IllegalArgumentException("성명을 입력하세요.");

            // 매장명은 user_mst 에서
            List<String> shopname = jdbc.query("SELECT TOP 1 shopname FROM user_mst WHERE shopno = :shop",
                new MapSqlParameterSource("shop", shopno),
                new RowMapper<String>() {
                    public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString("shopname")); }
                });
            if (shopname.isEmpty()) throw new IllegalArgumentException("등록되지 않은 매장입니다. (" + shopno + ")");

            // 아이디 중복 확인 (본인 제외, 아이디를 입력했을 때만)
            if (!isEmpty(userid)) {
                Integer dup = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM user_info WHERE userid = :id AND NOT (buseo = :buseo AND code = :code)",
                    new MapSqlParameterSource().addValue("id", userid).addValue("buseo", buseo).addValue("code", code), Integer.class);
                if (dup != null && dup > 0) throw new IllegalArgumentException("이미 사용 중인 아이디입니다. (" + userid + ")");
            }

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("buseo", buseo)
                .addValue("name", name)
                .addValue("remk", cut(str(req.get("remk")), 100))
                .addValue("handno", cut(str(req.get("handno")), 20))
                .addValue("position", position)
                .addValue("grade", grade)
                .addValue("userid", userid)
                .addValue("pass", pass)
                .addValue("shopno", shopno)
                .addValue("shopname", cut(shopname.get(0), 40))
                .addValue("chk", chk);

            if (isNew) {
                code = nextCode();
                p.addValue("code", code);
                jdbc.update(
                    "INSERT INTO user_info (buseo, code, name, remk, prdate, moddate, handno, position, grade," +
                    "                       userid, userpass, shopno, shopname, chk) " +
                    "VALUES (:buseo, :code, :name, :remk, " + TODAY + ", " + TODAY + ", :handno, :position, :grade," +
                    "        :userid, :pass, :shopno, :shopname, :chk)", p);
                logger.info("ai002 new: " + code + " " + userid + " " + name + " (by " + userId(session) + ")");
            } else {
                p.addValue("code", code);
                int cnt = jdbc.update(
                    "UPDATE user_info SET name = :name, remk = :remk, moddate = " + TODAY + ", handno = :handno," +
                    "       position = :position, grade = :grade, userid = :userid," +
                    (isEmpty(pass) ? "" : " userpass = :pass,") +          // 암호는 입력했을 때만 변경
                    "       shopno = :shopno, shopname = :shopname, chk = :chk" +
                    " WHERE buseo = :buseo AND code = :code AND shopno = :shopno", p);   // 다른 매장 직원은 수정 불가
                if (cnt == 0) throw new IllegalArgumentException("우리 매장 직원이 아니거나 찾을 수 없습니다. (" + code + ")");
                logger.info("ai002 update: " + code + " " + userid + " " + name + (isEmpty(pass) ? "" : " (암호 변경)") + " (by " + userId(session) + ")");
            }

            return ok(jdbc.query(SELECT_USER + " WHERE buseo = :buseo AND code = :code",
                new MapSqlParameterSource().addValue("buseo", buseo).addValue("code", code), USER_MAPPER).get(0));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** code = 숫자 코드 중 가장 큰 값 + 1 (4자리, 0 채움) */
    private String nextCode() {
        List<String> codes = jdbc.query("SELECT code FROM user_info", new MapSqlParameterSource(),
            new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString("code")); }
            });
        int max = 0;
        for (String c : codes) {
            if (c.matches("\\d{1,4}")) max = Math.max(max, Integer.parseInt(c));
        }
        if (max >= 9999) throw new IllegalStateException("직원코드(4자리)가 모두 사용되었습니다.");
        return String.format("%04d", max + 1);
    }

    // ------------------------------------------------------------------
    // 세션
    // ------------------------------------------------------------------
    @SuppressWarnings("rawtypes")
    private Map userMap(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map) u;
    }

    private String shopNo(HttpSession session) {
        Object v = userMap(session).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private String userId(HttpSession session) {
        Object v = userMap(session).get(USER_ID_FIELD);
        return v == null ? "" : v.toString().trim();
    }

    // ------------------------------------------------------------------
    // 응답 / 변환
    // ------------------------------------------------------------------
    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ai002 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static String str(Object o)       { return o == null ? "" : o.toString().trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.trim().isEmpty(); }
    private static String dateFmt(String d)   { return d.length() >= 8 && d.substring(0, 8).matches("\\d{8}") ? d.substring(0, 4) + "-" + d.substring(4, 6) + "-" + d.substring(6, 8) : d; }

    /** DB(CP949) 기준 바이트 수로 자르기 — 한글 2바이트 */
    private static String cut(String s, int maxBytes) {
        int n = 0;
        for (int i = 0; i < s.length(); i++) {
            n += s.charAt(i) > 127 ? 2 : 1;
            if (n > maxBytes) return s.substring(0, i);
        }
        return s;
    }
}
