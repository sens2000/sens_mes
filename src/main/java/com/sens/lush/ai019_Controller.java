package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
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
 * 계정 관리 (ai019)
 *  - 화면 : /ai019.do → ai019.jsp
 *  - 데이터 : /ai019/list (계정 목록), /ai019/save (등록·수정), /ai019/delete (삭제)
 *  - 테이블 : acct_tb
 *        acctnm(계정명), acctgu(구분 : 입금/출금), sys('N'), chk(Y/N), shopno(매장), acctgroup('' — 등록 시 빈 값)
 *  - 목록 : shopno IN (로그인 매장, 시스템 '000000')
 *  - 시스템 계정은 조회만 (수정·삭제 불가) — 매장 계정만 수정·삭제
 *  - 키 : shopno + acctnm (같은 매장 안에서 계정명 중복 불가, 시스템 계정명과도 중복 불가)
 */
@Controller
public class ai019_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 / 사용자ID 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";
    private static final String USER_ID_FIELD   = "USERID";

    /** 시스템 계정 매장코드 */
    private static final String SYS_SHOP = "000000";

    private static boolean isSysShop(String shop) { return SYS_SHOP.equals(shop); }

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ai019_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai019.do")
    public String ai019(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai019");
        return "ai019";
    }

    // ------------------------------------------------------------------
    // 계정 목록 : 시스템 계정 + 로그인 매장 계정
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai019/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "gu", defaultValue = "") String gu,
                                    @RequestParam(value = "keyword", defaultValue = "") String keyword,
                                    HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(
                "SELECT acctnm, acctgu, sys, chk, shopno FROM acct_tb WHERE shopno IN (:shop, :sys)");
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("shop", shopNo(session)).addValue("sys", SYS_SHOP);
            if ("입금".equals(gu) || "출금".equals(gu)) { sql.append(" AND acctgu = :gu"); p.addValue("gu", gu); }
            if (!isEmpty(keyword)) { sql.append(" AND acctnm LIKE :kw"); p.addValue("kw", "%" + keyword.trim() + "%"); }
            // 시스템 계정 먼저, 구분(입금 → 출금), 계정명 순
            sql.append(" ORDER BY CASE WHEN shopno = :sys THEN 0 ELSE 1 END, acctgu, acctnm");
            return ok(jdbc.query(sql.toString(), p, ACCT_MAPPER));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static final RowMapper<Map<String, Object>> ACCT_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            String shop = trim(rs.getString("shopno"));
            m.put("acctnm", trim(rs.getString("acctnm")));
            m.put("acctgu", trim(rs.getString("acctgu")));
            m.put("sys",    isSysShop(shop));          // 시스템 계정 → 수정·삭제 불가
            String chk = trim(rs.getString("chk"));
            m.put("chk",    isEmpty(chk) ? "Y" : chk);
            m.put("shopno", shop);
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 등록·수정 : orgName 이 비어 있으면 신규
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai019/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String shop    = shopNo(session);
            String orgName = str(req.get("orgName"));
            String name    = cut(str(req.get("acctnm")), 30);
            String gu      = str(req.get("acctgu"));
            if (isSysShop(shop)) throw new IllegalArgumentException("시스템 매장에서는 이 화면으로 계정을 바꿀 수 없습니다.");
            if (isEmpty(name)) throw new IllegalArgumentException("계정명을 입력하세요.");
            if (!"입금".equals(gu) && !"출금".equals(gu)) throw new IllegalArgumentException("구분(입금/출금)을 선택하세요.");
            boolean isNew = isEmpty(orgName);

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shop).addValue("sys", SYS_SHOP)
                .addValue("name", name).addValue("gu", gu).addValue("org", orgName);

            // 계정명 중복 : 우리 매장(본인 제외) + 시스템 계정
            Integer dup = jdbc.queryForObject(
                "SELECT COUNT(*) FROM acct_tb WHERE acctnm = :name" +
                "   AND (shopno = :sys OR (shopno = :shop AND acctnm <> :org))", p, Integer.class);
            if (dup != null && dup > 0) throw new IllegalArgumentException("이미 있는 계정명입니다. (" + name + ")");

            if (isNew) {
                jdbc.update("INSERT INTO acct_tb (acctnm, acctgu, sys, chk, shopno, acctgroup) VALUES (:name, :gu, 'N', 'Y', :shop, '')", p);
                logger.info("ai019 new: " + shop + " " + name + " " + gu + " (by " + userId(session) + ")");
            } else {
                // shopno = 로그인 매장 조건 → 시스템 계정(000000)은 수정되지 않음
                int cnt = jdbc.update("UPDATE acct_tb SET acctnm = :name, acctgu = :gu WHERE shopno = :shop AND acctnm = :org", p);
                if (cnt == 0) throw new IllegalArgumentException("수정할 수 없는 계정입니다. (시스템 계정이거나 이미 삭제됨)");
                logger.info("ai019 update: " + shop + " " + orgName + " -> " + name + " " + gu + " (by " + userId(session) + ")");
            }
            return ok(jdbc.query("SELECT acctnm, acctgu, sys, chk, shopno FROM acct_tb WHERE shopno = :shop AND acctnm = :name",
                p, ACCT_MAPPER).get(0));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 삭제 : 로그인 매장 계정만 (시스템 계정 불가)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai019/delete", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> delete(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String shop = shopNo(session);
            String name = str(req.get("acctnm"));
            if (isSysShop(shop)) throw new IllegalArgumentException("시스템 계정은 삭제할 수 없습니다.");
            int cnt = jdbc.update("DELETE FROM acct_tb WHERE shopno = :shop AND acctnm = :name",
                new MapSqlParameterSource().addValue("shop", shop).addValue("name", name));
            if (cnt == 0) throw new IllegalArgumentException("삭제할 수 없는 계정입니다. (시스템 계정이거나 이미 삭제됨)");
            logger.info("ai019 delete: " + shop + " " + name + " (by " + userId(session) + ")");
            return ok(null);
        } catch (Exception e) {
            return fail(e);
        }
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
        logger.error("ai019 error", e);
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
