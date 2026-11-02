package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
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
import org.springframework.jdbc.core.ResultSetExtractor;
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
 * 제품 수불 내역 (ar408) — 조회 전용
 *  - 화면 : /ar408.do → ar408.jsp
 *  - 데이터 : /ar408/products (제품 찾기 : 제조회사·브랜드·제품명·제품코드), /ar408/list (선택한 제품의 입출고 내역)
 *  - 입고 : IP01_MST + IP01_DTL (IP01KEY, KIND = '매입') + CUST_MST(매입처)
 *  - 출고 : MC20_MST + MC20_DTL (MC20KEY, KIND IN ('매출','직판')) + member(매출처, 비회원 포함)
 *  - 조정 : MC27_MST + MC27_DTL (MC27KEY)
 *  - 모두 로그인 매장(SHOPNO), 제품은 JEPMKEY
 *  - 기말재고(종료일 마감) = 현재고 - 종료일 이후 입고 + 종료일 이후 출고·조정
 *  - 줄마다 재고는 화면(JS)에서 기말재고부터 거꾸로 계산 (현재고 → 기말 → … → 이월)
 */
@Controller
public class ar408_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private static final int PRODUCT_MAX = 200;   // 제품 찾기 최대 건수

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar408_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar408.do")
    public String ar408(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar408");
        return "ar408";
    }

    // ------------------------------------------------------------------
    // 제품 찾기 : 제조회사·브랜드·제품명·제품코드 (포함 검색)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar408/products", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> products(@RequestParam(value = "makecust", defaultValue = "") String makecust,
                                        @RequestParam(value = "brand",    defaultValue = "") String brand,
                                        @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                        @RequestParam(value = "jepmcd",   defaultValue = "") String jepmcd,
                                        HttpSession session) {
        try {
            if (isEmpty(makecust) && isEmpty(brand) && isEmpty(jepmnm) && isEmpty(jepmcd))
                throw new IllegalArgumentException("제조회사·브랜드·제품명·제품코드 중 하나는 입력하세요.");

            StringBuilder sql = new StringBuilder(PRODUCT_SQL + " WHERE j.shopno = :shop AND j.sys = 'N'");
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            like(sql, p, "j.makecust", "makecust", makecust);
            like(sql, p, "j.brand",    "brand",    brand);
            like(sql, p, "j.jepmnm",   "jepmnm",   jepmnm);
            like(sql, p, "j.jepmcd",   "jepmcd",   jepmcd);     // 바코드 일부만 입력해도 찾음
            sql.append(" ORDER BY j.makecust, j.brand, j.jepmnm");

            // 최대 건수는 결과를 읽으면서 끊음 (PRODUCT_MAX + 1 건까지 읽어 "더 있음" 판단)
            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new ResultSetExtractor<List<Map<String, Object>>>() {
                public List<Map<String, Object>> extractData(ResultSet rs) throws SQLException {
                    List<Map<String, Object>> list = new ArrayList<Map<String, Object>>();
                    while (list.size() <= PRODUCT_MAX && rs.next()) list.add(product(rs));
                    return list;
                }
            });
            boolean more = rows.size() > PRODUCT_MAX;
            if (more) rows = rows.subList(0, PRODUCT_MAX);
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("rows", rows);
            r.put("more", more);
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 선택한 제품의 입출고 내역
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar408/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "jepmkey") String jepmkey,
                                    @RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
            if (isEmpty(jepmkey)) throw new IllegalArgumentException("제품을 먼저 선택하세요.");

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("k", jepmkey.trim())
                .addValue("f", f).addValue("t", t);

            // 1) 제품 정보 (현재고 포함)
            List<Map<String, Object>> ps = jdbc.query(PRODUCT_SQL + " WHERE j.shopno = :shop AND j.jepmkey = :k", p,
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException { return product(rs); }
                });
            if (ps.isEmpty()) throw new IllegalArgumentException("제품을 찾을 수 없습니다.");
            Map<String, Object> prod = ps.get(0);

            // 2) 기간 내역 (입고 · 출고 · 조정)
            String sql =
                // 입고
                "SELECT ISNULL(c.custname, '') AS custname, a.ipdate AS procdate, '입고' AS procgubun," +
                "       ISNULL(d.qty, 0) AS inqty, ISNULL(d.price, 0) AS inprice," +
                "       0 AS saleqty, 0 AS saleprice, 0 AS etcqty" +
                "  FROM ip01_mst a" +
                "       JOIN ip01_dtl d            ON a.ip01key = d.ip01key" +
                "       LEFT OUTER JOIN cust_mst c ON a.custcd  = c.custcd" +
                " WHERE a.shopno = :shop AND a.kind = '매입' AND d.jepmkey = :k" +
                "   AND a.ipdate BETWEEN :f AND :t" +
                " UNION ALL" +
                // 출고 (매출·직판, 비회원 포함)
                " SELECT TRIM(ISNULL(m.name, '비회원') + ' ' + ISNULL(m.telno, '')), a.chdate, a.kind," +
                "       0, 0, ISNULL(d.qty, 0), ISNULL(d.saleprice, 0), 0" +
                "  FROM mc20_mst a" +
                "       JOIN mc20_dtl d          ON a.mc20key = d.mc20key" +
                "       LEFT OUTER JOIN member m ON a.memno   = m.memno" +
                " WHERE a.shopno = :shop AND a.kind IN ('매출', '직판') AND d.jepmkey = :k" +
                "   AND a.chdate BETWEEN :f AND :t" +
                " UNION ALL" +
                // 조정 (기타출고)
                " SELECT ISNULL(a.cgubun, ''), a.chdate, '조정', 0, 0, 0, 0, ISNULL(d.qty, 0)" +
                "  FROM mc27_mst a" +
                "       JOIN mc27_dtl d ON a.mc27key = d.mc27key" +
                " WHERE a.shopno = :shop AND d.jepmkey = :k" +
                "   AND a.chdate BETWEEN :f AND :t" +
                " ORDER BY 2";
            List<Map<String, Object>> rows = jdbc.query(sql, p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("procdate",  trim(rs.getString("procdate")));
                    m.put("procgubun", trim(rs.getString("procgubun")));
                    m.put("custname",  trim(rs.getString("custname")));
                    m.put("inqty",     rs.getLong("inqty"));
                    m.put("inprice",   rs.getLong("inprice"));
                    m.put("saleqty",   rs.getLong("saleqty"));
                    m.put("saleprice", rs.getLong("saleprice"));
                    m.put("etcqty",    rs.getLong("etcqty"));
                    return m;
                }
            });

            // 3) 종료일 이후(오늘까지) 입출고 → 기말재고 = 현재고 - 이후 입고 + 이후 출고·조정
            String moveSql =
                "SELECT ( SELECT ISNULL(SUM(ISNULL(d.qty, 0)), 0)" +
                "           FROM ip01_mst a JOIN ip01_dtl d ON a.ip01key = d.ip01key" +
                "          WHERE a.shopno = :shop AND a.kind = '매입' AND d.jepmkey = :k AND a.ipdate > :t ) AS INQ," +
                "       ( SELECT ISNULL(SUM(ISNULL(d.qty, 0)), 0)" +
                "           FROM mc20_mst a JOIN mc20_dtl d ON a.mc20key = d.mc20key" +
                "          WHERE a.shopno = :shop AND a.kind IN ('매출', '직판') AND d.jepmkey = :k AND a.chdate > :t ) AS OUTQ," +
                "       ( SELECT ISNULL(SUM(ISNULL(d.qty, 0)), 0)" +
                "           FROM mc27_mst a JOIN mc27_dtl d ON a.mc27key = d.mc27key" +
                "          WHERE a.shopno = :shop AND d.jepmkey = :k AND a.chdate > :t ) AS ETCQ" +
                "  FROM dummy";
            Map<String, Object> mv = jdbc.queryForMap(moveSql, p);
            long jego = ((Number) prod.get("jego")).longValue();
            long afterIn = num(mv.get("INQ")), afterOut = num(mv.get("OUTQ")), afterEtc = num(mv.get("ETCQ"));
            long closing = jego - afterIn + afterOut + afterEtc;

            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("product", prod);
            r.put("closing", closing);     // 기말재고 (종료일 마감)
            r.put("afterIn", afterIn);     // 종료일 이후 입고
            r.put("afterOut", afterOut);   // 종료일 이후 출고
            r.put("afterEtc", afterEtc);   // 종료일 이후 조정
            r.put("rows", rows);
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 제품 정보 SELECT (WHERE 는 호출하는 쪽에서 붙임) */
    private static final String PRODUCT_SQL =
        "SELECT j.jepmkey, j.makecust, j.brand, j.jepmnm, j.jepmcd," +
        "       ISNULL(j.price, 0)     AS PRICE," +       // 정가
        "       ISNULL(j.inprice, 0)   AS INPRICE," +     // 입고가
        "       ISNULL(j.saleprice, 0) AS SALEPRICE," +   // 판매가
        "       ISNULL(j.jego, 0)      AS JEGO" +         // 현재고
        "  FROM SHOP_JEPM_MST j";

    private static Map<String, Object> product(ResultSet rs) throws SQLException {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("jepmkey",   trim(rs.getString("jepmkey")));
        m.put("makecust",  trim(rs.getString("makecust")));
        m.put("brand",     trim(rs.getString("brand")));
        m.put("jepmnm",    trim(rs.getString("jepmnm")));
        m.put("jepmcd",    trim(rs.getString("jepmcd")));
        m.put("price",     rs.getLong("PRICE"));
        m.put("inprice",   rs.getLong("INPRICE"));
        m.put("saleprice", rs.getLong("SALEPRICE"));
        m.put("jego",      rs.getLong("JEGO"));
        return m;
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
        logger.error("ar408 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static long num(Object o)         { return o instanceof Number ? ((Number) o).longValue() : 0L; }
    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.trim().isEmpty(); }
}
