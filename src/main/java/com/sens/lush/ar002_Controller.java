package com.sens.lush;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.text.SimpleDateFormat;
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
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.SQLStateSQLExceptionTranslator;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 직원 관리 (ar002) — USER_INFO 등록 / 수정 / 삭제
 *  - 화면 : /ar002.do → ar002.jsp
 *  - 데이터 : /ar002/init (관리자 여부·매장 목록), /ar002/list (목록), /ar002/save (등록·수정, JSON), /ar002/delete (삭제, JSON) — ai016 과 같은 방식
 *  - 대상 : USER_INFO, SHOPNO = 로그인 매장
 *  - 등록 : BUSEO = '0000', CODE = user_info 전체 MAX(CODE) + 1 (기존 자릿수 유지), PRDATE·MODDATE = 오늘,
 *           SHOPNO·SHOPNAME = 로그인 매장
 *  - 수정 : MODDATE = 오늘, 비밀번호는 입력했을 때만 바꿈
 *  - 목록에는 비밀번호를 내려보내지 않음
 *  - USERID 는 전체 매장에서 겹치지 않게 확인 (로그인 ID)
 *  - 로그인 사용자 GRADE = 99 (관리자) 이면 조회 · 등록 · 수정 · 삭제할 매장을 고를 수 있음 (/ar002/init 의 shops)
 *    목록은 '*' 로 전체 매장 조회도 가능, 수정할 때 매장 변경 가능 (옮길 매장에 같은 코드가 있으면 새 코드)
 *    그 밖에는 항상 로그인 매장
 */
