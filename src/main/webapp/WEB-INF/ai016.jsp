<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>거래처 관리</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 거래처 관리 (ai016) ===== */
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
  .card-box.locked .card-head { background: #6b7686; }
  .hint { font-size: 11px; color: var(--muted); }

  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
  #custTable { border: 0; font-size: 13px; }
  #custTable .tabulator-header { background: var(--navy-soft); }
  #custTable .tabulator-row { cursor: pointer; }
  #custTable .tabulator-row.row-off { color: #9aa3b0; }
  #custTable .tabulator-row.tabulator-selected { background: #dfe9fb; }
  #custTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  .btn-edit { font-size: 11px; padding: 1px 7px; }
  .off { font-size: 11px; color: #c0392b; margin-left: 4px; }
  .lock { font-size: 11px; color: var(--muted); }

  .form-body { padding: 14px 16px; }
  .form-body .form-label { font-size: 12px; color: var(--muted); margin-bottom: 2px; }
  .form-body .req::after { content: ' *'; color: #d63939; }
  .mibul { display: flex; justify-content: space-between; align-items: baseline; background: #fff6f5; border: 1px solid #f3d2cf; border-radius: 8px; padding: 8px 12px; margin-bottom: 10px; }
  .mibul .v { font-size: 20px; font-weight: 800; color: #d63939; }
  .meta { font-size: 11px; color: var(--muted); }
  .lock-msg { font-size: 12px; color: #8a5a00; background: #fff6e0; border: 1px solid #f0d28a; border-radius: 6px; padding: 6px 10px; margin-bottom: 10px; }
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

      <!-- ================= 거래처 목록 ================= -->
      <div class="card-box">
        <div class="card-head">
          <h6>거래처 목록</h6>
          <div class="sub">건수 <b id="cnt">0</b> · 미불금 합계 <b id="sumMibul">0</b></div>
        </div>
        <div class="filter">
          <input type="text" class="form-control form-control-sm" id="fKw" placeholder="거래처명·담당자·전화" style="width:200px">
          <div class="form-check form-check-inline ms-1 mb-0">
            <input class="form-check-input" type="checkbox" id="fUse" checked>
            <label class="form-check-label small" for="fUse">정상 거래처만</label>
          </div>
          <div class="form-check form-check-inline mb-0">
            <input class="form-check-input" type="checkbox" id="fMibul">
            <label class="form-check-label small" for="fMibul">미불금 있는 곳만</label>
          </div>
          <button type="button" class="btn btn-sm btn-secondary" id="ai016Search">조회</button>
          <span class="hint ms-auto">🔒 POS 거래처는 조회만</span>
          <button type="button" class="btn btn-sm btn-primary" id="btnNew">+ 신규등록</button>
        </div>
        <div id="custTable"></div>
      </div>

      <!-- ================= 등록 / 수정 ================= -->
      <div class="card-box" id="formBox">
        <div class="card-head">
          <h6 id="formTitle">신규 등록</h6>
          <div class="sub" id="formCode"></div>
        </div>
        <div class="form-body">
          <div class="lock-msg d-none" id="lockMsg">🔒 POS에서 등록한 거래처는 조회만 가능합니다. (WEB 등록 거래처만 수정)</div>
          <div class="mibul d-none" id="mibulBox"><span class="small text-muted">미불금</span><span class="v" id="fMibulAmt">0</span></div>
          <div class="row g-2 mb-2">
            <div class="col-12"><label class="form-label req">거래처명</label>
              <input type="text" class="form-control form-control-sm" id="cName" maxlength="30"></div>
            <div class="col-6"><label class="form-label">전화번호</label>
              <input type="text" class="form-control form-control-sm" id="cTel" maxlength="13" placeholder="02-000-0000"></div>
            <div class="col-6"><label class="form-label">담당자</label>
              <input type="text" class="form-control form-control-sm" id="cMan" maxlength="10"></div>
            <div class="col-6"><label class="form-label">핸드폰번호</label>
              <input type="text" class="form-control form-control-sm" id="cHp" maxlength="13" placeholder="010-0000-0000"></div>
            <div class="col-6"><label class="form-label">거래</label>
              <div class="pt-1">
                <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="cEnd" id="cEndY" value="Y" checked><label class="form-check-label small" for="cEndY">정상</label></div>
                <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="cEnd" id="cEndN" value="N"><label class="form-check-label small" for="cEndN">거래종료</label></div>
              </div>
            </div>
            <div class="col-12"><label class="form-label">비고</label>
              <textarea class="form-control form-control-sm" id="cRemk" rows="3"></textarea></div>
          </div>
          <div class="meta" id="cMeta"></div>
        </div>
        <div class="form-foot">
          <button type="button" class="btn btn-outline-secondary" id="btnClear">입력 취소</button>
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
 * 거래처 관리 (ai016) — CUST_MST (로그인 매장)
 *   - 목록 : 거래처명, 전화번호, 담당자, 핸드폰번호, 비고, 미불금
 *   - 등록 : CUSTCD 700000~900000 중 MAX + 1, SOPOST='WEB', ENDCHK='Y', JIKPAN='N', MIBULAMT 0 (ai201 과 동일)
 *   - 수정 : WEB 등록 거래처만 (미불금은 입고·지급으로만 바뀜)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai016';
  var cur = null;           // 수정 중인 거래처 (null = 신규)
  var all = [];             // 조회 결과
  var table = null, toast = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Number(n || 0).toLocaleString('ko-KR'); }
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
  function msg(t) { $('toastMsg').textContent = t; toast.show(); }
  function fail(e) { alert(e.message || e); }
  function isWeb(c) { return c && c.sopost === 'WEB'; }

  function api(path, params, body) {
    if (window.CustMock) return window.CustMock.handle(path, params, body);   // 미리보기용
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

  // ---------------- 목록 ----------------
  function buildTable() {
    table = new Tabulator('#custTable', {
      layout: 'fitColumns',
      height: 400,
      selectableRows: 1,
      placeholder: '조회된 거래처가 없어요.',
      rowFormatter: function (row) { row.getElement().classList.toggle('row-off', row.getData().endchk === 'N'); },
      columns: [
        { title: '거래처명', field: 'custname', minWidth: 150,
          formatter: function (c) { return '<b>' + esc(c.getValue()) + '</b>' + (c.getData().endchk === 'N' ? '<span class="off">거래종료</span>' : ''); } },
        { title: '전화번호', field: 'telno', width: 125, formatter: function (c) { return esc(fmtTel(c.getValue())); } },
        { title: '담당자', field: 'mannm', width: 90 },
        { title: '핸드폰번호', field: 'hp', width: 130, formatter: function (c) { return esc(fmtTel(c.getValue())); } },
        { title: '비고', field: 'remk', minWidth: 120, tooltip: true },
        { title: '미불금', field: 'mibul', width: 115, hozAlign: 'right', headerHozAlign: 'right',
          formatter: function (c) { var v = c.getValue(); return v ? '<span class="text-danger fw-bold">' + won(v) + '</span>' : '<span class="text-muted">0</span>'; },
          bottomCalc: 'sum', bottomCalcFormatter: function (c) { return '<span class="text-danger">' + won(c.getValue()) + '</span>'; } },
        { title: '수정', field: 'custcd', width: 84, hozAlign: 'center', headerHozAlign: 'center', headerSort: false,
          formatter: function (c) {
            return isWeb(c.getData()) ? '<button type="button" class="btn btn-outline-primary btn-edit">✎ 수정</button>'
                                      : '<span class="lock" title="POS 거래처 : 조회만">🔒 POS</span>';
          } }
      ]
    });
    table.on('rowClick', function (e, row) {
      row.select();
      edit(row.getData());
      if (e.target.closest('.btn-edit')) $('cName').focus();
    });
  }

  function search() {
    $('ai016Search').disabled = true;
    api('/list', { keyword: $('fKw').value.trim(), useOnly: $('fUse').checked ? 'Y' : 'N' })
      .then(function (list) { all = list || []; draw(); })
      .catch(fail)
      .then(function () { $('ai016Search').disabled = false; });
  }

  function draw() {
    var list = $('fMibul').checked ? all.filter(function (c) { return c.mibul; }) : all;
    table.setData(list);
    $('cnt').textContent = list.length;
    $('sumMibul').textContent = won(list.reduce(function (s, c) { return s + (c.mibul || 0); }, 0));
    if (cur) { var r = table.getRows().filter(function (x) { return x.getData().custcd === cur.custcd; })[0]; if (r) r.select(); }
  }

  // ---------------- 등록 / 수정 ----------------
  function lockForm(on) {
    ['cName', 'cTel', 'cMan', 'cHp', 'cRemk', 'cEndY', 'cEndN'].forEach(function (id) { $(id).disabled = on; });
    $('btnSave').disabled = on;
    $('lockMsg').classList.toggle('d-none', !on);
    $('formBox').classList.toggle('locked', on);
  }

  function clearForm() {
    cur = null;
    if (table) table.deselectRow();
    lockForm(false);
    $('formBox').classList.remove('editing');
    $('formTitle').textContent = '신규 등록';
    $('formCode').textContent = '';
    $('btnSave').textContent = '저장';
    ['cName', 'cTel', 'cMan', 'cHp', 'cRemk'].forEach(function (id) { $(id).value = ''; });
    $('cEndY').checked = true;
    $('mibulBox').classList.add('d-none');
    $('cMeta').textContent = '거래처코드는 저장할 때 700000~900000 중 다음 번호로 자동 부여됩니다.';
    $('btnClear').textContent = '입력 취소';
    $('cName').focus();
  }

  function edit(c) {
    cur = c;
    var web = isWeb(c);
    $('formBox').classList.toggle('editing', web);
    lockForm(!web);
    $('formTitle').textContent = (web ? '거래처 수정 · ' : '거래처 조회 · ') + c.custname;
    $('formCode').innerHTML = '코드 <b>' + esc(c.custcd) + '</b>';
    $('btnSave').textContent = '수정 저장';
    $('cName').value = c.custname;
    $('cTel').value = fmtTel(c.telno);
    $('cMan').value = c.mannm;
    $('cHp').value = fmtTel(c.hp);
    $('cRemk').value = c.remk;
    (c.endchk === 'N' ? $('cEndN') : $('cEndY')).checked = true;
    $('mibulBox').classList.remove('d-none');
    $('fMibulAmt').textContent = won(c.mibul);
    $('cMeta').textContent = (web ? 'WEB 등록 거래처' : 'POS 등록 거래처') + ' · 미불금은 입고·지급(ai201)으로만 바뀝니다.';
    $('btnClear').textContent = web ? '수정 취소' : '닫기';
  }

  function save() {
    if (cur && !isWeb(cur)) { msg('POS 거래처는 조회만 가능합니다.'); return; }
    var body = {
      custcd: cur ? cur.custcd : '',
      custname: $('cName').value.trim(),
      telno: fmtTel($('cTel').value.trim()), mannm: $('cMan').value.trim(), hp: fmtTel($('cHp').value.trim()),
      remk: $('cRemk').value.trim(), endchk: $('cEndN').checked ? 'N' : 'Y'
    };
    if (!body.custname) { alert('거래처명을 입력하세요.'); $('cName').focus(); return; }
    if (cur && body.endchk === 'N' && cur.endchk !== 'N') {
      var warn = body.custname + ' 을(를) 거래종료로 바꿀까요?\n입고 화면 거래처 검색에서 빠집니다.';
      if (cur.mibul) warn += '\n(미불금 ' + won(cur.mibul) + '원이 남아 있습니다)';
      if (!confirm(warn)) return;
    }

    var isNew = !cur;
    $('btnSave').disabled = true;
    api('/save', null, body)
      .then(function (c) {
        msg(isNew ? c.custname + ' 을(를) 등록했어요. (코드 ' + c.custcd + ')' : c.custname + ' 정보를 수정했어요.');
        edit(c);
        search();
      })
      .catch(fail)
      .then(function () { if (!cur || isWeb(cur)) $('btnSave').disabled = false; });
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var el = $('custTable');
    if (!table || !el.offsetParent) return;
    var top = el.getBoundingClientRect().top;
    table.setHeight(Math.max(300, window.innerHeight - top - 30));
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    toast = new bootstrap.Toast($('toast'), { delay: 2800 });
    buildTable();

    $('ai016Search').onclick = search;
    $('fKw').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('fUse').onchange = search;
    $('fMibul').onchange = draw;
    $('btnNew').onclick = clearForm;
    $('btnClear').onclick = clearForm;
    $('btnSave').onclick = save;
    ['cTel', 'cHp'].forEach(function (id) {
      $(id).addEventListener('blur', function () { $(id).value = fmtTel($(id).value.trim()); });
    });
    document.addEventListener('keydown', function (e) { if (e.key === 'F12') { e.preventDefault(); save(); } });
    window.addEventListener('resize', fit);

    table.on('tableBuilt', function () { fit(); clearForm(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
