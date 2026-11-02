package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
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
 * 회원별 6개월 실적 (ar305) — 조회 전용
 *  - 화면 : /ar305.do → ar305.jsp
 *  - 데이터 : /ar305/init (등급 목록), /ar305/list (회원별 월 실적)
 *  - 테이블 : member + MC20_MST (MEMNO 로 연결), KIND = '매출'(반품 포함), 로그인 매장(SHOPNO)만, member.sys = 'N'
 *  - 기간 : 기준월 포함 6개월 (예: 기준월 2026-10 → 20260501 ~ 20261031)
 *  - 실적 = AMT - SALEAMT - BONUSUSE
 *  - 검색 : 담당자(member.manager, 포함 검색), 등급(member.member), 기간실적(6개월 합계 이상), 방문수(이상)
 */
@Controller
public class ar305_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private static final int MONTHS = 6;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar305_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar305.do")
    public String ar305(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar305");
        return "ar305";
    }

    // ------------------------------------------------------------------
    // 검색 옵션 : 등급(CODE_MST)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar305/init", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> init(HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            RowMapper<String> one = new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
            };
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("grades", jdbc.query(
                "SELECT DISTINCT TRIM(CODENM) FROM CODE_MST WHERE CODEGU = '등급' AND SHOPNO = :shop" +
                " AND ISNULL(TRIM(CODENM), '') <> '' ORDER BY 1", p, one));
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 회원별 6개월 실적
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar305/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "base") String base,                        // 기준월 yyyy-MM
                                    @RequestParam(value = "manager",  defaultValue = "") String manager,
                                    @RequestParam(value = "grade",    defaultValue = "") String grade,
                                    @RequestParam(value = "minAmt",   defaultValue = "") String minAmt,   // 기간실적 이상
                                    @RequestParam(value = "minVisit", defaultValue = "") String minVisit, // 방문수 이상
                                    HttpSession session) {
        try {
            String b = base.replace("-", "").trim();
            if (!b.matches("\\d{6}")) throw new IllegalArgumentException("기준월을 확인하세요.");

            // 기준월 포함 6개월 : 가장 앞 달부터
            final List<String> months = new ArrayList<String>();
            Calendar c = Calendar.getInstance();
            c.clear();
            c.set(Integer.parseInt(b.substring(0, 4)), Integer.parseInt(b.substring(4, 6)) - 1, 1);
            c.add(Calendar.MONTH, -(MONTHS - 1));
            for (int i = 0; i < MONTHS; i++) {
                months.add(String.format("%04d%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1));
                c.add(Calendar.MONTH, 1);
            }
            String f = months.get(0) + "01";
            String t = b + "31";            // CHDATE 는 문자 yyyyMMdd 라 31 로 두면 말일까지 포함

            String amtExpr = "(ISNULL(a.AMT, 0) - ISNULL(a.SALEAMT, 0) - ISNULL(a.BONUSUSE, 0))";
            StringBuilder sql = new StringBuilder("SELECT m.manager, m.memno, m.name, m.member, m.handno");
            for (int i = 0; i < MONTHS; i++) {
                // months 값은 위에서 만든 숫자 6자리라 그대로 넣어도 안전
                sql.append(", ISNULL(SUM(IF SUBSTRING(a.CHDATE, 1, 6) = '").append(months.get(i))
                   .append("' THEN ").append(amtExpr).append(" ELSE 0 ENDIF), 0) AS AMT").append(i + 1);
            }
            sql.append(", ISNULL(SUM(ISNULL(a.VISITCNT, 0)), 0) AS VISIT")
               .append(", ISNULL(SUM(").append(amtExpr).append("), 0) AS AMT")
               .append("  FROM member m, MC20_MST a")
               .append(" WHERE a.MEMNO = m.memno")
               .append("   AND a.KIND = '매출'")                            // 반품도 KIND = '매출' 로 저장됨
               .append("   AND a.SHOPNO = :shop AND m.shopno = :shop")     // 로그인 매장만
               .append("   AND m.sys = 'N'")
               .append("   AND a.CHDATE BETWEEN :f AND :t");

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);
            // 입력한 항목만 조건 추가 (비워 두면 전체)
            if (!isEmpty(manager)) { sql.append(" AND m.manager LIKE :manager"); p.addValue("manager", "%" + manager.trim() + "%"); }
            if (!isEmpty(grade))   { sql.append(" AND m.member = :grade");       p.addValue("grade", grade.trim()); }

            sql.append(" GROUP BY m.manager, m.memno, m.name, m.member, m.handno");
            // 기간실적·방문수 : 입력했을 때만
            List<String> having = new ArrayList<String>();
            if (!isEmpty(minAmt))   { having.add("SUM(" + amtExpr + ") >= :minAmt");          p.addValue("minAmt", toLong(minAmt, "기간실적")); }
            if (!isEmpty(minVisit)) { having.add("SUM(ISNULL(a.VISITCNT, 0)) >= :minVisit"); p.addValue("minVisit", toLong(minVisit, "방문수")); }
            if (!having.isEmpty()) sql.append(" HAVING ").append(String.join(" AND ", having));
            sql.append(" ORDER BY m.manager, m.member, m.name");          // 담당 > 등급 > 성명 (화면에서 담당별 병합)

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("manager", trim(rs.getString("manager")));
                    m.put("memno",   trim(rs.getString("memno")));
                    m.put("name",    trim(rs.getString("name")));
                    m.put("grade",   trim(rs.getString("member")));
                    m.put("handno",  trim(rs.getString("handno")));
                    for (int k = 1; k <= MONTHS; k++) m.put("amt" + k, rs.getLong("AMT" + k));
                    m.put("visit",   rs.getLong("VISIT"));
                    m.put("amt",     rs.getLong("AMT"));
                    return m;
                }
            });

            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("months", months);          // ["202605", … "202610"]
            r.put("from", f);
            r.put("to", t);
            r.put("rows", rows);
            return ok(r);
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
        logger.error("ar305 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static long toLong(String s, String label) {
        try { return Long.parseLong(s.replace(",", "").trim()); }
        catch (NumberFormatException e) { throw new IllegalArgumentException(label + "은(는) 숫자로 입력하세요."); }
    }

    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.replace(",", "").trim().isEmpty(); }
}
