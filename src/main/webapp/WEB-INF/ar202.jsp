<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>거래처별 미지급 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 거래처별 미지급 현황 (ar202) ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
  }
  .rp { font-size: 14px; flex: 1 1 0; min-width: 0; }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; position: relative; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .sub { margin-left: auto; font-size: 12px; opacity: .9; }
  .card-head .sub b { color: var(--accent); }

  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
  .filter .lbl { font-size: 12px; color: var(--muted); margin-left: 6px; }

  .sum-bar { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v.main { color: #d63939; }
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  .cust { font-weight: 700; color: var(--navy); }
  .minus { color: #d63939; }
  .zero  { color: #c3c9d3; }
  .owe   { color: #d63939; font-weight: 800; }    /* 미지급 남음 */
  .loading-mask { position: absolute; inset: 0; background: rgba(255,255,255,.7); display: flex; align-items: center; justify-content: center; z-index: 10; font-weight: 700; color: var(--navy); }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 rp">
    <div class="card-box">
      <div class="card-head">
        <h6>거래처별 미지급 현황</h6>
        <div class="sub" id="headInfo">기간을 정하고 조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">기간</span>
        <input type="date" class="form-control form-control-sm" id="fFrom" style="width:138px">
        <span>~</span>
        <input type="date" class="form-control form-control-sm" id="fTo" style="width:138px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-range="today">오늘</button>
          <button type="button" class="btn btn-outline-secondary" data-range="month">이번달</button>
          <button type="button" class="btn btn-outline-secondary" data-range="prev">지난달</button>
        </div>
        <span class="lbl">거래처명</span>
        <input type="text" class="form-control form-control-sm" id="fCust" placeholder="빈칸 = 전체" style="width:140px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar202Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0" title="기간 중 거래가 없어도 미지급금이 남은 거래처를 함께 보여줍니다">
          <input class="form-check-input" type="checkbox" id="fAll">
          <label class="form-check-label small" for="fAll">거래 없는 미지급 거래처 포함</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">거래처수</div><div class="v" id="sCnt">0</div></div>
        <div><div class="k">이월</div><div class="v" id="sEwol">0</div></div>
        <div><div class="k">입고</div><div class="v" id="sAmt">0</div></div>
        <div><div class="k">현금</div><div class="v" id="sCash">0</div></div>
        <div><div class="k">할인</div><div class="v" id="sSale">0</div></div>
        <div><div class="k">미지급금</div><div class="v main" id="sMibul">0</div></div>
      </div>
      <div id="rpTable"></div>
      <div class="loading-mask d-none" id="loading">조회 중입니다…</div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://unpkg.com/tabulator-tables@6.2.5/dist/js/tabulator.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 거래처별 미지급 현황 (ar202) — CUST_MST + IP01_MST, 로그인 매장
 *   - 미지급금 = 기간 말 미지급 (현재 MIBULAMT - 기간 이후 증가분)
 *   - 이월     = 미지급금 - 입고 + 현금 + 할인  (기간 시작 전 잔액)
 *   - 이월 + 입고 - 현금 - 할인 = 미지급금
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar202';
  var NUMS = ['ewol', 'amt', 'cash', 'sale', 'mibul'];
  var table = null, rows = [], total = null, cond = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.substr(0, 2) === '02' ? d.replace(/(\d{2})(\d{4})(\d{4})/, '$1-$2-$3') : d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    if (d.length === 9 && d.substr(0, 2) === '02') return d.replace(/(\d{2})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
  function fail(e) { alert(e.message || e); }

  function api(path, params) {
    if (window.ReportMock) return window.ReportMock.handle(path, params);   // 미리보기용
    var url = API + path + (params ? '?' + new URLSearchParams(params) : '');
    return fetch(url)
      .then(function (r) {
        if (!r.ok) throw new Error('서버 요청 실패 (' + r.status + ') : ' + url);
        return r.json();
      })
      .then(function (res) {
        if (!res.ok) throw new Error(res.msg || '처리 중 오류가 발생했습니다.');
        return res.data;
      });
  }

  // ---------------- 기간 ----------------
  function setRange(kind) {
    var d = new Date();
    if (kind === 'today') { $('fFrom').value = $('fTo').value = ymd(d); }
    if (kind === 'month') { $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth(), 1)); $('fTo').value = ymd(d); }
    if (kind === 'prev') {
      $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth() - 1, 1));
      $('fTo').value = ymd(new Date(d.getFullYear(), d.getMonth(), 0));
    }
  }

  // ---------------- 목록 ----------------
  function money(v, cls) {
    var c = cls || (v < 0 ? 'minus' : (Math.round(v) === 0 ? 'zero' : ''));
    return '<span class="' + c + '">' + won(v) + '</span>';
  }
  function col(title, field, width, cellFmt) {
    return {
      title: title, field: field, minWidth: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
      formatter: function (c) { return (cellFmt || money)(c.getValue()); },
      bottomCalc: function () { return total ? total[field] : ''; },
      bottomCalcFormatter: function (c) { return c.getValue() === '' ? '' : won(c.getValue()); }
    };
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 거래처가 없어요.',
      columns: [
        { title: '거래처명', field: 'custname', minWidth: 160, sorter: 'string',
          formatter: function (c) { return '<span class="cust">' + esc(c.getValue() || '(이름 없음)') + '</span>'; },
          bottomCalc: function () { return total ? '합계 ' + won(rows.length) + '곳' : ''; } },
        { title: '전화번호', field: 'telno', minWidth: 120, sorter: 'string',
          formatter: function (c) { return esc(fmtTel(c.getValue())); } },
        col('이월',     'ewol',  110),
        col('입고',     'amt',   110, function (v) { return '<b>' + money(v) + '</b>'; }),
        col('현금',     'cash',  110),
        col('할인',     'sale',  100),
        col('미지급금', 'mibul', 120, function (v) { return money(v, v > 0 ? 'owe' : ''); })
      ]
    });
  }

  function search() {
    var p = { from: $('fFrom').value, to: $('fTo').value, custname: $('fCust').value.trim(), all: $('fAll').checked ? 'Y' : 'N' };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar202Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = (list || []).map(function (r) { NUMS.forEach(function (k) { r[k] = Number(r[k] || 0); }); return r; });
        total = {};
        NUMS.forEach(function (k) { total[k] = rows.reduce(function (s, r) { return s + r[k]; }, 0); });
        cond = p;
        table.setData(rows);
        setTimeout(function () { table.redraw(true); fit(); }, 0);
        $('sCnt').textContent = won(rows.length);
        $('sEwol').textContent = won(total.ewol);
        $('sAmt').textContent = won(total.amt);
        $('sCash').textContent = won(total.cash);
        $('sSale').textContent = won(total.sale);
        $('sMibul').textContent = won(total.mibul);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>' + (p.custname ? ' · 거래처 ' + esc(p.custname) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar202Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var head = ['거래처명', '전화번호', '이월', '입고', '현금', '할인', '미지급금'];
    var data = table.getData('active').map(function (r) {     // 화면 정렬 순서 그대로
      return [r.custname, fmtTel(r.telno), r.ewol, r.amt, r.cash, r.sale, r.mibul];
    });
    data.push(['합계 ' + rows.length + '곳', '', total.ewol, total.amt, total.cash, total.sale, total.mibul]);
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!cols'] = [20, 15, 13, 13, 13, 12, 13].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '거래처별미지급현황').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + (cond ? cond.from + '_' + cond.to : '') + '.xlsx');
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var el = $('rpTable');
    if (!table || !el.offsetParent) return;
    table.setHeight(Math.max(300, window.innerHeight - el.getBoundingClientRect().top - 30));
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    setRange('month');
    buildTable();
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); search(); };
    });
    $('ar202Search').onclick = search;
    $('fCust').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('fAll').onchange = search;
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
