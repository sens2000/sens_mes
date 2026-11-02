<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제조회사별 판매·매입 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제조회사별 판매·매입 현황 (ar603) ===== */
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
  .filter .form-select { width: 120px; }

  .sum-bar { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v.main { color: #1f6fd1; }
  .sum-bar .v.profit { color: #1f7a4d; }
  .sum-bar .v.buy { color: #b25b00; }
  @media (max-width: 1100px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-col-group .tabulator-col-title { text-align: center; font-weight: 800; }
  #rpTable .tabulator-col.g-sale   > .tabulator-col-content { background: #e3eefc; }
  #rpTable .tabulator-col.g-profit > .tabulator-col-content { background: #e3f5ea; }
  #rpTable .tabulator-col.g-buy    > .tabulator-col-content { background: #fdeee4; }
  #rpTable .tabulator-col .tabulator-col-title { white-space: nowrap; overflow: visible; text-overflow: clip; }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  #rpTable .tabulator-tableholder { cursor: grab; }
  #rpTable.dragging .tabulator-tableholder { cursor: grabbing; user-select: none; }
  .maker { font-weight: 700; color: var(--navy); }
  .minus { color: #d63939; }
  .zero  { color: #d5dae2; }
  .share { display: flex; align-items: center; gap: 6px; justify-content: flex-end; }
  .share .bar { flex: 1 1 auto; max-width: 46px; height: 6px; border-radius: 3px; background: #e9eef6; overflow: hidden; }
  .share .bar i { display: block; height: 100%; background: #1f6fd1; }
  .share .bar i.g { background: #1f7a4d; }
  .share .bar i.o { background: #c26a00; }
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
        <h6>제조회사별 판매·매입 현황</h6>
        <div class="sub" id="headInfo">기간을 정하고 조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">일자</span>
        <input type="date" class="form-control form-control-sm" id="fFrom" style="width:138px">
        <span>~</span>
        <input type="date" class="form-control form-control-sm" id="fTo" style="width:138px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-range="today">오늘</button>
          <button type="button" class="btn btn-outline-secondary" data-range="month">이번달</button>
          <button type="button" class="btn btn-outline-secondary" data-range="prev">지난달</button>
        </div>
        <span class="lbl">판매자</span>
        <select class="form-select form-select-sm" id="fPruser"><option value="">전체</option></select>
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar603Search">조회</button>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">판매금액</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">할인%</div><div class="v" id="sDc">0%</div></div>
        <div><div class="k">이익</div><div class="v profit" id="sProfit">0</div></div>
        <div><div class="k">이익율</div><div class="v" id="sRate">0%</div></div>
        <div><div class="k">매입금액</div><div class="v buy" id="sBuy">0</div></div>
        <div><div class="k">판매가재고</div><div class="v" id="sJego">0</div></div>
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
 * 제조회사별 판매·매입 현황 (ar603)
 *   - 할인%     = 100 - (판매금액 × 100 ÷ 판매 정가금액)
 *   - 판매비율  = 판매금액 × 100 ÷ 판매금액 합계
 *   - 이익      = 판매금액 - 판매원가,  이익율 = 이익 × 100 ÷ 판매금액
 *   - 이익비율  = 이익 × 100 ÷ 이익 합계
 *   - 매입율    = 매입금액 × 100 ÷ 매입 정가금액
 *   - 매입비율  = 매입금액 × 100 ÷ 매입금액 합계
 *   - 판매가재고 = 현재 재고 × 판매가
 *   - 합계줄의 % 는 합계값으로 다시 계산, 비율은 100%
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar603';
  var SUMS = ['inamt', 'saleamt', 'priceamt', 'saleqty', 'custcnt', 'buyamt', 'buyprice', 'buyqty', 'salejego'];
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

  // ---------------- 계산 ----------------
  function derive(r, t, all) {
    r.dc        = r.priceamt ? 100 - (r.saleamt * 100 / r.priceamt) : 0;   // 할인%
    r.profit    = r.saleamt - r.inamt;                                     // 이익
    r.rate      = div(r.profit * 100, r.saleamt);                          // 이익율
    r.buyrate   = div(r.buyamt * 100, r.buyprice);                         // 매입율
    r.saleShare = all ? 100 : div(r.saleamt * 100, t.saleamt);             // 판매 비율
    r.profShare = all ? 100 : div(r.profit * 100, t.profit);               // 이익 비율
    r.buyShare  = all ? 100 : div(r.buyamt * 100, t.buyamt);               // 매입 비율
    return r;
  }
  function calc(list) {
    var t = { makecust: '합계' };
    SUMS.forEach(function (k) { t[k] = 0; });
    list.forEach(function (r) { SUMS.forEach(function (k) { r[k] = Number(r[k] || 0); t[k] += r[k]; }); });
    t.profit = t.saleamt - t.inamt;
    list.forEach(function (r) { derive(r, t); });
    return derive(t, t, list.length > 0);
  }

  // ---------------- 기간 ----------------
  function setRange(kind) {
    var d = new Date();
    if (kind === 'today') { $('fFrom').value = $('fTo').value = ymd(d); }
    if (kind === 'month') { $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth(), 1)); $('fTo').value = ymd(d); }
    if (kind === 'prev')  { $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth() - 1, 1)); $('fTo').value = ymd(new Date(d.getFullYear(), d.getMonth(), 0)); }
  }

  // ---------------- 검색 옵션 ----------------
  function loadInit() {
    return api('/init').then(function (d) {
      var seen = {};
      var list = (d.staff || []).map(function (n) { return String(n || '').trim(); })
        .filter(function (n) { if (!n || seen[n]) return false; seen[n] = 1; return true; });
      $('fPruser').insertAdjacentHTML('beforeend', list.map(function (n) { return '<option>' + esc(n) + '</option>'; }).join(''));
    });
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
      title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
      formatter: function (c) { return (cellFmt || fmt)(c.getValue()); },
      bottomCalc: function () { return total ? total[field] : ''; },
      bottomCalcFormatter: function (c) { return c.getValue() === '' ? '' : fmt(c.getValue()); }
    };
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitDataFill',          // 칸 너비 유지, 화면보다 넓으면 옆으로 스크롤
      height: 400,
      placeholder: '조회된 자료가 없어요.',
      columns: [
        { title: '제조회사', field: 'makecust', width: 130, frozen: true, sorter: 'string',
          formatter: function (c) { return '<span class="maker">' + esc(c.getValue() || '(없음)') + '</span>'; },
          bottomCalc: function () { return total ? '합계 ' + rows.length + '곳' : ''; } },
        { title: '판매', cssClass: 'g-sale', columns: [
          col('판매금액', 'saleamt',   120, won, function (v) { return '<b>' + money(v) + '</b>'; }),
          col('할인%',    'dc',         75, pct),
          col('비율',     'saleShare', 105, pct, shareBar('')),
          col('수량',     'saleqty',    75, won, money),
          col('고객수',   'custcnt',    80, won, money)
        ] },
        { title: '이익', cssClass: 'g-profit', columns: [
          col('이익',   'profit',    120, won, function (v) { return '<b class="' + (v < 0 ? 'minus' : 'text-success') + '">' + won(v) + '</b>'; }),
          col('이익율', 'rate',       80, pct),
          col('비율',   'profShare', 105, pct, shareBar('g'))
        ] },
        { title: '매입', cssClass: 'g-buy', columns: [
          col('매입금액', 'buyamt',   120, won, function (v) { return '<b>' + money(v) + '</b>'; }),
          col('매입율',   'buyrate',   80, pct),
          col('비율',     'buyShare', 105, pct, shareBar('o')),
          col('수량',     'buyqty',    75, won, money)
        ] },
        col('판매가재고', 'salejego', 120, won, money)
      ]
    });
  }

  function search() {
    var p = { from: $('fFrom').value, to: $('fTo').value, pruser: $('fPruser').value };
    if (!p.from || !p.to) { alert('일자를 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar603Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = list || [];
        total = calc(rows);
        cond = p;
        table.setData(rows);
        setTimeout(function () { table.redraw(true); fit(); }, 0);
        $('sAmt').textContent = won(total.saleamt);
        $('sDc').textContent = pct(total.dc);
        $('sProfit').textContent = won(total.profit);
        $('sRate').textContent = pct(total.rate);
        $('sBuy').textContent = won(total.buyamt);
        $('sJego').textContent = won(total.salejego);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>' + (p.pruser ? ' · 판매자 ' + esc(p.pruser) + ' (매입·재고는 매장 전체)' : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar603Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var head = ['제조회사', '판매금액', '할인%', '판매비율(%)', '판매수량', '고객수', '이익', '이익율(%)', '이익비율(%)',
                '매입금액', '매입율(%)', '매입비율(%)', '매입수량', '판매가재고'];
    var line = function (r) {
      return [r.makecust || '(없음)', r.saleamt, r1(r.dc), r1(r.saleShare), r.saleqty, r.custcnt, r.profit, r1(r.rate), r1(r.profShare),
              r.buyamt, r1(r.buyrate), r1(r.buyShare), r.buyqty, r.salejego];
    };
    var data = table.getData('active').map(line);   // 화면 정렬 순서 그대로
    var tl = line(total); tl[0] = '합계 ' + rows.length + '곳';
    data.push(tl);
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!cols'] = [16, 13, 8, 10, 9, 8, 13, 9, 10, 13, 9, 10, 9, 13].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제조회사별현황').replace(/[\s·]+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + cond.from + '_' + cond.to + '.xlsx');
  }

  // ---------------- 끌어서 옆으로 보기 ----------------
  function dragScroll() {
    var wrap = $('rpTable'), holder = wrap.querySelector('.tabulator-tableholder');
    if (!holder) return;
    var down = false, moved = false, sx = 0, sl = 0;
    holder.addEventListener('mousedown', function (e) {
      if (e.button !== 0) return;
      down = true; moved = false; sx = e.pageX; sl = holder.scrollLeft;
    });
    window.addEventListener('mousemove', function (e) {
      if (!down) return;
      var dx = e.pageX - sx;
      if (!moved && Math.abs(dx) < 4) return;         // 살짝 누른 건 클릭으로
      moved = true;
      wrap.classList.add('dragging');
      holder.scrollLeft = sl - dx;
      e.preventDefault();
    });
    window.addEventListener('mouseup', function () { if (down) { down = false; wrap.classList.remove('dragging'); } });
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
    $('ar603Search').onclick = search;
    $('fPruser').onchange = search;
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); dragScroll(); loadInit().catch(fail).then(search); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
