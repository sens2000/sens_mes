<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>계정 관리</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 계정 관리 (ai019) ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
  }
  .ac { font-size: 14px; flex: 1 1 0; min-width: 0; }
  .ac-grid { display: grid; grid-template-columns: minmax(0, 760px) 360px; gap: 16px; align-items: start; }
  @media (max-width: 1100px) { .ac-grid { grid-template-columns: 1fr; } }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .sub { margin-left: auto; font-size: 12px; opacity: .9; }
  .card-head .sub b { color: var(--accent); }
  .card-box.editing { box-shadow: 0 0 0 2px #f0a43a; }
  .card-box.editing .card-head { background: #b86e12; }
  .hint { font-size: 11px; color: var(--muted); }

  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
  #acctTable { border: 0; font-size: 13px; }
  #acctTable .tabulator-header { background: var(--navy-soft); }
  #acctTable .tabulator-row.row-sys { background: #f7f8fb; color: #5b6576; }
  #acctTable .tabulator-row.row-off { color: #9aa3b0; }
  #acctTable .tabulator-row.tabulator-selected { background: #dfe9fb; }
  #acctTable .tabulator-row:not(.row-sys) { cursor: pointer; }
  .gu-in  { display: inline-block; padding: 0 9px; border-radius: 9px; font-size: 12px; font-weight: 700; color: #1f6fd1; background: #e6f0fd; border: 1px solid #a9c8f3; }
  .gu-out { display: inline-block; padding: 0 9px; border-radius: 9px; font-size: 12px; font-weight: 700; color: #c0392b; background: #fdecea; border: 1px solid #f1b5ae; }
  .sys { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; color: #fff; background: #6b7686; }
  .btn-act { font-size: 11px; padding: 1px 7px; }
  .lock { font-size: 11px; color: var(--muted); }

  .form-body { padding: 14px 16px; }
  .form-body .form-label { font-size: 12px; color: var(--muted); margin-bottom: 2px; }
  .form-body .req::after { content: ' *'; color: #d63939; }
  .gu-pick { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .gu-pick input { display: none; }
  .gu-pick label { border: 1px solid var(--line); border-radius: 8px; padding: 10px; text-align: center; font-weight: 700; cursor: pointer; color: var(--muted); }
  .gu-pick input#gIn:checked + label  { border-color: #1f6fd1; background: #e6f0fd; color: #1f6fd1; }
  .gu-pick input#gOut:checked + label { border-color: #c0392b; background: #fdecea; color: #c0392b; }
  .form-foot { display: flex; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line); background: #fafbfd; }
  .form-foot .btn { flex: 1; }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 ac">
    <div class="ac-grid">

      <!-- ================= 계정 목록 ================= -->
      <div class="card-box">
        <div class="card-head">
          <h6>계정 목록</h6>
          <div class="sub">입금 <b id="cntIn">0</b> · 출금 <b id="cntOut">0</b></div>
        </div>
        <div class="filter">
          <select class="form-select form-select-sm" id="fGu" style="width:100px">
            <option value="">전체</option><option>입금</option><option>출금</option>
          </select>
          <input type="text" class="form-control form-control-sm" id="fKw" placeholder="계정명" style="width:160px">
          <button type="button" class="btn btn-sm btn-secondary" id="ai019Search">조회</button>
          <span class="hint ms-auto">시스템 계정은 조회만</span>
          <button type="button" class="btn btn-sm btn-primary" id="btnNew">+ 신규등록</button>
        </div>
        <div id="acctTable"></div>
      </div>

      <!-- ================= 등록 / 수정 ================= -->
      <div class="card-box" id="formBox">
        <div class="card-head">
          <h6 id="formTitle">신규 등록</h6>
        </div>
        <div class="form-body">
          <div class="mb-3"><label class="form-label req">계정명</label>
            <input type="text" class="form-control" id="aName" maxlength="15" autocomplete="off"></div>
          <div class="mb-2"><label class="form-label req">구분</label>
            <div class="gu-pick">
              <input type="radio" name="aGu" id="gIn" value="입금" checked><label for="gIn">입금</label>
              <input type="radio" name="aGu" id="gOut" value="출금"><label for="gOut">출금</label>
            </div>
          </div>
          <div class="hint mt-2" id="aHint">우리 매장 계정으로 등록됩니다. 시스템 계정과 같은 이름은 쓸 수 없습니다.</div>
        </div>
        <div class="form-foot">
          <button type="button" class="btn btn-outline-secondary" id="btnClear">입력 취소</button>
          <button type="button" class="btn btn-outline-danger d-none" id="btnDelete">삭제</button>
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
 * 계정 관리 (ai019) — acct_tb
 *   - 목록 : 계정명, 구분(입금/출금), 시스템(shopno = '000000')
 *   - 등록 : 계정명, 구분 / sys = 'N', chk = 'Y', shopno = 로그인 매장
 *   - 시스템 계정은 수정·삭제 불가
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai019';
  var cur = null;           // 수정 중인 계정 (null = 신규)
  var table = null, toast = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function msg(t) { $('toastMsg').textContent = t; toast.show(); }
  function fail(e) { alert(e.message || e); }

  function api(path, params, body) {
    if (window.AcctMock) return window.AcctMock.handle(path, params, body);   // 미리보기용
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
    table = new Tabulator('#acctTable', {
      layout: 'fitColumns',
      height: 400,
      selectableRows: false,
      placeholder: '조회된 계정이 없어요.',
      rowFormatter: function (row) {
        var d = row.getData(), el = row.getElement();
        el.classList.toggle('row-sys', d.sys);
        el.classList.toggle('row-off', d.chk === 'N');
        el.classList.toggle('tabulator-selected', !!cur && !d.sys && d.acctnm === cur.acctnm);
      },
      columns: [
        { title: '계정명', field: 'acctnm', minWidth: 180,
          formatter: function (c) { return (c.getData().sys ? '' : '<b>') + esc(c.getValue()) + (c.getData().sys ? '' : '</b>'); } },
        { title: '구분', field: 'acctgu', width: 100, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { var v = c.getValue(); return '<span class="' + (v === '출금' ? 'gu-out' : 'gu-in') + '">' + esc(v) + '</span>'; } },
        { title: 'SYS', field: 'sys', width: 100, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { return c.getValue() ? '<span class="sys">시스템</span>' : '<span class="text-muted small">매장</span>'; } },
        { title: '관리', field: 'acctnm', width: 130, hozAlign: 'center', headerHozAlign: 'center', headerSort: false,
          formatter: function (c) {
            if (c.getData().sys) return '<span class="lock">🔒 수정·삭제 불가</span>';
            return '<button type="button" class="btn btn-outline-primary btn-act act-edit">✎ 수정</button> '
                 + '<button type="button" class="btn btn-outline-danger btn-act act-del">삭제</button>';
          } }
      ]
    });
    table.on('rowClick', function (e, row) {
      var d = row.getData();
      if (d.sys) { msg('시스템 계정은 수정·삭제할 수 없습니다.'); return; }
      if (e.target.closest('.act-del')) { del(d); return; }
      edit(d);
    });
  }

  function search() {
    $('ai019Search').disabled = true;
    return api('/list', { gu: $('fGu').value, keyword: $('fKw').value.trim() })
      .then(function (list) {
        list = list || [];
        table.setData(list);
        $('cntIn').textContent = list.filter(function (a) { return a.acctgu === '입금'; }).length;
        $('cntOut').textContent = list.filter(function (a) { return a.acctgu === '출금'; }).length;
      })
      .catch(fail)
      .then(function () { $('ai019Search').disabled = false; });
  }

  // ---------------- 등록 / 수정 / 삭제 ----------------
  function clearForm() {
    cur = null;
    $('formBox').classList.remove('editing');
    $('formTitle').textContent = '신규 등록';
    $('aName').value = '';
    $('gIn').checked = true;
    $('btnSave').textContent = '저장';
    $('btnClear').textContent = '입력 취소';
    $('btnDelete').classList.add('d-none');
    if (table) table.redraw(true);
    $('aName').focus();
  }

  function edit(a) {
    cur = a;
    $('formBox').classList.add('editing');
    $('formTitle').textContent = '계정 수정 · ' + a.acctnm;
    $('aName').value = a.acctnm;
    (a.acctgu === '출금' ? $('gOut') : $('gIn')).checked = true;
    $('btnSave').textContent = '수정 저장';
    $('btnClear').textContent = '수정 취소';
    $('btnDelete').classList.remove('d-none');
    table.redraw(true);
    $('aName').focus();
  }

  function save() {
    var body = { orgName: cur ? cur.acctnm : '', acctnm: $('aName').value.trim(), acctgu: $('gOut').checked ? '출금' : '입금' };
    if (!body.acctnm) { alert('계정명을 입력하세요.'); $('aName').focus(); return; }
    var isNew = !cur;
    $('btnSave').disabled = true;
    api('/save', null, body)
      .then(function (a) {
        msg(isNew ? a.acctnm + ' (' + a.acctgu + ') 계정을 등록했어요.' : a.acctnm + ' 계정을 수정했어요.');
        cur = a;
        return search().then(function () { edit(a); });
      })
      .catch(fail)
      .then(function () { $('btnSave').disabled = false; });
  }

  function del(a) {
    if (!confirm('"' + a.acctnm + '" (' + a.acctgu + ') 계정을 삭제할까요?\n삭제하면 되돌릴 수 없습니다.')) return;
    api('/delete', null, { acctnm: a.acctnm })
      .then(function () {
        msg(a.acctnm + ' 계정을 삭제했어요.');
        if (cur && cur.acctnm === a.acctnm) clearForm();
        search();
      })
      .catch(fail);
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var el = $('acctTable');
    if (!table || !el.offsetParent) return;
    var top = el.getBoundingClientRect().top;
    table.setHeight(Math.max(300, window.innerHeight - top - 30));
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    toast = new bootstrap.Toast($('toast'), { delay: 2800 });
    buildTable();

    $('ai019Search').onclick = search;
    $('fGu').onchange = search;
    $('fKw').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('btnNew').onclick = clearForm;
    $('btnClear').onclick = clearForm;
    $('btnSave').onclick = save;
    $('btnDelete').onclick = function () { if (cur) del(cur); };
    $('aName').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); save(); } });
    window.addEventListener('resize', fit);

    table.on('tableBuilt', function () { fit(); clearForm(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
