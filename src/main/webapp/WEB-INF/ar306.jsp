<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>판매자별 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 판매자별 현황 (ar306) ===== */
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
  .sum-bar .v.main { color: #1f6fd1; }
  .sum-bar .v.profit { color: #1f7a4d; }
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  .seller { font-weight: 700; color: var(--navy); }
  /* 제목 글자가 잘리지 않게 */
  #rpTable .tabulator-col .tabulator-col-title { white-space: nowrap; overflow: visible; text-overflow: clip; }
  /* 끌어서 옆으로 보기 */
  #rpTable .tabulator-tableholder { cursor: grab; }
  #rpTable.dragging .tabulator-tableholder { cursor: grabbing; user-select: none; }
  .minus { color: #d63939; }
  .share { display: flex; align-items: center; gap: 6px; justify-content: flex-end; }
  .share .bar { flex: 1 1 auto; max-width: 50px; height: 6px; border-radius: 3px; background: #e9eef6; overflow: hidden; }
  .share .bar i { display: block; height: 100%; background: #1f6fd1; }
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
        <h6>판매자별 현황</h6>
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
        <span class="lbl">재방문일</span>
        <input type="text" class="form-control form-control-sm text-end" id="fDays" value="31" style="width:60px" inputmode="numeric" autocomplete="off">
        <span class="small text-muted">일 미만</span>
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar306Search">조회</button>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">매출</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">이익</div><div class="v profit" id="sProfit">0</div></div>
        <div><div class="k">이익율</div><div class="v" id="sRate">0%</div></div>
        <div><div class="k">방문수</div><div class="v" id="sVisit">0</div></div>
        <div><div class="k">객단가</div><div class="v" id="sAvg">0</div></div>
        <div><div class="k">신규 / 재방문</div><div class="v" id="sNew">0 / 0</div></div>
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
 * 판매자별 현황 (ar306) — MC20_MST + member, 로그인 매장, KIND = '매출'
 *   - 이익     = 매출 - 원가(INAMT)
 *   - %        = 이익 × 100 ÷ 매출
 *   - 객단가   = 매출 ÷ 방문수
 *   - 비중     = 매출 × 100 ÷ 매출합계
 *   - 객수량   = 개수 ÷ 방문수 (소수점 2자리)
 *   - 개당판매 = 매출 ÷ 개수
 *   - 합계줄의 %·객단가·객수량·개당판매 는 합계값으로 다시 계산
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar306';
  var SUMS = ['mcamt', 'cash', 'card', 'disc', 'inamt', 'point', 'qty', 'memcnt', 'newmem', 'newamt', 'revisit', 'revisitamt'];
  var table = null, rows = [], total = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function pct(n) { return (Math.round(Number(n || 0) * 10) / 10).toFixed(1) + '%'; }
  function dec2(n) { return (Math.round(Number(n || 0) * 100) / 100).toFixed(2); }
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
  function derive(r, totalAmt) {
    r.profit   = r.mcamt - r.inamt;
    r.rate     = div(r.profit * 100, r.mcamt);
    r.avg      = div(r.mcamt, r.memcnt);
    r.share    = div(r.mcamt * 100, totalAmt);
    r.perQty   = div(r.qty, r.memcnt);
    r.unitSale = div(r.mcamt, r.qty);
    return r;
  }
  function calc(list) {
    var t = { pruser: '합계' };
    SUMS.forEach(function (k) { t[k] = 0; });
    list.forEach(function (r) { SUMS.forEach(function (k) { r[k] = Number(r[k] || 0); t[k] += r[k]; }); });
    list.forEach(function (r) { derive(r, t.mcamt); });
    return derive(t, t.mcamt);
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
  function money(v) { return '<span class="' + (v < 0 ? 'minus' : '') + '">' + won(v) + '</span>'; }
  /** 합계줄 : 계산해 둔 total 값 사용 */
  function col(title, field, width, fmt, cellFmt) {
    // 제목 글자 수 + 정렬 화살표 자리만큼은 항상 확보
    var w = Math.max(width, title.length * 14 + 40);
    return {
      title: title, field: field, width: w, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
      formatter: function (c) { return (cellFmt || fmt)(c.getValue()); },
      bottomCalc: function () { return total ? total[field] : ''; },
      bottomCalcFormatter: function (c) { return c.getValue() === '' ? '' : fmt(c.getValue()); }
    };
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitDataFill',          // 칸 너비 유지, 화면보다 넓으면 옆으로 스크롤
      height: 400,
      placeholder: '조회된 매출이 없어요.',
      columns: [
        { title: '판매자', field: 'pruser', width: 100, frozen: true, sorter: 'string',
          formatter: function (c) { return '<span class="seller">' + esc(c.getValue() || '(없음)') + '</span>'; },
          bottomCalc: function () { return '합계'; } },
        col('매출',       'mcamt',      105, won, function (v) { return '<b>' + money(v) + '</b>'; }),
        col('현금',       'cash',        95, won, money),
        col('카드',       'card',        95, won, money),
        col('할인',       'disc',        85, won, money),
        col('포인트',     'point',       85, won, money),
        col('이익',       'profit',     100, won, function (v) { return '<b class="' + (v < 0 ? 'minus' : 'text-success') + '">' + won(v) + '</b>'; }),
        col('%',          'rate',        65, pct),
        col('방문수',     'memcnt',      70, won),
        col('객단가',     'avg',         85, won),
        col('비중',       'share',      105, pct, function (v) {
          return '<div class="share"><span class="bar"><i style="width:' + Math.max(0, Math.min(100, v)) + '%"></i></span>' + pct(v) + '</div>';
        }),
        col('개수',       'qty',         65, won),
        col('신규',       'newmem',      60, won),
        col('신규매출',   'newamt',      95, won, money),
        col('재방문',     'revisit',     70, won),
        col('재방문금액', 'revisitamt', 100, won, money),
        col('객수량',     'perQty',      70, dec2),
        col('개당판매',   'unitSale',    85, won)
      ]
    });
  }

  function search() {
    var p = { from: $('fFrom').value, to: $('fTo').value, days: $('fDays').value.replace(/[^\d]/g, '') || '31' };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('fDays').value = p.days;
    $('loading').classList.remove('d-none');
    $('ar306Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = list || [];
        total = calc(rows);
        table.setData(rows);
        setTimeout(function () { table.redraw(true); fit(); }, 0);
        $('sAmt').textContent = won(total.mcamt);
        $('sProfit').textContent = won(total.profit);
        $('sRate').textContent = pct(total.rate);
        $('sVisit').textContent = won(total.memcnt);
        $('sAvg').textContent = won(total.avg);
        $('sNew').textContent = won(total.newmem) + ' / ' + won(total.revisit);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b> · 재방문 ' + esc(p.days) + '일 미만';
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar306Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var r2 = function (n) { return Math.round(n * 100) / 100; };
    var head = ['판매자', '매출', '현금', '카드', '할인', '포인트', '이익', '이익율(%)', '방문수', '객단가', '비중(%)',
                '개수', '신규', '신규매출', '재방문', '재방문금액', '객수량', '개당판매'];
    var line = function (r) {
      return [r.pruser, r.mcamt, r.cash, r.card, r.disc, r.point, r.profit, r1(r.rate), r.memcnt, Math.round(r.avg), r1(r.share),
              r.qty, r.newmem, r.newamt, r.revisit, r.revisitamt, r2(r.perQty), Math.round(r.unitSale)];
    };
    var data = table.getData('active').map(line);   // 화면 정렬 순서 그대로
    data.push(line(total));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!cols'] = [10, 13, 12, 12, 10, 10, 12, 9, 8, 10, 8, 8, 6, 12, 8, 12, 8, 10].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '판매자별현황').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + $('fFrom').value + '_' + $('fTo').value + '.xlsx');
  }

  // ---------------- 끌어서 옆으로 보기 ----------------
  /** 표 안을 마우스로 누른 채 좌우로 끌면 가로 스크롤 */
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
    window.addEventListener('mouseup', function () {
      if (!down) return;
      down = false;
      wrap.classList.remove('dragging');
    });
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var el = $('rpTable');
    if (!table || !el.offsetParent) return;
    var top = el.getBoundingClientRect().top;
    table.setHeight(Math.max(300, window.innerHeight - top - 30));
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    setRange('month');
    buildTable();
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); search(); };
    });
    $('ar306Search').onclick = search;
    $('fDays').addEventListener('input', function () { this.value = this.value.replace(/[^\d]/g, ''); });
    $('fDays').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); dragScroll(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
