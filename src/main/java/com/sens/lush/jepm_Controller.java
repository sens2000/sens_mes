package com.sens.lush;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpSession;
import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.jdbc.support.SQLStateSQLExceptionTranslator;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 제품정보 등록 — 공통 (어느 화면에서나 사용)
 *  - 화면 : /WEB-INF/common/jepm_new.jspf 를 JSP 에 include 하고
 *           JepmNew.open({ jepmcd: '...', onSaved: function (p) { ... } }) 호출
 *           수정은 JepmNew.edit('제품코드', { onSaved: function (p) { ... } })
 *  - 데이터 : /jepm/new   (POST) 제품 등록
 *             /jepm/update (POST) 제품 수정,  /jepm/get?jepmcd= (GET) 제품 1건
 *             /jepm/names (GET)  제조회사·브랜드 자동완성 목록
 *
 *  SHOP_JEPM_MST : SHOPNO(= 세션 GROUPNO), JEPMKEY(GROUPNO + JEPMCD), JEPMCD, MAKECUST(제조회사), BRAND, JEPMNM,
 *                  PRICE(정가), INPRICE(입고가), SALEPRICE(판매가), JPMBONUS(포인트구분 Y/N), SETCHK(세트 Y/N),
 *                  OLDBAR(바코드), REMK, CHK(사용 'Y'), PRDATE, MODDATE (yyyymmdd)
 *
 *  제품은 그룹 단위 : SHOP_JEPM_MST.SHOPNO 에 세션 USER 의 GROUPNO 를 넣고 조회도 GROUPNO 로 함
 *  판매가가 100 보다 작으면 할인율로 보고  판매가 = 정가 - (정가 × 할인율 / 100)  (할인액 원 단위 버림)
 */
