package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
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
 * 등급별 매출 (ar303) — 조회 전용
 *  - 화면 : /ar303.do → ar303.jsp
 *  - 데이터 : /ar303/list
 *  - 검색 : 기간(CHDATE), 담당자(member.manager, 포함 검색 / 빈칸 = 전체)
 *  - 보기 : mode = grade(등급별, 기본) / manager(담당자별 : 담당 + 등급으로 묶음)
 *  - 테이블 : MC20_MST + member, 로그인 매장(SHOPNO), KIND = '매출'
 *  - 등급 : member.member (회원번호 7~12자리가 '999999' 이면 '기타')
 *  - 원가 = INAMT, 매출 = AMT - BONUSUSE - SALEAMT, 할인 = SALEAMT + SAEUNAMT + BONUSUSE
 *  - 총회원수 : 로그인 매장 사용 회원(chk = 'Y') 등급별 인원 — 별도 쿼리로 구해서 합침
 *    (ASA 에서 GROUP BY 쿼리 안의 하위 쿼리가 오류를 내는 경우가 있어 분리)
 *  - 이익·이익율·객단가·비중은 화면에서 계산
 */
@Controller
public class ar303_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar303_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar303.do")
    public String ar303(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar303");
        return "ar303";
    }

    // ------------------------------------------------------------------
    // 등급별 매출
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar303/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "manager", defaultValue = "") String manager,
                                    @RequestParam(value = "mode", defaultValue = "grade") String mode,
                                    HttpSession session) {
        final boolean byManager = "manager".equals(mode);   // 담당자별 보기
        try {
            String shop = shopNo(session);
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            MapSqlParameterSource p = new MapSqlParameterSource().addValue("shop", shop).addValue("f", f).addValue("t", t);
            String mgrCond = "";
            if (!isEmpty(manager)) { mgrCond = " AND member.manager LIKE :manager"; p.addValue("manager", "%" + manager.trim() + "%"); }

            // ---- 등급별 매출
            String sql =
                "SELECT " + (byManager ? "t.manager, " : "") + "t.member," +
                "       SUM(t.inamt) AS INAMT, SUM(t.amt) AS AMT, SUM(t.cash) AS CASH, SUM(t.card) AS CARD, SUM(t.sale) AS SALE," +
                "       COUNT(*) AS VISIT, COUNT(DISTINCT t.memno) AS MEMCNT" +
                "  FROM (SELECT ISNULL(member.manager, '') AS manager," +
                "               (IF SUBSTRING(mc20_mst.memno, 7, 6) = '999999' THEN '기타' ELSE member.member ENDIF) AS member," +
                "               mc20_mst.memno," +
                "               ISNULL(mc20_mst.inamt, 0) AS inamt," +
                "               ISNULL(mc20_mst.amt, 0) - ISNULL(mc20_mst.bonususe, 0) - ISNULL(mc20_mst.saleamt, 0) AS amt," +
                "               ISNULL(mc20_mst.cashamt, 0) AS cash," +
                "               ISNULL(mc20_mst.cardamt, 0) AS card," +
                "               ISNULL(mc20_mst.saleamt, 0) + ISNULL(mc20_mst.saeunamt, 0) + ISNULL(mc20_mst.bonususe, 0) AS sale" +
                "          FROM mc20_mst, member" +
                "         WHERE mc20_mst.memno = member.memno" + mgrCond +
                "           AND mc20_mst.chdate BETWEEN :f AND :t" +
                "           AND mc20_mst.kind = '매출'" +
                "           AND mc20_mst.shopno = :shop) t" +
                (byManager ? " GROUP BY t.manager, t.member ORDER BY t.manager, t.member"
                           : " GROUP BY t.member ORDER BY t.member");
            List<Map<String, Object>> rows = jdbc.query(sql, p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    if (byManager) m.put("manager", trim(rs.getString("manager")));
                    m.put("grade",  trim(rs.getString("member")));
                    m.put("inamt",  rs.getLong("INAMT"));
                    m.put("amt",    rs.getLong("AMT"));
                    m.put("cash",   rs.getLong("CASH"));
                    m.put("card",   rs.getLong("CARD"));
                    m.put("sale",   rs.getLong("SALE"));
                    m.put("visit",  rs.getLong("VISIT"));
                    m.put("memcnt", rs.getLong("MEMCNT"));
                    return m;
                }
            });

            // ---- 등급별 총회원수 (사용 회원)
            final Map<String, Long> tot = new HashMap<String, Long>();
            jdbc.query("SELECT member, COUNT(*) AS CNT FROM member WHERE shopno = :shop AND chk = 'Y' GROUP BY member",
                p, new RowMapper<Object>() {
                    public Object mapRow(ResultSet rs, int i) throws SQLException { tot.put(trim(rs.getString("member")), rs.getLong("CNT")); return null; }
                });
            for (Map<String, Object> r : rows) {
                Long n = tot.get(r.get("grade"));
                r.put("memtot", n == null ? 0L : n);
            }
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
        logger.error("ar303 error", e);
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
