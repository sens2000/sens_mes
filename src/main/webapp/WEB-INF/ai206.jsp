<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>피부예약</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 피부예약(ai206) ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --slot-h: 28px;
    --st-resv: #4a7bd0;   --st-resv-bg: #eaf1fc;
    --st-conf: #2f9e6e;   --st-conf-bg: #e6f6ee;
    --st-done: #7a8494;   --st-done-bg: #eef0f3;
    --st-noshow: #d9534f; --st-noshow-bg: #fcecec;
    --st-cancel: #b0b6c0; --st-cancel-bg: #f5f6f8;
  }
  .ai206 { font-size: 14px; flex: 1 1 0; min-width: 0; }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 12px 16px; display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
  .card-head h5 { margin: 0; font-size: 16px; font-weight: 700; }
  .card-head .summary { margin-left: auto; font-size: 13px; display: flex; gap: 14px; }
  .card-head .summary b { color: #ffd66b; }

  .toolbar { display: flex; align-items: center; gap: 8px; padding: 12px 16px; border-bottom: 1px solid var(--line); flex-wrap: wrap; }
  .toolbar .date-label { font-weight: 700; font-size: 16px; min-width: 150px; text-align: center; }
  .toolbar .date-label.is-today { color: var(--navy); }

  .nav-tabs .nav-link { color: #555; }
  .nav-tabs .nav-link.active { color: var(--navy); font-weight: 700; }

  /* ---------- 예약표 ---------- */
  .tt-wrap { overflow: auto; }
  .tt { display: grid; min-width: 480px; }
  .tt-head { position: sticky; top: 0; z-index: 3; background: var(--navy-soft); border-bottom: 2px solid #c9d3e3;
             padding: 8px 6px; text-align: center; font-weight: 700; }
  .tt-head small { display: block; font-weight: 400; color: #667; font-size: 12px; }
  .tt-time { border-right: 1px solid var(--line); }
  .tt-time div { height: var(--slot-h); font-size: 12px; color: #889; text-align: right; padding-right: 6px; transform: translateY(-7px); }
  .tt-col { position: relative; border-right: 1px solid var(--line); cursor: pointer;
            background-image: repeating-linear-gradient(to bottom, transparent 0, transparent calc(var(--slot-h) - 1px), #eef1f5 calc(var(--slot-h) - 1px), #eef1f5 var(--slot-h)),
                              repeating-linear-gradient(to bottom, transparent 0, transparent calc(var(--slot-h) * 2 - 1px), #dde2ea calc(var(--slot-h) * 2 - 1px), #dde2ea calc(var(--slot-h) * 2)); }
  .tt-col:hover { background-color: #fafcff; }
  .tt-hover { position: absolute; left: 3px; right: 3px; height: var(--slot-h); border: 1px dashed #9db3d8; border-radius: 6px;
              color: #6f86b0; font-size: 12px; display: none; align-items: center; justify-content: center; pointer-events: none; }
  .tt-col:hover .tt-hover { display: flex; }

  .rsv { position: absolute; left: 3px; right: 3px; border-radius: 6px; padding: 3px 7px; overflow: hidden; z-index: 2;
         border-left: 4px solid; font-size: 12px; line-height: 1.35; cursor: pointer; box-shadow: 0 1px 2px rgba(0,0,0,.08); }
  .rsv:hover { filter: brightness(.97); box-shadow: 0 2px 6px rgba(0,0,0,.15); }
  .rsv .nm { font-weight: 700; font-size: 13px; }
  .rsv .tm { color: #556; }
  .rsv .alim { position: absolute; top: 3px; right: 5px; font-size: 10px; font-weight: 700; color: #6b5800; background: #fee500; border-radius: 3px; padding: 0 3px; }
  .now-line { position: absolute; left: 0; right: 0; height: 2px; background: #e5484d; z-index: 4; pointer-events: none; }

  .st-RESV   { color: var(--st-resv);   background: var(--st-resv-bg);   border-color: var(--st-resv); }
  .st-CONF   { color: var(--st-conf);   background: var(--st-conf-bg);   border-color: var(--st-conf); }
  .st-DONE   { color: var(--st-done);   background: var(--st-done-bg);   border-color: var(--st-done); }
  .st-NOSHOW { color: var(--st-noshow); background: var(--st-noshow-bg); border-color: var(--st-noshow); }
  .st-CANCEL { color: var(--st-cancel); background: var(--st-cancel-bg); border-color: var(--st-cancel); text-decoration: line-through; }
  .rsv .nm, .rsv .mn { color: #222; }

  .badge-st { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 12px; font-weight: 700; border: 1px solid; }
  .legend { display: flex; gap: 10px; padding: 10px 16px; border-top: 1px solid var(--line); font-size: 12px; flex-wrap: wrap; }

  /* ---------- 목록 ---------- */
  .tabulator { font-size: 13px; border: none; max-width: 100%; }
  .tabulator .tabulator-cell { padding: 8px 6px; }
  .tabulator .tabulator-col .tabulator-col-content { padding: 8px 6px; }
  .tabulator .tabulator-header .tabulator-col { background: var(--navy-soft); }
  .memo-cell { white-space: pre-line; color: #556; }
  .act-btn { padding: 1px 7px; font-size: 12px; margin-right: 2px; }

  /* ---------- 모달 ---------- */
  .modal-header { background: var(--navy); color: #fff; }
  .modal-header .btn-close { filter: invert(1); }
  .cust-result { position: absolute; z-index: 10; left: 0; right: 0; top: 100%; max-height: 220px; overflow-y: auto;
                 background: #fff; border: 1px solid #ccd; border-radius: 6px; box-shadow: 0 4px 12px rgba(0,0,0,.12); }
  .cust-result button { display: flex; justify-content: space-between; width: 100%; border: 0; background: none; padding: 7px 10px; text-align: left; }
  .cust-result button:hover { background: var(--navy-soft); }
  .form-label { font-weight: 600; font-size: 13px; margin-bottom: 3px; width: 100%; }
  .byte-cnt { font-size: 11px; color: #889; float: right; font-weight: 400; }
  .byte-cnt.over { color: #d9534f; font-weight: 700; }
  .done-box { background: #f6f8fa; border: 1px solid var(--line); border-radius: 8px; padding: 12px; }
  .mem-box { background: var(--navy-soft); border-radius: 6px; padding: 7px 10px; font-size: 13px; min-height: 34px; }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 ai206">
  <div class="card-box">
    <div class="card-head">
      <h5>피부예약</h5>
      <div class="summary">
        <span>전체 <b id="sumTotal">0</b>건</span>
        <span>예약 <b id="sumResv">0</b></span>
        <span>관리완료 <b id="sumDone">0</b></span>
      </div>
    </div>

    <ul class="nav nav-tabs px-3 pt-2" role="tablist">
      <li class="nav-item"><button class="nav-link active" data-bs-toggle="tab" data-bs-target="#tabTable" type="button">예약표</button></li>
      <li class="nav-item"><button class="nav-link" data-bs-toggle="tab" data-bs-target="#tabList" type="button" id="btnTabList">예약목록</button></li>
    </ul>

    <div class="tab-content">
      <!-- ===================== 예약표 ===================== -->
      <div class="tab-pane fade show active" id="tabTable">
        <div class="toolbar">
          <button class="btn btn-outline-secondary btn-sm" id="btnPrev" title="이전날">&lsaquo;</button>
          <div class="date-label" id="dateLabel"></div>
          <button class="btn btn-outline-secondary btn-sm" id="btnNext" title="다음날">&rsaquo;</button>
          <button class="btn btn-outline-secondary btn-sm" id="btnToday">오늘</button>
          <input type="date" class="form-control form-control-sm" id="datePick" style="width:150px">
          <div class="ms-auto d-flex gap-2">
            <button class="btn btn-warning btn-sm" id="btnRemind">내일 예약 안내 알림톡</button>
            <button class="btn btn-primary btn-sm" id="btnNew">+ 예약등록</button>
          </div>
        </div>
        <div class="tt-wrap"><div class="tt" id="timetable"></div></div>
        <div class="legend" id="legend"></div>
      </div>

      <!-- ===================== 예약목록 ===================== -->
      <div class="tab-pane fade" id="tabList">
        <div class="toolbar">
          <input type="date" class="form-control form-control-sm" id="fFrom" style="width:150px">
          <span>~</span>
          <input type="date" class="form-control form-control-sm" id="fTo" style="width:150px">
          <select class="form-select form-select-sm" id="fGubun" style="width:110px">
            <option value="">전체</option>
            <option value="예약">예약</option>
            <option value="관리">관리완료</option>
          </select>
          <input type="text" class="form-control form-control-sm" id="fKeyword" placeholder="회원명·연락처" style="width:170px">
          <button class="btn btn-secondary btn-sm" id="btnSearch">조회</button>
          <div class="ms-auto d-flex gap-2">
            <button class="btn btn-warning btn-sm" id="btnAlimSel">선택 예약확정 알림톡</button>
            <button class="btn btn-outline-success btn-sm" id="btnExcel">엑셀</button>
          </div>
        </div>
        <div id="listTable"></div>
      </div>
    </div>
  </div>
  </div>
</div>

<!-- ===================== 예약 등록/수정 모달 ===================== -->
<div class="modal fade" id="rsvModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered modal-lg">
    <div class="modal-content">
      <div class="modal-header py-2">
        <h6 class="modal-title" id="mTitle">예약등록</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <input type="hidden" id="mSkinKey">
        <input type="hidden" id="mMemNo">

        <div class="row g-3">
          <div class="col-md-6 position-relative">
            <label class="form-label">회원 검색 <span class="text-danger">*</span></label>
            <div class="input-group input-group-sm">
              <input type="text" class="form-control" id="mMemKw" placeholder="이름 또는 전화번호 뒷자리 + Enter">
              <button class="btn btn-outline-secondary" type="button" id="btnMemSearch">검색</button>
            </div>
            <div class="cust-result d-none" id="memResult"></div>
          </div>
          <div class="col-md-6">
            <label class="form-label">선택한 회원</label>
            <div class="mem-box" id="memBox"><span class="text-muted">회원을 검색해서 선택하세요</span></div>
          </div>

          <div class="col-md-4">
            <label class="form-label">예약일 <span class="text-danger">*</span></label>
            <input type="date" class="form-control form-control-sm" id="mDate">
          </div>
          <div class="col-md-4">
            <label class="form-label">예약시간 <span class="text-danger">*</span></label>
            <select class="form-select form-select-sm" id="mStart"></select>
          </div>
          <div class="col-md-4">
            <label class="form-label">소요시간</label>
            <select class="form-select form-select-sm" id="mDur">
              <option value="30">30분</option><option value="60">1시간</option><option value="90">1시간 30분</option>
              <option value="120">2시간</option><option value="150">2시간 30분</option><option value="180">3시간</option>
            </select>
          </div>

          <div class="col-md-4">
            <label class="form-label">시술</label>
            <select class="form-select form-select-sm" id="mMenu"></select>
          </div>
          <div class="col-md-4">
            <label class="form-label">관리사</label>
            <input type="text" class="form-control form-control-sm" id="mSkiner" maxlength="12">
          </div>
          <div class="col-md-4">
            <label class="form-label">구분</label>
            <select class="form-select form-select-sm" id="mGubun">
              <option value="예약">예약</option><option value="관리">관리완료</option>
            </select>
          </div>

          <div class="col-12">
            <label class="form-label">메모 <span class="byte-cnt" id="cntMemo">0/60</span></label>
            <input type="text" class="form-control form-control-sm" id="mMemo" placeholder="피부타입, 요청사항 등 (한글 30자)">
          </div>

          <div class="col-12 d-none" id="remkBox">
            <label class="form-label">관리내용 <span class="byte-cnt" id="cntRemk">0/60</span></label>
            <input type="text" class="form-control form-control-sm" id="mRemk" placeholder="관리한 내용 (한글 30자)">
          </div>

          <div class="col-12 d-none" id="doneBox">
            <div class="done-box row g-2 m-0">
              <div class="col-md-3">
                <label class="form-label">관리시간</label>
                <select class="form-select form-select-sm" id="mSkinTime"></select>
              </div>
            </div>
          </div>

          <div class="col-12">
            <div class="form-check">
              <input class="form-check-input" type="checkbox" id="mAlim">
              <label class="form-check-label" for="mAlim">저장 후 <b>예약확정 알림톡</b> 발송</label>
              <span class="ms-2 small text-muted" id="mAlimInfo"></span>
            </div>
          </div>
        </div>
      </div>
      <div class="modal-footer py-2">
        <button type="button" class="btn btn-outline-danger btn-sm me-auto d-none" id="btnDelete">예약취소(삭제)</button>
        <button type="button" class="btn btn-outline-success btn-sm d-none" id="btnDone">관리완료 처리</button>
        <button type="button" class="btn btn-outline-warning btn-sm d-none" id="btnUndo">예약으로 되돌리기</button>
        <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">닫기</button>
        <button type="button" class="btn btn-primary btn-sm" id="btnSave">저장</button>
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
 * 피부예약 (ai206)
 *   - 예약표(30분 슬롯 타임라인), 예약목록(Tabulator), 등록/수정 모달, 알림톡
 *   - skin_mst.gubun : '예약' → '관리'(관리완료)
 *   - 서버 응답 형식 : { ok:true, data:... } / { ok:false, msg:"..." }
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai206';
  var SLOT = 30;                                     // 슬롯 단위(분)
  var GUBUN = {                                      // DB값 → 화면 표시 / 색상 클래스
    '예약': { nm: '예약',     cls: 'RESV' },
    '관리': { nm: '관리완료', cls: 'DONE' }
  };

  var openTime = '10:00', closeTime = '21:00';
  var menus = [], dayList = [];
  var curDate = todayStr();
  var listTable = null, modal = null, toast = null;
  var $ = function (id) { return document.getElementById(id); };

  // ------------------------------------------------------------------
  // 공통 유틸
  // ------------------------------------------------------------------
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function dateStr(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function todayStr() { return dateStr(new Date()); }
  function addDays(s, n) { var d = new Date(s + 'T00:00:00'); d.setDate(d.getDate() + n); return dateStr(d); }
  function toMin(hm) { var a = hm.split(':'); return (+a[0]) * 60 + (+a[1]); }
  function toHM(m) { return pad(Math.floor(m / 60)) + ':' + pad(m % 60); }
  function nowHM() { var d = new Date(); return toHM(d.getHours() * 60 + Math.floor(d.getMinutes() / 10) * 10); }
  function slotPx() { return parseInt(getComputedStyle(document.documentElement).getPropertyValue('--slot-h'), 10) || 28; }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function weekday(s) { return '일월화수목금토'.charAt(new Date(s + 'T00:00:00').getDay()); }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
  function bytes(s) { var n = 0; for (var i = 0; i < s.length; i++) n += s.charCodeAt(i) > 127 ? 2 : 1; return n; }  // CP949 기준
  function gb(g) { return GUBUN[g] || GUBUN['예약']; }
  function msg(text) { $('toastMsg').textContent = text; toast.show(); }

  function api(path, params, body) {
    if (window.SkinMock) return window.SkinMock.handle(path, params, body);   // 미리보기용
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
  function fail(e) { alert(e.message || e); }

  // ------------------------------------------------------------------
  // 초기화
  // ------------------------------------------------------------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    modal = new bootstrap.Modal($('rsvModal'));
    toast = new bootstrap.Toast($('toast'), { delay: 2500 });

    $('legend').innerHTML = Object.keys(GUBUN).map(function (k) {
      return '<span class="badge-st st-' + GUBUN[k].cls + '">' + GUBUN[k].nm + '</span>';
    }).join('') + '<span class="ms-2 text-muted">빈 칸을 클릭하면 그 시간으로 예약등록, 예약을 클릭하면 수정·관리완료 처리</span>';

    // 예약표 툴바
    $('btnPrev').onclick  = function () { setDate(addDays(curDate, -1)); };
    $('btnNext').onclick  = function () { setDate(addDays(curDate, 1)); };
    $('btnToday').onclick = function () { setDate(todayStr()); };
    $('datePick').onchange = function () { if (this.value) setDate(this.value); };
    $('btnNew').onclick   = function () { openModal(null, { rsvDate: curDate }); };
    $('btnRemind').onclick = sendRemind;

    // 목록
    $('fFrom').value = curDate;
    $('fTo').value = addDays(curDate, 6);
    $('btnSearch').onclick = loadList;
    $('fKeyword').onkeydown = function (e) { if (e.key === 'Enter') loadList(); };
    $('btnTabList').addEventListener('shown.bs.tab', function () { if (!listTable) buildList(); else { fitLayout(); listTable.redraw(); } loadList(); });
    $('btnAlimSel').onclick = sendConfirmSelected;
    $('btnExcel').onclick = function () { if (listTable) listTable.download('xlsx', '피부예약_' + $('fFrom').value + '_' + $('fTo').value + '.xlsx', { sheetName: '피부예약' }); };

    // 모달
    $('btnSave').onclick = save;
    $('btnDelete').onclick = remove;
    $('btnDone').onclick = function () { $('mGubun').value = '관리'; toggleDone(); $('mRemk').focus(); };
    $('btnUndo').onclick = function () { undoDone($('mSkinKey').value, true); };
    $('mGubun').onchange = toggleDone;
    $('btnMemSearch').onclick = searchMember;
    $('mMemKw').onkeydown = function (e) { if (e.key === 'Enter') { e.preventDefault(); searchMember(); } };
    $('mMenu').onchange = function () { var m = menuById(this.value); if (m) $('mDur').value = String(m.durMin); };
    $('mMemo').oninput = function () { byteCount(this, 'cntMemo'); };
    $('mRemk').oninput = function () { byteCount(this, 'cntRemk'); };
    document.addEventListener('click', function (e) {
      if (!e.target.closest('#memResult') && e.target.id !== 'btnMemSearch') $('memResult').classList.add('d-none');
    });

    api('/init').then(function (d) {
      menus = d.menus || [];
      openTime = d.openTime || openTime;
      closeTime = d.closeTime || closeTime;
      fillSelects();
      fitLayout();
      setDate(curDate);
      var rt;
      window.addEventListener('resize', function () {
        clearTimeout(rt);
        rt = setTimeout(function () { fitLayout(); drawTimetable(); }, 150);
      });
      setInterval(drawNowLine, 60 * 1000);
    }).catch(fail);
  }

  function fillSelects() {
    var opts = '';
    for (var m = toMin(openTime); m < toMin(closeTime); m += SLOT) opts += '<option>' + toHM(m) + '</option>';
    $('mStart').innerHTML = opts;
    var opts10 = '';
    for (var t = toMin(openTime); t <= toMin(closeTime); t += 10) opts10 += '<option>' + toHM(t) + '</option>';
    $('mSkinTime').innerHTML = opts10;
    $('mMenu').innerHTML = '<option value="">선택</option>' + menus.map(function (m) {
      return '<option value="' + m.menuId + '">' + esc(m.menuNm) + ' (' + m.durMin + '분)</option>';
    }).join('');
  }
  function menuById(id) { return menus.filter(function (m) { return String(m.menuId) === String(id); })[0]; }

  function byteCount(el, cntId) {
    var n = bytes(el.value), c = $(cntId);
    c.textContent = n + '/60';
    c.classList.toggle('over', n > 60);
  }

  // ------------------------------------------------------------------
  // 예약표
  // ------------------------------------------------------------------
  function setDate(d) {
    curDate = d;
    $('datePick').value = d;
    $('dateLabel').textContent = d + ' (' + weekday(d) + ')';
    $('dateLabel').classList.toggle('is-today', d === todayStr());
    loadDay();
  }

  function loadDay() {
    return api('/day', { date: curDate }).then(function (list) {
      dayList = list || [];
      drawTimetable();
      drawSummary();
    }).catch(fail);
  }

  function drawSummary() {
    var r = 0, d = 0;
    dayList.forEach(function (x) { if (x.gubun === '관리') d++; else r++; });
    $('sumTotal').textContent = dayList.length;
    $('sumResv').textContent = r;
    $('sumDone').textContent = d;
  }

  // 시간이 겹치는 예약끼리 묶어서 나란히 놓을 위치(lane) 계산
  function layoutLanes(list) {
    var items = list.slice().sort(function (a, b) { return a.startTime.localeCompare(b.startTime) || a.endTime.localeCompare(b.endTime); });
    var group = [], groupEnd = '', lanes = [];
    function flush() { group.forEach(function (g) { g._lanes = lanes.length; }); group = []; lanes = []; }
    items.forEach(function (x) {
      if (group.length && x.startTime >= groupEnd) flush();
      var li = 0;
      while (li < lanes.length && lanes[li] > x.startTime) li++;
      lanes[li] = x.endTime;
      x._lane = li;
      group.push(x);
      if (group.length === 1 || x.endTime > groupEnd) groupEnd = x.endTime;
    });
    flush();
    return items;
  }

  // 화면 높이에 맞춰 30분 칸 높이 계산 (20~40px), 목록 높이도 같이 조정
  function fitLayout() {
    var slots = (toMin(closeTime) - toMin(openTime)) / SLOT;
    var wrap = $('timetable').parentElement;
    var top = wrap.getBoundingClientRect().top + window.pageYOffset;
    var avail = window.innerHeight - top - $('legend').offsetHeight - 62 - 40;   // 62 = 날짜 헤더, 40 = 아래 여백
    var px = Math.max(20, Math.min(40, Math.floor(avail / slots)));
    document.documentElement.style.setProperty('--slot-h', px + 'px');
    if (listTable && listTable.initialized && $('listTable').offsetParent) listTable.setHeight(listHeight());
  }

  function listHeight() {
    var lt = $('listTable').getBoundingClientRect().top + window.pageYOffset;
    return Math.max(300, window.innerHeight - lt - 40) + 'px';
  }

  function drawTimetable() {
    var start = toMin(openTime), end = toMin(closeTime);
    var slots = (end - start) / SLOT, px = slotPx();
    var tt = $('timetable');
    tt.style.gridTemplateColumns = '56px 1fr';

    var html = '<div class="tt-head"></div><div class="tt-head">' + esc(curDate) + ' (' + weekday(curDate) + ') 예약<small>' + dayList.length + '건</small></div>';

    html += '<div class="tt-time" style="padding-top:7px">';
    for (var i = 0; i < slots; i++) html += '<div>' + (i % 2 === 0 ? toHM(start + i * SLOT) : '') + '</div>';
    html += '</div>';

    html += '<div class="tt-col" style="height:' + (slots * px) + 'px"><div class="tt-hover"></div>';
    layoutLanes(dayList).forEach(function (x) {
      if (!x.startTime) return;
      var top = (toMin(x.startTime) - start) / SLOT * px;
      var h = (toMin(x.endTime) - toMin(x.startTime)) / SLOT * px - 2;
      var w = 100 / x._lanes;
      var short = h < px * 2 - 2;
      var g = gb(x.gubun);
      var sub = (x.menuNm || '') + (x.skiner ? ' · ' + x.skiner : '');
      html += '<div class="rsv st-' + g.cls + '" data-key="' + esc(x.skinKey) + '"'
           + ' style="top:' + top + 'px;height:' + h + 'px;left:calc(' + (w * x._lane) + '% + 3px);width:calc(' + w + '% - 6px);right:auto"'
           + ' title="' + esc(x.startTime + '~' + x.endTime + ' ' + x.custNm + ' ' + sub + (x.memo ? '\n' + x.memo : '') + (x.remk ? '\n[관리] ' + x.remk : '')) + '">'
           + (x.alimYn === 'Y' ? '<span class="alim">톡</span>' : '')
           + '<div><span class="nm">' + esc(x.custNm || x.memNo) + '</span>'
           + (short ? ' <span class="mn">' + esc(sub) + '</span>' : '') + '</div>'
           + (short ? '' : '<div class="mn">' + esc(sub) + '</div><div class="tm">' + x.startTime + '~' + x.endTime + ' · ' + g.nm + '</div>')
           + '</div>';
    });
    html += '</div>';
    tt.innerHTML = html;

    // 빈칸 클릭 → 신규, 블록 클릭 → 수정
    tt.querySelectorAll('.tt-col').forEach(function (col) {
      col.addEventListener('mousemove', function (e) {
        var hv = col.querySelector('.tt-hover');
        if (e.target.closest('.rsv')) { hv.style.visibility = 'hidden'; return; }
        var idx = Math.floor((e.clientY - col.getBoundingClientRect().top) / px);
        hv.style.visibility = 'visible';
        hv.style.top = (idx * px) + 'px';
        hv.textContent = toHM(start + idx * SLOT) + ' 예약';
      });
      col.addEventListener('click', function (e) {
        var blk = e.target.closest('.rsv');
        if (blk) { openModal(blk.dataset.key); return; }
        var idx = Math.floor((e.clientY - col.getBoundingClientRect().top) / px);
        openModal(null, { rsvDate: curDate, startTime: toHM(start + idx * SLOT) });
      });
    });
    drawNowLine();
  }

  function drawNowLine() {
    document.querySelectorAll('.now-line').forEach(function (n) { n.remove(); });
    if (curDate !== todayStr()) return;
    var now = new Date(), m = now.getHours() * 60 + now.getMinutes();
    var start = toMin(openTime), end = toMin(closeTime);
    if (m < start || m > end) return;
    var top = (m - start) / SLOT * slotPx();
    document.querySelectorAll('.tt-col').forEach(function (col) {
      var line = document.createElement('div');
      line.className = 'now-line';
      line.style.top = top + 'px';
      col.appendChild(line);
    });
  }

  // ------------------------------------------------------------------
  // 등록/수정 모달
  // ------------------------------------------------------------------
  function findRsv(key) {
    var all = dayList.concat(listTable ? listTable.getData() : []);
    return all.filter(function (r) { return r.skinKey === key; })[0];
  }

  function setMember(memNo, nm, tel) {
    $('mMemNo').value = memNo || '';
    $('memBox').innerHTML = memNo
      ? '<b>' + esc(nm) + '</b> <span class="text-muted ms-1">' + esc(fmtTel(tel)) + '</span> <span class="text-muted small ms-2">회원번호 ' + esc(memNo) + '</span>'
      : '<span class="text-muted">회원을 검색해서 선택하세요</span>';
  }

  function toggleDone() {
    var done = $('mGubun').value === '관리';
    $('doneBox').classList.toggle('d-none', !done);
    $('remkBox').classList.toggle('d-none', !done && !$('mSkinKey').value);   // 수정 중이거나 관리완료면 표시
    if (done && !$('mSkinTime').dataset.set) { $('mSkinTime').value = $('mStart').value; }
  }

  function openModal(key, preset) {
    var r = key ? findRsv(key) : null;
    var p = r || preset || {};
    $('mTitle').textContent = r ? '예약수정' : '예약등록';
    $('mSkinKey').value = r ? r.skinKey : '';
    setMember(p.memNo, p.custNm, p.custTel);
    $('mMemKw').value = '';
    $('mDate').value = p.rsvDate || curDate;
    $('mStart').value = p.startTime || openTime;
    $('mMenu').value = p.menuId ? String(p.menuId) : '';
    $('mDur').value = String(p.durMin || 60);
    $('mSkiner').value = p.skiner || '';
    $('mGubun').value = p.gubun === '관리' ? '관리' : '예약';
    $('mMemo').value = p.memo || '';
    $('mRemk').value = p.remk || '';
    $('mSkinTime').value = p.skinTime || (r && r.rsvDate === todayStr() ? nowHM() : (p.startTime || openTime));
    if (!$('mSkinTime').value) $('mSkinTime').value = p.startTime || openTime;
    $('mSkinTime').dataset.set = '1';
    byteCount($('mMemo'), 'cntMemo');
    byteCount($('mRemk'), 'cntRemk');
    toggleDone();
    $('mAlim').checked = !r;
    $('mAlimInfo').textContent = r && r.alimYn === 'Y' ? '(' + (r.alimDt || '') + ' 발송됨)' : '';
    $('btnDelete').classList.toggle('d-none', !r);
    $('btnDone').classList.toggle('d-none', !r || r.gubun === '관리');
    $('btnUndo').classList.toggle('d-none', !r || r.gubun !== '관리');
    $('memResult').classList.add('d-none');
    modal.show();
    setTimeout(function () { (r ? $('mMemo') : $('mMemKw')).focus(); }, 300);
  }

  function searchMember() {
    var kw = $('mMemKw').value.trim();
    if (kw.length < 2) { msg('2글자 이상 입력하세요.'); return; }
    api('/members', { keyword: kw }).then(function (list) {
      var box = $('memResult');
      if (!list.length) {
        box.innerHTML = '<div class="p-2 text-muted small">검색된 회원이 없어요. 회원 등록 후 예약할 수 있어요.</div>';
      } else {
        box.innerHTML = list.map(function (c, i) {
          return '<button type="button" data-i="' + i + '"><span><b>' + esc(c.custNm) + '</b> <small class="text-muted">' + esc(c.memNo) + '</small></span><span class="text-muted">' + esc(fmtTel(c.custTel)) + '</span></button>';
        }).join('');
        box.querySelectorAll('button').forEach(function (b) {
          b.onclick = function () {
            var c = list[+b.dataset.i];
            setMember(c.memNo, c.custNm, c.custTel);
            box.classList.add('d-none');
          };
        });
        if (list.length === 1) { setMember(list[0].memNo, list[0].custNm, list[0].custTel); return; }
      }
      box.classList.remove('d-none');
    }).catch(fail);
  }

  function save() {
    var start = $('mStart').value;
    var end = toHM(toMin(start) + (+$('mDur').value));
    var menu = menuById($('mMenu').value);
    var body = {
      skinKey: $('mSkinKey').value,
      memNo: $('mMemNo').value,
      rsvDate: $('mDate').value,
      startTime: start,
      durMin: +$('mDur').value,
      menuId: menu ? menu.menuId : 0,
      jepmcd: menu ? menu.jepmcd : '',
      menuNm: menu ? menu.menuNm : '',
      price: menu ? menu.price : 0,
      skiner: $('mSkiner').value.trim(),
      gubun: $('mGubun').value,
      memo: $('mMemo').value.trim(),
      remk: $('mRemk').value.trim(),
      skinTime: $('mSkinTime').value
    };
    if (!body.memNo) { msg('회원을 검색해서 선택하세요.'); $('mMemKw').focus(); return; }
    if (toMin(end) > toMin(closeTime)) { msg('영업종료(' + closeTime + ')를 넘어가요. 소요시간을 확인하세요.'); return; }
    if (bytes(body.memo) > 60) { msg('메모는 한글 30자까지 입력할 수 있어요.'); $('mMemo').focus(); return; }
    if (bytes(body.remk) > 60) { msg('관리내용은 한글 30자까지 입력할 수 있어요.'); $('mRemk').focus(); return; }

    var sendAlim = $('mAlim').checked && body.gubun === '예약';
    $('btnSave').disabled = true;
    api('/save', null, body)
      .then(function (d) {
        if (sendAlim) return api('/alimtalk', null, { type: 'CONFIRM', keys: [d.skinKey] }).then(function () { return '저장하고 알림톡을 보냈어요.'; });
        return '저장했어요.';
      })
      .then(function (text) {
        modal.hide();
        msg(text);
        if (body.rsvDate !== curDate) setDate(body.rsvDate); else loadDay();
        if (listTable) loadList();
      })
      .catch(fail)
      .then(function () { $('btnSave').disabled = false; });
  }

  // 관리완료 → 예약으로 되돌리기 (관리시간 지움, 관리내용은 유지)
  function undoDone(key, fromModal) {
    if (!confirm('관리완료를 취소하고 예약 상태로 되돌릴까요?')) return;
    api('/undo', null, { skinKey: key })
      .then(function () {
        if (fromModal) modal.hide();
        msg('예약 상태로 되돌렸어요.');
        loadDay();
        if (listTable) loadList();
      })
      .catch(fail);
  }

  function remove() {
    if (!confirm('이 예약을 취소(삭제)할까요?')) return;
    api('/delete', null, { skinKey: $('mSkinKey').value })
      .then(function () { modal.hide(); msg('예약을 삭제했어요.'); loadDay(); if (listTable) loadList(); })
      .catch(fail);
  }

  // ------------------------------------------------------------------
  // 예약목록
  // ------------------------------------------------------------------
  function buildList() {
    listTable = new Tabulator('#listTable', {
      layout: 'fitColumns',
      height: listHeight(),
      placeholder: '조회된 예약이 없어요.',
      selectableRows: true,
      columnDefaults: { headerSort: false },   // 정렬은 예약일·시간순 고정
      rowHeader: { formatter: 'rowSelection', titleFormatter: 'rowSelection', headerSort: false, hozAlign: 'center', width: 36, download: false },
      columns: [
        { title: '예약일', field: 'rsvDate', width: 120, hozAlign: 'center',
          formatter: function (c) { var v = c.getValue(); return v + ' (' + weekday(v) + ')'; } },
        { title: '예약시간', field: 'startTime', width: 100, hozAlign: 'center',
          formatter: function (c) { var d = c.getData(); return d.startTime + '~' + d.endTime; } },
        { title: '회원명', field: 'custNm', width: 80 },
        { title: '연락처', field: 'custTel', width: 115, formatter: function (c) { return esc(fmtTel(c.getValue())); } },
        { title: '시술', field: 'menuNm', width: 100 },
        { title: '관리사', field: 'skiner', width: 80 },
        { title: '구분', field: 'gubun', width: 90, hozAlign: 'center',
          formatter: function (c) { var g = gb(c.getValue()); return '<span class="badge-st st-' + g.cls + '">' + g.nm + '</span>'; },
          accessorDownload: function (v) { return gb(v).nm; } },
        { title: '알림톡', field: 'alimYn', width: 70, headerSort: false, hozAlign: 'center',
          formatter: function (c) { return c.getValue() === 'Y' ? '<span title="' + esc(c.getData().alimDt || '') + '">발송</span>' : '-'; } },
        { title: '메모', field: 'memo', minWidth: 100, formatter: function (c) { return '<div class="memo-cell">' + esc(c.getValue() || '') + '</div>'; } },
        { title: '관리내용', field: 'remk', minWidth: 100,
          formatter: function (c) { var d = c.getData(); return '<div class="memo-cell">' + (d.skinTime ? '<b>' + d.skinTime + '</b> ' : '') + esc(c.getValue() || '') + '</div>'; } },
        { title: '처리', field: 'skinKey', width: 125, headerSort: false, download: false,
          formatter: function (c) {
            return '<button class="btn btn-outline-primary act-btn" data-act="edit">수정</button>'
                 + (c.getData().gubun !== '관리'
                    ? '<button class="btn btn-outline-success act-btn" data-act="done">관리</button>'
                    : '<button class="btn btn-outline-warning act-btn" data-act="undo">예약복귀</button>');
          },
          cellClick: function (e, cell) {
            var act = e.target.dataset && e.target.dataset.act;
            if (!act) return;
            e.stopPropagation();
            if (act === 'undo') { undoDone(cell.getData().skinKey, false); return; }
            openModal(cell.getData().skinKey);
            if (act === 'done') $('btnDone').click();
          }
        }
      ]
    });
    listTable.on('rowDblClick', function (e, row) { openModal(row.getData().skinKey); });
  }

  function loadList() {
    if (!listTable) return;
    api('/list', { from: $('fFrom').value, to: $('fTo').value, gubun: $('fGubun').value, keyword: $('fKeyword').value.trim() })
      .then(function (list) { listTable.setData(list || []); })
      .catch(fail);
  }

  // ------------------------------------------------------------------
  // 알림톡
  // ------------------------------------------------------------------
  function sendConfirmSelected() {
    var rows = listTable ? listTable.getSelectedData() : [];
    var keys = rows.filter(function (r) { return r.gubun !== '관리'; }).map(function (r) { return r.skinKey; });
    if (!keys.length) { msg('발송할 예약(구분: 예약)을 선택하세요.'); return; }
    var resend = rows.filter(function (r) { return r.alimYn === 'Y' && r.gubun !== '관리'; }).length;
    if (!confirm(keys.length + '건에 예약확정 알림톡을 보낼까요?' + (resend ? '\n(이미 보낸 ' + resend + '건 포함)' : ''))) return;
    api('/alimtalk', null, { type: 'CONFIRM', keys: keys })
      .then(function (d) { msg(d.sent + '건 발송했어요.'); loadList(); loadDay(); })
      .catch(fail);
  }

  function sendRemind() {
    var tomorrow = addDays(todayStr(), 1);
    if (!confirm(tomorrow + ' (' + weekday(tomorrow) + ') 예약 회원 전체에게 방문 안내 알림톡을 보낼까요?')) return;
    api('/alimtalk', null, { type: 'REMIND', date: tomorrow })
      .then(function (d) { msg(d.sent ? d.sent + '건 발송했어요.' : '내일 예약이 없어요.'); if (curDate === tomorrow) loadDay(); })
      .catch(fail);
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
