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
 * 판매자별 현황 (ar306) — 조회 전용
 *  - 화면 : /ar306.do → ar306.jsp
 *  - 데이터 : /ar306/list (판매자별 집계)
 *  - 테이블 : MC20_MST + member (MEMNO 로 연결 — MEMNO 에 매장코드 포함), MC20_DTL(개수)
 *  - 조건 : KIND = '매출'(반품 포함), 로그인 매장(SHOPNO)만, 기간(CHDATE)
 *  - 매출     = AMT - BONUSUSE - SALEAMT
 *  - 포인트   = BONUSUSE + SAEUNAMT
 *  - 방문수   = 판매자별 서로 다른 회원 수
 *  - 신규     = 가입일(member.prdate) = 판매일 인 전표의 VISITCNT, 신규매출 = 그 전표 매출
 *  - 재방문   = 가입일부터 판매일까지 재방문일(기본 31일) 미만인 전표의 VISITCNT, 재방문금액 = 그 전표 매출
 *  - 이익·%·객단가·비중·객수량·개당판매 는 화면(JS)에서 계산
 */
@Controller
public class ar306_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar306_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar306.do")
    public String ar306(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar306");
        return "ar306";
    }

    // ------------------------------------------------------------------
    // 판매자별 현황
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar306/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "days", defaultValue = "31") String days,   // 재방문일
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
            String d = days == null ? "" : days.trim();
            if (!d.matches("\\d{1,4}") || Integer.parseInt(d) < 1) throw new IllegalArgumentException("재방문일은 1 이상 숫자로 입력하세요.");
            int revisitDays = Integer.parseInt(d);   // 숫자만 확인했으므로 SQL 에 그대로 넣어도 안전

            String saleExpr = "(ISNULL(a.AMT, 0) - ISNULL(a.BONUSUSE, 0) - ISNULL(a.SALEAMT, 0))";
            String isNew    = "m.prdate = a.CHDATE";
            // 가입일이 비어 있으면 아주 옛날(20000101)로 보고 재방문에서 빠지게 함
            String passDays = "DATEDIFF(day, IF ISNULL(m.prdate, '') = '' THEN '20000101' ELSE m.prdate ENDIF, a.CHDATE)";

            String sql =
                "SELECT t.PRUSER," +
                "       SUM(t.MCAMT)      AS MCAMT," +       // 매출
                "       SUM(t.CASH)       AS CASH," +        // 현금
                "       SUM(t.CARD)       AS CARD," +        // 카드
                "       SUM(t.DISC)       AS DISC," +        // 할인
                "       SUM(t.INAMT)      AS INAMT," +       // 원가
                "       SUM(t.POINT)      AS POINT," +       // 포인트
                "       SUM(t.QTY)        AS QTY," +         // 개수
                "       COUNT(DISTINCT t.MEMNO) AS MEMCNT," + // 방문수
                "       SUM(t.NEWMEM)     AS NEWMEM," +      // 신규
                "       SUM(t.NEWAMT)     AS NEWAMT," +      // 신규매출
                "       SUM(t.REVISIT)    AS REVISIT," +     // 재방문
                "       SUM(t.REVISITAMT) AS REVISITAMT" +   // 재방문금액
                "  FROM ( SELECT a.PRUSER," +
                "                " + saleExpr + " AS MCAMT," +
                "                ISNULL(a.CASHAMT, 0) AS CASH," +
                "                ISNULL(a.CARDAMT, 0) AS CARD," +
                "                ISNULL(a.SALEAMT, 0) AS DISC," +
                "                ISNULL(a.INAMT, 0)   AS INAMT," +
                "                ISNULL(a.BONUSUSE, 0) + ISNULL(a.SAEUNAMT, 0) AS POINT," +
                "                (SELECT ISNULL(SUM(d.QTY), 0) FROM MC20_DTL d WHERE d.MC20KEY = a.MC20KEY) AS QTY," +
                "                a.MEMNO," +
                "                IF " + isNew + " THEN ISNULL(a.VISITCNT, 0) ELSE 0 ENDIF AS NEWMEM," +
                "                IF " + isNew + " THEN " + saleExpr + " ELSE 0 ENDIF AS NEWAMT," +
                "                IF " + passDays + " < " + revisitDays + " THEN ISNULL(a.VISITCNT, 0) ELSE 0 ENDIF AS REVISIT," +
                "                IF " + passDays + " < " + revisitDays + " THEN " + saleExpr + " ELSE 0 ENDIF AS REVISITAMT" +
                "           FROM MC20_MST a, member m" +
                "          WHERE m.memno = a.MEMNO" +
                "            AND a.CHDATE BETWEEN :f AND :t" +
                "            AND a.SHOPNO = :shop" +             // 로그인 매장만
                "            AND a.KIND = '매출' ) AS t" +       // 반품도 KIND = '매출'
                " GROUP BY t.PRUSER" +
                " ORDER BY t.PRUSER";

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);

            List<Map<String, Object>> rows = jdbc.query(sql, p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("pruser",     trim(rs.getString("PRUSER")));
                    m.put("mcamt",      rs.getLong("MCAMT"));
                    m.put("cash",       rs.getLong("CASH"));
                    m.put("card",       rs.getLong("CARD"));
                    m.put("disc",       rs.getLong("DISC"));
                    m.put("inamt",      rs.getLong("INAMT"));
                    m.put("point",      rs.getLong("POINT"));
                    m.put("qty",        rs.getLong("QTY"));
                    m.put("memcnt",     rs.getLong("MEMCNT"));
                    m.put("newmem",     rs.getLong("NEWMEM"));
                    m.put("newamt",     rs.getLong("NEWAMT"));
                    m.put("revisit",    rs.getLong("REVISIT"));
                    m.put("revisitamt", rs.getLong("REVISITAMT"));
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
        logger.error("ar306 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s) { return s == null ? "" : s.trim(); }
}
