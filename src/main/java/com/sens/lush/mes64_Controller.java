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
 * mes64 외주 출고 (PB mes64 조회 화면)
 *  - /mes64.do         화면
 *  - /mes64/list       조회 (JSON)  view=reg 등록일 보기 / view=cust 외주처 보기
 *
 *  출고번호 · 담당 · 관리번호 는 앞글자 검색 (like '값%')
 */
@Controller
public class mes64_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes64_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    /** 등록일 보기 */
    private static final String REG_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       m.company, m.jpno, m.carno, m.manager, m.outdate, m.indate, m.remk, m.rtnmsg, " +
        "       m.proc1, m.proc2, m.proc3, m.prdate, m.prtime, m.pruser, p.jepmnm, d.flow " +
        "  FROM woiju_mst m " +
        "  JOIN woiju_dtl d ON m.jpno = d.jpno " +
        "  JOIN jepm_mst p  ON d.jepmno = p.jepmno " +
        " WHERE 1 = 1 ";

    /** 외주처 보기 (아직 입고로 넘어가지 않은 출고 줄 : outjpno = '').
     *  이름이 겹치는 woiju_dtl.jpno → dtl_jpno, woiju_dtl.remk(외주처비고) → dtl_remk */
    private static final String CUST_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       woiju_mst.company, woiju_mst.jpno, woiju_dtl.jpno as dtl_jpno, woiju_dtl.seq, woiju_mst.carno, " +
        "       woiju_mst.manager, woiju_dtl.outdate, woiju_dtl.outjpno, woiju_dtl.outseq, woiju_mst.remk, " +
        "       woiju_mst.rtnmsg, woiju_mst.prdate, woiju_mst.prtime, trim(cust_mst.custname) as custname, " +
        "       woiju_dtl.orderno, woiju_dtl.flow, jepm_mst.jepmnm, woiju_dtl.qty, woiju_dtl.remk as dtl_remk, " +
        "       '입고' as temp, " +
        "       (select sum(inqty) from woiju_dtl as wi where wi.outjpno = woiju_dtl.jpno and wi.outseq = woiju_dtl.seq) as inqty, " +
        "       (select list(indate) from woiju_dtl as wd where wd.outjpno = woiju_dtl.jpno and wd.outseq = woiju_dtl.seq) as indate, " +
        "       woiju_dtl.in_chk " +
        "  FROM woiju_mst, woiju_dtl " +
        "       left outer join mc20_mst on mc20_mst.jpno = woiju_dtl.mstjpno " +
        "       left outer join cust_mst on woiju_dtl.custcd = cust_mst.custcd " +
        "       left outer join jepm_mst on woiju_dtl.jepmno = jepm_mst.jepmno " +
        " WHERE woiju_mst.jpno = woiju_dtl.jpno " +
        "   and woiju_dtl.outjpno = '' ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes64.do")
    public String mes64(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes64");
        return "mes64";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes64/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            checkLogin(session);
            boolean cust = "cust".equals(v(req, "view"));
            String m = cust ? "woiju_mst" : "m";
            StringBuilder sql = new StringBuilder(cust ? CUST_SQL : REG_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource();

            like(sql, p, m + ".carno",   "carno",   v(req, "carno"));      // 출고번호
            like(sql, p, m + ".manager", "manager", v(req, "manager"));    // 담당

            if (cust) {
                like(sql, p, "woiju_dtl.orderno", "orderno", v(req, "orderno"));   // 관리번호
                eqNotAll(sql, p, "woiju_dtl.in_chk", "inchk", v(req, "inchk"));    // 외주 / 완료 
            }

            // 출고일
            String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
            if (f.length() == 8 && t.length() == 8) {
                if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                sql.append(" AND ").append(m).append(".outdate BETWEEN :f AND :t");
                p.addValue("f", f).addValue("t", t);
            }

            if (cust) sql.append(" ORDER BY woiju_mst.prdate, woiju_mst.carno, woiju_dtl.seq");
            else      sql.append(" ORDER BY m.prdate, m.carno, d.seq");

            logger.info("mes64 list view=" + (cust ? "cust" : "reg") + " params=" + p.getValues());
            logger.info("mes64 list sql=" + sql);
            List<Map<String, Object>> rows = lower(jdbc.queryForList(sql.toString(), p));
            logger.info("mes64 list rows=" + rows.size());
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

    /** 앞글자 검색 : col like '값%' */
    private static void like(StringBuilder sql, MapSqlParameterSource p, String col, String name, String val) {
        if (isEmpty(val)) return;
        sql.append(" AND ").append(col).append(" LIKE :").append(name);
        p.addValue(name, val + "%");
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
        logger.error("mes64 error", e);
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
