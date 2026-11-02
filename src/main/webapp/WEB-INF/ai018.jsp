<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품 관리</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제품 관리 (ai018) ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
  }
  .pd { font-size: 14px; flex: 1 1 0; min-width: 0; }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .sub { margin-left: auto; font-size: 12px; opacity: .9; }
  .card-head .sub b { color: var(--accent); }
  .hint { font-size: 11px; color: var(--muted); }

  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
  .filter .f-in { width: 130px; }
  .filter .f-in.w-name { width: 170px; }
  #prodTable { border: 0; font-size: 13px; }
  #prodTable .tabulator-header { background: var(--navy-soft); }
  #prodTable .tabulator-row { cursor: pointer; }
  #prodTable .tabulator-row.row-off { color: #9aa3b0; }
  #prodTable .tabulator-row.tabulator-selected { background: #dfe9fb; }
  .btn-edit { font-size: 11px; padding: 1px 7px; }
  .off { font-size: 11px; color: #c0392b; margin-left: 4px; }
  .jego-0 { color: #b0b7c3; }
  .jego-minus { color: #d63939; font-weight: 700; }
  .more { font-size: 12px; color: #8a5a00; background: #fff6e0; border-top: 1px solid #f0d28a; padding: 5px 14px; }

  #prodModal .modal-header { background: var(--navy); color: #fff; }
  #prodModal.editing .modal-header { background: #b86e12; }
  #prodModal .form-label { font-size: 12px; color: var(--muted); margin-bottom: 2px; }
  #prodModal .req::after { content: ' *'; color: #d63939; }
  #prodModal .num { text-align: right; }
  .jego-box { display: flex; justify-content: space-between; align-items: baseline; background: #f4f7fc; border: 1px solid var(--line); border-radius: 8px; padding: 6px 12px; }
  .jego-box .v { font-size: 18px; font-weight: 800; color: var(--navy); }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 pd">
    <div class="card-box">
      <div class="card-head">
        <h6>제품 목록</h6>
        <div class="sub">건수 <b id="cnt">0</b> · 재고는 로그인 매장 기준</div>
      </div>
      <div class="filter">
        <input type="text" class="form-control form-control-sm f-in" id="fMaker" placeholder="제조회사">
        <input type="text" class="form-control form-control-sm f-in" id="fBrand" placeholder="브랜드">
        <input type="text" class="form-control form-control-sm f-in w-name" id="fName" placeholder="제품명">
        <input type="text" class="form-control form-control-sm f-in" id="fCode" placeholder="코드">
        <input type="text" class="form-control form-control-sm f-in" id="fBar" placeholder="바코드">
        <div class="form-check form-check-inline ms-1 mb-0">
          <input class="form-check-input" type="checkbox" id="fUse" checked>
          <label class="form-check-label small" for="fUse">사용 제품만</label>
        </div>
        <button type="button" class="btn btn-sm btn-secondary" id="ai018Search">조회</button>
        <button type="button" class="btn btn-sm btn-outline-secondary" id="btnReset" title="검색 조건 지우기">초기화</button>
        <button type="button" class="btn btn-sm btn-primary ms-auto" id="btnNew">+ 신규등록</button>
      </div>
      <div id="prodTable"></div>
      <div class="more d-none" id="moreMsg"></div>
    </div>
  </div>
</div>

<!-- 제품 등록 / 수정 -->
<div class="modal fade" id="prodModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header py-2">
        <h6 class="modal-title" id="pmTitle">제품 등록</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="row g-2">
          <div class="col-6"><label class="form-label req">코드 (JEPMCD)</label>
            <input type="text" class="form-control form-control-sm" id="pmCode" maxlength="20" autocomplete="off"></div>
          <div class="col-6"><label class="form-label">바코드</label>
            <input type="text" class="form-control form-control-sm" id="pmBar" maxlength="20" autocomplete="off"></div>
          <div class="col-6"><label class="form-label">제조회사</label>
            <input type="text" class="form-control form-control-sm" id="pmMaker" maxlength="15"></div>
          <div class="col-6"><label class="form-label">브랜드</label>
            <input type="text" class="form-control form-control-sm" id="pmBrand" maxlength="15"></div>
          <div class="col-12"><label class="form-label req">제품명</label>
            <input type="text" class="form-control form-control-sm" id="pmName" maxlength="30"></div>
          <div class="col-4"><label class="form-label">정가</label>
            <input type="text" class="form-control form-control-sm num" id="pmPrice" inputmode="numeric"></div>
          <div class="col-4"><label class="form-label">입고가 <span class="hint" id="pmRate"></span></label>
            <input type="text" class="form-control form-control-sm num" id="pmIn" inputmode="numeric"></div>
          <div class="col-4"><label class="form-label">판매가</label>
            <input type="text" class="form-control form-control-sm num" id="pmSale" inputmode="numeric"></div>
          <div class="col-6 d-flex align-items-end">
            <div class="form-check mb-1">
              <input class="form-check-input" type="checkbox" id="pmChk" checked>
              <label class="form-check-label small" for="pmChk">사용 (CHK = Y)</label>
            </div>
          </div>
          <div class="col-6" id="pmJegoCol">
            <div class="jego-box"><span class="small text-muted">재고 (우리 매장)</span><span class="v" id="pmJego">0</span></div>
          </div>
        </div>
        <div class="hint mt-2" id="pmHint"></div>
        <div class="small text-danger mt-1" id="pmErr"></div>
      </div>
      <div class="modal-footer py-2">
        <button type="button" class="btn btn-sm btn-secondary" data-bs-dismiss="modal">닫기</button>
        <button type="button" class="btn btn-sm btn-primary" id="pmSave">저장</button>
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
 * 제품 관리 (ai018) — SHOP_JEPM_MST (SHOPNO = 세션 GROUPNO)
 *   - 목록 : 제조회사, 브랜드, 제품명, 코드, 정가, 입고가, 판매가, 바코드, 등록일, 재고(SHOP_JEGO, 로그인 매장)
 *   - 검색 : 제조회사, 브랜드, 제품명, 코드, 바코드
 *   - 등록 : 코드 직접 입력 (그룹 안 중복 불가), 등록일 = 오늘
 *   - 수정 : 코드 제외 / 재고는 보기만
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai018';
  var cur = null;           // 수정 중인 제품 (null = 신규)
  var table = null, toast = null, modal = null;
  var $ = function (id) { return document.getElementById(id); };
  var FILTERS = ['fMaker', 'fBrand', 'fName', 'fCode', 'fBar'];

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Number(n || 0).toLocaleString('ko-KR'); }
  function num(v) { var n = parseInt(String(v || '').replace(/[^\d-]/g, ''), 10); return isNaN(n) ? 0 : n; }
  function msg(t) { $('toastMsg').textContent = t; toast.show(); }
  function fail(e) { alert(e.message || e); }

  function api(path, params, body) {
    if (window.ProdMock) return window.ProdMock.handle(path, params, body);   // 미리보기용
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
  function money(c) { return won(c.getValue()); }
  function buildTable() {
    table = new Tabulator('#prodTable', {
      layout: 'fitColumns',
      height: 400,
      selectableRows: 1,
      placeholder: '검색 조건을 넣고 조회하세요.',
      rowFormatter: function (row) { row.getElement().classList.toggle('row-off', row.getData().chk === 'N'); },
      columns: [
        { title: '제조회사', field: 'maker', width: 118 },
        { title: '브랜드', field: 'brand', width: 95 },
        { title: '제품명', field: 'jepmnm', minWidth: 150,
          formatter: function (c) { return '<b>' + esc(c.getValue()) + '</b>' + (c.getData().chk === 'N' ? '<span class="off">미사용</span>' : ''); } },
        { title: '코드', field: 'jepmcd', width: 100 },
        { title: '정가', field: 'price', width: 90, hozAlign: 'right', headerHozAlign: 'right', formatter: money },
        { title: '입고가', field: 'inprice', width: 100, hozAlign: 'right', headerHozAlign: 'right', formatter: money },
        { title: '판매가', field: 'saleprice', width: 100, hozAlign: 'right', headerHozAlign: 'right', formatter: money },
        { title: '바코드', field: 'barcode', width: 140 },
        { title: '등록일', field: 'prdate', width: 108, hozAlign: 'center', headerHozAlign: 'center' },
        { title: '재고', field: 'jego', width: 80, hozAlign: 'right', headerHozAlign: 'right',
          formatter: function (c) { var v = c.getValue(); return '<span class="' + (v < 0 ? 'jego-minus' : v === 0 ? 'jego-0' : 'fw-bold') + '">' + won(v) + '</span>'; } },
        { title: '수정', field: 'jepmkey', width: 76, hozAlign: 'center', headerHozAlign: 'center', headerSort: false,
          formatter: function () { return '<button type="button" class="btn btn-outline-primary btn-edit">✎ 수정</button>'; } }
      ]
    });
    table.on('rowClick', function (e, row) { row.select(); openEdit(row.getData()); });
  }

  function search() {
    var p = { maker: $('fMaker').value.trim(), brand: $('fBrand').value.trim(), name: $('fName').value.trim(),
              code: $('fCode').value.trim(), barcode: $('fBar').value.trim(), useOnly: $('fUse').checked ? 'Y' : 'N' };
    $('ai018Search').disabled = true;
    table.alert('조회 중…', 'msg');
    api('/list', p)
      .then(function (d) {
        table.setData(d.rows || []);
        $('cnt').textContent = (d.rows || []).length + (d.more ? '+' : '');
        $('moreMsg').textContent = '조회 결과가 많아 ' + won(d.max) + '건까지만 보여 줍니다. 검색 조건을 더 넣어 주세요.';
        $('moreMsg').classList.toggle('d-none', !d.more);
        if (cur) { var r = table.getRows().filter(function (x) { return x.getData().jepmcd === cur.jepmcd; })[0]; if (r) { r.select(); r.scrollTo(); } }
      })
      .catch(fail)
      .then(function () { table.clearAlert(); $('ai018Search').disabled = false; fit(); });
  }

  // ---------------- 등록 / 수정 ----------------
  function rateText() {
    var price = num($('pmPrice').value), inp = num($('pmIn').value);
    $('pmRate').textContent = price && inp ? '(' + (Math.round(inp / price * 1000) / 10) + '%)' : '';
  }
  function setMoney(id, v) { $(id).value = v ? won(v) : ''; }

  function openNew() {
    cur = null;
    if (table) table.deselectRow();
    $('prodModal').classList.remove('editing');
    $('pmTitle').textContent = '제품 등록';
    $('pmCode').readOnly = false;
    ['pmCode', 'pmBar', 'pmMaker', 'pmBrand', 'pmName', 'pmPrice', 'pmIn', 'pmSale'].forEach(function (id) { $(id).value = ''; });
    // 검색칸에 넣은 값을 기본값으로
    $('pmMaker').value = $('fMaker').value.trim();
    $('pmBrand').value = $('fBrand').value.trim();
    $('pmChk').checked = true;
    $('pmJegoCol').classList.add('invisible');
    $('pmHint').textContent = '코드는 직접 입력합니다. 같은 그룹 안에서 중복될 수 없고, 등록 후에는 바꿀 수 없습니다.';
    $('pmErr').textContent = '';
    $('pmSave').textContent = '등록';
    rateText();
    modal.show();
    setTimeout(function () { $('pmCode').focus(); }, 300);
  }

  function openEdit(p) {
    cur = p;
    $('prodModal').classList.add('editing');
    $('pmTitle').textContent = '제품 수정 · ' + p.jepmnm;
    $('pmCode').value = p.jepmcd;
    $('pmCode').readOnly = true;
    $('pmBar').value = p.barcode;
    $('pmMaker').value = p.maker;
    $('pmBrand').value = p.brand;
    $('pmName').value = p.jepmnm;
    setMoney('pmPrice', p.price); setMoney('pmIn', p.inprice); setMoney('pmSale', p.saleprice);
    $('pmChk').checked = p.chk !== 'N';
    $('pmJegoCol').classList.remove('invisible');
    $('pmJego').textContent = won(p.jego);
    $('pmHint').textContent = '등록일 ' + (p.prdate || '-') + ' · 코드는 바꿀 수 없습니다. 재고는 입고·판매로만 바뀝니다.';
    $('pmErr').textContent = '';
    $('pmSave').textContent = '수정 저장';
    rateText();
    modal.show();
    setTimeout(function () { $('pmName').focus(); }, 300);
  }

  function save() {
    var body = {
      isNew: cur ? 'N' : 'Y',
      jepmcd: $('pmCode').value.trim(), barcode: $('pmBar').value.trim(),
      maker: $('pmMaker').value.trim(), brand: $('pmBrand').value.trim(), jepmnm: $('pmName').value.trim(),
      price: num($('pmPrice').value), inprice: num($('pmIn').value), saleprice: num($('pmSale').value),
      chk: $('pmChk').checked ? 'Y' : 'N'
    };
    if (!body.jepmcd) { $('pmErr').textContent = '코드를 입력하세요.'; $('pmCode').focus(); return; }
    if (!body.jepmnm) { $('pmErr').textContent = '제품명을 입력하세요.'; $('pmName').focus(); return; }
    if (cur && body.chk === 'N' && cur.chk !== 'N' && !confirm(body.jepmnm + ' 을(를) 미사용으로 바꿀까요?\n판매·입고 화면 제품 검색에서 빠집니다.')) return;

    var isNew = !cur;
    $('pmSave').disabled = true;
    api('/save', null, body)
      .then(function (p) {
        modal.hide();
        msg(isNew ? p.jepmnm + ' 을(를) 등록했어요. (코드 ' + p.jepmcd + ')' : p.jepmnm + ' 정보를 수정했어요.');
        cur = p;
        var row = table.getRows().filter(function (x) { return x.getData().jepmcd === p.jepmcd; })[0];
        if (row) { row.update(p); row.reformat(); row.select(); }
        else { table.addData([p], true); var r2 = table.getRows()[0]; r2.select(); $('cnt').textContent = table.getDataCount(); }
      })
      .catch(function (e) { $('pmErr').textContent = e.message || e; })
      .then(function () { $('pmSave').disabled = false; });
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var el = $('prodTable');
    if (!table || !el.offsetParent) return;
    var top = el.getBoundingClientRect().top;
    var more = $('moreMsg').classList.contains('d-none') ? 0 : $('moreMsg').offsetHeight;
    table.setHeight(Math.max(300, window.innerHeight - top - more - 30));
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    toast = new bootstrap.Toast($('toast'), { delay: 2800 });
    modal = new bootstrap.Modal($('prodModal'));
    buildTable();

    $('ai018Search').onclick = search;
    FILTERS.forEach(function (id) {
      $(id).addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    $('fUse').onchange = search;
    $('btnReset').onclick = function () { FILTERS.forEach(function (id) { $(id).value = ''; }); $('fName').focus(); };
    $('btnNew').onclick = openNew;
    $('pmSave').onclick = save;
    ['pmPrice', 'pmIn', 'pmSale'].forEach(function (id) {
      $(id).addEventListener('input', rateText);
      $(id).addEventListener('blur', function () { setMoney(id, num($(id).value)); rateText(); });
    });
    $('prodModal').addEventListener('input', function () { $('pmErr').textContent = ''; });
    $('prodModal').addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && e.target.tagName === 'INPUT' && e.target.type !== 'checkbox') { e.preventDefault(); save(); }
    });
    window.addEventListener('resize', fit);

    table.on('tableBuilt', function () { fit(); $('fName').focus(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
