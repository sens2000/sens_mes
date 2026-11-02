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
 * 적정재고 현황 (ar402) — 조회 전용
 *  - 화면 : /ar402.do → ar402.jsp
 *  - 데이터 : /ar402/list
 *  - 테이블 : SHOP_JEPM_MST(현재고) + MC20_MST/MC20_DTL(MC20KEY, 매출·직판 = 판매수량)
 *  - 검색 : 판매기간(CHDATE), 제조회사·브랜드·제품명 = 포함 검색
 *  - 서버는 제품별 현재고·기간 판매수량만 돌려줌
 *    일평균·적정재고·소진예상일·상태·발주권장·과다는 화면(JS)에서 계산 (보유일수를 바꿔도 다시 조회하지 않음)
 */
@Controller
public class ar402_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar402_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar402.do")
    public String ar402(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar402");
        return "ar402";
    }

    // ------------------------------------------------------------------
    // 제품별 현재고 + 기간 판매수량
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar402/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "makecust", defaultValue = "") String makecust,
                                    @RequestParam(value = "brand",    defaultValue = "") String brand,
                                    @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("판매기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            StringBuilder sql = new StringBuilder(
                "SELECT j.makecust, j.brand, j.jepmcd, j.jepmnm," +
                "       ISNULL(j.inprice, 0) AS INPRICE," +      // 매입가
                "       ISNULL(j.jego, 0)    AS JEGO," +         // 현재고
                "       ISNULL(s.saleqty, 0) AS SALEQTY" +       // 기간 판매수량
                "  FROM SHOP_JEPM_MST j" +
                "       LEFT OUTER JOIN" +
                "       ( SELECT d.jepmkey, SUM(ISNULL(d.qty, 0)) AS saleqty" +
                "           FROM mc20_mst a JOIN mc20_dtl d ON a.mc20key = d.mc20key" +
                "          WHERE a.shopno = :shop" +
                "            AND a.kind IN ('매출', '직판')" +      // 반품(마이너스 수량)도 KIND = '매출' 로 같이 빠짐
                "            AND a.chdate BETWEEN :f AND :t" +
                "          GROUP BY d.jepmkey ) s ON s.jepmkey = j.jepmkey" +
                " WHERE j.shopno = :shop" +
                "   AND j.sys = 'N'" +
                "   AND ( ISNULL(j.jego, 0) <> 0 OR ISNULL(s.saleqty, 0) <> 0 )");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);

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
                    m.put("saleqty",  rs.getLong("SALEQTY"));
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
        logger.error("ar402 error", e);
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
