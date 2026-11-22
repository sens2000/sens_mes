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
 * mes3402 지류 발주 (PB mes3402 조회 화면 — 요청된 지류 중 아직 발주 안 한 것)
 *  - /mes3402.do         화면
 *  - /mes3402/list       [조 회] (JSON)
 *  - /mes3402/order      [발주조회] ip01_dtl (JSON)
 *  지질 찾기는 mes3401 의 /mes3401/paper 를 같이 씀
 *  거래처 찾기는 mes0201 의 /mes0201/cust 를 같이 씀
 *
 *  수주번호가 있으면 그것으로만 조회 (다른 검색 조건 무시, 기본 조건은 유지)
 */
@Controller
public class mes3402_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3402_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_dtl.jpno as mstjpno, mc20_dtl.jpno, mc20_dtl.seq, mc20_dtl.gubun, mc20_dtl.cdate, mc20_dtl.procdate, " +
        "       mc20_dtl.plandate, mc20_dtl.orderdate, mc20_dtl.planseq, mc20_dtl.custcd, mc20_dtl.workkind, " +
        "       mc20_dtl.size, mc20_dtl.jepmno as paperjepmno, " +
        "       mc20_dtl.qty - mc20_dtl.paperjego as qty, " +                       // 실수량 (재고 뺀 것)
        "       mc20_dtl.price, mc20_dtl.inqty, mc20_dtl.remk, mc20_dtl.planremk, mc20_dtl.injpno, " +
        "       mc20_mst.papmkind, mc20_mst.orderno, jepm_mst.jepmcd as prodjepmcd, mc20_mst.company, " +
        "       mc20_mst.jepmnm as prodjepmnm, mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, " +   // qty 와 이름이 겹쳐서 별칭
        "       mc20_mst.deliverydate, " +
        "       paper_jepm_mst.jepmnm as paperjepmnm, paper_jepm_mst.unit as paperunit, paper_jepm_mst.danwi as paperdanwi, " +
        "       paper_info.cutwidth, paper_info.cutlength, paper_info.sizejul, paper_info.sizebu, " +
        "       paper_info.dofront, paper_info.doback, " +
        "       (select okper   from mc20_dtl d2 where d2.jpno = mc20_mst.jpno and d2.seq = 1 + 100) as ok, " +
        "       (select lossper from mc20_dtl d2 where d2.jpno = mc20_mst.jpno and d2.seq = 1 + 100) as loss, " +
        "       mc20_dtl.okper, mc20_dtl.lossper, mc20_dtl.editper, mc20_dtl.paperjego, mc20_dtl.orderremk, " +
        "       mc20_dtl.incustcd, mc20_dtl.proc1, " +
        "       (select custname from cust_mst where custcd = mc20_dtl.incustcd) as incustname, " +
        "       (select top 1 orderremk + ' 전:' + convert(char(3), prodcnt) + ' 후:' + convert(char(3), docnt) + ' ' + remk " +
        "          from mc20_dtl flow_dtl " +
        "         where flow_dtl.jpno = mc20_dtl.jpno and flow_dtl.flow like '%방습%' and flow_dtl.gubun = '외주') as proofcont, " +
        "       'N' as selchk " +
        "  FROM mc20_dtl, mc20_mst, jepm_mst, paper_info, jepm_mst paper_jepm_mst " +
        " WHERE mc20_mst.jpno = mc20_dtl.jpno " +
        "   and mc20_dtl.jpno = paper_info.jpno " +
        "   and paper_info.seq = mc20_dtl.seq " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_dtl.jepmno = paper_jepm_mst.jepmno " +
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and mc20_dtl.gubun = '지류' " +
        "   and mc20_mst.ok1 = '결재' " +
        "   and mc20_dtl.proc1 = '요청' " +
        "   and mc20_mst.company = :company " +
        // [조 회] 조건 : 요청은 했고, 아직 발주 안 한 것
        "   and isnull(mc20_dtl.injpno,'') = '' " +
        "   and trim(isnull(mc20_dtl.orderdate,'')) <> '' " +                      // PB: orderdate <> '        '
        "   and mc20_dtl.proc1 <> '통과' " +
        "   and trim(isnull(mc20_dtl.plandate,'')) = '' ";                         // PB: plandate = '        '

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3402.do")
    public String mes3402(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3402");
        return "mes3402";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3402/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));

            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                // 수주번호 단독 (다른 검색 조건 무시)
                sql.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                // 거래처
                eq(sql, p, "mc20_mst.custcd", "custcd", v(req, "custcd"));

                // 지질 : 목록에서 고르면 코드 일치, 직접 입력하면 이름 포함
                String paperno = v(req, "paperjepmno"), papernm = v(req, "papernm");
                if (!isEmpty(paperno)) {
                    eq(sql, p, "mc20_dtl.jepmno", "paperjepmno", paperno);
                } else if (!isEmpty(papernm)) {
                    sql.append(" AND paper_jepm_mst.jepmnm LIKE :papernm");
                    p.addValue("papernm", "%" + papernm + "%");
                }

                // 전체 / 제품 / 상품
                eqNotAll(sql, p, "jepm_mst.test", "test", v(req, "test"));

                // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
                String jepmnm = v(req, "jepmnm");
                if (!isEmpty(jepmnm)) {
                    String[] a = jepmnm.split("/", 2);
                    String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                    if (!s1.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                    if (!s2.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
                }
            }

            sql.append(" ORDER BY paperjepmnm, mc20_mst.deliverydate, prodjepmnm, mc20_dtl.jpno, mc20_dtl.seq");

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
    // 발주조회 (ip01_dtl)
    // ------------------------------------------------------------------
    private static final String ORDER_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       (select custname from cust_mst where cust_mst.custcd = ip01_dtl.custcd) as custname, " +
        "       trim(jepm_mst.jepmnm) as jepmnm, jepm_mst.kind, jepm_mst.jepmcd, jepm_mst.danwi, " +
        "       ip01_dtl.company, ip01_dtl.jpno, ip01_dtl.seq, ip01_dtl.cdate, ip01_dtl.prdate, ip01_dtl.prtime, " +
        "       ip01_dtl.gubun, ip01_dtl.custcd, ip01_dtl.jepmno, ip01_dtl.unit, ip01_dtl.size, ip01_dtl.ordersize, " +
        "       ip01_dtl.okper, ip01_dtl.lossper, ip01_dtl.editper, ip01_dtl.paperjego, ip01_dtl.qty, " +
        "       ip01_dtl.subulunit, ip01_dtl.price, ip01_dtl.amt, ip01_dtl.remk, ip01_dtl.incustcd, " +
        "       (select custname from cust_mst where cust_mst.custcd = ip01_dtl.incustcd) as incustname, " +
        "       ip01_dtl.inflow, ip01_dtl.procchk, ip01_dtl.procdate, ip01_dtl.procprtime, ip01_dtl.chk, " +
        "       ip01_dtl.proc1, ip01_dtl.proc2, ip01_dtl.proc3, " +
        "       mc20_mst.orderno, mc20_mst.jpno as mstjpno, mc20_mst.papmkind, mc20_mst.jepmnm as prodjepmnm, " +
        "       'N' as prtchk " +
        "  FROM jepm_mst, ip01_dtl, mc20_mst " +
        " WHERE jepm_mst.jepmno = ip01_dtl.jepmno " +
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and ip01_dtl.mcjpno = mc20_mst.jpno " +
        "   and mc20_mst.company = :company ";

    @RequestMapping(value = "/mes3402/order", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> order(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(ORDER_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));

            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                // 수주번호 단독 (다른 검색 조건 무시)
                sql.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                // 발주처
                eq(sql, p, "ip01_dtl.custcd", "ordcustcd", v(req, "ordcustcd"));

                // 전체 / 제품 / 상품  (PB 조건 그대로 : 지류 품목의 jepm_mst.test)
                eqNotAll(sql, p, "jepm_mst.test", "test", v(req, "test"));

                // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
                String jepmnm = v(req, "jepmnm");
                if (!isEmpty(jepmnm)) {
                    String[] a = jepmnm.split("/", 2);
                    String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                    if (!s1.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                    if (!s2.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
                }

                // 발주일 / 입고예정일
                String dc = "cdate".equals(v(req, "dateKind")) ? "ip01_dtl.cdate" : "ip01_dtl.prdate";
                String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                    sql.append(" AND ").append(dc).append(" BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }
            }

            sql.append(" ORDER BY ip01_dtl.prdate DESC, custname, ip01_dtl.jpno, ip01_dtl.seq");

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
        logger.error("mes3402 error", e);
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
