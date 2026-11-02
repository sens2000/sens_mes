package com.sens.lush;

import java.math.BigDecimal;
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
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.SQLStateSQLExceptionTranslator;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 제품 관리 (ai018)
 *  - 화면 : /ai018.do → ai018.jsp
 *  - 데이터 : /ai018/list (제품 목록), /ai018/save (등록·수정)
 *  - 테이블 : SHOP_JEPM_MST — 그룹 제품 마스터 (SHOPNO = 세션 USER.GROUPNO)
 *        JEPMKEY(GROUPNO + JEPMCD), SHOPNO(=GROUPNO), JEPMCD(코드), OLDBAR(바코드), MAKECUST(제조회사), BRAND, JEPMNM,
 *        PRICE(정가), INPRICE(입고가), SALEPRICE(판매가), PRDATE(등록일), CHK(Y 사용 / N 미사용)
 *           SHOP_JEGO     — 매장 재고 : SHOPNO = 세션 USER.SHOPNO, JEPMCD 로 연결 (JEGO)
 *  - 신규 : 코드(JEPMCD)는 직접 입력, 그룹 안에서 중복 불가, PRDATE = 오늘
 *  - 수정 : 코드는 바꾸지 않음 / 재고는 보기만 (입고·판매로 바뀜)
 */
