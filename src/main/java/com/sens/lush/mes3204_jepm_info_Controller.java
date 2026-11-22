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
 * mes3204_jepm_info 수주 정보 (팝업, 조회 전용) — PB 수주 등록 화면
 *  - 화면 : /mes3204_jepm_info.do?jpno=...  → mes3204_jepm_info.jsp
 *  - 데이터 : /mes3204_jepm_info/data?jpno=...
 *  - 다른 화면에서는 /WEB-INF/common/jepm_info_popup.jspf 를 include 하고 openJepmOrder(jpno) 호출
 *
 *  head  수주 내용 (mc20_mst 1건)
 *  jepm_mst.kind 는 mc20_mst.kind 와 이름이 겹쳐서 jepmkind 로 별칭
 */
@Controller
public class mes3204_jepm_info_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3204_jepm_info_Controller(DataSource dataSource) {
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

    // ------------------------------------------------------------------
    // 화면 (팝업)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3204_jepm_info.do")
    public String mes3204_jepm_info(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3204_jepm_info jpno=" + request.getParameter("jpno"));
        return "mes3204_jepm_info";
    }

    // ------------------------------------------------------------------
    // 데이터
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3204_jepm_info/data", method = RequestMethod.GET)
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
            data.put("head",   head.isEmpty() ? new LinkedHashMap<String, Object>() : head.get(0));
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
            logger.error("mes3204_jepm_info " + name + " error", e);
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
        logger.error("mes3204_jepm_info error", e);
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
