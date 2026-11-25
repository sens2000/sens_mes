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
 * mes0105_cust_mst 거래처 (팝업, 지금은 조회 전용) — PB 거래처 등록 화면
 *  - 화면 : /mes0105_cust_mst.do?custcd=...  → mes0105_cust_mst.jsp
 *  - 데이터 : /mes0105_cust_mst/data?custcd=...
 *  - mes0105 목록 더블클릭 → 그 줄의 custcd 로 열림 (openCustMst(custcd), jepm_info_popup.jspf)
 *
 *  head  거래처 1건 (cust_mst). 비밀번호는 화면에 보내지 않고 있는지(haspass)만 보냄
 *  dtl   거래처 부서 (cust_dtl)
 */
@Controller
public class mes0105_cust_mst_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes0105_cust_mst_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // SQL
    // ------------------------------------------------------------------
    private static final String SQL_HEAD =
        "SELECT cust_mst.company, cust_mst.custcd, cust_mst.custname, cust_mst.sabun, cust_mst.sabunnm, " +
        "       cust_mst.positioncd, cust_mst.mimc, cust_mst.owner, cust_mst.taxname, cust_mst.sano, " +
        "       cust_mst.uptae, cust_mst.upjong, cust_mst.post, cust_mst.addr1, cust_mst.addr2, " +
        "       cust_mst.telno, cust_mst.faxno, cust_mst.lastdate, cust_mst.prdate, cust_mst.gubun, cust_mst.chk, " +
        "       cust_mst.manager, cust_mst.taxgubun, cust_mst.tax, cust_mst.remk, cust_mst.userid, " +
        "       (if isnull(cust_mst.password,'') = '' then 'N' else 'Y' endif) as haspass, " +
        "       cust_mst.term " +
        "  FROM cust_mst " +
        " WHERE cust_mst.custcd = :custcd";

    private static final String SQL_DTL =
        "SELECT cust_dtl.custcd, cust_dtl.seq, cust_dtl.telno, cust_dtl.custsect, cust_dtl.custsectname, " +
        "       cust_dtl.custmanager, cust_dtl.sect, cust_dtl.sectname, cust_dtl.sabun, cust_dtl.sabunnm, " +
        "       cust_dtl.custseqcd, cust_dtl.chk " +
        "  FROM cust_dtl " +
        " WHERE cust_dtl.custcd = :custcd " +
        " ORDER BY cust_dtl.seq ASC";

    // ------------------------------------------------------------------
    // 화면 (팝업)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0105_cust_mst.do")
    public String mes0105_cust_mst(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes0105_cust_mst custcd=" + request.getParameter("custcd"));
        return "mes0105_cust_mst";
    }

    // ------------------------------------------------------------------
    // 데이터
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes0105_cust_mst/data", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> data(@RequestParam(value = "custcd", defaultValue = "") String custcd, HttpSession session) {
        try {
            checkLogin(session);
            custcd = custcd == null ? "" : custcd.trim();
            if (custcd.isEmpty()) throw new IllegalArgumentException("거래처코드(custcd)가 없습니다.");

            Map<String, Object> data   = new LinkedHashMap<String, Object>();
            Map<String, Object> errors = new LinkedHashMap<String, Object>();
            MapSqlParameterSource p = new MapSqlParameterSource("custcd", custcd);

            List<Map<String, Object>> head = query("head", SQL_HEAD, p, errors);
            if (head.isEmpty() && !errors.containsKey("head"))
                throw new IllegalArgumentException("거래처 자료가 없습니다. (거래처코드 " + custcd + ")");
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
            logger.error("mes0105_cust_mst " + name + " error", e);
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
        logger.error("mes0105_cust_mst error", e);
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
