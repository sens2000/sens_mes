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
 * mes3205_jepm_info 수주 조회 (팝업, 조회 전용) — PB 수주 조회 화면
 *  - 화면 : /mes3205_jepm_info.do?jpno=...  → mes3205_jepm_info.jsp
 *  - 데이터 : /mes3205_jepm_info/data?jpno=...
 *  - 다른 화면에서는 /WEB-INF/common/jepm_info_popup.jspf 를 include 하고 openJepmOrderView(jpno) 호출
 *
 *  head      상단 수주 내용   (mc20_mst 1건 — mes3204_jepm_info 와 같은 SQL)
 *  wip       재공 제품        (같은 관리번호의 jepminfo='재공' 전표)
 *  woiju     외주 공정        (mc20_dtl gubun='외주')            왼쪽 3번째
 *  paper     지류             (paper_info + mc20_dtl gubun='지류') 왼쪽 4번째
 *  tax       청구현황         (tax_dtl)                          오른쪽 3번째
 *  woijuPlan 외주 처리 내역   (mc20_plan + woiju_woijubi1)        오른쪽 4번째
 *  paperIn   지류 입고        (prod_dtl kind='지류')             오른쪽 5번째
 *
 *  같은 이름의 컬럼은 값이 덮어써지지 않도록 별칭 사용
 *  한 구역 쿼리가 실패해도 나머지는 보여주도록 구역별로 오류를 따로 담음 (errors)
 */
