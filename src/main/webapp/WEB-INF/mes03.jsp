<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>사양서 결재</title>
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
  /* 줄마다 결재 버튼 */
  .btn-sign { font-size:.72rem; line-height:1; padding:3px 7px; border-radius:4px; border:1px solid #7c3aed;
              background:#fff; color:#7c3aed; font-weight:700; cursor:pointer; }
  .btn-sign:hover { background:#7c3aed; color:#fff; }
  .btn-sign.done, .btn-sign:disabled { border-color:#ced4da; color:#adb5bd; background:#fff; cursor:default; }
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
      <h6>사양서 결재</h6>
      <span class="row-info"><span id="rowInfo"></span></span>
    </div>

    <!-- ===== 검색 조건 ===== -->
    <div class="search-box">
      <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
        <span class="lbl">등록일</span>
        <input type="date" id="fdate" class="form-control form-control-sm w-date">
        <span>~</span>
        <input type="date" id="tdate" class="form-control form-control-sm w-date">

        <span class="lbl ms-2">담당</span>
        <input type="text" id="sabun" class="form-control form-control-sm w-mid" placeholder="이름 또는 사번">

        <span class="lbl ms-2">매출처</span>
        <input type="text" id="custName" class="form-control form-control-sm w-long" list="custList" placeholder="이름 입력 후 선택" autocomplete="off">
        <datalist id="custList"></datalist>

        <span class="lbl ms-2">부서</span>
        <select id="custseqcd" class="form-select form-select-sm w-mid"><option value="">전체</option></select>

        <span class="lbl ms-2">상태</span>
        <select id="ok1" class="form-select form-select-sm w-sel">
          <option>전체</option><option>확정</option><option>결재</option><option>반려</option>
        </select>
      </div>

      <div class="d-flex flex-wrap align-items-center gap-2">
        <span class="lbl">수주번호</span>
        <input type="text" id="orderno" class="form-control form-control-sm w-mid" title="입력하면 수주번호로만 조회 (다른 조건 무시)">

        <select id="test" class="form-select form-select-sm w-sel ms-2">
          <option>전체</option><option>제품</option><option>상품</option>
        </select>

        <span class="lbl ms-2">제품분류</span>
        <input type="text" id="kind" class="form-control form-control-sm w-mid">

        <span class="lbl ms-2">제품명</span>
        <input type="text" id="jepmnm" class="form-control form-control-sm w-long" placeholder="앞글자/포함글자  ENTER=조회">

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
<%@ include file="/WEB-INF/common/mes_sign.jspf" %>

<script>
  const CTX     = '${pageContext.request.contextPath}';
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

  /* 팝업(사양서 확인)에서 결재·반려하면 불림 — 해당 줄 상태 바꿈 */
  window.onJepmSigned = function (jpno, ok1) {
    if (!grid) return;
    grid.getRows().forEach(function (row) {
      if ((row.getData().jpno || "") === jpno) row.update({ ok1: ok1 });
    });
  };

  /* ---------- 결재 버튼 ---------- */
  const fSign = function (c) {
    const done = (c.getRow().getData().ok1 || "") === "결재";
    return '<button type="button" class="btn-sign' + (done ? ' done" title="결재 완료"' : '"') + '>결재</button>';
  };
  function signRow(e, cell) {
    const r = cell.getRow().getData();
    if ((r.ok1 || "") === "결재") { alert("이미 결재된 사양서입니다.\n관리번호 " + (r.orderno || "")); return; }
    if (!confirm("관리번호 " + (r.orderno || "") + "\n" + (r.jepmnm || "") + "\n\n결재 처리할까요?")) return;
    const btn = cell.getElement().querySelector("button");
    if (btn) { btn.disabled = true; btn.textContent = "처리중"; }
    signJepm(r.jpno)
      .then(function (d) {
        // 결재한 줄만 결재로 표시 (서버에서 jpno 1건만 결재)
        cell.getRow().update({ ok1: "결재" });
        alert("결재 완료되었습니다.\n관리번호 " + d.orderno);
      })
      .catch(function (err) {
        alert(err.message || err);
        cell.getRow().reformat();                     // 버튼 원래대로
      });
  }

  /* ---------- 컬럼 (PB 화면 순서) ---------- */
  const COLUMNS = [
    { title: "담당",       field: "sabunnm",      width: 65, frozen: true },
    { title: "구분",       field: "test",         width: 50, hozAlign: "center", frozen: true },
    { title: "분류",       field: "jepmkind",     width: 80, frozen: true },   // jepm_mst.kind
    { title: "원코드",     field: "wonjepmcd",    width: 75 },
    { title: "매출처",     field: "custname",     width: 120 },
    { title: "거래처부서", field: "custsectname", width: 100 },
    { title: "수주일",     field: "cdate",        width: 85, hozAlign: "center", formatter: fDate },
    { title: "등록일",     field: "prdate",       width: 85, hozAlign: "center", formatter: fDate },
    { title: "관리번호",   field: "orderno",      width: 95 },
    { title: "PO-Code",    field: "pocode",       width: 80 },
    { title: "물류코드",   field: "outjpno",      width: 85 },
    { title: "제품명",     field: "jepmnm",       width: 300, tooltip: true },
    { title: "납품예정",   field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    Object.assign({ title: "수주량",   field: "qty",      hozAlign: "right", formatter: fNum, sorter: "number", width: 75 }, sumCalc),
    Object.assign({ title: "납품잔량", field: "restqty",  hozAlign: "right", formatter: fNum, sorter: "number", width: 75 }, sumCalc),
    { title: "상태",       field: "ok1",          width: 55, hozAlign: "center", formatter: fStat },
    { title: "결재", field: "_sign", width: 55, hozAlign: "center", headerSort: false, frozen: true,   // 맨 오른쪽 고정
      formatter: fSign, cellClick: signRow, download: false }
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
    p.set("orderno",   $("orderno").value.trim());
    p.set("fdate",     $("fdate").value.replace(/-/g, ""));
    p.set("tdate",     $("tdate").value.replace(/-/g, ""));
    p.set("sabun",     $("sabun").value.trim());
    p.set("custcd",    custMap[$("custName").value.trim()] || "");
    p.set("custseqcd", $("custseqcd").value);
    p.set("ok1",       $("ok1").value);
    p.set("test",      $("test").value);
    p.set("kind",      $("kind").value.trim());
    p.set("jepmnm",    $("jepmnm").value.trim());
    return p;
  }

  function search() {
    if ($("custName").value.trim() && !custMap[$("custName").value.trim()]) {
      alert("매출처는 목록에서 선택하세요."); $("custName").focus(); return;
    }
    const btn = $("btnSearch");
    btn.disabled = true; btn.textContent = "조회 중…";
    showLoading(true);
    getJson(CTX + "/mes03/list?" + params().toString())
      .then(function (res) {
        showLoading(false);
        const rows = res.data || [];
        grid.setData(rows);
        $("rowInfo").textContent = ($("orderno").value.trim() ? "[수주번호 단독 검색] " : "") +
                                   "조회 " + rows.length.toLocaleString("ko-KR") + "건";
        if (res.msg) alert(res.msg);
      })
      .catch(function (e) { showLoading(false); alert(e.message || e); })
      .then(function () { showLoading(false); btn.disabled = false; btn.textContent = "조 회"; });
  }

  /* ---------- 매출처 / 부서 (mes0201 것을 같이 씀) ---------- */
  let custTimer = null;
  function findCust() {
    const q = $("custName").value.trim();
    if (custMap[q]) { loadDept(custMap[q]); return; }
    loadDept("");
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
          if (custMap[$("custName").value.trim()]) loadDept(custMap[$("custName").value.trim()]);
        })
        .catch(function (e) { console.log(e); });
    }, 250);
  }

  function loadDept(custcd) {
    const sel = $("custseqcd");
    sel.innerHTML = '<option value="">전체</option>';
    if (!custcd) return;
    getJson(CTX + "/mes0201/dept?custcd=" + encodeURIComponent(custcd))
      .then(function (res) {
        (res.data || []).forEach(function (d) {
          const o = document.createElement("option");
          o.value = d.custseqcd; o.textContent = d.custsectname;
          sel.appendChild(o);
        });
      })
      .catch(function (e) { console.log(e); });
  }

  /* ---------- 시작 ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    // 등록일 : 이번 달 1일 ~ 오늘
    const t = new Date(), f = new Date(t.getFullYear(), t.getMonth(), 1);
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
    // 더블클릭 : 자세히 (사양서 확인 팝업)
    grid.on("rowDblClick", function (e, row) {
      const r = row.getData();
      openJepmInfo(r.jpno, r.orderno, "결재");
    });

    $("btnSearch").addEventListener("click", search);
    $("btnExcel").addEventListener("click", function () {
      if (!grid.getDataCount()) { alert("조회된 자료가 없습니다."); return; }
      grid.download("xlsx", "사양서결재_" + ymdInput(new Date()).replace(/-/g, "") + ".xlsx", { sheetName: "사양서결재" });
    });

    // 입력칸에서 ENTER = 조회
    ["orderno", "sabun", "kind", "jepmnm"].forEach(function (id) {
      $(id).addEventListener("keydown", function (e) { if (e.key === "Enter") search(); });
    });

    $("custName").addEventListener("input", findCust);
    $("custName").addEventListener("change", findCust);
  });
</script>

</body>
</html>
