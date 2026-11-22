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
 * mes0201_jepm_jego 사양서출고 확인 (팝업, 조회 전용) — PB 사양서출고 화면
 *  - 화면 : /mes0201_jepm_jego.do?jpno=...&orderno=...  → mes0201_jepm_jego.jsp
 *  - 데이터 : /mes0201_jepm_jego/data?jpno=...&orderno=...
 *  - 다른 화면에서는 /WEB-INF/common/jepm_info_popup.jspf 를 include 하고 openJepmJego(jpno, orderno) 호출
 *
 *  head      출고 내용 (mc20_mst 1건)
 *  delivery  납품현황  (delivery_dtl, 관리번호 기준)
 *  tax       청구현황  (tax_dtl, 전표번호 기준)
 *
 *  한 구역 쿼리가 실패해도 나머지는 보여주도록 구역별로 오류를 따로 담음 (errors)
 */
@Controller
public class mes0201_jepm_jego_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes0201_jepm_jego_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // SQL
    // ------------------------------------------------------------------

    /** 출고 내용 */
    private static final String SQL_HEAD =
        "SELECT cust_mst.custname, cust_dtl.custsectname, cust_mst.telno, " +
        "       mc20_mst.company, mc20_mst.jpno, mc20_mst.mstjpno, mc20_mst.wonjpno, " +
        "       mc20_mst.wonjepmno, wonjepm_mst.wonjepmcd, " +
        "       mc20_mst.amt, mc20_mst.datagubun, mc20_mst.kind, mc20_mst.jepminfo, mc20_mst.remk, mc20_mst.returnmsg, " +
        "       mc20_mst.prdate, mc20_mst.prtime, mc20_mst.pruser, mc20_mst.custcd, mc20_mst.custseqcd, " +
        "       mc20_mst.jepmno, jepm_mst.jepmcd, mc20_mst.jepmnm, mc20_mst.sabun, mc20_mst.sabunnm, " +
        "       mc20_mst.oldorderno, mc20_mst.orderno, mc20_mst.setno, " +
        "       mc20_mst.qty, mc20_mst.addqty, mc20_mst.totqty, " +
        "       (select orderno from mc20_mst won_mst where won_mst.jpno = mc20_mst.mstjpno) as fromorderno, " +
        "       (select totqty  from mc20_mst won_mst where won_mst.jpno = mc20_mst.mstjpno) as wonorderqty, " +
        "       mc20_mst.price, mc20_mst.restqty, mc20_mst.ok1, mc20_mst.ok2, mc20_mst.ok3, " +
        "       mc20_mst.paperjpno, mc20_mst.makejpno, mc20_mst.outjpno, " +
        "       mc20_mst.cdate, mc20_mst.deliverydate, mc20_mst.deliveryok, mc20_mst.keepsite, " +
        "       (select custname from cust_mst cust_keep where cust_keep.custcd = mc20_mst.keepsite) as keepname, " +
        "       mc20_mst.custjepmcd, mc20_mst.pocode, mc20_mst.jepmgubun, " +
        "       mc20_mst.designer, mc20_mst.designertelno, mc20_mst.flowlist, mc20_mst.taxgubun, mc20_mst.kind1, " +
        "       jepm_mst.kind as jepmkind, " +
        "       mc20_mst.papmkind, mc20_mst.papmmsg, mc20_mst.wonorderno, " +
        "       mc20_mst.bill_call, mc20_mst.call_date, mc20_mst.biddate, mc20_mst.codeno, mc20_mst.pono_gu, mc20_mst.loadjpno, " +
        "       0 as jego, " +
        "       isnull(mc20_file.jpno, '') as filejpno, " +
        "       isnull(mc20_file.filename, '') as filename, " +
        "       (select list(trim(distinct tax_dtl.cdate)) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxyymm, " +
        "       (select sum(tax_dtl.amt) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxamt, " +
        "       (select sum(tax_dtl.qty) from tax_dtl where tax_dtl.mcjpno = mc20_mst.jpno) as taxqty, " +
        "       (select sum(qty) from mc20_dtl dtl where dtl.jpno = mc20_mst.jpno and dtl.gubun = '납품') as makeqty " +
        "  FROM cust_mst, cust_dtl, mc20_mst, jepm_mst " +
        "       left outer join mc20_file   on mc20_file.jpno = mc20_mst.jpno " +
        "       left outer join wonjepm_mst on wonjepm_mst.wonjepmno = mc20_mst.wonjepmno " +
        " WHERE ( cust_mst.custcd = mc20_mst.custcd ) " +
        "   and ( cust_mst.custcd = cust_dtl.custcd ) " +
        "   and ( mc20_mst.custseqcd = cust_dtl.custseqcd ) " +
        "   and ( mc20_mst.jepmno = jepm_mst.jepmno ) " +
        "   and ( mc20_mst.jpno = :jpno ) " +
        " ORDER BY cust_mst.custname, mc20_mst.jpno ASC";

    /** 납품현황 (왼쪽 아래) */
    private static final String SQL_DELIVERY =
        "SELECT delivery_dtl.company, delivery_dtl.jpno, delivery_dtl.orderno, " +
        "       delivery_dtl.prsabun, delivery_dtl.prsabunnm, delivery_dtl.custcd, delivery_dtl.custseqcd, " +
        "       delivery_dtl.jepmno, delivery_dtl.orderdate, delivery_dtl.orderqty, delivery_dtl.deliverydate, " +
        "       delivery_dtl.loadjpno, " +
        "       (select sum(deliveryqty) from delivery_dtl dd where dd.orderno = delivery_dtl.orderno) as deliverysum, " +
        "       isnull((select sum(deliveryqty) from delivery_dtl dd where dd.orderno = delivery_dtl.orderno and dd.jpno <> delivery_dtl.jpno), 0) as exceptdeliverysum, " +
        "       delivery_dtl.deliveryqty, delivery_dtl.deliveryplace, delivery_dtl.procdate, delivery_dtl.remk, " +
        "       delivery_dtl.mstjpno, delivery_dtl.proc1, delivery_dtl.proc2, delivery_dtl.proc3, " +
        "       delivery_dtl.prdate, delivery_dtl.prtime, " +
        "       isnull(delivery_auth.jpno, '') as delivery_auth_jpno, " +
        "       isnull(delivery_list.listjpno, '') as delivery_list_jpno, " +
        "       (if delivery_dtl.loadjpno = '' then '' else '엑셀' endif) as excelchk " +
        "  FROM delivery_dtl " +
        "       left outer join delivery_auth on delivery_auth.jpno = delivery_dtl.jpno " +
        "       left outer join delivery_list on delivery_list.jpno = delivery_dtl.jpno " +
        " WHERE ( delivery_dtl.orderno = :orderno ) " +
        " ORDER BY delivery_dtl.prdate, delivery_dtl.prtime";

    /** 청구현황 (오른쪽 아래) — tax_dtl / mc20_mst / jepm_mst 의 같은 이름 컬럼은 별칭으로 구분 */
    private static final String SQL_TAX =
        "SELECT cust_mst.custname, tax_dtl.subcustnm, tax_dtl.designnm1, tax_dtl.taxno, tax_dtl.jepmnm, " +
        "       tax_dtl.taxamt, tax_dtl.totamt, tax_dtl.loadjpno, tax_dtl.jpno, tax_dtl.seq, tax_dtl.cdate, " +
        "       tax_dtl.custcd, tax_dtl.mcjpno, tax_dtl.orderno, tax_dtl.jepmno, " +
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

    // ------------------------------------------------------------------
    // 화면 (팝업)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201_jepm_jego.do")
    public String mes0201_jepm_jego(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes0201_jepm_jego jpno=" + request.getParameter("jpno"));
        return "mes0201_jepm_jego";
    }

    // ------------------------------------------------------------------
    // 데이터 (3개 구역 한 번에)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0201_jepm_jego/data", method = RequestMethod.GET)
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

            List<Map<String, Object>> head = query("head", SQL_HEAD, new MapSqlParameterSource("jpno", jpno), errors);
            if (head.isEmpty() && !errors.containsKey("head"))
                throw new IllegalArgumentException("출고 자료가 없습니다. (전표번호 " + jpno + ")");
            Map<String, Object> h = head.isEmpty() ? new LinkedHashMap<String, Object>() : head.get(0);
            data.put("head", h);

            // 관리번호가 안 넘어왔으면 출고 전표의 관리번호 사용
            if (orderno.isEmpty() && h.get("orderno") != null) orderno = h.get("orderno").toString().trim();

            data.put("delivery", orderno.isEmpty() ? new ArrayList<Object>()
                                 : query("delivery", SQL_DELIVERY, new MapSqlParameterSource("orderno", orderno), errors));
            data.put("tax",      query("tax", SQL_TAX, new MapSqlParameterSource("jpno", jpno), errors));
            data.put("errors",   errors);
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
            logger.error("mes0201_jepm_jego " + name + " error", e);
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
        logger.error("mes0201_jepm_jego error", e);
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