@Controller
public class mes3205_jepm_info_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3205_jepm_info_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // SQL
    // ------------------------------------------------------------------
    private static final String SQL_HEAD =
        "SELECT cust_mst.custname, cust_dtl.custsectname, cust_mst.telno, " +
        "       mc20_mst.company, mc20_mst.jpno, mc20_mst.amt, mc20_mst.datagubun, mc20_mst.kind, mc20_mst.kind1, " +
        "       mc20_mst.papmkind, mc20_mst.remk, mc20_mst.returnmsg, mc20_mst.prdate, mc20_mst.prtime, mc20_mst.pruser, " +
        "       mc20_mst.custcd, mc20_mst.taxpub, mc20_mst.custseqcd, mc20_mst.jepmno, mc20_mst.moddate, " +
        "       jepm_mst.jepmcd, jepm_mst.test, mc20_mst.jepmnm, mc20_mst.sabun, mc20_mst.sabunnm, " +
        "       mc20_mst.oldorderno, mc20_mst.orderno, mc20_mst.setno, mc20_mst.pocode, " +
        "       mc20_mst.qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.price, mc20_mst.restqty, " +
        "       mc20_mst.ok1, mc20_mst.ok2, mc20_mst.ok3, mc20_mst.paperjpno, mc20_mst.makejpno, mc20_mst.outjpno, " +
        "       mc20_mst.cdate, mc20_mst.deliverydate, mc20_mst.deliveryok, mc20_mst.keepsite, " +
        "       (select custname from cust_mst cust_keep where cust_keep.custcd = mc20_mst.keepsite) as keepname, " +
        "       mc20_mst.wonorderno, mc20_mst.papmmsg, mc20_mst.custjepmcd, mc20_mst.jepmgubun, " +
        "       mc20_mst.designer, mc20_mst.designertelno, mc20_mst.flowlist, mc20_mst.jepminfo, mc20_mst.wonjepmno, " +
        "       mc20_mst.chktime, mc20_mst.chkdate, mc20_mst.chkuser, mc20_mst.codeno, " +
        "       wonjepm_mst.wonjepmcd, jepm_mst.kind as jepmkind, jepm_mst.prodjepmno, " +
        "       0 as jego, " +
        "       (select sum(deliveryqty) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makeqty, " +
        "       (select list(trim(distinct tax_dtl.cdate)) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxyymm, " +
        "       (select sum(tax_dtl.amt) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxamt, " +
        "       (select sum(tax_dtl.qty) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxqty, " +
        "       isnull(mc20_file.jpno, '') as filejpno, isnull(mc20_file.filename, '') as filename, " +
        "       isnull((select count(*) from mc20_mst mm, jepm_mst jm where mm.jepminfo = '재공' and mm.jepmno = jm.jepmno and mm.orderno = mc20_mst.orderno), 0) as jepminfocnt, " +
        "       mc20_mst.code as code, mc20_mst.lotno as lotno, mc20_mst.cgchk as cgchk " +
        "  FROM cust_mst, cust_dtl, mc20_mst, jepm_mst " +
        "       left outer join wonjepm_mst on wonjepm_mst.wonjepmno = mc20_mst.wonjepmno " +
        "       left outer join mc20_file   on mc20_file.jpno = mc20_mst.jpno " +
        " WHERE ( cust_mst.custcd = mc20_mst.custcd ) " +
        "   and ( cust_mst.custcd = cust_dtl.custcd ) " +
        "   and ( mc20_mst.custseqcd = cust_dtl.custseqcd ) " +
        "   and ( mc20_mst.jepmno = jepm_mst.jepmno ) " +
        "   and ( mc20_mst.jpno = :jpno ) " +
        " ORDER BY cust_mst.custname, mc20_mst.jpno ASC";

    /** 재공 제품 (가운데) */
    private static final String SQL_WIP =
        "SELECT jepm_mst.jepmno, jepm_mst.kind, jepm_mst.jepmcd, jepm_mst.jepmnm, jepm_mst.prdate, " +
        "       jepm_mst.sizewidth, jepm_mst.sizelength, " +
        "       jepm_info.remk, jepm_info.cutwidth, jepm_info.cutlength, jepm_info.width, jepm_info.length, jepm_info.height, " +
        "       jepm_info.sizejul, jepm_info.sizebu, jepm_info.pancnt, jepm_info.docnt, jepm_info.pantype, jepm_info.lentype, " +
        "       jepm_info.jego, " +
        "       mc20_mst.jpno as jpno, mc20_mst.orderno as orderno, mc20_mst.papmkind as papmkind, " +
        "       isnull((select round(avg(lossper), 2) from jepm_info_flow where jepm_info_flow.jepmno = mc20_mst.jepmno), 0) as lossper, " +
        "       (select okper   from mc20_dtl where mc20_dtl.jpno = mc20_mst.jpno and seq = 101) as ok, " +
        "       (select lossper from mc20_dtl where mc20_dtl.jpno = mc20_mst.jpno and seq = 101) as loss, " +
        "       isnull((select count(*) from mc20_dtl where mc20_dtl.jpno = mc20_mst.jpno and plandate <> ''), 0) as plandatecnt, " +
        "       isnull((select count(*) from mc20_dtl where mc20_dtl.jpno = mc20_mst.jpno and procdate <> ''), 0) as procdatecnt, " +
        "       isnull((select count(*) from mc20_dtl where mc20_dtl.jpno = mc20_mst.jpno and mc20_dtl.qty <> 0 and mc20_dtl.gubun = '외주'), 0) as prodqtycnt, " +
        "       isnull((select count(*) from ip01_dtl where ip01_dtl.mcjpno = mc20_mst.jpno), 0) as paperordercnt " +
        "  FROM mc20_mst, jepm_mst " +
        "       left outer join jepm_info on jepm_info.jepmno = jepm_mst.jepmno and jepm_info.chk = 'Y' " +
        " WHERE mc20_mst.jepmno = jepm_mst.jepmno " +
        "   and mc20_mst.jepminfo = '재공' " +
        "   and mc20_mst.orderno = :orderno";

    /** 외주 공정 (왼쪽 3번째) — 계획일 표시는 mc20_dtl 의 jpno·seq 기준으로 계획(mc20_plan)이 있으면 'o' */
    private static final String SQL_WOIJU =
        "SELECT mc20_dtl.company, mc20_dtl.custcd, " +
        "       (select custname from cust_mst where cust_mst.custcd = mc20_dtl.custcd) as custname, " +
        "       mc20_dtl.jpno, mc20_dtl.seq, mc20_dtl.cdate, mc20_dtl.procdate, mc20_dtl.plandate, mc20_dtl.gubun, " +
        "       mc20_dtl.jepmkind, mc20_dtl.workkind, mc20_dtl.flow, mc20_dtl.nextflow, mc20_dtl.startflow, " +
        "       mc20_dtl.unit, mc20_dtl.jepmno, mc20_dtl.size, mc20_dtl.amt, mc20_dtl.qty, mc20_dtl.jisiqty, " +
        "       mc20_dtl.price, mc20_dtl.procchk, mc20_dtl.kind, mc20_dtl.prodcnt, mc20_dtl.docnt, " +
        "       (select frontcnt from jepm_info_flow where jepmno = mc20_dtl.jepmno and seq = substr(mc20_dtl.seq,3,1)) as frontcnt, " +
        "       (select backcnt  from jepm_info_flow where jepmno = mc20_dtl.jepmno and seq = substr(mc20_dtl.seq,3,1)) as backcnt, " +
        "       mc20_dtl.orderremk, mc20_dtl.remk, " +
        "       (if (select count(*) from mc20_plan where mc20_plan.mcjpno = mc20_dtl.jpno and mc20_plan.flowseq = mc20_dtl.seq " +
        "                                          and mc20_dtl.seq is not null and mc20_dtl.seq <> 0) > 0 then 'o' else '' endif) as chk " +
        "  FROM mc20_dtl " +
        " WHERE ( mc20_dtl.jpno = :jpno ) " +
        "   and ( mc20_dtl.gubun = '외주' ) " +
        " ORDER BY mc20_dtl.seq ASC";

    /** 지류 (왼쪽 4번째) */
    private static final String SQL_PAPER =
        "SELECT mc20_dtl.custcd, mc20_dtl.company, " +
        "       (select custname from cust_mst where cust_mst.custcd = mc20_dtl.custcd) as custname, " +
        "       isnull(trim(jepm_mst.jepmnm), '<<지류없음>>') as jepmnm, jepm_mst.kind as jkind, jepm_mst.jepmcd, jepm_mst.danwi, " +
        "       paper_info.jpno as jpno, mc20_dtl.jpno as dtl_jpno, mc20_dtl.seq, mc20_dtl.cdate, mc20_dtl.procdate, " +
        "       mc20_dtl.gubun, mc20_dtl.ok1, mc20_dtl.jepmkind, mc20_dtl.workkind, mc20_dtl.flow, mc20_dtl.jepmno, " +
        "       mc20_dtl.size, mc20_dtl.amt, mc20_dtl.okper, mc20_dtl.lossper, mc20_dtl.editper, mc20_dtl.qty, mc20_dtl.inqty, " +
        "       mc20_dtl.unit, mc20_dtl.price, mc20_dtl.proc1, mc20_dtl.kind, mc20_dtl.remk, " +
        "       0 as salesloss, '생산' as papmkind, 0 as jego " +
        "  FROM mc20_mst, paper_info " +
        "       left outer join mc20_dtl on mc20_dtl.jpno = paper_info.jpno and mc20_dtl.gubun = '지류' " +
        "       left outer join jepm_mst on mc20_dtl.jepmno = jepm_mst.jepmno " +
        " WHERE mc20_mst.jpno = paper_info.jpno " +
        "   and mc20_mst.jpno = :jpno " +
        " ORDER BY mc20_dtl.seq ASC";

    /** 청구현황 (오른쪽 3번째) — mc20_mst / jepm_mst 의 같은 이름 컬럼은 별칭 */
    private static final String SQL_TAX =
        "SELECT tax_dtl.jpno, tax_dtl.cdate, tax_dtl.sabun, tax_dtl.sabunnm, tax_dtl.custcd, cust_mst.custname, " +
        "       tax_dtl.subcustnm, tax_dtl.designnm1, tax_dtl.taxno, tax_dtl.jepmnm, tax_dtl.taxamt, tax_dtl.totamt, " +
        "       tax_dtl.loadjpno, tax_dtl.seq, tax_dtl.mcjpno, tax_dtl.orderno, tax_dtl.jepmno, " +
        "       tax_dtl.amt, tax_dtl.qty, tax_dtl.price, tax_dtl.remk, " +
        "       mc20_mst.orderno as mc_orderno, mc20_mst.cdate as mc_cdate, mc20_mst.sabunnm as mc_sabunnm, " +
        "       mc20_mst.deliverydate as mc_deliverydate, mc20_mst.qty as mc_qty, " +
        "       jepm_mst.jepmnm as jepm_jepmnm, jepm_mst.custjepmcd, jepm_mst.jepmcd " +
        "  FROM tax_dtl, mc20_mst, cust_mst, jepm_mst " +
        " WHERE ( tax_dtl.mcjpno = mc20_mst.jpno ) " +
        "   and ( tax_dtl.custcd = cust_mst.custcd ) " +
        "   and ( mc20_mst.jepmno = jepm_mst.jepmno ) " +
        "   and ( tax_dtl.mcjpno = :jpno ) " +
        " ORDER BY tax_dtl.cdate, cust_mst.custname";

    /** 외주 처리 내역 (오른쪽 4번째) */
    private static final String SQL_WOIJU_PLAN =
        "SELECT mc20_plan.jpno, mc20_plan.flowseq, mc20_plan.procdate, mc20_plan.custcd, " +
        "       (select custname from cust_mst where custcd = mc20_plan.custcd) as flowcustname, " +
        "       mc20_plan.proc3, mc20_plan.flow, 0 as price, mc20_plan.qty as qty, 0 as dtlamt, " +
        "       '' as loadremk, '' as loadjepmnm, '생산' as stat, " +
        "       (select kind from jepm_mst where jepm_mst.jepmno in (select jepmno from mc20_mst where mc20_mst.jpno = mc20_plan.mcjpno) group by kind) as kind " +
        "  FROM mc20_plan " +
        " WHERE mc20_plan.mcjpno in (select jpno from mc20_mst where mc20_mst.orderno = :orderno) " +
        "UNION ALL " +
        "SELECT '' jpno, '' seq, woiju_woijubi1.sdate procdate, '' custcd, " +
        "       woiju_woijubi1.woijucompany flowcustname, '' flowcost, woiju_woijubi1.workflow flow, " +
        "       woiju_woijubi1.danga as price, woiju_woijubi1.balju as qty, woiju_woijubi1.buy as dtlamt, " +
        "       '' loadremk, '' loadjepmnm, '' stat, woiju_woijubi1.workflow as kind " +
        "  FROM woiju_woijubi1 " +
        " WHERE woiju_woijubi1.woijuCheck = 'Y' " +
        "   and woiju_woijubi1.erpcode = :orderno";

    /** 지류 입고 (오른쪽 5번째) */
    private static final String SQL_PAPER_IN =
        "SELECT prod_dtl.jpno, prod_dtl.seq, prod_dtl.procdate, prod_dtl.custcd, " +
        "       (select custname from cust_mst where custcd = prod_dtl.custcd) as flowcustname, " +
        "       prod_dtl.flowcost, prod_dtl.flow, prod_dtl.price, prod_dtl.yeun, " +
        "       prod_dtl.wonji as wonji, prod_dtl.color as color, prod_dtl.qty, prod_dtl.amt as dtlamt, " +
        "       prod_dtl.loadremk, prod_dtl.jepmremk as loadjepmnm " +
        "  FROM prod_dtl " +
        " WHERE prod_dtl.orderno = :orderno " +
        "   and prod_dtl.kind = '지류' " +
        " ORDER BY procdate";

    // ------------------------------------------------------------------
    // 화면 (팝업)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3205_jepm_info.do")
    public String mes3205_jepm_info(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3205_jepm_info jpno=" + request.getParameter("jpno"));
        return "mes3205_jepm_info";
    }

    // ------------------------------------------------------------------
    // 데이터
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3205_jepm_info/data", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> data(@RequestParam(value = "jpno", defaultValue = "") String jpno, HttpSession session) {
        try {
            checkLogin(session);
            jpno = jpno == null ? "" : jpno.trim();
            if (jpno.isEmpty()) throw new IllegalArgumentException("전표번호(jpno)가 없습니다.");

            Map<String, Object> data   = new LinkedHashMap<String, Object>();
            Map<String, Object> errors = new LinkedHashMap<String, Object>();

            List<Map<String, Object>> head = query("head", SQL_HEAD, new MapSqlParameterSource("jpno", jpno), errors);
            if (head.isEmpty() && !errors.containsKey("head"))
                throw new IllegalArgumentException("수주 자료가 없습니다. (전표번호 " + jpno + ")");
            Map<String, Object> h = head.isEmpty() ? new LinkedHashMap<String, Object>() : head.get(0);
            data.put("head", h);

            // 관리번호 기준 구역은 상단 수주의 관리번호로 조회
            String orderno = h.get("orderno") == null ? "" : h.get("orderno").toString().trim();
            MapSqlParameterSource pj = new MapSqlParameterSource("jpno", jpno);
            MapSqlParameterSource po = new MapSqlParameterSource("orderno", orderno);
            List<Object> none = new ArrayList<Object>();

            data.put("wip",       orderno.isEmpty() ? none : query("wip",       SQL_WIP,        po, errors));
            data.put("woiju",     query("woiju", SQL_WOIJU, pj, errors));
            data.put("paper",     query("paper", SQL_PAPER, pj, errors));
            data.put("tax",       query("tax",   SQL_TAX,   pj, errors));
            data.put("woijuPlan", orderno.isEmpty() ? none : query("woijuPlan", SQL_WOIJU_PLAN, po, errors));
            data.put("paperIn",   orderno.isEmpty() ? none : query("paperIn",   SQL_PAPER_IN,   po, errors));
            data.put("errors", errors);
            return ok(data);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 구역별 조회 — 실패하면 errors 에 메시지를 담고 빈 목록 반환 */
    private List<Map<String, Object>> query(String name, String sql, MapSqlParameterSource p, Map<String, Object> errors) {
        try {
            return lower(jdbc.queryForList(sql, p));
        } catch (Exception e) {
            logger.error("mes3205_jepm_info " + name + " error", e);
            Throwable root = e;
            while (root.getCause() != null && root.getCause() != root) root = root.getCause();
            errors.put(name, root.getMessage() == null ? "조회 오류" : root.getMessage());
            return new ArrayList<Map<String, Object>>();
        }
    }

    // ------------------------------------------------------------------
    // 세션 / 응답
    // ------------------------------------------------------------------
    private void checkLogin(HttpSession session) {
        if (!(session.getAttribute(SESSION_USER) instanceof Map))
            throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
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
        logger.error("mes3205_jepm_info error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        if (e instanceof IllegalStateException) m.put("login", true);
        return m;
    }
}
