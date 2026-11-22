package com.sens.lush;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpSession;
import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.support.SQLStateSQLExceptionTranslator;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 사양서 확정 / 결재 / 반려 처리 (공통) — 여러 화면에서 같이 씀
 *  - POST /mes_sign/confirm  (jpno)   확정
 *  - POST /mes_sign/approve  (jpno)   결재
 *  - POST /mes_sign/reject   (jpno)   반려
 *  - 화면에서는 /WEB-INF/common/mes_sign.jspf 를 include 하고 confirmJepm / signJepm / rejectJepm (jpno) 호출
 *
 *  처리 (한 트랜잭션 — 하나라도 실패하면 모두 취소)
 *   ※ jConnect 는 setAutoCommit(false) 때 메타데이터 테이블이 없으면 JZ0SJ 오류가 나므로
 *     Spring 트랜잭션 대신 SQL 로 BEGIN TRANSACTION / COMMIT / ROLLBACK 을 직접 보냄
 *   1) mc20_mst 에서 jpno 의 관리번호(orderno) 확인
 *   2) log_data INSERT  (gubun='사양서', tbl='mc20_mst', datagubun='확정'·'결재'·'반려', remk=관리번호)
 *   3) UPDATE mc20_mst SET ok1 = '확정'·'결재'·'반려' WHERE jpno = 전표번호   (해당 전표 1건만)
 *
 *  세션 USER 사용 키 : COMPANY(회사), SECTNAME(부서), NAME(처리자), CODE(사번)
 */
@Controller
public class mes_sign_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes_sign_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final String SQL_ORDERNO =
        "SELECT orderno, ok1 FROM mc20_mst WHERE jpno = :jpno AND company = :company";

    /** ? 순서 : jpkey, company, sectname, jpno, ok1, orderno, pruser, sabun */
    private static final String SQL_LOG =
        "INSERT INTO log_data " +
        "       ( jpkey, company, sectname, jpno, gubun, tbl, datagubun, remk, prdate, prtime, pruser, sabun ) " +
        "VALUES ( ?, ?, ?, ?, '사양서', 'mc20_mst', ?, ?, " +
        "         dateformat(now(*), 'yyyymmdd'), dateformat(now(*), 'hhnn'), ?, ? )";

    /** ? 순서 : ok1, jpno, company */
    private static final String SQL_SIGN =
        "UPDATE mc20_mst SET ok1 = ? WHERE jpno = ? AND company = ?";

    // ------------------------------------------------------------------
    // 확정 / 결재 / 반려
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes_sign/confirm", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> confirm(@RequestParam(value = "jpno", defaultValue = "") String jpno, HttpSession session) {
        return process(jpno, "확정", session);
    }

    @RequestMapping(value = "/mes_sign/approve", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> approve(@RequestParam(value = "jpno", defaultValue = "") String jpno, HttpSession session) {
        return process(jpno, "결재", session);
    }

    @RequestMapping(value = "/mes_sign/reject", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> reject(@RequestParam(value = "jpno", defaultValue = "") String jpno, HttpSession session) {
        return process(jpno, "반려", session);
    }

    /** ok1 : '확정' / '결재' / '반려' — log_data.datagubun 과 mc20_mst.ok1 에 같이 들어감 */
    private Map<String, Object> process(String jpno, final String ok1, HttpSession session) {
        try {
            Map<?, ?> user = user(session);
            final String company = str(user.get("COMPANY"));
            if (company.isEmpty()) throw new IllegalArgumentException("로그인 정보(회사코드)가 없습니다. 세션 USER 의 COMPANY 키를 확인하세요.");
            final String no = str(jpno);
            if (no.isEmpty()) throw new IllegalArgumentException("전표번호(jpno)가 없습니다.");

            final MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("jpno", no)
                .addValue("ok1", ok1)
                .addValue("company", company)
                .addValue("sectname", str(user.get("SECTNAME")))
                .addValue("pruser", str(user.get("NAME")))
                .addValue("sabun", str(user.get("CODE")));

            // 1) 관리번호 확인
            List<Map<String, Object>> found = jdbc.queryForList(SQL_ORDERNO, p);
            if (found.isEmpty()) throw new IllegalArgumentException("사양서가 없습니다. (전표번호 " + no + ")");
            final String orderno = str(found.get(0).get("orderno"));
            if (orderno.isEmpty()) throw new IllegalArgumentException("관리번호가 없는 사양서입니다. (전표번호 " + no + ")");
            p.addValue("orderno", orderno);

            // jpkey : yyyymmddHHMMSS + 1/100초 (PB string(today(),"yyyymmddHHMMSSFF") 와 같은 16자리)
            final String jpkey   = new SimpleDateFormat("yyyyMMddHHmmssSSS").format(new Date()).substring(0, 16);
            final String sect    = str(user.get("SECTNAME"));
            final String pruser  = str(user.get("NAME"));     // log_data.pruser = 세션 NAME
            final String sabun   = str(user.get("CODE"));     // log_data.sabun = 세션 CODE

            // 2) 로그 + 3) 상태 변경 — 한 연결에서 BEGIN TRANSACTION ~ COMMIT (실패 시 ROLLBACK)
            Integer cnt = jdbc.getJdbcOperations().execute(new ConnectionCallback<Integer>() {
                public Integer doInConnection(Connection con) throws SQLException {
                    Statement st = con.createStatement();
                    PreparedStatement ps1 = null, ps2 = null;
                    try {
                        st.execute("BEGIN TRANSACTION");

                        ps1 = con.prepareStatement(SQL_LOG);
                        ps1.setString(1, jpkey);
                        ps1.setString(2, company);
                        ps1.setString(3, sect);
                        ps1.setString(4, no);
                        ps1.setString(5, ok1);
                        ps1.setString(6, orderno);
                        ps1.setString(7, pruser);
                        ps1.setString(8, sabun);
                        ps1.executeUpdate();

                        ps2 = con.prepareStatement(SQL_SIGN);
                        ps2.setString(1, ok1);
                        ps2.setString(2, no);
                        ps2.setString(3, company);
                        int n = ps2.executeUpdate();

                        st.execute("COMMIT");
                        return n;
                    } catch (SQLException e) {
                        try { st.execute("ROLLBACK"); } catch (SQLException ignore) { /* 원래 오류를 알림 */ }
                        throw e;
                    } finally {
                        if (ps1 != null) try { ps1.close(); } catch (SQLException ignore) {}
                        if (ps2 != null) try { ps2.close(); } catch (SQLException ignore) {}
                        try { st.close(); } catch (SQLException ignore) {}
                    }
                }
            });

            logger.info("mes_sign " + ok1 + " jpno=" + no + " orderno=" + orderno + " rows=" + cnt + " user=" + str(user.get("NAME")));

            Map<String, Object> data = new LinkedHashMap<String, Object>();
            data.put("jpno", no);
            data.put("orderno", orderno);
            data.put("count", cnt);
            data.put("ok1", ok1);
            return ok(data);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 세션 / 응답
    // ------------------------------------------------------------------
    private Map<?, ?> user(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map<?, ?>) u;
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("mes_sign error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        if (e instanceof IllegalStateException) m.put("login", true);
        return m;
    }

    private static String str(Object o) { return o == null ? "" : o.toString().trim(); }
}
