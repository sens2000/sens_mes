<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제조회사별 재고 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제조회사별 재고 현황 (ar405) ===== */
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

  .sum-bar { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v.main { color: #1f6fd1; }
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  .maker { font-weight: 700; color: var(--navy); }
  .minus { color: #d63939; }
  .zero  { color: #c3c9d3; }
  .share { display: flex; align-items: center; gap: 6px; justify-content: flex-end; }
  .share .bar { flex: 1 1 auto; max-width: 60px; height: 6px; border-radius: 3px; background: #e9eef6; overflow: hidden; }
  .share .bar i { display: block; height: 100%; background: #1f6fd1; }
  .share .bar i.b { background: #7a5cc7; }
  .share .bar i.g { background: #1f7a4d; }
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
        <h6>제조회사별 재고 현황</h6>
        <div class="sub" id="headInfo">기준일을 정하고 조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">기준일</span>
        <input type="date" class="form-control form-control-sm" id="fDate" style="width:138px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-day="today">오늘</button>
          <button type="button" class="btn btn-outline-secondary" data-day="prevEnd">지난달 말</button>
        </div>
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar405Search">조회</button>
        <span class="small text-muted ms-2">기준일 마감 후 재고 (기준일 다음 날부터의 입출고를 거꾸로 계산)</span>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">제조회사</div><div class="v" id="sCnt">0</div></div>
        <div><div class="k">재고</div><div class="v" id="sJego">0</div></div>
        <div><div class="k">매입가 금액</div><div class="v main" id="sIn">0</div></div>
        <div><div class="k">정가 금액</div><div class="v" id="sPrice">0</div></div>
        <div><div class="k">판매가 금액</div><div class="v" id="sSale">0</div></div>
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
 * 제조회사별 재고 현황 (ar405) — 기준일 재고 × 단가, 제조회사별
 *   - 매입가 비중 = 매입가 금액 × 100 ÷ 총 매입가 금액
 *   - 정가 비중   = 정가 금액 × 100 ÷ 총 정가 금액
 *   - 판매가 비중 = 판매가 금액 × 100 ÷ 총 판매가 금액
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar405';
  var NUMS = ['jego', 'inpriceamt', 'priceamt', 'salepriceamt'];
  var table = null, rows = [], total = null, cond = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function pct(n) { return (Math.round(Number(n || 0) * 10) / 10).toFixed(1) + '%'; }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function div(a, b) { return b ? a / b : 0; }
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

  // ---------------- 기준일 ----------------
  function setDay(kind) {
    var d = new Date();
    if (kind === 'today')   $('fDate').value = ymd(d);
    if (kind === 'prevEnd') $('fDate').value = ymd(new Date(d.getFullYear(), d.getMonth(), 0));
  }

  // ---------------- 목록 ----------------
  function money(v) { return '<span class="' + (v < 0 ? 'minus' : (Math.round(v) === 0 ? 'zero' : '')) + '">' + won(v) + '</span>'; }
  function shareBar(cls) {
    return function (v) {
      return '<div class="share"><span class="bar"><i class="' + cls + '" style="width:' + Math.max(0, Math.min(100, v)) + '%"></i></span>' + pct(v) + '</div>';
    };
  }
  function col(title, field, width, fmt, cellFmt) {
    return {
      title: title, field: field, minWidth: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
      formatter: function (c) { return (cellFmt || fmt)(c.getValue()); },
      bottomCalc: function () { return total ? total[field] : ''; },
      bottomCalcFormatter: function (c) { return c.getValue() === '' ? '' : fmt(c.getValue()); }
    };
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 재고가 없어요.',
      columns: [
        { title: '제조회사', field: 'makecust', minWidth: 140, sorter: 'string',
          formatter: function (c) { return '<span class="maker">' + esc(c.getValue() || '(없음)') + '</span>'; },
          bottomCalc: function () { return total ? '합계 ' + won(rows.length) + '곳' : ''; } },
        col('재고',      'jego',         80, won, money),
        col('매입가',    'inpriceamt',  120, won, function (v) { return '<b>' + money(v) + '</b>'; }),
        col('비중',      'inRate',      110, pct, shareBar('')),
        col('정가금액',  'priceamt',    120, won, money),
        col('비중',      'priceRate',   110, pct, shareBar('b')),
        col('판매가',    'salepriceamt',120, won, money),
        col('비중',      'saleRate',    110, pct, shareBar('g'))
      ]
    });
  }

  function search() {
    var p = { tdate: $('fDate').value };
    if (!p.tdate) { alert('기준일을 입력하세요.'); return; }
    $('loading').classList.remove('d-none');
    $('ar405Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = (list || []).map(function (r) { NUMS.forEach(function (k) { r[k] = Number(r[k] || 0); }); return r; });
        total = {};
        NUMS.forEach(function (k) { total[k] = rows.reduce(function (s, r) { return s + r[k]; }, 0); });
        rows.forEach(function (r) {
          r.inRate    = div(r.inpriceamt * 100, total.inpriceamt);
          r.priceRate = div(r.priceamt * 100, total.priceamt);
          r.saleRate  = div(r.salepriceamt * 100, total.salepriceamt);
        });
        total.inRate = total.priceRate = total.saleRate = rows.length ? 100 : 0;
        cond = p;
        table.setData(rows);
        setTimeout(function () { table.redraw(true); fit(); }, 0);
        $('sCnt').textContent = won(rows.length);
        $('sJego').textContent = won(total.jego);
        $('sIn').textContent = won(total.inpriceamt);
        $('sPrice').textContent = won(total.priceamt);
        $('sSale').textContent = won(total.salepriceamt);
        $('headInfo').innerHTML = '기준일 <b>' + esc(p.tdate) + '</b>';
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar405Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var head = ['제조회사', '재고', '매입가', '매입가비중(%)', '정가금액', '정가비중(%)', '판매가', '판매가비중(%)'];
    var line = function (label, r) {
      return [label, r.jego, r.inpriceamt, r1(r.inRate), r.priceamt, r1(r.priceRate), r.salepriceamt, r1(r.saleRate)];
    };
    var data = table.getData('active').map(function (r) { return line(r.makecust, r); });   // 화면 정렬 순서 그대로
    data.push(line('합계', total));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!cols'] = [20, 9, 14, 12, 14, 11, 14, 12].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제조회사별재고현황').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + (cond ? cond.tdate : '') + '.xlsx');
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
    setDay('today');
    buildTable();
    document.querySelectorAll('[data-day]').forEach(function (b) {
      b.onclick = function () { setDay(b.dataset.day); search(); };
    });
    $('ar405Search').onclick = search;
    $('fDate').onchange = search;
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
