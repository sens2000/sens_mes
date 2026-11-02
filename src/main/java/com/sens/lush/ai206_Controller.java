package com.sens.lush;
import com.sens.lush.util.*;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.annotation.Resource;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.sql.DataSource;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sens.lush.service.ai206_Service;

/**
 * 피부예약 (ai206)
 *  - 화면 : /ai206.do  → /WEB-INF/ai206.jsp
 *  - 데이터 : /ai206/init, /ai206/day, /ai206/list, /ai206/members, /ai206/save, /ai206/undo, /ai206/delete, /ai206/alimtalk
 *  - 테이블 : skin_mst(예약), skin_menu(시술메뉴), member(회원)
 *  - 응답 : { ok:true, data:... }  /  { ok:false, msg:"..." }
 *
 * skin_mst 컬럼 용도
 *  skinkey  = shopno + cjpno          chdate   = 예약일(yyyymmdd)
 *  cjpno    = 등록일시(yyyymmddhhnnss)  plantime = 예약시간(hhmm)
 *  memno    = 회원번호                  durmin   = 소요시간(분)
 *  gubun    = '예약' / '관리'           skiner   = 관리사
 *  memo     = 예약 메모                 remk     = 관리내용
 *  skintime = 관리시간(hhmm)            prdate/prtime/pruser = 등록일·시간·등록자
 *  moddate  = 수정일시(yyyymmddhhnnss)  managechk = 사용안함
 */
