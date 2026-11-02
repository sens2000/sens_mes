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
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
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
 * POS 판매 (ai101)
 *  - 화면   : /ai101.do  → /WEB-INF/ai101.jsp
 *  - 데이터 : /ai101/rates, /ai101/members, /ai101/products, /ai101/save,
 *             /ai101/sales (매출조회), /ai101/sales/detail (매출상세), /ai101/cancel (매출취소),
 *             /ai101/sellers (판매자 목록), /ai101/seller (판매자 변경)
 *   user_info : shopno, name(판매자), chk('Y' = 사용), position('메니저' = 판매자 변경 승인), 암호 컬럼(MANAGER_PW_COLUMN)
 *
 *  테이블
 *   member          : memno, name, handno, member(등급), saleamt(누적판매), bonusamt(포인트잔액),
 *                     prdate, remk, lastdate(최근방문), manager(담당), shopno
 *   SHOP_JEPM_MST   : (SHOPNO = 세션 GROUPNO) JEPMKEY, SHOPNO, JEPMCD, BRAND, JEPMNM, PRICE, SALEPRICE, INPRICE, CHK
 *   CODE_MST        : CODEGU='등급', SHOPNO, CODENM(등급명), CASHTERM(현금 적립률 %), CASHCOST(카드 적립률 %)
 *   MC20_MST        : mc20key(SHOPNO+yymmddhhnnss), SHOPNO, CHDATE, CJPNO, MEMNO, AMT, CASHAMT, CARDAMT,
 *                     SALEAMT, BONUSUSE, BONUSAMT, INAMT, REMK, PRUSER, KIND('WEB'), CARDNO,
 *                     PRDATE = DATEFORMAT(GETDATE(),'YYYYMMDD'), PRTIME = DATEFORMAT(GETDATE(),'HHNN')
 *                     VISITCNT(방문수) : 판매 1 / 취소 -1
 *   MC20_DTL        : mc20key, SHOPNO, CHDATE, CJPNO, SEQ, JEPMKEY, JEPMCD, JEPMNM, INPRICE, PRICE, SALEPRICE,
 *                     QTY, CGUBUN('일반'), MEMNO, REMK, KIND('WEB')
 *   SHOP_JEGO       : SHOPNO, JEPMCD, JEPMKEY(SHOP_JEPM_MST.JEPMKEY), JEGO — 판매 -QTY / 매출 취소 +QTY (없으면 INSERT)
 *
 *  금액 계산 (서버에서 다시 계산)
 *   판매합계 = Σ(판매가 × 수량)
 *   AMT(매출) = 판매합계 - 할인 - 포인트사용   (= 현금 + 카드)
 *   CASHAMT  = 받은 현금 - 거스름돈,  CARDAMT = 카드
 *   BONUSAMT(적립) = 현금 × CASHTERM / 100 + 카드 × CASHCOST / 100  (원 단위 버림, 비회원 0)
 */
