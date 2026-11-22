<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품 사양</title>
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
  /* 줄마다 확인 버튼 */
  .btn-row { font-size:.72rem; line-height:1; padding:3px 7px; border-radius:4px; border:1px solid #2f3e5c;
             background:#fff; color:#2f3e5c; font-weight:700; cursor:pointer; }
  .btn-row:hover { background:#2f3e5c; color:#fff; }
  .btn-row.off { border-color:#ced4da; color:#adb5bd; cursor:default; }
  .btn-row.off:hover { background:#fff; color:#adb5bd; }

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
      <h6>제품 사양</h6>
      <span class="row-info"><span id="rowInfo"></span></span>
    </div>

    <!-- ===== 검색 조건 ===== -->
    <div class="search-box">
      <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
        <select id="dateKind" class="form-select form-select-sm w-sel">
          <option value="prdate">등록일</option>
          <option value="deliverydate">납품예정일</option>
        </select>
        <input type="date" id="fdate" class="form-control form-control-sm w-date">
        <span>~</span>
        <input type="date" id="tdate" class="form-control form-control-sm w-date">

        <span class="lbl ms-2">담당</span>
        <input type="text" id="sabun" class="form-control form-control-sm w-mid" placeholder="이름 또는 사번">
        <button type="button" class="btn btn-sm btn-outline-primary" id="btnMe">본인</button>

        <span class="lbl ms-2">매출처</span>
        <input type="text" id="custName" class="form-control form-control-sm w-long" list="custList" placeholder="이름 입력 후 선택" autocomplete="off">
        <datalist id="custList"></datalist>

        <span class="lbl ms-2">상태</span>
        <select id="ok1" class="form-select form-select-sm w-sel">
          <option>전체</option><option>확정</option><option>미확정</option><option>반려</option><option>결재</option>
        </select>
      </div>

      <div class="d-flex flex-wrap align-items-center gap-2">
        <select id="test" class="form-select form-select-sm w-sel">
          <option>전체</option><option>제품</option><option>상품</option>
        </select>

        <span class="lbl ms-2">제품분류</span>
        <input type="text" id="kind" class="form-control form-control-sm w-mid">

        <span class="lbl ms-2">제품명</span>
        <input type="text" id="jepmnm" class="form-control form-control-sm w-long" placeholder="앞글자/포함글자  ENTER=조회">

        <span class="lbl ms-2">부코드</span>
        <input type="text" id="bucode" class="form-control form-control-sm w-mid" title="입력하면 부코드로만 조회 (기간 포함 다른 조건 무시)">

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
  const CTX     = '${pageContext.request.contextPath}';
  const MY_NAME = '<c:out value="${sessionScope.USER.NAME}"/>';       // 세션 이름 (본인 버튼)
  let grid = null, custMap = {};

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

  function fmtDate(v) {
    if (v === null || v === undefined || v === "") return "";
    const s = String(v).replace(/\D/g, "");
    return s.length >= 8 ? s.substr(0, 4) + "-" + s.substr(4, 2) + "-" + s.substr(6, 2) : "";
  }

  /* ---------- Tabulator 포매터 ---------- */
  const fDate = function (c) { return fmtDate(c.getValue()); };
  const fNum  = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR"); };
  const fStat = function (c) {
    const v = c.getValue() || "";
    if (v === "결재") return '<span class="st-wait">' + v + '</span>';
    if (v === "반려") return '<span class="st-reject">' + v + '</span>';
    return v;
  };
  const sumCalc = { bottomCalc: "sum", bottomCalcFormatter: function (c) { return num(c.getValue()).toLocaleString("ko-KR"); } };

  /* ---------- 컬럼 (PB 화면 순서) ---------- */
  const fNum2 = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); };
  const fAtt  = function (c) { return c.getValue() ? "첨부" : ""; };

  /* 더블클릭 : 제품 사양 정보 팝업 (jepmno 기준, 생산·결재 구분 없음) */
  function openDetail(r) { openJepmSpec(r.jepmno); }

  const COLUMNS = [
    { title: "구분",       field: "test",        width: 50, hozAlign: "center", frozen: true },
    { title: "분류",       field: "kind",        width: 80, frozen: true },
    { title: "거래처",     field: "custname",    width: 120 },
    { title: "제품코드",   field: "jepmcd",      width: 100 },
    { title: "제품명",     field: "jepmnm",      width: 300, tooltip: true },
    { title: "부코드",     field: "custjepmcd",  width: 85 },
    { title: "완제품코드", field: "prodjepmcd",  width: 90 },
    { title: "완제품",     field: "prodjepmnm",  width: 220, tooltip: true },
    { title: "담당",       field: "sabunnm",     width: 65 },
    { title: "판형",       field: "pantype",     width: 70 },
    { title: "규격",       field: "size",        width: 85 },
    { title: "절수",       field: "sizejul",     width: 50, hozAlign: "right", formatter: fNum2, sorter: "number" },
    { title: "부수",       field: "sizebu",      width: 50, hozAlign: "right", formatter: fNum2, sorter: "number" },
    { title: "판수",       field: "pancnt",      width: 50, hozAlign: "right", formatter: fNum,  sorter: "number" },
    { title: "도수",       field: "docnt",       width: 50, hozAlign: "right", formatter: fNum,  sorter: "number" },
    { title: "등록일",     field: "prdate",      width: 85, hozAlign: "center", formatter: fDate },
    { title: "견적",       field: "filejpno",    width: 50, hozAlign: "center", formatter: fAtt },
    { title: "제조",       field: "mcinfojpno",  width: 50, hozAlign: "center", formatter: fAtt }
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
    p.set("dateKind",  $("dateKind").value);
    p.set("fdate",     $("fdate").value.replace(/-/g, ""));
    p.set("tdate",     $("tdate").value.replace(/-/g, ""));
    p.set("sabun",     $("sabun").value.trim());
    p.set("custcd",    custMap[$("custName").value.trim()] || "");
    p.set("ok1",       $("ok1").value);
    p.set("test",      $("test").value);
    p.set("kind",      $("kind").value.trim());
    p.set("jepmnm",    $("jepmnm").value.trim());
    p.set("bucode",    $("bucode").value.trim());
    return p;
  }

  function search() {
    if ($("custName").value.trim() && !custMap[$("custName").value.trim()]) {
      alert("매출처는 목록에서 선택하세요."); $("custName").focus(); return;
    }
    const btn = $("btnSearch");
    btn.disabled = true; btn.textContent = "조회 중…";
    showLoading(true);
    getJson(CTX + "/mes3202/list?" + params().toString())
      .then(function (res) {
        showLoading(false);
        const rows = res.data || [];
        grid.setData(rows);
        $("rowInfo").textContent = ($("bucode").value.trim() ? "[부코드 단독 검색] " : "") +
                                   "조회 " + rows.length.toLocaleString("ko-KR") + "건";
        if (res.msg) alert(res.msg);
      })
      .catch(function (e) { showLoading(false); alert(e.message || e); })
      .then(function () { showLoading(false); btn.disabled = false; btn.textContent = "조 회"; });
  }

  /* ---------- 매출처 (mes0201 것을 같이 씀) ---------- */
  let custTimer = null;
  function findCust() {
    const q = $("custName").value.trim();
    if (custMap[q]) return;
    clearTimeout(custTimer);
    if (q.length < 1) return;
    custTimer = setTimeout(function () {
      getJson(CTX + "/mes0201/cust?q=" + encodeURIComponent(q))
        .then(function (res) {
          const dl = $("custList");
          dl.innerHTML = "";
          custMap = {};
          (res.data || []).forEach(function (c) {
            custMap[c.custname] = c.custcd;
            const o = document.createElement("option");
            o.value = c.custname;
            dl.appendChild(o);
          });
        })
        .catch(function (e) { console.log(e); });
    }, 250);
  }

  /* ---------- 시작 ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    // 기본 기간 : 15일 전 ~ 오늘
    const t = new Date(), f = new Date(); f.setDate(f.getDate() - 15);
    $("fdate").value = ymdInput(f);
    $("tdate").value = ymdInput(t);

    grid = new Tabulator("#grid", {
      height: "calc(100vh - 235px)",
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
      grid.download("xlsx", "제품사양_" + ymdInput(new Date()).replace(/-/g, "") + ".xlsx", { sheetName: "제품사양" });
    });

    // 입력칸에서 ENTER = 조회
    ["sabun", "kind", "jepmnm", "bucode"].forEach(function (id) {
      $(id).addEventListener("keydown", function (e) { if (e.key === "Enter") search(); });
    });

    $("custName").addEventListener("input", findCust);
    $("custName").addEventListener("change", findCust);

    // 본인 : 세션 NAME 을 담당 칸에 넣고 바로 조회
    $("btnMe").addEventListener("click", function () {
      if (!MY_NAME) { alert("로그인 정보(세션 NAME)에 이름이 없습니다."); return; }
      $("sabun").value = MY_NAME;
      search();
    });
  });
</script>

</body>
</html>
