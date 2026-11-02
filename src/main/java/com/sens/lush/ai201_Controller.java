package com.sens.lush;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletRequest;
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
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 입고 (ai201)
 *  - 화면   : /ai201.do  → /WEB-INF/ai201.jsp
 *  - 데이터 : /ai201/custs (거래처 검색), /ai201/cust (거래처 등록),
 *             /ai201/history (입고내역), /ai201/detail (입고상세),
 *             /ai201/products (제품 검색 + 최근입고가), /ai201/save (입고 저장),
 *             /ai201/list (입고조회 : 기간, 전체/매입/WEB),
 *             /ai201/cust/update (거래처 수정), /ai201/sellers·/ai201/pruser (처리자 변경, 매니저 암호),
 *             /ai201/product·/ai201/product/update (제품 조회·수정),
 *             /ai201/update (입고 수정), /ai201/delete (입고 삭제)
 *
 *  테이블
 *   CUST_MST      : CUSTKEY(SHOPNO+CUSTCD), SHOPNO, CUSTCD(char6, 신규 등록은 '700000'~'900000'), CUSTNAME, TELNO, MANNM,
 *                   CUSTNMHP(핸드폰), ENDCHK(Y=정상 거래처), MIBULAMT(미불금), JIKPAN('N'), SOPOST('WEB' = 웹 등록)
 *   SHOP_JEPM_MST : (SHOPNO = 세션 GROUPNO) JEPMKEY, SHOPNO, JEPMCD, BRAND, JEPMNM, PRICE(정가), SALEPRICE, INPRICE(입고가), CHK
 *   IP01_MST      : IP01KEY(SHOPNO+yymmddhhnnss), SHOPNO, IPDATE(입고일), MJPNO(yyyymmddhhnnss), CUSTKEY, CUSTCD,
 *                   AMT(입고금액), CASHAMT(지급금), SALEAMT(할인), PRDATE, PRTIME, PRUSER, REMK, KIND('매입'), CASHNO('WEB')
 *   IP01_DTL      : IP01KEY, SHOPNO, IPDATE, MJPNO, SEQ, JEPMKEY, JEPMCD, JEPMNM, QTY, PRICE(입고가), AMT(QTY×PRICE),
 *                   CUSTKEY, CUSTCD, REMK('WEB')
 *   SHOP_JEGO     : SHOPNO, JEPMCD, JEPMKEY(SHOP_JEPM_MST.JEPMKEY), JEGO — 입고 저장 +QTY / 수정 -기존 +새 수량 / 삭제 -QTY
 *
 *  미불금 : 저장할 때 CUST_MST.MIBULAMT = MIBULAMT + AMT - CASHAMT - SALEAMT
 *  입고가 기본값 : 해당 제품의 최근 입고단가(IP01_DTL.PRICE), 없으면 SHOP_JEPM_MST.INPRICE
 */
