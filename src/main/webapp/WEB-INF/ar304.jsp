<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>월별 매출</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 월별 매출 (ar304) ===== */
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
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  #rpTable .tabulator-calcs-holder .tabulator-cell { white-space: normal; padding-top: 4px; padding-bottom: 4px; }
  .foot-sum { font-weight: 800; }
  .foot-avg { font-weight: 700; color: #1f6fd1; border-top: 1px dashed #cbd2dc; margin-top: 3px; padding-top: 3px; }
  .ym { font-weight: 700; color: var(--navy); }
  .minus { color: #d63939; }
  .share { display: flex; align-items: center; gap: 6px; justify-content: flex-end; }
  .share .bar { flex: 1 1 auto; max-width: 60px; height: 6px; border-radius: 3px; background: #e9eef6; overflow: hidden; }
  .share .bar i { display: block; height: 100%; background: #1f6fd1; }
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
        <h6>월별 매출</h6>
        <div class="sub" id="headInfo">기간을 정하고 조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">기간</span>
        <input type="date" class="form-control form-control-sm" id="fFrom" style="width:138px">
        <span>~</span>
        <input type="date" class="form-control form-control-sm" id="fTo" style="width:138px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-range="month">이번달</button>
          <button type="button" class="btn btn-outline-secondary" data-range="prev">지난달</button>
          <button type="button" class="btn btn-outline-secondary" data-range="year">올해</button>
        </div>
        <span class="lbl">담당자</span>
        <input type="text" class="form-control form-control-sm" id="fManager" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">판매자</span>
        <select class="form-select form-select-sm" id="fPruser"><option value="">전체</option></select>
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar304Search">조회</button>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">판매</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">이익</div><div class="v profit" id="sProfit">0</div></div>
        <div><div class="k">이익율</div><div class="v" id="sRate">0%</div></div>
        <div><div class="k">등록수</div><div class="v" id="sNew">0</div></div>
        <div><div class="k">방문수</div><div class="v" id="sVisit">0</div></div>
        <div><div class="k">객단가</div><div class="v" id="sAvg">0</div></div>
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
 * 월별 매출 (ar304) — MC20_MST + member, 로그인 매장, KIND = '매출'
 *   - 년월     = member.prdate 앞 6자리
 *   - 판매     = AMT - SALEAMT - BONUSUSE
 *   - 판매비중 = 판매 × 100 ÷ 판매합계
 *   - 이익     = 판매 - 원가(INAMT)
 *   - %        = 이익 × 100 ÷ 판매
 *   - 이익비중 = 이익 × 100 ÷ 이익합계
 *   - 등록비중 = 등록수 × 100 ÷ 방문수
 *   - 객단가   = 판매 ÷ 방문수
 *   - 하단     = 합계 / 평균(합계 ÷ 월 수) 두 줄
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar304';
  var table = null, rows = [], total = null, avg = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function pct(n) { return (Math.round(Number(n || 0) * 10) / 10).toFixed(1) + '%'; }
  function cnt(n) { n = Number(n || 0); return Number.isInteger(n) ? n.toLocaleString('ko-KR') : (Math.round(n * 10) / 10).toFixed(1); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function ym(s) { s = String(s || ''); return s.length === 6 ? s.substr(0, 4) + '-' + s.substr(4) : (s || '(없음)'); }
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
  function derive(r, t, share) {
    r.profit     = r.saleamt - r.inamt;
    r.saleRate   = share != null ? share : div(r.saleamt * 100, t.saleamt);
    r.profitPct  = div(r.profit * 100, r.saleamt);
    r.profitRate = share != null ? share : div(r.profit * 100, t.profit);
    r.newRate    = div(r.newmember * 100, r.visitcnt);
    r.perVisit   = div(r.saleamt, r.visitcnt);
    return r;
  }
  function calc(list) {
    var t = { inamt: 0, saleamt: 0, visitcnt: 0, newmember: 0 };
    list.forEach(function (r) {
      ['inamt', 'saleamt', 'visitcnt', 'newmember'].forEach(function (k) { r[k] = Number(r[k] || 0); t[k] += r[k]; });
    });
    t.profit = t.saleamt - t.inamt;
    list.forEach(function (r) { derive(r, t); });
    var n = list.length;
    total = derive(t, t, n ? 100 : 0);
    avg = derive({
      inamt: div(t.inamt, n), saleamt: div(t.saleamt, n),
      visitcnt: div(t.visitcnt, n), newmember: div(t.newmember, n)
    }, t, n ? 100 / n : 0);
  }

  // ---------------- 기간 ----------------
  function setRange(kind) {
    var d = new Date();
    if (kind === 'month') { $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth(), 1)); $('fTo').value = ymd(d); }
    if (kind === 'prev') {
      $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth() - 1, 1));
      $('fTo').value = ymd(new Date(d.getFullYear(), d.getMonth(), 0));
    }
    if (kind === 'year') { $('fFrom').value = ymd(new Date(d.getFullYear(), 0, 1)); $('fTo').value = ymd(d); }
  }

  // ---------------- 목록 ----------------
  function money(v) { return '<span class="' + (v < 0 ? 'minus' : '') + '">' + won(v) + '</span>'; }
  function shareBar(v, cls) {
    return '<div class="share"><span class="bar"><i class="' + (cls || '') + '" style="width:' + Math.max(0, Math.min(100, v)) + '%"></i></span>' + pct(v) + '</div>';
  }
  /** 하단 두 줄 : 합계 / 평균 */
  function foot(field, fmt) {
    return {
      bottomCalc: function () { return total ? field : ''; },
      bottomCalcFormatter: function (c) {
        if (!total) return '';
        return '<div class="foot-sum">' + fmt(total[field]) + '</div><div class="foot-avg">' + fmt(avg[field]) + '</div>';
      }
    };
  }
  function col(title, field, width, fmt, cellFmt) {
    var f = foot(field, fmt);
    return {
      title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
      formatter: function (c) { return (cellFmt || fmt)(c.getValue()); },
      bottomCalc: f.bottomCalc, bottomCalcFormatter: f.bottomCalcFormatter
    };
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 매출이 없어요.',
      columns: [
        { title: '년월', field: 'yymm', minWidth: 90, hozAlign: 'center', headerHozAlign: 'center', sorter: 'string',
          formatter: function (c) { return '<span class="ym">' + esc(ym(c.getValue())) + '</span>'; },
          bottomCalc: function () { return total ? 'x' : ''; },
          bottomCalcFormatter: function () { return total ? '<div class="foot-sum">합계</div><div class="foot-avg">평균</div>' : ''; } },
        col('판매',   'saleamt',    120, won, function (v) { return '<b>' + money(v) + '</b>'; }),
        col('비중',   'saleRate',   120, pct, function (v) { return shareBar(v); }),
        col('이익',   'profit',     120, won, function (v) { return '<b class="' + (v < 0 ? 'minus' : 'text-success') + '">' + won(v) + '</b>'; }),
        col('%',      'profitPct',   80, pct),
        col('비중',   'profitRate', 120, pct, function (v) { return shareBar(v, 'g'); }),
        col('등록수', 'newmember',   90, cnt),
        col('방문수', 'visitcnt',    90, cnt),
        col('비중',   'newRate',     80, pct),
        col('객단가', 'perVisit',   100, won)
      ]
    });
  }

  function search() {
    var p = { from: $('fFrom').value, to: $('fTo').value, manager: $('fManager').value.trim(), pruser: $('fPruser').value.trim() };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar304Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = list || [];
        calc(rows);
        table.setData(rows);
        setTimeout(function () { table.redraw(true); fit(); }, 0);
        $('sAmt').textContent = won(total.saleamt);
        $('sProfit').textContent = won(total.profit);
        $('sRate').textContent = pct(total.profitPct);
        $('sNew').textContent = cnt(total.newmember);
        $('sVisit').textContent = cnt(total.visitcnt);
        $('sAvg').textContent = won(total.perVisit);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>'
                                + (p.manager ? ' · 담당 ' + esc(p.manager) : '')
                                + (p.pruser ? ' · 판매자 ' + esc(p.pruser) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar304Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var head = ['년월', '판매', '판매비중(%)', '이익', '이익율(%)', '이익비중(%)', '등록수', '방문수', '등록비중(%)', '객단가'];
    var line = function (label, r) {
      return [label, Math.round(r.saleamt), r1(r.saleRate), Math.round(r.profit), r1(r.profitPct), r1(r.profitRate),
              r1(r.newmember), r1(r.visitcnt), r1(r.newRate), Math.round(r.perVisit)];
    };
    var data = rows.map(function (r) { return line(ym(r.yymm), r); });
    data.push(line('합계', total));
    data.push(line('평균', avg));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!cols'] = [10, 14, 11, 14, 10, 11, 9, 9, 11, 11].map(function (w) { return { wch: w }; });
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, '월별매출');
    XLSX.writeFile(wb, '월별매출_' + $('fFrom').value + '_' + $('fTo').value + '.xlsx');
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
    $('ar304Search').onclick = search;
    $('fManager').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('fPruser').onchange = search;
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); loadInit().catch(fail).then(search); });
  }

  // ---------------- 검색 옵션 ----------------
  function loadInit() {
    return api('/init').then(function (d) {
      var opt = function (n) { return '<option>' + esc(n) + '</option>'; };
      var uniq = function (list) {             // 공백 제거 후 중복 제거
        var seen = {};
        return (list || []).map(function (n) { return String(n || '').trim(); })
          .filter(function (n) { if (!n || seen[n]) return false; seen[n] = 1; return true; });
      };
      $('fPruser').insertAdjacentHTML('beforeend', uniq(d.staff).map(opt).join(''));
    });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
