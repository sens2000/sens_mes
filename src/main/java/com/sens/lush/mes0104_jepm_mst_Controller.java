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
 * mes0104_jepm_mst 제품 등록 (팝업, 지금은 조회 전용) — PB 제품등록 화면
 *  - 화면 : /mes0104_jepm_mst.do?jepmno=...  → mes0104_jepm_mst.jsp
 *  - 데이터 : /mes0104_jepm_mst/data?jepmno=...
 *  - mes0104 목록 더블클릭 → 그 줄의 jegongno 로 열림 (openJepmMst(jepmno), jepm_info_popup.jspf)
 *
 *  head  제품 1건 (완제품 j.jepmcd / j.jepmnm 은 이름이 겹쳐서 prodjepmcd / prodjepmnm)
 *  dtl   이 제품에 붙은 재공품 (prodjepmno = jepmno, chk = 'Y')
 */
@Controller
public class mes0104_jepm_mst_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes0104_jepm_mst_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // SQL
    // ------------------------------------------------------------------
    private static final String SQL_HEAD =
        "SELECT jepm_mst.company, jepm_mst.jepmno, jepm_mst.kind, jepm_mst.jepmcd, jepm_mst.jepmnm, jepm_mst.test, " +
        "       jepm_mst.prdate, jepm_mst.pruser, jepm_mst.chk, jepm_mst.danwi, jepm_mst.unitper, jepm_mst.remk, " +
        "       jepm_mst.sizewidth, jepm_mst.sizelength, jepm_mst.custcd, jepm_mst.goodcode, jepm_mst.custjepmcd, " +
        "       jepm_mst.subcode, cust_mst.custname, jepm_mst.prodjepmno, jepm_mst.orderkind, " +
        "       j.jepmcd as prodjepmcd, j.jepmnm as prodjepmnm " +
        "  FROM jepm_mst " +
        "       left outer join cust_mst on cust_mst.custcd = jepm_mst.custcd " +
        "       left outer join jepm_mst j on j.jepmno = jepm_mst.prodjepmno " +
        " WHERE jepm_mst.jepmno = :jepmno";

    private static final String SQL_DTL =
        "SELECT jepm_mst.company, jepm_mst.jepmno, jepm_mst.kind, jepm_mst.jepmcd, jepm_mst.custjepmcd, " +
        "       jepm_mst.goodcode, jepm_mst.jepmnm, jepm_mst.test, jepm_mst.prdate, jepm_mst.pruser, jepm_mst.chk, " +
        "       jepm_mst.danwi, jepm_mst.remk, jepm_mst.sizewidth, jepm_mst.sizelength, jepm_mst.custcd, jepm_mst.prodjepmno " +
        "  FROM jepm_mst " +
        " WHERE jepm_mst.prodjepmno = :jepmno " +
        "   and jepm_mst.chk = 'Y' " +
        " ORDER BY jepm_mst.kind, jepm_mst.jepmcd";

    // ------------------------------------------------------------------
    // 화면 (팝업)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0104_jepm_mst.do")
    public String mes0104_jepm_mst(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes0104_jepm_mst jepmno=" + request.getParameter("jepmno"));
        return "mes0104_jepm_mst";
    }

    // ------------------------------------------------------------------
    // 데이터
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0104_jepm_mst/data", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> data(@RequestParam(value = "jepmno", defaultValue = "") String jepmno, HttpSession session) {
        try {
            checkLogin(session);
            jepmno = jepmno == null ? "" : jepmno.trim();
            if (jepmno.isEmpty()) throw new IllegalArgumentException("제품번호(jepmno)가 없습니다.");

            Map<String, Object> data   = new LinkedHashMap<String, Object>();
            Map<String, Object> errors = new LinkedHashMap<String, Object>();
            MapSqlParameterSource p = new MapSqlParameterSource("jepmno", jepmno);

            List<Map<String, Object>> head = query("head", SQL_HEAD, p, errors);
            if (head.isEmpty() && !errors.containsKey("head"))
                throw new IllegalArgumentException("제품 자료가 없습니다. (제품번호 " + jepmno + ")");
            data.put("head",   head.isEmpty() ? new LinkedHashMap<String, Object>() : head.get(0));
            data.put("dtl",    query("dtl", SQL_DTL, p, errors));
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
            logger.error("mes0104_jepm_mst " + name + " error", e);
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
        logger.error("mes0104_jepm_mst error", e);
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
