<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>재작업</title>
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
      <h6>재작업</h6>
      <span class="row-info"><span id="rowInfo"></span></span>
    </div>

    <!-- ===== 검색 조건 ===== -->
    <div class="search-box">
      <div class="d-flex flex-wrap align-items-center gap-2">
        <span class="lbl">등록일</span>
        <input type="date" id="fdate" class="form-control form-control-sm w-date">
        <span>~</span>
        <input type="date" id="tdate" class="form-control form-control-sm w-date">

        <span class="lbl ms-3">수주번호</span>
        <input type="text" id="keyText" class="form-control form-control-sm w-mid" title="입력하면 이 값으로만 조회 (등록일 무시)">

        <span class="ms-2 small text-danger fw-bold">더블클릭 : 자세히</span>

        <div class="ms-auto d-flex gap-2">
          <button type="button" class="btn btn-sm btn-primary px-4" id="btnSearch">조 회</button>
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
  const fDate = function (c) { return fmtDate(c.getValue()); };
  const fNum  = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR"); };
  const sumCalc = { bottomCalc: "sum", bottomCalcFormatter: function (c) { return num(c.getValue()).toLocaleString("ko-KR"); } };
  function numCol(title, field, extra) {
    return Object.assign({ title: title, field: field, hozAlign: "right", formatter: fNum, sorter: "number", width: 70 }, extra || {});
  }

  /* 더블클릭 : 수주 조회 팝업 (mes33 과 같음, 재작업 수주의 jpno) */
  function openDetail(r) { if (r.jpno) openJepmOrderView(r.jpno); }

  /* ---------- 컬럼 (PB 화면 순서) ---------- */
  const COLUMNS = [
    { title: "등록일",     field: "prdate",       width: 85, hozAlign: "center", formatter: fDate },   // papm_mst.prdate
    { title: "수주일",     field: "cdate",        width: 85, hozAlign: "center", formatter: fDate },
    { title: "원관리번호", field: "wonorderno",   width: 85 },
    { title: "재작업번호", field: "orderno",      width: 85 },
    { title: "제품명",     field: "jepmnm",       width: 300, tooltip: true },
    { title: "납품예정",   field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    numCol("수주량",     "qty",      Object.assign({ width: 75 }, sumCalc)),
    numCol("원생산수량", "papm_qty", Object.assign({ width: 80 }, sumCalc)),
    numCol("재작업수량", "reqty",    Object.assign({ width: 80 }, sumCalc)),
    { title: "생산일",     field: "proddate",     width: 85, hozAlign: "center", formatter: fDate },
    { title: "출고일",     field: "outdate",      width: 85, hozAlign: "center", formatter: fDate },
    { title: "불량공정",   field: "papmflow",     width: 80 },
    { title: "문제점",     field: "trouble",      width: 300, tooltip: true },
    { title: "파일",       field: "file_chk",     width: 45, hozAlign: "center",
      tooltip: function (e, c) { return c.getRow().getData().filename || ""; } }
  ];

  /* 열 폭이 제목 글자보다 좁으면 제목이 보이도록 넓힘 */
  COLUMNS.forEach(function (c) {
    const need = String(c.title).length * 11 + 18;
    if (!c.width || c.width < need) c.width = need;
  });

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
  function params() {
    const p = new URLSearchParams();
    p.set("fdate",   $("fdate").value.replace(/-/g, ""));
    p.set("tdate",   $("tdate").value.replace(/-/g, ""));
    p.set("keyText", $("keyText").value.trim());
    return p;
  }

  function search() {
    const btn = $("btnSearch"), btnText = btn.textContent;
    btn.disabled = true; btn.textContent = "조회 중…";
    showLoading(true);
    getJson(CTX + "/mes77/list?" + params().toString())
      .then(function (res) {
        showLoading(false);
        const rows = res.data || [];
        grid.setData(rows);
        $("rowInfo").textContent = ($("keyText").value.trim() ? "[수주번호 단독 검색] " : "") +
          "조회 " + rows.length.toLocaleString("ko-KR") + "건";
        if (res.msg) alert(res.msg);
      })
      .catch(function (e) { showLoading(false); alert(e.message || e); })
      .then(function () { showLoading(false); btn.disabled = false; btn.textContent = btnText; });
  }

  /* ---------- 시작 ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    // 등록일 : 이번 달 1일 ~ 오늘
    const t = new Date();
    $("fdate").value = ymdInput(new Date(t.getFullYear(), t.getMonth(), 1));
    $("tdate").value = ymdInput(t);

    grid = new Tabulator("#grid", {
      height: "calc(100vh - 200px)",
      layout: "fitData",
      columns: COLUMNS,
      selectable: 1,
      placeholder: "조회 버튼을 눌러 주세요.",
      columnDefaults: { headerSort: true, resizable: true, headerHozAlign: "center" }
    });
    grid.on("rowDblClick", function (e, row) { openDetail(row.getData()); });   // 자세히

    $("btnSearch").addEventListener("click", search);
    $("btnExcel").addEventListener("click", function () {
      if (!grid.getDataCount()) { alert("조회된 자료가 없습니다."); return; }
      grid.download("xlsx", "재작업_" + ymdInput(new Date()).replace(/-/g, "") + ".xlsx", { sheetName: "재작업" });
    });
    $("keyText").addEventListener("keydown", function (e) { if (e.key === "Enter") search(); });
  });
</script>

</body>
</html>
