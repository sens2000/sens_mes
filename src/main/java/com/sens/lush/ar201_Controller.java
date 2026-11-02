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
 * 입고 내역 (ar201) — 조회 전용
 *  - 화면 : /ar201.do → ar201.jsp
 *  - 데이터 : /ar201/list (입고 내역)
 *  - 테이블 : IP01_MST + IP01_DTL(IP01KEY) + SHOP_JEPM_MST(JEPMKEY) + CUST_MST(CUSTCD)
 *  - 조건 : 로그인 매장(IP01_MST.SHOPNO), 제품 마스터는 세션 GROUPNO (없으면 SHOPNO), 기간(IPDATE)
 *  - 검색 : 거래처명·제조회사·브랜드·제품명 = 포함 검색
 *  - 전표번호(MJPNO)·SEQ 는 화면에 안 보임 (정렬·줄 색 구분용)
 *  - 소계·합계(수량·서비스·금액)는 화면(JS)에서 계산
 */
@Controller
public class ar201_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 키 이름 */
    private static final String SESSION_USER     = "USER";
    private static final String USER_SHOP_FIELD  = "SHOPNO";
    private static final String USER_GROUP_FIELD = "GROUPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar201_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar201.do")
    public String ar201(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar201");
        return "ar201";
    }

    // ------------------------------------------------------------------
    // 입고 내역
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar201/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "custname", defaultValue = "") String custname,
                                    @RequestParam(value = "makecust", defaultValue = "") String makecust,
                                    @RequestParam(value = "brand",    defaultValue = "") String brand,
                                    @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            StringBuilder sql = new StringBuilder(
                "SELECT c.custcd, c.custname, a.IPDATE, a.MJPNO, d.SEQ," +
                "       j.makecust, j.brand, j.jepmnm, j.jepmcd," +
                "       ISNULL(j.inprice, 0) AS JINPRICE," +   // 제품입고가 (마스터)
                "       ISNULL(j.price, 0)   AS JPRICE," +     // 정가 (마스터)
                "       ISNULL(d.price, 0)   AS IPPRICE," +    // 입고가 (전표)
                "       ISNULL(d.qty, 0)     AS QTY," +        // 수량
                "       ISNULL(d.amt, 0)     AS AMT," +        // 금액
                "       ISNULL(d.pack, 0)    AS PACK" +        // 서비스
                "  FROM IP01_MST a, IP01_DTL d, SHOP_JEPM_MST j, CUST_MST c" +
                " WHERE a.IP01KEY = d.IP01KEY" +
                "   AND d.JEPMKEY = j.JEPMKEY" +
                "   AND a.CUSTCD  = c.CUSTCD" +
                "   AND a.SHOPNO  = :shop" +               // 입고 : 로그인 매장
                "   AND j.SHOPNO  = :grp" +                // 제품 마스터 : 그룹(본사) 기준
                "   AND a.IPDATE BETWEEN :f AND :t");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("grp", shopNo(session))
                .addValue("f", f).addValue("t", t);

            // 입력한 항목만 조건 추가 (비워 두면 전체)
            like(sql, p, "c.custname", "custname", custname);
            like(sql, p, "j.makecust", "makecust", makecust);
            like(sql, p, "j.brand",    "brand",    brand);
            like(sql, p, "j.jepmnm",   "jepmnm",   jepmnm);

            sql.append(" ORDER BY c.custname, a.IPDATE, a.MJPNO, d.SEQ");   // 거래처 > 입고일 > 전표 > 순번
            logger.info("Start Page: ar201 sql=" + sql);
            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("custcd",   trim(rs.getString("custcd")));
                    m.put("custname", trim(rs.getString("custname")));
                    m.put("ipdate",   trim(rs.getString("IPDATE")));
                    m.put("mjpno",    trim(rs.getString("MJPNO")));     // 화면에는 안 보임
                    m.put("makecust", trim(rs.getString("makecust")));
                    m.put("brand",    trim(rs.getString("brand")));
                    m.put("jepmnm",   trim(rs.getString("jepmnm")));
                    m.put("jepmcd",   trim(rs.getString("jepmcd")));
                    m.put("jinprice", rs.getLong("JINPRICE"));
                    m.put("jprice",   rs.getLong("JPRICE"));
                    m.put("ipprice",  rs.getLong("IPPRICE"));
                    m.put("qty",      rs.getLong("QTY"));
                    m.put("amt",      rs.getLong("AMT"));
                    m.put("pack",     rs.getLong("PACK"));
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
        logger.error("ar201 error", e);
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
