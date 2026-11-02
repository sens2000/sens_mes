<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>등급별 매출</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 등급별 매출 (ar303) ===== */
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
  .grade { display: inline-block; padding: 0 9px; border-radius: 9px; font-size: 12px; font-weight: 700; border: 1px solid #cbd2dc; color: #4a5568; background: #fff; }
  .grade-GOLD   { color: #9a6b00; background: #fff4d1; border-color: #e7b93c; }
  .grade-SILVER { color: #56606e; background: #eef0f3; border-color: #aab2bd; }
  .grade-YELLO, .grade-YELLOW { color: #8a6d00; background: #fffbd6; border-color: #e6cf3a; }
  .grade-GREEN  { color: #1f7a4d; background: #e3f5ea; border-color: #5cbf8a; }
  .grade-기타   { color: #6b7686; background: #f4f5f7; border-color: #d5d9e0; }
  .minus { color: #d63939; }
  .share { display: flex; align-items: center; gap: 6px; justify-content: flex-end; }
  .share .bar { flex: 1 1 auto; max-width: 70px; height: 6px; border-radius: 3px; background: #e9eef6; overflow: hidden; }
  .share .bar i { display: block; height: 100%; background: #1f6fd1; }

  .merge-wrap { overflow: auto; }
  table.merge { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
  table.merge th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); padding: 9px 10px; font-weight: 700;
                   border-bottom: 1px solid #cfd6e2; white-space: nowrap; }
  table.merge td { padding: 8px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
  table.merge .r { text-align: right; }
  table.merge .c { text-align: center; }
  table.merge td.mgr { text-align: center; vertical-align: middle; font-weight: 800; color: var(--navy);
                       background: #f4f7fc; border-right: 1px solid #cfd6e2; border-bottom: 2px solid #b9c5d8; }
  table.merge tr.sub td { background: #f7f9fc; font-weight: 700; border-bottom: 2px solid #b9c5d8; }
  table.merge tr.sub td.lbl { color: var(--muted); text-align: center; }
  table.merge tfoot td { position: sticky; bottom: 0; background: #e9eef7; font-weight: 800; border-top: 1px solid #b9c5d8; }
  table.merge tbody tr:not(.sub):hover td:not(.mgr) { background: #f0f5ff; }
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
        <h6>등급별 매출</h6>
        <div class="sub" id="headInfo">기간을 정하고 조회하세요</div>
      </div>
      <div class="filter">
        <div class="btn-group btn-group-sm me-2" role="group" title="보기">
          <input type="radio" class="btn-check" name="fMode" id="mGrade" value="grade" checked>
          <label class="btn btn-outline-primary" for="mGrade">등급별</label>
          <input type="radio" class="btn-check" name="fMode" id="mManager" value="manager">
          <label class="btn btn-outline-primary" for="mManager">담당자별</label>
        </div>
        <span class="lbl ms-0">기간</span>
        <input type="date" class="form-control form-control-sm" id="fFrom" style="width:138px">
        <span>~</span>
        <input type="date" class="form-control form-control-sm" id="fTo" style="width:138px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-range="today">오늘</button>
          <button type="button" class="btn btn-outline-secondary" data-range="month">이번달</button>
          <button type="button" class="btn btn-outline-secondary" data-range="prev">지난달</button>
        </div>
        <span class="lbl">담당자</span>
        <input type="text" class="form-control form-control-sm" id="fManager" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar303Search">조회</button>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">매출금액</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">이익</div><div class="v profit" id="sProfit">0</div></div>
        <div><div class="k">이익율</div><div class="v" id="sRate">0%</div></div>
        <div><div class="k">회원수</div><div class="v" id="sMem">0</div></div>
        <div><div class="k">방문수</div><div class="v" id="sVisit">0</div></div>
        <div><div class="k">객단가</div><div class="v" id="sAvg">0</div></div>
      </div>
      <div id="rpTable"></div>
      <!-- 담당자별 : 담당 칸 병합 표 -->
      <div class="merge-wrap d-none" id="mergeWrap"><table class="merge" id="mergeTable"></table></div>
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
 * 등급별 매출 (ar303) — MC20_MST + member, 로그인 매장, KIND = '매출'
 *   - 이익   = 매출 - 원가(INAMT)
 *   - 이익율 = 이익 × 100 ÷ 매출
 *   - 객단가 = 매출 ÷ 방문수
 *   - 비중   = 매출 ÷ 총매출 × 100
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar303';
  var table = null, rows = [], total = null;
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
  /** 이익·이익율·객단가·비중 채우기 */
  var SUMS = ['inamt', 'amt', 'cash', 'card', 'sale', 'visit', 'memcnt'];
  /** 금액·방문·회원수 합계 + 총회원(등급별 인원이라 같은 등급은 한 번만) */
  function sumOf(list) {
    var t = { memtot: 0 }, seen = {};
    SUMS.forEach(function (k) { t[k] = 0; });
    list.forEach(function (r) {
      SUMS.forEach(function (k) { t[k] += r[k] || 0; });
      if (!seen[r.grade]) { seen[r.grade] = 1; t.memtot += r.memtot || 0; }
    });
    return t;
  }
  function derive(r, totalAmt) {
    r.profit = r.amt - r.inamt;
    r.rate   = r.amt ? r.profit * 100 / r.amt : 0;
    r.avg    = r.visit ? r.amt / r.visit : 0;
    r.share  = totalAmt ? r.amt * 100 / totalAmt : 0;
    return r;
  }
  function calc(list) {
    var t = sumOf(list);
    t.grade = '합계';
    list.concat([t]).forEach(function (r) {
      r.profit = r.amt - r.inamt;
      r.rate   = r.amt ? r.profit * 100 / r.amt : 0;
      r.avg    = r.visit ? r.amt / r.visit : 0;
      r.share  = t.amt ? r.amt * 100 / t.amt : 0;
    });
    return t;
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
  function money(c) { var v = c.getValue(); return '<span class="' + (v < 0 ? 'minus' : '') + '">' + won(v) + '</span>'; }
  /** 합계줄 : 계산해 둔 total 값 사용 */
  function totCalc(field, fmt) {
    return { bottomCalc: function () { return total ? total[field] : ''; }, bottomCalcFormatter: function (c) { return c.getValue() === '' ? '' : fmt(c.getValue()); } };
  }
  function col(title, field, width, fmt, cellFmt) {
    var c = { title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right', formatter: cellFmt || function (x) { return fmt(x.getValue()); } };
    var tc = totCalc(field, fmt);
    c.bottomCalc = tc.bottomCalc; c.bottomCalcFormatter = tc.bottomCalcFormatter;
    return c;
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 매출이 없어요.',
      columns: [
        { title: '등급', field: 'grade', minWidth: 90, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { var g = c.getValue(); return '<span class="grade grade-' + esc(g) + '">' + esc(g || '(없음)') + '</span>'; },
          bottomCalc: function () { return '합계'; } },
        col('매출금액', 'amt', 120, won, function (c) { return '<b>' + money(c) + '</b>'; }),
        col('현금', 'cash', 110, won, money),
        col('카드', 'card', 110, won, money),
        col('할인', 'sale', 100, won, money),
        col('이익', 'profit', 110, won, function (c) { return '<span class="' + (c.getValue() < 0 ? 'minus' : 'text-success') + ' fw-bold">' + won(c.getValue()) + '</span>'; }),
        col('이익율', 'rate', 100, pct),
        col('총회원', 'memtot', 100, won),
        col('회원수', 'memcnt', 100, won),
        col('방문수', 'visit', 100, won),
        col('객단가', 'avg', 100, won),
        col('비중', 'share', 135, pct, function (c) {
          var v = c.getValue();
          return '<div class="share"><span class="bar"><i style="width:' + Math.max(0, Math.min(100, v)) + '%"></i></span>' + pct(v) + '</div>';
        })
      ]
    });
  }

  function mode() { return $('mManager').checked ? 'manager' : 'grade'; }
  var NO_MGR = '(담당 없음)';

  /** 담당자별 묶음 [{ name, rows }] — 서버에서 담당·등급 순으로 옴 */
  function mgrGroups() {
    var out = [];
    rows.forEach(function (r) {
      var n = r.manager || NO_MGR, g = out[out.length - 1];
      if (!g || g.name !== n) out.push(g = { name: n, rows: [] });
      g.rows.push(r);
    });
    // 담당 없음은 맨 뒤로
    return out.filter(function (g) { return g.name !== NO_MGR; }).concat(out.filter(function (g) { return g.name === NO_MGR; }));
  }
  function gradeBadge(g) { return '<span class="grade grade-' + esc(g) + '">' + esc(g || '(없음)') + '</span>'; }
  function td(v, f, cls) { return '<td class="r' + (cls ? ' ' + cls : '') + (v < 0 ? ' minus' : '') + '">' + f(v) + '</td>'; }
  function numCells(r, isSum) {
    return td(r.amt, function (v) { return '<b>' + won(v) + '</b>'; }) + td(r.cash, won) + td(r.card, won) + td(r.sale, won)
         + td(r.profit, function (v) { return '<b class="' + (v < 0 ? '' : 'text-success') + '">' + won(v) + '</b>'; })
         + td(r.rate, pct)
         + (isSum === 'sub' ? '<td></td>' : td(r.memtot, won))     // 총회원은 등급 기준이라 담당 소계에는 비움
         + td(r.memcnt, won) + td(r.visit, won) + td(r.avg, won) + td(r.share, pct);
  }

  /** 담당 칸을 위아래로 합친 표 (담당 | 등급들 … | 소계) */
  function drawMerged() {
    var html = '<thead><tr><th class="c" style="width:110px">담당</th><th class="c">등급</th>'
             + ['매출금액', '현금', '카드', '할인', '이익', '이익율', '총회원', '회원수', '방문수', '객단가', '비중']
                 .map(function (h) { return '<th class="r">' + h + '</th>'; }).join('') + '</tr></thead><tbody>';
    var gs = mgrGroups();
    if (!gs.length) html += '<tr><td colspan="13" class="c text-muted py-5">조회된 매출이 없어요.</td></tr>';
    gs.forEach(function (g) {
      g.rows.forEach(function (r, i) {
        html += '<tr>' + (i === 0 ? '<td class="mgr" rowspan="' + (g.rows.length + 1) + '">' + esc(g.name) + '</td>' : '')
              + '<td class="c">' + gradeBadge(r.grade) + '</td>' + numCells(r) + '</tr>';
      });
      var s = derive(sumOf(g.rows), total.amt);
      html += '<tr class="sub"><td class="lbl">소계</td>' + numCells(s, 'sub') + '</tr>';
    });
    html += '</tbody><tfoot><tr><td class="c">합계</td><td></td>' + numCells(total) + '</tr></tfoot>';
    $('mergeTable').innerHTML = html;
  }

  function draw() {
    var byMgr = mode() === 'manager';
    $('rpTable').classList.toggle('d-none', byMgr);
    $('mergeWrap').classList.toggle('d-none', !byMgr);
    if (byMgr) drawMerged();
    else { table.setData(rows); setTimeout(function () { table.redraw(true); fit(); }, 0); }
    fit();
  }

  function search() {
    var p = { from: $('fFrom').value, to: $('fTo').value, manager: $('fManager').value.trim(), mode: mode() };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar303Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = list || [];
        total = calc(rows);
        draw();
        $('sAmt').textContent = won(total.amt);
        $('sProfit').textContent = won(total.profit);
        $('sRate').textContent = pct(total.rate);
        $('sMem').textContent = won(total.memcnt);
        $('sVisit').textContent = won(total.visit);
        $('sAvg').textContent = won(total.avg);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b> · ' + (p.mode === 'manager' ? '담당자별' : '등급별')
                                + (p.manager ? ' · 담당 ' + esc(p.manager) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar303Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var head = ['등급', '매출금액', '현금', '카드', '할인', '이익', '이익율(%)', '총회원', '회원수', '방문수', '객단가', '비중(%)'];
    var nums = function (r, sub) {
      return [r.amt, r.cash, r.card, r.sale, r.profit, r1(r.rate), sub ? '' : r.memtot, r.memcnt, r.visit, Math.round(r.avg), r1(r.share)];
    };
    var byMgr = mode() === 'manager', data = [], merges = [], title = byMgr ? '담당자별매출' : '등급별매출';
    if (byMgr) {                                  // 담당 칸 병합 + 담당 소계
      head = ['담당'].concat(head);
      mgrGroups().forEach(function (g) {
        var start = data.length + 1;
        g.rows.forEach(function (r, i) { data.push([i === 0 ? g.name : '', r.grade].concat(nums(r))); });
        data.push(['', '소계'].concat(nums(derive(sumOf(g.rows), total.amt), true)));
        merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
      });
      data.push(['합계', ''].concat(nums(total)));
    } else {
      data = rows.map(function (r) { return [r.grade].concat(nums(r)); });
      data.push(['합계'].concat(nums(total)));
    }
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    if (merges.length) ws['!merges'] = merges;
    ws['!cols'] = (byMgr ? [12] : []).concat([10, 13, 12, 12, 11, 12, 9, 8, 8, 8, 10, 8]).map(function (w) { return { wch: w }; });
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title);
    XLSX.writeFile(wb, title + '_' + $('fFrom').value + '_' + $('fTo').value + '.xlsx');
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var w = $('mergeWrap');
    if (w.offsetParent) w.style.height = Math.max(300, window.innerHeight - w.getBoundingClientRect().top - 30) + 'px';
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
    $('ar303Search').onclick = search;
    $('fManager').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('btnExcel').onclick = excel;
    document.querySelectorAll('input[name=fMode]').forEach(function (r) { r.onchange = search; });
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
