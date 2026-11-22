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
 * mes0201_jepm_info 사양서 확인 (팝업, 조회 전용) — PB 사양서등록 화면
 *  - 화면 : /mes0201_jepm_info.do?jpno=...&orderno=...  → mes0201_jepm_info.jsp
 *  - 데이터 : /mes0201_jepm_info/data?jpno=...&orderno=...
 *  - 다른 화면에서는 /WEB-INF/common/jepm_info_popup.jspf 를 include 하고 openJepmInfo(jpno, orderno) 호출
 *
 *  head      견적      (mc20_mst 1건)
 *  spec      사양      (paper_info)
 *  woiju     외주      (mc20_dtl gubun='외주')
 *  woijuPlan 외주 오른쪽 (mc20_plan + woiju_woijubi1, 관리번호 기준)
 *  paper     지류      (mc20_dtl gubun='지류')
 *  paperOut  지류 오른쪽 (paper_jego_dtl 출고, 관리번호 기준)
 *
 *  한 구역 쿼리가 실패해도 나머지는 보여주도록 구역별로 오류를 따로 담음 (errors)
 */
@Controller
public class mes0201_jepm_info_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes0201_jepm_info_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // SQL
    // ------------------------------------------------------------------

    /** 견적 */
    private static final String SQL_HEAD =
        "SELECT cust_mst.custname, cust_dtl.custsectname, cust_mst.telno, " +
        "       mc20_mst.company, mc20_mst.jpno, mc20_mst.amt, mc20_mst.datagubun, mc20_mst.kind, mc20_mst.kind1, " +
        "       mc20_mst.papmkind, mc20_mst.remk, mc20_mst.returnmsg, mc20_mst.prdate, mc20_mst.prtime, mc20_mst.pruser, " +
        "       mc20_mst.custcd, mc20_mst.custseqcd, mc20_mst.wonjepmno, wonjepm_mst.wonjepmcd, " +
        "       mc20_mst.jepmno, jepm_mst.jepmcd, mc20_mst.jepmnm, mc20_mst.sabun, mc20_mst.sabunnm, " +
        "       mc20_mst.oldorderno, mc20_mst.orderloadjpno, mc20_mst.orderno, mc20_mst.setno, " +
        "       mc20_mst.qty, mc20_mst.addqty, mc20_mst.totqty, mc20_mst.price, mc20_mst.restqty, " +
        "       mc20_mst.ok1, mc20_mst.ok2, mc20_mst.ok3, mc20_mst.paperjpno, mc20_mst.makejpno, mc20_mst.outjpno, " +
        "       mc20_mst.cdate, mc20_mst.deliverydate, mc20_mst.deliveryok, mc20_mst.keepsite, " +
        "       (select custname from cust_mst cust_keep where cust_keep.custcd = mc20_mst.keepsite) as keepname, " +
        "       isnull((select count(*) from mc20_mst mc_out where mc_out.wonjpno = mc20_mst.jpno), 0) as outcnt, " +
        "       mc20_mst.wonorderno, mc20_mst.papmmsg, mc20_mst.custjepmcd, mc20_mst.pocode, mc20_mst.gubun, " +
        "       mc20_mst.jepmgubun, mc20_mst.designer, mc20_mst.designertelno, mc20_mst.flowlist, " +
        "       mc20_mst.taxgubun, mc20_mst.sheet_chk, " +
        "       jepm_mst.kind as jepmkind, " +
        "       0 as jego, " +
        "       isnull(mc20_file.jpno, '') as filejpno, " +
        "       isnull(mc20_file.filename, '') as filename, " +
        "       (select list(trim(distinct tax_dtl.cdate)) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxyymm, " +
        "       (select sum(tax_dtl.amt) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxamt, " +
        "       (select sum(tax_dtl.qty) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxqty, " +
        "       (select sum(deliveryqty) from delivery_dtl dtl where dtl.orderno = mc20_mst.orderno) as makeqty " +
        "  FROM cust_mst, cust_dtl, mc20_mst, jepm_mst " +
        "       left outer join wonjepm_mst on wonjepm_mst.wonjepmno = mc20_mst.wonjepmno " +
        "       left outer join mc20_file   on mc20_file.jpno = mc20_mst.jpno " +
        " WHERE ( cust_mst.custcd = mc20_mst.custcd ) " +
        "   and ( cust_mst.custcd = cust_dtl.custcd ) " +
        "   and ( mc20_mst.custseqcd = cust_dtl.custseqcd ) " +
        "   and ( mc20_mst.jepmno = jepm_mst.jepmno ) " +
        "   and ( mc20_mst.jpno = :jpno ) " +
        " ORDER BY cust_mst.custname, mc20_mst.jpno ASC";

    /** 사양 */
    private static final String SQL_SPEC =
        "SELECT trim(jepm_mst.jepmnm) as jepmnm, jepm_mst.kind as jkind, jepm_mst.danwi, jepm_mst.jepmcd, " +
        "       paper_info.company, paper_info.jpno, paper_info.seq, paper_info.cdate, paper_info.jepmno, " +
        "       paper_info.jepmkind, paper_info.workkind, paper_info.cutwidth, paper_info.cutlength, " +
        "       paper_info.sizepage, paper_info.sizejul, paper_info.sizebu, " +
        "       paper_info.panfront, paper_info.panback, paper_info.dofront, paper_info.doback, " +
        "       paper_info.kind, paper_info.remk, paper_info.estimapaper " +
        "  FROM jepm_mst, paper_info " +
        " WHERE ( paper_info.jepmno = jepm_mst.jepmno ) " +
        "   and ( paper_info.jpno = :jpno ) " +
        " ORDER BY paper_info.seq ASC";

    /** 외주 */
    private static final String SQL_WOIJU =
        "SELECT mc20_dtl.company, mc20_dtl.custcd, " +
        "       (select custname from cust_mst where cust_mst.custcd = mc20_dtl.custcd) as custname, " +
        "       mc20_dtl.jpno, mc20_dtl.seq, mc20_dtl.cdate, mc20_dtl.procdate, mc20_dtl.plandate, mc20_dtl.gubun, " +
        "       mc20_dtl.jepmkind, mc20_dtl.workkind, mc20_dtl.flow, mc20_dtl.nextflow, mc20_dtl.startflow, " +
        "       mc20_dtl.unit, mc20_dtl.jepmno, mc20_dtl.size, mc20_dtl.amt, mc20_dtl.qty, mc20_dtl.jisiqty, " +
        "       mc20_dtl.price, mc20_dtl.procchk, mc20_dtl.kind, mc20_dtl.prodcnt, mc20_dtl.docnt, " +
        "       (select frontcnt from jepm_info_flow where jepmno = mc20_dtl.jepmno and seq = substr(mc20_dtl.seq,3,1)) frontcnt, " +
        "       (select backcnt  from jepm_info_flow where jepmno = mc20_dtl.jepmno and seq = substr(mc20_dtl.seq,3,1)) backcnt, " +
        "       mc20_dtl.orderremk, mc20_dtl.remk, " +
        "       (if (select top 1 jpno from plan_seq where plan_seq.jpno = mc20_dtl.jpno and plan_seq.seq = mc20_dtl.seq) = '' then '' else 'o' endif) as chk, " +
        "       (select mc20_mst.qty from mc20_mst where mc20_mst.jpno = mc20_dtl.jpno) as mstqty, " +
        "       (select sizebu from paper_info where paper_info.jpno = mc20_dtl.jpno and paper_info.seq = mc20_dtl.seq) as sizebu " +
        "  FROM mc20_dtl " +
        "       left outer join mc20_plan on mc20_dtl.jpno = mc20_plan.mcjpno and mc20_dtl.seq = mc20_plan.flowseq " +
        " WHERE ( mc20_dtl.jpno = :jpno ) " +
        "   and ( mc20_dtl.gubun = '외주' ) " +
        " GROUP BY mc20_dtl.company, mc20_dtl.custcd, custname, mc20_dtl.jpno, mc20_dtl.seq, mc20_dtl.cdate, " +
        "       mc20_dtl.procdate, mc20_dtl.plandate, mc20_dtl.gubun, mc20_dtl.jepmkind, mc20_dtl.workkind, " +
        "       mc20_dtl.flow, mc20_dtl.nextflow, mc20_dtl.startflow, mc20_dtl.unit, mc20_dtl.jepmno, mc20_dtl.size, " +
        "       mc20_dtl.amt, mc20_dtl.qty, mc20_dtl.jisiqty, mc20_dtl.price, mc20_dtl.procchk, mc20_dtl.kind, " +
        "       mc20_dtl.prodcnt, mc20_dtl.docnt, frontcnt, backcnt, mc20_dtl.orderremk, mc20_dtl.remk, mstqty, sizebu " +
        " ORDER BY mc20_dtl.seq ASC";

    /** 외주 오른쪽 */
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

    /** 지류 */
    private static final String SQL_PAPER =
        "SELECT mc20_dtl.custcd, mc20_dtl.company, " +
        "       (select custname from cust_mst where cust_mst.custcd = mc20_dtl.custcd) as custname, " +
        "       trim(jepm_mst.jepmnm) as jepmnm, jepm_mst.jepmcd, jepm_mst.kind as jkind, jepm_mst.danwi, " +
        "       mc20_dtl.jpno, mc20_dtl.seq, mc20_dtl.cdate, mc20_dtl.orderdate, mc20_dtl.plandate, mc20_dtl.procdate, " +
        "       mc20_dtl.ok1, mc20_dtl.gubun, mc20_dtl.jepmkind, mc20_dtl.workkind, mc20_dtl.flow, mc20_dtl.jepmno, " +
        "       mc20_dtl.size, mc20_dtl.amt, mc20_dtl.okper, mc20_dtl.lossper, mc20_dtl.editper, " +
        "       mc20_dtl.qty, mc20_dtl.inqty, mc20_dtl.unit, mc20_dtl.price, mc20_dtl.kind, mc20_dtl.proc1, mc20_dtl.remk " +
        "  FROM jepm_mst, mc20_dtl " +
        " WHERE ( jepm_mst.jepmno = mc20_dtl.jepmno ) " +
        "   and ( mc20_dtl.jpno = :jpno ) " +
        "   and ( mc20_dtl.gubun = '지류' ) " +
        " ORDER BY mc20_dtl.seq ASC";

    /** 지류 오른쪽 */
    private static final String SQL_PAPER_OUT =
        "SELECT cdate, papernm, flow_gubun, exelqty, pruser, amt " +
        "  FROM paper_jego_dtl " +
        " WHERE etc1 = :orderno " +
        "   and gubun = '출고' " +
        " ORDER BY cdate";

    // ------------------------------------------------------------------
    // 화면 (팝업)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201_jepm_info.do")
    public String mes0201_jepm_info(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes0201_jepm_info jpno=" + request.getParameter("jpno"));
        return "mes0201_jepm_info";
    }

    // ------------------------------------------------------------------
    // 데이터 (6개 구역 한 번에)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201_jepm_info/data", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> data(@RequestParam(value = "jpno", defaultValue = "") String jpno,
                                    @RequestParam(value = "orderno", defaultValue = "") String orderno,
                                    HttpSession session) {
        try {
            checkLogin(session);
            jpno = trim(jpno);
            orderno = trim(orderno);
            if (jpno.isEmpty()) throw new IllegalArgumentException("전표번호(jpno)가 없습니다.");

            Map<String, Object> data   = new LinkedHashMap<String, Object>();
            Map<String, Object> errors = new LinkedHashMap<String, Object>();

            // 견적
            List<Map<String, Object>> head = query("head", SQL_HEAD, new MapSqlParameterSource("jpno", jpno), errors);
            if (head.isEmpty() && !errors.containsKey("head"))
                throw new IllegalArgumentException("사양서 자료가 없습니다. (전표번호 " + jpno + ")");
            Map<String, Object> h = head.isEmpty() ? new LinkedHashMap<String, Object>() : head.get(0);
            data.put("head", h);

            // 관리번호가 안 넘어왔으면 견적의 관리번호 사용
            if (orderno.isEmpty() && h.get("orderno") != null) orderno = h.get("orderno").toString().trim();

            MapSqlParameterSource pj = new MapSqlParameterSource("jpno", jpno);
            MapSqlParameterSource po = new MapSqlParameterSource("orderno", orderno);

            data.put("spec",      query("spec",      SQL_SPEC,       pj, errors));
            data.put("woiju",     query("woiju",     SQL_WOIJU,      pj, errors));
            data.put("woijuPlan", orderno.isEmpty() ? new ArrayList<Object>() : query("woijuPlan", SQL_WOIJU_PLAN, po, errors));
            data.put("paper",     query("paper",     SQL_PAPER,      pj, errors));
            data.put("paperOut",  orderno.isEmpty() ? new ArrayList<Object>() : query("paperOut",  SQL_PAPER_OUT,  po, errors));
            data.put("errors",    errors);
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
            logger.error("mes0201_jepm_info " + name + " error", e);
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
        logger.error("mes0201_jepm_info error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        if (e instanceof IllegalStateException) m.put("login", true);
        return m;
    }

    private static String trim(String s) { return s == null ? "" : s.trim(); }
}
