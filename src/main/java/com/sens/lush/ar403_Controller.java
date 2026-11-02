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
 * 제품별 수불 현황 (ar403) — 조회 전용
 *  - 화면 : /ar403.do → ar403.jsp
 *  - 데이터 : /ar403/list
 *  - 테이블 : SHOP_JEPM_MST(JEPMKEY) + IP01(IP01KEY, 매입) + MC20(MC20KEY, 매출·직판) + MC27(MC27KEY, 기타출고)
 *  - 기간 안 : 매입·판매·판매금액·직판·기타 수량
 *  - 재고(기말) = 현재 재고 - 종료일 이후 매입 + 종료일 이후 매출·직판·기타
 *  - 이월       = 재고 - 매입 + 판매 + 기타 + 직판
 *  - 검색 : 제조회사·브랜드·제품명 = 포함 검색, 기간
 *  - 재고금액·소계·합계는 화면(JS)에서 계산
 */
@Controller
public class ar403_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar403_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar403.do")
    public String ar403(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar403");
        return "ar403";
    }

    // ------------------------------------------------------------------
    // 제품별 수불
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar403/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "makecust", defaultValue = "") String makecust,
                                    @RequestParam(value = "brand",    defaultValue = "") String brand,
                                    @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            StringBuilder sql = new StringBuilder(
                "SELECT j.makecust, j.brand, j.jepmcd, j.jepmnm," +
                "       ISNULL(j.price, 0)     AS PRICE," +       // 정가
                "       ISNULL(j.inprice, 0)   AS INPRICE," +     // 매입가
                "       ISNULL(j.saleprice, 0) AS SALEPRICE," +   // 판매가
                "       SUM(t.jego - t.inqty + t.mcqty + t.etcqty + t.jikqty) AS EWOLQTY," +   // 이월
                "       SUM(t.inqty)  AS INQTY," +      // 매입
                "       SUM(t.inamt)  AS INAMT," +      // 매입금액
                "       SUM(t.mcqty)  AS MCQTY," +      // 판매
                "       SUM(t.mcamt)  AS MCAMT," +      // 판매금액
                "       SUM(t.etcqty) AS ETCQTY," +     // 기타출고
                "       SUM(t.jikqty) AS JIKQTY," +     // 직판
                "       SUM(t.jego)   AS JEGO" +        // 재고 (종료일 기준)
                "  FROM SHOP_JEPM_MST j" +
                "       JOIN" +
                // 매입 : 기간 안 = 매입, 종료일 이후 = 재고에서 뺌
                "       ( SELECT d.jepmkey," +
                "                IF a.ipdate <= :t THEN ISNULL(d.qty, 0) ELSE 0 ENDIF AS inqty," +
                "                IF a.ipdate <= :t THEN ISNULL(d.amt, 0) ELSE 0 ENDIF AS inamt," +
                "                0 AS mcqty, 0 AS mcamt, 0 AS jikqty, 0 AS etcqty," +
                "                IF a.ipdate >  :t THEN -ISNULL(d.qty, 0) ELSE 0 ENDIF AS jego" +
                "           FROM ip01_mst a JOIN ip01_dtl d ON a.ip01key = d.ip01key" +
                "          WHERE a.shopno = :shop AND a.kind = '매입' AND a.ipdate >= :f" +
                "         UNION ALL" +
                // 매출·직판 : 기간 안 = 판매/직판, 종료일 이후 = 재고에 더함
                "         SELECT d.jepmkey, 0, 0," +
                "                IF a.kind = '매출' AND a.chdate <= :t THEN ISNULL(d.qty, 0) ELSE 0 ENDIF," +
                "                IF a.kind = '매출' AND a.chdate <= :t THEN ISNULL(d.amt, 0) ELSE 0 ENDIF," +
                "                IF a.kind = '직판' AND a.chdate <= :t THEN ISNULL(d.qty, 0) ELSE 0 ENDIF," +
                "                0," +
                "                IF a.chdate > :t THEN ISNULL(d.qty, 0) ELSE 0 ENDIF" +
                "           FROM mc20_mst a JOIN mc20_dtl d ON a.mc20key = d.mc20key" +
                "          WHERE a.shopno = :shop AND a.kind IN ('매출', '직판') AND a.chdate >= :f" +
                "         UNION ALL" +
                // 기타출고(MC27) : 기간 안 = 기타, 종료일 이후 = 재고에 더함
                "         SELECT d.jepmkey, 0, 0, 0, 0, 0," +
                "                IF a.chdate <= :t THEN ISNULL(d.qty, 0) ELSE 0 ENDIF," +
                "                IF a.chdate >  :t THEN ISNULL(d.qty, 0) ELSE 0 ENDIF" +
                "           FROM mc27_mst a JOIN mc27_dtl d ON a.mc27key = d.mc27key" +
                "          WHERE a.shopno = :shop AND a.chdate >= :f" +
                "         UNION ALL" +
                // 현재 재고
                "         SELECT jepmkey, 0, 0, 0, 0, 0, 0, ISNULL(jego, 0)" +
                "           FROM SHOP_JEPM_MST" +
                "          WHERE shopno = :shop AND ISNULL(jego, 0) <> 0" +
                "       ) t ON t.jepmkey = j.jepmkey" +
                " WHERE j.shopno = :shop" +
                "   AND j.sys = 'N'");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);

            // 입력한 항목만 조건 추가 (비워 두면 전체)
            like(sql, p, "j.makecust", "makecust", makecust);
            like(sql, p, "j.brand",    "brand",    brand);
            like(sql, p, "j.jepmnm",   "jepmnm",   jepmnm);

            sql.append(" GROUP BY j.makecust, j.brand, j.jepmcd, j.jepmnm, j.price, j.inprice, j.saleprice" +
                       " ORDER BY j.makecust, j.brand, j.jepmnm");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("makecust",  trim(rs.getString("makecust")));
                    m.put("brand",     trim(rs.getString("brand")));
                    m.put("jepmcd",    trim(rs.getString("jepmcd")));
                    m.put("jepmnm",    trim(rs.getString("jepmnm")));
                    m.put("price",     rs.getLong("PRICE"));
                    m.put("inprice",   rs.getLong("INPRICE"));
                    m.put("saleprice", rs.getLong("SALEPRICE"));
                    m.put("ewol",      rs.getLong("EWOLQTY"));
                    m.put("inqty",     rs.getLong("INQTY"));
                    m.put("inamt",     rs.getLong("INAMT"));
                    m.put("mcqty",     rs.getLong("MCQTY"));
                    m.put("mcamt",     rs.getLong("MCAMT"));
                    m.put("etcqty",    rs.getLong("ETCQTY"));
                    m.put("jikqty",    rs.getLong("JIKQTY"));
                    m.put("jego",      rs.getLong("JEGO"));
                    return m;
                }
            });
            return ok(rows);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 값이 있을 때만 포함 검색 조건 추가 */
    private static void like(StringBuilder sql, MapSqlParameterSource p, String col, String name, String v) {
        if (isEmpty(v)) return;
        sql.append(" AND ").append(col).append(" LIKE :").append(name);
        p.addValue(name, "%" + v.trim() + "%");
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
        logger.error("ar403 error", e);
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
