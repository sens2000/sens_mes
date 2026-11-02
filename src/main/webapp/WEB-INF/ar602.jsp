<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>월별 매출·매입 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 월별 매출·매입 현황 (ar602) ===== */
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

  .sum-bar { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v.main { color: #1f6fd1; }
  .sum-bar .v.profit { color: #1f7a4d; }
  .sum-bar .v.buy { color: #b25b00; }
  @media (max-width: 1100px) { .sum-bar { grid-template-columns: repeat(4, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-col-group .tabulator-col-title { text-align: center; font-weight: 800; }
  #rpTable .tabulator-col.g-sale  > .tabulator-col-content { background: #e3eefc; }
  #rpTable .tabulator-col.g-cust  > .tabulator-col-content { background: #e3f5ea; }
  #rpTable .tabulator-col.g-buy   > .tabulator-col-content { background: #fdeee4; }
  #rpTable .tabulator-col .tabulator-col-title { white-space: nowrap; overflow: visible; text-overflow: clip; }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  /* 하단 : 합계 / 평균 두 줄 */
  #rpTable .tabulator-calcs-holder .tabulator-cell { white-space: normal; padding-top: 4px; padding-bottom: 4px; }
  .foot-sum { font-weight: 800; }
  .foot-avg { font-weight: 700; color: #1f6fd1; border-top: 1px dashed #cbd2dc; margin-top: 3px; padding-top: 3px; }
  #rpTable .tabulator-tableholder { cursor: grab; }
  #rpTable.dragging .tabulator-tableholder { cursor: grabbing; user-select: none; }
  .day  { font-weight: 700; color: var(--navy); }
  .sat  { color: #1f6fd1; }
  .sun  { color: #d63939; }
  .minus { color: #d63939; }
  .zero  { color: #d5dae2; }
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
        <h6>월별 매출·매입 현황</h6>
        <div class="sub" id="headInfo">기간을 정하고 조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">기간</span>
        <input type="month" class="form-control form-control-sm" id="fFrom" style="width:140px">
        <span>~</span>
        <input type="month" class="form-control form-control-sm" id="fTo" style="width:140px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-range="year">올해</button>
          <button type="button" class="btn btn-outline-secondary" data-range="last">작년</button>
          <button type="button" class="btn btn-outline-secondary" data-range="m6">최근 6개월</button>
          <button type="button" class="btn btn-outline-secondary" data-range="m12">최근 12개월</button>
        </div>
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar602Search">조회</button>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">판매</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">이익</div><div class="v profit" id="sProfit">0</div></div>
        <div><div class="k">이익 %</div><div class="v" id="sRate">0%</div></div>
        <div><div class="k">방문</div><div class="v" id="sVisit">0</div></div>
        <div><div class="k">객단가</div><div class="v" id="sAvg">0</div></div>
        <div><div class="k">신규 / 재방문</div><div class="v" id="sNew">0 / 0</div></div>
        <div><div class="k">매입금액</div><div class="v buy" id="sBuy">0</div></div>
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
 * 월별 매출·매입 현황 (ar602) — 로그인 매장, 매출은 KIND = '매출'
 *   - 외상 = 판매 - 현금 - 카드,  현금+카드 = 현금 + 카드
 *   - 이익 = 판매 - 원가,  % = 이익 × 100 ÷ 판매 (판매 0 이면 0)
 *   - 객단가 = 매출 ÷ 방문수
 *   - 기간·묶음은 월(yyyymm) 단위, 하단 두 줄 : 합계 / 평균(합계 ÷ 개월수) — 외상·현금+카드·이익·%·객단가는 각 줄 값으로 다시 계산
 *   - 년월은 왼쪽에 고정, 표 안을 끌면 옆으로 이동
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar602';
  var SUMS = ['inamt', 'mcamt', 'mccash', 'mccard', 'mcsale', 'visicnt', 'miamt', 'micash', 'misale',
              'newmember', 'newmemberamt', 'revisitmem', 'revisitmemamt'];
  var table = null, rows = [], total = null, avg = null, cond = null, revisitDays = 31;
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
  function dow(s) { return new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2)).getDay(); }

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
  function derive(r) {
    r.credit = r.mcamt - r.mccash - r.mccard;     // 외상
    r.paid   = r.mccash + r.mccard;               // 현금+카드
    r.profit = r.mcamt - r.inamt;
    r.rate   = div(r.profit * 100, r.mcamt);
    r.avg    = div(r.mcamt, r.visicnt);
    return r;
  }
  function calc(list) {
    var t = { ym: '합계' };
    SUMS.forEach(function (k) { t[k] = 0; });
    list.forEach(function (r) { SUMS.forEach(function (k) { r[k] = Number(r[k] || 0); t[k] += r[k]; }); derive(r); });
    derive(t);
    // 평균 = 합계 ÷ 개월수 (조회된 달 기준)
    var n = list.length;
    avg = { ym: '평균' };
    SUMS.forEach(function (k) { avg[k] = n ? t[k] / n : 0; });
    derive(avg);
    return t;
  }

  // ---------------- 기간 ----------------
  function ym(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1); }
  function setRange(kind) {
    var d = new Date(), y = d.getFullYear(), m = d.getMonth();
    if (kind === 'year') { $('fFrom').value = y + '-01'; $('fTo').value = ym(d); }
    if (kind === 'last') { $('fFrom').value = (y - 1) + '-01'; $('fTo').value = (y - 1) + '-12'; }
    if (kind === 'm6')   { $('fFrom').value = ym(new Date(y, m - 5, 1)); $('fTo').value = ym(d); }
    if (kind === 'm12')  { $('fFrom').value = ym(new Date(y, m - 11, 1)); $('fTo').value = ym(d); }
  }

  // ---------------- 목록 ----------------
  function money(v) { return '<span class="' + (v < 0 ? 'minus' : (Math.round(v) === 0 ? 'zero' : '')) + '">' + won(v) + '</span>'; }
  // 금액이 큰 칸은 넓게
  var WIDE = { mcamt: 1, mccash: 1, mccard: 1, credit: 1, paid: 1, profit: 1, miamt: 1, micash: 1 };
  function col(title, field, fmt, cellFmt) {
    return {
      title: title, field: field, width: WIDE[field] ? 120 : Math.max(80, title.length * 14 + 40),
      hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
      formatter: function (c) { return (cellFmt || fmt)(c.getValue()); },
      bottomCalc: function () { return total ? field : ''; },
      bottomCalcFormatter: function () {
        if (!total) return '';
        return '<div class="foot-sum">' + fmt(total[field]) + '</div><div class="foot-avg">' + fmt(avg[field]) + '</div>';
      }
    };
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitDataFill',          // 칸 너비 유지, 화면보다 넓으면 옆으로 스크롤
      height: 400,
      placeholder: '조회된 자료가 없어요.',
      columns: [
        { title: '년월', field: 'ym', width: 90, frozen: true, sorter: 'string', hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { var s = c.getValue(); return '<span class="day">' + s.substr(0, 4) + '-' + s.substr(4, 2) + '</span>'; },
          bottomCalc: function () { return total ? 'x' : ''; },
          bottomCalcFormatter: function () {
            return total ? '<div class="foot-sum">합계 ' + rows.length + '개월</div><div class="foot-avg">평균</div>' : '';
          } },
        { title: '매출', cssClass: 'g-sale', columns: [
          col('판매',      'mcamt',  won, function (v) { return '<b>' + money(v) + '</b>'; }),
          col('현금',      'mccash', won, money),
          col('카드',      'mccard', won, money),
          col('외상',      'credit', won, money),
          col('할인',      'mcsale', won, money),
          col('현금+카드', 'paid',   won, money),
          col('이익',      'profit', won, function (v) { return '<b class="' + (v < 0 ? 'minus' : 'text-success') + '">' + won(v) + '</b>'; }),
          col('%',         'rate',   pct)
        ] },
        { title: '고객', cssClass: 'g-cust', columns: [
          col('방문',       'visicnt',       won, money),
          col('객단가',     'avg',           won, money),
          col('신규',       'newmember',     won, money),
          col('신규매출',   'newmemberamt',  won, money),
          col('재방문',     'revisitmem',    won, money),
          col('매출',       'revisitmemamt', won, money)
        ] },
        { title: '매입', cssClass: 'g-buy', columns: [
          col('매입금액', 'miamt',  won, function (v) { return '<b>' + money(v) + '</b>'; }),
          col('결재현금', 'micash', won, money),
          col('결재할인', 'misale', won, money)
        ] }
      ]
    });
  }

  function search() {
    var p = { from: $('fFrom').value, to: $('fTo').value };
    if (!p.from || !p.to) { alert('기간(월)을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작월이 종료월보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar602Search').disabled = true;
    api('/list', p)
      .then(function (d) {
        rows = d.rows || [];
        revisitDays = d.revisitDays || 31;
        total = calc(rows);
        cond = p;
        table.setData(rows);
        setTimeout(function () { table.redraw(true); fit(); }, 0);
        $('sAmt').textContent = won(total.mcamt);
        $('sProfit').textContent = won(total.profit);
        $('sRate').textContent = pct(total.rate);
        $('sVisit').textContent = won(total.visicnt);
        $('sAvg').textContent = won(total.avg);
        $('sNew').textContent = won(total.newmember) + ' / ' + won(total.revisitmem);
        $('sBuy').textContent = won(total.miamt);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b> · 재방문 ' + revisitDays + '일 이내';
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar602Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var head = ['년월', '판매', '현금', '카드', '외상', '할인', '현금+카드', '이익', '%', '방문', '객단가',
                '신규', '신규매출', '재방문', '재방문매출', '매입금액', '결재현금', '결재할인'];
    var line = function (label, r) {
      return [label, r.mcamt, r.mccash, r.mccard, r.credit, r.mcsale, r.paid, r.profit, r1(r.rate), r.visicnt, Math.round(r.avg),
              r.newmember, r.newmemberamt, r.revisitmem, r.revisitmemamt, r.miamt, r.micash, r.misale];
    };
    var data = table.getData('active').map(function (r) {   // 화면 정렬 순서 그대로
      var s = r.ym; return line(s.substr(0, 4) + '-' + s.substr(4, 2), r);
    });
    data.push(line('합계', total));
    data.push(line('평균', avg));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!cols'] = [10, 12, 11, 11, 10, 10, 12, 11, 7, 7, 9, 8, 11, 7, 11, 12, 11, 10].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '월별현황').replace(/[\s·]+/g, '');
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
    setRange('year');
    buildTable();
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); search(); };
    });
    $('ar602Search').onclick = search;
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); dragScroll(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
