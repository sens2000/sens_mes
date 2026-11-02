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
 * 거래처별 미지급 현황 (ar202) — 조회 전용
 *  - 화면 : /ar202.do → ar202.jsp
 *  - 데이터 : /ar202/list
 *  - 테이블 : CUST_MST (MIBULAMT = 현재 미지급) + IP01_MST (입고·현금·할인)
 *  - 기간 말 미지급 = 현재 미지급 - 기간 이후 증가분(입고 - 현금 - 할인)
 *  - 이월           = 기간 말 미지급 - 기간 입고 + 기간 현금 + 기간 할인
 *  - 검색 : 거래처명(포함 검색), 기간(IPDATE), 거래 없는 거래처 포함 여부
 */
@Controller
public class ar202_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar202_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar202.do")
    public String ar202(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar202");
        return "ar202";
    }

    // ------------------------------------------------------------------
    // 거래처별 미지급 현황
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar202/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "custname", defaultValue = "") String custname,
                                    @RequestParam(value = "all",      defaultValue = "N") String all,   // Y = 거래 없어도 미지급 있으면 표시
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            String endMibul = "(ISNULL(c.mibulamt, 0) - ISNULL(t.addmisu, 0))";   // 기간 말 미지급

            StringBuilder sql = new StringBuilder(
                "SELECT c.custcd, c.custname, c.telno," +
                "       " + endMibul + " - ISNULL(t.amt, 0) + ISNULL(t.cash, 0) + ISNULL(t.sale, 0) AS EWOL," +  // 이월
                "       ISNULL(t.amt, 0)  AS AMT," +       // 입고
                "       ISNULL(t.cash, 0) AS CASH," +      // 현금
                "       ISNULL(t.sale, 0) AS SALE," +      // 할인
                "       " + endMibul + " AS MIBUL" +       // 미지급금 (기간 말)
                "  FROM CUST_MST c" +
                "       LEFT OUTER JOIN" +
                "       ( SELECT custcd," +
                "                SUM(IF ipdate <= :t THEN ISNULL(amt, 0)     ELSE 0 ENDIF) AS amt," +
                "                SUM(IF ipdate <= :t THEN ISNULL(cashamt, 0) ELSE 0 ENDIF) AS cash," +
                "                SUM(IF ipdate <= :t THEN ISNULL(saleamt, 0) ELSE 0 ENDIF) AS sale," +
                "                SUM(IF ipdate >  :t" +
                "                       THEN ISNULL(amt, 0) - ISNULL(cashamt, 0) - ISNULL(saleamt, 0)" +
                "                       ELSE 0 ENDIF) AS addmisu" +              // 기간 이후 증가분
                "           FROM IP01_MST" +
                "          WHERE shopno = :shop" +
                "            AND ipdate >= :f" +                                  // 기간 시작일부터 오늘까지
                "          GROUP BY custcd ) t ON c.custcd = t.custcd" +
                " WHERE c.shopno = :shop");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);

            if (!isEmpty(custname)) {
                sql.append(" AND c.custname LIKE :custname");
                p.addValue("custname", "%" + custname.trim() + "%");
            }
            // 기본 : 기간 중 거래가 있는 거래처만, 'Y' 면 기간 말 미지급이 남은 거래처도 포함
            sql.append(" AND ( ISNULL(t.amt, 0) <> 0 OR ISNULL(t.cash, 0) <> 0 OR ISNULL(t.sale, 0) <> 0");
            if ("Y".equalsIgnoreCase(all)) sql.append(" OR ").append(endMibul).append(" <> 0");
            sql.append(" )");
            sql.append(" ORDER BY c.custname");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("custcd",   trim(rs.getString("custcd")));
                    m.put("custname", trim(rs.getString("custname")));
                    m.put("telno",    trim(rs.getString("telno")));
                    m.put("ewol",     rs.getLong("EWOL"));
                    m.put("amt",      rs.getLong("AMT"));
                    m.put("cash",     rs.getLong("CASH"));
                    m.put("sale",     rs.getLong("SALE"));
                    m.put("mibul",    rs.getLong("MIBUL"));
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
        logger.error("ar202 error", e);
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
