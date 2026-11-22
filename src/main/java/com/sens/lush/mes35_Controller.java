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
 * mes35 생산계획 대상 (외주 공정 · 지류별) — 조회 버튼을 눌렀을 때만 조회
 *  - /mes35.do       화면
 *  - /mes35/list     생산계획 대상 조회 (JSON)
 *  - /mes35/plan     생산계획 조회 (JSON) — mc20_plan (proc3 = '오산인쇄')
 *  - 외주처 찾기는 mes0201 것을 같이 씀 (/mes0201/cust)
 *
 *  기본 조건 : 결재된 제품·재공 사양서의 외주 공정 중 처리(procchk='Y'), 오산인쇄 공정, 반려되지 않음, 계획일 없음
 *  수주번호 / 제품명 이 있으면 그것으로만 조회 (다른 조건 무시)
 *  아니면 구분 '생산' + 외주처 / 공정 / 사업장 / 등록월 / 강제조회 / 작업 (부족분·일부불량·전체불량 제외)
 *
 *  PB SQL 에서 바꾼 점
 *   - 같은 이름 컬럼(seq, jepmno, workkind, qty, size 등)은 값이 덮어써지지 않도록 별칭
 *   - sect_flow EXISTS 의 닫는 괄호 추가
 *   - 구분(proc1) 조건은 별칭 대신 식 그대로 사용
 *   - 외주처 조건은 외주처(mc20_dtl.custcd) 기준
 */
