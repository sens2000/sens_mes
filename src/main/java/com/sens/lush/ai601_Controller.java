package com.sens.lush;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
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
import org.springframework.jdbc.core.ConnectionCallback;
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
 * 매장 재고조사 (ai601)
 *  - 화면 : /ai601.do → ai601.jsp
 *  - 입력 : 제품 검색(제품코드·제조회사·브랜드·제품명) → 실사 수량 입력 → REAL_JEGO 한 건 INSERT
 *           같은 제품을 다시 입력하면 한 건 더 생기고, 실사 수량 = 그 제품 REAL_JEGO.JEGO 합계
 *  - 마감 : 실사 수량 − 전산재고(SHOP_JEPM_MST.JEGO) = 차이 → MC27_MST 1건 + MC27_DTL(조사한 제품마다 1건, 차이 0 포함)
 *           CGUBUN '실사', AMT = Σ(입고가 × 차이), MC27KEY = SHOPNO + CJPNO(yyyyMMddHHmmss)
 *           SHOP_JEPM_MST.JEGO 에 차이 반영 (UPDATE_JEGO), 처리한 REAL_JEGO 삭제
 *  - 조사하지 않은 제품은 마감해도 재고가 바뀌지 않음
 *
 *  /ai601/products  제품 검색 (최대 200)
 *  /ai601/list      조사 목록 (조사한 제품 + 전산재고가 있는 미조사 제품)
 *  /ai601/entries   한 제품의 입력 내역
 *  /ai601/recent    최근 입력 20건
 *  /ai601/save      수량 입력 (JSON)
 *  /ai601/delete    입력 한 건 삭제 (JSON)
 *  /ai601/close     조사 마감 · 재고 반영 (JSON)
 *  /ai601/adjList   재고조정 조회 — MC27_MST (기간)
 *  /ai601/adjDtl    재고조정 조회 — MC27_DTL (선택한 전표)
 *  /ai601/adjDelete 재고조정 전표 삭제 — DTL 수량만큼 재고 + , DTL · MST 삭제
 *  /ai601/reset     재고 초기화 — 재고 있는 제품 전부 0 (MC27 REMK '재고초기화')
 */