@Controller
public class ai018_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 키 이름 */
    private static final String SESSION_USER     = "USER";
    private static final String USER_SHOP_FIELD  = "SHOPNO";
    private static final String USER_GROUP_FIELD = "GROUPNO";
    private static final String USER_ID_FIELD    = "USERID";

    /** 한 번에 보여 줄 최대 건수 */
    private static final int MAX_ROWS = 500;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ai018_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai018.do")
    public String ai018(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai018");
        return "ai018";
    }

    // ------------------------------------------------------------------
    // 제품 목록 : 그룹 제품 + 로그인 매장 재고
    //   검색 : 제조회사, 브랜드, 제품명, 코드, 바코드 (입력한 항목끼리 AND) / 사용 제품만
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai018/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam(value = "maker", defaultValue = "") String maker,
                                    @RequestParam(value = "brand", defaultValue = "") String brand,
                                    @RequestParam(value = "name", defaultValue = "") String name,
                                    @RequestParam(value = "code", defaultValue = "") String code,
                                    @RequestParam(value = "barcode", defaultValue = "") String barcode,
                                    @RequestParam(value = "useOnly", defaultValue = "N") String useOnly,
                                    HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder("SELECT TOP " + (MAX_ROWS + 1) + SELECT_COLS + FROM_JOIN + " WHERE j.SHOPNO = :grp");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("grp", groupNo(session))
                .addValue("shop", shopNo(session));
            like(sql, p, "j.MAKECUST", "maker", maker);
            like(sql, p, "j.BRAND", "brand", brand);
            like(sql, p, "j.JEPMNM", "name", name);
            like(sql, p, "j.JEPMCD", "code", code);
            like(sql, p, "j.OLDBAR", "bar", barcode);
            if ("Y".equals(useOnly)) sql.append(" AND ISNULL(j.CHK, 'Y') = 'Y'");
            sql.append(" ORDER BY j.BRAND, j.JEPMNM");

            List<Map<String, Object>> rows = jdbc.query(sql.toString(), p, JEPM_MAPPER);
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("more", rows.size() > MAX_ROWS);          // 최대 건수를 넘으면 잘라서 보냄
            r.put("rows", rows.size() > MAX_ROWS ? rows.subList(0, MAX_ROWS) : rows);
            r.put("max", MAX_ROWS);
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static void like(StringBuilder sql, MapSqlParameterSource p, String col, String key, String v) {
        if (isEmpty(v)) return;
        sql.append(" AND ").append(col).append(" LIKE :").append(key);
        p.addValue(key, "%" + v.trim() + "%");
    }

    private static final String SELECT_COLS =
        " j.JEPMKEY, j.JEPMCD, j.OLDBAR, j.MAKECUST, j.BRAND, j.JEPMNM, j.PRICE, j.INPRICE, j.SALEPRICE, j.PRDATE, j.CHK," +
        " ISNULL(g.JEGO, 0) AS JEGO";

    /** 재고 : 로그인 매장(SHOP_JEGO.SHOPNO = 세션 SHOPNO) */
    private static final String FROM_JOIN =
        "  FROM SHOP_JEPM_MST j" +
        "  LEFT OUTER JOIN SHOP_JEGO g ON g.SHOPNO = :shop AND g.JEPMCD = j.JEPMCD";

    private static final RowMapper<Map<String, Object>> JEPM_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("jepmkey",   trim(rs.getString("JEPMKEY")));
            m.put("jepmcd",    trim(rs.getString("JEPMCD")));
            m.put("barcode",   trim(rs.getString("OLDBAR")));
            m.put("maker",     trim(rs.getString("MAKECUST")));
            m.put("brand",     trim(rs.getString("BRAND")));
            m.put("jepmnm",    trim(rs.getString("JEPMNM")));
            m.put("price",     rs.getLong("PRICE"));
            m.put("inprice",   rs.getLong("INPRICE"));
            m.put("saleprice", rs.getLong("SALEPRICE"));
            m.put("prdate",    dateFmt(trim(rs.getString("PRDATE"))));
            String chk = trim(rs.getString("CHK"));
            m.put("chk",       isEmpty(chk) ? "Y" : chk);
            m.put("jego",      rs.getLong("JEGO"));
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 등록·수정 : isNew = true 이면 신규 (코드 직접 입력)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai018/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String grp    = groupNo(session);
            String shop   = shopNo(session);
            boolean isNew = "Y".equals(str(req.get("isNew")));
            String jepmcd = str(req.get("jepmcd"));
            String name   = cut(str(req.get("jepmnm")), 60);
            long price = toLong(req.get("price")), in = toLong(req.get("inprice")), sale = toLong(req.get("saleprice"));
            String chk = "N".equals(str(req.get("chk"))) ? "N" : "Y";

            if (isEmpty(jepmcd)) throw new IllegalArgumentException("코드를 입력하세요.");
            if (jepmcd.length() > 20) throw new IllegalArgumentException("코드가 너무 깁니다. (20자 이내)");
            if (isEmpty(name)) throw new IllegalArgumentException("제품명을 입력하세요.");
            if (price < 0 || in < 0 || sale < 0) throw new IllegalArgumentException("금액이 잘못되었습니다.");

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("grp", grp).addValue("shop", shop).addValue("cd", jepmcd)
                .addValue("bar", cut(str(req.get("barcode")), 20))
                .addValue("maker", cut(str(req.get("maker")), 30))
                .addValue("brand", cut(str(req.get("brand")), 30))
                .addValue("name", name)
                .addValue("price", price).addValue("in", in).addValue("sale", sale)
                .addValue("chk", chk);

            Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM SHOP_JEPM_MST WHERE SHOPNO = :grp AND JEPMCD = :cd", p, Integer.class);
            boolean exists = n != null && n > 0;

            if (isNew) {
                if (exists) throw new IllegalArgumentException("이미 등록된 코드입니다. (" + jepmcd + ")");
                p.addValue("key", grp + jepmcd);
                jdbc.update(
                    "INSERT INTO SHOP_JEPM_MST (JEPMKEY, SHOPNO, JEPMCD, OLDBAR, MAKECUST, BRAND, JEPMNM, PRICE, INPRICE, SALEPRICE, PRDATE, CHK) " +
                    "VALUES (:key, :grp, :cd, :bar, :maker, :brand, :name, :price, :in, :sale, DATEFORMAT(GETDATE(), 'YYYYMMDD'), :chk)", p);
                logger.info("ai018 new: " + grp + " " + jepmcd + " " + name + " (by " + userId(session) + ")");
            } else {
                if (!exists) throw new IllegalArgumentException("제품을 찾을 수 없습니다. (" + jepmcd + ")");
                jdbc.update(
                    "UPDATE SHOP_JEPM_MST SET OLDBAR = :bar, MAKECUST = :maker, BRAND = :brand, JEPMNM = :name," +
                    "       PRICE = :price, INPRICE = :in, SALEPRICE = :sale, CHK = :chk" +
                    " WHERE SHOPNO = :grp AND JEPMCD = :cd", p);
                logger.info("ai018 update: " + grp + " " + jepmcd + " " + name + " price=" + price + " in=" + in + " sale=" + sale
                          + " chk=" + chk + " (by " + userId(session) + ")");
            }

            return ok(jdbc.query("SELECT" + SELECT_COLS + FROM_JOIN + " WHERE j.SHOPNO = :grp AND j.JEPMCD = :cd", p, JEPM_MAPPER).get(0));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 세션
    // ------------------------------------------------------------------
    @SuppressWarnings("rawtypes")
    private Map userMap(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map) u;
    }

    private String shopNo(HttpSession session) {
        Object v = userMap(session).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private String groupNo(HttpSession session) {
        Object v = userMap(session).get(USER_GROUP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(그룹번호)가 없습니다. 세션 USER 의 " + USER_GROUP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private String userId(HttpSession session) {
        Object v = userMap(session).get(USER_ID_FIELD);
        return v == null ? "" : v.toString().trim();
    }

    // ------------------------------------------------------------------
    // 응답 / 변환
    // ------------------------------------------------------------------
    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ai018 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static String str(Object o)       { return o == null ? "" : o.toString().trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.trim().isEmpty(); }
    private static String dateFmt(String d)   { return d.length() >= 8 && d.substring(0, 8).matches("\\d{8}") ? d.substring(0, 4) + "-" + d.substring(4, 6) + "-" + d.substring(6, 8) : d; }

    /** DB(CP949) 기준 바이트 수로 자르기 — 한글 2바이트 */
    private static String cut(String s, int maxBytes) {
        int n = 0;
        for (int i = 0; i < s.length(); i++) {
            n += s.charAt(i) > 127 ? 2 : 1;
            if (n > maxBytes) return s.substring(0, i);
        }
        return s;
    }

    private static long toLong(Object o) {
        if (o == null) return 0;
        if (o instanceof Number) return ((Number) o).longValue();
        try { return new BigDecimal(o.toString().replace(",", "").trim()).longValue(); } catch (Exception e) { return 0; }
    }
}
