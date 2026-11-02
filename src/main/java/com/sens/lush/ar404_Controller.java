package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
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
 * 장기재고 현황 (ar404) — 조회 전용
 *  - 화면 : /ar404.do → ar404.jsp
 *  - 데이터 : /ar404/list
 *  - 대상 : 현재고가 있는 제품 (SHOP_JEPM_MST.JEGO > 0, SYS = 'N', 로그인 매장)
 *  - 최종판매일 = MC20(MC20KEY) 매출·직판 중 수량 > 0 인 마지막 일자
 *  - 최종입고일 = IP01(IP01KEY) 매입 중 수량 > 0 인 마지막 일자
 *  - 최근 90·180·365일 판매수량(매출·직판, 반품 차감)과 입고수량(매입)을 한 번에 돌려줌
 *  - 장기재고수량·경과일·구분·기준 필터는 화면(JS)에서 계산 (기준을 바꿔도 다시 조회하지 않음)
 *  - 검색 : 제조회사·브랜드·제품명 = 포함 검색
 */
@Controller
public class ar404_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar404_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar404.do")
    public String ar404(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar404");
        return "ar404";
    }

    // ------------------------------------------------------------------
    // 재고 있는 제품 + 최종판매일·최종입고일
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar404/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "makecust", defaultValue = "") String makecust,
                                    @RequestParam(value = "brand",    defaultValue = "") String brand,
                                    @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                    HttpSession session) {
        try {
            // 최근 N일 시작일 (오늘 포함 N일)
            String d90 = daysAgo(89), d180 = daysAgo(179), d365 = daysAgo(364);
            String saleQty = "ISNULL(d.qty, 0)";

            StringBuilder sql = new StringBuilder(
                "SELECT j.makecust, j.brand, j.jepmcd, j.jepmnm," +
                "       ISNULL(j.inprice, 0) AS INPRICE," +      // 매입가
                "       ISNULL(j.jego, 0)    AS JEGO," +         // 현재고
                "       s.LASTSALE, i.LASTIN," +                 // 최종판매일, 최종입고일
                "       ISNULL(s.S90, 0)  AS S90,  ISNULL(s.S180, 0) AS S180, ISNULL(s.S365, 0) AS S365," +   // 기간 판매수량
                "       ISNULL(i.I90, 0)  AS I90,  ISNULL(i.I180, 0) AS I180, ISNULL(i.I365, 0) AS I365" +    // 기간 입고수량
                "  FROM SHOP_JEPM_MST j" +
                "       LEFT OUTER JOIN" +
                "       ( SELECT d.jepmkey," +
                "                MAX(IF " + saleQty + " > 0 THEN a.chdate ELSE NULL ENDIF) AS LASTSALE," +   // 반품은 판매로 보지 않음
                "                SUM(IF a.chdate >= :d90  THEN " + saleQty + " ELSE 0 ENDIF) AS S90," +        // 반품은 차감
                "                SUM(IF a.chdate >= :d180 THEN " + saleQty + " ELSE 0 ENDIF) AS S180," +
                "                SUM(IF a.chdate >= :d365 THEN " + saleQty + " ELSE 0 ENDIF) AS S365" +
                "           FROM mc20_mst a JOIN mc20_dtl d ON a.mc20key = d.mc20key" +
                "          WHERE a.shopno = :shop" +
                "            AND a.kind IN ('매출', '직판')" +
                "          GROUP BY d.jepmkey ) s ON s.jepmkey = j.jepmkey" +
                "       LEFT OUTER JOIN" +
                "       ( SELECT d.jepmkey," +
                "                MAX(IF ISNULL(d.qty, 0) > 0 THEN a.ipdate ELSE NULL ENDIF) AS LASTIN," +
                "                SUM(IF a.ipdate >= :d90  THEN ISNULL(d.qty, 0) ELSE 0 ENDIF) AS I90," +
                "                SUM(IF a.ipdate >= :d180 THEN ISNULL(d.qty, 0) ELSE 0 ENDIF) AS I180," +
                "                SUM(IF a.ipdate >= :d365 THEN ISNULL(d.qty, 0) ELSE 0 ENDIF) AS I365" +
                "           FROM ip01_mst a JOIN ip01_dtl d ON a.ip01key = d.ip01key" +
                "          WHERE a.shopno = :shop" +
                "            AND a.kind = '매입'" +
                "          GROUP BY d.jepmkey ) i ON i.jepmkey = j.jepmkey" +
                " WHERE j.shopno = :shop" +
                "   AND j.sys = 'N'" +
                "   AND ISNULL(j.jego, 0) > 0");
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session))
                .addValue("d90", d90).addValue("d180", d180).addValue("d365", d365);

            // 입력한 항목만 조건 추가 (비워 두면 전체)
            like(sql, p, "j.makecust", "makecust", makecust);
            like(sql, p, "j.brand",    "brand",    brand);
            like(sql, p, "j.jepmnm",   "jepmnm",   jepmnm);

            sql.append(" ORDER BY j.makecust, j.brand, j.jepmnm");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("makecust", trim(rs.getString("makecust")));
                    m.put("brand",    trim(rs.getString("brand")));
                    m.put("jepmcd",   trim(rs.getString("jepmcd")));
                    m.put("jepmnm",   trim(rs.getString("jepmnm")));
                    m.put("inprice",  rs.getLong("INPRICE"));
                    m.put("jego",     rs.getLong("JEGO"));
                    m.put("lastsale", trim(rs.getString("LASTSALE")));
                    m.put("lastin",   trim(rs.getString("LASTIN")));
                    m.put("s90",  rs.getLong("S90"));  m.put("s180", rs.getLong("S180")); m.put("s365", rs.getLong("S365"));
                    m.put("i90",  rs.getLong("I90"));  m.put("i180", rs.getLong("I180")); m.put("i365", rs.getLong("I365"));
                    return m;
                }
            });
            return ok(rows);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 오늘에서 n 일 전 (yyyyMMdd) */
    private static String daysAgo(int n) {
        Calendar c = Calendar.getInstance();
        c.add(Calendar.DATE, -n);
        return new SimpleDateFormat("yyyyMMdd").format(c.getTime());
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
        logger.error("ar404 error", e);
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
