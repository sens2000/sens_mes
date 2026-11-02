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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 회원별 매출 (ar302) — 조회 전용
 *  - 화면 : /ar302.do → ar302.jsp
 *  - 데이터 : /ar302/init (등급·직원 목록), /ar302/list (회원별 매출)
 *  - 테이블 : member + MC20_MST (MEMNO 로 연결), 로그인 매장(SHOPNO)만
 *  - 검색 : 담당자(member.manager, 입력값 포함 검색 / 빈칸 = 전체), 등급(member.member), 판매자(MC20_MST.PRUSER), 기간(MC20_MST.CHDATE)
 *  - 매출 = CASHAMT + CARDAMT (현금 + 카드)
 */
@Controller
public class ar302_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar302_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar302.do")
    public String ar302(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar302");
        return "ar302";
    }

    // ------------------------------------------------------------------
    // 검색 옵션 : 등급(CODE_MST), 직원(user_info — 담당자·판매자)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar302/init", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> init(HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            RowMapper<String> one = new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
            };
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("grades", jdbc.query(
                "SELECT DISTINCT TRIM(CODENM) FROM CODE_MST WHERE CODEGU = '등급' AND SHOPNO = :shop" +
                " AND ISNULL(TRIM(CODENM), '') <> '' ORDER BY 1", p, one));   // 같은 등급이 여러 줄 있어도 한 번만
            // 사용 중인 직원 먼저
            r.put("staff", jdbc.query(
                "SELECT name FROM user_info WHERE shopno = :shop AND ISNULL(name, '') <> ''" +
                " ORDER BY CASE WHEN ISNULL(chk, 'Y') = 'Y' THEN 0 ELSE 1 END, name", p, one));
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 회원별 매출
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar302/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "manager", defaultValue = "") String manager,
                                    @RequestParam(value = "grade", defaultValue = "") String grade,
                                    @RequestParam(value = "pruser", defaultValue = "") String pruser,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            StringBuilder sql = new StringBuilder(
                "SELECT m.manager, m.memno, m.name, m.member, m.handno, m.sms," +
                "       ISNULL(SUM(ISNULL(a.CASHAMT, 0) + ISNULL(a.CARDAMT, 0)), 0) AS AMT," +   // 매출 = 현금 + 카드
                "       ISNULL(SUM(a.CASHAMT), 0)  AS CASH," +
                "       ISNULL(SUM(a.CARDAMT), 0)  AS CARD," +
                "       ISNULL(SUM(a.BONUSUSE), 0) AS BONUS," +
                "       ISNULL(SUM(a.SALEAMT), 0)  AS SALE," +
                "       ISNULL(SUM(a.VISITCNT), 0) AS QTY" +
                "  FROM member m, MC20_MST a" +
                " WHERE a.MEMNO = m.memno" +
                "   AND a.SHOPNO = :shop AND m.shopno = :shop" +       // 로그인 매장만
                "   AND m.chk = 'Y'" +
                "   AND a.CHDATE BETWEEN :f AND :t");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);
            // 선택한 항목만 조건 추가 (비워 두면 전체)
            if (!isEmpty(manager)) { sql.append(" AND m.manager LIKE :manager"); p.addValue("manager", "%" + manager.trim() + "%"); }   // 담당 : 일부만 입력해도 검색
            if (!isEmpty(grade))   { sql.append(" AND m.member = :grade");    p.addValue("grade", grade.trim()); }
            if (!isEmpty(pruser))  { sql.append(" AND a.PRUSER = :pruser");   p.addValue("pruser", pruser.trim()); }
            sql.append(" GROUP BY m.manager, m.memno, m.name, m.member, m.handno, m.sms" +
                       " ORDER BY m.member, m.manager, m.name");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("manager", trim(rs.getString("manager")));
                    m.put("memno",   trim(rs.getString("memno")));
                    m.put("name",    trim(rs.getString("name")));
                    m.put("grade",   trim(rs.getString("member")));
                    m.put("handno",  trim(rs.getString("handno")));
                    m.put("amt",     rs.getLong("AMT"));
                    m.put("cash",    rs.getLong("CASH"));
                    m.put("card",    rs.getLong("CARD"));
                    m.put("bonus",   rs.getLong("BONUS"));
                    m.put("sale",    rs.getLong("SALE"));
                    m.put("qty",     rs.getLong("QTY"));
                    m.put("sms",     trim(rs.getString("sms")));
                    return m;
                }
            });
            return ok(rows);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 세션 / 응답
    // ------------------------------------------------------------------
    @SuppressWarnings("rawtypes")
    private String shopNo(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        Object v = ((Map) u).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ar302 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.trim().isEmpty(); }
}
