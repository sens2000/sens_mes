package com.sens.lush;

import java.sql.SQLException;
import java.util.ArrayList;
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
 * mes0104 제품 (PB mes0104 조회 화면)
 *  - /mes0104.do         화면
 *  - /mes0104/list       조회 (JSON)
 *
 *  제품(prodjepmno = '') 과 그 제품에 붙은 재공품(prodjepmno <> '') 을 UNION 으로 같이 보여 줌
 *  검색 조건은 UNION 위 · 아래에 똑같이 붙임 (둘 다 jepm_mst 기준)
 */
@Controller
public class mes0104_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes0104_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    /** 위 : 제품 ({W} 자리에 검색 조건) */
    private static final String SQL_TOP =
        "SELECT jepm_mst.kind, jepm_mst.jepmno, jepm_mst.jepmcd, jepm_mst.jepmnm, jepm_mst.test, jepm_mst.danwi, " +
        "       convert(char(6), jepm_mst.sizewidth) + '*' + convert(char(6), jepm_mst.sizelength) as size, " +
        "       jepm_mst.prdate, jepm_mst.goodcode, jepm_mst.subcode, jepm_mst.custjepmcd, " +
        "       jepm_mst.jepmno as jegongno, '' as jegongcd, '' as jegongnm, '' as jegongsize, '' as jgongprdate " +
        "  FROM jepm_mst " +
        " WHERE jepm_mst.jepmnm <> '' and jepm_mst.prodjepmno = '' {W} ";

    /** 아래 : 재공품 (j = 그 재공품이 붙은 제품) */
    private static final String SQL_BOTTOM =
        "SELECT j.kind, j.jepmno, j.jepmcd, j.jepmnm, j.test, j.danwi, " +
        "       convert(char(6), j.sizewidth) + '*' + convert(char(6), j.sizelength), " +
        "       j.prdate, j.goodcode, j.subcode, j.custjepmcd, " +
        "       jepm_mst.jepmno, jepm_mst.jepmcd, jepm_mst.jepmnm, " +
        "       convert(char(6), j.sizewidth) + '*' + convert(char(6), j.sizelength), " +
        "       jepm_mst.prdate " +
        "  FROM jepm_mst left outer join jepm_mst j on j.jepmno = jepm_mst.prodjepmno " +
        " WHERE jepm_mst.jepmnm <> '' and jepm_mst.prodjepmno <> '' {W} ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0104.do")
    public String mes0104(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes0104");
        return "mes0104";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0104/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            checkLogin(session);
            StringBuilder w = new StringBuilder();
            MapSqlParameterSource p = new MapSqlParameterSource();

            eqNotAll(w, p, "jepm_mst.company", "comp", v(req, "comp"));          // 전체 / 서울 / 오산 / 원재료
            eqNotAll(w, p, "jepm_mst.test", "test", v(req, "test"));             // 전체 / 제품 / 상품 / 원재료 / 부재료

            String jepmcd = v(req, "jepmcd");                                      // 코드 : 앞글자
            if (!isEmpty(jepmcd)) { w.append(" AND jepm_mst.jepmcd LIKE :jepmcd"); p.addValue("jepmcd", jepmcd + "%"); }

            eq(w, p, "jepm_mst.subcode", "subcode", v(req, "subcode"));          // 분류1

            String cj = v(req, "custjepmcd");                                      // 부코드 : 앞글자
            if (!isEmpty(cj)) { w.append(" AND jepm_mst.custjepmcd LIKE :cj"); p.addValue("cj", cj + "%"); }

            // 품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
            String jepmnm = v(req, "jepmnm");
            if (!isEmpty(jepmnm)) {
                String[] a = jepmnm.split("/", 2);
                String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                if (!s1.isEmpty()) { w.append(" AND jepm_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                if (!s2.isEmpty()) { w.append(" AND jepm_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
            }

            // 등록일 (체크했을 때만)
            if ("Y".equals(v(req, "useDate"))) {
                String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                    w.append(" AND jepm_mst.prdate BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }
            }

            // 삭제제품 : 체크 = chk 'N' (삭제된 것), 해제 = chk 'Y'
            w.append(" AND jepm_mst.chk = :chk");
            p.addValue("chk", "Y".equals(v(req, "delChk")) ? "N" : "Y");

            String sql = SQL_TOP.replace("{W}", w) + " UNION " + SQL_BOTTOM.replace("{W}", w) +
                         " ORDER BY 1, 3, 4, 13, 12";

            List<Map<String, Object>> rows = lower(jdbc.queryForList(sql, p));
            Map<String, Object> res = ok(rows);
            if (rows.size() > MAX_ROWS) {
                rows.subList(MAX_ROWS, rows.size()).clear();
                res.put("msg", MAX_ROWS + "건까지만 표시합니다. 조건을 좁혀 주세요.");
            }
            return res;
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 세션 / 조건 / 응답
    // ------------------------------------------------------------------
    /** 세션 USER 의 COMPANY (없으면 오류) */
    @SuppressWarnings("rawtypes")
    private String company(HttpSession session) {
        checkLogin(session);
        Object v = ((Map) session.getAttribute(SESSION_USER)).get(USER_COMPANY);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalArgumentException("로그인 정보(회사코드)가 없습니다. 세션 USER 의 " + USER_COMPANY + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private void checkLogin(HttpSession session) {
        if (!(session.getAttribute(SESSION_USER) instanceof Map))
            throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
    }

    private static String v(Map<String, String> req, String k) { return trim(req.get(k)); }
    private static String digits(String s) { return s.replaceAll("\\D", ""); }

    private static void eq(StringBuilder sql, MapSqlParameterSource p, String col, String name, String val) {
        if (isEmpty(val)) return;
        sql.append(" AND ").append(col).append(" = :").append(name);
        p.addValue(name, val);
    }

    private static void eqNotAll(StringBuilder sql, MapSqlParameterSource p, String col, String name, String val) {
        if (isEmpty(val) || "전체".equals(val)) return;
        eq(sql, p, col, name, val);
    }

    /** 컬럼명 소문자 + 문자열 앞뒤 공백 제거 */
    private static List<Map<String, Object>> lower(List<Map<String, Object>> list) {
        List<Map<String, Object>> out = new ArrayList<Map<String, Object>>(list.size());
        for (Map<String, Object> r : list) {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            for (Map.Entry<String, Object> e : r.entrySet()) {
                Object val = e.getValue();
                if (val instanceof String) val = ((String) val).trim();
                m.put(e.getKey().toLowerCase(), val);
            }
            out.add(m);
        }
        return out;
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("mes0104 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        if (e instanceof IllegalStateException) m.put("login", true);
        return m;
    }

    private static String trim(String s)     { return s == null ? "" : s.trim(); }
    private static boolean isEmpty(String s) { return s == null || s.trim().isEmpty(); }
}
