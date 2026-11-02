<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직원 관리</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 직원 관리 (ar002) — ai016 거래처 관리와 같은 구성 ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
  }
  .cu { font-size: 14px; flex: 1 1 0; min-width: 0; }
  .cu-grid { display: grid; grid-template-columns: minmax(0, 1fr) 380px; gap: 16px; align-items: start; }
  @media (max-width: 1100px) { .cu-grid { grid-template-columns: 1fr; } }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .sub { margin-left: auto; font-size: 12px; opacity: .9; }
  .card-head .sub b { color: var(--accent); }
  .card-box.editing { box-shadow: 0 0 0 2px #f0a43a; }
  .card-box.editing .card-head { background: #b86e12; }
  .hint { font-size: 11px; color: var(--muted); }

  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
  #userTable { border: 0; font-size: 13px; }
  #userTable .tabulator-header { background: var(--navy-soft); }
  #userTable .tabulator-row { cursor: pointer; }
  #userTable .tabulator-row.row-off { color: #9aa3b0; }
  #userTable .tabulator-row.tabulator-selected { background: #dfe9fb; }
  .btn-edit { font-size: 11px; padding: 1px 7px; }
  .off { font-size: 11px; color: #c0392b; margin-left: 4px; }
  .pos { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; border: 1px solid #cbd2dc; color: #4a5568; background: #fff; }
  .pos-mgr { color: #1f6fd1; background: #e8f1fd; border-color: #9cc2f2; }
  .pos-pt  { color: #8a6d00; background: #fffbd6; border-color: #e6cf3a; }

  .form-body { padding: 14px 16px; }
  .form-body .form-label { font-size: 12px; color: var(--muted); margin-bottom: 2px; }
  .form-body .req::after { content: ' *'; color: #d63939; }
  .meta { font-size: 11px; color: var(--muted); }
  .form-foot { display: flex; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line); background: #fafbfd; }
  .form-foot .btn { flex: 1; }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 cu">
    <div class="cu-grid">

      <!-- ================= 직원 목록 ================= -->
      <div class="card-box">
        <div class="card-head">
          <h6>직원 목록</h6>
          <div class="sub">전체 <b id="cnt">0</b> · 사용 중 <b id="cntOn">0</b></div>
        </div>
        <div class="filter">
          <!-- 관리자(등급 99)만 매장 선택 -->
          <select class="form-select form-select-sm d-none" id="fShop" style="width:200px" title="조회할 매장"></select>
          <input type="text" class="form-control form-control-sm" id="fKw" placeholder="성명·ID·전화번호" style="width:200px">
          <div class="form-check form-check-inline ms-1 mb-0">
            <input class="form-check-input" type="checkbox" id="fUse" checked>
            <label class="form-check-label small" for="fUse">사용 중인 직원만</label>
          </div>
          <button type="button" class="btn btn-sm btn-secondary" id="ar002Search">조회</button>
          <span class="hint ms-auto">F12 = 저장</span>
          <button type="button" class="btn btn-sm btn-primary" id="btnNew">+ 신규등록</button>
        </div>
        <div id="userTable"></div>
      </div>

      <!-- ================= 등록 / 수정 ================= -->
      <div class="card-box" id="formBox">
        <div class="card-head">
          <h6 id="formTitle">신규 등록</h6>
          <div class="sub" id="formCode"></div>
        </div>
        <div class="form-body">
          <div class="row g-2 mb-2">
            <div class="col-12 d-none" id="eShopBox"><label class="form-label req">매장</label>
              <select class="form-select form-select-sm" id="eShop"></select>
              <div class="hint" id="eShopHint">등록할 매장을 고르세요 (관리자)</div></div>
            <div class="col-12"><label class="form-label req">성명</label>
              <input type="text" class="form-control form-control-sm" id="eName" maxlength="20"></div>
            <div class="col-6"><label class="form-label">ID</label>
              <input type="text" class="form-control form-control-sm" id="eUserid" maxlength="20" autocomplete="off"></div>
            <div class="col-6"><label class="form-label" id="passLbl">비밀번호</label>
              <input type="password" class="form-control form-control-sm" id="ePass" maxlength="20" autocomplete="new-password">
              <div class="hint" id="passHint">ID 를 넣을 때만</div></div>
            <div class="col-6"><label class="form-label">직위</label>
              <select class="form-select form-select-sm" id="ePosition">
                <option value="일반">일반</option>
                <option value="메니져">메니져</option>
                <option value="알바">알바</option>
              </select></div>
            <div class="col-6"><label class="form-label">등급</label>
              <input type="text" class="form-control form-control-sm text-end" id="eGrade" maxlength="4" inputmode="numeric"></div>
            <div class="col-6"><label class="form-label">전화번호</label>
              <input type="text" class="form-control form-control-sm" id="eHandno" maxlength="13" placeholder="010-0000-0000"></div>
            <div class="col-6"><label class="form-label">유무</label>
              <div class="pt-1">
                <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="eChk" id="eChkY" value="Y" checked><label class="form-check-label small" for="eChkY">사용</label></div>
                <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="eChk" id="eChkN" value="N"><label class="form-check-label small" for="eChkN">중지</label></div>
              </div>
            </div>
            <div class="col-12"><label class="form-label">비고</label>
              <textarea class="form-control form-control-sm" id="eRemk" rows="3" maxlength="100"></textarea></div>
          </div>
          <div class="meta" id="eMeta"></div>
        </div>
        <div class="form-foot">
          <button type="button" class="btn btn-outline-secondary" id="btnClear">입력 취소</button>
          <button type="button" class="btn btn-outline-danger d-none" id="btnDel">삭제</button>
          <button type="button" class="btn btn-primary" id="btnSave">저장</button>
        </div>
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
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 직원 관리 (ar002) — USER_INFO (로그인 매장)
 *   - 목록 : 성명, ID, 직위, 등급, 전화번호, 비고, 유무
 *   - 필수는 성명뿐, ID·비밀번호는 로그인할 직원만 (ID 를 넣으면 비밀번호도 필요)
 *   - 등록 : BUSEO '0000', CODE = 매장 안 MAX + 1, 등록일·수정일 = 오늘, 매장코드·매장명 = 로그인 매장
 *   - 수정 : 비밀번호는 입력했을 때만 바뀜
 *   - 삭제 : 본인 계정은 불가, 그만둔 직원은 유무 '중지' 권장
 *   - 로그인 사용자 등급 99 (관리자) : 조회할 매장(전체 매장 포함) · 등록할 매장을 고를 수 있음, 그리드에 매장 칸
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar002';
  var cur = null;           // 수정 중인 직원 (null = 신규)
  var all = [];             // 조회 결과
  var table = null, toast = null;
  var ADMIN = false, MY_SHOP = '', SHOPS = [];   // 관리자(등급 99)면 매장 선택
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (/^02/.test(d)) {
      if (d.length === 9) return d.replace(/(\d{2})(\d{3})(\d{4})/, '$1-$2-$3');
      if (d.length === 10) return d.replace(/(\d{2})(\d{4})(\d{4})/, '$1-$2-$3');
    }
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
  function dLabel(s) { s = String(s || ''); return s.length === 8 ? s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2) : s; }
  function msg(t) { $('toastMsg').textContent = t; toast.show(); }
  function fail(e) { alert(e.message || e); }

  function api(path, params, body) {
    if (window.UserMock) return window.UserMock.handle(path, params, body);   // 미리보기용
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

  // ---------------- 매장 (관리자) ----------------
  function shopLabel(no) {
    var s = SHOPS.filter(function (x) { return x.shopno === no; })[0];
    return s ? s.shopno + ' ' + s.shopname : no;
  }
  function loadInit() {
    return api('/init').then(function (d) {
      ADMIN = !!d.admin; MY_SHOP = d.myShop || ''; SHOPS = d.shops || [];
      if (!ADMIN) return;
      var opts = SHOPS.map(function (x) { return '<option value="' + esc(x.shopno) + '">' + esc(x.shopno + ' ' + x.shopname) + '</option>'; }).join('');
      $('fShop').innerHTML = opts; $('eShop').innerHTML = opts;
      if (!SHOPS.some(function (x) { return x.shopno === MY_SHOP; })) {   // 목록에 없으면 로그인 매장 추가
        var mine = '<option value="' + esc(MY_SHOP) + '">' + esc(MY_SHOP + ' ' + (d.myShopName || '')) + '</option>';
        $('fShop').insertAdjacentHTML('afterbegin', mine); $('eShop').insertAdjacentHTML('afterbegin', mine);
      }
      $('fShop').insertAdjacentHTML('afterbegin', '<option value="*">전체 매장</option>');   // 전체 조회 (등록 칸에는 없음)
      $('fShop').value = MY_SHOP; $('eShop').value = MY_SHOP;
      table.showColumn('shopno');                                             // 그리드에 매장 칸
      $('fShop').classList.remove('d-none');
      $('eShopBox').classList.remove('d-none');
    });
  }
  /** 지금 조회 중인 매장 (관리자가 아니면 빈 값 = 로그인 매장) */
  function curShop() { return ADMIN ? $('fShop').value : ''; }

  // ---------------- 목록 ----------------
  function buildTable() {
    table = new Tabulator('#userTable', {
      layout: 'fitColumns',
      height: 400,
      selectableRows: 1,
      placeholder: '등록된 직원이 없어요.',
      rowFormatter: function (row) { row.getElement().classList.toggle('row-off', row.getData().chk === 'N'); },
      columns: [
        { title: '매장', field: 'shopno', minWidth: 200, visible: false,
          formatter: function (c) { var d = c.getData(); return '<span class="text-muted small">' + esc(d.shopno) + '</span> ' + esc(d.shopname); } },
        { title: '성명', field: 'name', minWidth: 110,
          formatter: function (c) { return '<b>' + esc(c.getValue()) + '</b>' + (c.getData().chk === 'N' ? '<span class="off">중지</span>' : ''); } },
        { title: 'ID', field: 'userid', minWidth: 90,
          formatter: function (c) { return c.getValue() ? esc(c.getValue()) : '<span class="text-muted small">-</span>'; } },
        { title: '직위', field: 'position', width: 85, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { var v = c.getValue(); return v ? '<span class="pos' + (v === '메니져' ? ' pos-mgr' : v === '알바' ? ' pos-pt' : '') + '">' + esc(v) + '</span>' : ''; } },
        { title: '등급', field: 'grade', width: 90, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number' },
        { title: '전화번호', field: 'handno', width: 130, formatter: function (c) { return esc(fmtTel(c.getValue())); } },
        { title: '비고', field: 'remk', minWidth: 120, tooltip: true },
        { title: '유무', field: 'chk', width: 90, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { var v = c.getValue() || 'Y'; return v === 'N' ? '<span class="text-danger fw-bold">N</span>' : '<span class="text-success fw-bold">Y</span>'; } },
        { title: '수정', field: 'code', width: 84, hozAlign: 'center', headerHozAlign: 'center', headerSort: false,
          formatter: function () { return '<button type="button" class="btn btn-outline-primary btn-edit">✎ 수정</button>'; } }
      ]
    });
    table.on('rowClick', function (e, row) {
      row.select();
      edit(row.getData());
      if (e.target.closest('.btn-edit')) $('eName').focus();
    });
  }

  function search() {
    $('ar002Search').disabled = true;
    api('/list', { shop: curShop() })
      .then(function (list) { all = list || []; draw(); })
      .catch(fail)
      .then(function () { $('ar002Search').disabled = false; });
  }

  /** 찾기·사용 중 필터 (화면에서 바로) */
  function draw() {
    var q = $('fKw').value.trim().toLowerCase(), qd = q.replace(/\D/g, ''), useOnly = $('fUse').checked;
    var list = all.filter(function (r) {
      if (useOnly && r.chk === 'N') return false;
      if (!q) return true;
      return (r.name || '').toLowerCase().indexOf(q) >= 0 || (r.userid || '').toLowerCase().indexOf(q) >= 0
          || (qd && (r.handno || '').indexOf(qd) >= 0);
    });
    table.setData(list);
    $('cnt').textContent = all.length;
    $('cntOn').textContent = all.filter(function (r) { return r.chk !== 'N'; }).length;
    if (cur) { var r = table.getRows().filter(function (x) { return x.getData().code === cur.code && x.getData().shopno === cur.shopno; })[0]; if (r) r.select(); }
  }

  // ---------------- 등록 / 수정 ----------------
  function clearForm() {
    cur = null;
    if (table) table.deselectRow();
    $('formBox').classList.remove('editing');
    $('formTitle').textContent = '신규 등록';
    $('formCode').textContent = '';
    $('btnSave').textContent = '저장';
    $('btnDel').classList.add('d-none');
    ['eName', 'eUserid', 'ePass', 'eHandno', 'eRemk'].forEach(function (id) { $(id).value = ''; });
    $('eGrade').value = '0';        // 등급 기본 0
    $('ePosition').value = '일반';  // 직위 기본 일반
    $('eChkY').checked = true;
    if (ADMIN) {
      $('eShop').disabled = false;
      $('eShop').value = $('fShop').value === '*' ? MY_SHOP : $('fShop').value;   // 전체 조회 중이면 로그인 매장
      $('eShopHint').textContent = '등록할 매장을 고르세요 (관리자)';
    }
    $('passHint').textContent = 'ID 를 넣을 때만';
    $('eMeta').textContent = '코드는 저장할 때 매장 안 다음 번호로 자동 부여됩니다.';
    $('btnClear').textContent = '입력 취소';
    $('eName').focus();
  }

  function edit(r) {
    cur = r;
    $('formBox').classList.add('editing');
    $('formTitle').textContent = '직원 수정 · ' + r.name;
    $('formCode').innerHTML = '코드 <b>' + esc(r.code) + '</b>';
    $('btnSave').textContent = '수정 저장';
    $('btnDel').classList.remove('d-none');
    $('eName').value = r.name;
    $('eUserid').value = r.userid;
    $('ePass').value = '';
    var pos = $('ePosition');
    if (r.position && !Array.prototype.some.call(pos.options, function (o) { return o.value === r.position; })) {
      pos.insertAdjacentHTML('beforeend', '<option>' + esc(r.position) + '</option>');   // 기존에 다른 직위 값이 있으면 목록에 추가
    }
    pos.value = r.position || '일반';
    $('eGrade').value = r.grade === '' ? '0' : r.grade;
    $('eHandno').value = fmtTel(r.handno);
    $('eRemk').value = r.remk;
    (r.chk === 'N' ? $('eChkN') : $('eChkY')).checked = true;
    if (ADMIN) {
      if (!Array.prototype.some.call($('eShop').options, function (o) { return o.value === r.shopno; })) {
        $('eShop').insertAdjacentHTML('beforeend', '<option value="' + esc(r.shopno) + '">' + esc(r.shopno + ' ' + (r.shopname || '')) + '</option>');
      }
      $('eShop').value = r.shopno; $('eShop').disabled = false;           // 수정할 때도 매장 변경 가능
      $('eShopHint').textContent = '매장을 바꾸면 그 매장으로 옮겨집니다';
    }
    $('passHint').textContent = '비워 두면 그대로';
    $('eMeta').textContent = '등록 ' + dLabel(r.prdate) + (r.moddate ? ' · 수정 ' + dLabel(r.moddate) : '');
    $('btnClear').textContent = '수정 취소';
  }

  function save() {
    var body = {
      shop: ADMIN ? (cur ? cur.shopno : $('eShop').value) : '',
      new_shop: ADMIN && cur ? $('eShop').value : '',                         // 수정 : 옮길 매장
      code: cur ? cur.code : '',
      name: $('eName').value.trim(), userid: $('eUserid').value.trim(), userpass: $('ePass').value,
      position: $('ePosition').value || '일반', grade: $('eGrade').value.trim() || '0',
      handno: $('eHandno').value.replace(/\D/g, ''), remk: $('eRemk').value.trim(), chk: $('eChkN').checked ? 'N' : 'Y'
    };
    if (!body.name)   { alert('성명을 입력하세요.'); $('eName').focus(); return; }
    if (!cur && body.userid && !body.userpass) { alert('ID 를 넣었으면 비밀번호도 입력하세요.'); $('ePass').focus(); return; }
    if (body.grade && !/^\d+$/.test(body.grade)) { alert('등급은 숫자로 입력하세요.'); $('eGrade').focus(); return; }
    if (cur && body.chk === 'N' && cur.chk !== 'N' &&
        !confirm(body.name + ' 을(를) 중지로 바꿀까요?\n판매자 선택 목록 등에서 뒤로 밀립니다.')) return;

    var isNew = !cur;
    if (ADMIN && cur && body.new_shop && body.new_shop !== cur.shopno &&
        !confirm('[' + body.name + '] 직원을\n' + shopLabel(cur.shopno) + ' → ' + shopLabel(body.new_shop) + ' 매장으로 옮길까요?\n\n옮길 매장에 같은 코드가 있으면 코드가 새로 붙습니다.')) return;
    if (ADMIN && isNew && $('fShop').value !== '*' && body.shop !== $('fShop').value &&
        !confirm('[' + shopLabel(body.shop) + '] 매장에 등록할까요?\n(지금 목록은 ' + shopLabel($('fShop').value) + ' 매장입니다)')) return;
    $('btnSave').disabled = true;
    api('/save', null, body)
      .then(function (r) {
        msg(isNew ? r.name + ' 을(를) 등록했어요. (코드 ' + r.code + ')' : r.name + ' 정보를 수정했어요.');
        if (ADMIN && r.shopno && $('fShop').value !== '*' && $('fShop').value !== r.shopno) $('fShop').value = r.shopno;   // 등록한 매장 목록으로
        edit(r);
        search();
      })
      .catch(fail)
      .then(function () { $('btnSave').disabled = false; });
  }

  function del() {
    if (!cur) return;
    if (!confirm('[' + cur.name + '] 직원을 삭제할까요?\n\n삭제하면 되돌릴 수 없습니다.\n그만둔 직원은 삭제 대신 유무를 "중지"로 바꾸는 것을 권장합니다.')) return;
    var name = cur.name;
    api('/delete', null, { code: cur.code, shop: ADMIN ? cur.shopno : '' })
      .then(function () { msg(name + ' 을(를) 삭제했어요.'); clearForm(); search(); })
      .catch(fail);
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var el = $('userTable');
    if (!table || !el.offsetParent) return;
    var top = el.getBoundingClientRect().top;
    table.setHeight(Math.max(300, window.innerHeight - top - 30));
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    toast = new bootstrap.Toast($('toast'), { delay: 2800 });
    buildTable();

    $('ar002Search').onclick = search;
    $('fKw').addEventListener('input', draw);
    $('fKw').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('fUse').onchange = draw;
    $('fShop').onchange = function () { clearForm(); search(); };
    $('btnNew').onclick = clearForm;
    $('btnClear').onclick = clearForm;
    $('btnSave').onclick = save;
    $('btnDel').onclick = del;
    $('eGrade').addEventListener('input', function () { this.value = this.value.replace(/[^\d]/g, ''); });
    $('eHandno').addEventListener('blur', function () { this.value = fmtTel(this.value.trim()); });
    document.addEventListener('keydown', function (e) { if (e.key === 'F12') { e.preventDefault(); save(); } });
    window.addEventListener('resize', fit);

    table.on('tableBuilt', function () {
      fit();
      loadInit().catch(fail).then(function () { clearForm(); search(); });
    });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
