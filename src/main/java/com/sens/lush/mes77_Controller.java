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
 * mes77 재작업 (PB mes77 조회 화면)
 *  - /mes77.do         화면
 *  - /mes77/list       조회 (JSON)
 *
 *  수주번호가 있으면 등록일 무시 (회사 · 재작업 · 생산 조건은 유지)
 *  papm_mst.qty 는 mc20_mst.qty 와 이름이 겹쳐서 papm_qty (원생산수량)
 */
@Controller
public class mes77_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes77_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       papm_mst.prdate, mc20_mst.wonorderno, mc20_mst.orderno, mc20_mst.jepmnm, mc20_mst.qty, " +
        "       mc20_mst.cdate, mc20_mst.deliverydate, mc20_mst.jpno, " +
        "       isnull(mc20_file.jpno,'') as filejpno, isnull(mc20_file.filename,'') as filename, " +
        "       isnull(papm_mst.jpno,'') as papm_mst_jpno, isnull(papm_mst.prdate,'') as papm_mst_prdate, " +
        "       papm_mst.qty as papm_qty, papm_mst.reqty, papm_mst.proddate, papm_mst.outdate, " +
        "       papm_mst.papmflow, papm_mst.trouble, mc20_mst.pruser as pruser, " +
        "       (if mc20_file.jpno <> '' then '첨부' else '' endif) as file_chk " +
        "  FROM mc20_mst " +
        "       left outer join papm_mst  on papm_mst.mstjpno = mc20_mst.jpno " +
        "       left outer join mc20_file on mc20_file.jpno = papm_mst.jpno " +
        " WHERE mc20_mst.chk = 'Y' " +
        "   and mc20_mst.company = :company " +
        "   and mc20_mst.papmkind = '재작업' " +
        "   and mc20_mst.kind1 in ('','생산') ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes77.do")
    public String mes77(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes77");
        return "mes77";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes77/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));

            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                // 수주번호 단독 (등록일 무시)
                sql.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                    sql.append(" AND mc20_mst.prdate BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }
            }

            sql.append(" ORDER BY mc20_mst.prdate DESC, mc20_mst.orderno DESC");

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
        logger.error("mes77 error", e);
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
