<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>매장 재고조사</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 매장 재고조사 (ai601) ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
    --red: #a8321a; --red-bg: #fde9e4;
    --blue: #1f5fbf; --blue-bg: #e4eefc;
    --green: #1f6b45; --green-bg: #e1f3e8;
  }
  .ji { font-size: 14px; flex: 1 1 0; min-width: 0; }
  .ji-grid { display: grid; grid-template-columns: 380px minmax(0, 1fr); gap: 16px; align-items: start; }
  @media (max-width: 1100px) { .ji-grid { grid-template-columns: 1fr; } }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .tools { margin-left: auto; display: flex; gap: 6px; }
  .hint { font-size: 11px; color: var(--muted); }

  /* 요약 */
  .sum-bar { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); border-bottom: 1px solid var(--line); }
  .sum-bar > div { padding: 10px 16px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .lb { font-size: 12px; color: var(--muted); }
  .sum-bar .v { font-size: 20px; font-weight: 800; }
  .prog { height: 6px; border-radius: 3px; background: #e6eaf0; overflow: hidden; margin-top: 4px; }
  .prog > i { display: block; height: 6px; background: var(--navy); width: 0; }
  @media (max-width: 700px) { .sum-bar { grid-template-columns: repeat(2, minmax(0, 1fr)); } }

  /* 왼쪽 : 검색 · 입력 */
  .pane { padding: 14px 16px; display: flex; flex-direction: column; gap: 10px; }
  .pane .form-label { font-size: 12px; color: var(--muted); margin-bottom: 2px; }
  .sec-t { font-size: 12px; font-weight: 700; color: var(--muted); display: flex; justify-content: space-between; }
  .found { border: 1px solid var(--line); border-radius: 8px; max-height: 260px; overflow: auto; }
  .found .it { display: flex; justify-content: space-between; align-items: center; gap: 8px; width: 100%; padding: 8px 12px;
               border: 0; border-bottom: 1px solid #eef1f5; background: #fff; text-align: left; font: inherit; }
  .found .it:last-child { border-bottom: 0; }
  .found .it:hover { background: #f6f8fb; }
  .found .it.on { background: var(--blue-bg); box-shadow: inset 4px 0 0 var(--navy); }
  .found .nm { display: block; font-size: 13px; font-weight: 700; color: #1f2733; }
  .found .sb { display: block; font-size: 11px; color: var(--muted); }
  .found .rt { font-size: 12px; color: var(--muted); white-space: nowrap; text-align: right; }
  .found .empty { padding: 14px; text-align: center; color: var(--muted); font-size: 13px; }

  .selbox { border: 1px solid #cfdcf3; background: #f3f7fd; border-radius: 8px; padding: 12px 14px; display: flex; flex-direction: column; gap: 8px; }
  .selbox.none { background: #f6f8fb; border-color: var(--line); color: var(--muted); text-align: center; font-size: 13px; padding: 22px 14px; }
  .selbox .nm { font-size: 15px; font-weight: 800; }
  .selbox .sb { font-size: 12px; color: var(--muted); }
  .selbox .nums { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
  .selbox .nums .lb { font-size: 11px; color: var(--muted); }
  .selbox .nums .v { font-size: 20px; font-weight: 800; }
  #eQty { height: 46px; border: 2px solid var(--navy); font-size: 22px; font-weight: 800; text-align: right; }
  #btnInput { height: 46px; background: var(--accent); border: 0; color: var(--navy); font-weight: 800; white-space: nowrap; }
  #btnInput:hover { background: #ffcc45; }
  .ent { font-size: 12px; }
  .ent div { display: flex; justify-content: space-between; align-items: center; padding: 3px 0; border-bottom: 1px dashed #dfe5ee; }
  .ent .x { border: 0; background: none; color: #c0392b; font-size: 12px; padding: 0 4px; }

  .recent div { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #eef1f5; font-size: 13px; }
  .recent span.t { color: var(--muted); }

  /* 오른쪽 : 조사 목록 */
  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
  .tabs .btn { font-size: 12px; }
  .tabs .btn b { margin-left: 3px; }
  #listTable { border: 0; font-size: 13px; }
  #listTable .tabulator-header { background: var(--navy-soft); }
  #listTable .tabulator-row { cursor: pointer; }
  #listTable .tabulator-row.row-sel { background: #dfe9fb !important; }
  #listTable .tabulator-footer { background: #f6f8fb; font-weight: 700; }
  .st { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; }
  .st-none  { color: var(--muted); background: #eef1f5; }
  .st-ok    { color: var(--green); background: var(--green-bg); }
  .st-short { color: var(--red); background: var(--red-bg); }
  .st-over  { color: var(--blue); background: var(--blue-bg); }
  .neg { color: var(--red); font-weight: 700; }
  .posv { color: var(--blue); font-weight: 700; }
  .code { font-size: 11px; color: var(--muted); }

  /* 화면 탭 */
  .page-tabs { border-bottom: 2px solid var(--navy); margin-bottom: 14px; gap: 4px; }
  .page-tabs .nav-link { border: 1px solid var(--line); border-bottom: 0; border-radius: 8px 8px 0 0; color: var(--navy); background: #fff; font-weight: 700; padding: 8px 18px; }
  .page-tabs .nav-link.active { background: var(--navy); color: #fff; border-color: var(--navy); }

  /* 재고조정 조회 */
  .adj-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 16px; align-items: start; }
  @media (max-width: 1000px) { .adj-grid { grid-template-columns: 1fr; } }
  #mstTable, #dtlTable { border: 0; font-size: 13px; }
  #mstTable .tabulator-header, #dtlTable .tabulator-header { background: var(--navy-soft); }
  #mstTable .tabulator-row { cursor: pointer; }
  #mstTable .tabulator-row.tabulator-selected { background: #dfe9fb; }
  #mstTable .tabulator-footer, #dtlTable .tabulator-footer { background: #f6f8fb; font-weight: 700; }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <div class="flex-grow-1 p-4 ji">

    <ul class="nav page-tabs" role="tablist">
      <li class="nav-item"><button type="button" class="nav-link active" data-pane="paneInput">재고조사 입력</button></li>
      <li class="nav-item"><button type="button" class="nav-link" data-pane="paneAdj">재고조정 조회</button></li>
    </ul>

    <div id="paneInput">
    <!-- ================= 요약 ================= -->
    <div class="card-box mb-3">
      <div class="card-head">
        <h6>매장 재고조사</h6>
        <span class="small" style="opacity:.85">입력한 수량은 바로 저장됩니다 · 같은 제품을 다시 입력하면 더해집니다</span>
        <div class="tools">
          <button type="button" class="btn btn-sm btn-light" id="btnReload">새로고침</button>
          <button type="button" class="btn btn-sm btn-light" id="btnExcel">엑셀</button>
          <button type="button" class="btn btn-sm btn-outline-light" id="btnReset">재고 초기화</button>
          <button type="button" class="btn btn-sm btn-warning fw-bold" id="btnClose">조사 마감 · 재고 반영</button>
        </div>
      </div>
      <div class="sum-bar">
        <div><div class="lb">대상 제품</div><div class="v" id="sTotal">0</div></div>
        <div><div class="lb">조사 완료</div><div class="v" id="sDone">0</div></div>
        <div><div class="lb">차이 제품</div><div class="v" id="sDiff" style="color:var(--red)">0</div></div>
        <div><div class="lb">차이 금액 (입고가)</div><div class="v" id="sAmt">0</div></div>
        <div><div class="lb">진행률</div><div class="v" id="sRate">0%</div><div class="prog"><i id="sBar"></i></div></div>
      </div>
    </div>

    <div class="ji-grid">

      <!-- ================= 제품 검색 → 수량 입력 ================= -->
      <div class="card-box">
        <div class="card-head"><h6>제품 검색</h6></div>
        <div class="pane">
          <div class="row g-2">
            <div class="col-6"><label class="form-label" for="qCode">제품코드</label>
              <input type="text" class="form-control form-control-sm" id="qCode" placeholder="바코드 스캔 가능" autocomplete="off"></div>
            <div class="col-6"><label class="form-label" for="qMaker">제조회사</label>
              <input type="text" class="form-control form-control-sm" id="qMaker" autocomplete="off"></div>
            <div class="col-6"><label class="form-label" for="qBrand">브랜드</label>
              <input type="text" class="form-control form-control-sm" id="qBrand" autocomplete="off"></div>
            <div class="col-6"><label class="form-label" for="qName">제품명</label>
              <input type="text" class="form-control form-control-sm" id="qName" autocomplete="off"></div>
          </div>
          <div class="d-flex gap-2">
            <button type="button" class="btn btn-sm btn-primary flex-fill" id="btnFind" style="background:var(--navy);border-color:var(--navy)">검색 (Enter)</button>
            <button type="button" class="btn btn-sm btn-outline-secondary" id="btnFindClear">지우기</button>
          </div>

          <div class="sec-t"><span>검색 결과 <b id="fCnt">0</b>건</span><span>눌러서 선택</span></div>
          <div class="found" id="found"><div class="empty">제품코드·제조회사·브랜드·제품명으로 검색하세요.</div></div>

          <!-- 선택한 제품 -->
          <div class="selbox none" id="selBox">제품을 선택하면 여기서 수량을 입력합니다.</div>

          <div class="sec-t mt-1"><span>최근 입력</span><span class="hint" id="recentHint"></span></div>
          <div class="recent" id="recent"></div>
        </div>
      </div>

      <!-- ================= 조사 목록 ================= -->
      <div class="card-box">
        <div class="filter">
          <div class="btn-group tabs" role="group" id="tabs">
            <button type="button" class="btn btn-sm btn-outline-secondary active" data-tab="all">전체<b id="tAll">0</b></button>
            <button type="button" class="btn btn-sm btn-outline-secondary" data-tab="none">미조사<b id="tNone">0</b></button>
            <button type="button" class="btn btn-sm btn-outline-secondary" data-tab="diff">차이<b id="tDiff">0</b></button>
            <button type="button" class="btn btn-sm btn-outline-secondary" data-tab="ok">일치<b id="tOk">0</b></button>
          </div>
          <input type="text" class="form-control form-control-sm" id="lMaker" placeholder="제조회사" style="width:130px">
          <input type="text" class="form-control form-control-sm" id="lName" placeholder="제품명·코드" style="width:150px">
          <span class="hint ms-auto" id="listHint">전산재고가 있는 제품 + 조사한 제품</span>
        </div>
        <div id="listTable"></div>
      </div>

    </div>
    </div><!-- /paneInput -->

    <!-- ================= 재고조정 조회 ================= -->
    <div id="paneAdj" class="d-none">
      <div class="card-box mb-3">
        <div class="filter">
          <label class="small text-muted" for="aFrom">기간</label>
          <input type="date" class="form-control form-control-sm" id="aFrom" style="width:150px">
          <span>~</span>
          <input type="date" class="form-control form-control-sm" id="aTo" style="width:150px">
          <div class="btn-group btn-group-sm">
            <button type="button" class="btn btn-outline-secondary" data-days="0">오늘</button>
            <button type="button" class="btn btn-outline-secondary" data-days="7">7일</button>
            <button type="button" class="btn btn-outline-secondary" data-days="30">30일</button>
            <button type="button" class="btn btn-outline-secondary" data-days="m">이번 달</button>
          </div>
          <button type="button" class="btn btn-sm btn-secondary" id="ai601AdjSearch">조회</button>
        </div>
      </div>
      <div class="adj-grid">
        <div class="card-box">
          <div class="card-head"><h6>재고조정 전표</h6><span class="ms-auto small">전표 <b id="aCnt" style="color:var(--accent)">0</b>건</span></div>
          <div id="mstTable"></div>
        </div>
        <div class="card-box">
          <div class="card-head"><h6 id="dtlTitle">전표 상세</h6><span class="ms-auto small" id="dtlSub"></span>
            <button type="button" class="btn btn-sm btn-outline-light" id="btnAdjDel" disabled>전표 삭제</button></div>
          <div class="hint px-3 py-1" style="border-bottom:1px solid var(--line)">수량 + 는 재고 감소, − 는 재고 증가 · 전표를 삭제하면 수량만큼 재고에 더해 되돌립니다</div>
          <div id="dtlTable"></div>
        </div>
      </div>
    </div><!-- /paneAdj -->

  </div>
</div>

<!-- 마감 확인 -->
<div class="modal fade" id="closeModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header" style="background:var(--navy);color:#fff">
        <h6 class="modal-title fw-bold">조사 마감 · 재고 반영</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <table class="table table-sm mb-2">
          <tr><th class="fw-normal text-muted">조사한 제품</th><td class="text-end fw-bold" id="cDone"></td></tr>
          <tr><th class="fw-normal text-muted">차이 있는 제품</th><td class="text-end fw-bold" id="cLines"></td></tr>
          <tr><th class="fw-normal text-muted">차이 수량 합계</th><td class="text-end fw-bold" id="cQty"></td></tr>
          <tr><th class="fw-normal text-muted">차이 금액 (입고가)</th><td class="text-end fw-bold" id="cAmt"></td></tr>
          <tr><th class="fw-normal text-muted">미조사 제품</th><td class="text-end" id="cNone"></td></tr>
        </table>
        <div class="alert alert-warning py-2 small mb-2">
          조정 전표(실사) 1건에 조사한 제품이 모두 상세로 남습니다. 조사한 제품만 실사 수량으로 재고가 바뀝니다. <b>미조사 제품은 그대로</b>입니다.<br>
          마감하면 입력한 실사 수량은 지워지고 재고조정 전표(실사)로 남습니다.
        </div>
        <label class="form-label small text-muted" for="cRemk">비고</label>
        <input type="text" class="form-control form-control-sm" id="cRemk" maxlength="100" placeholder="예) 10월 정기 재고조사">
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">취소</button>
        <button type="button" class="btn btn-warning fw-bold" id="btnCloseGo">마감하고 재고 반영</button>
      </div>
    </div>
  </div>
</div>

<!-- 토스트 -->
<div class="position-fixed bottom-0 end-0 p-3" style="z-index:2000">
  <div id="toast" class="toast align-items-center text-bg-dark border-0" role="alert">
    <div class="d-flex"><div class="toast-body" id="toastMsg"></div>
      <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button></div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://unpkg.com/tabulator-tables@6.2.5/dist/js/tabulator.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 매장 재고조사 (ai601)
 *   - 제품 검색(제품코드·제조회사·브랜드·제품명) → 선택 → 실사 수량 입력 → REAL_JEGO 저장
 *   - 같은 제품을 다시 입력하면 한 건 더 저장, 실사 수량 = 합계 (진열대·창고 따로 세도 됨)
 *   - 잘못 넣은 수량은 선택한 제품의 입력 내역에서 × 로 삭제
 *   - 마감 : 차이 → MC27(실사) 전표, 재고 반영, 입력 삭제
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai601';
  var all = [];            // 조사 목록
  var found = [];          // 검색 결과
  var sel = null;          // 선택한 제품
  var tab = 'all';
  var table = null, toast = null, closeModal = null;
  var mstTable = null, dtlTable = null, adjLoaded = false, curAdj = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function n(v) { return Number(v || 0).toLocaleString('ko-KR'); }
  function sn(v) { v = Number(v || 0); return (v > 0 ? '+' : '') + v.toLocaleString('ko-KR'); }
  function tLabel(s) { s = String(s || ''); return s.length >= 12 ? s.substr(8, 2) + ':' + s.substr(10, 2) : s; }
  function dtLabel(s) { s = String(s || ''); return s.length >= 12 ? s.substr(4, 2) + '/' + s.substr(6, 2) + ' ' + tLabel(s) : s; }
  function msg(t) { $('toastMsg').textContent = t; toast.show(); }
  function fail(e) { alert(e.message || e); }

  function api(path, params, body) {
    if (window.ReportMock) return window.ReportMock.handle(path, params, body);   // 미리보기용
    var url = API + path + (params ? '?' + new URLSearchParams(params) : '');
    var opt = body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {};
    return fetch(url, opt)
      .then(function (r) {
        if (!r.ok) throw new Error('서버 요청 실패 (' + r.status + ') : ' + url);
        return r.json();
      })
      .then(function (res) {
        if (!res.ok) throw new Error(res.msg || '처리 중 오류가 발생했습니다.');
        return res.data;
      });
  }

  /** 행 계산 : 차이·차이금액·상태 */
  function calc(r) {
    var done = r.realqty !== null && r.realqty !== undefined;
    r.diff = done ? r.realqty - r.jego : null;
    r.diffamt = done ? r.diff * r.inprice : null;
    r.status = !done ? 'none' : r.diff === 0 ? 'ok' : r.diff < 0 ? 'short' : 'over';
    return r;
  }
  var ST = { none: ['미조사', 'st-none'], ok: ['일치', 'st-ok'], short: ['부족', 'st-short'], over: ['초과', 'st-over'] };
  function badge(s) { return '<span class="st ' + ST[s][1] + '">' + ST[s][0] + '</span>'; }

  // ================= 조사 목록 =================
  function buildTable() {
    function numF(c) { var v = c.getValue(); return v === null || v === undefined ? '' : n(v); }
    function diffF(c) {
      var v = c.getValue(); if (v === null || v === undefined) return '';
      return v === 0 ? '0' : '<span class="' + (v < 0 ? 'neg' : 'posv') + '">' + sn(v) + '</span>';
    }
    function sumF(field) {
      return function (values, data) {
        return data.reduce(function (s, r) { return s + Number(r[field] || 0); }, 0);
      };
    }
    table = new Tabulator('#listTable', {
      layout: 'fitColumns',
      height: 500,
      index: 'jepmkey',
      placeholder: '조사할 제품이 없어요.',
      rowFormatter: function (row) { row.getElement().classList.toggle('row-sel', !!sel && row.getData().jepmkey === sel.jepmkey); },
      columns: [
        { title: '제조회사', field: 'makecust', minWidth: 100, bottomCalc: function () { return '합계'; } },
        { title: '브랜드', field: 'brand', minWidth: 90 },
        { title: '제품명', field: 'jepmnm', minWidth: 180,
          formatter: function (c) { var d = c.getData(); return '<b>' + esc(d.jepmnm) + '</b> <span class="code">' + esc(d.jepmcd) + '</span>'; } },
        { title: '입고가', field: 'inprice', width: 85, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number', formatter: numF },
        { title: '전산재고', field: 'jego', width: 85, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number', formatter: numF,
          bottomCalc: sumF('jego'), bottomCalcFormatter: numF },
        { title: '실사 수량', field: 'realqty', width: 90, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
          formatter: function (c) { var v = c.getValue(); return v === null || v === undefined ? '<span class="text-muted">-</span>' : '<b>' + n(v) + '</b>'; },
          bottomCalc: sumF('realqty'), bottomCalcFormatter: numF },
        { title: '차이', field: 'diff', width: 75, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number', formatter: diffF,
          bottomCalc: sumF('diff'), bottomCalcFormatter: diffF },
        { title: '차이 금액', field: 'diffamt', width: 105, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number', formatter: diffF,
          bottomCalc: sumF('diffamt'), bottomCalcFormatter: diffF },
        { title: '입력', field: 'cnt', width: 58, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
          formatter: function (c) { return c.getValue() ? c.getValue() + '건' : ''; } },
        { title: '상태', field: 'status', width: 72, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { return badge(c.getValue()); } }
      ]
    });
    table.on('rowClick', function (e, row) { select(row.getData(), true); });
  }

  function loadList() {
    return api('/list').then(function (d) {
      all = (d.rows || []).map(calc);
      $('listHint').textContent = d.more ? '제품이 많아 앞쪽 ' + all.length + '건만 표시' : '전산재고가 있는 제품 + 조사한 제품';
      draw();
    });
  }

  function filtered() {
    var mk = $('lMaker').value.trim().toLowerCase(), q = $('lName').value.trim().toLowerCase();
    return all.filter(function (r) {
      if (mk && (r.makecust || '').toLowerCase().indexOf(mk) < 0) return false;
      if (q && (r.jepmnm || '').toLowerCase().indexOf(q) < 0 && (r.jepmcd || '').toLowerCase().indexOf(q) < 0) return false;
      return true;
    });
  }

  function draw() {
    var base = filtered();
    var cnt = { all: base.length, none: 0, diff: 0, ok: 0 };
    base.forEach(function (r) { if (r.status === 'none') cnt.none++; else if (r.status === 'ok') cnt.ok++; else cnt.diff++; });
    $('tAll').textContent = cnt.all; $('tNone').textContent = cnt.none; $('tDiff').textContent = cnt.diff; $('tOk').textContent = cnt.ok;
    var list = base.filter(function (r) {
      return tab === 'all' || (tab === 'none' ? r.status === 'none' : tab === 'ok' ? r.status === 'ok' : (r.status === 'short' || r.status === 'over'));
    });
    table.setData(list);
    summary();
  }

  function summary() {
    var done = 0, diff = 0, amt = 0;
    all.forEach(function (r) { if (r.status !== 'none') { done++; if (r.diff) { diff++; amt += r.diffamt; } } });
    var rate = all.length ? Math.floor(done * 100 / all.length) : 0;
    $('sTotal').textContent = n(all.length);
    $('sDone').textContent = n(done);
    $('sDiff').textContent = n(diff);
    $('sAmt').innerHTML = amt ? '<span class="' + (amt < 0 ? 'neg' : 'posv') + '">' + sn(amt) + '</span>' : '0';
    $('sRate').textContent = rate + '%';
    $('sBar').style.width = rate + '%';
  }

  /** 저장·삭제 후 그 제품 한 줄만 목록에 반영 */
  function upsert(p) {
    calc(p);
    var i = -1;
    all.some(function (r, k) { if (r.jepmkey === p.jepmkey) { i = k; return true; } return false; });
    if (i >= 0) {
      if (p.status === 'none' && !p.jego) all.splice(i, 1); else all[i] = p;
    } else if (p.status !== 'none' || p.jego) {
      all.push(p);
      all.sort(function (a, b) { return (a.makecust + a.brand + a.jepmnm).localeCompare(b.makecust + b.brand + b.jepmnm); });
    }
    found.forEach(function (f, k) { if (f.jepmkey === p.jepmkey) found[k] = p; });
    draw();
    drawFound();
  }

  // ================= 제품 검색 =================
  function find() {
    var q = { jepmcd: $('qCode').value.trim(), makecust: $('qMaker').value.trim(), brand: $('qBrand').value.trim(), jepmnm: $('qName').value.trim() };
    if (!q.jepmcd && !q.makecust && !q.brand && !q.jepmnm) { alert('제품코드·제조회사·브랜드·제품명 중 하나는 입력하세요.'); $('qName').focus(); return; }
    $('btnFind').disabled = true;
    api('/products', q)
      .then(function (d) {
        found = (d.rows || []).map(calc);
        $('fCnt').textContent = found.length + (d.more ? '+' : '');
        drawFound();
        if (found.length === 1) select(found[0]);          // 한 건이면 바로 선택 → 수량 칸으로
        else if (!found.length) { select(null); $('qCode').select(); }
      })
      .catch(fail)
      .then(function () { $('btnFind').disabled = false; });
  }

  function drawFound() {
    var el = $('found');
    if (!found.length) { el.innerHTML = '<div class="empty">검색된 제품이 없어요.</div>'; return; }
    el.innerHTML = found.map(function (f, i) {
      var st = f.status === 'none' ? badge('none') : '실사 <b style="color:#1f2733">' + n(f.realqty) + '</b>';
      return '<button type="button" class="it' + (sel && sel.jepmkey === f.jepmkey ? ' on' : '') + '" data-i="' + i + '">' +
             '<span style="min-width:0"><span class="nm">' + esc(f.jepmnm) + '</span>' +
             '<span class="sb">' + esc(f.makecust) + (f.brand ? ' · ' + esc(f.brand) : '') + ' · ' + esc(f.jepmcd) + '</span></span>' +
             '<span class="rt">전산 <b style="color:#1f2733">' + n(f.jego) + '</b><br>' + st + '</span></button>';
    }).join('');
  }

  // ================= 선택 · 수량 입력 =================
  function select(p, fromList) {
    sel = p;
    drawFound();
    table.getRows().forEach(function (r) { r.reformat(); });
    var box = $('selBox');
    if (!p) { box.className = 'selbox none'; box.textContent = '제품을 선택하면 여기서 수량을 입력합니다.'; return; }
    box.className = 'selbox';
    var done = p.status !== 'none';
    box.innerHTML =
      '<div class="d-flex justify-content-between"><span style="font-size:11px;font-weight:700;color:var(--blue)">선택한 제품</span>' + badge(p.status) + '</div>' +
      '<div class="nm">' + esc(p.jepmnm) + '</div>' +
      '<div class="sb">' + esc(p.makecust) + (p.brand ? ' · ' + esc(p.brand) : '') + ' · ' + esc(p.jepmcd) + ' · 입고가 ' + n(p.inprice) + '</div>' +
      '<div class="nums">' +
        '<div><div class="lb">전산재고</div><div class="v">' + n(p.jego) + '</div></div>' +
        '<div><div class="lb">실사 합계</div><div class="v">' + (done ? n(p.realqty) : '-') + '</div></div>' +
        '<div><div class="lb">차이</div><div class="v ' + (p.diff < 0 ? 'neg' : p.diff > 0 ? 'posv' : '') + '">' + (done ? sn(p.diff) : '-') + '</div></div>' +
      '</div>' +
      '<label class="form-label mb-0" for="eQty" style="font-weight:700;color:var(--navy)">' + (done ? '추가할 수량 (합계에 더해짐)' : '실사 수량') + '</label>' +
      '<div class="d-flex gap-2"><input type="text" class="form-control" id="eQty" inputmode="numeric" autocomplete="off" maxlength="6">' +
      '<button type="button" class="btn" id="btnInput">수량 입력</button></div>' +
      '<div class="hint" id="eQtyHint">Enter = 입력 · 0 도 입력 가능 (재고 없음 확인)</div>' +
      '<div class="ent" id="ent"></div>';
    var q = $('eQty');
    q.addEventListener('input', function () { this.value = this.value.replace(/\D/g, ''); preview(); });
    q.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); input(); } });
    $('btnInput').onclick = input;
    loadEntries(p);
    if (fromList) box.scrollIntoView({ block: 'nearest' });
    q.focus();
  }

  function preview() {
    if (!sel) return;
    var v = $('eQty').value, h = $('eQtyHint');
    if (v === '') { h.textContent = 'Enter = 입력 · 0 도 입력 가능 (재고 없음 확인)'; return; }
    var tot = (sel.realqty || 0) + Number(v), d = tot - sel.jego;
    h.innerHTML = '입력하면 실사 <b>' + n(tot) + '</b> · 차이 <b class="' + (d < 0 ? 'neg' : d > 0 ? 'posv' : '') + '">' + sn(d) + '</b> · ' + sn(d * sel.inprice) + '원';
  }

  function loadEntries(p) {
    if (!p.cnt) { $('ent').innerHTML = ''; return; }
    api('/entries', { jepmkey: p.jepmkey }).then(function (list) {
      if (!sel || sel.jepmkey !== p.jepmkey) return;
      $('ent').innerHTML = '<div style="border:0;font-weight:700;color:var(--muted)">입력 내역 ' + list.length + '건</div>' +
        list.map(function (e) {
          return '<div><span>' + dtLabel(e.prdatetime) + '</span><span><b>' + n(e.qty) + '</b>' +
                 '<button type="button" class="x" title="이 입력 삭제" data-dt="' + esc(e.prdatetime) + '">✕</button></span></div>';
        }).join('');
    }).catch(fail);
  }

  function input() {
    if (!sel) return;
    var v = $('eQty').value.trim();
    if (!/^\d+$/.test(v)) { alert('수량을 숫자로 입력하세요.'); $('eQty').focus(); return; }
    if (Number(v) >= 1000 && !confirm(sel.jepmnm + '\n수량 ' + n(v) + ' 개가 맞나요?')) { $('eQty').select(); return; }
    var name = sel.jepmnm;
    $('btnInput').disabled = true;
    api('/save', null, { jepmkey: sel.jepmkey, qty: v })
      .then(function (p) {
        msg(name + ' ' + n(v) + '개 입력 → 실사 ' + n(p.realqty));
        upsert(p);
        select(p);
        loadRecent();
        // 다음 제품 : 제품코드 칸으로 (바코드 바로 찍을 수 있게)
        $('qCode').value = '';
        $('qCode').focus();
      })
      .catch(function (e) { fail(e); var b = $('btnInput'); if (b) b.disabled = false; });
  }

  function delEntry(dt) {
    if (!sel) return;
    if (!confirm(sel.jepmnm + '\n' + dtLabel(dt) + ' 에 입력한 수량을 삭제할까요?')) return;
    api('/delete', null, { jepmkey: sel.jepmkey, prdatetime: dt })
      .then(function (p) { msg('입력을 삭제했어요.'); upsert(p); select(p); loadRecent(); })
      .catch(fail);
  }

  function loadRecent() {
    return api('/recent').then(function (list) {
      $('recentHint').textContent = list.length ? '최근 ' + list.length + '건' : '';
      $('recent').innerHTML = list.length ? list.map(function (e) {
        return '<div><span>' + esc(e.jepmnm || e.jepmcd) + '</span><span class="t">' + tLabel(e.prdatetime) + ' · <b style="color:#1f2733">' + n(e.qty) + '</b></span></div>';
      }).join('') : '<div class="hint" style="border:0">아직 입력한 수량이 없어요.</div>';
    });
  }

  // ================= 마감 =================
  function openClose() {
    var done = 0, lines = 0, qty = 0, amt = 0, none = 0;
    all.forEach(function (r) {
      if (r.status === 'none') { none++; return; }
      done++; if (r.diff) { lines++; qty += r.diff; amt += r.diffamt; }
    });
    if (!done) { alert('입력된 실사 수량이 없습니다.'); return; }
    $('cDone').textContent = n(done) + ' 개';
    $('cLines').textContent = n(lines) + ' 개';
    $('cQty').innerHTML = '<span class="' + (qty < 0 ? 'neg' : qty > 0 ? 'posv' : '') + '">' + sn(qty) + '</span>';
    $('cAmt').innerHTML = '<span class="' + (amt < 0 ? 'neg' : amt > 0 ? 'posv' : '') + '">' + sn(amt) + '</span>';
    $('cNone').textContent = n(none) + ' 개 (재고 그대로)';
    $('cRemk').value = '';
    closeModal.show();
    setTimeout(function () { $('cRemk').focus(); }, 300);
  }

  function doClose() {
    $('btnCloseGo').disabled = true;
    api('/close', null, { remk: $('cRemk').value.trim() })
      .then(function (r) {
        closeModal.hide();
        alert('재고조사를 마감했습니다.\n\n조정 전표 ' + r.cjpno + ' (상세 ' + n(r.lines) + '건)' +
              '\n조사 제품 ' + n(r.items) + '개 · 차이 ' + n(r.diffs) + '개 · 재고 변경 ' + n(r.updated) + '개' +
              '\n재고 증감 ' + sn(-r.qty) + ' · 금액 ' + sn(-r.amt));
        select(null); found = []; drawFound(); $('fCnt').textContent = '0'; adjLoaded = false;
        return Promise.all([loadList(), loadRecent()]);
      })
      .catch(fail)
      .then(function () { $('btnCloseGo').disabled = false; });
  }

  // ================= 재고 초기화 =================
  function resetStock() {
    var cnt = 0, qty = 0, amt = 0;
    all.forEach(function (r) { if (r.jego) { cnt++; qty += r.jego; amt += r.jego * r.inprice; } });
    if (!confirm('[재고 초기화]\n\n전산재고가 있는 제품 ' + n(cnt) + '개의 재고를 모두 0 으로 만듭니다.\n' +
                 '재고 수량 ' + n(qty) + ' · 입고가 금액 ' + n(amt) + '\n\n재고조정 전표(비고 "재고초기화")가 남습니다.\n계속할까요?')) return;
    if (prompt('되돌릴 수 없습니다. 계속하려면  초기화  라고 입력하세요.') !== '초기화') { msg('재고 초기화를 취소했어요.'); return; }
    $('btnReset').disabled = true;
    api('/reset', null, {})
      .then(function (r) {
        alert('재고를 초기화했습니다.\n\n조정 전표 ' + r.cjpno + ' (상세 ' + n(r.lines) + '건)\n재고 증감 ' + sn(-r.qty) + ' · 금액 ' + sn(-r.amt));
        select(null); found = []; drawFound(); $('fCnt').textContent = '0'; adjLoaded = false;
        return Promise.all([loadList(), loadRecent()]);
      })
      .catch(fail)
      .then(function () { $('btnReset').disabled = false; });
  }

  // ================= 재고조정 조회 =================
  function ymd(d) { var p = function (x) { return (x < 10 ? '0' : '') + x; }; return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); }
  function dLabel(s) { s = String(s || '').replace(/-/g, '').substr(0, 8); return s.length === 8 ? s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2) : s; }
  function setRange(k) {
    var t = new Date(), f = new Date();
    if (k === 'm') f = new Date(t.getFullYear(), t.getMonth(), 1); else f.setDate(t.getDate() - Number(k));
    $('aFrom').value = ymd(f); $('aTo').value = ymd(t);
  }

  function buildAdjTables() {
    function numF(c) { return n(c.getValue()); }
    // MC27 수량 · 금액 : + 재고 감소(빨강), − 재고 증가(파랑)
    function signF(c) { var v = Number(c.getValue() || 0); return v === 0 ? '0' : '<span class="' + (v > 0 ? 'neg' : 'posv') + '">' + n(v) + '</span>'; }
    function sumF(field) { return function (values, data) { return data.reduce(function (s, r) { return s + Number(r[field] || 0); }, 0); }; }
    mstTable = new Tabulator('#mstTable', {
      layout: 'fitColumns', height: 460, selectableRows: 1, index: 'mc27key',
      placeholder: '기간 안에 재고조정 전표가 없어요.',
      columns: [
        { title: '처리일', field: 'chdate', width: 105, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { return dLabel(c.getValue()); }, bottomCalc: function () { return '합계'; } },
        { title: '금액', field: 'amt', width: 120, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number', formatter: signF,
          bottomCalc: sumF('amt'), bottomCalcFormatter: signF },
        { title: '비고', field: 'remk', minWidth: 140, tooltip: true },
        { title: '등록일', field: 'prdate', width: 105, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { return dLabel(c.getValue()); } }
      ]
    });
    mstTable.on('rowClick', function (e, row) { row.select(); loadDtl(row.getData()); });
    dtlTable = new Tabulator('#dtlTable', {
      layout: 'fitColumns', height: 460,
      placeholder: '왼쪽에서 전표를 선택하세요.',
      columns: [
        { title: '제품코드', field: 'jepmcd', width: 150, bottomCalc: function () { return '합계'; } },
        { title: '제품명', field: 'jepmnm', minWidth: 180 },
        { title: '수량', field: 'qty', width: 90, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number', formatter: signF,
          bottomCalc: sumF('qty'), bottomCalcFormatter: signF }
      ]
    });
  }

  function adjSearch() {
    var f = $('aFrom').value, t = $('aTo').value;
    if (!f || !t) { alert('기간을 입력하세요.'); return; }
    if (f > t) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('ai601AdjSearch').disabled = true;
    api('/adjList', { from: f, to: t })
      .then(function (list) {
        adjLoaded = true;
        mstTable.setData(list);
        $('aCnt').textContent = list.length;
        dtlTable.setData([]); $('dtlTitle').textContent = '전표 상세'; $('dtlSub').textContent = ''; curAdj = null; $('btnAdjDel').disabled = true;
        if (list.length) { var r = mstTable.getRows()[0]; r.select(); loadDtl(r.getData()); }
      })
      .catch(fail)
      .then(function () { $('ai601AdjSearch').disabled = false; });
  }

  function loadDtl(m) {
    curAdj = m; $('btnAdjDel').disabled = false;
    $('dtlTitle').textContent = '전표 상세 · ' + dLabel(m.chdate) + (m.remk ? ' · ' + m.remk : '');
    $('dtlSub').textContent = '전표 ' + m.cjpno;
    api('/adjDtl', { mc27key: m.mc27key })
      .then(function (list) { dtlTable.setData(list); $('dtlSub').textContent = '전표 ' + m.cjpno + ' · ' + list.length + '건'; })
      .catch(fail);
  }

  /** 선택한 재고조정 전표 삭제 — 상세 수량만큼 재고에 더해 되돌림 */
  function adjDelete() {
    var m = curAdj; if (!m) return;
    var rows = dtlTable.getData(), qty = rows.reduce(function (s, r) { return s + Number(r.qty || 0); }, 0);
    if (!confirm('[재고조정 전표 삭제]\n\n' + dLabel(m.chdate) + (m.remk ? ' · ' + m.remk : '') + '\n전표 ' + m.cjpno + ' · 상세 ' + rows.length + '건' +
                 '\n\n상세 수량만큼 재고에 더해 되돌립니다. (재고 증감 ' + sn(qty) + ')\n삭제하면 되돌릴 수 없습니다. 계속할까요?')) return;
    $('btnAdjDel').disabled = true;
    api('/adjDelete', null, { mc27key: m.mc27key })
      .then(function (r) {
        msg('전표를 삭제했어요. 상세 ' + r.dtl + '건 · 재고 되돌린 제품 ' + r.restored + '개');
        adjSearch();
        return loadList();
      })
      .catch(function (e) { fail(e); $('btnAdjDel').disabled = false; });
  }

  function showPane(id) {
    Array.prototype.forEach.call(document.querySelectorAll('.page-tabs .nav-link'), function (b) {
      var on = b.getAttribute('data-pane') === id;
      b.classList.toggle('active', on);
      $(b.getAttribute('data-pane')).classList.toggle('d-none', !on);
    });
    if (id === 'paneAdj') {
      fitAdj(); mstTable.redraw(true); dtlTable.redraw(true);
      if (!adjLoaded) adjSearch();
    } else { fit(); table.redraw(true); }
  }

  function fitAdj() {
    var el = $('mstTable');
    if (!mstTable || !el.offsetParent) return;
    var h = Math.max(320, window.innerHeight - (el.getBoundingClientRect().top + window.scrollY) - 30);
    mstTable.setHeight(h); dtlTable.setHeight(h);
  }

  // ================= 엑셀 =================
  function excel() {
    var rows = table.getData().map(function (r) {
      return { '제조회사': r.makecust, '브랜드': r.brand, '제품코드': r.jepmcd, '제품명': r.jepmnm, '입고가': r.inprice,
               '전산재고': r.jego, '실사수량': r.realqty === null ? '' : r.realqty, '차이': r.diff === null ? '' : r.diff,
               '차이금액': r.diffamt === null ? '' : r.diffamt, '상태': ST[r.status][0] };
    });
    var ws = XLSX.utils.json_to_sheet(rows);
    ws['!cols'] = [{ wch: 14 }, { wch: 12 }, { wch: 15 }, { wch: 30 }, { wch: 9 }, { wch: 9 }, { wch: 9 }, { wch: 8 }, { wch: 11 }, { wch: 7 }];
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, '재고조사');
    var d = new Date(), p = function (x) { return (x < 10 ? '0' : '') + x; };
    XLSX.writeFile(wb, '재고조사_' + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + '.xlsx');
  }

  // ================= 화면 크기 =================
  function fit() {
    var el = $('listTable');
    if (!table || !el.offsetParent) return;
    var top = el.getBoundingClientRect().top + window.scrollY;
    table.setHeight(Math.max(360, window.innerHeight - top - 30));
  }

  // ================= 이벤트 =================
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    toast = new bootstrap.Toast($('toast'), { delay: 2500 });
    closeModal = new bootstrap.Modal($('closeModal'));
    buildTable();
    buildAdjTables();
    setRange(30);

    ['qCode', 'qMaker', 'qBrand', 'qName'].forEach(function (id) {
      $(id).addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); find(); } });
    });
    $('btnFind').onclick = find;
    $('btnFindClear').onclick = function () {
      ['qCode', 'qMaker', 'qBrand', 'qName'].forEach(function (id) { $(id).value = ''; });
      found = []; $('fCnt').textContent = '0';
      $('found').innerHTML = '<div class="empty">제품코드·제조회사·브랜드·제품명으로 검색하세요.</div>';
      select(null); $('qCode').focus();
    };
    $('found').addEventListener('click', function (e) {
      var b = e.target.closest('.it'); if (b) select(found[Number(b.getAttribute('data-i'))]);
    });
    $('selBox').addEventListener('click', function (e) {
      var x = e.target.closest('.x'); if (x) delEntry(x.getAttribute('data-dt'));
    });
    Array.prototype.forEach.call($('tabs').querySelectorAll('.btn'), function (b) {
      b.onclick = function () {
        tab = b.getAttribute('data-tab');
        Array.prototype.forEach.call($('tabs').querySelectorAll('.btn'), function (x) { x.classList.toggle('active', x === b); });
        draw();
      };
    });
    $('lMaker').addEventListener('input', draw);
    $('lName').addEventListener('input', draw);
    $('btnReload').onclick = function () { Promise.all([loadList(), loadRecent()]).catch(fail); };
    $('btnExcel').onclick = excel;
    $('btnClose').onclick = openClose;
    $('btnReset').onclick = resetStock;
    $('btnCloseGo').onclick = doClose;
    window.addEventListener('resize', function () { fit(); fitAdj(); });
    Array.prototype.forEach.call(document.querySelectorAll('.page-tabs .nav-link'), function (b) {
      b.onclick = function () { showPane(b.getAttribute('data-pane')); };
    });
    Array.prototype.forEach.call(document.querySelectorAll('#paneAdj [data-days]'), function (b) {
      b.onclick = function () { setRange(b.getAttribute('data-days')); adjSearch(); };
    });
    $('ai601AdjSearch').onclick = adjSearch;
    $('btnAdjDel').onclick = adjDelete;

    table.on('tableBuilt', function () {
      fit();
      Promise.all([loadList(), loadRecent()]).catch(fail);
      $('qCode').focus();
    });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