@Controller
public class mes35_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";
    private static final String USER_COMPANY = "COMPANY";   // 세션 USER 의 회사코드 키 (로그인 확인용)

    private static final int MAX_ROWS = 5000;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes35_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_dtl.jpno, mc20_dtl.seq, mc20_dtl.gubun, mc20_dtl.cdate, mc20_dtl.jepmno as mc20_dtl_jepmno, " +
        "       mc20_dtl.workflow, '' as worktime, mc20_dtl.jobseq, mc20_dtl.procdate, mc20_dtl.plandate, mc20_dtl.planseq, " +
        "       mc20_dtl.custcd, cust_mst.custname as flowcustname, mc20_dtl.workkind, mc20_dtl.flow, " +
        "       mc20_dtl.prodcnt, mc20_dtl.docnt, " +
        "       isnull(mc20_dtl.orderremk, '') + isnull(mc20_dtl.remk, '') as flowname, " +
        "       mc20_dtl.price, mc20_dtl.okper as prodok, mc20_dtl.lossper as prodloss, mc20_dtl.jisiqty, " +
        "       mc20_dtl.qty as dtl_qty, " +
        "       (select sum(qty) + sum(cut_qty) from jaje20_dtl where prodjpno = mc20_mst.jpno and in_out = '출고') as papertuip, " +
        "       mc20_dtl.amt as dtlamt, mc20_dtl.remk, mc20_dtl.planremk, " +
        "       mc20_mst.company, mc20_mst.sabunnm, mc20_mst.orderno, mc20_mst.papmkind, mc20_mst.prdate, " +
        "       jepm_mst.jepmcd as prodjepmcd, mc20_mst.jepmnm as prodjepmnm, " +
        "       mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.deliverydate, " +
        "       paper_info.jepmno as paper_jepmno, paper_jepm_mst.jepmnm as paperjepmnm, " +
        "       paper_dtl.size as paper_size, paper_dtl.seq as paper_dtl_seq, " +
        "       paper_info.workkind as paper_workkind, paper_info.cutwidth, paper_info.cutlength, " +
        "       paper_info.sizejul, paper_info.sizebu, paper_info.seq as paper_info_seq, " +
        "       paper_dtl.okper, paper_dtl.lossper, mc20_mst.ok2, " +
        "       isnull(mc20_dtl_paper.proc1, '생산') as proc1, " +
        "       isnull((select sum(mp.jisiqty) from mc20_plan mp where mp.mcjpno = mc20_dtl.jpno and mp.flowseq = mc20_dtl.seq and mp.paperseq = paper_info.seq), 0) as savejisiqty, " +
        "       isnull((select sum(mp.qty)     from mc20_plan mp where mp.mcjpno = mc20_dtl.jpno and mp.flowseq = mc20_dtl.seq and mp.paperseq = paper_info.seq), 0) as prodqty, " +
        "       isnull((select company from mc20_plan mp where mp.mcjpno = mc20_dtl.jpno and mp.flowseq = mc20_dtl.seq and mp.paperseq = paper_info.seq group by company), '') as incompany, " +
        "       (if (select top 1 mp.jpno from mc20_plan mp where mp.mcjpno = mc20_dtl.jpno and mp.flowseq = mc20_dtl.seq) is null then 'N' else 'Y' endif) as datachk, " +
        "       (select md.seq from mc20_dtl as md where paper_info.jpno = md.jpno and paper_info.seq = md.seq) as mdseq " +
        "  FROM mc20_dtl, mc20_mst, jepm_mst, paper_info, mc20_dtl as paper_dtl, jepm_mst paper_jepm_mst " +
        "       left outer join cust_mst       on mc20_dtl.custcd = cust_mst.custcd " +
        "       left outer join mc20_dtl_paper on mc20_dtl.jpno = mc20_dtl_paper.jpno and mc20_dtl.seq = mc20_dtl_paper.seq and paper_info.seq = mc20_dtl_paper.paperseq " +
        " WHERE mc20_mst.jpno = mc20_dtl.jpno " +
        "   and mc20_mst.chk = 'Y' " +
        "   and mc20_dtl.jpno = paper_info.jpno " +
        "   and paper_dtl.seq = paper_info.seq " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_dtl.jpno = paper_dtl.jpno " +
        "   and paper_dtl.jepmno = paper_jepm_mst.jepmno " +
        "   and paper_dtl.gubun = '지류' " +
        "   and mc20_mst.jepminfo in ('제품', '재공') " +
        "   and mc20_mst.ok1 = '결재' " +
        "   and mc20_dtl.gubun = '외주' " +
        "   and mc20_dtl.procchk = 'Y' " +
        "   and exists (select custcd from sect_flow where sect_flow.custcd = mc20_dtl.custcd and sect_flow.flow = mc20_dtl.flow and sect_flow.gubun = '오산인쇄') " +
        "   and not exists (select flow_return.proc1 from flow_return where flow_return.jpno = mc20_dtl.jpno and flow_return.flowseq = mc20_dtl.seq " +
        "                                                            and flow_return.paperseq = paper_info.seq and flow_return.proc1 = '반려') " +
        "   and mc20_dtl.plandate = '' ";

    /** 생산계획 (mc20_plan) — 같은 이름 컬럼은 별칭 (수주량 mst_qty, 지류 작업분류 paper_workkind 등) */
    private static final String PLAN_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_plan.jpno as planjpno, mc20_plan.mcjpno as jpno, mc20_plan.flowseq as seq, mc20_plan.paperseq as paper_info_seq, " +
        "       mc20_plan.gubun, mc20_plan.cdate, mc20_plan.jepmno as mc20_plan_jepmno, " +
        "       mc20_plan.workflow, mc20_plan.worktime, mc20_plan.jobseq, mc20_plan.procdate, mc20_plan.plandate, mc20_plan.planseq, " +
        "       mc20_plan.custcd, cust_mst.custname as flowcustname, mc20_plan.workkind, " +
        "       (select flow from mc20_dtl md where md.jpno = paper_dtl.jpno and md.seq = mc20_plan.flowseq) as flow, " +
        "       mc20_plan.price, mc20_plan.jisiqty, mc20_plan.qty, mc20_plan.papmqty, " +
        "       (select sum(qty) + sum(cut_qty) from jaje20_dtl where prodjpno = mc20_mst.jpno and in_out = '출고') as papertuip, " +
        "       mc20_plan.paperprodtuip, mc20_plan.amt as dtlamt, " +
        "       (select orderremk || remk from mc20_dtl md where md.jpno = paper_dtl.jpno and md.seq = mc20_plan.flowseq) as flowname, " +
        "       mc20_plan.planremk, mc20_plan.prodremk, mc20_plan.readyterm, mc20_plan.timeterm, " +
        "       mc20_plan.readyfrom, mc20_plan.readyto, mc20_plan.ftime, mc20_plan.ttime, mc20_plan.stick, " +
        "       mc20_plan.company as incompany, " +
        "       (select count(*) from mc20_plan_log lg where lg.jpno = mc20_plan.jpno and lg.flowseq = mc20_plan.flowseq and lg.paperseq = mc20_plan.paperseq) as mod_cnt, " +
        "       mc20_plan.sil_loss, " +
        "       mc20_mst.orderno, mc20_mst.company, mc20_mst.sabunnm, jepm_mst.jepmcd as prodjepmcd, mc20_mst.jepmnm as prodjepmnm, " +
        "       mc20_mst.papmkind, mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.deliverydate, " +
        "       paper_info.jepmno as paper_jepmno, paper_jepm_mst.jepmnm as paperjepmnm, paper_dtl.size as paper_size, " +
        "       paper_info.workkind as paper_workkind, paper_info.cutwidth, paper_info.cutlength, " +
        "       paper_info.sizejul, paper_info.sizebu, paper_info.panfront, paper_info.panback, paper_info.dofront, paper_info.doback, " +
        "       paper_dtl.okper, paper_dtl.okper as prodok, paper_dtl.lossper, mc20_mst.ok2, " +
        "       isnull((select sum(mp.realpapm) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno and mp.flowseq = mc20_plan.flowseq and mp.paperseq = mc20_plan.paperseq), 0) as realpapm, " +
        "       isnull((select proc1 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq), '생산') as proc1, " +
        "       isnull((select sum(mp.jisiqty) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno and mp.flowseq = mc20_plan.flowseq and mp.paperseq = mc20_plan.paperseq), 0) as savejisiqty, " +
        "       isnull((select sum(mp.qty) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno and mp.flowseq = mc20_plan.flowseq and mp.paperseq = mc20_plan.paperseq), 0) as prodqty, " +
        "       isnull(mc20_plan.procprdate + mc20_plan.procprtime, '') as lostprdate, " +
        "       mc20_plan.yarigeqty as yarigeqty, " +
        "       (select top 1 mc20_dtl.prodcnt from mc20_dtl where mc20_dtl.jpno = paper_dtl.jpno and flow like '%인쇄%') as prodcnt, " +
        "       (select top 1 mc20_dtl.docnt   from mc20_dtl where mc20_dtl.jpno = paper_dtl.jpno and flow like '%인쇄%') as docnt, " +
        "       isnull((select proc2 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq), '') as proc2, " +
        "       paper_info.seq as paper_info_paperseq, paper_dtl.seq as mc20_dtl_seq, " +
        "       (select md.seq from mc20_dtl as md where paper_info.jpno = md.jpno and paper_info.seq = md.seq) as mdseq, " +
        "       (select custname from cust_mst cm where cm.custcd = mc20_mst.custcd) as custname " +
        "  FROM mc20_plan, mc20_mst, jepm_mst, paper_info, mc20_dtl as paper_dtl, jepm_mst paper_jepm_mst, cust_mst " +
        " WHERE mc20_mst.jpno = mc20_plan.mcjpno " +
        "   and cust_mst.custcd = mc20_plan.custcd " +
        "   and mc20_plan.mcjpno = paper_info.jpno " +
        "   and mc20_plan.paperseq = paper_info.seq " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_plan.mcjpno = paper_dtl.jpno " +
        "   and paper_dtl.seq = paper_info.seq " +
        "   and paper_dtl.jepmno = paper_jepm_mst.jepmno " +
        "   and paper_dtl.gubun = '지류' " +
        "   and mc20_mst.jepminfo in ('제품', '재공') " +
        "   and mc20_mst.ok1 = '결재' " +
        "   and mc20_plan.proc3 = '오산인쇄' ";

    /** 생산라인 선택값 → workflow 목록 */
    private static final Map<String, String> LINE = new LinkedHashMap<String, String>();
    static {
        LINE.put("인쇄1호",    "('인쇄 1호', '오산ROND')");
        LINE.put("인쇄2호",    "('인쇄 2호', '오산MSBC8도')");
        LINE.put("인쇄3호",    "('인쇄 3호', '서울V3000')");
        LINE.put("스테이너만", "('스테이너만')");
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes35.do")
    public String mes35(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes35");
        return "mes35";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes35/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            company(session);   // 로그인 확인
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource();

            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                // 수주번호 / 제품명 단독 (다른 조건 무시)
                if ("jepmnm".equals(v(req, "keyKind"))) { sql.append(" AND mc20_mst.jepmnm LIKE :key"); p.addValue("key", "%" + key + "%"); }
                else                                    { sql.append(" AND mc20_mst.orderno = :key");   p.addValue("key", key); }
            } else {
                // 구분 = 생산
                sql.append(" AND isnull(mc20_dtl_paper.proc1, '생산') = '생산'");

                // 외주처
                eq(sql, p, "mc20_dtl.custcd", "custcd", v(req, "custcd"));

                // 공정 (입력되면 사업장은 오산)
                String flow = v(req, "flow");
                if (!isEmpty(flow)) {
                    sql.append(" AND mc20_dtl.flow = :flow AND mc20_mst.company = '오산'");
                    p.addValue("flow", flow);
                } else {
                    eqNotAll(sql, p, "mc20_mst.company", "comp", v(req, "comp"));   // 전체 / 서울 / 오산
                }

                // 강제조회가 아니면 앞 공정(또는 101) 완료된 것만
                if (!"Y".equals(v(req, "force")))
                    sql.append(" AND exists (select chk from plan_seq where plan_seq.jpno = mc20_dtl.jpno " +
                               "and (plan_seq.seq = (mc20_dtl.seq - 1) or plan_seq.seq = 101) and chk = '완료')");

                // 등록 기간
                String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
                if (f.length() == 8 && t.length() == 8) {
                    sql.append(" AND mc20_mst.prdate BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }

                sql.append(" AND mc20_mst.papmkind not in ('부족분', '일부불량', '전체불량')");
            }

            sql.append(" ORDER BY mc20_mst.prdate DESC, mc20_mst.orderno DESC, mc20_dtl.seq, paper_dtl.seq, flowcustname, " +
                       "mc20_dtl.flow, mc20_mst.deliverydate, prodjepmnm, mc20_dtl.jpno");

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
    // 생산계획 조회
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes35/plan", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> plan(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            company(session);   // 로그인 확인
            StringBuilder sql = new StringBuilder(PLAN_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource();

            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                // 수주번호 / 제품명 단독 (다른 조건 무시)
                if ("jepmnm".equals(v(req, "keyKind"))) { sql.append(" AND mc20_mst.jepmnm LIKE :key"); p.addValue("key", "%" + key + "%"); }
                else                                    { sql.append(" AND mc20_mst.orderno = :key");   p.addValue("key", key); }
            } else {
                // 외주처 / 공정 / 사업장
                eq(sql, p, "mc20_plan.custcd", "custcd", v(req, "custcd"));
                eq(sql, p, "mc20_plan.flow",   "flow",   v(req, "flow"));
                eqNotAll(sql, p, "mc20_mst.company", "comp", v(req, "comp"));

                // 구분 (전체 / 생산 / 완료 / 중지)
                String proc1 = v(req, "proc1");
                if (!isEmpty(proc1) && !"전체".equals(proc1)) {
                    sql.append(" AND isnull((select proc1 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno " +
                               "and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq), '생산') = :proc1");
                    p.addValue("proc1", proc1);
                }

                // 생산라인 (전체 / 인쇄1호 / 인쇄2호 / 인쇄3호 / 스테이너만 / 처리안함)
                String line = v(req, "line");
                if (LINE.containsKey(line))       sql.append(" AND mc20_plan.workflow in ").append(LINE.get(line));
                else if ("처리안함".equals(line)) sql.append(" AND isnull(mc20_plan.workflow, '') = ''");

                // 주야 (전체 / 주 / 야)
                eqNotAll(sql, p, "mc20_plan.worktime", "worktime", v(req, "worktime"));

                // 강제조회가 아니면 앞 공정(또는 101) 완료된 것만 — 계획의 사양서번호·공정순번 기준
                if (!"Y".equals(v(req, "force")))
                    sql.append(" AND exists (select chk from plan_seq where plan_seq.jpno = mc20_plan.mcjpno " +
                               "and (plan_seq.seq = (mc20_plan.flowseq - 1) or plan_seq.seq = 101) and chk = '완료')");

                // 계획기간 (mc20_plan.plandate)
                String f = digits(v(req, "pfdate")), t = digits(v(req, "ptdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                    sql.append(" AND mc20_plan.plandate BETWEEN :f AND :t");
                    p.addValue("f", f).addValue("t", t);
                }
            }

            sql.append(" ORDER BY mc20_plan.workflow DESC, mc20_plan.worktime DESC, mc20_plan.plandate, mc20_plan.jobseq, " +
                       "mc20_mst.deliverydate, prodjepmnm");

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
        logger.error("mes35 error", e);
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
