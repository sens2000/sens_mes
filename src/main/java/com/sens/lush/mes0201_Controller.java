package com.sens.lush;

import java.sql.SQLException;
import java.util.ArrayList;
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
 * mes0201 사양서관리 (PB 사양서관리-서울 조회 화면)
 *  - /mes0201.do         화면
 *  - /mes0201/list       조회 (JSON)
 *  - /mes0201/cust       매출처 찾기 (JSON)
 *  - /mes0201/dept       매출처 부서 목록 (JSON)
 *
 * 검색 조건은 PB 처럼 문자열을 이어붙이지 않고 :이름 파라미터로 넘김 (따옴표·SQL 주입 방지)
 */
@Controller
public class mes0201_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";   // 세션 USER 의 회사코드 키

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes0201_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       cust_mst.custname, cust_dtl.custsectname, " +
        "       mc20_mst.jpno, mc20_mst.mstjpno, mc20_mst.amt, mc20_mst.remk, " +
        "       mc20_mst.prdate, mc20_mst.prtime, mc20_mst.pruser, mc20_mst.custcd, mc20_mst.jepmno, " +
        "       jepm_mst.test, jepm_mst.kind AS jepmkind, jepm_mst.jepmcd, " +   // mc20_mst.kind 와 이름이 겹쳐서 별칭
        "       mc20_mst.wonjepmno, wonjepm_mst.wonjepmcd, wonjepm_mst.wonjepmnm, " +
        "       mc20_mst.jepmnm, mc20_mst.sabun, mc20_mst.sabunnm, mc20_mst.deliverydate, " +
        "       mc20_mst.orderno, mc20_mst.pocode, " +
        "       (if papmkind <> '재작업' and (mc20_mst.kind1 = '생산' or mc20_mst.kind1 = '') then mc20_mst.qty else 0 endif) prodqty, " +
        "       (if papmkind <> '재작업' and  mc20_mst.kind1 = '출고' then mc20_mst.qty else 0 endif) outqty, " +
        "       (if papmkind =  '재작업' and (mc20_mst.kind1 = '생산' or mc20_mst.kind1 = '') then mc20_mst.qty else 0 endif) reprodqty, " +
        "       (if papmkind =  '재작업' and  mc20_mst.kind1 = '출고' then mc20_mst.qty else 0 endif) reoutqty, " +
        "       mc20_mst.addqty, mc20_mst.price, mc20_mst.restqty, " +
        "       mc20_mst.ok1, mc20_mst.ok2, mc20_mst.ok3, mc20_mst.kind, mc20_mst.kind1, " +
        "       mc20_mst.papmkind, mc20_mst.paperjpno, mc20_mst.makejpno, mc20_mst.outjpno, " +
        "       mc20_mst.cdate, mc20_mst.stat, mc20_mst.gubun, mc20_mst.taxgubun, mc20_mst.designer, " +
        "       mc20_mst.sheet_chk, mc20_mst.call_date, mc20_mst.datagubun as datagubun, mc20_mst.biddate, " +
        "       (if mc20_mst.bill_call = 'Y' then '요청' else '' endif) bill_call, " +
        "       (select sum(deliveryqty) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makeqty, " +
        "       (select list(deliverydate) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makedate, " +
        "       isnull((select jpno from mc20_file where mc20_file.jpno = mc20_mst.jpno),'') as filejpno, " +
        "       (select list(trim(distinct tax_dtl.cdate)) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxstat, " +
        "       (select sum(tax_dtl.amt) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxamt, " +
        "       isnull((select sum(tax_dtl.qty) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno),0) as taxrestqty, " +
        "       mc20_mst.qty as qty, " +
        "       (select sizebu  from paper_info where paper_info.jpno = mc20_mst.jpno and paper_info.seq = 1) as sizebu, " +
        "       (select sizejul from paper_info where paper_info.jpno = mc20_mst.jpno and paper_info.seq = 1) as sizejul, " +
        "       (select count(*) from mc20_dtl where mc20_dtl.jpno = mc20_mst.jpno and mc20_dtl.seq <> 1) as gubunqty " +
        "  FROM cust_mst, cust_dtl, mc20_mst, " +
        "       jepm_mst left outer join wonjepm_mst on wonjepm_mst.wonjepmno = mc20_mst.wonjepmno " +
        " WHERE ( mc20_mst.jepmno = jepm_mst.jepmno ) " +
        "   and ( cust_mst.custcd = mc20_mst.custcd ) " +
        "   and ( cust_mst.custcd = cust_dtl.custcd ) " +
        "   and ( mc20_mst.chk = 'Y' ) " +
        "   and ( mc20_mst.custseqcd = cust_dtl.custseqcd ) " +
        "   and ( mc20_mst.company = :company ) " +
        "   and ( mc20_mst.kind <> '교정' ) ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201.do")
    public String mes0201(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes0201");
        return "mes0201";
    }

    // ------------------------------------------------------------------
    // 사양서 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));

            // 단독 검색 (기간 포함 다른 조건 모두 무시)
            //  1) 부코드가 있으면 부코드로만
            //  2) 관리번호 / 원코드 / SET번호 / POCODE / 물류코드 가 있으면 그것으로만
            String bucode = v(req, "bucode");
            String key    = v(req, "keyText");
            if (!isEmpty(bucode)) {
                sql.append(" AND jepm_mst.custjepmcd LIKE :bucode");
                p.addValue("bucode", bucode + "%");
            } else if (!isEmpty(key)) {
                String kk = v(req, "keyKind");
                if      ("orderno".equals(kk))   { sql.append(" AND mc20_mst.orderno LIKE :key");   p.addValue("key", "%" + key + "%"); }
                else if ("wonjepmcd".equals(kk)) { sql.append(" AND wonjepm_mst.wonjepmcd = :key"); p.addValue("key", key); }
                else if ("setno".equals(kk))     { sql.append(" AND mc20_mst.setno = :key");        p.addValue("key", key); }
                else if ("pocode".equals(kk))    { sql.append(" AND mc20_mst.pocode = :key");       p.addValue("key", key); }
                else if ("outjpno".equals(kk))   { sql.append(" AND mc20_mst.outjpno = :key");      p.addValue("key", key); }
                else throw new IllegalArgumentException("검색 구분을 확인하세요.");
            } else {

            // 등록일 / 수주일 / 납품예정일
            Map<String, String> dateCol = new HashMap<String, String>();
            dateCol.put("prdate",       "mc20_mst.prdate");
            dateCol.put("cdate",        "mc20_mst.cdate");
            dateCol.put("deliverydate", "mc20_mst.deliverydate");
            String dc = dateCol.get(v(req, "dateKind"));
            String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
            if (dc != null && f.length() == 8 && t.length() == 8) {
                if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                sql.append(" AND ").append(dc).append(" BETWEEN :f AND :t");
                p.addValue("f", f).addValue("t", t);
            }

            // 담당 : 이름 포함 검색 또는 사번 일치 / 매출처 / 부서
            String sabun = v(req, "sabun");
            if (!isEmpty(sabun)) {
                sql.append(" AND ( mc20_mst.sabunnm LIKE :sabunnm OR mc20_mst.sabun = :sabun )");
                p.addValue("sabunnm", "%" + sabun + "%").addValue("sabun", sabun);
            }
            eq(sql, p, "mc20_mst.custcd",    "custcd",    v(req, "custcd"));
            eq(sql, p, "mc20_mst.custseqcd", "custseqcd", v(req, "custseqcd"));

            // 상태 / 생산 / 제품·상품 (전체면 조건 없음)
            eqNotAll(sql, p, "mc20_mst.ok1",   "ok1",   v(req, "ok1"));
            eqNotAll(sql, p, "mc20_mst.kind1", "kind1", v(req, "kind1"));
            eqNotAll(sql, p, "jepm_mst.test",  "test",  v(req, "test"));

            // 제품분류
            eq(sql, p, "jepm_mst.kind", "kind", v(req, "kind"));

            // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
            String jepmnm = v(req, "jepmnm");
            if (!isEmpty(jepmnm)) {
                String[] a = jepmnm.split("/", 2);
                String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                if (!s1.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                if (!s2.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
            }

            // 재작업 / 불량 (둘 다 체크하면 둘 중 하나라도 해당)
            boolean rework = "Y".equals(v(req, "rework")), bad = "Y".equals(v(req, "bad"));
            if (rework && bad) sql.append(" AND ( mc20_mst.papmkind = '재작업' OR papmorderno <> '' )");
            else if (rework)   sql.append(" AND mc20_mst.papmkind = '재작업'");
            else if (bad)      sql.append(" AND papmorderno <> ''");

            }   // 단독 검색이 아닐 때만 적용

            sql.append(" ORDER BY mc20_mst.prdate DESC, mc20_mst.orderno DESC");
            
logger.info("Start Page: mes0201 sql=" + sql.toString());

            List<Map<String, Object>> rows = lower(jdbc.queryForList(sql.toString(), p));

            Map<String, Object> res = ok(rows);
            if (rows.size() > MAX_ROWS) {
                rows.remove(rows.size() - 1);
                res.put("msg", MAX_ROWS + "건까지만 표시합니다. 조건을 좁혀 주세요.");
            }
logger.info("Start Page: mes0201 res=" + res);
            return res;
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 매출처 찾기
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201/cust", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> cust(@RequestParam(value = "q", defaultValue = "") String q, HttpSession session) {
        try {
            checkLogin(session);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("q", "%" + q.trim() + "%");
            return ok(lower(jdbc.queryForList(
                "SELECT TOP 50 custcd, custname FROM cust_mst WHERE custname LIKE :q ORDER BY custname", p)));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 매출처 부서
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201/dept", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> dept(@RequestParam(value = "custcd", defaultValue = "") String custcd, HttpSession session) {
        try {
            checkLogin(session);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("custcd", custcd.trim());
            return ok(lower(jdbc.queryForList(
                "SELECT custseqcd, custsectname FROM cust_dtl WHERE custcd = :custcd ORDER BY custsectname", p)));
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
        logger.error("mes0201 error", e);
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