@Controller
public class jepm_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 키 이름 — ai101 과 동일 */
    private static final String SESSION_USER     = "USER";
    private static final String USER_ID_FIELD    = "USERID";
    private static final String USER_GROUP_FIELD = "GROUPNO";

    private final NamedParameterJdbcTemplate jdbc;
    private final JdbcTemplate plain;

    @Autowired
    public jepm_Controller(DataSource dataSource) {
        this.jdbc  = noMeta(new NamedParameterJdbcTemplate(dataSource));
        this.plain = new JdbcTemplate(dataSource);
        this.plain.setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    /** jConnect + SQL Anywhere : DB 메타데이터를 읽지 않는 SQLState 방식으로 오류 해석 (ai101 과 같은 이유) */
    private static NamedParameterJdbcTemplate noMeta(NamedParameterJdbcTemplate t) {
        ((JdbcTemplate) t.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
        return t;
    }

    // ------------------------------------------------------------------
    // 제조회사·브랜드 자동완성 목록 (이 매장 기존 제품 기준)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/jepm/names", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> names(HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource("shop", groupNo(session));
            RowMapper<String> one = new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
            };
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("brands", jdbc.query("SELECT DISTINCT brand FROM SHOP_JEPM_MST WHERE shopno = :shop AND ISNULL(brand, '') <> '' ORDER BY brand", p, one));
            r.put("makers", jdbc.query("SELECT DISTINCT makecust FROM SHOP_JEPM_MST WHERE shopno = :shop AND ISNULL(makecust, '') <> '' ORDER BY makecust", p, one));
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 제품 1건 조회 (수정 화면용)  /jepm/get?jepmcd=
    // ------------------------------------------------------------------
    private static final String SELECT_PRODUCT =
        "SELECT jepmkey, jepmcd, oldbar, makecust, brand, jepmnm, price, saleprice, inprice, jpmbonus, setchk, remk, chk" +
        "  FROM SHOP_JEPM_MST";

    private static final RowMapper<Map<String, Object>> PRODUCT_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("jepmkey",   trim(rs.getString("jepmkey")));
            m.put("jepmcd",    trim(rs.getString("jepmcd")));
            m.put("oldbar",    trim(rs.getString("oldbar")));
            m.put("makecust",  trim(rs.getString("makecust")));
            m.put("brand",     trim(rs.getString("brand")));
            m.put("jepmnm",    trim(rs.getString("jepmnm")));
            m.put("price",     rs.getLong("price"));
            m.put("saleprice", rs.getLong("saleprice"));
            m.put("inprice",   rs.getLong("inprice"));
            m.put("jpmbonus",  trim(rs.getString("jpmbonus")));
            m.put("noBonus",   "N".equalsIgnoreCase(trim(rs.getString("jpmbonus"))));
            m.put("setchk",    trim(rs.getString("setchk")));
            m.put("remk",      trim(rs.getString("remk")));
            m.put("chk",       trim(rs.getString("chk")));
            return m;
        }
    };

    private Map<String, Object> findProduct(NamedParameterJdbcTemplate j, String group, String jepmcd) {
        List<Map<String, Object>> list = j.query(SELECT_PRODUCT + " WHERE shopno = :shop AND jepmcd = :cd",
            new MapSqlParameterSource().addValue("shop", group).addValue("cd", jepmcd), PRODUCT_MAPPER);
        return list.isEmpty() ? null : list.get(0);
    }

    @RequestMapping(value = "/jepm/get", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> getProduct(@RequestParam("jepmcd") String jepmcd, HttpSession session) {
        try {
            Map<String, Object> p = findProduct(jdbc, groupNo(session), jepmcd.trim());
            if (p == null) throw new IllegalArgumentException("제품을 찾을 수 없습니다. (" + jepmcd + ")");
            return ok(p);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 제품 등록 /jepm/new,  제품 수정 /jepm/update
    //   요청 : { jepmcd, oldbar, makecust, brand, jepmnm, price, saleprice, inprice, jpmbonus(Y/N), setchk(Y/N), remk, chk(수정만) }
    //   SHOPNO = 세션 GROUPNO,  JEPMKEY = GROUPNO + JEPMCD  (수정 때 제품코드·제품키는 안 바뀜)
    //   판매가 : 비우면(0) 정가,  1~99 이면 할인율(%) → 정가 - (정가 × 할인율 / 100)
    //   등록 : 같은 그룹에 같은 제품코드가 있으면 등록 안 함,  CHK = 'Y',  PRDATE/MODDATE = 오늘
    //   수정 : MODDATE = 오늘
    //   응답 : 제품 { jepmkey, jepmcd, oldbar, makecust, brand, jepmnm, price, saleprice, inprice, jpmbonus, noBonus, setchk, remk, chk }
    // ------------------------------------------------------------------
    @RequestMapping(value = "/jepm/new", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> newProduct(@RequestBody final Map<String, Object> req, HttpSession session) {
        return save(req, session, false);
    }

    @RequestMapping(value = "/jepm/update", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> updateProduct(@RequestBody final Map<String, Object> req, HttpSession session) {
        return save(req, session, true);
    }

    private Map<String, Object> save(final Map<String, Object> req, HttpSession session, final boolean update) {
        try {
            final String group = groupNo(session);   // SHOP_JEPM_MST.SHOPNO 값
            final String user  = userId(session);
            return ok(plain.execute(new ConnectionCallback<Map<String, Object>>() {
                public Map<String, Object> doInConnection(Connection con) throws SQLException {
                    // ai101 과 같이 BEGIN/COMMIT/ROLLBACK 을 SQL 로 직접 (jConnect + setAutoCommit 문제)
                    NamedParameterJdbcTemplate j = noMeta(new NamedParameterJdbcTemplate(new SingleConnectionDataSource(con, true)));
                    Statement st = con.createStatement();
                    try {
                        st.execute("BEGIN TRANSACTION");
                        try {
                            Map<String, Object> r = update ? doUpdate(j, req, group, user) : doNew(j, req, group, user);
                            st.execute("COMMIT TRANSACTION");
                            return r;
                        } catch (RuntimeException e) {
                            try { st.execute("ROLLBACK TRANSACTION"); } catch (SQLException ignore) { logger.error("jepm rollback 실패", ignore); }
                            throw e;
                        }
                    } finally {
                        st.close();
                    }
                }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 입력값 정리·검사 (등록·수정 공통) */
    private static MapSqlParameterSource readProduct(Map<String, Object> req) {
        String jepmcd = str(req.get("jepmcd")).replaceAll("\\s", "");
        String jepmnm = str(req.get("jepmnm"));
        if (isEmpty(jepmcd)) throw new IllegalArgumentException("제품코드를 입력하세요.");
        if (isEmpty(jepmnm)) throw new IllegalArgumentException("제품명을 입력하세요.");
        long price     = toLong(req.get("price"));
        long saleprice = toLong(req.get("saleprice"));
        long inprice   = toLong(req.get("inprice"));
        if (price <= 0) throw new IllegalArgumentException("정가를 입력하세요.");
        if (saleprice < 0 || inprice < 0) throw new IllegalArgumentException("금액이 잘못되었습니다.");
        if (saleprice == 0) saleprice = price;                                     // 판매가를 비우면 정가로
        else if (saleprice < 100) saleprice = price - (price * saleprice / 100);   // 100 미만 = 할인율(%), 할인액 원 단위 버림
        return new MapSqlParameterSource()
            .addValue("jepmcd", jepmcd).addValue("jepmnm", jepmnm)
            .addValue("makecust", str(req.get("makecust"))).addValue("brand", str(req.get("brand")))
            .addValue("price", price).addValue("inprice", inprice).addValue("saleprice", saleprice)
            .addValue("jpmbonus", "N".equalsIgnoreCase(str(req.get("jpmbonus"))) ? "N" : "Y")
            .addValue("setchk", "Y".equalsIgnoreCase(str(req.get("setchk"))) ? "Y" : "N")
            .addValue("oldbar", str(req.get("oldbar")).replaceAll("\\s", ""))
            .addValue("remk", cut(str(req.get("remk")), 60))
            .addValue("chk", "N".equalsIgnoreCase(str(req.get("chk"))) ? "N" : "Y");
    }

    private Map<String, Object> doNew(NamedParameterJdbcTemplate j, Map<String, Object> req, String group, String user) {
        MapSqlParameterSource p = readProduct(req);
        String jepmcd = (String) p.getValue("jepmcd");
        if (findProduct(j, group, jepmcd) != null) throw new IllegalArgumentException("이미 등록된 제품코드입니다. (" + jepmcd + ")");
        String key = group + jepmcd;
        Integer n = j.queryForObject("SELECT COUNT(*) FROM SHOP_JEPM_MST WHERE jepmkey = :k",
            new MapSqlParameterSource("k", key), Integer.class);
        if (n != null && n > 0) throw new IllegalArgumentException("제품키가 이미 있습니다. (" + key + ")");

        j.update(
            "INSERT INTO SHOP_JEPM_MST (shopno, jepmkey, jepmcd, makecust, brand, jepmnm, price, inprice, saleprice," +
            "                           jpmbonus, setchk, oldbar, remk, chk, prdate, moddate) " +
            "VALUES (:shop, :key, :jepmcd, :makecust, :brand, :jepmnm, :price, :inprice, :saleprice," +
            "        :jpmbonus, :setchk, :oldbar, :remk, 'Y', DATEFORMAT(GETDATE(),'YYYYMMDD'), DATEFORMAT(GETDATE(),'YYYYMMDD'))",
            p.addValue("shop", group).addValue("key", key));

        logger.info("jepm new: " + key + " " + p.getValue("jepmnm") + " price=" + p.getValue("price")
                  + " sale=" + p.getValue("saleprice") + " by " + user);
        return findProduct(j, group, jepmcd);
    }

    private Map<String, Object> doUpdate(NamedParameterJdbcTemplate j, Map<String, Object> req, String group, String user) {
        MapSqlParameterSource p = readProduct(req);
        String jepmcd = (String) p.getValue("jepmcd");
        Map<String, Object> old = findProduct(j, group, jepmcd);
        if (old == null) throw new IllegalArgumentException("제품을 찾을 수 없습니다. (" + jepmcd + ")");

        j.update(
            "UPDATE SHOP_JEPM_MST SET makecust = :makecust, brand = :brand, jepmnm = :jepmnm, price = :price, inprice = :inprice," +
            "       saleprice = :saleprice, jpmbonus = :jpmbonus, setchk = :setchk, oldbar = :oldbar, remk = :remk, chk = :chk," +
            "       moddate = DATEFORMAT(GETDATE(),'YYYYMMDD')" +
            " WHERE shopno = :shop AND jepmcd = :jepmcd",
            p.addValue("shop", group));

        logger.info("jepm update: " + old.get("jepmkey") + " " + p.getValue("jepmnm")
                  + " price=" + old.get("price") + "->" + p.getValue("price")
                  + " sale=" + old.get("saleprice") + "->" + p.getValue("saleprice")
                  + " chk=" + p.getValue("chk") + " by " + user);
        return findProduct(j, group, jepmcd);
    }

    // ------------------------------------------------------------------
    // 세션 / 공통
    // ------------------------------------------------------------------
    @SuppressWarnings("rawtypes")
    private Map userMap(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map) u;
    }

    /** 제품 그룹번호 = 세션 USER 의 GROUPNO  (SHOP_JEPM_MST.SHOPNO 에 들어가는 값) */
    private String groupNo(HttpSession session) {
        Object v = userMap(session).get(USER_GROUP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(그룹번호)가 없습니다. 세션 USER 의 " + USER_GROUP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private String userId(HttpSession session) {
        Object v = userMap(session).get(USER_ID_FIELD);
        return cut(v == null ? "" : v.toString().trim(), 12);
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("jepm error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s)     { return s == null ? "" : s.trim(); }
    private static String str(Object o)      { return o == null ? "" : o.toString().trim(); }
    private static boolean isEmpty(String s) { return s == null || s.trim().isEmpty(); }

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
        try { return new java.math.BigDecimal(o.toString().replace(",", "").trim()).longValue(); } catch (Exception e) { return 0; }
    }
}
