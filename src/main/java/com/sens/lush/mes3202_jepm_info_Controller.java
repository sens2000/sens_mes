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
 * mes3202_jepm_info 제품 사양 정보 (팝업, 조회 전용) — PB 사양서등록(제품 기준) 화면
 *  - 화면 : /mes3202_jepm_info.do?jepmno=...  → mes3202_jepm_info.jsp
 *  - 데이터 : /mes3202_jepm_info/data?jepmno=...
 *  - 다른 화면에서는 /WEB-INF/common/jepm_info_popup.jspf 를 include 하고 openJepmSpec(jepmno) 호출
 *
 *  head   기본정보 (jepm_info + jepm_mst 1건)
 *  flow   공정     (jepm_info_flow)
 *  paper  지류     (jepm_info_paper)
 *  log    변경정보 (jepm_info_log)
 *
 *  한 구역 쿼리가 실패해도 나머지는 보여주도록 구역별로 오류를 따로 담음 (errors)
 */
@Controller
public class mes3202_jepm_info_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3202_jepm_info_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // SQL
    // ------------------------------------------------------------------

    /** 기본정보 */
    private static final String SQL_HEAD =
        "SELECT cust_mst.custname, cust_dtl.custsectname, cust_mst.telno, " +
        "       jepm_info.company, jepm_info.gubun, jepm_info.remk, " +
        "       jepm_info.prdate, jepm_info.prtime, jepm_info.pruser, " +
        "       jepm_info.moddate, jepm_info.modtime, jepm_info.moduser, jepm_info.chk, " +
        "       jepm_info.custcd, jepm_info.custseqcd, jepm_info.jepmno, " +
        "       jepm_mst.jepmcd, jepm_mst.prodjepmno, j.jepmcd as prodjepmcd, jepm_mst.jepmnm, " +
        "       jepm_info.sabun, jepm_info.sabunnm, jepm_info.orderno, jepm_mst.custjepmcd, " +
        "       jepm_info.cdate, jepm_info.designer, jepm_info.designertelno, jepm_info.flowlist, " +
        "       jepm_mst.kind as jepmkind, jepm_mst.test as jepmgubun, " +
        "       jepm_info.cutwidth, jepm_info.cutlength, jepm_info.width, jepm_info.length, " +
        "       jepm_info.silwidth, jepm_info.sillength, jepm_info.height, " +
        "       jepm_info.sizejul, jepm_info.sizebu, jepm_info.pancnt, jepm_info.docnt, " +
        "       jepm_info.pantype, jepm_info.lentype, " +
        "       isnull(mc20_file.jpno, '') as filejpno, isnull(mc20_file.filename, '') as filename, " +
        "       isnull(mc_info.jpno, '') as mcinfojpno, isnull(mc_info.filename, '') as mcinfofilename " +
        "  FROM jepm_info, jepm_mst " +
        "       left outer join cust_mst          on cust_mst.custcd = jepm_info.custcd " +
        "       left outer join cust_dtl          on cust_dtl.custseqcd = jepm_info.custseqcd " +
        "       left outer join jepm_mst j        on j.jepmno = jepm_mst.prodjepmno " +
        "       left outer join mc20_file         on mc20_file.jpno = jepm_info.jepmno and mc20_file.seq = 0 " +
        "       left outer join mc20_file mc_info on mc_info.jpno = jepm_info.jepmno and mc_info.seq = 1 " +
        " WHERE ( jepm_info.jepmno = jepm_mst.jepmno ) " +
        "   and ( jepm_info.jepmno = :jepmno )";

    /** 공정 */
    private static final String SQL_FLOW =
        "SELECT jepm_info_flow.company, jepm_info_flow.custcd, " +
        "       (select custname from cust_mst where cust_mst.custcd = jepm_info_flow.custcd) as custname, " +
        "       jepm_info_flow.jepmno, jepm_info_flow.seq, jepm_info_flow.cdate, " +
        "       jepm_info_flow.workkind, jepm_info_flow.flow, jepm_info_flow.flowcd, jepm_info_flow.flowcdname, " +
        "       jepm_info_flow.frontcnt, jepm_info_flow.backcnt, jepm_info_flow.remk, jepm_info_flow.chk, " +
        "       jepm_info_flow.prdate, jepm_info_flow.prtime, jepm_info_flow.lossper " +
        "  FROM jepm_info_flow " +
        " WHERE ( jepm_info_flow.jepmno = :jepmno ) " +
        " ORDER BY jepm_info_flow.seq ASC";

    /** 지류 */
    private static final String SQL_PAPER =
        "SELECT jepm_info_paper.company, jepm_info_paper.jepmno, jepm_info_paper.seq, jepm_info_paper.cdate, " +
        "       jepm_info_paper.jajejepmno, jepm_mst.jepmcd, trim(jepm_mst.jepmnm) as jepmnm, jepm_mst.danwi, " +
        "       jepm_info_paper.workkind, jepm_info_paper.size, jepm_info_paper.unit, " +
        "       jepm_info_paper.width, jepm_info_paper.length, jepm_info_paper.chk, " +
        "       jepm_info_paper.prdate, jepm_info_paper.prtime " +
        "  FROM jepm_mst, jepm_info_paper " +
        " WHERE ( jepm_mst.jepmno = jepm_info_paper.jajejepmno ) " +
        "   and ( jepm_info_paper.jepmno = :jepmno ) " +
        " ORDER BY jepm_info_paper.seq ASC";

    /** 변경정보 */
    private static final String SQL_LOG =
        "SELECT jepm_info_log.jepmno, jepm_info_log.seq, jepm_info_log.kind, jepm_info_log.remk, " +
        "       jepm_info_log.prdate, jepm_info_log.prtime, jepm_info_log.pruser, " +
        "       jepm_info_log.moddate, jepm_info_log.modtime, jepm_info_log.moduser " +
        "  FROM jepm_info_log " +
        " WHERE jepm_info_log.jepmno = :jepmno " +
        " ORDER BY jepm_info_log.seq ASC";

    // ------------------------------------------------------------------
    // 화면 (팝업)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3202_jepm_info.do")
    public String mes3202_jepm_info(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3202_jepm_info jepmno=" + request.getParameter("jepmno"));
        return "mes3202_jepm_info";
    }

    // ------------------------------------------------------------------
    // 데이터 (4개 구역 한 번에)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3202_jepm_info/data", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> data(@RequestParam(value = "jepmno", defaultValue = "") String jepmno, HttpSession session) {
        try {
            checkLogin(session);
            jepmno = jepmno == null ? "" : jepmno.trim();
            if (jepmno.isEmpty()) throw new IllegalArgumentException("제품번호(jepmno)가 없습니다.");

            MapSqlParameterSource p = new MapSqlParameterSource("jepmno", jepmno);
            Map<String, Object> data   = new LinkedHashMap<String, Object>();
            Map<String, Object> errors = new LinkedHashMap<String, Object>();

            List<Map<String, Object>> head = query("head", SQL_HEAD, p, errors);
            if (head.isEmpty() && !errors.containsKey("head"))
                throw new IllegalArgumentException("제품 사양 자료가 없습니다. (제품번호 " + jepmno + ")");
            data.put("head",   head.isEmpty() ? new LinkedHashMap<String, Object>() : head.get(0));
            data.put("flow",   query("flow",  SQL_FLOW,  p, errors));
            data.put("paper",  query("paper", SQL_PAPER, p, errors));
            data.put("log",    query("log",   SQL_LOG,   p, errors));
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
            logger.error("mes3202_jepm_info " + name + " error", e);
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
        logger.error("mes3202_jepm_info error", e);
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
