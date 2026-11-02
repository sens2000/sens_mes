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

  /* ===== 직원 관리 (ai002) ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
  }
  .us { font-size: 14px; flex: 1 1 0; min-width: 0; }
  .us-grid { display: grid; grid-template-columns: minmax(0, 1fr) 400px; gap: 16px; align-items: start; }
  @media (max-width: 1100px) { .us-grid { grid-template-columns: 1fr; } }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .sub { margin-left: auto; font-size: 12px; opacity: .9; }
  .card-head .sub b { color: var(--accent); }
  .hint { font-size: 11px; color: var(--muted); }

  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
  #userTable { border: 0; font-size: 13px; }
  #userTable .tabulator-header { background: var(--navy-soft); }
  #userTable .tabulator-row.row-off { color: #9aa3b0; }
  #userTable .tabulator-row.tabulator-selected { background: #dfe9fb; }
  #userTable .tabulator-row { cursor: pointer; }
  .btn-edit { font-size: 11px; padding: 1px 7px; }
  .card-box.editing { box-shadow: 0 0 0 2px #f0a43a; }
  .card-box.editing .card-head { background: #b86e12; }
  .pos-m { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 12px; font-weight: 700; color: #8a5a00; background: #fff1cc; border: 1px solid #f0c75e; }
  .pos-s { color: #4a5568; font-size: 12px; }
  .off { font-size: 11px; color: #c0392b; margin-left: 4px; }

  .form-body { padding: 14px 16px; }
  .form-body .form-label { font-size: 12px; color: var(--muted); margin-bottom: 2px; }
  .form-body .req::after { content: ' *'; color: #d63939; }
  .sec { font-size: 12px; font-weight: 700; color: var(--navy); border-bottom: 1px solid var(--line); padding-bottom: 3px; margin: 4px 0 8px; }
  .meta { font-size: 11px; color: var(--muted); }
  .form-foot { display: flex; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line); background: #fafbfd; }
  .form-foot .btn { flex: 1; }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 us">
    <div class="us-grid">

      <!-- ================= 직원 목록 ================= -->
      <div class="card-box">
        <div class="card-head">
          <h6>직원 목록</h6>
          <div class="sub">건수 <b id="cnt">0</b></div>
        </div>
        <div class="filter">
          <span class="badge text-bg-light border" id="fShop" style="font-size:13px;font-weight:600;padding:6px 10px"></span>
          <input type="text" class="form-control form-control-sm" id="fKw" placeholder="성명·아이디·전화" style="width:160px">
          <div class="form-check form-check-inline ms-1 mb-0">
            <input class="form-check-input" type="checkbox" id="fUse" checked>
            <label class="form-check-label small" for="fUse">사용중만</label>
          </div>
          <button type="button" class="btn btn-sm btn-secondary" id="ai002Search">조회</button>
          <span class="hint ms-auto">줄 또는 ✎ 수정을 누르면 오른쪽에서 수정</span>
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
          <div class="sec">로그인</div>
          <div class="row g-2 mb-2">
            <div class="col-6"><label class="form-label">아이디 (userid) <span class="hint">선택</span></label>
              <input type="text" class="form-control form-control-sm" id="uId" maxlength="20" autocomplete="off"></div>
            <div class="col-6"><label class="form-label" id="uPassLbl">암호</label>
              <input type="password" class="form-control form-control-sm" id="uPass" maxlength="20" autocomplete="new-password"></div>
          </div>

          <div class="sec">매장</div>
          <div class="row g-2 mb-2">
            <div class="col-5"><label class="form-label req">매장코드</label>
              <input type="text" class="form-control form-control-sm" id="uShop" readonly tabindex="-1"></div>
            <div class="col-7"><label class="form-label">매장명</label>
              <input type="text" class="form-control form-control-sm" id="uShopName" readonly tabindex="-1"></div>
          </div>

          <div class="sec">직원 정보</div>
          <div class="row g-2 mb-2">
            <div class="col-6"><label class="form-label">직급</label>
              <select class="form-select form-select-sm" id="uPos"><option>직원</option><option>메니저</option></select></div>
            <div class="col-6"><label class="form-label">등급 (grade)</label>
              <input type="number" class="form-control form-control-sm" id="uGrade" min="0" max="99" value="5"></div>
            <div class="col-6"><label class="form-label req">성명</label>
              <input type="text" class="form-control form-control-sm" id="uName" maxlength="10"></div>
            <div class="col-6"><label class="form-label">전화번호</label>
              <input type="text" class="form-control form-control-sm" id="uHand" maxlength="13" placeholder="010-0000-0000"></div>
            <div class="col-12"><label class="form-label">비고</label>
              <textarea class="form-control form-control-sm" id="uRemk" rows="3"></textarea></div>
            <div class="col-12"><label class="form-label">사용</label>
              <div>
                <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="uChk" id="uChkY" value="Y" checked><label class="form-check-label small" for="uChkY">사용 (Y)</label></div>
                <div class="form-check form-check-inline"><input class="form-check-input" type="radio" name="uChk" id="uChkN" value="N"><label class="form-check-label small" for="uChkN">미사용 (N)</label></div>
              </div>
            </div>
          </div>
          <div class="meta" id="uMeta"></div>
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
 * 직원 관리 (ai002) — user_info
 *   - 목록 : 매장코드, 매장명, 성명, 직급, 아이디, 등급, 유무
 *   - 등록 : buseo '0001', code = MAX + 1 (4자리), 직급 기본 '직원', grade 기본 5
 *   - 수정 : 암호는 입력했을 때만 바뀜 / 삭제 대신 사용 = N
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai002';
  var SHOPS = [], MY_SHOP = '';
  var cur = null;           // 수정 중인 직원 (null = 신규)
  var table = null, toast = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
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

  // ---------------- 매장 ----------------
  function loadShops() {
    return api('/shops').then(function (d) {
      SHOPS = d.shops || [];
      MY_SHOP = d.myShop || '';
      $('fShop').textContent = MY_SHOP + ' ' + shopName(MY_SHOP);      // 로그인 매장 직원만 조회
    });
  }
  function shopName(no) {
    var s = SHOPS.filter(function (x) { return x.shopno === no; })[0];
    return s ? s.shopname : '';
  }

  // ---------------- 목록 ----------------
  function buildTable() {
    table = new Tabulator('#userTable', {
      layout: 'fitColumns',
      height: 400,
      selectableRows: 1,
      placeholder: '조회된 직원이 없어요.',
      rowFormatter: function (row) { row.getElement().classList.toggle('row-off', row.getData().chk === 'N'); },
      columns: [
        { title: '매장코드', field: 'shopno', width: 115, hozAlign: 'center', headerHozAlign: 'center' },
        { title: '매장명', field: 'shopname', minWidth: 130 },
        { title: '성명', field: 'name', minWidth: 110,
          formatter: function (c) { return '<b>' + esc(c.getValue()) + '</b>' + (c.getData().chk === 'N' ? '<span class="off">미사용</span>' : ''); } },
        { title: '직급', field: 'position', width: 90, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { return c.getValue() === '메니저' ? '<span class="pos-m">메니저</span>' : '<span class="pos-s">' + esc(c.getValue() || '직원') + '</span>'; } },
        { title: '아이디', field: 'userid', minWidth: 110 },
        { title: '등급', field: 'grade', width: 90, hozAlign: 'center', headerHozAlign: 'center', sorter: 'number' },
        { title: '유무', field: 'chk', width: 90, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { return c.getValue() === 'N' ? '<span class="text-danger fw-bold">미사용</span>' : '<span class="text-success fw-bold">사용</span>'; } },
        { title: '수정', field: 'code', width: 84, hozAlign: 'center', headerHozAlign: 'center', headerSort: false,
          formatter: function () { return '<button type="button" class="btn btn-outline-primary btn-edit">✎ 수정</button>'; } }
      ]
    });
    table.on('rowClick', function (e, row) {
      row.select();
      edit(row.getData());
      if (e.target.closest('.btn-edit')) $('uName').focus();
    });
  }

  function search() {
    $('ai002Search').disabled = true;
    api('/list', { keyword: $('fKw').value.trim(), useOnly: $('fUse').checked ? 'Y' : 'N' })
      .then(function (list) {
        table.setData(list || []);
        $('cnt').textContent = (list || []).length;
        if (cur) { var r = table.getRows().filter(function (x) { return x.getData().code === cur.code; })[0]; if (r) r.select(); }
      })
      .catch(fail)
      .then(function () { $('ai002Search').disabled = false; });
  }

  // ---------------- 등록 / 수정 ----------------
  function clearForm() {
    cur = null;
    if (table) table.deselectRow();
    $('formBox').classList.remove('editing');
    $('formTitle').textContent = '신규 등록';
    $('btnSave').textContent = '저장';
    $('formCode').textContent = '';
    $('uPassLbl').textContent = '암호 (아이디 입력 시)';
    $('uPass').placeholder = '';
    ['uId', 'uPass', 'uName', 'uHand', 'uRemk'].forEach(function (id) { $(id).value = ''; });
    $('uShop').value = MY_SHOP;
    $('uShopName').value = shopName($('uShop').value);
    $('uPos').value = '직원';
    $('uGrade').value = 5;
    $('uChkY').checked = true;
    $('uMeta').textContent = '직원코드는 저장할 때 자동으로 부여됩니다.';
    $('btnClear').textContent = '입력 취소';
    $('uName').focus();
  }

  function edit(u) {
    cur = u;
    $('formBox').classList.add('editing');
    $('formTitle').textContent = '직원 수정 · ' + u.name;
    $('btnSave').textContent = '수정 저장';
    $('formCode').innerHTML = '코드 <b>' + esc(u.code) + '</b>';
    $('uPassLbl').textContent = '암호 (변경 시에만 입력)';
    $('uPass').value = '';
    $('uPass').placeholder = '••••';
    $('uId').value = u.userid;
    $('uShop').value = u.shopno;
    $('uShopName').value = u.shopname || shopName(u.shopno);
    $('uPos').value = u.position === '메니저' ? '메니저' : '직원';
    $('uGrade').value = u.grade === '' ? 5 : u.grade;
    $('uName').value = u.name;
    $('uHand').value = fmtTel(u.handno);
    $('uRemk').value = u.remk;
    (u.chk === 'N' ? $('uChkN') : $('uChkY')).checked = true;
    $('uMeta').textContent = '등록 ' + (u.prdate || '-') + ' · 수정 ' + (u.moddate || '-');
    $('btnClear').textContent = '수정 취소';
  }

  function save() {
    var body = {
      buseo: cur ? cur.buseo : '', code: cur ? cur.code : '',
      userid: $('uId').value.trim(), pass: $('uPass').value,
      position: $('uPos').value, grade: $('uGrade').value,
      name: $('uName').value.trim(), handno: $('uHand').value.trim(), remk: $('uRemk').value.trim(),
      chk: $('uChkN').checked ? 'N' : 'Y'
    };
    if (!body.name) { alert('성명을 입력하세요.'); $('uName').focus(); return; }
    if (!cur && body.userid && !body.pass) { alert('아이디를 넣으면 암호도 입력하세요.'); $('uPass').focus(); return; }
    if (body.handno) body.handno = fmtTel(body.handno);
    if (cur && body.chk === 'N' && cur.chk !== 'N' && !confirm(body.name + ' 님을 미사용으로 바꿀까요?\n판매자·처리자 목록에서 빠집니다.')) return;

    var isNew = !cur;
    $('btnSave').disabled = true;
    api('/save', null, body)
      .then(function (u) {
        msg(isNew ? u.name + ' 님을 등록했어요. (코드 ' + u.code + ')' : u.name + ' 님 정보를 수정했어요.');
        cur = u;
        edit(u);
        search();
      })
      .catch(fail)
      .then(function () { $('btnSave').disabled = false; });
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

    $('ai002Search').onclick = search;
    $('fKw').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('fUse').onchange = search;
    $('btnNew').onclick = clearForm;
    $('btnClear').onclick = clearForm;
    $('btnSave').onclick = save;
    $('uHand').addEventListener('blur', function () { $('uHand').value = fmtTel($('uHand').value.trim()); });
    document.addEventListener('keydown', function (e) { if (e.key === 'F12') { e.preventDefault(); save(); } });
    window.addEventListener('resize', fit);

    table.on('tableBuilt', function () {
      fit();
      loadShops().then(function () { clearForm(); search(); }).catch(fail);
    });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
