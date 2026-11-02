package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
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
import org.springframework.jdbc.core.ResultSetExtractor;
import org.springframework.jdbc.core.RowMapper;
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
 * 월별 매출·매입 현황 (ar602) — 조회 전용 (ar601 일별과 같은 계산을 월로 묶음)
 *  - 화면 : /ar602.do → ar602.jsp
 *  - 데이터 : /ar602/list
 *  - 모두 로그인 매장(SHOPNO), 매출은 KIND = '매출'(반품 포함)
 *  - 매출 = AMT - SALEAMT - BONUSUSE,  할인 = SALEAMT + SAEUNAMT + BONUSUSE
 *  - 원가 = MC20_DTL.INPRICE × QTY (MC20KEY 로 연결)
 *  - 방문수 = 회원은 하루 한 번(같은 날 여러 번 사도 1), 비회원(회원번호 끝 999999)은 거래마다 1
 *  - 신규 = 가입일 = 판매일 인 회원 수(하루 한 번), 신규매출 = 기간 안에 가입한 회원의 매출
 *  - 재방문 = 가입 다음 날부터 재방문일(CODE_MST, 없으면 31) 안의 거래 수와 매출
 *  - 매입 = IP01_MST (금액·현금·할인)
 *  - 이익·이익율·객단가는 화면(JS)에서 계산
 */