@Controller
public class ai206_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    /** 로그인 시 세션 "USER" HashMap 에 들어있는 매장코드 / 사용자ID 키 이름 — 실제 키로 맞추세요 */
    private static final String SESSION_USER    = "USER";
    private static final String USER_SHOP_FIELD = "SHOPNO";
    private static final String USER_ID_FIELD   = "USERID";

    private static final String OPEN_TIME  = "10:00";
    private static final String CLOSE_TIME = "21:00";

    private static final String GUBUN_RESV = "예약";
    private static final String GUBUN_DONE = "관리";

    private final NamedParameterJdbcTemplate jdbc;

    @Resource(name = "ai206_Service")
    private ai206_Service Service;

    @Autowired
    public ai206_Controller(DataSource dataSource) {
        this.jdbc = new NamedParameterJdbcTemplate(dataSource);
    }

    // ------------------------------------------------------------------
    // 화면
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206.do")
    public String ai206(HttpServletRequest request, Model model) throws Exception {
        String sPage = "ai206";
        logger.info("Start Page: " + sPage);
        return sPage;
    }

    // ------------------------------------------------------------------
    // 시술메뉴
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/init", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> init(HttpSession session) {
        try {
            List<Map<String, Object>> menus = jdbc.query(
                "SELECT menu_id, jepmcd, menu_nm, dur_min, price " +
                "  FROM skin_menu WHERE shopno = :shop AND use_yn = 'Y' ORDER BY sort_no, menu_id",
                new MapSqlParameterSource("shop", shopNo(session)),
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("menuId", rs.getInt("menu_id"));
                        m.put("jepmcd", trim(rs.getString("jepmcd")));
                        m.put("menuNm", trim(rs.getString("menu_nm")));
                        m.put("durMin", rs.getInt("dur_min"));
                        m.put("price",  rs.getLong("price"));
                        return m;
                    }
                });
            Map<String, Object> data = new HashMap<String, Object>();
            data.put("menus", menus);
            data.put("openTime", OPEN_TIME);
            data.put("closeTime", CLOSE_TIME);
            return ok(data);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 하루 예약표
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/day", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> day(@RequestParam("date") String date, HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("date", ymd(date));
            return ok(jdbc.query(SELECT_RSV +
                " WHERE s.shopno = :shop AND s.chdate = :date ORDER BY s.plantime", p, RSV_MAPPER));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 예약 목록 (기간 / 구분 / 회원명·연락처)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/list", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> list(@RequestParam("from") String from,
                                    @RequestParam("to") String to,
                                    @RequestParam(value = "gubun", required = false) String gubun,
                                    @RequestParam(value = "keyword", required = false) String keyword,
                                    HttpSession session) {
        try {
            StringBuilder sql = new StringBuilder(SELECT_RSV)
                .append(" WHERE s.shopno = :shop AND s.chdate BETWEEN :from AND :to");
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("from", ymd(from))
                .addValue("to", ymd(to));
            if (!isEmpty(gubun)) {
                sql.append(" AND s.gubun = :gubun");
                p.addValue("gubun", gubun);
            }
            if (!isEmpty(keyword)) {
                sql.append(" AND (m.name LIKE :kw OR REPLACE(m.handno,'-','') LIKE :kw)");
                p.addValue("kw", "%" + keyword.replace("-", "").trim() + "%");
            }
            sql.append(" ORDER BY s.chdate, s.plantime");
            return ok(jdbc.query(sql.toString(), p, RSV_MAPPER));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 회원 검색 (회원만 예약 가능)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/members", method = RequestMethod.GET)
    @ResponseBody
    public Map<String, Object> members(@RequestParam("keyword") String keyword, HttpSession session) {
        try {
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("kw", "%" + keyword.replace("-", "").trim() + "%");
            return ok(jdbc.query(
                "SELECT TOP 20 memno, name, handno FROM member " +
                " WHERE shopno = :shop AND (name LIKE :kw OR REPLACE(handno,'-','') LIKE :kw) " +
                " ORDER BY name", p,
                new RowMapper<Map<String, Object>>() {
                    public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
                        Map<String, Object> m = new LinkedHashMap<String, Object>();
                        m.put("memNo",   trim(rs.getString("memno")));
                        m.put("custNm",  trim(rs.getString("name")));
                        m.put("custTel", trim(rs.getString("handno")));
                        return m;
                    }
                }));
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 저장 (신규/수정)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/save", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> save(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String shop      = shopNo(session);
            String skinKey   = str(req.get("skinKey"));
            String rsvDate   = str(req.get("rsvDate"));       // yyyy-mm-dd
            String startTime = str(req.get("startTime"));     // HH:mm
            int    durMin    = toInt(req.get("durMin"));
            String memNo     = str(req.get("memNo"));
            String gubun     = GUBUN_DONE.equals(str(req.get("gubun"))) ? GUBUN_DONE : GUBUN_RESV;
            String memo      = str(req.get("memo"));
            String remk      = str(req.get("remk"));
            String skinTime  = str(req.get("skinTime"));

            // --- 검증
            if (isEmpty(memNo))                        return fail("회원을 검색해서 선택하세요.");
            if (isEmpty(rsvDate) || isEmpty(startTime)) return fail("예약일과 예약시간을 입력하세요.");
            if (durMin <= 0)                           return fail("소요시간을 선택하세요.");
            String endTime = hm(toMin(startTime) + durMin);
            if (startTime.compareTo(OPEN_TIME) < 0 || endTime.compareTo(CLOSE_TIME) > 0)
                return fail("영업시간(" + OPEN_TIME + "~" + CLOSE_TIME + ") 안에서 예약하세요.");
            if (bytes(memo) > 60) return fail("메모는 한글 30자(60바이트)까지 입력할 수 있어요.");
            if (bytes(remk) > 60) return fail("관리내용은 한글 30자(60바이트)까지 입력할 수 있어요.");

            String now = new SimpleDateFormat("yyyyMMddHHmmss").format(new Date());
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shop)
                .addValue("chdate", ymd(rsvDate))
                .addValue("plantime", startTime.replace(":", ""))
                .addValue("durmin", durMin)
                .addValue("memno", memNo)
                .addValue("menuId", toInt(req.get("menuId")))
                .addValue("jepmcd", str(req.get("jepmcd")))
                .addValue("jepmnm", str(req.get("menuNm")))
                .addValue("saleprice", toLong(req.get("price")))
                .addValue("skiner", str(req.get("skiner")))
                .addValue("gubun", gubun)
                .addValue("memo", memo)
                .addValue("remk", remk)
                .addValue("skintime", GUBUN_DONE.equals(gubun) ? skinTime.replace(":", "") : "")
                .addValue("moddate", now);

            if (isEmpty(skinKey)) {
                // skinkey = shopno + cjpno(yyyymmddhhnnss), 같은 초에 겹치면 1초씩 밀어서 생성
                SimpleDateFormat f = new SimpleDateFormat("yyyyMMddHHmmss");
                String cjpno = now;
                skinKey = shop.trim() + cjpno;
                for (int i = 0; i < 5 && exists(skinKey); i++) {
                    cjpno = f.format(new Date(f.parse(cjpno).getTime() + 1000));
                    skinKey = shop.trim() + cjpno;
                }
                p.addValue("skinkey", skinKey)
                 .addValue("cjpno", cjpno)
                 .addValue("prdate", now.substring(0, 8))
                 .addValue("prtime", now.substring(8, 12))
                 .addValue("pruser", userId(session));
                jdbc.update(
                    "INSERT INTO skin_mst (skinkey, shopno, chdate, cjpno, memno, remk, prdate, prtime, pruser," +
                    "                      gubun, skiner, skintime, plantime, memo, jepmcd, jepmnm, saleprice," +
                    "                      durmin, menu_id, moddate, alim_yn, alim_dt) " +
                    "VALUES (:skinkey, :shop, :chdate, :cjpno, :memno, :remk, :prdate, :prtime, :pruser," +
                    "        :gubun, :skiner, :skintime, :plantime, :memo, :jepmcd, :jepmnm, :saleprice," +
                    "        :durmin, :menuId, :moddate, 'N', '')", p);
            } else {
                p.addValue("skinkey", skinKey);
                int cnt = jdbc.update(
                    "UPDATE skin_mst SET chdate = :chdate, plantime = :plantime, durmin = :durmin, memno = :memno," +
                    "       menu_id = :menuId, jepmcd = :jepmcd, jepmnm = :jepmnm, saleprice = :saleprice," +
                    "       skiner = :skiner, gubun = :gubun, memo = :memo, remk = :remk, skintime = :skintime," +
                    "       moddate = :moddate " +
                    " WHERE skinkey = :skinkey AND shopno = :shop", p);
                if (cnt == 0) return fail("예약을 찾을 수 없어요.");
            }

            Map<String, Object> data = new HashMap<String, Object>();
            data.put("skinKey", skinKey);
            return ok(data);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 관리완료 → 예약으로 되돌리기 (관리시간만 지우고 관리내용은 유지)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/undo", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> undo(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            int cnt = jdbc.update(
                "UPDATE skin_mst SET gubun = :gubun, skintime = '', moddate = :moddate " +
                " WHERE skinkey = :skinkey AND shopno = :shop",
                new MapSqlParameterSource()
                    .addValue("gubun", GUBUN_RESV)
                    .addValue("moddate", new SimpleDateFormat("yyyyMMddHHmmss").format(new Date()))
                    .addValue("skinkey", str(req.get("skinKey")))
                    .addValue("shop", shopNo(session)));
            if (cnt == 0) return fail("예약을 찾을 수 없어요.");
            return ok(null);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 삭제 (예약 취소)
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/delete", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> delete(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            jdbc.update("DELETE FROM skin_mst WHERE skinkey = :skinkey AND shopno = :shop",
                new MapSqlParameterSource()
                    .addValue("skinkey", str(req.get("skinKey")))
                    .addValue("shop", shopNo(session)));
            return ok(null);
        } catch (Exception e) {
            return fail(e);
        }
    }

    // ------------------------------------------------------------------
    // 알림톡 발송
    //   type = CONFIRM : keys 로 넘어온 예약에 예약확정 알림톡
    //   type = REMIND  : date(보통 내일) '예약' 건 전체에 방문 안내 알림톡
    // ------------------------------------------------------------------
    @RequestMapping(value = "/ai206/alimtalk", method = RequestMethod.POST)
    @ResponseBody
    public Map<String, Object> alimtalk(@RequestBody Map<String, Object> req, HttpSession session) {
        try {
            String type = str(req.get("type"));
            MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("shop", shopNo(session))
                .addValue("gubun", GUBUN_RESV);
            List<Map<String, Object>> targets;

            if ("REMIND".equals(type)) {
                p.addValue("date", ymd(str(req.get("date"))));
                targets = jdbc.query(SELECT_RSV +
                    " WHERE s.shopno = :shop AND s.chdate = :date AND s.gubun = :gubun", p, RSV_MAPPER);
            } else {
                List<String> keys = new ArrayList<String>();
                Object raw = req.get("keys");
                if (raw instanceof List) for (Object o : (List<?>) raw) keys.add(str(o));
                if (keys.isEmpty()) return fail("발송할 예약을 선택하세요.");
                p.addValue("keys", keys);
                targets = jdbc.query(SELECT_RSV +
                    " WHERE s.shopno = :shop AND s.skinkey IN (:keys) AND s.gubun = :gubun", p, RSV_MAPPER);
            }

            int sent = 0;
            String now = new SimpleDateFormat("yyyyMMddHHmmss").format(new Date());
            for (Map<String, Object> r : targets) {
                if (isEmpty(str(r.get("custTel")))) continue;
                String msg = buildMessage(type, r);
                logger.info("ai206 alimtalk: " + r.get("custTel") + " / " + msg);

                // TODO: 알림톡 발송 대행 모듈 호출 (매장 채널 발신프로필키 + 템플릿코드)
                //       alimtalkService.send(shop, str(r.get("custTel")), templateCode(type), msg);

                jdbc.update("UPDATE skin_mst SET alim_yn = 'Y', alim_dt = :now WHERE skinkey = :skinkey",
                    new MapSqlParameterSource().addValue("now", now).addValue("skinkey", r.get("skinKey")));
                sent++;
            }

            Map<String, Object> data = new HashMap<String, Object>();
            data.put("sent", sent);
            return ok(data);
        } catch (Exception e) {
            return fail(e);
        }
    }

    /** 알림톡 본문 — 카카오에 등록한 템플릿 문구와 똑같이 맞춰야 발송됩니다 */
    private String buildMessage(String type, Map<String, Object> r) {
        String head = "REMIND".equals(type) ? "[방문 안내]" : "[예약 확정]";
        return head + "\r\n"
             + str(r.get("custNm")) + " 고객님, 피부관리 예약 안내드립니다.\r\n\r\n"
             + "■ 일시 : " + str(r.get("rsvDate")) + " " + str(r.get("startTime")) + "\r\n"
             + "■ 시술 : " + str(r.get("menuNm")) + "\r\n\r\n"
             + "변경·취소는 매장으로 연락 부탁드립니다.";
    }

    // ------------------------------------------------------------------
    // 기존 저장 방식 (ai206_Service 사용) — 그대로 유지
    // ------------------------------------------------------------------
    @SuppressWarnings({ "unchecked", "rawtypes" })
    @RequestMapping(value = "/ai206save.do")
    public @ResponseBody String dataSave(HttpServletRequest request, HttpServletResponse res) throws Exception {
        String sList = request.getParameter("list");
        logger.info("ai206save.list: " + sList);

        Map<String, Object> mapSos = new ObjectMapper().readValue(sList, HashMap.class);
        HashMap MapUser = (HashMap) request.getSession().getAttribute(SESSION_USER);
        List<Map> paramList = (List<Map>) mapSos.get("updateList");
        logger.info("ai206save.MapUser: " + MapUser);
        logger.info("ai206save.updateList: " + paramList);

        String sRet = Service.dataSave(paramList, MapUser);
        return "{\"result\": \"success\"}";
    }

    // ------------------------------------------------------------------
    // 조회 공통
    // ------------------------------------------------------------------
    private static final String SELECT_RSV =
        "SELECT s.skinkey, s.chdate, s.plantime, s.durmin, s.memno, m.name, m.handno," +
        "       s.menu_id, s.jepmcd, s.jepmnm, s.saleprice, s.skiner, s.gubun, s.memo, s.remk," +
        "       s.skintime, s.alim_yn, s.alim_dt" +
        "  FROM skin_mst s" +
        "  LEFT OUTER JOIN member m ON m.memno = s.memno";

    /** DB 값(yyyymmdd, hhmm, char 공백) → 화면용(yyyy-mm-dd, HH:mm) */
    private static final RowMapper<Map<String, Object>> RSV_MAPPER = new RowMapper<Map<String, Object>>() {
        public Map<String, Object> mapRow(ResultSet rs, int i) throws SQLException {
            String plan = hmFmt(trim(rs.getString("plantime")));
            int dur = rs.getInt("durmin");
            if (dur <= 0) dur = 60;
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("skinKey",   trim(rs.getString("skinkey")));
            m.put("rsvDate",   dateFmt(trim(rs.getString("chdate"))));
            m.put("startTime", plan);
            m.put("endTime",   plan.length() == 5 ? hm(toMin(plan) + dur) : "");
            m.put("durMin",    dur);
            m.put("memNo",     trim(rs.getString("memno")));
            m.put("custNm",    trim(rs.getString("name")));
            m.put("custTel",   trim(rs.getString("handno")));
            m.put("menuId",    rs.getInt("menu_id"));
            m.put("jepmcd",    trim(rs.getString("jepmcd")));
            m.put("menuNm",    trim(rs.getString("jepmnm")));
            m.put("price",     rs.getLong("saleprice"));
            m.put("skiner",    trim(rs.getString("skiner")));
            m.put("gubun",     trim(rs.getString("gubun")));
            m.put("memo",      trim(rs.getString("memo")));
            m.put("remk",      trim(rs.getString("remk")));
            m.put("skinTime",  hmFmt(trim(rs.getString("skintime"))));
            m.put("alimYn",    trim(rs.getString("alim_yn")));
            String ad = trim(rs.getString("alim_dt"));
            m.put("alimDt",    ad.length() >= 12 ? dateFmt(ad.substring(0, 8)) + " " + hmFmt(ad.substring(8, 12)) : "");
            return m;
        }
    };

    private boolean exists(String skinKey) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM skin_mst WHERE skinkey = :k",
            new MapSqlParameterSource("k", skinKey), Integer.class);
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

    private String shopNo(HttpSession session) {
        Object v = userMap(session).get(USER_SHOP_FIELD);
        if (v == null || v.toString().trim().isEmpty())
            throw new IllegalStateException("로그인 정보(매장코드)가 없습니다. 세션 USER 의 " + USER_SHOP_FIELD + " 키를 확인하세요.");
        return v.toString().trim();
    }

    private String userId(HttpSession session) {
        Object v = userMap(session).get(USER_ID_FIELD);
        String s = v == null ? "" : v.toString().trim();
        return s.length() > 12 ? s.substring(0, 12) : s;
    }

    // ------------------------------------------------------------------
    // 응답 / 변환 공통
    // ------------------------------------------------------------------
    private Map<String, Object> ok(Object data) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", true);
        m.put("data", data);
        return m;
    }

    private Map<String, Object> fail(String msg) {
        Map<String, Object> m = new LinkedHashMap<String, Object>();
        m.put("ok", false);
        m.put("msg", msg);
        return m;
    }

    private Map<String, Object> fail(Exception e) {
        logger.error("ai206 error", e);
        return fail(e.getMessage() == null ? "처리 중 오류가 발생했습니다." : e.getMessage());
    }

    private static String trim(String s)        { return s == null ? "" : s.trim(); }
    private static String str(Object o)         { return o == null ? "" : o.toString().trim(); }
    private static boolean isEmpty(String s)    { return s == null || s.trim().isEmpty(); }
    private static String ymd(String d)         { return d == null ? "" : d.replace("-", ""); }
    private static String dateFmt(String ymd)   { return ymd.length() == 8 ? ymd.substring(0, 4) + "-" + ymd.substring(4, 6) + "-" + ymd.substring(6) : ymd; }
    private static String hmFmt(String hhmm)    { return hhmm.length() == 4 ? hhmm.substring(0, 2) + ":" + hhmm.substring(2) : hhmm; }
    private static int toMin(String hm)         { String[] a = hm.split(":"); return Integer.parseInt(a[0]) * 60 + Integer.parseInt(a[1]); }
    private static String hm(int min)           { return String.format("%02d:%02d", min / 60, min % 60); }

    /** DB(CP949) 기준 바이트 수 - 한글 2바이트 */
    private static int bytes(String s) {
        int n = 0;
        for (int i = 0; i < s.length(); i++) n += s.charAt(i) > 127 ? 2 : 1;
        return n;
    }

    private static int toInt(Object o) {
        if (o == null) return 0;
        if (o instanceof Number) return ((Number) o).intValue();
        try { return Integer.parseInt(o.toString().trim()); } catch (Exception e) { return 0; }
    }

    private static long toLong(Object o) {
        if (o == null) return 0;
        if (o instanceof Number) return ((Number) o).longValue();
        try { return Long.parseLong(o.toString().trim()); } catch (Exception e) { return 0; }
    }
}