@Controller
public class ai201_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 / 사용자ID 키 이름 — ai101 과 동일 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";
    private static final String USER_GROUP_FIELD = "GROUPNO";   // 제품 마스터 SHOP_JEPM_MST.SHOPNO
    private static final String USER_ID_FIELD   = "USERID";

    /** 매입 거래처 코드 범위 */
    private static final String CUST_FROM = "700000";
    private static final String CUST_TO   = "900000";

    /** IP01_MST 등록일·시간 : DB 서버 시각 기준 PRDATE(yyyymmdd), PRTIME(hhnn) */
    private static final String PR_DATE_TIME = " DATEFORMAT(GETDATE(), 'YYYYMMDD'), DATEFORMAT(GETDATE(), 'HHNN')";

    private final NamedParameterJdbcTemplate jdbc;
    private final JdbcTemplate plain;

    @Autowired
    public ai201_Controller(DataSource dataSource) {
        this.jdbc  = noMeta(new NamedParameterJdbcTemplate(dataSource));
        this.plain = new JdbcTemplate(dataSource);
        this.plain.setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    /** jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석 */
    private static NamedParameterJdbcTemplate noMeta(NamedParameterJdbcTemplate t) {
        ((JdbcTemplate) t.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
        return t;
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201.do")
    public String ai201(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai201");
        return "ai201";
    }

    // ------------------------------------------------------------------
    // 거래처 검색 : 거래처명(CUSTNAME) — 해당 매장 거래처 전체 (코드 범위 제한 없음, JIKPAN='N', ENDCHK='Y' 정상 거래처만)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/custs", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> custs(@RequestParam("keyword") String keyword, HttpSession session) {
        try {
            String kw = keyword.trim();
            logger.info("ai201 custs: shop=" + shopNo(session) + " keyword=" + kw);
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("kw", "%" + kw + "%");
            return ok(jdbc.query(SELECT_CUST +
                " WHERE SHOPNO = :shop " +
                "   AND ISNULL(JIKPAN, 'N') = 'N' AND ENDCHK = 'Y'" +
                "   AND CUSTNAME LIKE :kw" +
                " ORDER BY CUSTNAME", p, CUST_MAPPER));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static final String SELECT_CUST =
        "SELECT TOP 30 CUSTKEY, CUSTCD, CUSTNAME, TELNO, MANNM, CUSTNMHP, SAADDR, MIBULAMT, SOPOST FROM CUST_MST";

    private static final RowMapper<Map<String, Object>> CUST_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("custkey",  trim(rs.getString("CUSTKEY")));
            m.put("custcd",   trim(rs.getString("CUSTCD")));
            m.put("custname", trim(rs.getString("CUSTNAME")));
            m.put("telno",    trim(rs.getString("TELNO")));
            m.put("mannm",    trim(rs.getString("MANNM")));
            m.put("hp",       trim(rs.getString("CUSTNMHP")));
            m.put("mibul",    rs.getLong("MIBULAMT"));
            m.put("remk",     trim(rs.getString("SAADDR")));   // 비고 (CUST_MST 에 REMK 가 없어 SAADDR 사용)
            m.put("sopost",   trim(rs.getString("SOPOST")));   // 'WEB' = 웹 등록 → 수정 가능 (그 외는 조회만)
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 거래처 등록 : CUSTCD = 해당 매장 '700000'~'900000' 중 MAX + 1
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/cust", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> newCust(@RequestBody final Map<String, Object> req, HttpSession session) {
        try {
            final String shop = shopNo(session);
            return ok(inTx(new TxWork() {
                public Map<String, Object> run(NamedParameterJdbcTemplate j) { return doNewCust(j, req, shop); }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private Map<String, Object> doNewCust(NamedParameterJdbcTemplate j, Map<String, Object> req, String shop) {
        String name = cut(str(req.get("custname")), 60);
        if (isEmpty(name)) throw new IllegalArgumentException("거래처명을 입력하세요.");

        String max = j.queryForObject(
            "SELECT MAX(CUSTCD) FROM CUST_MST WHERE SHOPNO = :shop AND CUSTCD BETWEEN :from AND :to",
            new MapSqlParameterSource().addValue("shop", shop).addValue("from", CUST_FROM).addValue("to", CUST_TO),
            String.class);
        long next;
        try {
            next = isEmpty(max) ? Long.parseLong(CUST_FROM) + 1 : Long.parseLong(max.trim()) + 1;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("거래처코드 최대값이 숫자가 아닙니다. (" + max + ")");
        }
        if (next > Long.parseLong(CUST_TO)) throw new IllegalArgumentException("거래처코드가 " + CUST_TO + " 를 넘었습니다.");
        String custcd = String.format("%06d", next);
        String custkey = shop.trim() + custcd;

        j.update(
            "INSERT INTO CUST_MST (CUSTKEY, SHOPNO, CUSTCD, CUSTNAME, TELNO, MANNM, CUSTNMHP, SAADDR, ENDCHK, MIBULAMT, JIKPAN, SOPOST) " +
            "VALUES (:custkey, :shop, :custcd, :name, :tel, :man, :hp, :remk, 'Y', 0, 'N', 'WEB')",
            new MapSqlParameterSource()
                .addValue("custkey", custkey).addValue("shop", shop).addValue("custcd", custcd)
                .addValue("name", name)
                .addValue("tel", cut(str(req.get("telno")), 20))
                .addValue("man", cut(str(req.get("mannm")), 20))
                .addValue("hp", cut(str(req.get("hp")), 20))
                .addValue("remk", cut(str(req.get("remk")), 100)));
        logger.info("ai201 new cust: " + custkey + " " + name);

        List<Map<String, Object>> r = j.query(SELECT_CUST + " WHERE CUSTKEY = :ck AND SHOPNO = :shop",
            new MapSqlParameterSource().addValue("ck", custkey).addValue("shop", shop), CUST_MAPPER);
        return r.get(0);
    }

    // ------------------------------------------------------------------
    // 거래처 수정 : 거래처명, 전화번호, 담당자, 핸드폰, 비고(SAADDR) (코드·미불금은 수정하지 않음)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/cust/update", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> updateCust(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String shop = shopNo(session);
            String custcd = str(req.get("custcd"));
            String name = cut(str(req.get("custname")), 60);
            if (isEmpty(name)) throw new IllegalArgumentException("거래처명을 입력하세요.");
            Integer w = jdbc.queryForObject("SELECT COUNT(*) FROM CUST_MST WHERE SHOPNO = :shop AND CUSTCD = :cd AND SOPOST = 'WEB'",
                new MapSqlParameterSource().addValue("shop", shop).addValue("cd", custcd), Integer.class);
            if (w == null || w == 0) throw new IllegalArgumentException("WEB 등록 거래처만 수정할 수 있습니다. (POS 거래처는 수정 불가)");
            int cnt = jdbc.update(
                "UPDATE CUST_MST SET CUSTNAME = :name, TELNO = :tel, MANNM = :man, CUSTNMHP = :hp, SAADDR = :remk" +
                " WHERE SHOPNO = :shop AND CUSTCD = :cd",
                new MapSqlParameterSource()
                    .addValue("name", name)
                    .addValue("tel", cut(str(req.get("telno")), 20))
                    .addValue("man", cut(str(req.get("mannm")), 20))
                    .addValue("hp", cut(str(req.get("hp")), 20))
                    .addValue("remk", cut(str(req.get("remk")), 100))
                    .addValue("shop", shop).addValue("cd", custcd));
            if (cnt == 0) throw new IllegalArgumentException("거래처를 찾을 수 없습니다. (" + custcd + ")");
            logger.info("ai201 cust update: " + custcd + " " + name + " (by " + userId(session) + ")");
            return ok(jdbc.query(SELECT_CUST + " WHERE SHOPNO = :shop AND CUSTCD = :cd",
                new MapSqlParameterSource().addValue("shop", shop).addValue("cd", custcd), CUST_MAPPER).get(0));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 처리자 목록 (user_info.chk = 'Y', 해당 매장) / 처리자 변경 (IP01_MST.PRUSER, 매니저 암호 확인)
    // ------------------------------------------------------------------
    /** user_info 암호 컬럼 / 매니저 직책 — ai101 과 동일 */
    private static final String MANAGER_PW_COLUMN = "userpass";
    private static final String MANAGER_POSITION  = "메니저";

    @RequestMapping(value = "/ai201/sellers", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> sellers(HttpSession session) {
        try {
            return ok(jdbc.query("SELECT DISTINCT name FROM user_info WHERE chk = 'Y' AND shopno = :shop ORDER BY name",
                new MapSqlParameterSource("shop", shopNo(session)),
                new RowMapper<String>() {
                    public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString("name")); }
                }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    @RequestMapping(value = "/ai201/pruser", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> changePruser(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String shop = shopNo(session);
            String key = str(req.get("key"));
            String pruser = str(req.get("pruser"));
            if (isEmpty(pruser)) throw new IllegalArgumentException("처리자를 선택하세요.");
            Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM user_info WHERE chk = 'Y' AND shopno = :shop AND name = :name",
                new MapSqlParameterSource().addValue("shop", shop).addValue("name", pruser), Integer.class);
            if (n == null || n == 0) throw new IllegalArgumentException("사용 중인 직원이 아닙니다. (" + pruser + ")");
            checkWeb(loadIp(jdbc, shop, key), "처리자를 바꿀 수 없습니다.");

            String pw = str(req.get("pw"));
            if (isEmpty(pw)) throw new IllegalArgumentException("매니저 암호를 입력하세요.");
            List<String> mgr = jdbc.query(
                "SELECT name FROM user_info WHERE chk = 'Y' AND position = :pos AND " + MANAGER_PW_COLUMN + " = :pw",
                new MapSqlParameterSource().addValue("pos", MANAGER_POSITION).addValue("pw", pw),
                new RowMapper<String>() {
                    public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString("name")); }
                });
            if (mgr.isEmpty()) {
                logger.warn("ai201 pruser: 매니저 암호 불일치 (by " + userId(session) + ")");
                throw new IllegalArgumentException("매니저 암호가 맞지 않습니다.");
            }

            int cnt = jdbc.update("UPDATE IP01_MST SET PRUSER = :pruser WHERE IP01KEY = :key AND SHOPNO = :shop",
                new MapSqlParameterSource().addValue("pruser", cut(pruser, 12)).addValue("key", key).addValue("shop", shop));
            if (cnt == 0) throw new IllegalArgumentException("입고 전표를 찾을 수 없습니다.");
            logger.info("ai201 pruser: " + key + " -> " + pruser + " (승인 " + mgr.get(0) + ", by " + userId(session) + ")");
            return ok(null);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 제품 조회 / 수정 (SHOP_JEPM_MST) — 제품코드는 수정하지 않음
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/product", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> product(@RequestParam("jepmcd") String jepmcd, HttpSession session) {
        try {
            List<Map<String, Object>> r = jdbc.query(
                "SELECT JEPMCD, BRAND, JEPMNM, PRICE, SALEPRICE, INPRICE, CHK FROM SHOP_JEPM_MST WHERE SHOPNO = :grp AND JEPMCD = :cd",
                new MapSqlParameterSource().addValue("grp", groupNo(session)).addValue("cd", jepmcd.trim()),
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("jepmcd",    trim(rs.getString("JEPMCD")));
                        m.put("brand",     trim(rs.getString("BRAND")));
                        m.put("jepmnm",    trim(rs.getString("JEPMNM")));
                        m.put("price",     rs.getLong("PRICE"));
                        m.put("saleprice", rs.getLong("SALEPRICE"));
                        m.put("inprice",   rs.getLong("INPRICE"));
                        m.put("chk",       trim(rs.getString("CHK")));
                        return m;
                    }
                });
            if (r.isEmpty()) throw new IllegalArgumentException("제품을 찾을 수 없습니다. (" + jepmcd + ")");
            return ok(r.get(0));
        } catch (Exception e) {
            return fail(e);
        }
    }

    @RequestMapping(value = "/ai201/product/update", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> updateProduct(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String jepmcd = str(req.get("jepmcd"));
            String name = cut(str(req.get("jepmnm")), 60);
            long price = toLong(req.get("price")), sale = toLong(req.get("saleprice")), in = toLong(req.get("inprice"));
            String chk = "N".equals(str(req.get("chk"))) ? "N" : "Y";
            if (isEmpty(name)) throw new IllegalArgumentException("제품명을 입력하세요.");
            if (price < 0 || sale < 0 || in < 0) throw new IllegalArgumentException("금액이 잘못되었습니다.");
            int cnt = jdbc.update(
                "UPDATE SHOP_JEPM_MST SET BRAND = :brand, JEPMNM = :name, PRICE = :price, SALEPRICE = :sale, INPRICE = :in, CHK = :chk" +
                " WHERE SHOPNO = :grp AND JEPMCD = :cd",
                new MapSqlParameterSource()
                    .addValue("brand", cut(str(req.get("brand")), 30)).addValue("name", name)
                    .addValue("price", price).addValue("sale", sale).addValue("in", in).addValue("chk", chk)
                    .addValue("grp", groupNo(session)).addValue("cd", jepmcd));
            if (cnt == 0) throw new IllegalArgumentException("제품을 찾을 수 없습니다. (" + jepmcd + ")");
            logger.info("ai201 product update: " + jepmcd + " " + name + " price=" + price + " sale=" + sale + " in=" + in
                      + " chk=" + chk + " (by " + userId(session) + ")");
            return ok(null);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 입고내역 (IP01_MST) — 미지급금은 현재 미불금에서 거꾸로 계산한 그 시점 잔액
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/history", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> history(@RequestParam("custcd") String custcd,
                                       @RequestParam("from") String from,
                                       @RequestParam("to") String to,
                                       HttpSession session) {
        try {
            String shop = shopNo(session);
            String f = from.replace("-", ""), t = to.replace("-", "");
            Map<String, Object> cust = loadCust(jdbc, shop, custcd);
            long bal = toLong(cust.get("MIBULAMT"));

            // 시작일 이후 전부(종료일 이후 포함)를 최신순으로 읽어서 잔액을 거꾸로 계산한 뒤, 종료일까지만 돌려준다
            List<Map<String, Object>> rows = jdbc.query(
                "SELECT IP01KEY, IPDATE, MJPNO, AMT, CASHAMT, SALEAMT, REMK, PRUSER, PRTIME, CASHNO FROM IP01_MST" +
                " WHERE SHOPNO = :shop AND CUSTCD = :cd AND IPDATE >= :from" +
                " ORDER BY IPDATE DESC, IP01KEY DESC",
                new MapSqlParameterSource().addValue("shop", shop).addValue("cd", custcd).addValue("from", f),
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        String pt = trim(rs.getString("PRTIME"));
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("key",    trim(rs.getString("IP01KEY")));
                        m.put("ymd",    trim(rs.getString("IPDATE")));
                        m.put("date",   dateFmt(trim(rs.getString("IPDATE"))));
                        m.put("time",   pt.length() >= 4 ? pt.substring(0, 2) + ":" + pt.substring(2, 4) : "");
                        m.put("mjpno",  trim(rs.getString("MJPNO")));
                        m.put("amt",    rs.getLong("AMT"));
                        m.put("cash",   rs.getLong("CASHAMT"));
                        m.put("disc",   rs.getLong("SALEAMT"));
                        m.put("remk",   trim(rs.getString("REMK")));
                        m.put("pruser", trim(rs.getString("PRUSER")));
                        m.put("kind",   "WEB".equals(trim(rs.getString("CASHNO"))) ? "WEB" : "매입");
                        return m;
                    }
                });
            List<Map<String, Object>> list = new ArrayList<Map<String, Object>>();
            for (Map<String, Object> r : rows) {
                r.put("bal", bal);   // 이 전표 처리 후 미지급금
                bal -= toLong(r.get("amt")) - toLong(r.get("cash")) - toLong(r.get("disc"));
                if (str(r.get("ymd")).compareTo(t) <= 0) list.add(r);
            }

            Map<String, Object> data = new LinkedHashMap<String, Object>();
            data.put("mibul", toLong(cust.get("MIBULAMT")));
            data.put("rows", list);
            return ok(data);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 입고조회 (IP01_MST) — 기간(from~to), 구분(전체 / 매입=WEB 아닌 것 / WEB), 거래처명
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam("from") String from,
                                    @RequestParam("to") String to,
                                    @RequestParam(value = "kind", required = false) String kind,
                                    @RequestParam(value = "keyword", required = false) String keyword,
                                    HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(
                "SELECT TOP 2000 a.IP01KEY, a.IPDATE, a.MJPNO, a.CUSTCD, c.CUSTNAME, c.TELNO, c.MANNM, c.CUSTNMHP, c.MIBULAMT," +
                "       a.AMT, a.CASHAMT, a.SALEAMT, a.REMK, a.PRUSER, a.PRTIME, a.CASHNO" +
                "  FROM IP01_MST a" +
                "  LEFT OUTER JOIN CUST_MST c ON c.SHOPNO = a.SHOPNO AND c.CUSTCD = a.CUSTCD" +
                " WHERE a.SHOPNO = :shop AND a.IPDATE BETWEEN :from AND :to");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("from", from.replace("-", ""))
                .addValue("to", to.replace("-", ""));
            if ("WEB".equals(kind)) sql.append(" AND ISNULL(a.CASHNO, '') = 'WEB'");
            else if ("매입".equals(kind)) sql.append(" AND ISNULL(a.CASHNO, '') <> 'WEB'");
            if (!isEmpty(keyword)) {
                String kw = keyword.trim();
                sql.append(" AND c.CUSTNAME LIKE :kw");
                p.addValue("kw", "%" + kw + "%");
            }
            sql.append(" ORDER BY a.IPDATE DESC, a.IP01KEY DESC");
            return ok(jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    String pt = trim(rs.getString("PRTIME"));
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("key",      trim(rs.getString("IP01KEY")));
                    m.put("date",     dateFmt(trim(rs.getString("IPDATE"))));
                    m.put("time",     pt.length() >= 4 ? pt.substring(0, 2) + ":" + pt.substring(2, 4) : "");
                    m.put("custcd",   trim(rs.getString("CUSTCD")));
                    m.put("custname", trim(rs.getString("CUSTNAME")));
                    m.put("telno",    trim(rs.getString("TELNO")));
                    m.put("mannm",    trim(rs.getString("MANNM")));
                    m.put("hp",       trim(rs.getString("CUSTNMHP")));
                    m.put("mibul",    rs.getLong("MIBULAMT"));
                    m.put("amt",      rs.getLong("AMT"));
                    m.put("cash",     rs.getLong("CASHAMT"));
                    m.put("disc",     rs.getLong("SALEAMT"));
                    m.put("remk",     trim(rs.getString("REMK")));
                    m.put("pruser",   trim(rs.getString("PRUSER")));
                    m.put("kind",     "WEB".equals(trim(rs.getString("CASHNO"))) ? "WEB" : "매입");
                    return m;
                }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 입고상세 (IP01_DTL)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/detail", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> detail(@RequestParam("key") String key, HttpSession session) {
        try {
            return ok(jdbc.query(
                "SELECT d.SEQ, d.JEPMCD, j.BRAND, d.JEPMNM, j.PRICE AS JPRICE, d.PRICE, d.QTY, d.AMT, d.REMK" +
                "  FROM IP01_DTL d" +
                "  LEFT OUTER JOIN SHOP_JEPM_MST j ON j.SHOPNO = :grp AND j.JEPMCD = d.JEPMCD" +
                " WHERE d.IP01KEY = :key AND d.SHOPNO = :shop" +
                " ORDER BY d.SEQ",
                new MapSqlParameterSource().addValue("key", key).addValue("shop", shopNo(session)).addValue("grp", groupNo(session)),
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("seq",     rs.getInt("SEQ"));
                        m.put("jepmcd",  trim(rs.getString("JEPMCD")));
                        m.put("brand",   trim(rs.getString("BRAND")));
                        m.put("jepmnm",  trim(rs.getString("JEPMNM")));
                        m.put("price",   rs.getLong("JPRICE"));
                        m.put("inprice", rs.getLong("PRICE"));
                        m.put("qty",     rs.getLong("QTY"));
                        m.put("amt",     rs.getLong("AMT"));
                        m.put("remk",    trim(rs.getString("REMK")));
                        return m;
                    }
                }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 제품 검색 + 최근 입고단가
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/products", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> products(@RequestParam("keyword") String keyword, HttpSession session) {
        try {
            String kw = keyword.trim();
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))           // 최근 입고단가 : 우리 매장 입고
                .addValue("grp", groupNo(session))           // 제품 마스터 : 그룹
                .addValue("code", kw)
                .addValue("kw", "%" + kw + "%");
            List<Map<String, Object>> list = jdbc.query(SELECT_JEPM +
                " WHERE j.SHOPNO = :grp AND j.CHK = 'Y' AND j.JEPMCD = :code", p, JEPM_MAPPER);
            if (list.isEmpty()) {
                list = jdbc.query(SELECT_JEPM +
                    " WHERE j.SHOPNO = :grp AND j.CHK = 'Y'" +
                    "   AND (j.JEPMNM LIKE :kw OR j.BRAND LIKE :kw OR j.JEPMCD LIKE :kw)" +
                    " ORDER BY j.BRAND, j.JEPMNM", p, JEPM_MAPPER);
            }
            return ok(list);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** LASTIN = 같은 매장·제품의 가장 최근 입고전표(IP01KEY 최대) 입고단가 */
    private static final String SELECT_JEPM =
        "SELECT TOP 50 j.JEPMKEY, j.JEPMCD, j.BRAND, j.JEPMNM, j.PRICE, j.INPRICE," +
        "       (SELECT MAX(d.PRICE) FROM IP01_DTL d" +
        "         WHERE d.SHOPNO = :shop AND d.JEPMCD = j.JEPMCD" +
        "           AND d.IP01KEY = (SELECT MAX(d2.IP01KEY) FROM IP01_DTL d2 WHERE d2.SHOPNO = :shop AND d2.JEPMCD = j.JEPMCD)) AS LASTIN" +
        "  FROM SHOP_JEPM_MST j";

    private static final RowMapper<Map<String, Object>> JEPM_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("jepmkey", trim(rs.getString("JEPMKEY")));
            m.put("jepmcd",  trim(rs.getString("JEPMCD")));
            m.put("brand",   trim(rs.getString("BRAND")));
            m.put("jepmnm",  trim(rs.getString("JEPMNM")));
            m.put("price",   rs.getLong("PRICE"));
            m.put("inprice", rs.getLong("INPRICE"));
            m.put("lastin",  rs.getLong("LASTIN"));   // 최근 입고단가 (없으면 0)
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 입고 저장
    //   요청 : { custcd, ipdate, cash(지급금), disc(할인), remk,
    //            lines:[{ jepmcd, inprice(입고가), qty, remk }] }
    //   품목 없이 지급금·할인만 저장하는 것도 가능 (미불금 지급)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody final Map<String, Object> req, HttpSession session) {
        try {
            final String shop = shopNo(session);
            final String grp = groupNo(session);
            final String user = userId(session);
            return ok(inTx(new TxWork() {
                public Map<String, Object> run(NamedParameterJdbcTemplate j) { return doSave(j, req, shop, grp, user); }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> doSave(NamedParameterJdbcTemplate j, Map<String, Object> req, String shop, String grp, String user) {
        String custcd = str(req.get("custcd"));
        String ipdate = str(req.get("ipdate")).replace("-", "");
        long cash = toLong(req.get("cash"));
        long disc = toLong(req.get("disc"));
        String remk = cut(str(req.get("remk")), 60);

        if (!ipdate.matches("\\d{8}")) throw new IllegalArgumentException("입고일을 확인하세요.");
        if (cash < 0 || disc < 0) throw new IllegalArgumentException("지급금·할인이 잘못되었습니다.");
        Map<String, Object> cust = loadCust(j, shop, custcd);
        String custkey = str(cust.get("CUSTKEY"));
        if (isEmpty(custkey)) custkey = shop.trim() + custcd;

        List<Map<String, Object>> lines = buildLines(j, grp, req.get("lines"));
        if (lines.isEmpty() && cash == 0 && disc == 0)
            throw new IllegalArgumentException("입고할 제품이나 지급금을 입력하세요.");
        long amt = sumAmt(lines);

        // ---- 키 (IP01KEY = SHOPNO + yymmddhhnnss, MJPNO = yyyymmddhhnnss, 같은 초면 1초씩 밀기)
        SimpleDateFormat fmt = new SimpleDateFormat("yyyyMMddHHmmss");
        Date now = new Date();
        String mjpno = fmt.format(now);
        for (int i = 0; i < 10 && exists(j, ip01key(shop, mjpno)); i++) {
            now = new Date(now.getTime() + 1000);
            mjpno = fmt.format(now);
        }
        String key = ip01key(shop, mjpno);

        // ---- IP01_MST
        j.update(
            "INSERT INTO IP01_MST (IP01KEY, SHOPNO, IPDATE, MJPNO, CUSTKEY, CUSTCD, AMT, CASHAMT, SALEAMT," +
            "                      PRDATE, PRTIME, PRUSER, REMK, KIND, CASHNO) " +
            "VALUES (:key, :shop, :ipdate, :mjpno, :custkey, :custcd, :amt, :cash, :disc," + PR_DATE_TIME + ", :user, :remk, '매입', 'WEB')",
            new MapSqlParameterSource()
                .addValue("key", key).addValue("shop", shop).addValue("ipdate", ipdate).addValue("mjpno", mjpno)
                .addValue("custkey", custkey).addValue("custcd", custcd)
                .addValue("amt", amt).addValue("cash", cash).addValue("disc", disc)
                .addValue("user", user).addValue("remk", remk));

        // ---- IP01_DTL
        insertDtl(j, key, shop, ipdate, mjpno, custkey, custcd, lines);

        // ---- 거래처 미불금 = 미불금 + 입고금액 - 지급금 - 할인
        long diff = amt - cash - disc;
        j.update("UPDATE CUST_MST SET MIBULAMT = ISNULL(MIBULAMT, 0) + :diff WHERE SHOPNO = :shop AND CUSTCD = :cd",
            new MapSqlParameterSource().addValue("diff", diff).addValue("shop", shop).addValue("cd", custcd));
        long bal = toLong(loadCust(j, shop, custcd).get("MIBULAMT"));

        logger.info("ai201 save: " + key + " cust=" + custcd + " amt=" + amt + " cash=" + cash + " disc=" + disc
                  + " lines=" + lines.size() + " mibul=" + bal);

        Map<String, Object> r = new LinkedHashMap<String, Object>();
        r.put("key", key);
        r.put("amt", amt);
        r.put("cash", cash);
        r.put("disc", disc);
        r.put("mibul", bal);
        return r;
    }

    // ------------------------------------------------------------------
    // 입고 수정 : 전표키 그대로, 품목은 지우고 다시 넣음
    //   미불금 = 미불금 - (기존 입고-지급-할인) + (새 입고-지급-할인)
    //   거래처는 바꿀 수 없음 (거래처를 바꾸려면 삭제 후 새로 입고)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/update", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> update(@RequestBody final Map<String, Object> req, HttpSession session) {
        try {
            final String shop = shopNo(session);
            final String grp = groupNo(session);
            final String user = userId(session);
            return ok(inTx(new TxWork() {
                public Map<String, Object> run(NamedParameterJdbcTemplate j) { return doUpdate(j, req, shop, grp, user); }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private Map<String, Object> doUpdate(NamedParameterJdbcTemplate j, Map<String, Object> req, String shop, String grp, String user) {
        String key = str(req.get("key"));
        String ipdate = str(req.get("ipdate")).replace("-", "");
        long cash = toLong(req.get("cash"));
        long disc = toLong(req.get("disc"));
        String remk = cut(str(req.get("remk")), 60);
        if (!ipdate.matches("\\d{8}")) throw new IllegalArgumentException("입고일을 확인하세요.");
        if (cash < 0 || disc < 0) throw new IllegalArgumentException("지급금·할인이 잘못되었습니다.");

        Map<String, Object> old = loadIp(j, shop, key);
        checkWeb(old, "수정할 수 없습니다.");
        String custcd = str(old.get("CUSTCD"));
        if (!isEmpty(str(req.get("custcd"))) && !custcd.equals(str(req.get("custcd"))))
            throw new IllegalArgumentException("다른 거래처의 전표는 수정할 수 없습니다.");
        String custkey = str(old.get("CUSTKEY"));
        if (isEmpty(custkey)) custkey = shop.trim() + custcd;
        String mjpno = str(old.get("MJPNO"));

        List<Map<String, Object>> lines = buildLines(j, grp, req.get("lines"));
        if (lines.isEmpty() && cash == 0 && disc == 0)
            throw new IllegalArgumentException("입고할 제품이나 지급금을 입력하세요. (전표를 없애려면 삭제하세요)");
        long amt = sumAmt(lines);

        // ---- 품목 다시 저장 (재고 : 기존 수량 빼고 → 새 수량 더하기)
        reverseJego(j, key, shop);
        j.update("DELETE FROM IP01_DTL WHERE IP01KEY = :key AND SHOPNO = :shop",
            new MapSqlParameterSource().addValue("key", key).addValue("shop", shop));
        insertDtl(j, key, shop, ipdate, mjpno, custkey, custcd, lines);

        // ---- 전표 (등록일·등록자는 그대로)
        j.update("UPDATE IP01_MST SET IPDATE = :ipdate, AMT = :amt, CASHAMT = :cash, SALEAMT = :disc, REMK = :remk" +
                 " WHERE IP01KEY = :key AND SHOPNO = :shop",
            new MapSqlParameterSource()
                .addValue("ipdate", ipdate).addValue("amt", amt).addValue("cash", cash).addValue("disc", disc)
                .addValue("remk", remk).addValue("key", key).addValue("shop", shop));

        // ---- 미불금 : 기존 전표분을 빼고 새 전표분을 더함
        long oldDiff = toLong(old.get("AMT")) - toLong(old.get("CASHAMT")) - toLong(old.get("SALEAMT"));
        long newDiff = amt - cash - disc;
        j.update("UPDATE CUST_MST SET MIBULAMT = ISNULL(MIBULAMT, 0) + :d WHERE SHOPNO = :shop AND CUSTCD = :cd",
            new MapSqlParameterSource().addValue("d", newDiff - oldDiff).addValue("shop", shop).addValue("cd", custcd));
        long bal = toLong(loadCust(j, shop, custcd).get("MIBULAMT"));

        logger.info("ai201 update: " + key + " amt " + old.get("AMT") + "->" + amt + " cash " + old.get("CASHAMT") + "->" + cash
                  + " disc " + old.get("SALEAMT") + "->" + disc + " mibul=" + bal + " (by " + user + ")");

        Map<String, Object> r = new LinkedHashMap<String, Object>();
        r.put("key", key);
        r.put("amt", amt);
        r.put("cash", cash);
        r.put("disc", disc);
        r.put("mibul", bal);
        return r;
    }

    // ------------------------------------------------------------------
    // 입고 삭제 : IP01_DTL·IP01_MST 삭제, 미불금 = 미불금 - (입고 - 지급 - 할인)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai201/delete", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> delete(@RequestBody final Map<String, Object> req, HttpSession session) {
        try {
            final String shop = shopNo(session);
            final String user = userId(session);
            return ok(inTx(new TxWork() {
                public Map<String, Object> run(NamedParameterJdbcTemplate j) { return doDelete(j, str(req.get("key")), shop, user); }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private Map<String, Object> doDelete(NamedParameterJdbcTemplate j, String key, String shop, String user) {
        Map<String, Object> old = loadIp(j, shop, key);
        checkWeb(old, "삭제할 수 없습니다.");
        String custcd = str(old.get("CUSTCD"));
        MapSqlParameterSource kp = new MapSqlParameterSource().addValue("key", key).addValue("shop", shop);
        reverseJego(j, key, shop);                                                  // 재고 : 입고했던 수량 빼기
        j.update("DELETE FROM IP01_DTL WHERE IP01KEY = :key AND SHOPNO = :shop", kp);
        j.update("DELETE FROM IP01_MST WHERE IP01KEY = :key AND SHOPNO = :shop", kp);

        long oldDiff = toLong(old.get("AMT")) - toLong(old.get("CASHAMT")) - toLong(old.get("SALEAMT"));
        j.update("UPDATE CUST_MST SET MIBULAMT = ISNULL(MIBULAMT, 0) - :d WHERE SHOPNO = :shop AND CUSTCD = :cd",
            new MapSqlParameterSource().addValue("d", oldDiff).addValue("shop", shop).addValue("cd", custcd));
        long bal = toLong(loadCust(j, shop, custcd).get("MIBULAMT"));

        logger.info("ai201 delete: " + key + " cust=" + custcd + " amt=" + old.get("AMT") + " cash=" + old.get("CASHAMT")
                  + " disc=" + old.get("SALEAMT") + " mibul=" + bal + " (by " + user + ")");

        Map<String, Object> r = new LinkedHashMap<String, Object>();
        r.put("key", key);
        r.put("mibul", bal);
        return r;
    }

    // ------------------------------------------------------------------
    // 공통 : 품목 검증 / 품목 저장 / 전표 읽기
    // ------------------------------------------------------------------
    /** 화면에서 넘어온 품목을 검증 (제품명은 DB 기준, 입고가·수량은 화면 입력값) */
    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> buildLines(NamedParameterJdbcTemplate j, String grp, Object raw) {
        List<Map<String, Object>> lines = new ArrayList<Map<String, Object>>();
        if (!(raw instanceof List)) return lines;
        for (Object o : (List<?>) raw) {
            if (!(o instanceof Map)) continue;
            Map<String, Object> l = (Map<String, Object>) o;
            String jepmcd = str(l.get("jepmcd"));
            long qty = toLong(l.get("qty"));
            long price = toLong(l.get("inprice"));
            if (qty <= 0) throw new IllegalArgumentException("수량이 잘못되었습니다. (" + jepmcd + ")");
            if (price < 0) throw new IllegalArgumentException("입고가가 잘못되었습니다. (" + jepmcd + ")");
            List<Map<String, Object>> found = j.queryForList(
                "SELECT JEPMKEY, JEPMNM FROM SHOP_JEPM_MST WHERE SHOPNO = :grp AND JEPMCD = :cd",
                new MapSqlParameterSource().addValue("grp", grp).addValue("cd", jepmcd));
            if (found.isEmpty()) throw new IllegalArgumentException("등록되지 않은 제품입니다. (" + jepmcd + ")");
            Map<String, Object> jp = upperKeys(found.get(0));
            Map<String, Object> line = new HashMap<String, Object>();
            line.put("jepmkey", str(jp.get("JEPMKEY")));
            line.put("jepmcd",  jepmcd);
            line.put("jepmnm",  str(jp.get("JEPMNM")));
            line.put("qty",     qty);
            line.put("price",   price);
            line.put("amt",     qty * price);
            lines.add(line);
        }
        return lines;
    }

    private static long sumAmt(List<Map<String, Object>> lines) {
        long amt = 0;
        for (Map<String, Object> l : lines) amt += toLong(l.get("amt"));
        return amt;
    }

    private void insertDtl(NamedParameterJdbcTemplate j, String key, String shop, String ipdate, String mjpno,
                           String custkey, String custcd, List<Map<String, Object>> lines) {
        int seq = 0;
        for (Map<String, Object> l : lines) {
            seq++;
            j.update(
                "INSERT INTO IP01_DTL (IP01KEY, SHOPNO, IPDATE, MJPNO, SEQ, JEPMKEY, JEPMCD, JEPMNM, QTY, PRICE, AMT," +
                "                      CUSTKEY, CUSTCD, REMK) " +
                "VALUES (:key, :shop, :ipdate, :mjpno, :seq, :jepmkey, :jepmcd, :jepmnm, :qty, :price, :amt," +
                "        :custkey, :custcd, 'WEB')",
                new MapSqlParameterSource()
                    .addValue("key", key).addValue("shop", shop).addValue("ipdate", ipdate).addValue("mjpno", mjpno)
                    .addValue("seq", seq).addValue("jepmkey", l.get("jepmkey")).addValue("jepmcd", l.get("jepmcd"))
                    .addValue("jepmnm", l.get("jepmnm")).addValue("qty", l.get("qty")).addValue("price", l.get("price"))
                    .addValue("amt", l.get("amt")).addValue("custkey", custkey).addValue("custcd", custcd));
            addJego(j, shop, str(l.get("jepmcd")), str(l.get("jepmkey")), toLong(l.get("qty")));        // 재고 : 입고수량만큼 더하기
        }
    }

    /** 기존 입고 품목만큼 재고 빼기 (수정·삭제 전에 호출) */
    private void reverseJego(NamedParameterJdbcTemplate j, String key, String shop) {
        List<Map<String, Object>> old = j.queryForList(
            "SELECT JEPMCD, JEPMKEY, QTY FROM IP01_DTL WHERE IP01KEY = :key AND SHOPNO = :shop",
            new MapSqlParameterSource().addValue("key", key).addValue("shop", shop));
        for (Map<String, Object> row : old) {
            Map<String, Object> d = upperKeys(row);
            addJego(j, shop, str(d.get("JEPMCD")), str(d.get("JEPMKEY")), -toLong(d.get("QTY")));
        }
    }

    // ------------------------------------------------------------------
    // 재고 (SHOP_JEGO.JEGO) : 매장 + 제품코드, 행이 없으면 새로 만듦
    // ------------------------------------------------------------------
    private void addJego(NamedParameterJdbcTemplate j, String shop, String jepmcd, String jepmkey, long delta) {
        if (delta == 0 || isEmpty(jepmcd)) return;
        MapSqlParameterSource p = new MapSqlParameterSource()
            .addValue("shop", shop).addValue("cd", jepmcd.trim()).addValue("d", delta)
            .addValue("jepmkey", jepmkey == null ? "" : jepmkey.trim());   // SHOP_JEPM_MST.JEPMKEY
        int cnt = j.update("UPDATE SHOP_JEGO SET JEGO = ISNULL(JEGO, 0) + :d WHERE SHOPNO = :shop AND JEPMCD = :cd", p);
        if (cnt == 0) j.update("INSERT INTO SHOP_JEGO (SHOPNO, JEPMCD, JEPMKEY, JEGO) VALUES (:shop, :cd, :jepmkey, :d)", p);
    }


    /** CASHNO = 'WEB' 인 입고 전표만 수정·삭제·처리자 변경 가능 / POS 전표는 조회만 */
    private static void checkWeb(Map<String, Object> ip, String what) {
        if (!"WEB".equals(str(ip.get("CASHNO"))))
            throw new IllegalArgumentException("POS 입고 전표는 조회만 가능합니다. " + what + " (WEB 전표만 가능)");
    }

    private Map<String, Object> loadIp(NamedParameterJdbcTemplate j, String shop, String key) {
        List<Map<String, Object>> m = j.queryForList(
            "SELECT IP01KEY, CUSTCD, CUSTKEY, MJPNO, AMT, CASHAMT, SALEAMT, CASHNO FROM IP01_MST WHERE IP01KEY = :key AND SHOPNO = :shop",
            new MapSqlParameterSource().addValue("key", key).addValue("shop", shop));
        if (m.isEmpty()) throw new IllegalArgumentException("입고 전표를 찾을 수 없습니다. (" + key + ")");
        return upperKeys(m.get(0));
    }

    // ------------------------------------------------------------------
    // 공통 : 트랜잭션, 키, 거래처
    // ------------------------------------------------------------------
    private interface TxWork { Map<String, Object> run(NamedParameterJdbcTemplate j); }

    /**
     * jConnect + SQL Anywhere : setAutoCommit(false) 를 쓰면 jConnect 메타데이터 테이블이 없어서 오류(JZ0SJ)
     * → 한 커넥션에서 BEGIN TRANSACTION / COMMIT / ROLLBACK 을 SQL 로 직접 실행
     */
    private Map<String, Object> inTx(final TxWork work) {
        return plain.execute(new ConnectionCallback<Map<String, Object>>() {
            public Map<String, Object> doInConnection(Connection con) throws SQLException {
                NamedParameterJdbcTemplate one = noMeta(new NamedParameterJdbcTemplate(new SingleConnectionDataSource(con, true)));
                Statement st = con.createStatement();
                try {
                    st.execute("BEGIN TRANSACTION");
                    try {
                        Map<String, Object> r = work.run(one);
                        st.execute("COMMIT TRANSACTION");
                        return r;
                    } catch (RuntimeException e) {
                        try { st.execute("ROLLBACK TRANSACTION"); } catch (SQLException ignore) { logger.error("ai201 rollback 실패", ignore); }
                        throw e;
                    }
                } finally {
                    st.close();
                }
            }
        });
    }

    /** IP01KEY = SHOPNO + yymmddhhnnss  (MJPNO 는 yyyymmddhhnnss 그대로) */
    private static String ip01key(String shop, String mjpno) {
        return shop.trim() + mjpno.substring(2);
    }

    private boolean exists(NamedParameterJdbcTemplate j, String key) {
        Integer n = j.queryForObject("SELECT COUNT(*) FROM IP01_MST WHERE IP01KEY = :k",
            new MapSqlParameterSource("k", key), Integer.class);
        return n != null && n > 0;
    }

    private Map<String, Object> loadCust(NamedParameterJdbcTemplate j, String shop, String custcd) {
        List<Map<String, Object>> c = j.queryForList(
            "SELECT CUSTKEY, CUSTCD, CUSTNAME, MIBULAMT FROM CUST_MST WHERE SHOPNO = :shop AND CUSTCD = :cd",
            new MapSqlParameterSource().addValue("shop", shop).addValue("cd", custcd));
        if (c.isEmpty()) throw new IllegalArgumentException("거래처를 찾을 수 없습니다. (" + custcd + ")");
        return upperKeys(c.get(0));
    }

    // ------------------------------------------------------------------
    // 세션 (로그인 시 "USER" HashMap)
    // ------------------------------------------------------------------
    @SuppressWarnings("rawtypes")
    private Map userMap(HttpSession session) {
        Object u = session.getAttribute(SESSION_USER);
        if (!(u instanceof Map)) throw new IllegalStateException("로그인 정보가 없습니다. 다시 로그인하세요.");
        return (Map) u;
    }

    /** 제품 마스터(SHOP_JEPM_MST.SHOPNO) 조회용 그룹번호 — 세션 USER.GROUPNO */
    private String groupNo(HttpSession session) {
        Object v = userMap(session).get(USER_GROUP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(그룹번호)가 없습니다. 세션 USER 의 " + USER_GROUP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private String shopNo(HttpSession session) {
        Object v = userMap(session).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private String userId(HttpSession session) {
        Object v = userMap(session).get(USER_ID_FIELD);
        return cut(v == null ? "" : v.toString().trim(), 12);
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
        logger.error("ai201 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    /** queryForList 결과 컬럼명을 대문자로 통일 */
    private static Map<String, Object> upperKeys(Map<String, Object> src) {
        Map<String, Object> m = new HashMap<String, Object>();
        for (Map.Entry<String, Object> e : src.entrySet()) m.put(e.getKey().toUpperCase(), e.getValue());
        return m;
    }

    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static String str(Object o)       { return o == null ? "" : o.toString().trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.trim().isEmpty(); }
    private static String dateFmt(String d)   { return d.length() == 8 && d.matches("\\d{8}") ? d.substring(0, 4) + "-" + d.substring(4, 6) + "-" + d.substring(6) : d; }

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