@Controller
public class ar602_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 키 이름 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private static final int DEFAULT_REVISIT_DAYS = 31;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar602_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar602.do")
    public String ar602(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar602");
        return "ar602";
    }

    // ------------------------------------------------------------------
    // 월별 현황
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar602/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,   // 시작월 yyyy-MM
                                    @RequestParam(value = "to") String to,       // 종료월 yyyy-MM
                                    HttpSession session) {
        try {
            String fm = from.replace("-", "").trim(), tm = to.replace("-", "").trim();
            if (!fm.matches("\\d{6}") || !tm.matches("\\d{6}")) throw new IllegalArgumentException("기간(월)을 확인하세요.");
            if (fm.compareTo(tm) > 0) throw new IllegalArgumentException("시작월이 종료월보다 늦습니다.");
            // 일자는 문자 yyyyMMdd 라 종료월은 31일로 두면 말일까지 포함
            String f = fm + "01", t = tm + "31";

            String shop = shopNo(session);
            int revisitDays = revisitDays(shop);   // 재방문일 (CODE_MST)
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shop).addValue("f", f).addValue("t", t).addValue("rv", revisitDays);

            String sale = "(ISNULL(a.amt, 0) - ISNULL(a.saleamt, 0) - ISNULL(a.bonususe, 0))";
            String mcWhere = " a.shopno = :shop AND a.kind = '매출' AND a.chdate BETWEEN :f AND :t";

            String sql =
                "SELECT SUBSTRING(v.ymd, 1, 6) AS ym," +
                "       SUM(v.inamt) AS inamt,   SUM(v.mcamt) AS mcamt,   SUM(v.mccash) AS mccash," +
                "       SUM(v.mccard) AS mccard, SUM(v.mcsale) AS mcsale, SUM(v.visicnt) AS visicnt," +
                "       SUM(v.miamt) AS miamt,   SUM(v.micash) AS micash, SUM(v.misale) AS misale," +
                "       SUM(v.newmember) AS newmember,   SUM(v.newmemberamt) AS newmemberamt," +
                "       SUM(v.revisitmem) AS revisitmem, SUM(v.revisitmemamt) AS revisitmemamt" +
                "  FROM (" +
                // 1) 매출
                "        SELECT a.chdate AS ymd, 0 AS inamt," +
                "               SUM(" + sale + ") AS mcamt," +
                "               SUM(ISNULL(a.cashamt, 0)) AS mccash," +
                "               SUM(ISNULL(a.cardamt, 0)) AS mccard," +
                "               SUM(ISNULL(a.saleamt, 0) + ISNULL(a.saeunamt, 0) + ISNULL(a.bonususe, 0)) AS mcsale," +
                "               0 AS visicnt, 0 AS miamt, 0 AS micash, 0 AS misale," +
                "               0 AS newmember, 0 AS newmemberamt, 0 AS revisitmem, 0 AS revisitmemamt" +
                "          FROM mc20_mst a" +
                "         WHERE" + mcWhere +
                "         GROUP BY a.chdate" +
                "        UNION ALL" +
                // 2) 방문수 : 회원은 하루 한 번, 비회원(끝 999999)은 거래마다
                "        SELECT tm.mcdate, 0, 0, 0, 0, 0, COUNT(*), 0, 0, 0, 0, 0, 0, 0" +
                "          FROM ( SELECT a.chdate AS mcdate, a.memno" +
                "                   FROM mc20_mst a" +
                "                  WHERE" + mcWhere +
                "                    AND ISNULL(a.cardno, '') = ''" +
                "                    AND SUBSTRING(a.memno, 7, 6) <> '999999'" +
                "                  GROUP BY a.chdate, a.memno" +
                "                 UNION ALL" +
                "                 SELECT a.chdate, a.memno" +
                "                   FROM mc20_mst a" +
                "                  WHERE" + mcWhere +
                "                    AND ISNULL(a.cardno, '') = ''" +
                "                    AND SUBSTRING(a.memno, 7, 6) = '999999' ) tm" +
                "         GROUP BY tm.mcdate" +
                "        UNION ALL" +
                // 3) 원가 (판매 상세의 입고가 × 수량)
                "        SELECT a.chdate, SUM(ISNULL(d.inprice, 0) * ISNULL(d.qty, 0)), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0" +
                "          FROM mc20_mst a JOIN mc20_dtl d ON a.mc20key = d.mc20key" +
                "         WHERE" + mcWhere +
                "         GROUP BY a.chdate" +
                "        UNION ALL" +
                // 4) 매입
                "        SELECT b.ipdate, 0, 0, 0, 0, 0, 0," +
                "               SUM(ISNULL(b.amt, 0)), SUM(ISNULL(b.cashamt, 0)), SUM(ISNULL(b.saleamt, 0))," +
                "               0, 0, 0, 0" +
                "          FROM ip01_mst b" +
                "         WHERE b.shopno = :shop AND b.ipdate BETWEEN :f AND :t" +
                "         GROUP BY b.ipdate" +
                "        UNION ALL" +
                // 5) 신규 : 가입일 = 판매일 인 회원 수 (하루 한 번)
                "        SELECT nm.ymd, 0, 0, 0, 0, 0, 0, 0, 0, 0, COUNT(*), 0, 0, 0" +
                "          FROM ( SELECT a.chdate AS ymd, a.memno" +
                "                   FROM mc20_mst a JOIN member m ON a.memno = m.memno" +
                "                  WHERE" + mcWhere +
                "                    AND m.prdate = a.chdate" +
                "                  GROUP BY a.chdate, a.memno ) nm" +
                "         GROUP BY nm.ymd" +
                "        UNION ALL" +
                // 6) 신규매출 : 기간 안에 가입한 회원의 매출
                "        SELECT a.chdate, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, SUM(" + sale + "), 0, 0" +
                "          FROM mc20_mst a JOIN member m ON a.memno = m.memno" +
                "         WHERE" + mcWhere +
                "           AND m.prdate BETWEEN :f AND :t" +
                "         GROUP BY a.chdate" +
                "        UNION ALL" +
                // 7) 재방문 : 가입 다음 날부터 재방문일 안의 거래
                "        SELECT a.chdate, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, COUNT(*), SUM(" + sale + ")" +
                "          FROM mc20_mst a JOIN member m ON a.memno = m.memno" +
                "         WHERE" + mcWhere +
                // 가입일(prdate)은 빈칸·잘못된 값이 있을 수 있어 날짜로 바꾸지 않고 문자열로 비교
                //   판매일 - 재방문일 <= 가입일 < 판매일   (= 가입 다음 날부터 재방문일 안)
                "           AND m.prdate <  a.chdate" +
                "           AND m.prdate >= DATEFORMAT(DATEADD(day, -:rv, a.chdate), 'yyyymmdd')" +
                "         GROUP BY a.chdate" +
                "       ) v" +
                " GROUP BY SUBSTRING(v.ymd, 1, 6)" +
                " ORDER BY 1";

            List<Map<String, Object>> rows = jdbc.query(sql, p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("ym", trim(rs.getString("ym")));
                    for (String k : new String[] { "inamt", "mcamt", "mccash", "mccard", "mcsale", "visicnt",
                                                   "miamt", "micash", "misale", "newmember", "newmemberamt",
                                                   "revisitmem", "revisitmemamt" })
                        m.put(k, rs.getLong(k));
                    return m;
                }
            });
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("revisitDays", revisitDays);
            r.put("rows", rows);
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 재방문일 : CODE_MST (MODDATE = '재방문') 의 KIND 숫자, 없거나 이상하면 31 */
    private int revisitDays(String shop) {
        try {
            String v = jdbc.query(
                "SELECT kind FROM code_mst WHERE moddate = '재방문' AND shopno = :shop",
                new MapSqlParameterSource("shop", shop),
                new ResultSetExtractor<String>() {
                    public String extractData(ResultSet rs) throws SQLException { return rs.next() ? trim(rs.getString(1)) : ""; }
                });
            int n = Integer.parseInt(v);
            return n > 0 ? n : DEFAULT_REVISIT_DAYS;
        } catch (Exception e) {
            return DEFAULT_REVISIT_DAYS;
        }
    }

    // ------------------------------------------------------------------
    // 세션 / 응답
    // ------------------------------------------------------------------
    @SuppressWarnings("rawtypes")
    private String shopNo(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        Object v = ((Map) u).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ar602 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s) { return s == null ? "" : s.trim(); }
}
