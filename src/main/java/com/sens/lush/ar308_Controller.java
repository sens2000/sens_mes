package com.sens.lush;

import java.sql.ResultSet;
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
 * 제품별 판매내역 (ar308) — 조회 전용
 *  - 화면 : /ar308.do → ar308.jsp
 *  - 데이터 : /ar308/init (등급 목록), /ar308/members (회원 찾기), /ar308/list (내역별),
 *             /ar308/receipts (영수건별 — 기본), /ar308/detail (영수증 판매 상세)
 *  - 테이블 : MC20_MST + MC20_DTL(CJPNO) + SHOP_JEPM_MST(JEPMKEY) + member(MEMNO)
 *  - 조건 : KIND = '매출'(반품 포함), 판매는 로그인 매장(SHOPNO), 제품 마스터는 세션 GROUPNO (없으면 SHOPNO)
 *  - 검색 : 판매자(PRUSER)·담당자(manager)·제조회사·브랜드·제품명 = 포함 검색, 등급 = 일치, 회원 = MEMNO 일치, 기간(CHDATE)
 *  - 일자별 소계·합계(금액만)는 화면(JS)에서 계산
 */
@Controller
public class ar308_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 키 이름 */
    private static final String SESSION_USER     = "USER";
    private static final String USER_SHOP_FIELD  = "SHOPNO";
    private static final String USER_GROUP_FIELD = "GROUPNO";

    private static final int MEMBER_MAX = 100;   // 회원 찾기 최대 건수

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar308_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar308.do")
    public String ar308(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar308");
        return "ar308";
    }

    // ------------------------------------------------------------------
    // 검색 옵션 : 등급(CODE_MST)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar308/init", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> init(HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            RowMapper<String> one = new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
            };
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("grades", jdbc.query(
                "SELECT DISTINCT TRIM(CODENM) FROM CODE_MST WHERE CODEGU = '등급' AND SHOPNO = :shop" +
                " AND ISNULL(TRIM(CODENM), '') <> '' ORDER BY 1", p, one));
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 회원 찾기 : 이름 또는 전화번호 (숫자만 입력하면 전화번호로)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar308/members", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> members(@RequestParam(value = "q", defaultValue = "") String q, HttpSession session) {
        try {
            String key = q.trim();
            if (key.isEmpty()) throw new IllegalArgumentException("이름이나 전화번호를 입력하세요.");
            String digits = key.replaceAll("[^0-9]", "");

            MapSqlParameterSource p = new MapSqlParameterSource("shop", shopNo(session));
            String where;
            if (!digits.isEmpty() && digits.length() == key.replaceAll("[\\s-]", "").length()) {
                if (digits.length() < 3) throw new IllegalArgumentException("전화번호는 3자리 이상 입력하세요.");
                where = "REPLACE(ISNULL(handno, ''), '-', '') LIKE :q";
                p.addValue("q", "%" + digits + "%");
            } else {
                where = "name LIKE :q";
                p.addValue("q", "%" + key + "%");
            }
            // 최대 건수는 결과를 읽으면서 끊음 (MEMBER_MAX + 1 건까지 읽어 "더 있음" 판단)
            List<Map<String, Object>> rows = jdbc.query(
                "SELECT memno, name, handno, member, manager FROM member" +
                " WHERE shopno = :shop AND " + where +
                " ORDER BY name, handno", p, new ResultSetExtractor<List<Map<String, Object>>>() {
                    public List<Map<String, Object>> extractData(ResultSet rs) throws SQLException {
                        List<Map<String, Object>> list = new ArrayList<Map<String, Object>>();
                        while (list.size() <= MEMBER_MAX && rs.next()) {
                            Map<String, Object> m = new LinkedHashMap<String, Object>();
                            m.put("memno",   trim(rs.getString("memno")));
                            m.put("name",    trim(rs.getString("name")));
                            m.put("handno",  trim(rs.getString("handno")));
                            m.put("grade",   trim(rs.getString("member")));
                            m.put("manager", trim(rs.getString("manager")));
                            list.add(m);
                        }
                        return list;
                    }
                });
            boolean more = rows.size() > MEMBER_MAX;
            if (more) rows = rows.subList(0, MEMBER_MAX);
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("rows", rows);
            r.put("more", more);           // 더 있음
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 제품별 판매내역
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar308/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "from") String from,
                                    @RequestParam(value = "to") String to,
                                    @RequestParam(value = "pruser",   defaultValue = "") String pruser,
                                    @RequestParam(value = "manager",  defaultValue = "") String manager,
                                    @RequestParam(value = "grade",    defaultValue = "") String grade,
                                    @RequestParam(value = "memno",    defaultValue = "") String memno,
                                    @RequestParam(value = "makecust", defaultValue = "") String makecust,
                                    @RequestParam(value = "brand",    defaultValue = "") String brand,
                                    @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                    HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            StringBuilder sql = new StringBuilder(
                "SELECT a.CHDATE, a.PRTIME, a.PRUSER, a.CJPNO," +
                "       m.name, m.handno, m.member," +
                "       j.makecust, j.brand, j.jepmnm, j.jepmcd," +
                "       ISNULL(j.price, 0)     AS PRICE," +      // 정가
                "       ISNULL(d.saleprice, 0) AS SALEPRICE," +  // 판매가
                "       ISNULL(d.qty, 0)       AS QTY," +        // 수량
                "       ISNULL(d.amt, 0)       AS AMT" +         // 금액
                "  FROM MC20_MST a, MC20_DTL d, SHOP_JEPM_MST j, member m" +
                " WHERE a.MEMNO   = m.memno" +
                "   AND a.CJPNO   = d.CJPNO" +
                "   AND d.JEPMKEY = j.JEPMKEY" +
                "   AND j.SHOPNO  = :grp" +                // 제품 마스터 : 그룹(본사) 기준
                "   AND a.SHOPNO  = :shop" +               // 판매 : 로그인 매장
                "   AND a.KIND    = '매출'" +              // 반품도 KIND = '매출'
                "   AND a.CHDATE BETWEEN :f AND :t");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("grp", shopNo(session))
                .addValue("f", f).addValue("t", t);

            // 입력한 항목만 조건 추가 (비워 두면 전체)
            like(sql, p, "a.PRUSER",   "pruser",   pruser);
            like(sql, p, "m.manager",  "manager",  manager);
            like(sql, p, "j.makecust", "makecust", makecust);
            like(sql, p, "j.brand",    "brand",    brand);
            like(sql, p, "j.jepmnm",   "jepmnm",   jepmnm);
            if (!isEmpty(grade)) { sql.append(" AND m.member = :grade"); p.addValue("grade", grade.trim()); }
            if (!isEmpty(memno)) { sql.append(" AND m.memno = :memno");  p.addValue("memno", memno.trim()); }

            sql.append(" ORDER BY a.CHDATE, a.PRTIME, a.CJPNO");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("chdate",    trim(rs.getString("CHDATE")));
                    m.put("prtime",    trim(rs.getString("PRTIME")));
                    m.put("pruser",    trim(rs.getString("PRUSER")));
                    m.put("cjpno",     trim(rs.getString("CJPNO")));     // 전표번호 (화면에는 안 보임, 줄 색 구분용)
                    m.put("name",      trim(rs.getString("name")));
                    m.put("handno",    trim(rs.getString("handno")));
                    m.put("grade",     trim(rs.getString("member")));
                    m.put("makecust",  trim(rs.getString("makecust")));
                    m.put("brand",     trim(rs.getString("brand")));
                    m.put("jepmnm",    trim(rs.getString("jepmnm")));
                    m.put("jepmcd",    trim(rs.getString("jepmcd")));
                    m.put("price",     rs.getLong("PRICE"));
                    m.put("saleprice", rs.getLong("SALEPRICE"));
                    m.put("qty",       rs.getLong("QTY"));
                    m.put("amt",       rs.getLong("AMT"));
                    return m;
                }
            });
            return ok(rows);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 영수건별 (보고서 기본) — MC20_MST 한 건 = 한 줄
    //   제조회사·브랜드·제품명을 넣으면 그 제품이 들어 있는 영수증만
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar308/receipts", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> receipts(@RequestParam(value = "from") String from,
                                        @RequestParam(value = "to") String to,
                                        @RequestParam(value = "pruser",   defaultValue = "") String pruser,
                                        @RequestParam(value = "manager",  defaultValue = "") String manager,
                                        @RequestParam(value = "grade",    defaultValue = "") String grade,
                                        @RequestParam(value = "memno",    defaultValue = "") String memno,
                                        @RequestParam(value = "makecust", defaultValue = "") String makecust,
                                        @RequestParam(value = "brand",    defaultValue = "") String brand,
                                        @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                        HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");

            StringBuilder sql = new StringBuilder(
                "SELECT a.CHDATE, a.PRTIME, a.PRUSER, a.MC20KEY, a.CJPNO," +
                "       m.name, m.handno, m.member," +
                "       ISNULL(a.cashamt, 0)  AS CASHAMT," +     // 현금
                "       ISNULL(a.cardamt, 0)  AS CARDAMT," +     // 카드
                "       ISNULL(a.saleamt, 0)  AS SALEAMT," +     // 할인
                "       ISNULL(a.bonususe, 0) AS BONUSUSE," +    // 포인트 사용
                "       ISNULL(a.bonusamt, 0) AS BONUSAMT" +     // 포인트 누적
                "  FROM MC20_MST a, member m" +
                " WHERE a.MEMNO  = m.memno" +
                "   AND a.SHOPNO = :shop" +                  // 로그인 매장
                "   AND a.KIND   = '매출'" +                 // 반품도 '매출'
                "   AND a.CHDATE BETWEEN :f AND :t");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);

            like(sql, p, "a.PRUSER",  "pruser",  pruser);
            like(sql, p, "m.manager", "manager", manager);
            if (!isEmpty(grade)) { sql.append(" AND m.member = :grade"); p.addValue("grade", grade.trim()); }
            if (!isEmpty(memno)) { sql.append(" AND m.memno = :memno");  p.addValue("memno", memno.trim()); }
            // 제품 조건 : 그 제품이 들어 있는 영수증만
            if (!isEmpty(makecust) || !isEmpty(brand) || !isEmpty(jepmnm)) {
                StringBuilder ex = new StringBuilder(
                    " AND EXISTS ( SELECT 1 FROM MC20_DTL d, SHOP_JEPM_MST j" +
                    "               WHERE d.MC20KEY = a.MC20KEY AND j.JEPMKEY = d.JEPMKEY AND j.SHOPNO = :shop");
                like(ex, p, "j.makecust", "makecust", makecust);
                like(ex, p, "j.brand",    "brand",    brand);
                like(ex, p, "j.jepmnm",   "jepmnm",   jepmnm);
                sql.append(ex).append(" )");
            }
            sql.append(" ORDER BY a.CHDATE, a.PRTIME, a.CJPNO");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("chdate",   trim(rs.getString("CHDATE")));
                    m.put("prtime",   trim(rs.getString("PRTIME")));
                    m.put("pruser",   trim(rs.getString("PRUSER")));
                    m.put("mc20key",  trim(rs.getString("MC20KEY")));
                    m.put("cjpno",    trim(rs.getString("CJPNO")));
                    m.put("name",     trim(rs.getString("name")));
                    m.put("handno",   trim(rs.getString("handno")));
                    m.put("grade",    trim(rs.getString("member")));
                    m.put("cashamt",  rs.getLong("CASHAMT"));
                    m.put("cardamt",  rs.getLong("CARDAMT"));
                    m.put("saleamt",  rs.getLong("SALEAMT"));
                    m.put("bonususe", rs.getLong("BONUSUSE"));
                    m.put("bonusamt", rs.getLong("BONUSAMT"));
                    return m;
                }
            });
            return ok(rows);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 영수증 한 건의 판매 상세 (줄 클릭)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar308/detail", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> detail(@RequestParam("mc20key") String mc20key, HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("key", mc20key.trim());
            return ok(jdbc.query(
                "SELECT ISNULL(j.makecust, '') AS makecust, ISNULL(j.brand, '') AS brand," +
                "       ISNULL(j.jepmnm, '') AS jepmnm, ISNULL(j.jepmcd, '') AS jepmcd," +
                "       ISNULL(j.price, 0)     AS PRICE," +
                "       ISNULL(d.saleprice, 0) AS SALEPRICE," +
                "       ISNULL(d.qty, 0)       AS QTY," +
                "       ISNULL(d.amt, 0)       AS AMT" +
                "  FROM MC20_DTL d" +
                "  LEFT OUTER JOIN SHOP_JEPM_MST j ON j.JEPMKEY = d.JEPMKEY AND j.SHOPNO = :shop" +
                " WHERE d.MC20KEY = :key" +
                "   AND EXISTS ( SELECT 1 FROM MC20_MST a WHERE a.MC20KEY = d.MC20KEY AND a.SHOPNO = :shop )",   // 우리 매장 영수증만
                p, new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("makecust",  trim(rs.getString("makecust")));
                        m.put("brand",     trim(rs.getString("brand")));
                        m.put("jepmnm",    trim(rs.getString("jepmnm")));
                        m.put("jepmcd",    trim(rs.getString("jepmcd")));
                        m.put("price",     rs.getLong("PRICE"));
                        m.put("saleprice", rs.getLong("SALEPRICE"));
                        m.put("qty",       rs.getLong("QTY"));
                        m.put("amt",       rs.getLong("AMT"));
                        return m;
                    }
                }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 값이 있을 때만 포함 검색 조건 추가 */
    private static void like(StringBuilder sql, MapSqlParameterSource p, String col, String name, String v) {
        if (isEmpty(v)) return;
        sql.append(" AND ").append(col).append(" LIKE :").append(name);
        p.addValue(name, "%" + v.trim() + "%");
    }

    // ------------------------------------------------------------------
    // 세션 / 응답
    // ------------------------------------------------------------------
    @SuppressWarnings("rawtypes")
    private Map user(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map) u;
    }

    private String shopNo(HttpSession session) {
        Object v = user(session).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    /** 제품 마스터 기준 : 세션 GROUPNO, 없으면 매장코드 */
    private String groupNo(HttpSession session) {
        Object v = user(session).get(USER_GROUP_FIELD);
        return (v == null || v.toString().trim().isEmpty()) ? shopNo(session) : v.toString().trim();
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ar308 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.trim().isEmpty(); }
}