@Controller
public class ai601_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";

    private static final int PRODUCT_MAX = 200;
    private static final int LIST_MAX    = 10000;
    private static final int RECENT_MAX  = 20;

    /**
     * 마감할 때 SHOP_JEPM_MST.JEGO 를 직접 고칠지 여부.
     * MC27_DTL 에 재고를 고치는 트리거가 이미 있으면 false 로 바꿔야 두 번 반영되지 않음.
     */
    private static final boolean UPDATE_JEGO = true;

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ai601_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // 주의 : setMaxRows 는 jConnect JZ0SJ 오류가 나므로 쓰지 않음 (ResultSetExtractor 로 끊어 읽음)
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601.do")
    public String ai601(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai601");
        return "ai601";
    }

    // ------------------------------------------------------------------
    // 제품 검색
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/products", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> products(@RequestParam(value = "jepmcd",   defaultValue = "") String jepmcd,
                                        @RequestParam(value = "makecust", defaultValue = "") String makecust,
                                        @RequestParam(value = "brand",    defaultValue = "") String brand,
                                        @RequestParam(value = "jepmnm",   defaultValue = "") String jepmnm,
                                        HttpSession session) {
        try {
            if (isEmpty(makecust) && isEmpty(brand) && isEmpty(jepmnm) && isEmpty(jepmcd))
                throw new IllegalArgumentException("제품코드·제조회사·브랜드·제품명 중 하나는 입력하세요.");
            String shop = shopNo(session);
            MapSqlParameterSource p = new MapSqlParameterSource("shop", shop);

            // 바코드를 통째로 찍은 경우 : 코드가 정확히 같은 제품이 있으면 그것만
            if (!isEmpty(jepmcd) && isEmpty(makecust) && isEmpty(brand) && isEmpty(jepmnm)) {
                p.addValue("code", jepmcd.trim());
                List<Map<String, Object>> exact = jdbc.query(
                    PRODUCT_SQL + " WHERE j.shopno = :shop AND j.jepmcd = :code ORDER BY j.jepmnm", p, PRODUCT_ROW);
                if (!exact.isEmpty()) return ok(rows(exact, false));
            }

            StringBuilder sql = new StringBuilder(PRODUCT_SQL + " WHERE j.shopno = :shop AND j.sys = 'N'");
            like(sql, p, "j.jepmcd",   "jepmcd",   jepmcd);
            like(sql, p, "j.makecust", "makecust", makecust);
            like(sql, p, "j.brand",    "brand",    brand);
            like(sql, p, "j.jepmnm",   "jepmnm",   jepmnm);
            sql.append(" ORDER BY j.makecust, j.brand, j.jepmnm");

            List<Map<String, Object>> list = jdbc.query(sql.toString(), p, limit(PRODUCT_ROW, PRODUCT_MAX + 1));
            boolean more = list.size() > PRODUCT_MAX;
            if (more) list = list.subList(0, PRODUCT_MAX);
            return ok(rows(list, more));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 제품 + 지금까지 입력한 실사 수량 합계 / 입력 건수 */
    private static final String PRODUCT_SQL =
        "SELECT j.jepmkey, j.jepmcd, j.makecust, j.brand, j.jepmnm," +
        "       ISNULL(j.inprice, 0) AS INPRICE, ISNULL(j.jego, 0) AS JEGO," +
        "       ( SELECT SUM(r.jego) FROM real_jego r WHERE r.shopno = :shop AND r.jepmkey = j.jepmkey ) AS REALQTY," +
        "       ( SELECT COUNT(*)    FROM real_jego r WHERE r.shopno = :shop AND r.jepmkey = j.jepmkey ) AS CNT" +
        "  FROM shop_jepm_mst j";

    private static final RowMapper<Map<String, Object>> PRODUCT_ROW = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("jepmkey",  trim(rs.getString("jepmkey")));
            m.put("jepmcd",   trim(rs.getString("jepmcd")));
            m.put("makecust", trim(rs.getString("makecust")));
            m.put("brand",    trim(rs.getString("brand")));
            m.put("jepmnm",   trim(rs.getString("jepmnm")));
            m.put("inprice",  rs.getLong("INPRICE"));
            m.put("jego",     rs.getLong("JEGO"));
            int cnt = rs.getInt("CNT");
            m.put("cnt",      cnt);
            m.put("realqty",  cnt == 0 ? null : Long.valueOf(rs.getLong("REALQTY")));   // null = 미조사
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 조사 목록 (조사한 제품 + 전산재고가 0 이 아닌 미조사 제품)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(HttpSession session) {
        try {
            String sql =
                "SELECT j.jepmkey, j.jepmcd, j.makecust, j.brand, j.jepmnm," +
                "       ISNULL(j.inprice, 0) AS INPRICE, ISNULL(j.jego, 0) AS JEGO," +
                "       r.qty AS REALQTY, ISNULL(r.cnt, 0) AS CNT, r.lasttime" +
                "  FROM shop_jepm_mst j" +
                "  LEFT OUTER JOIN ( SELECT jepmkey, SUM(jego) AS qty, COUNT(*) AS cnt, MAX(prdatetime) AS lasttime" +
                "                      FROM real_jego WHERE shopno = :shop GROUP BY jepmkey ) r" +
                "    ON r.jepmkey = j.jepmkey" +
                " WHERE j.shopno = :shop" +
                "   AND ( r.jepmkey IS NOT NULL OR ( j.sys = 'N' AND j.jego <> 0 ) )" +
                " ORDER BY j.makecust, j.brand, j.jepmnm";
            List<Map<String, Object>> list = jdbc.query(sql, new MapSqlParameterSource("shop", shopNo(session)),
                limit(new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = PRODUCT_ROW.mapRow(rs, i);
                        m.put("lasttime", trim(rs.getString("lasttime")));
                        return m;
                    }
                }, LIST_MAX + 1));
            boolean more = list.size() > LIST_MAX;
            if (more) list = list.subList(0, LIST_MAX);
            return ok(rows(list, more));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 한 제품의 입력 내역
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/entries", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> entries(@RequestParam("jepmkey") String jepmkey, HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("key", jepmkey.trim());
            return ok(jdbc.query(
                "SELECT jepmkey, jepmcd, jego, prdatetime, '' AS jepmnm FROM real_jego" +
                " WHERE shopno = :shop AND jepmkey = :key ORDER BY prdatetime DESC", p, ENTRY_ROW));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 최근 입력
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/recent", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> recent(HttpSession session) {
        try {
            return ok(jdbc.query(
                "SELECT r.jepmkey, r.jepmcd, r.jego, r.prdatetime, ISNULL(j.jepmnm, '') AS jepmnm" +
                "  FROM real_jego r" +
                "  LEFT OUTER JOIN shop_jepm_mst j ON j.shopno = r.shopno AND j.jepmkey = r.jepmkey" +
                " WHERE r.shopno = :shop ORDER BY r.prdatetime DESC",
                new MapSqlParameterSource("shop", shopNo(session)), limit(ENTRY_ROW, RECENT_MAX)));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private static final RowMapper<Map<String, Object>> ENTRY_ROW = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("jepmkey",    trim(rs.getString("jepmkey")));
            m.put("jepmcd",     trim(rs.getString("jepmcd")));
            m.put("jepmnm",     trim(rs.getString("jepmnm")));
            m.put("qty",        rs.getLong("jego"));
            m.put("prdatetime", trim(rs.getString("prdatetime")));
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 수량 입력 — REAL_JEGO 한 건 추가 (같은 제품이면 합계에 더해짐)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            String key = str(body.get("jepmkey"));
            String qtyS = str(body.get("qty"));
            if (key.isEmpty()) throw new IllegalArgumentException("제품을 먼저 선택하세요.");
            if (!qtyS.matches("\\d{1,6}")) throw new IllegalArgumentException("수량은 0 이상 숫자로 입력하세요.");
            String shop = shopNo(session);

            Map<String, Object> prod = findProduct(shop, key);
            if (prod == null) throw new IllegalArgumentException("이 매장에 없는 제품입니다. 다시 검색하세요.");

            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("key", key)
                .addValue("shop", shop)
                .addValue("code", prod.get("jepmcd"))
                .addValue("qty", Integer.valueOf(qtyS), Types.INTEGER)
                .addValue("dt", new SimpleDateFormat("yyyyMMddHHmmss").format(new Date()));
            jdbc.update(
                "INSERT INTO real_jego (jepmkey, shopno, jepmcd, jego, prdatetime)" +
                " VALUES (:key, :shop, :code, :qty, :dt)", p);

            return ok(findProduct(shop, key));   // 합계가 바뀐 제품 한 줄을 돌려줌
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 입력 한 건 삭제 (잘못 넣은 수량 취소)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/delete", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> delete(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            String key = str(body.get("jepmkey"));
            String dt  = str(body.get("prdatetime"));
            if (key.isEmpty() || dt.isEmpty()) throw new IllegalArgumentException("삭제할 입력을 선택하세요.");
            String shop = shopNo(session);
            int n = jdbc.update(
                "DELETE FROM real_jego WHERE shopno = :shop AND jepmkey = :key AND prdatetime = :dt",
                new MapSqlParameterSource().addValue("shop", shop).addValue("key", key).addValue("dt", dt));
            if (n == 0) throw new IllegalArgumentException("삭제할 입력을 찾을 수 없습니다. 다시 조회하세요.");
            return ok(findProduct(shop, key));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 조사 마감 · 재고 반영
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/close", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> close(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            final String shop = shopNo(session);
            final String remk = str(body.get("remk"));
            return ok(inTx(new Work() {
                public Map<String, Object> run(NamedParameterJdbcTemplate t) { return doClose(t, shop, remk); }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private Map<String, Object> doClose(NamedParameterJdbcTemplate t, String shop, String remk) {
        // 1) 조사한 제품별 실사 합계와 전산재고 → 차이
        MapSqlParameterSource sp = new MapSqlParameterSource("shop", shop);
        List<Map<String, Object>> lines = t.query(
            "SELECT j.jepmkey, j.jepmcd, j.jepmnm, ISNULL(j.inprice, 0) AS INPRICE, ISNULL(j.jego, 0) AS JEGO, r.qty AS REALQTY" +
            "  FROM ( SELECT jepmkey, SUM(jego) AS qty FROM real_jego WHERE shopno = :shop GROUP BY jepmkey ) r" +
            "  JOIN shop_jepm_mst j ON j.shopno = :shop AND j.jepmkey = r.jepmkey" +
            " ORDER BY j.makecust, j.brand, j.jepmnm", sp,
            new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = line(rs);
                    m.put("qty", rs.getLong("JEGO") - rs.getLong("REALQTY"));   // MC27 수량 : + 재고 감소, − 재고 증가
                    m.put("real", rs.getLong("REALQTY"));                          // 실사 수량 → 새 재고
                    return m;
                }
            });
        if (lines.isEmpty()) throw new IllegalArgumentException("입력된 실사 수량이 없습니다.");

        // 2) MC27 마스터 1건 + 조사한 제품마다 상세 1건 (차이 0 포함)
        Map<String, Object> r = writeMc27(t, shop, remk, lines);

        // 3) SHOP_JEPM_MST.JEGO 를 실사 수량으로 변경 (차이 있는 제품만)
        //    예) 현재고 1, 실사 5 → MC27 QTY -4, JEGO = 5
        int updated = 0;
        for (Map<String, Object> m : lines) {
            if ((Long) m.get("qty") == 0) continue;
            updated += t.update("UPDATE shop_jepm_mst SET jego = :real WHERE shopno = :shop AND jepmkey = :key",
                new MapSqlParameterSource().addValue("real", m.get("real"), Types.NUMERIC)
                    .addValue("shop", shop).addValue("key", m.get("jepmkey")));
        }
        r.put("updated", updated);          // 재고를 바꾼 제품 수

        // 4) 이 매장의 실사 입력(REAL_JEGO) 전부 삭제
        r.put("removed", t.update("DELETE FROM real_jego WHERE shopno = :shop", sp));
        return r;
    }

    // ------------------------------------------------------------------
    // 재고 초기화 — 전산재고가 0 이 아닌 제품을 모두 0 으로
    //   MC27_MST 1건 (REMK '재고초기화') + MC27_DTL (QTY = 현재고, + 는 재고 감소) → JEGO = 0
    //   REAL_JEGO (조사 입력) 는 건드리지 않음
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/reset", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> reset(HttpSession session) {
        try {
            final String shop = shopNo(session);
            return ok(inTx(new Work() {
                public Map<String, Object> run(NamedParameterJdbcTemplate t) { return doReset(t, shop); }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    private Map<String, Object> doReset(NamedParameterJdbcTemplate t, String shop) {
        MapSqlParameterSource sp = new MapSqlParameterSource("shop", shop);
        List<Map<String, Object>> lines = t.query(
            "SELECT j.jepmkey, j.jepmcd, j.jepmnm, ISNULL(j.inprice, 0) AS INPRICE, j.jego AS JEGO" +
            "  FROM shop_jepm_mst j WHERE j.shopno = :shop AND j.jego <> 0" +
            " ORDER BY j.makecust, j.brand, j.jepmnm", sp,
            new RowMapper<Map<String, Object>>() {
                public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                    Map<String, Object> m = line(rs);
                    m.put("qty", rs.getLong("JEGO"));        // 0 으로 만들려고 빼는 수량
                    return m;
                }
            });
        if (lines.isEmpty()) throw new IllegalArgumentException("재고가 있는 제품이 없습니다. (이미 모두 0)");

        Map<String, Object> r = writeMc27(t, shop, "재고초기화", lines);
        if (UPDATE_JEGO) {
            r.put("updated", t.update("UPDATE shop_jepm_mst SET jego = 0 WHERE shopno = :shop AND jego <> 0", sp));
        }
        return r;
    }

    // ------------------------------------------------------------------
    // 재고조정 조회 — 왼쪽 MC27_MST (기간), 오른쪽 선택한 전표의 MC27_DTL
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/adjList", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> adjList(@RequestParam("from") String from, @RequestParam("to") String to,
                                       HttpSession session) {
        try {
            String f = from.replace("-", "").trim(), t = to.replace("-", "").trim();
            if (!f.matches("\\d{8}") || !t.matches("\\d{8}")) throw new IllegalArgumentException("기간을 확인하세요.");
            if (f.compareTo(t) > 0) throw new IllegalArgumentException("시작일이 종료일보다 늦습니다.");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("f", f).addValue("t", t);
            return ok(jdbc.query(
                "SELECT a.mc27key, a.cjpno, a.chdate, ISNULL(a.amt, 0) AS AMT, a.remk, a.prdate, a.cgubun" +
                "  FROM mc27_mst a" +
                " WHERE a.shopno = :shop AND a.chdate BETWEEN :f AND :t" +
                " ORDER BY a.chdate DESC, a.cjpno DESC", p,
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("mc27key", trim(rs.getString("mc27key")));
                        m.put("cjpno",   trim(rs.getString("cjpno")));
                        m.put("chdate",  trim(rs.getString("chdate")));
                        m.put("amt",     rs.getLong("AMT"));
                        m.put("remk",    trim(rs.getString("remk")));
                        m.put("prdate",  trim(rs.getString("prdate")));
                        m.put("cgubun",  trim(rs.getString("cgubun")));
                        return m;
                    }
                }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    @RequestMapping(value = "/ai601/adjDtl", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> adjDtl(@RequestParam("mc27key") String mc27key, HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session)).addValue("mkey", mc27key.trim());
            return ok(jdbc.query(
                "SELECT d.seq, d.jepmcd, d.jepmnm, ISNULL(d.qty, 0) AS QTY" +
                "  FROM mc27_dtl d" +
                " WHERE d.mc27key = :mkey AND d.shopno = :shop" +
                " ORDER BY d.seq", p,
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("seq",    rs.getInt("seq"));
                        m.put("jepmcd", trim(rs.getString("jepmcd")));
                        m.put("jepmnm", trim(rs.getString("jepmnm")));
                        m.put("qty",    rs.getLong("QTY"));
                        return m;
                    }
                }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 재고조정 전표 삭제 — MC27_DTL 수량만큼 재고에 더하고 (조정 되돌림) DTL · MST 삭제
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai601/adjDelete", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> adjDelete(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            final String shop = shopNo(session);
            final String mkey = str(body.get("mc27key"));
            if (mkey.isEmpty()) throw new IllegalArgumentException("삭제할 전표를 선택하세요.");
            return ok(inTx(new Work() {
                public Map<String, Object> run(NamedParameterJdbcTemplate t) {
                    MapSqlParameterSource p = new MapSqlParameterSource().addValue("shop", shop).addValue("mkey", mkey);
                    Integer cnt = t.queryForObject(
                        "SELECT COUNT(*) FROM mc27_mst WHERE shopno = :shop AND mc27key = :mkey", p, Integer.class);
                    if (cnt == null || cnt == 0) throw new IllegalArgumentException("삭제할 전표를 찾을 수 없습니다. 다시 조회하세요.");

                    int restored = 0;
                    if (UPDATE_JEGO) {
                        // 제품별 수량 합계만큼 재고에 더함 (같은 제품이 여러 줄이어도 한 번에)
                        restored = t.update(
                            "UPDATE shop_jepm_mst" +
                            "   SET jego = ISNULL(jego, 0) + ( SELECT SUM(ISNULL(d.qty, 0)) FROM mc27_dtl d" +
                            "                                   WHERE d.mc27key = :mkey AND d.jepmkey = shop_jepm_mst.jepmkey )" +
                            " WHERE shopno = :shop" +
                            "   AND jepmkey IN ( SELECT d.jepmkey FROM mc27_dtl d WHERE d.mc27key = :mkey AND ISNULL(d.qty, 0) <> 0 )", p);
                    }
                    int dtl = t.update("DELETE FROM mc27_dtl WHERE mc27key = :mkey", p);
                    t.update("DELETE FROM mc27_mst WHERE shopno = :shop AND mc27key = :mkey", p);

                    Map<String, Object> r = new LinkedHashMap<String, Object>();
                    r.put("dtl", dtl);              // 지운 상세 건수
                    r.put("restored", restored);    // 재고를 되돌린 제품 수
                    return r;
                }
            }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // MC27 저장 (마감 · 초기화 공용)
    //   CJPNO = yyyyMMddHHmmss, MC27KEY = SHOPNO + CJPNO, CGUBUN '실사', PRDATE = yyyyMMdd
    //   QTY : + 재고 감소, − 재고 증가 (삭제하면 QTY 만큼 재고에 더해서 되돌림)
    //   AMT = Σ(입고가 × QTY), 상세 SEQ 1 부터
    // ------------------------------------------------------------------
    private Map<String, Object> writeMc27(NamedParameterJdbcTemplate t, String shop, String remk, List<Map<String, Object>> lines) {
        Date now = new Date();
        String cjpno   = new SimpleDateFormat("yyyyMMddHHmmss").format(now);
        String prdate  = new SimpleDateFormat("yyyyMMdd").format(now);
        String mc27key = shop + cjpno;
        String chdate  = prdate;          // 처리일 yyyyMMdd (ar309 처럼 CHDATE 를 yyyyMMdd 로 비교)

        long amt = 0, qtySum = 0; int diffs = 0;
        for (Map<String, Object> m : lines) {
            long d = (Long) m.get("qty");
            amt += d * (Long) m.get("inprice");
            qtySum += d;
            if (d != 0) diffs++;
        }

        MapSqlParameterSource mp = new MapSqlParameterSource()
            .addValue("chdate", chdate, Types.VARCHAR)
            .addValue("cjpno", cjpno)
            .addValue("remk", remk)
            .addValue("prdate", prdate, Types.VARCHAR)
            .addValue("amt", Long.valueOf(amt), Types.NUMERIC)
            .addValue("shop", shop)
            .addValue("mkey", mc27key);
        Integer dup = t.queryForObject("SELECT COUNT(*) FROM mc27_mst WHERE mc27key = :mkey", mp, Integer.class);
        if (dup != null && dup > 0) throw new IllegalStateException("같은 시각에 만든 전표가 있습니다. 잠시 후 다시 하세요.");

        t.update(
            "INSERT INTO mc27_mst (chdate, cjpno, cgubun, remk, prdate, amt, shopno, mc27key)" +
            " VALUES (:chdate, :cjpno, '실사', :remk, :prdate, :amt, :shop, :mkey)", mp);

        int seq = 0;
        for (Map<String, Object> m : lines) {
            t.update(
                "INSERT INTO mc27_dtl (chdate, cjpno, seq, jepmcd, qty, inprice, jepmnm, shopno, mc27key, jepmkey)" +
                " VALUES (:chdate, :cjpno, :seq, :code, :qty, :inprice, :name, :shop, :mkey, :key)",
                new MapSqlParameterSource()
                    .addValue("chdate", chdate, Types.VARCHAR)
                    .addValue("cjpno", cjpno)
                    .addValue("seq", Integer.valueOf(++seq), Types.INTEGER)
                    .addValue("code", m.get("jepmcd"))
                    .addValue("qty", m.get("qty"), Types.NUMERIC)
                    .addValue("inprice", m.get("inprice"), Types.NUMERIC)
                    .addValue("name", m.get("jepmnm"))
                    .addValue("shop", shop)
                    .addValue("mkey", mc27key)
                    .addValue("key", m.get("jepmkey")));
        }

        Map<String, Object> r = new LinkedHashMap<String, Object>();
        r.put("mc27key", mc27key);
        r.put("cjpno",   cjpno);
        r.put("items",   lines.size());     // 제품 수
        r.put("lines",   lines.size());     // MC27_DTL 건수
        r.put("diffs",   diffs);            // 차이 있는 제품 수
        r.put("qty",     qtySum);           // MC27 수량 합계 (+ 감소)
        r.put("amt",     amt);
        return r;
    }

    private static Map<String, Object> line(ResultSet rs) throws SQLException {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("jepmkey", trim(rs.getString("jepmkey")));
        m.put("jepmcd",  trim(rs.getString("jepmcd")));
        m.put("jepmnm",  trim(rs.getString("jepmnm")));
        m.put("inprice", rs.getLong("INPRICE"));
        return m;
    }

    // ------------------------------------------------------------------
    // 트랜잭션 — jConnect 는 setAutoCommit(false) 에서 JZ0SJ 오류가 나므로
    //   연결 하나를 잡고 BEGIN TRANSACTION / COMMIT / ROLLBACK 을 SQL 로 직접 실행
    // ------------------------------------------------------------------
    private interface Work { Map<String, Object> run(NamedParameterJdbcTemplate t); }

    private Map<String, Object> inTx(final Work work) {
        return ((JdbcTemplate) jdbc.getJdbcOperations()).execute(new ConnectionCallback<Map<String, Object>>() {
            public Map<String, Object> doInConnection(Connection con) throws SQLException {
                JdbcTemplate one = new JdbcTemplate(new SingleConnectionDataSource(con, true));
                one.setExceptionTranslator(new SQLStateSQLExceptionTranslator());
                NamedParameterJdbcTemplate t = new NamedParameterJdbcTemplate(one);
                one.execute("BEGIN TRANSACTION");
                try {
                    Map<String, Object> res = work.run(t);
                    one.execute("COMMIT");
                    return res;
                } catch (RuntimeException e) {
                    try { one.execute("ROLLBACK"); } catch (Exception ignore) { logger.error("ai601 rollback error", ignore); }
                    throw e;
                }
            }
        });
    }

    // ------------------------------------------------------------------
    // 공통
    // ------------------------------------------------------------------
    private Map<String, Object> findProduct(String shop, String key) {
        List<Map<String, Object>> l = jdbc.query(PRODUCT_SQL + " WHERE j.shopno = :shop AND j.jepmkey = :key",
            new MapSqlParameterSource().addValue("shop", shop).addValue("key", key), PRODUCT_ROW);
        return l.isEmpty() ? null : l.get(0);
    }

    /** max 건까지만 읽고 끊음 (setMaxRows 대신) */
    private static ResultSetExtractor<List<Map<String, Object>>> limit(final RowMapper<Map<String, Object>> row, final int max) {
        return new ResultSetExtractor<List<Map<String, Object>>>() {
            public List<Map<String, Object>> extractData(ResultSet rs) throws SQLException {
                List<Map<String, Object>> list = new ArrayList<Map<String, Object>>();
                int i = 0;
                while (list.size() < max && rs.next()) list.add(row.mapRow(rs, i++));
                return list;
            }
        };
    }

    private static Map<String, Object> rows(List<Map<String, Object>> list, boolean more) {
        Map<String, Object> r = new LinkedHashMap<String, Object>();
        r.put("rows", list);
        r.put("more", more);
        return r;
    }

    private static void like(StringBuilder sql, MapSqlParameterSource p, String col, String name, String v) {
        if (isEmpty(v)) return;
        sql.append(" AND ").append(col).append(" LIKE :").append(name);
        p.addValue(name, "%" + v.trim() + "%");
    }

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
        logger.error("ai601 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static boolean isEmpty(String s) { return s == null || s.trim().isEmpty(); }
    private static String trim(String s) { return s == null ? "" : s.trim(); }
    private static String str(Object o)   { return o == null ? "" : o.toString().trim(); }
}
