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
 * mes0105 거래처관리 (PB mes0105 조회 화면)
 *  - /mes0105.do         화면
 *  - /mes0105/list       조회 (JSON)
 *
 *  담당 · 거래처명 은 이름 일부 검색 (like '%값%')
 *  삭제구분 체크 = chk 'N' (삭제된 거래처), 해제 = chk 'Y'
 */
@Controller
public class mes0105_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes0105_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       cust_mst.custcd, cust_mst.company, cust_mst.custname, cust_mst.owner, cust_mst.telno, " +
        "       cust_mst.userid, cust_mst.mimc, cust_mst.prdate, cust_mst.sabunnm " +
        "  FROM cust_mst " +
        " WHERE cust_mst.chk = :chk ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0105.do")
    public String mes0105(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes0105");
        return "mes0105";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0105/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            checkLogin(session);
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("chk", "Y".equals(v(req, "delChk")) ? "N" : "Y");       // 삭제구분

            eqNotAll(sql, p, "cust_mst.company", "comp", v(req, "comp"));         // 전체 / 서울 / 오산
            eqNotAll(sql, p, "cust_mst.mimc",    "mimc", v(req, "mimc"));         // 전체 / 매입 / 매출 / 외주

            String sabunnm = v(req, "sabunnm");                                    // 담당 : 이름 일부
            if (!isEmpty(sabunnm)) { sql.append(" AND cust_mst.sabunnm LIKE :sabunnm"); p.addValue("sabunnm", "%" + sabunnm + "%"); }

            String custname = v(req, "custname");                                  // 거래처명 : 이름 일부
            if (!isEmpty(custname)) { sql.append(" AND cust_mst.custname LIKE :custname"); p.addValue("custname", "%" + custname + "%"); }

            sql.append(" ORDER BY cust_mst.company, cust_mst.mimc, cust_mst.sabunnm ASC, cust_mst.custname ASC");

            List<Map<String, Object>> rows = lower(jdbc.queryForList(sql.toString(), p));
            Map<String, Object> res = ok(rows);
            if (rows.size() > MAX_ROWS) {
                rows.remove(rows.size() - 1);
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
        logger.error("mes0105 error", e);
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
