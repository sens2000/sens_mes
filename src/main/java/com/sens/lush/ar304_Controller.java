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
 * 월별 매출 분석 (ar304) — 조회 전용
 *  - 화면 : /ar304.do → ar304.jsp
 *  - 데이터 : /ar304/init (직원 목록), /ar304/list (월별 매출)
 *  - 테이블 : member + MC20_MST (MEMNO 로 연결), KIND = '매출', 로그인 매장(SHOPNO)만
 *  - 년월 : member.prdate(회원 등록일) 앞 6자리
 *  - 검색 : 담당자(member.manager, 포함 검색), 판매자(MC20_MST.PRUSER, 목록 선택), 기간(MC20_MST.CHDATE)
 *  - 판매 = AMT - SALEAMT - BONUSUSE, 원가 = INAMT
 *  - 비중·이익·%·객단가·합계·평균은 화면(JS)에서 계산
 */
@Controller
public class ar304_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar304_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar304.do")
    public String ar304(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar304");
        return "ar304";
    }

    // ------------------------------------------------------------------
    // 검색 옵션 : 직원(user_info — 판매자)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar304/init", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> init(HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            RowMapper<String> one = new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
            };
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            // 사용 중인 직원 먼저
            r.put("staff", jdbc.query(
                "SELECT name FROM user_info WHERE shopno = :shop AND ISNULL(name, '') <> ''" +
                " ORDER BY CASE WHEN ISNULL(chk, 'Y') = 'Y' THEN 0 ELSE 1 END, name", p, one));
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 월별 매출
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar304/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "manager", defaultValue = "") String manager,
                                    @RequestParam(value = "pruser", defaultValue = "") String pruser,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            StringBuilder sql = new StringBuilder(
                "SELECT SUBSTRING(m.prdate, 1, 6) AS YYMM," +
                "       ISNULL(SUM(ISNULL(a.INAMT, 0)), 0) AS INAMT," +                                       // 원가
                "       ISNULL(SUM(ISNULL(a.AMT, 0) - ISNULL(a.SALEAMT, 0) - ISNULL(a.BONUSUSE, 0)), 0) AS SALEAMT," +  // 판매
                "       ISNULL(SUM(ISNULL(a.VISITCNT, 0)), 0) AS VISITCNT," +                                 // 방문수
                "       SUM(IF m.prdate = a.CHDATE THEN 1 ELSE 0 ENDIF) AS NEWMEMBER" +                        // 등록수
                "  FROM member m, MC20_MST a" +
                " WHERE a.MEMNO = m.memno" +
                "   AND a.KIND = '매출'" +
                "   AND a.SHOPNO = :shop" +                     // 로그인 매장만
                "   AND a.CHDATE BETWEEN :f AND :t");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);
            // 입력한 항목만 조건 추가 (비워 두면 전체)
            if (!isEmpty(manager)) { sql.append(" AND m.manager LIKE :manager"); p.addValue("manager", "%" + manager.trim() + "%"); }
            if (!isEmpty(pruser))  { sql.append(" AND a.PRUSER = :pruser");      p.addValue("pruser",  pruser.trim()); }
            sql.append(" GROUP BY SUBSTRING(m.prdate, 1, 6)" +
                       " ORDER BY 1");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("yymm",      trim(rs.getString("YYMM")));
                    m.put("inamt",     rs.getLong("INAMT"));
                    m.put("saleamt",   rs.getLong("SALEAMT"));
                    m.put("visitcnt",  rs.getLong("VISITCNT"));
                    m.put("newmember", rs.getLong("NEWMEMBER"));
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
        logger.error("ar304 error", e);
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