@Controller
public class ai101_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 매장코드 / 사용자ID 키 이름 — ai206 과 동일 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";
    private static final String USER_GROUP_FIELD = "GROUPNO";   // 제품 마스터 SHOP_JEPM_MST.SHOPNO
    private static final String USER_ID_FIELD   = "USERID";

    private final NamedParameterJdbcTemplate jdbc;
    private final JdbcTemplate plain;

    @Autowired
    public ai101_Controller(DataSource dataSource) {
        this.jdbc  = noMeta(new NamedParameterJdbcTemplate(dataSource));
        this.plain = new JdbcTemplate(dataSource);
        this.plain.setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    /**
     * jConnect + SQL Anywhere 에는 jConnect 메타데이터 테이블이 없어서,
     * SQL 오류가 나면 Spring 이 DB 정보를 읽다가 JZ0SJ 경고를 남기고 진짜 오류를 가린다.
     * → DB 정보를 읽지 않는 SQLState 방식으로 오류를 해석한다.
     */
    private static NamedParameterJdbcTemplate noMeta(NamedParameterJdbcTemplate t) {
        ((JdbcTemplate) t.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
        return t;
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101.do")
    public String ai101(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai101");
        return "ai101";
    }

    // ------------------------------------------------------------------
    // 등급별 적립률 (CODE_MST)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/rates", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> rates(HttpSession session) {
        try {
            return ok(loadRates(jdbc, shopNo(session)));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private Map<String, Object> loadRates(NamedParameterJdbcTemplate j, String shop) {
        final Map<String, Object> rates = new LinkedHashMap<String, Object>();
        j.query("SELECT CODENM, CASHTERM, CASHCOST FROM CODE_MST WHERE CODEGU = '등급' AND SHOPNO = :shop",
            new MapSqlParameterSource("shop", shop),
            new RowMapper<Object>() {
                public Object mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> r = new LinkedHashMap<String, Object>();
                    r.put("cash", toDec(rs.getString("CASHTERM")));   // 현금 적립률
                    r.put("card", toDec(rs.getString("CASHCOST")));   // 카드 적립률
                    rates.put(trim(rs.getString("CODENM")).toUpperCase(), r);
                    return null;
                }
            });
        return rates;
    }

    // ------------------------------------------------------------------
    // 회원 검색 (해당 매장)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/members", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> members(@RequestParam("keyword") String keyword, HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("kw", "%" + keyword.replace("-", "").trim() + "%");
            return ok(jdbc.query(
                "SELECT TOP 30 " + MEMBER_COLS +
                "  FROM member " +
                " WHERE shopno = :shop AND (name LIKE :kw OR REPLACE(handno,'-','') LIKE :kw) " +
                " ORDER BY name", p, MEMBER_MAPPER));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static final String MEMBER_COLS =
        "memno, name, handno, member, saleamt, bonusamt, remk, lastdate, manager, job ";

    // ------------------------------------------------------------------
    // 회원 수정 (성명·전화번호·등급·담당·비고)  ※ job = 'WEB' 회원만 수정 가능 (POS 회원은 조회만)
    //   누적판매·포인트잔액은 판매/취소로만 바뀌므로 여기서는 고치지 않음
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/member/update", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> updateMember(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String shop = shopNo(session);
            String memno = str(req.get("memno"));
            String name = cut(str(req.get("name")), 20);
            String handno = cut(str(req.get("handno")), 20);
            String grade = cut(str(req.get("grade")), 10);
            if (isEmpty(memno)) throw new IllegalArgumentException("회원을 선택하세요.");
            if (isEmpty(name)) throw new IllegalArgumentException("성명을 입력하세요.");
            if (handno.replaceAll("\\D", "").length() < 9) throw new IllegalArgumentException("전화번호를 확인하세요.");
            if (isEmpty(grade)) throw new IllegalArgumentException("등급을 선택하세요.");

            MapSqlParameterSource k = new MapSqlParameterSource().addValue("shop", shop).addValue("memno", memno);
            List<String> job = jdbc.query("SELECT ISNULL(job, '') AS job FROM member WHERE shopno = :shop AND memno = :memno", k,
                new RowMapper<String>() {
                    public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString("job")); }
                });
            if (job.isEmpty()) throw new IllegalArgumentException("회원을 찾을 수 없습니다. (" + memno + ")");
            if (!"WEB".equals(job.get(0))) throw new IllegalArgumentException("WEB 회원만 수정할 수 있습니다. (POS 회원은 수정 불가)");

            jdbc.update(
                "UPDATE member SET name = :name, handno = :handno, member = :grade, manager = :manager, remk = :remk" +
                " WHERE shopno = :shop AND memno = :memno",
                new MapSqlParameterSource()
                    .addValue("name", name).addValue("handno", handno).addValue("grade", grade)
                    .addValue("manager", cut(str(req.get("manager")), 20))
                    .addValue("remk", cut(str(req.get("remk")), 100))
                    .addValue("shop", shop).addValue("memno", memno));
            logger.info("ai101 member update: " + memno + " " + name + " (by " + userId(session) + ")");
            return ok(jdbc.query("SELECT " + MEMBER_COLS + " FROM member WHERE shopno = :shop AND memno = :memno", k, MEMBER_MAPPER).get(0));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static final RowMapper<Map<String, Object>> MEMBER_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("memno",    trim(rs.getString("memno")));
            m.put("name",     trim(rs.getString("name")));
            m.put("handno",   trim(rs.getString("handno")));
            m.put("grade",    trim(rs.getString("member")));
            m.put("saleamt",  rs.getLong("saleamt"));
            m.put("bonusamt", rs.getLong("bonusamt"));
            m.put("remk",     trim(rs.getString("remk")));
            m.put("lastdate", dateFmt(trim(rs.getString("lastdate"))));
            m.put("manager",  trim(rs.getString("manager")));
            m.put("job",      trim(rs.getString("job")));       // 'WEB' 회원만 수정 가능
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 제품 검색 (바코드 정확히 일치 우선, 아니면 제품명·브랜드)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/products", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> products(@RequestParam("keyword") String keyword, HttpSession session) {
        try {
            String kw = keyword.trim();
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("grp", groupNo(session))          // 제품 마스터는 그룹 단위
                .addValue("code", kw)
                .addValue("kw", "%" + kw + "%");
            List<Map<String, Object>> list = jdbc.query(SELECT_JEPM +
                " WHERE SHOPNO = :grp AND CHK = 'Y' AND JEPMCD = :code", p, JEPM_MAPPER);
            if (list.isEmpty()) {
                list = jdbc.query(
                    "SELECT TOP 50 JEPMKEY, JEPMCD, BRAND, JEPMNM, PRICE, SALEPRICE FROM SHOP_JEPM_MST" +
                    " WHERE SHOPNO = :grp AND CHK = 'Y'" +
                    "   AND (JEPMNM LIKE :kw OR BRAND LIKE :kw OR JEPMCD LIKE :kw)" +
                    " ORDER BY BRAND, JEPMNM", p, JEPM_MAPPER);
            }
            return ok(list);
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static final String SELECT_JEPM =
        "SELECT JEPMKEY, JEPMCD, BRAND, JEPMNM, PRICE, SALEPRICE FROM SHOP_JEPM_MST";

    private static final RowMapper<Map<String, Object>> JEPM_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("jepmkey",   trim(rs.getString("JEPMKEY")));
            m.put("jepmcd",    trim(rs.getString("JEPMCD")));
            m.put("brand",     trim(rs.getString("BRAND")));
            m.put("jepmnm",    trim(rs.getString("JEPMNM")));
            m.put("price",     rs.getLong("PRICE"));
            m.put("saleprice", rs.getLong("SALEPRICE"));
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 결제 저장
    //   요청 : { memno, disc, point, cash(받은현금), card, remk,
    //            lines:[{ jepmcd, saleprice, qty, remk }] }
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/save", method = RequestMethod.POST)
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

    /** MC20_MST 처리일자·시간 : DB 서버 시각 기준 PRDATE(yyyymmdd), PRTIME(hhnn) */
    private static final String PR_DATE_TIME = " DATEFORMAT(GETDATE(), 'YYYYMMDD'), DATEFORMAT(GETDATE(), 'HHNN')";

    /** 트랜잭션 안에서 할 일 */
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
                        try { st.execute("ROLLBACK TRANSACTION"); } catch (SQLException ignore) { logger.error("ai101 rollback 실패", ignore); }
                        throw e;
                    }
                } finally {
                    st.close();
                }
            }
        });
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> doSave(NamedParameterJdbcTemplate j, Map<String, Object> req, String shop, String grp, String user) {
        String memno = str(req.get("memno"));
        long disc  = toLong(req.get("disc"));
        long point = toLong(req.get("point"));
        long cash  = toLong(req.get("cash"));
        long card  = toLong(req.get("card"));
        String remk = cut(str(req.get("remk")), 60);
        String seller = str(req.get("seller"));
        if (!isEmpty(seller)) {
            if (!isSeller(j, shop, seller)) throw new IllegalArgumentException("사용 중인 판매자가 아닙니다. (" + seller + ")");
            user = cut(seller, 12);
        }

        List<Map<String, Object>> reqLines = new ArrayList<Map<String, Object>>();
        Object raw = req.get("lines");
        if (raw instanceof List) for (Object o : (List<?>) raw) if (o instanceof Map) reqLines.add((Map<String, Object>) o);
        if (reqLines.isEmpty()) throw new IllegalArgumentException("판매할 제품이 없습니다.");
        if (disc < 0 || point < 0 || cash < 0 || card < 0) throw new IllegalArgumentException("금액이 잘못되었습니다.");

        // ---- 제품 정보 다시 읽기 (제품명·정가·입고가는 DB 기준, 판매가·수량은 화면 입력값)
        List<Map<String, Object>> lines = new ArrayList<Map<String, Object>>();
        long sumSale = 0, sumIn = 0;
        for (Map<String, Object> l : reqLines) {
            String jepmcd = str(l.get("jepmcd"));
            long qty = toLong(l.get("qty"));
            long salePrice = toLong(l.get("saleprice"));
            if (qty <= 0) throw new IllegalArgumentException("수량이 잘못되었습니다. (" + jepmcd + ")");
            List<Map<String, Object>> found = j.queryForList(
                "SELECT JEPMKEY, JEPMCD, BRAND, JEPMNM, PRICE, INPRICE FROM SHOP_JEPM_MST WHERE SHOPNO = :grp AND JEPMCD = :cd",
                new MapSqlParameterSource().addValue("grp", grp).addValue("cd", jepmcd));
            if (found.isEmpty()) throw new IllegalArgumentException("등록되지 않은 제품입니다. (" + jepmcd + ")");
            Map<String, Object> jp = upperKeys(found.get(0));
            // 판매가가 100 보다 작으면 할인율로 보고  판매가 = 정가 - (정가 × 할인율 / 100)  (할인액 원 단위 버림)
            if (salePrice > 0 && salePrice < 100) {
                long price = toLong(jp.get("PRICE"));
                salePrice = price - (price * salePrice / 100);
            }
            Map<String, Object> line = new HashMap<String, Object>();
            line.put("jepmkey",   str(jp.get("JEPMKEY")));
            line.put("jepmcd",    str(jp.get("JEPMCD")));
            line.put("jepmnm",    str(jp.get("JEPMNM")));
            line.put("price",     toLong(jp.get("PRICE")));
            line.put("inprice",   toLong(jp.get("INPRICE")));
            line.put("saleprice", salePrice);
            line.put("qty",       qty);
            line.put("remk",      cut(str(l.get("remk")), 60));
            lines.add(line);
            sumSale += salePrice * qty;
            sumIn   += toLong(jp.get("INPRICE")) * qty;
        }

        // ---- 회원 / 포인트
        String grade = "";
        long bonusBal = 0;
        if (!isEmpty(memno)) {
            List<Map<String, Object>> mem = j.queryForList(
                "SELECT member, bonusamt FROM member WHERE memno = :memno AND shopno = :shop",
                new MapSqlParameterSource().addValue("memno", memno).addValue("shop", shop));
            if (mem.isEmpty()) throw new IllegalArgumentException("회원을 찾을 수 없습니다. (" + memno + ")");
            Map<String, Object> m = upperKeys(mem.get(0));
            grade = str(m.get("MEMBER")).toUpperCase();
            bonusBal = toLong(m.get("BONUSAMT"));
            if (point > bonusBal) throw new IllegalArgumentException("포인트 잔액(" + bonusBal + ")보다 많이 사용할 수 없습니다.");
        } else if (point > 0) {
            throw new IllegalArgumentException("비회원은 포인트를 사용할 수 없습니다.");
        }

        // ---- 금액
        long amt = sumSale - disc - point;                   // 매출(= 현금 + 카드)
        if (amt < 0) throw new IllegalArgumentException("할인·포인트가 판매금액보다 많습니다.");
        if (card > amt) throw new IllegalArgumentException("카드 금액이 받을 금액보다 많습니다.");
        if (cash + card < amt) throw new IllegalArgumentException("받은 금액이 " + (amt - cash - card) + "원 부족합니다.");
        long cashNet = amt - card;                           // 거스름돈 뺀 현금
        long change  = cash - cashNet;

        // 적립 = 현금 × 현금적립률(CASHTERM) / 100 + 카드 × 카드적립률(CASHCOST) / 100  (합계에서 원 단위 버림)
        BigDecimal cashRate = BigDecimal.ZERO, cardRate = BigDecimal.ZERO;
        if (!isEmpty(memno)) {
            Object r = loadRates(j, shop).get(grade);
            if (r instanceof Map) {
                cashRate = (BigDecimal) ((Map<?, ?>) r).get("cash");
                cardRate = (BigDecimal) ((Map<?, ?>) r).get("card");
            } else {
                logger.warn("ai101 적립률 없음 : 등급=[" + grade + "] CODE_MST(CODEGU='등급', SHOPNO=" + shop + ") 에 해당 CODENM 이 있는지 확인");
            }
        }
        long bonus = BigDecimal.valueOf(cashNet).multiply(cashRate)
                        .add(BigDecimal.valueOf(card).multiply(cardRate))
                        .divide(BigDecimal.valueOf(100), 0, java.math.RoundingMode.DOWN).longValue();

        // 판매화면에서 적립 포인트를 직접 고친 경우 : 그 값으로 저장하고 REMK 에 '포인트수정' 표시
        long autoBonus = bonus;
        boolean bonusEdited = "true".equalsIgnoreCase(str(req.get("bonusEdited")));
        if (bonusEdited) {
            if (isEmpty(memno)) throw new IllegalArgumentException("비회원은 포인트를 적립할 수 없습니다.");
            long given = toLong(req.get("bonus"));
            if (given < 0) throw new IllegalArgumentException("적립 포인트가 잘못되었습니다.");
            if (given != autoBonus) {
                bonus = given;
                remk = cut(isEmpty(remk) ? "포인트수정" : "포인트수정 " + remk, 60);
            }
        }

        // ---- 키 (mc20key = SHOPNO + yymmddhhnnss, 같은 초면 1초씩 밀기)
        String cjpno = newCjpno(j, shop);
        String key = mc20key(shop, cjpno);
        String chdate = cjpno.substring(0, 8);

        // ---- MC20_MST
        j.update(
            "INSERT INTO MC20_MST (mc20key, SHOPNO, CHDATE, CJPNO, MEMNO, AMT, CASHAMT, CARDAMT, SALEAMT," +
            "                      BONUSUSE, BONUSAMT, INAMT, REMK, PRUSER, KIND, CARDNO, PRDATE, PRTIME, VISITCNT) " +
            "VALUES (:key, :shop, :chdate, :cjpno, :memno, :amt, :cash, :card, :disc," +
            "        :point, :bonus, :inamt, :remk, :user, 'WEB', ''," + PR_DATE_TIME + ", 1)",          // 방문수 1
            new MapSqlParameterSource()
                .addValue("key", key).addValue("shop", shop).addValue("chdate", chdate).addValue("cjpno", cjpno)
                .addValue("memno", memno).addValue("amt", amt).addValue("cash", cashNet).addValue("card", card)
                .addValue("disc", disc).addValue("point", point).addValue("bonus", bonus).addValue("inamt", sumIn)
                .addValue("remk", remk).addValue("user", user));

        // ---- MC20_DTL
        int seq = 0;
        for (Map<String, Object> l : lines) {
            seq++;
            j.update(
                "INSERT INTO MC20_DTL (mc20key, SHOPNO, CHDATE, CJPNO, SEQ, JEPMKEY, JEPMCD, JEPMNM, INPRICE, PRICE," +
                "                      SALEPRICE, QTY, AMT, CGUBUN, MEMNO, REMK, KIND) " +
                "VALUES (:key, :shop, :chdate, :cjpno, :seq, :jepmkey, :jepmcd, :jepmnm, :inprice, :price," +
                "        :saleprice, :qty, :amt, '일반', :memno, :remk, 'WEB')",
                new MapSqlParameterSource()
                    .addValue("key", key).addValue("shop", shop).addValue("chdate", chdate).addValue("cjpno", cjpno)
                    .addValue("seq", seq).addValue("jepmkey", l.get("jepmkey")).addValue("jepmcd", l.get("jepmcd"))
                    .addValue("jepmnm", l.get("jepmnm")).addValue("inprice", l.get("inprice")).addValue("price", l.get("price"))
                    .addValue("saleprice", l.get("saleprice")).addValue("qty", l.get("qty"))
                    .addValue("amt", (Long) l.get("saleprice") * (Long) l.get("qty"))
                    .addValue("memno", memno).addValue("remk", l.get("remk")));
            addJego(j, shop, str(l.get("jepmcd")), str(l.get("jepmkey")), -toLong(l.get("qty")));     // 재고 : 판매수량만큼 빼기
        }

        // ---- 회원 누적판매 / 포인트 / 최근방문
        if (!isEmpty(memno)) {
            j.update(
                "UPDATE member SET saleamt = saleamt + :amt, bonusamt = bonusamt - :point + :bonus, lastdate = :chdate" +
                " WHERE memno = :memno AND shopno = :shop",
                new MapSqlParameterSource()
                    .addValue("amt", amt).addValue("point", point).addValue("bonus", bonus)
                    .addValue("chdate", chdate).addValue("memno", memno).addValue("shop", shop));
        }

        logger.info("ai101 save: " + key + " amt=" + amt + " cash=" + cashNet + " card=" + card
                  + " grade=" + grade + " cashRate=" + cashRate + " cardRate=" + cardRate + " bonus=" + bonus
                  + (bonus != autoBonus ? " (포인트수정, 계산값 " + autoBonus + ")" : ""));

        Map<String, Object> r = new LinkedHashMap<String, Object>();
        r.put("key", key);
        r.put("cjpno", cjpno);
        r.put("amt", amt);
        r.put("cash", cashNet);
        r.put("card", card);
        r.put("change", change);
        r.put("bonus", bonus);
        r.put("bonusBal", isEmpty(memno) ? 0 : bonusBal - point + bonus);
        return r;
    }

    // ------------------------------------------------------------------
    // 매출조회 (MC20_MST)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/sales", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> sales(@RequestParam("from") String from,
                                     @RequestParam("to") String to,
                                     @RequestParam(value = "kind", required = false) String kind,
                                     @RequestParam(value = "keyword", required = false) String keyword,
                                     HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(
                "SELECT TOP 2000 a.mc20key, a.CHDATE, a.CJPNO, a.MEMNO, m.name, m.handno," +
                "       a.AMT, a.CASHAMT, a.CARDAMT, a.SALEAMT, a.BONUSUSE, a.BONUSAMT, a.INAMT, a.REMK, a.PRUSER, a.KIND, a.CARDNO, a.PRTIME," +
                "       (SELECT COUNT(*) FROM MC20_MST c WHERE c.SHOPNO = a.SHOPNO AND c.CARDNO = a.CJPNO) AS CANCELCNT" +
                "  FROM MC20_MST a" +
                "  LEFT OUTER JOIN member m ON m.memno = a.MEMNO AND m.shopno = a.SHOPNO" +
                " WHERE a.SHOPNO = :shop AND a.CHDATE BETWEEN :from AND :to");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("from", from.replace("-", ""))
                .addValue("to", to.replace("-", ""));
            if (!isEmpty(kind)) {
                // 구분으로 걸러도 취소전표(CARDNO 에 원CJPNO)는 함께 보여준다
                sql.append(" AND (a.KIND = :kind OR ISNULL(a.CARDNO, '') <> '')");
                p.addValue("kind", kind);
            }
            if (!isEmpty(keyword)) {
                sql.append(" AND (m.name LIKE :kw OR REPLACE(m.handno,'-','') LIKE :kw OR a.MEMNO = :kwExact)");
                p.addValue("kw", "%" + keyword.replace("-", "").trim() + "%").addValue("kwExact", keyword.trim());
            }
            sql.append(" ORDER BY a.mc20key DESC");
            return ok(jdbc.query(sql.toString(), p, new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    String cj = trim(rs.getString("CJPNO"));
                    Map<String, Object> m = new LinkedHashMap<String, Object>();
                    m.put("key",      trim(rs.getString("mc20key")));
                    m.put("date",     dateFmt(trim(rs.getString("CHDATE"))));
                    String pt = trim(rs.getString("PRTIME"));                                  // 처리시간 hhnn
                    m.put("time",     pt.length() >= 4 ? pt.substring(0, 2) + ":" + pt.substring(2, 4) : "");
                    m.put("cjpno",    cj);
                    m.put("memno",    trim(rs.getString("MEMNO")));
                    m.put("name",     trim(rs.getString("name")));
                    m.put("handno",   trim(rs.getString("handno")));
                    m.put("amt",      rs.getLong("AMT"));
                    m.put("cash",     rs.getLong("CASHAMT"));
                    m.put("card",     rs.getLong("CARDAMT"));
                    m.put("disc",     rs.getLong("SALEAMT"));
                    m.put("point",    rs.getLong("BONUSUSE"));
                    m.put("bonus",    rs.getLong("BONUSAMT"));
                    m.put("inamt",    rs.getLong("INAMT"));
                    m.put("remk",     trim(rs.getString("REMK")));
                    m.put("pruser",   trim(rs.getString("PRUSER")));
                    m.put("kind",     trim(rs.getString("KIND")));
                    m.put("canceled", rs.getInt("CANCELCNT") > 0);                         // 이미 취소된 원전표
                    m.put("cardno",   trim(rs.getString("CARDNO")));
                    m.put("isCancel", !trim(rs.getString("CARDNO")).isEmpty());   // CARDNO 에 원CJPNO 가 있으면 취소전표
                    return m;
                }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 매출취소 : 원전표를 마이너스로 한 취소전표를 오늘 날짜로 새로 만든다
    //   MC20_MST : AMT, CASHAMT, CARDAMT, SALEAMT, BONUSUSE, BONUSAMT, INAMT 마이너스
    //              CARDNO = 원전표 CJPNO  (빈칸 = 정상, 값 있음 = 취소전표 / 중복취소 방지에도 사용)
    //   MC20_DTL : QTY, AMT 마이너스 (단가는 그대로)
    //   member   : saleamt, bonusamt 되돌림 (누적판매 - 매출, 포인트 + 사용분 - 적립분)
    // ------------------------------------------------------------------

    @RequestMapping(value = "/ai101/cancel", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> cancel(@RequestBody final Map<String, Object> req, HttpSession session) {
        try {
            final String shop = shopNo(session);
            final String user = userId(session);
            return ok(inTx(new TxWork() {
                public Map<String, Object> run(NamedParameterJdbcTemplate j) { return doCancel(j, str(req.get("key")), shop, user); }
            }));
        } catch (Exception e) {
            return fail(e);
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

    private Map<String, Object> doCancel(NamedParameterJdbcTemplate j, String orgKey, String shop, String user) {
        MapSqlParameterSource kp = new MapSqlParameterSource().addValue("key", orgKey).addValue("shop", shop);
        List<Map<String, Object>> mst = j.queryForList(
            "SELECT CJPNO, MEMNO, AMT, CASHAMT, CARDAMT, SALEAMT, BONUSUSE, BONUSAMT, INAMT, CARDNO, KIND FROM MC20_MST" +
            " WHERE mc20key = :key AND SHOPNO = :shop", kp);
        if (mst.isEmpty()) throw new IllegalArgumentException("매출을 찾을 수 없습니다.");
        Map<String, Object> o = upperKeys(mst.get(0));
        String orgCjpno = str(o.get("CJPNO"));
        // 웹에서 판매한 매출(KIND = 'WEB')만 웹에서 취소 가능 / POS 매출은 취소 불가
        if (!"WEB".equals(str(o.get("KIND"))))
            throw new IllegalArgumentException("WEB 매출만 취소할 수 있습니다. (POS 매출은 취소 불가)");
        if (!isEmpty(str(o.get("CARDNO"))) || toLong(o.get("AMT")) < 0)
            throw new IllegalArgumentException("취소전표는 다시 취소할 수 없습니다.");
        Integer done = j.queryForObject("SELECT COUNT(*) FROM MC20_MST WHERE SHOPNO = :shop AND CARDNO = :org",
            new MapSqlParameterSource().addValue("shop", shop).addValue("org", orgCjpno), Integer.class);
        if (done != null && done > 0) throw new IllegalArgumentException("이미 취소된 매출입니다.");

        String memno = str(o.get("MEMNO"));
        long amt   = toLong(o.get("AMT")),      cash  = toLong(o.get("CASHAMT")), card = toLong(o.get("CARDAMT"));
        long disc  = toLong(o.get("SALEAMT")),  point = toLong(o.get("BONUSUSE")), bonus = toLong(o.get("BONUSAMT"));
        long inamt = toLong(o.get("INAMT"));

        String cjpno  = newCjpno(j, shop);
        String key    = mc20key(shop, cjpno);
        String chdate = cjpno.substring(0, 8);   // 취소일 = 오늘

        // ---- MC20_MST (마이너스)
        j.update(
            "INSERT INTO MC20_MST (mc20key, SHOPNO, CHDATE, CJPNO, MEMNO, AMT, CASHAMT, CARDAMT, SALEAMT," +
            "                      BONUSUSE, BONUSAMT, INAMT, REMK, PRUSER, KIND, CARDNO, PRDATE, PRTIME, VISITCNT) " +
            "VALUES (:key, :shop, :chdate, :cjpno, :memno, :amt, :cash, :card, :disc," +
            "        :point, :bonus, :inamt, :remk, :user, 'WEB', :cardno," + PR_DATE_TIME + ", -1)",   // 취소 : 방문수 -1
            new MapSqlParameterSource()
                .addValue("key", key).addValue("shop", shop).addValue("chdate", chdate).addValue("cjpno", cjpno)
                .addValue("cardno", orgCjpno)
                .addValue("memno", memno).addValue("amt", -amt).addValue("cash", -cash).addValue("card", -card)
                .addValue("disc", -disc).addValue("point", -point).addValue("bonus", -bonus).addValue("inamt", -inamt)
                .addValue("remk", "").addValue("user", user));

        // ---- MC20_DTL (수량·금액 마이너스)
        List<Map<String, Object>> dtl = j.queryForList(
            "SELECT SEQ, JEPMKEY, JEPMCD, JEPMNM, INPRICE, PRICE, SALEPRICE, QTY, CGUBUN, REMK FROM MC20_DTL" +
            " WHERE mc20key = :key AND SHOPNO = :shop ORDER BY SEQ", kp);
        for (Map<String, Object> row : dtl) {
            Map<String, Object> d = upperKeys(row);
            long qty = toLong(d.get("QTY")), sp = toLong(d.get("SALEPRICE"));
            j.update(
                "INSERT INTO MC20_DTL (mc20key, SHOPNO, CHDATE, CJPNO, SEQ, JEPMKEY, JEPMCD, JEPMNM, INPRICE, PRICE," +
                "                      SALEPRICE, QTY, AMT, CGUBUN, MEMNO, REMK, KIND) " +
                "VALUES (:key, :shop, :chdate, :cjpno, :seq, :jepmkey, :jepmcd, :jepmnm, :inprice, :price," +
                "        :saleprice, :qty, :amt, :cgubun, :memno, :remk, 'WEB')",
                new MapSqlParameterSource()
                    .addValue("key", key).addValue("shop", shop).addValue("chdate", chdate).addValue("cjpno", cjpno)
                    .addValue("seq", toLong(d.get("SEQ"))).addValue("jepmkey", str(d.get("JEPMKEY")))
                    .addValue("jepmcd", str(d.get("JEPMCD"))).addValue("jepmnm", str(d.get("JEPMNM")))
                    .addValue("inprice", toLong(d.get("INPRICE"))).addValue("price", toLong(d.get("PRICE")))
                    .addValue("saleprice", sp).addValue("qty", -qty).addValue("amt", -(qty * sp))
                    .addValue("cgubun", str(d.get("CGUBUN"))).addValue("memno", memno).addValue("remk", str(d.get("REMK"))));
            addJego(j, shop, str(d.get("JEPMCD")), str(d.get("JEPMKEY")), qty);                          // 재고 : 취소수량만큼 되돌리기
        }

        // ---- member 누적판매 / 포인트 되돌리기
        if (!isEmpty(memno)) {
            j.update(
                "UPDATE member SET saleamt = saleamt - :amt, bonusamt = bonusamt + :point - :bonus" +
                " WHERE memno = :memno AND shopno = :shop",
                new MapSqlParameterSource()
                    .addValue("amt", amt).addValue("point", point).addValue("bonus", bonus)
                    .addValue("memno", memno).addValue("shop", shop));
        }

        logger.info("ai101 cancel: " + orgKey + " -> " + key + " amt=-" + amt + " bonus=-" + bonus + " point=+" + point);

        Map<String, Object> r = new LinkedHashMap<String, Object>();
        r.put("key", key);
        r.put("amt", -amt);
        return r;
    }

    // ------------------------------------------------------------------
    // 판매자 목록 (user_info.chk = 'Y')
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/sellers", method = RequestMethod.GET)
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

    private boolean isSeller(NamedParameterJdbcTemplate j, String shop, String name) {
        Integer n = j.queryForObject("SELECT COUNT(*) FROM user_info WHERE chk = 'Y' AND shopno = :shop AND name = :name",
            new MapSqlParameterSource().addValue("shop", shop).addValue("name", name), Integer.class);
        return n != null && n > 0;
    }

    // ------------------------------------------------------------------
    // 판매자 변경 (MC20_MST.PRUSER) — user_info.position = '메니저' 의 암호를 확인한 뒤 변경
    // ------------------------------------------------------------------
    /** user_info 의 암호 컬럼 이름 — 로그인에서 쓰는 컬럼명으로 맞추세요 */
    private static final String MANAGER_PW_COLUMN = "userpass";
    private static final String MANAGER_POSITION  = "메니저";

    @RequestMapping(value = "/ai101/seller", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> changeSeller(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String key = str(req.get("key"));
            String seller = str(req.get("seller"));
            if (isEmpty(seller)) throw new IllegalArgumentException("판매자를 선택하세요.");
            if (!isSeller(jdbc, shopNo(session), seller)) throw new IllegalArgumentException("사용 중인 판매자가 아닙니다. (" + seller + ")");
            if (!isWebSale(shopNo(session), key)) throw new IllegalArgumentException("WEB 매출만 판매자를 바꿀 수 있습니다. (POS 매출은 변경 불가)");

            // 매니저 암호 확인
            String pw = str(req.get("pw"));
            if (isEmpty(pw)) throw new IllegalArgumentException("매니저 암호를 입력하세요.");
            List<String> mgr = jdbc.query(
                "SELECT name FROM user_info WHERE chk = 'Y' AND position = :pos AND " + MANAGER_PW_COLUMN + " = :pw",
                new MapSqlParameterSource().addValue("pos", MANAGER_POSITION).addValue("pw", pw),
                new RowMapper<String>() {
                    public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString("name")); }
                });
            if (mgr.isEmpty()) {
                logger.warn("ai101 seller: 매니저 암호 불일치 (by " + userId(session) + ")");
                throw new IllegalArgumentException("매니저 암호가 맞지 않습니다.");
            }

            int cnt = jdbc.update("UPDATE MC20_MST SET PRUSER = :seller WHERE mc20key = :key AND SHOPNO = :shop",
                new MapSqlParameterSource()
                    .addValue("seller", cut(seller, 12)).addValue("key", key).addValue("shop", shopNo(session)));
            if (cnt == 0) throw new IllegalArgumentException("매출을 찾을 수 없습니다.");
            logger.info("ai101 seller: " + key + " -> " + seller + " (승인 " + mgr.get(0) + ", by " + userId(session) + ")");
            return ok(null);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 매출상세 (MC20_DTL)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai101/sales/detail", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> salesDetail(@RequestParam("key") String key, HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("grp", groupNo(session))
                .addValue("key", key);
            return ok(jdbc.query(
                "SELECT d.SEQ, d.JEPMCD, j.BRAND, d.JEPMNM, d.PRICE, d.SALEPRICE, d.QTY, d.INPRICE, d.REMK" +
                "  FROM MC20_DTL d" +
                "  LEFT OUTER JOIN SHOP_JEPM_MST j ON j.SHOPNO = :grp AND j.JEPMCD = d.JEPMCD" +   // 제품 마스터 : 그룹
                " WHERE d.mc20key = :key AND d.SHOPNO = :shop" +
                " ORDER BY d.SEQ", p,
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("seq",       rs.getInt("SEQ"));
                        m.put("jepmcd",    trim(rs.getString("JEPMCD")));
                        m.put("brand",     trim(rs.getString("BRAND")));
                        m.put("jepmnm",    trim(rs.getString("JEPMNM")));
                        m.put("price",     rs.getLong("PRICE"));
                        m.put("saleprice", rs.getLong("SALEPRICE"));
                        m.put("qty",       rs.getLong("QTY"));
                        m.put("inprice",   rs.getLong("INPRICE"));
                        m.put("remk",      trim(rs.getString("REMK")));
                        return m;
                    }
                }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** KIND = 'WEB' 인 매출 전표 (웹 판매·취소전표) → 판매자 변경·취소 가능 / POS 매출은 조회만 */
    private boolean isWebSale(String shop, String key) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM MC20_MST WHERE mc20key = :key AND SHOPNO = :shop AND KIND = 'WEB'",
            new MapSqlParameterSource().addValue("key", key).addValue("shop", shop), Integer.class);
        return n != null && n > 0;
    }

    private String newCjpno(NamedParameterJdbcTemplate j, String shop) {
        SimpleDateFormat f = new SimpleDateFormat("yyyyMMddHHmmss");
        Date now = new Date();
        String cjpno = f.format(now);
        for (int i = 0; i < 10 && exists(j, mc20key(shop, cjpno)); i++) {
            now = new Date(now.getTime() + 1000);
            cjpno = f.format(now);
        }
        return cjpno;
    }

    /** mc20key = SHOPNO + yymmddhhnnss  (CJPNO 는 yyyymmddhhnnss 그대로) */
    private static String mc20key(String shop, String cjpno) {
        return shop.trim() + cjpno.substring(2);
    }

    private boolean exists(NamedParameterJdbcTemplate j, String key) {
        Integer n = j.queryForObject("SELECT COUNT(*) FROM MC20_MST WHERE mc20key = :k",
            new MapSqlParameterSource("k", key), Integer.class);
        return n != null && n > 0;
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
    // 공통
    // ------------------------------------------------------------------
    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ai101 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    /** queryForList 결과 컬럼명을 대문자로 통일 (드라이버마다 대소문자가 달라서) */
    private static Map<String, Object> upperKeys(Map<String, Object> src) {
        Map<String, Object> m = new HashMap<String, Object>();
        for (Map.Entry<String, Object> e : src.entrySet()) m.put(e.getKey().toUpperCase(), e.getValue());
        return m;
    }

    private static String trim(String s)      { return s == null ? "" : s.trim(); }
    private static String str(Object o)       { return o == null ? "" : o.toString().trim(); }
    private static boolean isEmpty(String s)  { return s == null || s.trim().isEmpty(); }
    private static String dateFmt(String d)   { return d.length() == 8 && d.matches("\\d{8}") ? d.substring(0, 4) + "-" + d.substring(4, 6) + "-" + d.substring(6) : d; }
    private static BigDecimal toDec(String v) {
        try { return v == null || v.trim().isEmpty() ? BigDecimal.ZERO : new BigDecimal(v.replace(",", "").trim()); }
        catch (Exception e) { return BigDecimal.ZERO; }
    }

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
