<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>생산실적</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@5.5.2/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">

<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  .mes-main { min-width:0; flex:1 1 0; }
  div:has(> .mes-main) > :not(.mes-main) { flex-shrink:0; }

  .card-head { display:flex; justify-content:space-between; align-items:center; margin-bottom:.5rem; }
  .card-head h6 { font-weight:700; font-size:.6rem; margin:0; }

  /* 검색 영역 */
  .search-box { background:#fff; border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,.08); padding:.6rem .8rem; margin-bottom:.6rem; }
  .search-box .form-control, .search-box .form-select { font-size:.85rem; padding-top:.2rem; padding-bottom:.2rem; }
  .search-box .lbl { font-size:.82rem; color:#495057; white-space:nowrap; font-weight:600; }
  .search-box .w-date { width:135px; }
  .search-box .w-sel  { width:105px; }
  .search-box .w-mid  { width:130px; }
  .search-box .w-long { width:200px; }
  .search-box .form-check-label { font-size:.85rem; }
  .dday-red  { color:#dc2626; font-weight:700; }
  .cell-time { background:#e6f4ea; }
  .cell-ptime { background:#dbeafe; }
  #flowBox .form-check-input { margin-right:2px; }

  /* 표 */
  #grid { background:#fff; border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,.08); font-size:.82rem; }
  .tabulator .tabulator-header .tabulator-col { background:#e8eef8; color:#2f3e5c; }
  .tabulator .tabulator-header .tabulator-col-title { font-weight:700; text-align:center; }
  /* 열 제목 : 작은 글자 + 정렬 화살표 공간 최소화 (제목이 … 으로 잘리지 않게) */
  .tabulator .tabulator-header { font-size:.72rem; }
  .tabulator .tabulator-header .tabulator-col .tabulator-col-content { padding:4px 2px; }
  .tabulator .tabulator-header .tabulator-col.tabulator-sortable .tabulator-col-title { padding-right:9px; }
  .tabulator .tabulator-header .tabulator-col .tabulator-col-content .tabulator-col-sorter { right:1px; }
  .tabulator .tabulator-header .tabulator-col .tabulator-col-sorter .tabulator-arrow {
    border-left-width:3px; border-right-width:3px; border-bottom-width:4px; }
  .tabulator .tabulator-tableholder .tabulator-placeholder .tabulator-placeholder-contents { font-size:1rem; }
  .tabulator .tabulator-row .tabulator-cell { padding:1px 5px; line-height:1.25; }   /* 줄 간격 좁게 */
  .cell-prod { background:#ffd6e0; color:#c2185b; font-weight:700; border-radius:3px; padding:0 4px; }
  .st-wait   { color:#c2410c; font-weight:700; }
  .st-reject { color:#dc2626; font-weight:700; }
  .row-info  { font-size:.82rem; color:#6c757d; }

  /* 조회 중 표시 */
  #loading {
    position:fixed; inset:0; z-index:2000; display:none;
    align-items:center; justify-content:center;
    background:rgba(255,255,255,.55); backdrop-filter:blur(1px);
  }
  #loading.show { display:flex; }
  #loading .box {
    background:#2f3e5c; color:#fff; border-radius:16px; padding:2.2rem 3.5rem;
    box-shadow:0 10px 30px rgba(0,0,0,.25); text-align:center;
  }
  #loading .spinner-border { width:4rem; height:4rem; border-width:.45rem; color:#ffd166; }
  #loading .msg { font-size:2rem; font-weight:800; margin-top:1rem; letter-spacing:2px; }
  #loading .sub { font-size:1rem; color:#c9d3e6; margin-top:.3rem; }
</style>
</head>
<body>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-3 mes-main">
    <div class="card-head">
      <h6>생산실적</h6>
      <span class="row-info"><span id="rowInfo"></span></span>
    </div>

    <!-- ===== 검색 조건 ===== -->
    <div class="search-box">
      <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
        <span class="lbl">공정</span>
        <select id="flow" class="form-select form-select-sm w-sel" title="메뉴에서 넘어온 공정 (parm)">
          <option>인쇄</option><option>스테이너만</option><option>라미</option><option>박</option><option>실크</option>
          <option>톰슨</option><option>수작업</option><option>접착</option><option>지함</option>
        </select>
        <span class="lbl ms-2">생산라인</span>
        <select id="line" class="form-select form-select-sm w-mid"></select>
        <span class="lbl ms-2">주야</span>
        <select id="worktime" class="form-select form-select-sm" style="width:80px">
          <option>전체</option><option>주</option><option>야</option>
        </select>

        <span class="lbl ms-3" title="[조 회] 는 계획일, [생산조회] 는 생산일">계획일/생산일</span>
        <input type="date" id="fdate" class="form-control form-control-sm w-date">
        <span>~</span>
        <input type="date" id="tdate" class="form-control form-control-sm w-date">
        <button type="button" class="btn btn-sm btn-outline-secondary" data-days="0">today</button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-days="3">3일</button>
        <button type="button" class="btn btn-sm btn-outline-secondary" data-days="7">1주일</button>
      </div>

      <div class="d-flex flex-wrap align-items-center gap-2">
        <span class="lbl">수주번호</span>
        <input type="text" id="keyText" class="form-control form-control-sm w-mid" title="입력하면 이 값으로만 조회 (생산라인 · 주야 · 기간 무시)">

        <span class="ms-2 small text-danger fw-bold">더블클릭 : 자세히</span>

        <div class="ms-auto d-flex gap-2">
          <button type="button" class="btn btn-sm btn-primary px-4" id="btnSearch">조 회</button>
          <button type="button" class="btn btn-sm btn-warning fw-bold" id="btnProd">생산조회</button>
          <button type="button" class="btn btn-sm btn-outline-success" id="btnExcel">엑셀</button>
        </div>
      </div>
    </div>

    <!-- ===== 목록 ===== -->
    <div id="grid"></div>
  </div>
</div>

<!-- 조회 중 표시 -->
<div id="loading">
  <div class="box">
    <div class="spinner-border" role="status"></div>
    <div class="msg">조회 중…</div>
    <div class="sub" id="loadingSub">잠시만 기다려 주세요</div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://unpkg.com/tabulator-tables@5.5.2/dist/js/tabulator.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<%@ include file="/WEB-INF/common/jepm_info_popup.jspf" %>

<script>
  const CTX    = '${pageContext.request.contextPath}';
  const MY_SABUN = '<c:out value="${sessionScope.USER.SABUN}"/>';      // 세션 사번
  const MY_NAME  = '<c:out value="${sessionScope.USER.NAME}"/>';       // 세션 이름 (본인 버튼)
  let grid = null;
  const MY_COMPANY = '<c:out value="${sessionScope.USER.COMPANY}"/>';   // 세션 사업장 (서울 / 오산)

  /* ---------- 공통 ---------- */
  function $(id) { return document.getElementById(id); }
  function ymdInput(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); }
  function num(v) { const n = Number(v); return isNaN(n) ? 0 : n; }

  function getJson(url) {
    return fetch(url, { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); location.href = CTX + "/sens.jsp"; }
          throw new Error(res.msg || "처리 중 오류가 발생했습니다.");
        }
        return res;
      });
  }

  /* yyyymmdd / yyyy-mm-dd / 날짜 → 2026-11-17 */
  function fmtDate(v) {
    if (v === null || v === undefined || v === "") return "";
    const s = String(v).replace(/\D/g, "");
    return s.length >= 8 ? s.substr(0, 4) + "-" + s.substr(4, 2) + "-" + s.substr(6, 2) : "";
  }
  /* 여러 날짜 (list 결과 "20261110,20261111") */
  function fmtDates(v) {
    if (!v) return "";
    return String(v).split(",").map(function (x) { return fmtDate(x.trim()); }).filter(Boolean).join(", ");
  }

  /* ---------- Tabulator 포매터 ---------- */
  const fDate  = function (c) { return fmtDate(c.getValue()); };
  const fNum   = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR"); };
  const f2     = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); };
  const fProc  = function (c) { const v = c.getValue() || ""; return v === "생산" ? '<span class="cell-prod">생산</span>' : v; };
  const fCheck = function (c) { return c.getValue() === "Y" ? "☑" : "☐"; };
  const sumCalc = { bottomCalc: "sum", bottomCalcFormatter: function (c) { return num(c.getValue()).toLocaleString("ko-KR"); } };

  /* 1230 / 12:30 / 시각 → 12:30 */
  function fmtTime(v) {
    if (v === null || v === undefined || v === "") return "";
    const m = String(v).match(/(\d{1,2}):?(\d{2})(?::\d{2}(?:\.\d+)?)?\s*$/);
    return m ? m[1].padStart(2, "0") + ":" + m[2] : String(v);
  }
  const fTime = function (c) { return fmtTime(c.getValue()); };
  /* 분 → 시:분 (준비시간 / 생산시간) */
  const fMin  = function (c) {
    const v = c.getValue();
    if (v === null || v === undefined || v === "" || num(v) === 0) return "";
    const n = num(v); return Math.floor(n / 60) + ":" + String(n % 60).padStart(2, "0");
  };

  /* 납품예정까지 남은 날 : D-7, 지나면 D+2 (6일 이내는 빨강) — mes3204 와 같음 */
  function ddayOf(v) {
    const s = String(v || "").replace(/\D/g, "");
    if (s.length < 8) return null;
    const due = new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2));
    const t = new Date(); const today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
    return Math.round((due - today) / 86400000);
  }
  const fDday = function (c) {
    const n = c.getValue();
    if (n === null || n === undefined || n === "") return "";
    const txt = n >= 0 ? "D-" + n : "D+" + (-n);
    return n <= 6 ? '<span class="dday-red">' + txt + '</span>' : txt;
  };

  function numCol(title, field, extra) {
    return Object.assign({ title: title, field: field, hozAlign: "right", formatter: fNum, sorter: "number", width: 70 }, extra || {});
  }
  const timeCols = [
    { title: "준비시작", field: "readyfrom", width: 65, hozAlign: "center", formatter: fTime, cssClass: "cell-time" },
    { title: "준비종료", field: "readyto",   width: 65, hozAlign: "center", formatter: fTime, cssClass: "cell-time" },
    { title: "준비시간", field: "readyterm", width: 65, hozAlign: "center", formatter: fMin,  cssClass: "cell-time" },
    { title: "생산시작", field: "ftime",     width: 65, hozAlign: "center", formatter: fTime, cssClass: "cell-ptime" },
    { title: "생산종료", field: "ttime",     width: 65, hozAlign: "center", formatter: fTime, cssClass: "cell-ptime" },
    { title: "생산시간", field: "timeterm",  width: 65, hozAlign: "center", formatter: fMin,  cssClass: "cell-ptime" }
  ];

  /* 더블클릭 : 수주 조회 팝업 (mes33 과 같음, mes3205_jepm_info 를 같이 사용, 수주 jpno 기준) */
  function openDetail(r) { if (r.mstjpno) openJepmOrderView(r.mstjpno); }

  /* ---------- 컬럼 : 접착 / 지함 ---------- */
  const STICK_COLUMNS = [
    { title: "사업장",       field: "company",      width: 50, hozAlign: "center", frozen: true },
    { title: "공정",         field: "flow",         width: 50, frozen: true },
    { title: "담당",         field: "sabunnm",      width: 60 },
    { title: "완성제품코드", field: "goodjepmcd",   width: 95 },
    { title: "완성품",       field: "goodjepmnm",   width: 260, tooltip: true },
    { title: "납품예정",     field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "D_day",        field: "d_day",        width: 55, hozAlign: "center", formatter: fDday, sorter: "number" },
    { title: "관리번호",     field: "orderno",      width: 80 },
    numCol("수주량",   "mst_qty", { width: 75 }),
    { title: "생산라인",     field: "workflow",     width: 80 },
    { title: "주야",         field: "worktime",     width: 45, hozAlign: "center" },
    numCol("순서",     "jobseq",  { width: 45 }),
    { title: "계획일",       field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("계획량",   "jisiqty", Object.assign({ width: 75 }, sumCalc)),
    numCol("지류출고-장", "papertuip", { width: 85 }),
    numCol("재사용지", "yarigeqty", { width: 70 }),
    { title: "접착",         field: "stick",        width: 55 },
    { title: "생산일",       field: "procdate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("생산량",   "qty",     Object.assign({ width: 70 }, sumCalc)),
    numCol("불량",     "papmqty", Object.assign({ width: 60 }, sumCalc))
  ].concat(timeCols, [
    { title: "생산담당",     field: "proder",       width: 70 },
    { title: "생산비고",     field: "prodremk",     width: 150, tooltip: true },
    { title: "비고",         field: "planremk",     width: 180, tooltip: true },
    { title: "미실적",       field: "chk",          width: 50, hozAlign: "center", formatter: fCheck, headerSort: false },
    { title: "재공코드",     field: "mst_jepmno",   width: 75 }
  ]);

  /* ---------- 컬럼 : 그 외 (지류 기준) ---------- */
  const PAPER_COLUMNS = [
    { title: "사업장",     field: "company",      width: 50, hozAlign: "center", frozen: true },
    { title: "외주처",     field: "flowcustname", width: 90, frozen: true },
    { title: "공정",       field: "flow",         width: 60 },
    { title: "담당",       field: "sabunnm",      width: 60 },
    { title: "제품코드",   field: "prodjepmcd",   width: 90 },
    { title: "제품명",     field: "prodjepmnm",   width: 260, tooltip: true },
    { title: "납품예정",   field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "D_day",      field: "d_day",        width: 55, hozAlign: "center", formatter: fDday, sorter: "number" },
    { title: "관리번호",   field: "orderno",      width: 80 },
    { title: "작업",       field: "papmkind",     width: 50, hozAlign: "center", formatter: fProc },
    numCol("수주량",   "mst_qty", { width: 75 }),
    { title: "생산라인",   field: "workflow",     width: 80 },
    { title: "주야",       field: "worktime",     width: 45, hozAlign: "center" },
    numCol("순서",     "jobseq",  { width: 45 }),
    { title: "계획일",     field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("계획량",   "jisiqty", Object.assign({ width: 75 }, sumCalc)),
    { title: "생산일",     field: "procdate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("생산-통",  "qty",     Object.assign({ width: 70 }, sumCalc)),
    numCol("불량-장",  "papmqty", Object.assign({ width: 65 }, sumCalc)),
    numCol("지류잔량-장", "paperprodtuip", { width: 85 }),
    numCol("재사용지", "yarigeqty", { width: 70 })
  ].concat(timeCols, [
    { title: "생산비고",   field: "prodremk",     width: 150, tooltip: true },
    { title: "작업분류",   field: "workkind",     width: 70 },
    { title: "지질",       field: "paperjepmnm",  width: 130, tooltip: true },
    { title: "규격",       field: "size",         width: 80 },
    { title: "재단규격",   field: "cutsize",      width: 80 },
    numCol("절",     "sizejul",  { width: 45, formatter: f2 }),
    numCol("부",     "sizebu",   { width: 45, formatter: f2 }),
    numCol("인-전",  "dofront",  { width: 45 }),
    numCol("인-후",  "doback",   { width: 45 }),
    { title: "계획비고",   field: "planremk",     width: 180, tooltip: true },
    { title: "미실적",     field: "chk",          width: 50, hozAlign: "center", formatter: fCheck, headerSort: false },
    { title: "재공코드",   field: "mst_jepmno",   width: 75 }
  ]);

  /* 열 폭이 제목 글자보다 좁으면 제목이 보이도록 넓힘 */
  STICK_COLUMNS.concat(PAPER_COLUMNS).forEach(function (c) {
    const need = String(c.title).length * 11 + 18;
    if (!c.width || c.width < need) c.width = need;
  });

  /* ---------- 공정별 생산라인 (PB ddlb_2) ---------- */
  function linesOf(flow) {
    switch (flow) {
      case "인쇄":
        return MY_COMPANY === "서울"
          ? ["전체", "서울MSBC", "서울ROND", "서울V3000"]
          : ["전체", "인쇄 1호", "인쇄 2호", "인쇄 3호", "스테이너만"];
      case "스테이너만": return ["전체", "스테이너만"];
      case "라미":       return ["전체", "라미", "라미2", "스테이너만"];
      case "박":         return ["전체", "박(닛코)", "박(하이델1)", "박(하이델2)"];
      case "실크":       return ["실크"];
      case "톰슨":       return ["전체", "톰슨1", "톰슨2", "스가노"];
      case "수작업":     return ["수작업"];
      case "접착":       return ["전체", "접착", "접착2"];
      case "지함":       return ["전체", "지함1", "지함2", "지함3", "수동지함"];
    }
    return ["전체"];
  }
  function fillLines() {
    const sel = $("line");
    sel.innerHTML = "";
    linesOf($("flow").value).forEach(function (v) {
      const o = document.createElement("option"); o.textContent = v; sel.appendChild(o);
    });
  }
  function isStick() { const f = $("flow").value; return f === "접착" || f === "지함"; }

  /* ---------- 조회 중 표시 ---------- */
  let loadingTimer = null;
  function showLoading(on) {
    const el = $("loading");
    clearInterval(loadingTimer);
    if (!on) { el.classList.remove("show"); return; }
    const start = Date.now();
    $("loadingSub").textContent = "잠시만 기다려 주세요";
    el.classList.add("show");
    loadingTimer = setInterval(function () {
      const sec = Math.floor((Date.now() - start) / 1000);
      if (sec >= 3) $("loadingSub").textContent = sec + "초 경과… 잠시만 기다려 주세요";
    }, 1000);
  }

  /* ---------- 조회 ---------- */
  let mode = "plan";            // plan = [조 회] (미실적, 계획일), prod = [생산조회] (생산일)
  function params() {
    const p = new URLSearchParams();
    p.set("mode",     mode);
    p.set("flow",     $("flow").value);
    p.set("line",     $("line").value);
    p.set("worktime", $("worktime").value);
    p.set("fdate",    $("fdate").value.replace(/-/g, ""));
    p.set("tdate",    $("tdate").value.replace(/-/g, ""));
    p.set("keyText",  $("keyText").value.trim());
    return p;
  }

  function search(m) {
    mode = (m === "prod") ? "prod" : "plan";
    const btn = $(mode === "prod" ? "btnProd" : "btnSearch"), btnText = btn.textContent;
    btn.disabled = true; btn.textContent = "조회 중…";
    showLoading(true);
    getJson(CTX + "/mes3811/list?" + params().toString())
      .then(function (res) {
        showLoading(false);
        const rows = (res.data || []).map(function (r) {
          r.d_day = ddayOf(r.deliverydate);
          if (!isStick()) r.cutsize = (r.cutwidth == null ? "" : num(r.cutwidth)) + "*" + (r.cutlength == null ? "" : num(r.cutlength));
          return r;
        });
        grid.setData(rows);
        $("rowInfo").textContent = (mode === "prod" ? "[생산조회] " : "[조 회] ") + "[" + $("flow").value + "] " +
          ($("keyText").value.trim() ? "[수주번호 단독 검색] " : "") +
          "조회 " + rows.length.toLocaleString("ko-KR") + "건";
        if (res.msg) alert(res.msg);
      })
      .catch(function (e) { showLoading(false); alert(e.message || e); })
      .then(function () { showLoading(false); btn.disabled = false; btn.textContent = btnText; });
  }

  /* 공정이 바뀌면 생산라인 · 컬럼 바꾸고 목록 비움 */
  function applyFlow() {
    fillLines();
    if (grid) { grid.clearData(); grid.setColumns(isStick() ? STICK_COLUMNS : PAPER_COLUMNS); }
    $("rowInfo").textContent = "";
  }

  /* ---------- 시작 ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    // 메뉴에서 넘어온 parm = 공정. 있으면 고정, 없으면 직접 고를 수 있음
    const parm = (typeof MENU_PARM !== "undefined" ? MENU_PARM : "").replace(/^스테이너$/, "스테이너만");
    if (parm) {
      const ok = Array.prototype.some.call($("flow").options, function (o) { return o.value === parm; });
      if (ok) { $("flow").value = parm; $("flow").disabled = true; }
      else alert("메뉴의 parm 값('" + parm + "')이 공정 목록에 없습니다.");
    }
    fillLines();

    // 계획일 : 이번 달 1일 ~ 오늘
    const t = new Date();
    $("fdate").value = ymdInput(new Date(t.getFullYear(), t.getMonth(), 1));
    $("tdate").value = ymdInput(t);
    document.querySelectorAll("[data-days]").forEach(function (b) {
      b.addEventListener("click", function () {
        const n = +b.getAttribute("data-days"), d = new Date();
        $("tdate").value = ymdInput(d);
        d.setDate(d.getDate() - n);
        $("fdate").value = ymdInput(d);
      });
    });

    grid = new Tabulator("#grid", {
      height: "calc(100vh - 235px)",
      layout: "fitData",
      columns: isStick() ? STICK_COLUMNS : PAPER_COLUMNS,
      selectable: 1,
      placeholder: "조회 버튼을 눌러 주세요.",
      columnDefaults: { headerSort: true, resizable: true, headerHozAlign: "center" }
    });
    grid.on("rowDblClick", function (e, row) { openDetail(row.getData()); });   // 자세히

    $("flow").addEventListener("change", applyFlow);
    $("btnSearch").addEventListener("click", function () { search("plan"); });
    $("btnProd").addEventListener("click", function () { search("prod"); });
    $("btnExcel").addEventListener("click", function () {
      if (!grid.getDataCount()) { alert("조회된 자료가 없습니다."); return; }
      const nm = (mode === "prod" ? "생산조회_" : "생산실적_") + $("flow").value;
      grid.download("xlsx", nm + "_" + ymdInput(new Date()).replace(/-/g, "") + ".xlsx", { sheetName: nm });
    });
    $("keyText").addEventListener("keydown", function (e) { if (e.key === "Enter") search(mode); });
  });
</script>

</body>
</html>
