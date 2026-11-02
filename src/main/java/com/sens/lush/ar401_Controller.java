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
 * 제품 현황 (ar401) — 조회 전용
 *  - 화면 : /ar401.do → ar401.jsp
 *  - 데이터 : /ar401/list
 *  - 테이블 : SHOP_JEPM_MST (SYS = 'N', 로그인 매장 SHOPNO)
 *  - 검색 : 제조회사·브랜드·제품명 = 포함 검색, 재고 있는 제품만(선택)
 *  - 입고율·할인율·입고금액·합계는 화면(JS)에서 계산
 */
@Controller
public class ar401_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar401_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar401.do")
    public String ar401(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar401");
        return "ar401";
    }

    // ------------------------------------------------------------------
    // 제품 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar401/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "makecust", defaultValue = "") String makecust,
                                    @RequestParam(value = "brand",    defaultValue = "") String brand,
                                    @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                    @RequestParam(value = "stock",    defaultValue = "N") String stock,   // Y = 재고 있는 것만
                                    HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(
                "SELECT jepmcd, makecust, brand, jepmnm," +
                "       ISNULL(price, 0)     AS PRICE," +       // 정가
                "       ISNULL(inprice, 0)   AS INPRICE," +     // 입고가
                "       ISNULL(saleprice, 0) AS SALEPRICE," +   // 판매가
                "       ISNULL(jego, 0)      AS JEGO," +        // 재고
                "       remk" +                                 // 비고
                "  FROM SHOP_JEPM_MST" +
                " WHERE sys = 'N'" +
                "   AND shopno = :shop");
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));

            // 입력한 항목만 조건 추가 (비워 두면 전체)
            like(sql, p, "makecust", makecust);
            like(sql, p, "brand",    brand);
            like(sql, p, "jepmnm",   jepmnm);
            if ("Y".equalsIgnoreCase(stock)) sql.append(" AND ISNULL(jego, 0) <> 0");

            sql.append(" ORDER BY makecust, brand, jepmnm");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("jepmcd",    trim(rs.getString("jepmcd")));
                    m.put("makecust",  trim(rs.getString("makecust")));
                    m.put("brand",     trim(rs.getString("brand")));
                    m.put("jepmnm",    trim(rs.getString("jepmnm")));
                    m.put("price",     rs.getLong("PRICE"));
                    m.put("inprice",   rs.getLong("INPRICE"));
                    m.put("saleprice", rs.getLong("SALEPRICE"));
                    m.put("jego",      rs.getLong("JEGO"));
                    m.put("remk",      trim(rs.getString("remk")));
                    return m;
                }
            });
            return ok(rows);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 값이 있을 때만 포함 검색 조건 추가 */
    private static void like(StringBuilder sql, MapSqlParameterSource p, String col, String v) {
        if (isEmpty(v)) return;
        sql.append(" AND ").append(col).append(" LIKE :").append(col);
        p.addValue(col, "%" + v.trim() + "%");
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
        logger.error("ar401 error", e);
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
