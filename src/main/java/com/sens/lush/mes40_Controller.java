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
 * mes40 납품 (PB mes40 조회 화면)
 *  - /mes40.do         화면
 *  - /mes40/list       조회 (JSON)
 *  매출처 찾기는 mes0201 의 /mes0201/cust 를 같이 씀
 *
 *  수주번호 / 원코드 / 제품명 은 매출처 · 기간과 같이 적용 (제품명은 "/" 로 앞글자/포함글자)
 *  mc20_mst 와 delivery_dtl 에 같은 이름이 많아 mc20_mst 쪽은 mst_ 별칭
 *  (mst_jpno, mst_orderno=관리번호, mst_deliverydate=납품예정, mst_remk, mst_custcd, mst_jepmno)
 */
@Controller
public class mes40_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes40_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       cust_mst.custname, cust_dtl.custsectname, " +
        "       mc20_mst.jpno as mst_jpno, mc20_mst.remk as mst_remk, mc20_mst.custcd as mst_custcd, " +
        "       (select jepmcd from jepm_mst where jepm_mst.jepmno = mc20_mst.jepmno) as jepmcd, " +
        "       mc20_mst.jepmno as mst_jepmno, mc20_mst.jepmnm, mc20_mst.deliverydate as mst_deliverydate, " +
        "       mc20_mst.wonorderno, mc20_mst.orderno as mst_orderno, mc20_mst.qty, " +
        "       (if (select price from mc20_mst where delivery_dtl.orderno = mc20_mst.orderno and jepminfo = '제품') = 0 " +
        "        then (select price from mc20_mst where substr(delivery_dtl.orderno,1,8) = mc20_mst.orderno and jepminfo = '제품') " +
        "        else (select price from mc20_mst where delivery_dtl.orderno = mc20_mst.orderno and jepminfo = '제품') endif) as price, " +
        "       mc20_mst.amt, mc20_mst.cdate, mc20_mst.pocode, mc20_mst.outjpno, " +
        "       delivery_dtl.company, delivery_dtl.jpno, delivery_dtl.orderno, delivery_dtl.prsabun, delivery_dtl.prsabunnm, " +
        "       delivery_dtl.custcd, delivery_dtl.custseqcd, delivery_dtl.jepmno, delivery_dtl.orderdate, delivery_dtl.orderqty, " +
        "       delivery_dtl.deliverydate, " +
        "       (select sum(deliveryqty) from delivery_dtl dd where dd.orderno = delivery_dtl.orderno) as deliverysum, " +
        "       isnull((select sum(deliveryqty) from delivery_dtl dd where dd.orderno = delivery_dtl.orderno " +
        "               and dd.jpno <> delivery_dtl.jpno),0) as exceptdeliverysum, " +
        "       (select sum(qty) from mc20_plan where mc20_plan.mcjpno = mc20_mst.jpno and mc20_plan.proc3 = '오산지함' " +
        "               and mc20_mst.papmkind <> '재작업') as ksqty, " +
        "       delivery_dtl.deliveryqty, delivery_dtl.deliveryplace, delivery_dtl.procdate, delivery_dtl.remk, " +
        "       delivery_dtl.mstjpno, delivery_dtl.proc1, delivery_dtl.proc2, delivery_dtl.proc3, " +
        "       delivery_dtl.prdate, delivery_dtl.prtime, wonjepm_mst.wonjepmcd, " +
        "       isnull(delivery_auth.jpno,'') as delivery_auth_jpno, isnull(delivery_list.listjpno,'') as delivery_list_jpno, " +
        "       mc20_mst.deliveryok " +
        "  FROM delivery_dtl, mc20_mst " +
        "       left outer join cust_mst      on cust_mst.custcd = mc20_mst.custcd " +
        "       left outer join cust_dtl      on delivery_dtl.custcd = cust_dtl.custcd and delivery_dtl.custseqcd = cust_dtl.custseqcd " +
        "       left outer join delivery_auth on delivery_auth.jpno = delivery_dtl.jpno " +
        "       left outer join delivery_list on delivery_list.jpno = delivery_dtl.jpno " +
        "       left outer join wonjepm_mst   on wonjepm_mst.wonjepmno = mc20_mst.wonjepmno " +
        " WHERE delivery_dtl.mstjpno = mc20_mst.jpno " +
        "   and delivery_dtl.company = :company ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes40.do")
    public String mes40(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes40");
        return "mes40";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes40/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));

            // 수주번호 / 원코드 / 제품명 : 다른 조건과 같이 적용
            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                String kind = v(req, "keyKind");
                if ("wonjepmcd".equals(kind)) {
                    sql.append(" AND wonjepm_mst.wonjepmcd = :key");
                    p.addValue("key", key);
                } else if ("jepmnm".equals(kind)) {
                    // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
                    String[] a = key.split("/", 2);
                    String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                    if (!s1.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                    if (!s2.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
                } else {
                    sql.append(" AND delivery_dtl.orderno = :key");
                    p.addValue("key", key);
                }
            }

            eq(sql, p, "delivery_dtl.custcd", "custcd", v(req, "custcd"));     // 매출처

            // 등록일 / 납품일
            String col = "deliverydate".equals(v(req, "dateKind")) ? "delivery_dtl.deliverydate" : "delivery_dtl.prdate";
            String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
            if (f.length() == 8 && t.length() == 8) {
                if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                sql.append(" AND ").append(col).append(" BETWEEN :f AND :t");
                p.addValue("f", f).addValue("t", t);
            }

            sql.append(" ORDER BY delivery_dtl.prdate, delivery_dtl.prtime");

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
        logger.error("mes40 error", e);
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
