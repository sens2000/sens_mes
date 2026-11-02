<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품별 수불 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제품별 수불 현황 (ar403) ===== */
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
  @media (max-width: 1100px) { .sum-bar { grid-template-columns: repeat(4, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }

  /* 제조회사별 묶기 : 제조회사 칸 병합 표 (실적현황과 같은 방식) */
  .merge-wrap { overflow: auto; }
  table.merge { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
  table.merge th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); padding: 9px 10px; font-weight: 700;
                   border-bottom: 1px solid #cfd6e2; white-space: nowrap; text-align: left; }
  table.merge th.in-out { background: #dfe7f3; }
  table.merge td { padding: 7px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
  table.merge .r { text-align: right; }
  table.merge .c { text-align: center; }
  table.merge td.mk { text-align: center; vertical-align: top; padding: 0; font-weight: 800; color: var(--navy);
                      background: #f4f7fc; border-right: 1px solid #cfd6e2; border-bottom: 2px solid #b9c5d8; }
  /* 제조회사 이름 : 칸 맨 위에서 시작해 스크롤하면 머리글 바로 아래에 붙어 따라옴 */
  table.merge td.mk .in { position: sticky; top: 38px; padding: 8px 6px; background: #f4f7fc; white-space: normal; }
  table.merge tr.sub td:not(.mk) { background: #f7f9fc; font-weight: 700; border-bottom: 2px solid #b9c5d8; }
  table.merge tr.sub td.lbl { color: var(--muted); }
  table.merge tfoot td { position: sticky; bottom: 0; background: #e9eef7; font-weight: 800; border-top: 1px solid #b9c5d8; }
  table.merge tbody tr.item:hover td:not(.mk) { background: #f0f5ff; }

  .maker { color: var(--muted); }
  .code  { color: var(--muted); font-size: 12px; }
  .pname { font-weight: 600; }
  .minus { color: #d63939; }
  .zero  { color: #c3c9d3; }
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
        <h6>제품별 수불 현황</h6>
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
        <span class="lbl">제조회사</span>
        <input type="text" class="form-control form-control-sm enter" id="fMakecust" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">브랜드</span>
        <input type="text" class="form-control form-control-sm enter" id="fBrand" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">제품명</span>
        <input type="text" class="form-control form-control-sm enter" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:140px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar403Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="fGroup" checked>
          <label class="form-check-label small" for="fGroup">제조회사별 묶기</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">품목수</div><div class="v" id="sCnt">0</div></div>
        <div><div class="k">이월</div><div class="v" id="sEwol">0</div></div>
        <div><div class="k">매입</div><div class="v" id="sIn">0</div></div>
        <div><div class="k">판매</div><div class="v" id="sMc">0</div></div>
        <div><div class="k">판매금액</div><div class="v" id="sMcAmt">0</div></div>
        <div><div class="k">재고</div><div class="v" id="sJego">0</div></div>
        <div><div class="k">재고금액</div><div class="v main" id="sJegoAmt">0</div></div>
      </div>
      <div id="rpTable"></div>
      <!-- 제조회사별 묶기 : 제조회사 칸 병합 표 -->
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
 * 제품별 수불 현황 (ar403) — SHOP_JEPM_MST + 매입(IP01) + 매출·직판(MC20) + 기타(MC27)
 *   - 이월 + 매입 - 판매 - 기타 - 직판 = 재고 (종료일 기준)
 *   - 재고금액 = 재고 × 매입가
 *   - 제조회사별 묶기 : 제조회사 칸 병합 + 소계 (수량·금액 칸)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar403';
  // 소계·합계를 내는 칸
  var SUMS = ['ewol', 'inqty', 'mcqty', 'mcamt', 'etcqty', 'jikqty', 'jego', 'jegoAmt'];
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

  function sumOf(list) {
    var s = { cnt: list.length };
    SUMS.forEach(function (k) { s[k] = 0; });
    list.forEach(function (r) { SUMS.forEach(function (k) { s[k] += r[k] || 0; }); });
    return s;
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

  // ---------------- 한 줄 목록 (묶기 끔) ----------------
  function money(v) { return '<span class="' + (v < 0 ? 'minus' : (Math.round(v) === 0 ? 'zero' : '')) + '">' + won(v) + '</span>'; }
  function txt(title, field, width, cls, extra) {
    var c = { title: title, field: field, minWidth: width, sorter: 'string',
              formatter: function (x) { return '<span class="' + (cls || '') + '">' + esc(x.getValue()) + '</span>'; } };
    for (var k in (extra || {})) c[k] = extra[k];
    return c;
  }
  function num(title, field, width, bold) {
    var c = { title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
              formatter: function (x) { return bold ? '<b>' + money(x.getValue()) + '</b>' : money(x.getValue()); } };
    if (SUMS.indexOf(field) >= 0) {
      c.bottomCalc = function (values) { return values.reduce(function (t, v) { return t + (Number(v) || 0); }, 0); };
      c.bottomCalcFormatter = function (x) { return won(x.getValue()); };
    }
    return c;
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 제품이 없어요.',
      columns: [
        txt('제조회사', 'makecust', 100, 'maker', {
          bottomCalc: function (values) { return values.length; },
          bottomCalcFormatter: function (x) { return x.getValue() ? '합계 ' + won(x.getValue()) + '품목' : ''; } }),
        txt('브랜드',   'brand',     90, 'maker'),
        txt('제품코드', 'jepmcd',   110, 'code'),
        txt('제품명',   'jepmnm',   180, 'pname'),
        num('정가',     'price',     80),
        num('매입가',   'inprice',   80),
        num('이월',     'ewol',      70),
        num('매입',     'inqty',     70),
        num('판매',     'mcqty',     70),
        num('판매금액', 'mcamt',    100),
        num('기타',     'etcqty',    60),
        num('직판',     'jikqty',    60),
        num('재고',     'jego',      70, true),
        num('재고금액', 'jegoAmt',  100, true)
      ]
    });
  }

  // ---------------- 제조회사별 묶기 (병합 표) ----------------
  var NONE = '(제조회사 없음)';
  function groups() {
    var out = [], by = {};
    rows.forEach(function (r) {
      var k = r.makecust || NONE;
      if (!by[k]) { by[k] = { name: k, rows: [] }; out.push(by[k]); }
      by[k].rows.push(r);
    });
    return out.filter(function (g) { return g.name !== NONE; }).concat(out.filter(function (g) { return g.name === NONE; }));
  }
  function td(v, bold) {
    var cls = 'r' + (v < 0 ? ' minus' : (Math.round(v) === 0 ? ' zero' : ''));
    return '<td class="' + cls + '">' + (bold ? '<b>' + won(v) + '</b>' : won(v)) + '</td>';
  }
  /** 이월 | 매입 | 판매 | 판매금액 | 기타 | 직판 | 재고 | 재고금액 */
  function qtyTds(r, bold) {
    return td(r.ewol, bold) + td(r.inqty, bold) + td(r.mcqty, bold) + td(r.mcamt, bold)
         + td(r.etcqty, bold) + td(r.jikqty, bold) + td(r.jego, true) + td(r.jegoAmt, true);
  }
  function drawMerged() {
    var html = '<thead><tr><th class="c" style="width:110px">제조회사</th><th>브랜드</th><th>제품코드</th><th>제품명</th>'
             + '<th class="r">정가</th><th class="r">매입가</th>'
             + ['이월', '매입', '판매', '판매금액', '기타', '직판', '재고', '재고금액']
                 .map(function (h) { return '<th class="r in-out">' + h + '</th>'; }).join('')
             + '</tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="14" class="c text-muted py-5">조회된 제품이 없어요.</td></tr>';
    gs.forEach(function (g) {
      g.rows.forEach(function (r, i) {
        html += '<tr class="item">'
              + (i === 0 ? '<td class="mk" rowspan="' + (g.rows.length + 1) + '"><div class="in">' + esc(g.name) + '</div></td>' : '')
              + '<td class="maker">' + esc(r.brand) + '</td>'
              + '<td class="code">' + esc(r.jepmcd) + '</td>'
              + '<td class="pname">' + esc(r.jepmnm) + '</td>'
              + td(r.price) + td(r.inprice) + qtyTds(r) + '</tr>';
      });
      html += '<tr class="sub"><td class="lbl" colspan="5">소계 · ' + won(g.rows.length) + '품목</td>' + qtyTds(sumOf(g.rows), true) + '</tr>';
    });
    html += '</tbody>';
    if (rows.length) {
      html += '<tfoot><tr><td class="c">합계</td><td colspan="5">' + won(gs.length) + '개 제조회사 · ' + won(rows.length) + '품목</td>'
            + qtyTds(total, true) + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
  }

  /** 묶기면 병합 표, 아니면 한 줄 목록(정렬 가능) */
  function draw() {
    var grouped = $('fGroup').checked;
    $('rpTable').classList.toggle('d-none', grouped);
    $('mergeWrap').classList.toggle('d-none', !grouped);
    if (grouped) drawMerged();
    else { table.setData(rows); setTimeout(function () { table.redraw(true); fit(); }, 0); }
    fit();
  }

  function search() {
    var p = {
      from: $('fFrom').value, to: $('fTo').value,
      makecust: $('fMakecust').value.trim(), brand: $('fBrand').value.trim(), jepmnm: $('fJepmnm').value.trim()
    };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar403Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = (list || []).map(function (r) {
          ['price', 'inprice', 'saleprice', 'ewol', 'inqty', 'inamt', 'mcqty', 'mcamt', 'etcqty', 'jikqty', 'jego']
            .forEach(function (k) { r[k] = Number(r[k] || 0); });
          r.jegoAmt = r.jego * r.inprice;          // 재고금액 = 재고 × 매입가
          return r;
        });
        total = sumOf(rows);
        cond = p;
        draw();
        $('sCnt').textContent = won(rows.length);
        $('sEwol').textContent = won(total.ewol);
        $('sIn').textContent = won(total.inqty);
        $('sMc').textContent = won(total.mcqty);
        $('sMcAmt').textContent = won(total.mcamt);
        $('sJego').textContent = won(total.jego);
        $('sJegoAmt').textContent = won(total.jegoAmt);
        var c = [p.makecust && '제조 ' + p.makecust, p.brand && '브랜드 ' + p.brand, p.jepmnm && '제품 ' + p.jepmnm].filter(Boolean);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>' + (c.length ? ' · ' + esc(c.join(' · ')) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar403Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var head = ['제조회사', '브랜드', '제품코드', '제품명', '정가', '매입가', '이월', '매입', '판매', '판매금액', '기타', '직판', '재고', '재고금액'];
    var nums = function (r) { return [r.ewol, r.inqty, r.mcqty, r.mcamt, r.etcqty, r.jikqty, r.jego, r.jegoAmt]; };
    var line = function (r) { return [r.makecust, r.brand, r.jepmcd, r.jepmnm, r.price, r.inprice].concat(nums(r)); };
    var data = [], merges = [];
    if ($('fGroup').checked) {                   // 제조회사 칸 병합 + 소계
      groups().forEach(function (g) {
        var start = data.length + 1;             // 0 행은 제목
        g.rows.forEach(function (r, i) { var l = line(r); l[0] = i === 0 ? g.name : ''; data.push(l); });
        data.push(['', '소계 ' + g.rows.length + '품목', '', '', '', ''].concat(nums(sumOf(g.rows))));
        merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
      });
    } else {
      data = table.getData('active').map(line);  // 화면 정렬 순서 그대로
    }
    data.push(['합계 ' + rows.length + '품목', '', '', '', '', ''].concat(nums(total)));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    if (merges.length) ws['!merges'] = merges;
    ws['!cols'] = [14, 12, 14, 28, 9, 9, 8, 8, 8, 12, 7, 7, 8, 12].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제품별수불현황').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + (cond ? cond.from + '_' + cond.to : '') + '.xlsx');
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var w = $('mergeWrap');
    if (w.offsetParent) w.style.height = Math.max(300, window.innerHeight - w.getBoundingClientRect().top - 30) + 'px';
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
    $('ar403Search').onclick = search;
    document.querySelectorAll('input.enter').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    $('fGroup').onchange = draw;
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
