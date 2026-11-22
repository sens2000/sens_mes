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
 * mes3811 생산실적 (PB mes3811 조회 화면) — 메뉴 parm 으로 공정을 받음
 *  - /mes3811.do         화면 (메뉴 : /mes3811.do?parm=인쇄 | 스테이너만 | 라미 | 박 | 실크 | 톰슨 | 수작업 | 접착 | 지함)
 *  - /mes3811/list       조회 (JSON)  mode=plan [조 회] 실적 안 들어온 계획 (계획일) / mode=prod [생산조회] 실적 (생산일)
 *
 *  공정(proc3) : 수작업 = 회사+"수작", 스테이너만 = "스테이너", 그 외 = 회사+공정 (예 : 오산인쇄)
 *  [조 회] 실적 안 들어온 계획만 (trim(procdate) = ''), 계획일 기간
 *  [생산조회] 생산일(procdate) 기간
 *  수주번호가 있으면 생산라인 · 주야 · 기간 무시 (공정 조건은 유지)
 */
@Controller
public class mes3811_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3811_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    private static final java.util.Set<String> FLOWS = new java.util.HashSet<String>(java.util.Arrays.asList(
        "인쇄", "스테이너만", "라미", "박", "실크", "톰슨", "수작업", "접착", "지함"));

    /** 구분 (mc20_dtl_paper.proc1, 없으면 생산) — PB 의 proc1 <> '중지' 는 이 값 */
    private static final String PROC1 = "isnull((select proc1 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq),'생산')";

    /** 접착 / 지함 : 완제품 기준. 이름이 겹치는 컬럼은 별칭 (mst_qty, mst_cdate, mst_jepmno, planjpno) */
    private static final String STICK_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_mst.company, mc20_mst.jpno as mstjpno, mc20_plan.flowseq as seq, mc20_plan.paperseq as paper_info_seq, " +
        "       mc20_plan.gubun, mc20_plan.cdate, mc20_plan.custcd, '' as flowcustname, " +
        "       mc20_plan.procdate, mc20_plan.qty, mc20_plan.papmqty, mc20_plan.papertuip as plan_papertuip, mc20_plan.paperprodtuip, " +
        "       mc20_plan.worktime, mc20_mst.sabunnm, mc20_mst.orderno, mc20_mst.cdate as mst_cdate, mc20_mst.prdate, " +
        "       mc20_plan.jepmno as goodjepmno, mc20_plan.readyfrom, mc20_plan.readyto, mc20_plan.readyterm, " +
        "       mc20_plan.ftime, mc20_plan.ttime, mc20_plan.timeterm, mc20_plan.prodremk, mc20_plan.proder, " +
        "       jepm_mst.jepmcd as goodjepmcd, mc20_mst.jepmnm as goodjepmnm, " +
        "       mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.deliverydate, mc20_mst.ok2, " +
        "       mc20_plan.workflow, mc20_plan.jobseq, mc20_plan.plandate, mc20_plan.jisiqty, mc20_plan.planremk, " +
        "       mc20_plan.jpno as planjpno, mc20_plan.planseq, mc20_plan.workkind, mc20_plan.flow, mc20_plan.price, " +
        "       mc20_plan.amt as dtlamt, mc20_plan.remk, mc20_plan.proc1 as chk, mc20_plan.stick, " +
        "       mc20_plan.procprdate, mc20_plan.procprtime, mc20_plan.procpruser, " +
        "       isnull((select sum(exelqty) from paper_jego_dtl where exeletc = mc20_plan.mcjpno),0) as papertuip, " +
        "       " + PROC1 + " as proc1, " +
        "       isnull((select count(*) from mc20_ks_dtl where mc20_ks_dtl.jpno = mc20_plan.jpno),0) as kscnt, " +
        "       (select sum(deliveryqty) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makeqty, " +
        "       mc20_mst.jepmno as mst_jepmno, mc20_plan.company as incompany, mc20_plan.yarigeqty, " +
        "       isnull((select proc2 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq),'') as proc2 " +
        "  FROM mc20_plan, mc20_mst, jepm_mst " +
        " WHERE mc20_mst.jpno = mc20_plan.mcjpno " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and " + PROC1 + " <> '중지' " +
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and mc20_mst.ok1 = '결재' ";

    /** 그 외 : 지류 기준. 이름이 겹치는 컬럼은 별칭 (mstjpno, mst_qty, mst_jepmno, paper_jepmno, plan_workkind, plan_planseq) */
    private static final String PAPER_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_plan.jpno, mc20_plan.mcjpno as mstjpno, mc20_plan.flowseq as seq, mc20_plan.paperseq as paper_info_seq, " +
        "       mc20_plan.gubun, mc20_plan.cdate, mc20_plan.jepmno as mc20_plan_jepmno, " +
        "       mc20_plan.workflow, mc20_plan.worktime, mc20_plan.jobseq, mc20_plan.procdate, mc20_plan.plandate, " +
        "       mc20_plan.planseq as plan_planseq, mc20_plan.procprdate, mc20_plan.procprtime, mc20_plan.procpruser, " +
        "       mc20_plan.custcd, cust_mst.custname as flowcustname, mc20_plan.workkind as plan_workkind, mc20_plan.flow, " +
        "       mc20_plan.price, mc20_plan.jisiqty, mc20_plan.qty, mc20_plan.papmqty, " +
        "       isnull((select sum(exelqty) from paper_jego_dtl where jpno = mc20_plan.jpno),0) as papertuip, " +
        "       mc20_plan.paperprodtuip, mc20_plan.amt as dtlamt, mc20_plan.remk, mc20_plan.planremk, mc20_plan.prodremk, " +
        "       mc20_plan.proder, mc20_plan.readyfrom, mc20_plan.readyto, mc20_plan.readyterm, " +
        "       mc20_plan.ftime, mc20_plan.ttime, mc20_plan.stick, mc20_plan.timeterm, mc20_plan.proc1 as chk, " +
        "       mc20_mst.company, mc20_mst.sabunnm, mc20_mst.orderno, mc20_mst.papmkind, " +
        "       jepm_mst.jepmcd as prodjepmcd, mc20_mst.jepmnm as prodjepmnm, " +
        "       mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.deliverydate, " +
        "       paper_info.jepmno as paper_jepmno, paper_jepm_mst.jepmnm as paperjepmnm, paper_dtl.size, " +
        "       paper_info.workkind, paper_info.cutwidth, paper_info.cutlength, paper_info.sizejul, paper_info.sizebu, " +
        "       paper_info.dofront, paper_info.doback, paper_dtl.okper, paper_dtl.lossper, mc20_mst.ok2, " +
        "       " + PROC1 + " as proc1, " +
        "       (select sum(deliveryqty) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makeqty, " +
        "       mc20_plan.company as incompany, mc20_mst.jepmno as mst_jepmno, mc20_plan.yarigeqty, " +
        "       isnull((select proc2 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq),'') as proc2, " +
        "       mc20_plan.flowseq as planseq, " +
        "       (select md.seq from mc20_dtl as md where paper_info.jpno = md.jpno and paper_info.seq = md.seq) as mdseq " +
        "  FROM mc20_plan, mc20_mst, jepm_mst, paper_info, mc20_dtl as paper_dtl, jepm_mst paper_jepm_mst, cust_mst " +
        " WHERE mc20_mst.jpno = mc20_plan.mcjpno " +
        "   and cust_mst.custcd = mc20_plan.custcd " +
        "   and mc20_plan.mcjpno = paper_info.jpno " +
        "   and mc20_plan.paperseq = paper_info.seq " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_plan.mcjpno = paper_dtl.jpno " +
        "   and paper_dtl.seq = paper_info.seq " +
        "   and paper_dtl.jepmno = paper_jepm_mst.jepmno " +
        "   and " + PROC1 + " <> '중지' " +
        "   and paper_dtl.gubun = '지류' " +
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and mc20_mst.ok1 = '결재' ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3811.do")
    public String mes3811(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3811 parm=" + request.getParameter("parm"));
        return "mes3811";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3811/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            String company = company(session);
            String flow = v(req, "flow");
            if (!FLOWS.contains(flow)) throw new IllegalArgumentException("공정('" + flow + "')이 올바르지 않습니다.");

            boolean stick = "접착".equals(flow) || "지함".equals(flow);
            StringBuilder sql = new StringBuilder(stick ? STICK_SQL : PAPER_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource();

            // 공정 (PB ls_proc)
            String proc;
            if ("수작업".equals(flow))        proc = company + "수작";
            else if ("스테이너만".equals(flow)) proc = "스테이너";
            else                               proc = company + flow;
            sql.append(" AND mc20_plan.proc3 = :proc");
            p.addValue("proc", proc);

            // [조 회] 는 실적 안 들어온 것, [생산조회] 는 생산일 기간으로 찾으므로 실적 들어온 것
            boolean prod = "prod".equals(v(req, "mode"));
            if (!prod) sql.append(" AND trim(isnull(mc20_plan.procdate,'')) = ''");

            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                // 수주번호 단독 (다른 검색 조건 무시)
                sql.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                // 생산라인 : [조 회] 의 인쇄 1~3호는 예전 라인 이름도 같이, [생산조회] 는 그대로
                String line = v(req, "line");
                if (prod) eqNotAll(sql, p, "mc20_plan.workflow", "line", line);
                else if ("인쇄 1호".equals(line))      sql.append(" AND mc20_plan.workflow in ('인쇄 1호','오산ROND')");
                else if ("인쇄 2호".equals(line)) sql.append(" AND mc20_plan.workflow in ('인쇄 2호','오산MSBC8도')");
                else if ("인쇄 3호".equals(line)) sql.append(" AND mc20_plan.workflow in ('인쇄 3호','서울V3000')");
                else eqNotAll(sql, p, "mc20_plan.workflow", "line", line);

                eqNotAll(sql, p, "mc20_plan.worktime", "worktime", v(req, "worktime"));   // 주 / 야

                // 기간 : [조 회] 계획일, [생산조회] 생산일
                String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                    sql.append(prod ? " AND mc20_plan.procdate BETWEEN :f AND :t" : " AND mc20_plan.plandate BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }
            }

            sql.append(" ORDER BY mc20_plan.workflow, mc20_plan.plandate, mc20_plan.jobseq, mc20_mst.deliverydate");

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
        logger.error("mes3811 error", e);
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
