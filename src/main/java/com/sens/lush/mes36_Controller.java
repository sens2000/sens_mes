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
 * mes36 생산계획 (후가공 : 접착 / 지함 ...) (PB mes36 조회 화면)
 *  - /mes36.do         화면
 *  - /mes36/list       조회 (JSON)  flow = 라미 | 박 | 실크 | 톰슨 | 수작업 | 스테이너만 | 접착 | 지함 | 용역작업
 *  - /mes36/plan       생산계획 조회 (JSON, mc20_plan) — 모든 공정 (접착·지함 / 그 외 SQL 따로)
 *
 *  수주번호가 있으면 그것으로만 조회 (등록월·구분 조건 무시)
 *  용역작업은 mc20_plan 기준 (등록월 · 수주번호 둘 다 적용, PB 와 같음)
 *  라미 / 박 / 실크 / 톰슨 / 수작업 / 스테이너만 은 외주처 · 사업장 · 강제조회 조건도 씀
 */
@Controller
public class mes36_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap */
    private static final String SESSION_USER  = "USER";
    private static final String USER_COMPANY  = "COMPANY";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes36_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final int MAX_ROWS = 5000;

    /** 화면의 공정 → mc20_plan.proc3 / sect_flow.gubun 값 (PB #flow#) */
    private static final Map<String, String> FLOW = new HashMap<String, String>();
    static {
        FLOW.put("접착", "오산접착");
        FLOW.put("지함", "오산지함");
        FLOW.put("용역작업", "오산용역");
    }

    /** 라미 / 박 / 실크 / 톰슨 / 수작업 / 스테이너만 → sect_flow.gubun like '%값' (PB is_flowgubun) */
    private static final Map<String, String> OUT_FLOW = new HashMap<String, String>();
    static {
        OUT_FLOW.put("라미",       "오산라미");
        OUT_FLOW.put("박",         "오산박");
        OUT_FLOW.put("실크",       "오산실크");
        OUT_FLOW.put("톰슨",       "오산톰슨");
        OUT_FLOW.put("수작업",     "오산수작");
        OUT_FLOW.put("스테이너만", "CTP");
    }

    /** 라미 / 박 / 실크 / 톰슨 / 스테이너만 (mc20_dtl 외주 공정). 이름이 겹치는 qty 는 별칭 */
    private static final String OUT_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_dtl.jpno, mc20_dtl.seq, isnull(mc20_dtl_paper.paperseq,1) as paper_info_seq, " +
        "       mc20_dtl.gubun, mc20_dtl.cdate, mc20_dtl.jepmno as mc20_dtl_jepmno, " +
        "       mc20_dtl.workflow, '' as worktime, mc20_dtl.jobseq, mc20_dtl.procdate, mc20_dtl.procdate as saveproddate, " +
        "       mc20_dtl.plandate, mc20_dtl.planseq, mc20_dtl.custcd, cust_mst.custname as flowcustname, " +
        "       paper_info.workkind, paper_info.cutwidth, paper_info.cutlength, paper_info.sizejul, paper_info.sizebu, " +
        "       mc20_dtl.flow, mc20_dtl.prodcnt, mc20_dtl.docnt, mc20_dtl.orderremk + mc20_dtl.remk as flowname, " +
        "       mc20_dtl.price, mc20_dtl.jisiqty, mc20_dtl.qty as dtl_qty, mc20_dtl.qty as saveprodqty, " +
        "       (select sum(qty) + sum(cut_qty) from jaje20_dtl where prodjpno = mc20_mst.jpno) as papertuip, " +
        "       mc20_dtl.okper as prodok, mc20_dtl.lossper as prodloss, mc20_dtl.amt as dtlamt, " +
        "       mc20_dtl.remk, mc20_dtl.planremk, " +
        "       mc20_mst.company, mc20_mst.sabunnm, mc20_mst.orderno, mc20_mst.papmkind, mc20_mst.prdate, " +
        "       jepm_mst.jepmcd as prodjepmcd, mc20_mst.jepmnm as prodjepmnm, " +
        "       mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.deliverydate, mc20_mst.ok2, " +
        "       isnull(mc20_dtl_paper.proc1,'생산') as proc1, 0 as ksqty, " +
        "       isnull((select sum(mp.jisiqty) from mc20_plan mp where mp.mcjpno = mc20_dtl.jpno and mp.flowseq = mc20_dtl.seq),0) as savejisiqty, " +
        "       isnull((select sum(mp.qty)     from mc20_plan mp where mp.mcjpno = mc20_dtl.jpno and mp.flowseq = mc20_dtl.seq),0) as prodqty, " +
        "       '' as stick, '' as planjpno, 'N' as datachk, 0 as parttime, mc20_dtl_paper.proc2 as proc2, " +
        "       paper_info.seq as paper_info_paperseq, " +
        "       (select md.seq from mc20_dtl as md where paper_info.jpno = md.jpno and paper_info.seq = md.seq) as mdseq, " +
        "       (select custname from cust_mst cm where cm.custcd = mc20_mst.custcd) as custname " +
        "  FROM mc20_dtl, mc20_mst, jepm_mst, paper_info " +
        "       left outer join cust_mst       on mc20_dtl.custcd = cust_mst.custcd " +
        "       left outer join mc20_dtl_paper on mc20_dtl.jpno = mc20_dtl_paper.jpno and mc20_dtl.seq = mc20_dtl_paper.seq " +
        " WHERE mc20_mst.jpno = mc20_dtl.jpno " +
        "   and paper_info.jpno = mc20_dtl.jpno " +
        "   and mc20_mst.chk = 'Y' " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and mc20_mst.ok1 = '결재' " +
        "   and mc20_dtl.gubun = '외주' " +
        "   and mc20_dtl.procchk = 'Y' " +
        "   and mc20_dtl.plandate = '' " +
        "   and exists (select custcd from sect_flow where sect_flow.custcd = mc20_dtl.custcd " +
        "                  and sect_flow.flow = mc20_dtl.flow and sect_flow.gubun like :flowlike) ";

    /** 접착 / 지함 : {DATE} 자리에 등록월 조건, :flow 에 오산접착 / 오산지함 */
    private static final String STICK_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_mst.company, mc20_mst.jpno, 0 as seq, 0 as paper_info_seq, '' as custcd, '' as flowcustname, " +
        "       mc20_mst.sabunnm, mc20_mst.orderno, mc20_mst.cdate, mc20_mst.prdate, " +
        "       jepm_mst.jepmno as goodjepmno, jepm_mst.jepmcd as goodjepmcd, mc20_mst.jepmnm as goodjepmnm, " +
        "       mc20_mst.qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.deliverydate, mc20_mst.ok2, " +
        "       '' as workflow, '' as worktime, 0 as jobseq, 0 as papertuip, '' as plandate, 0 as jisiqty, '' as planremk, " +
        "       isnull(mc20_dtl_paper.proc1,'생산') as proc1, 0 as ksqty, " +
        "       isnull((select sum(mp.jisiqty) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno and mp.proc3 = :flow),0) as savejisiqty, " +
        "       isnull((select sum(mp.qty)     from mc20_plan mp where mp.mcjpno = mc20_mst.jpno and mp.proc3 = :flow),0) as prodqty, " +
        "       '' as stick, '' as planjpno, 'N' as datachk, 0 as paper_info_paperseq, 0 as mdseq " +
        "  FROM mc20_mst, jepm_mst, " +
        "       (select distinct substring(mc20_mst.jpno,1,16) as jpno " +
        "          from mc20_dtl, mc20_mst " +
        "         where mc20_mst.jpno = mc20_dtl.jpno " +
        "           and mc20_dtl.gubun = '외주' and mc20_dtl.procchk = 'Y' and mc20_dtl.plandate = '' " +
        "           {DATE} " +
        "           and exists (select custcd from sect_flow where sect_flow.custcd = mc20_dtl.custcd " +
        "                          and sect_flow.flow = mc20_dtl.flow and sect_flow.gubun = :flow)) as t " +
        "       left outer join mc20_dtl_paper on mc20_dtl_paper.jpno = mc20_mst.jpno and mc20_dtl_paper.seq = 0 " +
        " WHERE mc20_mst.jpno = t.jpno " +
        "   and mc20_mst.chk = 'Y' " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_mst.jepminfo in ('제품') " +
        "   and mc20_mst.ok1 = '결재' ";

    /** 용역작업 : 수주 작업 + 주차수당 (union all). 이름이 겹치는 mc20_mst.jpno / qty 는 별칭 */
    private static final String YONG_COLS =
        "       mc20_plan.jpno, mc20_plan.flowseq, mc20_plan.cdate, mc20_plan.workflow, mc20_plan.proder, " +
        "       mc20_plan.prodremk, mc20_plan.proc3, mc20_plan.length, " +
        "       isnull((select count(*) from yong_rest where jpno = mc20_plan.jpno),0) as restlength, " +
        "       mc20_plan.timeterm, mc20_plan.jisiqty, mc20_plan.readyfrom, mc20_plan.readyto, mc20_plan.readyterm, " +
        "       mc20_plan.ftime, mc20_plan.ttime, mc20_plan.stick, mc20_plan.qty, mc20_plan.remk ";

    private static final String YONG_SQL =
        "SELECT mc20_mst.company, mc20_mst.jpno as mstjpno, mc20_mst.orderno, mc20_mst.jepmnm, mc20_mst.qty as mst_qty, " +
        "       wonjepm_mst.wonjepmcd, " + YONG_COLS +
        "  FROM mc20_plan, mc20_mst, wonjepm_mst " +
        " WHERE mc20_plan.mcjpno = mc20_mst.jpno " +
        "   and mc20_mst.wonjepmno = wonjepm_mst.wonjepmno " +
        "   and mc20_plan.proc3 = :flow " +
        "   and mc20_plan.cdate between :f and :t " +
        "   and mc20_mst.orderno like :orderno " +
        "UNION ALL " +
        "SELECT mc20_plan.company, '' as mstjpno, '' as orderno, '' as jepmnm, 0 as mst_qty, " +
        "       '' as wonjepmcd, " + YONG_COLS +
        "  FROM mc20_plan " +
        " WHERE mc20_plan.proc3 = :flow " +
        "   and mc20_plan.cdate between :f and :t " +
        "   and mc20_plan.orderno like :orderno " +
        "   and mc20_plan.workflow = '주차수당' " +
        " ORDER BY 9, 10, 7";                     // cdate, workflow, jpno (UNION 은 열 번호로 정렬)

    /** 생산계획 조회 : 화면의 공정 → mc20_plan.proc3 (PB is_flowgubun / #flow#) */
    private static final Map<String, String> PLAN_FLOW = new HashMap<String, String>();
    static {
        PLAN_FLOW.put("라미",       "오산라미");
        PLAN_FLOW.put("박",         "오산박");
        PLAN_FLOW.put("실크",       "오산실크");
        PLAN_FLOW.put("톰슨",       "오산톰슨");
        PLAN_FLOW.put("수작업",     "오산수작");
        PLAN_FLOW.put("접착",       "오산접착");
        PLAN_FLOW.put("지함",       "오산지함");
        PLAN_FLOW.put("용역작업",   "오산용역");
        PLAN_FLOW.put("스테이너만", "CTP");
    }

    /** 구분 (mc20_dtl_paper.proc1, 없으면 생산) — 조건에도 같은 식을 씀 */
    private static final String PLAN_PROC1 =
        "isnull((select proc1 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno " +
        "and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq),'생산')";

    /** 생산계획 (mc20_plan). 이름이 겹치는 mc20_mst.qty / cdate 는 별칭, 현장생산·분당생산은 화면에서 계산 */
    private static final String PLAN_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_mst.company, mc20_mst.jpno, mc20_plan.flowseq as seq, mc20_plan.paperseq as paper_info_seq, " +
        "       mc20_plan.gubun, mc20_plan.cdate, mc20_plan.custcd, '' as flowcustname, " +
        "       mc20_plan.procdate, mc20_plan.procdate as saveproddate, mc20_plan.qty, mc20_plan.papmqty, " +
        "       mc20_plan.qty as saveprodqty, mc20_plan.mod_cnt, mc20_plan.company as incompany, " +
        "       mc20_mst.sabunnm, mc20_mst.orderno, mc20_mst.cdate as mst_cdate, mc20_mst.prdate, " +
        "       jepm_mst.jepmno as goodjepmno, jepm_mst.jepmcd as goodjepmcd, mc20_mst.jepmnm as goodjepmnm, " +
        "       mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, " +
        "       mc20_plan.readyterm, mc20_plan.timeterm, mc20_plan.readyfrom, mc20_plan.readyto, " +
        "       mc20_plan.ftime, mc20_plan.ttime, mc20_mst.deliverydate, mc20_mst.ok2, " +
        "       mc20_plan.workflow, mc20_plan.worktime, mc20_plan.jobseq, mc20_plan.papertuip, mc20_plan.plandate, " +
        "       mc20_plan.jisiqty, mc20_plan.planremk, mc20_plan.prodremk, mc20_plan.stick, " +
        "       " + PLAN_PROC1 + " as proc1, 0 as ksqty, " +
        "       isnull((select sum(mp.jisiqty) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno and mp.proc3 = :flow),0) as savejisiqty, " +
        "       isnull((select sum(mp.qty)     from mc20_plan mp where mp.mcjpno = mc20_mst.jpno and mp.proc3 = :flow),0) as prodqty, " +
        "       mc20_plan.jpno as planjpno, 'N' as datachk, mc20_plan.yarigeqty as yarigeqty, 0 as parttime, " +
        "       isnull((select proc2 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno " +
        "               and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq),'') as proc2, " +
        "       0 as paper_info_paperseq, 0 as mdseq, " +
        "       (select custname from cust_mst cm where cm.custcd = mc20_mst.custcd) as custname " +
        "  FROM mc20_plan, mc20_mst, jepm_mst " +
        " WHERE mc20_mst.jpno = mc20_plan.mcjpno " +
        "   and jepm_mst.jepmno = mc20_mst.jepmno " +
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and mc20_mst.ok1 = '결재' ";

    /** 생산계획 (접착 / 지함 이 아닐 때) : 지류(paper_info / paper_dtl) 기준.
     *  이름이 겹치는 mc20_plan.workkind → plan_workkind, mc20_mst.qty → mst_qty. 정미+Loss · 재단규격 · 분당생산은 화면에서 계산 */
    private static final String PLAN2_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       mc20_plan.jpno as planjpno, mc20_plan.mcjpno as jpno, mc20_plan.flowseq as seq, mc20_plan.paperseq as paper_info_seq, " +
        "       mc20_plan.gubun, mc20_plan.cdate, mc20_plan.jepmno as mc20_plan_jepmno, " +
        "       mc20_plan.workflow, mc20_plan.worktime, mc20_plan.jobseq, mc20_plan.procdate, mc20_plan.procdate as saveproddate, " +
        "       mc20_plan.plandate, mc20_plan.planseq, mc20_plan.custcd, cust_mst.custname as flowcustname, " +
        "       mc20_plan.workkind as plan_workkind, " +
        "       (select flow from mc20_dtl md where md.jpno = paper_dtl.jpno and md.seq = mc20_plan.flowseq) as flow, " +
        "       mc20_plan.price, mc20_plan.jisiqty, mc20_plan.qty, mc20_plan.papmqty, mc20_plan.qty as saveprodqty, " +
        "       (select sum(qty) + sum(cut_qty) from jaje20_dtl where prodjpno = mc20_mst.jpno and in_out = '출고') as papertuip, " +
        "       mc20_plan.paperprodtuip, mc20_plan.amt as dtlamt, " +
        "       (select orderremk || remk from mc20_dtl md where md.jpno = paper_dtl.jpno and md.seq = mc20_plan.flowseq) as flowname, " +
        "       mc20_plan.planremk, mc20_plan.prodremk, mc20_plan.readyterm, mc20_plan.timeterm, " +
        "       mc20_plan.readyfrom, mc20_plan.readyto, mc20_plan.ftime, mc20_plan.ttime, mc20_plan.stick, " +
        "       mc20_plan.company as incompany, " +
        "       (select count() from mc20_plan_log lg where lg.jpno = mc20_plan.jpno and lg.flowseq = mc20_plan.flowseq " +
        "           and lg.paperseq = mc20_plan.paperseq) as mod_cnt, " +
        "       mc20_plan.sil_loss, " +
        "       mc20_mst.orderno, mc20_mst.company, mc20_mst.sabunnm, jepm_mst.jepmcd as prodjepmcd, " +
        "       mc20_mst.jepmnm as prodjepmnm, mc20_mst.papmkind, " +
        "       mc20_mst.qty as mst_qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.deliverydate, " +
        "       paper_info.jepmno, paper_jepm_mst.jepmnm as paperjepmnm, paper_dtl.size, " +
        "       paper_info.workkind, paper_info.cutwidth, paper_info.cutlength, paper_info.sizejul, paper_info.sizebu, " +
        "       paper_info.panfront, paper_info.panback, paper_info.dofront, paper_info.doback, " +
        "       paper_dtl.okper, paper_dtl.okper as prodok, paper_dtl.lossper, mc20_mst.ok2, 0 as ksqty, " +
        "       isnull((select sum(mp.realpapm) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno " +
        "               and mp.flowseq = mc20_plan.flowseq and mp.paperseq = mc20_plan.paperseq),0) as realpapm, " +
        "       " + PLAN_PROC1 + " as proc1, " +
        "       isnull((select sum(mp.jisiqty) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno " +
        "               and mp.flowseq = mc20_plan.flowseq and mp.paperseq = mc20_plan.paperseq),0) as savejisiqty, " +
        "       isnull((select sum(mp.qty) from mc20_plan mp where mp.mcjpno = mc20_mst.jpno " +
        "               and mp.flowseq = mc20_plan.flowseq and mp.paperseq = mc20_plan.paperseq),0) as prodqty, " +
        "       isnull(mc20_plan.procprdate + mc20_plan.procprtime,'') as lostprdate, " +
        "       'N' as datachk, 'N' as plandetail, mc20_plan.yarigeqty as yarigeqty, 0 as parttime, " +
        "       (select top 1 mc20_dtl.prodcnt from mc20_dtl where mc20_dtl.jpno = paper_dtl.jpno and flow like '%인쇄%') as prodcnt, " +
        "       (select top 1 mc20_dtl.docnt   from mc20_dtl where mc20_dtl.jpno = paper_dtl.jpno and flow like '%인쇄%') as docnt, " +
        "       isnull((select proc2 from mc20_dtl_paper where mc20_dtl_paper.jpno = mc20_mst.jpno " +
        "               and mc20_dtl_paper.seq = mc20_plan.flowseq and mc20_dtl_paper.paperseq = mc20_plan.paperseq),'') as proc2, " +
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
        "   and mc20_mst.jepminfo in ('제품','재공') " +
        "   and mc20_mst.ok1 = '결재' ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes36.do")
    public String mes36(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes36");
        return "mes36";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes36/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            checkLogin(session);
            String outFlow = OUT_FLOW.get(v(req, "flow"));
            if (outFlow != null) return out(req, outFlow);

            String flow = FLOW.get(v(req, "flow"));
            if (flow == null) throw new IllegalArgumentException("'" + v(req, "flow") + "' 공정은 아직 조회 SQL 이 없습니다.");

            MapSqlParameterSource p = new MapSqlParameterSource().addValue("flow", flow);
            String key = v(req, "keyText");

            if ("오산용역".equals(flow)) return yong(p, key, digits(v(req, "ym")));

            String dateCond = "";
            StringBuilder where = new StringBuilder();

            if (!isEmpty(key)) {
                // 수주번호 단독 (등록월 · 구분 무시)
                where.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                // 등록월 : yyyymm01 ~ yyyymm31 (안쪽 조회에 적용)
                String ym = digits(v(req, "ym"));
                if (ym.length() != 6) throw new IllegalArgumentException("등록월을 입력하세요.");
                dateCond = " and mc20_mst.prdate between :f and :t ";
                p.addValue("f", ym + "01").addValue("t", ym + "31");
                // 구분 = 생산
                where.append(" AND isnull(mc20_dtl_paper.proc1,'생산') = '생산'");
            }

            String sql = STICK_SQL.replace("{DATE}", dateCond) + where +
                         " ORDER BY mc20_mst.prdate DESC, mc20_mst.orderno DESC, flowcustname, mc20_mst.deliverydate";

            List<Map<String, Object>> rows = lower(jdbc.queryForList(sql, p));
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
    @RequestMapping(value = "/mes36/plan", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> plan(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            checkLogin(session);
            String flow = PLAN_FLOW.get(v(req, "flow"));
            if (flow == null) throw new IllegalArgumentException("공정을 선택하세요.");

            // 접착 / 지함 은 완제품 기준, 나머지는 지류 기준 SQL (검색 조건은 같음)
            boolean stick = "오산접착".equals(flow) || "오산지함".equals(flow);
            StringBuilder sql = new StringBuilder(stick ? PLAN_SQL : PLAN2_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("flow", flow);

            // 공정
            if ("CTP".equals(flow)) sql.append(" AND mc20_plan.proc3 like '스테이너'");
            else                    sql.append(" AND mc20_plan.flow <> 'CTP' AND mc20_plan.proc3 = :flow");

            String key = v(req, "keyText");
            if (!isEmpty(key)) {
                // 수주번호 단독 (다른 검색 조건 무시)
                sql.append(" AND mc20_mst.orderno = :key");
                p.addValue("key", key);
            } else {
                eqNotAll(sql, p, "mc20_mst.company", "comp", v(req, "comp"));        // 사업장
                eq(sql, p, "mc20_plan.custcd", "custcd", v(req, "custcd"));          // 외주처

                // 구분 : 전체 / 생산 / 완료 / 중지
                String proc1 = v(req, "proc1");
                if (!isEmpty(proc1) && !"전체".equals(proc1)) {
                    sql.append(" AND ").append(PLAN_PROC1).append(" = :proc1");
                    p.addValue("proc1", proc1);
                }

                // 생산라인 : 처리안함 = 생산라인 미지정 (mes35 와 같음)
                String line = v(req, "line");
                if ("처리안함".equals(line))                    sql.append(" AND isnull(mc20_plan.workflow,'') = ''");
                else if (!isEmpty(line) && !"전체".equals(line)) eq(sql, p, "mc20_plan.workflow", "line", line);

                eqNotAll(sql, p, "mc20_plan.worktime", "worktime", v(req, "worktime"));   // 주 / 야

                // 계획일
                String f = digits(v(req, "pfdate")), t = digits(v(req, "ptdate"));
                if (f.length() == 8 && t.length() == 8) {
                    if (f.compareTo(t) > 0) throw new IllegalArgumentException("계획일 시작일이 종료일보다 늦습니다.");
                    sql.append(" AND mc20_plan.plandate BETWEEN :pf AND :pt");
                    p.addValue("pf", f).addValue("pt", t);
                }
            }

            sql.append(" ORDER BY mc20_plan.workflow DESC, mc20_plan.worktime DESC, mc20_plan.plandate, mc20_plan.jobseq, " +
                       "mc20_mst.deliverydate");

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

    /** 라미 / 박 / 실크 / 톰슨 / 스테이너만 */
    private Map<String, Object> out(Map<String, String> req, String flowGubun) {
        StringBuilder sql = new StringBuilder(OUT_SQL);
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("flowlike", "%" + flowGubun);

        String key = v(req, "keyText");
        if (!isEmpty(key)) {
            // 수주번호 단독 (다른 검색 조건 무시)
            sql.append(" AND mc20_mst.orderno = :key");
            p.addValue("key", key);
        } else {
            sql.append(" AND isnull(mc20_dtl_paper.proc1,'생산') = '생산'");
            eqNotAll(sql, p, "mc20_mst.company", "comp", v(req, "comp"));   // 사업장 (전체면 조건 없음)
            eq(sql, p, "mc20_dtl.custcd", "custcd", v(req, "custcd"));        // 외주처

            // 강제조회 해제 : 앞 공정(또는 101) 이 완료된 것만
            if (!"Y".equals(v(req, "force")))
                sql.append(" AND exists (select chk from plan_seq where plan_seq.jpno = mc20_dtl.jpno " +
                           "and (plan_seq.seq = (mc20_dtl.seq - 1) or plan_seq.seq = 101) and chk = '완료')");

            // 등록월 : yyyymm01 ~ yyyymm31
            String ym = digits(v(req, "ym"));
            if (ym.length() == 6) {
                sql.append(" AND mc20_mst.prdate BETWEEN :f AND :t");
                p.addValue("f", ym + "01").addValue("t", ym + "31");
            }
        }

        sql.append(" ORDER BY mc20_mst.prdate DESC, mc20_mst.orderno DESC, mc20_dtl.seq, flowcustname, mc20_dtl.flow, " +
                   "mc20_mst.deliverydate, prodjepmnm, mc20_dtl.jpno");

        List<Map<String, Object>> rows = lower(jdbc.queryForList(sql.toString(), p));
        Map<String, Object> res = ok(rows);
        if (rows.size() > MAX_ROWS) {
            rows.remove(rows.size() - 1);
            res.put("msg", MAX_ROWS + "건까지만 표시합니다. 조건을 좁혀 주세요.");
        }
        return res;
    }

    /** 용역작업 : PB 처럼 등록월 + 수주번호 (비우면 전체) 둘 다 적용 */
    private Map<String, Object> yong(MapSqlParameterSource p, String key, String ym) {
        if (ym.length() != 6) throw new IllegalArgumentException("등록월을 입력하세요.");
        p.addValue("f", ym + "01").addValue("t", ym + "31")
         .addValue("orderno", isEmpty(key) ? "%" : key);

        List<Map<String, Object>> rows = lower(jdbc.queryForList(YONG_SQL, p));
        Map<String, Object> res = ok(rows);
        if (rows.size() > MAX_ROWS) {
            rows.subList(MAX_ROWS, rows.size()).clear();
            res.put("msg", MAX_ROWS + "건까지만 표시합니다. 조건을 좁혀 주세요.");
        }
        return res;
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
        logger.error("mes36 error", e);
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
