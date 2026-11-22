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
 * mes33 결재 사양서 목록 — 조회
 *  - /mes33.do       화면
 *  - /mes33/list     조회 (JSON)
 *  - 매출처 찾기 / 부서 목록은 mes0201 것을 같이 씀 (/mes0201/cust, /mes0201/dept)
 *
 *  기본 조건 : 회사(세션 COMPANY), chk = 'Y', ok1 = '결재', jepminfo = '제품', kind <> '교정'
 *  단독 검색 (기간 포함 다른 조건 무시)
 *   1) 부코드가 있으면 부코드로만
 *   2) 수주번호 / 원코드 가 있으면 그것으로만
 *  재작업 · 불량 · 비축 체크는 OR 로 연결
 *  jepm_mst.kind(분류) 는 mc20_mst.kind(구분) 와 이름이 겹쳐서 jepmkind 로 별칭
 */
@Controller
public class mes33_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";
    private static final String USER_COMPANY = "COMPANY";   // 세션 USER 의 회사코드 키

    private static final int MAX_ROWS = 5000;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes33_Controller(DataSource dataSource) {
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
        "       mc20_mst.addqty, mc20_mst.price, mc20_mst.restqty, mc20_mst.ok1, mc20_mst.ok2, mc20_mst.ok3, " +
        "       mc20_mst.paperjpno, mc20_mst.makejpno, mc20_mst.outjpno, mc20_mst.cdate, mc20_mst.stat, " +
        "       mc20_mst.codeno, mc20_mst.designer, " +
        "       wonjepm_mst.wonjepmcd, wonjepm_mst.wonjepmnm, " +
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
        "       left(mc20_mst.lotno, 2) as lotno, substr(mc20_mst.lotno, 3, 2) as lotnosub, " +
        "       isnull((select jpno from mc20_file where mc20_mst.jpno = mc20_file.jpno and mc20_mst.jepminfo = '제품'), '') as filechk, " +
        "       '' as cgmstjpno, 0 as cgqty " +
        "  FROM cust_mst, cust_dtl, mc20_mst, jepm_mst " +
        "       left outer join wonjepm_mst on wonjepm_mst.wonjepmno = mc20_mst.wonjepmno " +
        " WHERE ( mc20_mst.jepmno = jepm_mst.jepmno ) " +
        "   and ( cust_mst.custcd = mc20_mst.custcd ) " +
        "   and ( cust_mst.custcd = cust_dtl.custcd ) " +
        "   and ( mc20_mst.chk = 'Y' ) " +
        "   and ( mc20_mst.custseqcd = cust_dtl.custseqcd ) " +
        "   and ( mc20_mst.ok1 = '결재' ) " +
        "   and ( mc20_mst.company = :company ) " +
        "   and ( mc20_mst.jepminfo = '제품' ) " +
        "   and ( mc20_mst.jepminfo <> '재고' ) " +
        "   and ( mc20_mst.kind <> '교정' ) ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes33.do")
    public String mes33(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes33");
        return "mes33";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes33/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));

            String bucode = v(req, "bucode");
            String key    = v(req, "keyText");
            if (!isEmpty(bucode)) {
                // 1) 부코드 단독
                sql.append(" AND jepm_mst.custjepmcd LIKE :bucode");
                p.addValue("bucode", bucode + "%");
            } else if (!isEmpty(key)) {
                // 2) 수주번호 / 원코드 단독
                if ("wonjepmcd".equals(v(req, "keyKind"))) sql.append(" AND wonjepm_mst.wonjepmcd = :key");
                else                                      sql.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                // 등록일 / 납기예정일
                String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                    String col = "deliverydate".equals(v(req, "dateKind")) ? "mc20_mst.deliverydate" : "mc20_mst.prdate";
                    sql.append(" AND ").append(col).append(" BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }

                // 담당 : 이름 포함 검색 또는 사번 일치
                String sabun = v(req, "sabun");
                if (!isEmpty(sabun)) {
                    sql.append(" AND ( mc20_mst.sabunnm LIKE :sabunnm OR mc20_mst.sabun = :sabun )");
                    p.addValue("sabunnm", "%" + sabun + "%").addValue("sabun", sabun);
                }

                // 매출처 / 거래처부서 / 제품분류
                eq(sql, p, "mc20_mst.custcd",    "custcd",    v(req, "custcd"));
                eq(sql, p, "mc20_mst.custseqcd", "custseqcd", v(req, "custseqcd"));
                eq(sql, p, "jepm_mst.kind",      "kind",      v(req, "kind"));

                // 제품·상품 / 수주확인 (전체면 조건 없음)
                eqNotAll(sql, p, "jepm_mst.test", "test", v(req, "test"));
                eqNotAll(sql, p, "mc20_mst.ok1",  "ok1",  v(req, "ok1"));

                // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
                String jepmnm = v(req, "jepmnm");
                if (!isEmpty(jepmnm)) {
                    String[] a = jepmnm.split("/", 2);
                    String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                    if (!s1.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                    if (!s2.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
                }

                // 원코드 없음 (left join 이라 원코드가 없으면 NULL — isnull 로 함께 처리)
                if ("Y".equals(v(req, "noWon"))) sql.append(" AND isnull(wonjepm_mst.wonjepmcd, '') = ''");

                // 재작업 · 불량 · 비축 — 체크한 것끼리 OR
                List<String> or = new ArrayList<String>();
                if ("Y".equals(v(req, "rework"))) or.add("mc20_mst.papmkind = '재작업'");
                if ("Y".equals(v(req, "bad")))    or.add("papmorderno <> ''");
                if ("Y".equals(v(req, "stock")))  or.add("mc20_mst.kind1 = '비축분'");
                if (!or.isEmpty()) {
                    sql.append(" AND ( ");
                    for (int i = 0; i < or.size(); i++) sql.append(i == 0 ? "" : " OR ").append(or.get(i));
                    sql.append(" )");
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
        logger.error("mes33 error", e);
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
