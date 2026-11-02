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
 * 거래처 관리 (ai016)
 *  - 화면 : /ai016.do → ai016.jsp
 *  - 데이터 : /ai016/list (거래처 목록), /ai016/save (등록·수정)
 *  - 테이블 : CUST_MST — 로그인 매장(세션 USER.SHOPNO) 거래처만
 *        CUSTKEY(SHOPNO + CUSTCD), CUSTCD(700000~900000 중 MAX + 1), CUSTNAME, TELNO, MANNM(담당자),
 *        CUSTNMHP(핸드폰), SAADDR(비고로 사용), MIBULAMT(미불금 — 입고/지급으로만 바뀜), ENDCHK(Y 정상 / N 거래종료),
 *        JIKPAN('N'), SOPOST('WEB' = 웹 등록)
 *  - 등록 규칙은 ai201 거래처 등록과 같음
 *  - 수정 : SOPOST = 'WEB' 인 거래처만 (POS 거래처는 조회만) — ai201 과 같은 규칙
 */
@Controller
public class ai016_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 / 사용자ID 키 이름 — ai101 과 동일 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";
    private static final String USER_ID_FIELD   = "USERID";

    /** 매입 거래처 코드 범위 (ai201 과 동일) */
    private static final String CUST_FROM = "700000";
    private static final String CUST_TO   = "900000";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ai016_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai016.do")
    public String ai016(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai016");
        return "ai016";
    }

    // ------------------------------------------------------------------
    // 거래처 목록 : 로그인 매장만, 거래처명·전화·담당자·핸드폰 검색, 정상 거래처만(선택)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai016/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "keyword", defaultValue = "") String keyword,
                                    @RequestParam(value = "useOnly", defaultValue = "N") String useOnly,
                                    HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(SELECT_CUST).append(" WHERE SHOPNO = :shop");
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            if (!isEmpty(keyword)) {
                sql.append(" AND (CUSTNAME LIKE :kw OR MANNM LIKE :kw OR CUSTCD = :cd" +
                           "      OR REPLACE(TELNO, '-', '') LIKE :tel OR REPLACE(CUSTNMHP, '-', '') LIKE :tel)");
                p.addValue("kw", "%" + keyword.trim() + "%")
                 .addValue("cd", keyword.trim())
                 .addValue("tel", "%" + keyword.replace("-", "").trim() + "%");
            }
            if ("Y".equals(useOnly)) sql.append(" AND ISNULL(ENDCHK, 'Y') = 'Y'");
            sql.append(" ORDER BY CUSTNAME");
            return ok(jdbc.query(sql.toString(), p, CUST_MAPPER));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static final String SELECT_CUST =
        "SELECT CUSTKEY, CUSTCD, CUSTNAME, TELNO, MANNM, CUSTNMHP, SAADDR, MIBULAMT, ENDCHK, SOPOST FROM CUST_MST";

    private static final RowMapper<Map<String, Object>> CUST_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("custkey",  trim(rs.getString("CUSTKEY")));
            m.put("custcd",   trim(rs.getString("CUSTCD")));
            m.put("custname", trim(rs.getString("CUSTNAME")));
            m.put("telno",    trim(rs.getString("TELNO")));
            m.put("mannm",    trim(rs.getString("MANNM")));
            m.put("hp",       trim(rs.getString("CUSTNMHP")));
            m.put("remk",     trim(rs.getString("SAADDR")));
            m.put("mibul",    rs.getLong("MIBULAMT"));
            String end = trim(rs.getString("ENDCHK"));
            m.put("endchk",   isEmpty(end) ? "Y" : end);
            m.put("sopost",   trim(rs.getString("SOPOST")));   // 'WEB' = 웹 등록 → 수정 가능 (그 외는 조회만)
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 등록·수정 : custcd 가 비어 있으면 신규
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai016/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String shop   = shopNo(session);
            String custcd = str(req.get("custcd"));
            String name   = cut(str(req.get("custname")), 60);
            String endchk = "N".equals(str(req.get("endchk"))) ? "N" : "Y";
            if (isEmpty(name)) throw new IllegalArgumentException("거래처명을 입력하세요.");

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shop)
                .addValue("name", name)
                .addValue("tel", cut(str(req.get("telno")), 20))
                .addValue("man", cut(str(req.get("mannm")), 20))
                .addValue("hp", cut(str(req.get("hp")), 20))
                .addValue("remk", cut(str(req.get("remk")), 100))
                .addValue("endchk", endchk);

            if (isEmpty(custcd)) {
                custcd = nextCustcd(shop);
                p.addValue("custkey", shop + custcd).addValue("cd", custcd);
                jdbc.update(
                    "INSERT INTO CUST_MST (CUSTKEY, SHOPNO, CUSTCD, CUSTNAME, TELNO, MANNM, CUSTNMHP, SAADDR, ENDCHK, MIBULAMT, JIKPAN, SOPOST) " +
                    "VALUES (:custkey, :shop, :cd, :name, :tel, :man, :hp, :remk, :endchk, 0, 'N', 'WEB')", p);
                logger.info("ai016 new cust: " + shop + custcd + " " + name + " (by " + userId(session) + ")");
            } else {
                p.addValue("cd", custcd);
                List<String> sopost = jdbc.query("SELECT ISNULL(SOPOST, '') AS SOPOST FROM CUST_MST WHERE SHOPNO = :shop AND CUSTCD = :cd", p,
                    new RowMapper<String>() {
                        public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString("SOPOST")); }
                    });
                if (sopost.isEmpty()) throw new IllegalArgumentException("거래처를 찾을 수 없습니다. (" + custcd + ")");
                if (!"WEB".equals(sopost.get(0))) throw new IllegalArgumentException("WEB 등록 거래처만 수정할 수 있습니다. (POS 거래처는 수정 불가)");
                jdbc.update(
                    "UPDATE CUST_MST SET CUSTNAME = :name, TELNO = :tel, MANNM = :man, CUSTNMHP = :hp, SAADDR = :remk, ENDCHK = :endchk" +
                    " WHERE SHOPNO = :shop AND CUSTCD = :cd", p);
                logger.info("ai016 update cust: " + custcd + " " + name + " (by " + userId(session) + ")");
            }

            return ok(jdbc.query(SELECT_CUST + " WHERE SHOPNO = :shop AND CUSTCD = :cd",
                new MapSqlParameterSource().addValue("shop", shop).addValue("cd", custcd), CUST_MAPPER).get(0));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** CUSTCD = 해당 매장 700000~900000 중 MAX + 1 (ai201 과 동일) */
    private String nextCustcd(String shop) {
        String max = jdbc.queryForObject(
            "SELECT MAX(CUSTCD) FROM CUST_MST WHERE SHOPNO = :shop AND CUSTCD BETWEEN :from AND :to",
            new MapSqlParameterSource().addValue("shop", shop).addValue("from", CUST_FROM).addValue("to", CUST_TO),
            String.class);
        long next;
        try {
            next = isEmpty(max) ? Long.parseLong(CUST_FROM) + 1 : Long.parseLong(max.trim()) + 1;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("거래처코드 최대값이 숫자가 아닙니다. (" + max + ")");
        }
        if (next > Long.parseLong(CUST_TO)) throw new IllegalArgumentException("거래처코드가 " + CUST_TO + " 를 넘었습니다.");
        return String.format("%06d", next);
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
        logger.error("ai016 error", e);
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
