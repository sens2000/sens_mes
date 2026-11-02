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
 * 제품별 전표내역 (ar309) — 조회 전용
 *  - 화면 : /ar309.do → ar309.jsp
 *  - 데이터 : /ar309/list
 *  - 테이블 : MC27_MST + MC27_DTL(MC27KEY) + SHOP_JEPM_MST(JEPMKEY)
 *  - 조건 : 전표는 로그인 매장(MC27_MST.SHOPNO), 제품 마스터는 세션 GROUPNO (없으면 SHOPNO), 기간(CHDATE)
 *  - 검색 : 제조회사·브랜드·제품명 = 포함 검색
 *  - 금액 = 입고가 × 수량, 정가금액 = 정가 × 수량, 일자별 소계·합계는 화면(JS)에서 계산
 *  - 전표번호(CJPNO)·SEQ 는 화면에 안 보임 (정렬·줄 색 구분용)
 */
@Controller
public class ar309_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 키 이름 */
    private static final String SESSION_USER     = "USER";
    private static final String USER_SHOP_FIELD  = "SHOPNO";
    private static final String USER_GROUP_FIELD = "GROUPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar309_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar309.do")
    public String ar309(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar309");
        return "ar309";
    }

    // ------------------------------------------------------------------
    // 제품별 전표내역
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar309/list", method = RequestMethod.GET)
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
                "SELECT a.CHDATE, a.REMK, a.CGUBUN, a.CJPNO, d.SEQ," +
                "       j.jepmcd, j.makecust, j.brand, j.jepmnm," +
                "       ISNULL(j.price, 0)   AS PRICE," +      // 정가
                "       ISNULL(j.inprice, 0) AS INPRICE," +    // 입고가
                "       ISNULL(d.qty, 0)     AS QTY" +         // 수량
                "  FROM MC27_MST a, MC27_DTL d, SHOP_JEPM_MST j" +
                " WHERE a.MC27KEY = d.MC27KEY" +
                "   AND d.JEPMKEY = j.JEPMKEY" +
                "   AND a.SHOPNO  = :shop" +               // 전표 : 로그인 매장
                "   AND j.SHOPNO  = :grp" +                // 제품 마스터 : 그룹(본사) 기준
                "   AND a.CHDATE BETWEEN :f AND :t");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("grp", shopNo(session))
                .addValue("f", f).addValue("t", t);

            // 입력한 항목만 조건 추가 (비워 두면 전체)
            like(sql, p, "j.makecust", "makecust", makecust);
            like(sql, p, "j.brand",    "brand",    brand);
            like(sql, p, "j.jepmnm",   "jepmnm",   jepmnm);

            sql.append(" ORDER BY a.CHDATE, a.CJPNO, d.SEQ");   // 일자 > 전표 > 순번

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("chdate",   trim(rs.getString("CHDATE")));
                    m.put("remk",     trim(rs.getString("REMK")));
                    m.put("cgubun",   trim(rs.getString("CGUBUN")));
                    m.put("cjpno",    trim(rs.getString("CJPNO")));     // 화면에는 안 보임
                    m.put("jepmcd",   trim(rs.getString("jepmcd")));
                    m.put("makecust", trim(rs.getString("makecust")));
                    m.put("brand",    trim(rs.getString("brand")));
                    m.put("jepmnm",   trim(rs.getString("jepmnm")));
                    m.put("price",    rs.getLong("PRICE"));
                    m.put("inprice",  rs.getLong("INPRICE"));
                    m.put("qty",      rs.getLong("QTY"));
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
    private Map user(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map) u;
    }

    private String shopNo(HttpSession session) {
        Object v = user(session).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    /** 제품 마스터 기준 : 세션 GROUPNO, 없으면 매장코드 */
    private String groupNo(HttpSession session) {
        Object v = user(session).get(USER_GROUP_FIELD);
        return (v == null || v.toString().trim().isEmpty()) ? shopNo(session) : v.toString().trim();
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ar309 error", e);
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
