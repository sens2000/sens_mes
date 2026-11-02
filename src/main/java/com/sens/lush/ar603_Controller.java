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
 * 제조회사별 판매·매입 현황 (ar603) — 조회 전용
 *  - 화면 : /ar603.do → ar603.jsp
 *  - 데이터 : /ar603/init (판매자 목록), /ar603/list (제조회사별 집계)
 *  - 판매 : MC20_MST + MC20_DTL(MC20KEY) + SHOP_JEPM_MST(JEPMKEY), KIND = '매출'(반품 포함), 판매자(PRUSER)
 *  - 매입 : IP01_MST + IP01_DTL(IP01KEY), KIND = '매입' (판매자와 무관)
 *  - 판매가재고 : SHOP_JEPM_MST 현재 재고(JEGO) × 판매가 (shopno, makecust 인덱스 사용)
 *  - 제조회사는 함수 없이 비교 (인덱스 사용) — 제조회사 NULL 은 미리 '' 로 정리해 둘 것
 *  - 할인%·비율·이익·이익율·매입율은 화면(JS)에서 계산
 */
@Controller
public class ar603_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar603_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar603.do")
    public String ar603(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar603");
        return "ar603";
    }

    // ------------------------------------------------------------------
    // 검색 옵션 : 판매자 (user_info)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar603/init", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> init(HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            // 사용 중인 직원 먼저
            r.put("staff", jdbc.query(
                "SELECT name FROM user_info WHERE shopno = :shop AND ISNULL(name, '') <> ''" +
                " ORDER BY CASE WHEN ISNULL(chk, 'Y') = 'Y' THEN 0 ELSE 1 END, name", p,
                new RowMapper<String>() {
                    public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
                }));
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 제조회사별 판매·매입
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar603/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "pruser", defaultValue = "") String pruser,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t)
                .addValue("user", isEmpty(pruser) ? "%" : pruser.trim());   // 빈칸 = 전체

            String saleWhere =
                " WHERE a.shopno = :shop" +
                "   AND j.shopno = :shop" +
                "   AND a.kind   = '매출'" +
                "   AND a.pruser LIKE :user" +
                "   AND a.chdate BETWEEN :f AND :t";

            String sql =
                "SELECT g.makecust, g.inamt, g.saleamt, g.priceamt, g.saleqty, g.custcnt," +
                "       g.buyamt, g.buyprice, g.buyqty," +
                "       ISNULL(( SELECT SUM(ISNULL(sj.saleprice, 0) * ISNULL(sj.jego, 0))" +
                "                  FROM shop_jepm_mst sj" +
                "                 WHERE sj.shopno   = :shop" +
                "                   AND sj.makecust = g.makecust ), 0) AS salejego" +   // 현재 재고 × 판매가 (인덱스 사용)
                "  FROM ( SELECT v.makecust," +
                "                SUM(v.inamt) AS inamt, SUM(v.saleamt) AS saleamt, SUM(v.priceamt) AS priceamt," +
                "                SUM(v.saleqty) AS saleqty, SUM(v.custcnt) AS custcnt," +
                "                SUM(v.buyamt) AS buyamt, SUM(v.buyprice) AS buyprice, SUM(v.buyqty) AS buyqty" +
                "           FROM (" +
                // 판매
                "                 SELECT j.makecust AS makecust," +
                "                        SUM(ISNULL(d.inprice, 0)   * ISNULL(d.qty, 0)) AS inamt," +
                "                        SUM(ISNULL(d.saleprice, 0) * ISNULL(d.qty, 0)) AS saleamt," +
                "                        SUM(ISNULL(j.price, 0)     * ISNULL(d.qty, 0)) AS priceamt," +
                "                        SUM(ISNULL(d.qty, 0)) AS saleqty," +
                "                        0 AS custcnt, 0 AS buyamt, 0 AS buyprice, 0 AS buyqty" +
                "                   FROM mc20_mst a" +
                "                        JOIN mc20_dtl d      ON a.mc20key = d.mc20key" +
                "                        JOIN shop_jepm_mst j ON d.jepmkey = j.jepmkey" +
                saleWhere +
                "                  GROUP BY j.makecust" +
                "                 UNION ALL" +
                // 구매 고객수 (제조회사별로 서로 다른 회원 수)
                "                 SELECT t.makecust, 0, 0, 0, 0, COUNT(*), 0, 0, 0" +
                "                   FROM ( SELECT DISTINCT j.makecust AS makecust, a.memno" +
                "                            FROM mc20_mst a" +
                "                                 JOIN mc20_dtl d      ON a.mc20key = d.mc20key" +
                "                                 JOIN shop_jepm_mst j ON d.jepmkey = j.jepmkey" +
                saleWhere + " ) t" +
                "                  GROUP BY t.makecust" +
                "                 UNION ALL" +
                // 매입 (판매자와 무관)
                "                 SELECT j.makecust, 0, 0, 0, 0, 0," +
                "                        SUM(ISNULL(d.amt, 0))," +
                "                        SUM(ISNULL(j.price, 0) * ISNULL(d.qty, 0))," +
                "                        SUM(ISNULL(d.qty, 0))" +
                "                   FROM ip01_mst b" +
                "                        JOIN ip01_dtl d      ON b.ip01key = d.ip01key" +
                "                        JOIN shop_jepm_mst j ON d.jepmkey = j.jepmkey" +
                "                  WHERE b.shopno = :shop" +
                "                    AND j.shopno = :shop" +
                "                    AND b.kind   = '매입'" +
                "                    AND b.ipdate BETWEEN :f AND :t" +
                "                  GROUP BY j.makecust" +
                "                ) v" +
                "          GROUP BY v.makecust ) g" +
                " ORDER BY g.makecust";

            List<Map<String, Object>> rows = jdbc.query(sql, p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("makecust", trim(rs.getString("makecust")));
                    for (String k : new String[] { "inamt", "saleamt", "priceamt", "saleqty", "custcnt",
                                                   "buyamt", "buyprice", "buyqty", "salejego" })
                        m.put(k, rs.getLong(k));
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
        logger.error("ar603 error", e);
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
