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
 * mes3202 제품 사양 목록 (jepm_mst + jepm_info) — 조회
 *  - /mes3202.do       화면
 *  - /mes3202/list     조회 (JSON)
 *  - 매출처 찾기는 mes0201 것을 같이 씀 (/mes0201/cust)
 *  - 부코드가 있으면 부코드로만 조회 (다른 조건 무시) — mes0201 과 같은 방식
 *
 *  PB 검색조건의 mc20_mst.* 는 이 SQL 에 mc20_mst 가 없어서 아래처럼 바꿈
 *   담당       → jepm_info.sabunnm (이름 포함) 또는 jepm_info.sabun (사번 일치)
 *   매출처     → jepm_info.custcd
 *   등록일     → jepm_info.prdate
 *   제품명     → jepm_mst.jepmnm
 *   납품예정일 → jepm_info.orderno 로 연결된 mc20_mst.deliverydate  (EXISTS)
 *   상태       → jepm_info.orderno 로 연결된 mc20_mst.ok1           (EXISTS)
 */
@Controller
public class mes3202_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER = "USER";
    private static final String USER_COMPANY = "COMPANY";   // 세션 USER 의 회사코드 키 (company() 에서 로그인 확인용)

    private static final int MAX_ROWS = 5000;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public mes3202_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    private static final String BASE_SQL =
        "SELECT TOP " + (MAX_ROWS + 1) + " " +
        "       jepm_mst.jepmno, jepm_mst.kind, jepm_mst.jepmcd, jepm_mst.custjepmcd, jepm_mst.jepmnm, jepm_mst.test, " +
        "       jepm_mst.custcd, cust_mst.custname, " +
        "       jepm_mst.prdate as jepm_prdate, " +                    // jepm_info.prdate(등록일) 와 이름이 겹쳐서 별칭
        "       jepm_mst.prodjepmno, j.jepmcd as prodjepmcd, j.jepmnm as prodjepmnm, " +
        "       jepm_info.sabun, jepm_info.sabunnm, jepm_info.pantype, " +
        "       trim(convert(char(6), jepm_info.cutwidth)) + '*' + trim(convert(char(6), jepm_info.cutlength)) as size, " +
        "       jepm_info.cutwidth, jepm_info.cutlength, jepm_info.sizejul, jepm_info.sizebu, " +
        "       jepm_info.pancnt, jepm_info.docnt, jepm_info.prdate, jepm_info.prtime, " +
        "       isnull((select jpno from mc20_file where mc20_file.jpno = jepm_info.jepmno and mc20_file.seq = 0), '') as filejpno, " +
        "       isnull((select jpno from mc20_file where mc20_file.jpno = jepm_info.jepmno and mc20_file.seq = 1), '') as mcinfojpno, " +
        "       isnull(jepm_info.orderno, '') as orderno " +
        "  FROM jepm_mst, jepm_info " +
        "       left outer join cust_mst   on cust_mst.custcd = jepm_info.custcd " +
        "       left outer join jepm_mst j on j.jepmno = jepm_mst.prodjepmno and j.chk = 'Y' " +
        " WHERE jepm_mst.chk = 'Y' " +
        "   and jepm_info.jepmno = jepm_mst.jepmno ";

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3202.do")
    public String mes3202(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: mes3202");
        return "mes3202";
    }

    // ------------------------------------------------------------------
    // 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/mes3202/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam Map<String, String> req, HttpSession session) {
        try {
            company(session);   // 로그인 확인
            StringBuilder sql = new StringBuilder(BASE_SQL);
            MapSqlParameterSource p = new MapSqlParameterSource();

            // 부코드가 있으면 부코드로만 조회 (기간 포함 다른 조건 모두 무시) — mes0201 과 같음
            String bucode = v(req, "bucode");
            if (!isEmpty(bucode)) {
                sql.append(" AND jepm_mst.custjepmcd LIKE :bucode");
                p.addValue("bucode", bucode + "%");
            } else {

            // 등록일 / 납품예정일
            String f = digits(v(req, "fdate")), t = digits(v(req, "tdate"));
            if (f.length() == 8 && t.length() == 8) {
                if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
                p.addValue("f", f).addValue("t", t);
                if ("deliverydate".equals(v(req, "dateKind")))
                    sql.append(" AND EXISTS (SELECT 1 FROM mc20_mst m WHERE m.orderno = jepm_info.orderno AND m.deliverydate BETWEEN :f AND :t)");
                else
                    sql.append(" AND jepm_info.prdate BETWEEN :f AND :t");
            }

            // 담당 : 이름 포함 검색 또는 사번 일치
            String sabun = v(req, "sabun");
            if (!isEmpty(sabun)) {
                sql.append(" AND ( jepm_info.sabunnm LIKE :sabunnm OR jepm_info.sabun = :sabun )");
                p.addValue("sabunnm", "%" + sabun + "%").addValue("sabun", sabun);
            }

            // 매출처
            eq(sql, p, "jepm_info.custcd", "custcd", v(req, "custcd"));

            // 상태 (전체면 조건 없음) — 연결된 수주의 상태
            String ok1 = v(req, "ok1");
            if (!isEmpty(ok1) && !"전체".equals(ok1)) {
                sql.append(" AND EXISTS (SELECT 1 FROM mc20_mst m WHERE m.orderno = jepm_info.orderno AND m.ok1 = :ok1)");
                p.addValue("ok1", ok1);
            }

            // 제품·상품 / 제품분류
            eqNotAll(sql, p, "jepm_mst.test", "test", v(req, "test"));
            eq(sql, p, "jepm_mst.kind", "kind", v(req, "kind"));

            // 제품명 : "/" 로 나눠 앞부분은 시작 일치, 뒷부분은 포함
            String jepmnm = v(req, "jepmnm");
            if (!isEmpty(jepmnm)) {
                String[] a = jepmnm.split("/", 2);
                String s1 = a[0].trim(), s2 = a.length > 1 ? a[1].trim() : "";
                if (!s1.isEmpty()) { sql.append(" AND jepm_mst.jepmnm LIKE :nm1"); p.addValue("nm1", s1 + "%"); }
                if (!s2.isEmpty()) { sql.append(" AND jepm_mst.jepmnm LIKE :nm2"); p.addValue("nm2", "%" + s2 + "%"); }
            }

            }   // 부코드 단독 검색이 아닐 때만 적용

            sql.append(" ORDER BY jepm_info.prdate DESC, jepm_info.orderno DESC");
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
        logger.error("mes3202 error", e);
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