@Controller
public class ar002_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 의 키 이름 */
    private static final String SESSION_USER      = "USER";
    private static final String USER_SHOP_FIELD   = "SHOPNO";
    private static final String USER_SHOPNM_FIELD = "SHOPNAME";
    private static final String USER_ID_FIELD     = "USERID";

    private static final String USER_GRADE_FIELD  = "GRADE";
    private static final int    ADMIN_GRADE       = 99;      // 매장을 고를 수 있는 등급
    private static final String ALL_SHOPS         = "*";     // 관리자 : 전체 매장 조회

    /** 관리자용 매장 목록 — 매장 테이블이 다르면 여기만 바꾸세요 */
    private static final String SHOP_SQL = "SELECT DISTINCT shopno, shopname FROM user_mst ORDER BY shopno";

    private static final String BUSEO = "0000";

    private final NamedParameterJdbcTemplate jdbc;

    @Autowired
    public ar002_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
        // jConnect 메타데이터 테이블이 없어서 생기는 JZ0SJ 경고 방지 — SQLState 방식으로 오류 해석
        // 주의 : setMaxRows 는 jConnect 가 메타데이터 테이블을 찾다가 JZ0SJ 오류가 나므로 쓰지 않음
        ((JdbcTemplate) this.jdbc.getJdbcOperations()).setExceptionTranslator(new SQLStateSQLExceptionTranslator());
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar002.do")
    public String ar002(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ar002");
        return "ar002";
    }

    // ------------------------------------------------------------------
    // 화면 처음 : 관리자 여부, 로그인 매장, (관리자면) 매장 목록
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar002/init", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> init(HttpSession session) {
        try {
            boolean admin = isAdmin(session);
            Map<String, Object> r = new LinkedHashMap<String, Object>();
            r.put("admin", admin);
            r.put("myShop", shopNo(session));
            r.put("myShopName", shopName(session));
            r.put("shops", admin ? shops() : new java.util.ArrayList<Map<String, Object>>());
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 목록 (비밀번호 제외) — shop : 관리자만 다른 매장 지정 가능
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar002/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@org.springframework.web.bind.annotation.RequestParam(value = "shop", defaultValue = "") String shopParam,
                                    HttpSession session) {
        try {
            // 관리자가 '*' 를 고르면 전체 매장
            if (ALL_SHOPS.equals(shopParam.trim())) {
                if (!isAdmin(session)) throw new IllegalArgumentException("전체 매장 조회는 관리자(등급 99)만 할 수 있습니다.");
                return ok(jdbc.query(
                    "SELECT shopno, shopname, code, name, userid, position, grade, handno, remk, chk, prdate, moddate" +
                    "  FROM user_info" + LIST_ORDER,
                    new MapSqlParameterSource(), ROW));
            }
            return ok(jdbc.query(LIST_SQL + LIST_ORDER,
                                 new MapSqlParameterSource("shop", targetShop(session, shopParam)), ROW));
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 목록 순서 : 매장번호 → 직위(메니져 · 일반 · 알바 · 그 밖) → 등급(높은 순) → 성명 */
    private static final String LIST_ORDER =
        " ORDER BY shopno," +
        "          CASE ISNULL(position, '') WHEN '메니져' THEN 1 WHEN '일반' THEN 2 WHEN '알바' THEN 3 ELSE 4 END," +
        "          ISNULL(grade, 0) DESC, name";

    /** 목록·저장 후 돌려줄 한 줄 (비밀번호 제외) */
    private static final String LIST_SQL =
        "SELECT shopno, shopname, code, name, userid, position, grade, handno, remk, chk, prdate, moddate" +
        "  FROM user_info WHERE shopno = :shop";

    private static final RowMapper<Map<String, Object>> ROW = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("shopno",   trim(rs.getString("shopno")));
            m.put("shopname", trim(rs.getString("shopname")));
            m.put("code",     trim(rs.getString("code")));
            m.put("name",     trim(rs.getString("name")));
            m.put("userid",   trim(rs.getString("userid")));
            m.put("position", trim(rs.getString("position")));
            m.put("grade",    trim(rs.getString("grade")));
            m.put("handno",   trim(rs.getString("handno")));
            m.put("remk",     trim(rs.getString("remk")));
            String chk = trim(rs.getString("chk"));
            m.put("chk",      chk.isEmpty() ? "Y" : chk);
            m.put("prdate",   trim(rs.getString("prdate")));
            m.put("moddate",  trim(rs.getString("moddate")));
            return m;
        }
    };

    // ------------------------------------------------------------------
    // 등록 · 수정 (code 가 비어 있으면 등록)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar002/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            String code     = str(body.get("code"));
            String name     = str(body.get("name"));
            String userid   = str(body.get("userid"));
            String userpass = body.get("userpass") == null ? "" : body.get("userpass").toString();   // 비밀번호는 앞뒤 공백도 그대로
            String position = str(body.get("position"));
            String grade    = str(body.get("grade"));
            String handno   = str(body.get("handno"));
            String remk     = str(body.get("remk"));
            String chk      = str(body.get("chk"));
            String shop = targetShop(session, str(body.get("shop")));     // 관리자만 다른 매장
            name = name.trim(); userid = userid.trim(); code = code.trim();
            // 필수는 성명뿐 (ID·비밀번호는 로그인할 직원만 넣음)
            if (name.isEmpty()) throw new IllegalArgumentException("성명을 입력하세요.");
            if (!grade.trim().isEmpty() && !grade.trim().matches("\\d{1,4}")) throw new IllegalArgumentException("등급은 숫자로 입력하세요.");
            boolean isNew = code.isEmpty();
            // 새로 등록하면서 ID 를 넣었으면 비밀번호도 있어야 로그인 가능
            if (isNew && !userid.isEmpty() && userpass.isEmpty()) throw new IllegalArgumentException("ID 를 넣었으면 비밀번호도 입력하세요.");

            // ID 중복 확인 (ID 를 넣었을 때만, 전체 매장, 자기 자신 제외)
            if (!userid.isEmpty()) {
                MapSqlParameterSource dp = new MapSqlParameterSource()
                    .addValue("id", userid).addValue("shop", shop).addValue("code", code);
                Integer dup = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM user_info WHERE userid = :id" +
                    "   AND NOT (shopno = :shop AND code = :code)", dp, Integer.class);
                if (dup != null && dup > 0) throw new IllegalArgumentException("이미 사용 중인 ID 입니다 : " + userid);
            }

            String today = new SimpleDateFormat("yyyyMMdd").format(new Date());
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shop)
                .addValue("name", name)
                .addValue("userid", userid)
                .addValue("userpass", userpass)
                .addValue("position", position.trim().isEmpty() ? "일반" : position.trim())   // 직위 기본 일반
                // 등급 기본 0 (INTEGER 로 지정 — jConnect 는 타입 없는 값을 못 받음)
                .addValue("grade", grade.trim().isEmpty() ? Integer.valueOf(0) : Integer.valueOf(grade.trim()), Types.INTEGER)
                .addValue("handno", handno.replaceAll("[^0-9]", ""))     // 숫자만 저장
                .addValue("remk", remk.trim())
                .addValue("chk", "N".equalsIgnoreCase(chk) ? "N" : "Y")
                .addValue("today", today);

            if (isNew) {
                code = nextCode(shop);
                p.addValue("code", code).addValue("buseo", BUSEO)
                 .addValue("shopname", shop.equals(shopNo(session)) ? shopName(session) : shopNameOf(shop));
                jdbc.update(
                    "INSERT INTO user_info (buseo, code, name, remk, prdate, moddate, handno, position, grade," +
                    "                       userid, userpass, shopno, shopname, chk)" +
                    " VALUES (:buseo, :code, :name, :remk, :today, :today, :handno, :position, :grade," +
                    "         :userid, :userpass, :shop, :shopname, :chk)", p);
            } else {
                p.addValue("code", code);
                // 관리자(등급 99)는 수정할 때 매장을 옮길 수 있음 (new_shop)
                String newShop = str(body.get("new_shop"));
                boolean move = !newShop.isEmpty() && !newShop.equals(shop);
                String newCode = code;
                if (move) {
                    if (!isAdmin(session)) throw new IllegalArgumentException("매장 변경은 관리자(등급 99)만 할 수 있습니다.");
                    newShop = targetShop(session, newShop);               // 있는 매장인지 확인
                    // 코드가 다른 직원과 겹치면 (기본키 중복) 새 번호로
                    Integer used = jdbc.queryForObject(
                        "SELECT COUNT(*) FROM user_info WHERE code = :code AND NOT (shopno = :shop AND code = :code)",
                        new MapSqlParameterSource().addValue("shop", shop).addValue("code", code), Integer.class);
                    if (used != null && used > 0) newCode = nextCode(newShop);
                    p.addValue("ns", newShop).addValue("nsname", shopNameOf(newShop)).addValue("ncode", newCode);
                }
                int n = jdbc.update(
                    "UPDATE user_info" +
                    "   SET name = :name, remk = :remk, moddate = :today, handno = :handno," +
                    "       position = :position, grade = :grade, userid = :userid, chk = :chk" +
                    (userpass.isEmpty() ? "" : ", userpass = :userpass") +        // 비밀번호는 입력했을 때만
                    (move ? ", shopno = :ns, shopname = :nsname, code = :ncode" : "") +   // 매장 변경
                    " WHERE shopno = :shop AND code = :code", p);
                if (n == 0) throw new IllegalArgumentException("수정할 직원을 찾을 수 없습니다. 다시 조회하세요.");
                if (move) { shop = newShop; code = newCode; }
            }
            // 저장된 한 줄을 돌려줌 (화면에서 바로 다시 표시)
            List<Map<String, Object>> saved = jdbc.query(LIST_SQL + " AND code = :code",
                new MapSqlParameterSource().addValue("shop", shop).addValue("code", code), ROW);
            Map<String, Object> r = saved.isEmpty() ? new LinkedHashMap<String, Object>() : saved.get(0);
            r.put("isNew", isNew);
            return ok(r);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 삭제
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ar002/delete", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> delete(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            String code = str(body.get("code"));
            if (code.isEmpty()) throw new IllegalArgumentException("삭제할 직원을 선택하세요.");
            String shop = targetShop(session, str(body.get("shop")));     // 관리자만 다른 매장
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("shop", shop).addValue("code", code.trim());
            // 지금 로그인한 본인은 삭제할 수 없음
            String me = myUserId(session);
            if (!me.isEmpty()) {
                List<String> ids = jdbc.query("SELECT userid FROM user_info WHERE shopno = :shop AND code = :code", p,
                    new RowMapper<String>() {
                        public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
                    });
                if (!ids.isEmpty() && me.equalsIgnoreCase(ids.get(0)))
                    throw new IllegalArgumentException("지금 로그인한 본인 계정은 삭제할 수 없습니다.");
            }
            int n = jdbc.update("DELETE FROM user_info WHERE shopno = :shop AND code = :code", p);
            if (n == 0) throw new IllegalArgumentException("삭제할 직원을 찾을 수 없습니다. 다시 조회하세요.");
            return ok(n);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /**
     * 다음 직원 코드 = user_info 전체 MAX(CODE) + 1 — 숫자 코드만 보고, 기존 자릿수(앞자리 0)를 유지 (없으면 4자리)
     * user_info 기본키에 SHOPNO 가 없어서 (다른 매장과 코드가 겹치면 ASA -193) 매장 구분 없이 전체에서 번호를 매김
     */
    private String nextCode(String shop) {
        List<String> codes = jdbc.query("SELECT code FROM user_info",
            new MapSqlParameterSource(),
            new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
            });
        long max = 0; int width = 4;
        for (String c : codes) {
            if (!c.matches("\\d+")) continue;
            long v = Long.parseLong(c);
            if (v >= max) { max = v; width = Math.max(width, c.length()); }
        }
        String next = String.valueOf(max + 1);
        while (next.length() < width) next = "0" + next;
        return next;
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

    private String shopName(HttpSession session) {
        Object v = user(session).get(USER_SHOPNM_FIELD);
        return v == null ? "" : v.toString().trim();
    }

    /** 로그인 사용자 등급이 99 (관리자) 인지 */
    private boolean isAdmin(HttpSession session) {
        Object v = user(session).get(USER_GRADE_FIELD);
        if (v == null) return false;
        try { return Integer.parseInt(v.toString().trim()) == ADMIN_GRADE; } catch (NumberFormatException e) { return false; }
    }

    /** 처리할 매장 : 관리자가 매장을 지정했으면 그 매장 (있는 매장인지 확인), 아니면 로그인 매장 */
    private String targetShop(HttpSession session, String req) {
        String my = shopNo(session);
        if (req == null || req.trim().isEmpty() || req.trim().equals(my)) return my;
        if (!isAdmin(session)) throw new IllegalArgumentException("다른 매장 직원은 관리자(등급 99)만 볼 수 있습니다.");
        String shop = req.trim();
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM user_mst WHERE shopno = :shop",
            new MapSqlParameterSource("shop", shop), Integer.class);
        if (n == null || n == 0) throw new IllegalArgumentException("없는 매장입니다 : " + shop);
        return shop;
    }

    private List<Map<String, Object>> shops() {
        return jdbc.query(SHOP_SQL, new MapSqlParameterSource(), new RowMapper<Map<String, Object>>() {
            public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                Map<String, Object> m = new LinkedHashMap<String, Object>();
                m.put("shopno",   trim(rs.getString("shopno")));
                m.put("shopname", trim(rs.getString("shopname")));
                return m;
            }
        });
    }

    private String shopNameOf(String shop) {
        List<String> l = jdbc.query("SELECT shopname FROM user_mst WHERE shopno = :shop",
            new MapSqlParameterSource("shop", shop), new RowMapper<String>() {
                public String mapRow(ResultSet rs, int i) throws SQLException { return trim(rs.getString(1)); }
            });
        return l.isEmpty() ? "" : l.get(0);
    }

    private String myUserId(HttpSession session) {
        Object v = user(session).get(USER_ID_FIELD);
        return v == null ? "" : v.toString().trim();
    }

    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ar002 error", e);
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String msg = root instanceof SQLException ? "DB 오류 : " + root.getMessage() : e.getMessage();
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg == null ? "처리 중 오류가 발생했습니다." : msg);
        return m;
    }

    private static String trim(String s) { return s == null ? "" : s.trim(); }
    private static String str(Object o)   { return o == null ? "" : o.toString().trim(); }
}
