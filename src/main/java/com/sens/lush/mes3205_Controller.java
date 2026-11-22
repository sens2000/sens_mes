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
 * mes3205 수주 확인 목록 — 조회
 *  - /mes3205.do       화면
 *  - /mes3205/list     조회 (JSON)
 *  - 매출처 찾기는 mes0201 것을 같이 씀 (/mes0201/cust)
 *
 *  기본 조건 : 회사(세션 COMPANY), chk = 'Y'
 *  수주번호가 있으면 수주번호로만 조회 (다른 조건 무시)
 *  아니면 등록일 / 담당 / 매출처 / 상태(kind) / 수주확인(ok1) / 제품명
 *  생산(proc_chk) · 발주(paper_in) 는 화면에서 '생산' · '발주' 로 표시
 *  jepm_mst.kind(분류) 는 mc20_mst.kind(상태) 와 이름이 겹쳐서 jepmkind 로 별칭
 */
@Controller
public class mes3205_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";
    private static final String USER_COMPANY = "COMPANY";   // 세션 USER 의 회사코드 키

    private static final int MAX_ROWS = 5000;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3205_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       cust_mst.custname, cust_dtl.custsectname, " +
        "       mc20_mst.jpno, mc20_mst.amt, mc20_mst.remk, mc20_mst.prdate, mc20_mst.prtime, mc20_mst.pruser, " +
        "       mc20_mst.custcd, mc20_mst.jepmno, " +
        "       jepm_mst.test, jepm_mst.kind as jepmkind, jepm_mst.jepmcd, " +
        "       mc20_mst.jepmnm, mc20_mst.sabun, mc20_mst.sabunnm, mc20_mst.deliverydate, mc20_mst.orderno, mc20_mst.qty, " +
        "       (if mc20_mst.papmkind = '재작업' then mc20_mst.qty else 0 endif) as reqty, " +
        "       mc20_mst.addqty, mc20_mst.price, mc20_mst.restqty, mc20_mst.ok1, mc20_mst.ok1 as saveok, mc20_mst.ok2, mc20_mst.ok3, " +
        "       mc20_mst.paperjpno, mc20_mst.makejpno, mc20_mst.outjpno, mc20_mst.cdate, mc20_mst.stat, " +
        "       mc20_mst.designer, mc20_mst.codeno, " +
        "       wonjepm_mst.wonjepmcd, wonjepm_mst.wonjepmnm, " +
        "       isnull((select top 1 jpno from mc20_plan where mcjpno = mc20_mst.jpno), '') as proc_chk, " +
        "       isnull((select top 1 jpno from ip01_dtl  where mcjpno = mc20_mst.jpno), '') as paper_in, " +
        "       (select sum(qty) from mc20_plan where mc20_plan.mcjpno = mc20_mst.jpno and mc20_plan.proc3 = '오산지함' and mc20_mst.papmkind <> '재작업') as ksqty, " +
        "       (select sum(deliveryqty) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makeqty, " +
        "       (select list(deliverydate) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makedate, " +
        "       (if mc20_mst.kind1 = '비축분' and mc20_mst.jepminfo <> '재고' then " +
        "            mc20_mst.qty - isnull((select sum(mc_jego.qty) from mc20_mst mc_jego where mc_jego.mstjpno = mc20_mst.jpno), 0) " +
        "        else 0 endif) as restjego, " +
        "       (select list(trim(distinct tax_dtl.cdate)) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxstat, " +
        "       (select sum(tax_dtl.qty) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxrestqty, " +
        "       isnull((select jpno from mc20_file where mc20_file.jpno = jepm_mst.jepmno and mc20_file.seq = 0), '') as filejpno, " +
        "       mc20_mst.kind, mc20_mst.kind1, mc20_mst.papmkind, " +
        "       (select sum(tax_dtl.amt) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxamt, " +
        "       left(mc20_mst.lotno, 2) as lotno, substr(mc20_mst.lotno, 3, 2) as lotnosub " +
        "  FROM cust_mst, cust_dtl, mc20_mst, jepm_mst " +
        "       left outer join wonjepm_mst on wonjepm_mst.wonjepmno = mc20_mst.wonjepmno " +
        " WHERE ( mc20_mst.jepmno = jepm_mst.jepmno ) " +
        "   and ( cust_mst.custcd = mc20_mst.custcd ) " +
        "   and ( cust_mst.custcd = cust_dtl.custcd ) " +
        "   and ( mc20_mst.chk = 'Y' ) " +
        "   and ( mc20_mst.custseqcd = cust_dtl.custseqcd ) " +
        "   and ( mc20_mst.company = :company ) ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3205.do")
    public String mes3205(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3205");
        return "mes3205";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3205/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));

            // 수주번호가 있으면 수주번호로만 조회 (다른 조건 무시)
            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                sql.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                // 등록일
                String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                    sql.append(" AND mc20_mst.prdate BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }

                // 담당 : 이름 포함 검색 또는 사번 일치
                String sabun = v(req, "sabun");
                if (!isEmpty(sabun)) {
                    sql.append(" AND ( mc20_mst.sabunnm LIKE :sabunnm OR mc20_mst.sabun = :sabun )");
                    p.addValue("sabunnm", "%" + sabun + "%").addValue("sabun", sabun);
                }

                // 매출처
                eq(sql, p, "mc20_mst.custcd", "custcd", v(req, "custcd"));

                // 상태(kind) / 수주확인(ok1) — 전체면 조건 없음
                eqNotAll(sql, p, "mc20_mst.kind", "kind", v(req, "kind"));
                eqNotAll(sql, p, "mc20_mst.ok1",  "ok1",  v(req, "ok1"));

                // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
                String jepmnm = v(req, "jepmnm");
                if (!isEmpty(jepmnm)) {
                    String[] a = jepmnm.split("/", 2);
                    String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                    if (!s1.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                    if (!s2.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
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
        if (!(session.getAttribute(SESSION_USER) instanceof Map))
            throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        Object v = ((Map) session.getAttribute(SESSION_USER)).get(USER_COMPANY);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalArgumentException("로그인 정보(회사코드)가 없습니다. 세션 USER 의 " + USER_COMPANY + " 키를 확인하세요.");
        return v.toString().trim();
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
        logger.error("mes3205 error", e);
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
