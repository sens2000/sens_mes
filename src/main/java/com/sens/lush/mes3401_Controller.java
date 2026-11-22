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
 * mes3401 지류 발주요청 대상 (PB mes3401 조회 화면)
 *  - /mes3401.do         화면
 *  - /mes3401/list       조회 (JSON)  mode=target [조 회] / mode=req [요청조회]
 *  - /mes3401/paper      지질 찾기 (JSON)
 *  매출처 찾기는 mes0201 의 /mes0201/cust 를 같이 씀
 *
 *  수주번호가 있으면 그것으로만 조회 (다른 검색 조건 무시, 기본 조건은 유지)
 */
@Controller
public class mes3401_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3401_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_mst.company, mc20_dtl.jpno, mc20_dtl.seq, mc20_dtl.gubun, mc20_dtl.cdate, mc20_dtl.procdate, " +
        "       mc20_dtl.orderdate, mc20_dtl.plandate, mc20_dtl.planseq, mc20_dtl.custcd, mc20_dtl.workkind, " +
        "       mc20_dtl.size, mc20_dtl.jepmno as paperjepmno, mc20_dtl.qty as dtl_qty, mc20_dtl.price, mc20_dtl.inqty, " +
        "       mc20_dtl.remk, mc20_dtl.planremk, mc20_dtl.injpno, mc20_dtl.proc1, " +
        "       mc20_mst.prdate, mc20_mst.orderno, mc20_mst.papmkind, mc20_mst.deliverydate, " +
        "       jepm_mst.jepmcd as prodjepmcd, mc20_mst.jepmnm as prodjepmnm, mc20_mst.qty as mst_qty, " +   // mc20_dtl.qty 와 이름이 겹쳐서 별칭
        "       paper_jepm_mst.jepmnm as paperjepmnm, " +
        "       paper_info.cutwidth, paper_info.cutlength, paper_info.sizejul, paper_info.sizebu, " +
        "       paper_info.dofront, paper_info.doback, " +
        "       mc20_dtl.okper, mc20_dtl.lossper, mc20_dtl.editper, mc20_dtl.paperjego, mc20_dtl.orderremk, mc20_dtl.incustcd, " +
        "       (if mc20_dtl.injpno <> '' then '발주' else '' endif) as ip_chk, " +
        "       (select custname from cust_mst where custcd = mc20_dtl.incustcd) as incustname, " +
        "       'N' as selchk " +
        "  FROM mc20_dtl, mc20_mst, jepm_mst, paper_info, jepm_mst paper_jepm_mst " +
        " WHERE mc20_mst.jpno = mc20_dtl.jpno " +
        "   and mc20_dtl.jpno = paper_info.jpno " +
        "   and paper_info.seq = mc20_dtl.seq " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_dtl.jepmno = paper_jepm_mst.jepmno " +
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and mc20_dtl.gubun = '지류' " +
        "   and mc20_mst.chk = 'Y' " +
        "   and mc20_mst.ok1 = '결재' " +
        "   and mc20_mst.company = :company ";

    /** [조 회] 에만 붙는 조건 : 아직 요청 안 하고 입고 안 된 것 */
    private static final String TARGET_WHERE =
        "   and trim(isnull(mc20_dtl.orderdate,'')) = '' " +                       // 요청 안 한 것 (PB: orderdate = '        ')
        "   and isnull((select top 1 jpno from ip01_dtl where ip01_dtl.mcjpno = mc20_dtl.jpno and ip01_dtl.mcseq = mc20_dtl.seq),'') = '' " +   // 입고 안 된 것 (PB: ipjpno = '')
        "   and mc20_mst.kind1 in ('생산','') " +
        "   and mc20_dtl.ok1 = 'N' ";                                               // 선방지

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3401.do")
    public String mes3401(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3401");
        return "mes3401";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3401/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            // mode : target = [조 회] (요청 대상), req = [요청조회] (요청한 것)
            boolean reqMode = "req".equals(v(req, "mode"));

            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("company", company(session));
            if (!reqMode) sql.append(TARGET_WHERE);

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

                if (!reqMode) {
                    // [조 회] 등록월 : yyyymm01 ~ yyyymm31
                    String ym = digits(v(req, "ym"));
                    if (ym.length() == 6) {
                        sql.append(" AND mc20_mst.prdate BETWEEN :f AND :t");
                        p.addValue("f", ym + "01").addValue("t", ym + "31");
                    }
                } else {
                    // [요청조회] 요청일 기간
                    String f = digits(v(req, "ofdate")), t = digits(v(req, "otdate"));
                    if (f.length() == 8 && t.length() == 8) {
                        if (f.compareTo(t) > 0) throw new IllegalArgumentException("요청일 시작일이 종료일보다 늦습니다.");
                        sql.append(" AND mc20_dtl.orderdate BETWEEN :f AND :t");
                        p.addValue("f", f).addValue("t", t);
                    }
                    // 전체 / 요청 / 통과
                    eqNotAll(sql, p, "mc20_dtl.proc1", "proc1", v(req, "proc1"));
                    // 전체 / 발주 / 미발주
                    String ip = v(req, "ipchk");
                    if ("발주".equals(ip))        sql.append(" AND mc20_dtl.injpno <> ''");
                    else if ("미발주".equals(ip)) sql.append(" AND isnull(mc20_dtl.injpno,'') = ''");
                }

                // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
                String jepmnm = v(req, "jepmnm");
                if (!isEmpty(jepmnm)) {
                    String[] a = jepmnm.split("/", 2);
                    String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                    if (!s1.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                    if (!s2.isEmpty()) { sql.append(" AND mc20_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
                }
            }

            if (reqMode)
                sql.append(" ORDER BY paperjepmnm, mc20_mst.orderno, prodjepmnm, mc20_dtl.jpno, mc20_dtl.seq");
            else
                sql.append(" ORDER BY mc20_mst.prdate DESC, mc20_mst.orderno, paperjepmnm, mc20_mst.deliverydate, " +
                           "prodjepmnm, mc20_dtl.jpno, mc20_dtl.seq");

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
    // 지질 찾기 (지류로 쓰인 품목만)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3401/paper", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> paper(@RequestParam(value = "q", defaultValue = "") String q, HttpSession session) {
        try {
            checkLogin(session);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("q", "%" + q.trim() + "%");
            return ok(lower(jdbc.queryForList(
                "SELECT TOP 50 jepmno, jepmnm FROM jepm_mst " +
                " WHERE jepmnm LIKE :q " +
                "   AND EXISTS (select 1 from mc20_dtl where mc20_dtl.jepmno = jepm_mst.jepmno and mc20_dtl.gubun = '지류') " +
                " ORDER BY jepmnm", p)));
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
        logger.error("mes3401 error", e);
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
