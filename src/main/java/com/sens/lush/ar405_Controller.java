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
 * 제조회사별 재고 현황 (ar405) — 조회 전용
 *  - 화면 : /ar405.do → ar405.jsp
 *  - 데이터 : /ar405/list
 *  - 기준일 재고 = 현재 재고(SHOP_JEPM_MST.JEGO) - 기준일 이후 매입 + 기준일 이후 매출·직판 + 기준일 이후 MC27 수량
 *  - 금액 = 단가(정가·매입가·판매가) × 기준일 재고, 제조회사별 합계
 *  - 비중은 화면(JS)에서 계산
 */
@Controller
public class ar405_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar405_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar405.do")
    public String ar405(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar405");
        return "ar405";
    }

    // ------------------------------------------------------------------
    // 제조회사별 재고 (기준일)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar405/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "tdate") String tdate, HttpSession session) {
        try {
            String d = tdate.replace("-", "").trim();
            if (!d.matches("\\d{8}")) throw new IllegalArgumentException("기준일을 확인하세요.");

            String sql =
                "SELECT x.MAKECUST," +
                "       SUM(x.Q)               AS JEGO," +          // 재고
                "       SUM(x.INPRICE   * x.Q) AS INPRICEAMT," +    // 매입가 금액
                "       SUM(x.PRICE     * x.Q) AS PRICEAMT," +      // 정가 금액
                "       SUM(x.SALEPRICE * x.Q) AS SALEPRICEAMT" +   // 판매가 금액
                "  FROM ( SELECT ISNULL(j.makecust, '') AS MAKECUST," +
                "                ISNULL(j.price, 0)     AS PRICE," +
                "                ISNULL(j.inprice, 0)   AS INPRICE," +
                "                ISNULL(j.saleprice, 0) AS SALEPRICE," +
                "                ISNULL(j.jego, 0) + ISNULL(tt.JEGO, 0) AS Q" +    // 기준일 재고
                "           FROM SHOP_JEPM_MST j" +
                "                LEFT OUTER JOIN" +
                "                ( SELECT t.JEPMKEY, SUM(t.QTY) AS JEGO" +
                "                    FROM ( SELECT d.jepmkey AS JEPMKEY, -d.qty AS QTY" +     // 기준일 이후 매입 → 뺌
                "                             FROM ip01_mst a, ip01_dtl d" +
                "                            WHERE a.ip01key = d.ip01key" +
                "                              AND a.shopno = :shop" +
                "                              AND a.kind = '매입'" +
                "                              AND a.ipdate > :d" +
                "                           UNION ALL" +
                "                           SELECT d.jepmkey, d.qty" +                      // 기준일 이후 매출·직판 → 더함
                "                             FROM mc20_mst a, mc20_dtl d" +
                "                            WHERE a.mc20key = d.mc20key" +
                "                              AND a.shopno = :shop" +
                "                              AND a.kind IN ('매출', '직판')" +
                "                              AND a.chdate > :d" +
                "                           UNION ALL" +
                "                           SELECT d.jepmkey, d.qty" +                      // 기준일 이후 MC27 → 더함
                "                             FROM mc27_mst a, mc27_dtl d" +
                "                            WHERE a.mc27key = d.mc27key" +
                "                              AND a.shopno = :shop" +
                "                              AND a.chdate > :d ) t" +
                "                   GROUP BY t.JEPMKEY ) tt ON tt.JEPMKEY = j.jepmkey" +
                "          WHERE j.sys = 'N'" +
                "            AND j.shopno = :shop ) x" +
                " GROUP BY x.MAKECUST" +
                " HAVING SUM(x.Q) <> 0" +
                "     OR SUM(x.INPRICE * x.Q) <> 0 OR SUM(x.PRICE * x.Q) <> 0 OR SUM(x.SALEPRICE * x.Q) <> 0" +
                " ORDER BY x.MAKECUST";

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("d", d);

            List<Map<String, Object>> rows = jdbc.query(sql, p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("makecust",     trim(rs.getString("MAKECUST")));
                    m.put("jego",         rs.getLong("JEGO"));
                    m.put("inpriceamt",   rs.getLong("INPRICEAMT"));
                    m.put("priceamt",     rs.getLong("PRICEAMT"));
                    m.put("salepriceamt", rs.getLong("SALEPRICEAMT"));
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
        logger.error("ar405 error", e);
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
