<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>적정재고 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 적정재고 현황 (ar402) ===== */
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

  .filter { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 8px 14px; }
  .filter + .filter { padding-top: 0; }
  .filter-wrap { border-bottom: 1px solid var(--line); padding: 2px 0; }
  .filter .lbl { font-size: 12px; color: var(--muted); margin-left: 6px; }

  /* 요약 : 상태별 카드 (누르면 그 상태만 보기) */
  .sum-bar { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar > div[data-st] { cursor: pointer; }
  .sum-bar > div[data-st]:hover { background: #f0f5ff; }
  .sum-bar > div.on { box-shadow: inset 0 -3px 0 var(--navy); background: #eef3fb; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v small { font-size: 12px; font-weight: 600; color: var(--muted); margin-left: 4px; }
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  /* 상태 배지 */
  .st { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; border: 1px solid; }
  .st-short { color: #c0262d; background: #fdecec; border-color: #f0a3a6; }
  .st-ok    { color: #1f7a4d; background: #e3f5ea; border-color: #5cbf8a; }
  .st-over  { color: #b25b00; background: #fff1e0; border-color: #f0b46b; }
  .st-none  { color: #6b7686; background: #f1f3f6; border-color: #cbd2dc; }
  .v.short { color: #c0262d; } .v.over { color: #b25b00; } .v.none { color: #6b7686; }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }

  /* 제조회사별 묶기 : 제조회사 칸 병합 표 (실적현황과 같은 방식) */
  .merge-wrap { overflow: auto; }
  table.merge { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
  table.merge th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); padding: 9px 10px; font-weight: 700;
                   border-bottom: 1px solid #cfd6e2; white-space: nowrap; text-align: left; }
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
  .code  { color: var(--muted); font-size: 11px; }
  .pname { font-weight: 600; }
  .minus { color: #d63939; }
  .zero  { color: #c3c9d3; }
  .need  { color: #c0262d; font-weight: 800; }
  .much  { color: #b25b00; font-weight: 800; }
  .urgent { color: #c0262d; font-weight: 700; }   /* 소진예상일 짧음 */
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
        <h6>적정재고 현황</h6>
        <div class="sub" id="headInfo">판매기간을 정하고 조회하세요</div>
      </div>
      <div class="filter-wrap">
        <div class="filter">
          <span class="lbl ms-0">판매기간</span>
          <input type="date" class="form-control form-control-sm" id="fFrom" style="width:138px">
          <span>~</span>
          <input type="date" class="form-control form-control-sm" id="fTo" style="width:138px">
          <div class="btn-group btn-group-sm">
            <button type="button" class="btn btn-outline-secondary" data-days="30">최근 30일</button>
            <button type="button" class="btn btn-outline-secondary" data-days="60">60일</button>
            <button type="button" class="btn btn-outline-secondary" data-days="90">90일</button>
          </div>
          <span class="lbl">보유일수</span>
          <input type="text" class="form-control form-control-sm text-end" id="fHold" value="30" style="width:56px" inputmode="numeric" autocomplete="off"
                 title="며칠 팔 만큼을 적정재고로 볼지 (예: 30 → 30일치)">
          <span class="small text-muted">일분</span>
          <span class="lbl">과다 기준</span>
          <select class="form-select form-select-sm" id="fOver" style="width:90px" title="적정재고의 몇 배를 넘으면 과다로 볼지">
            <option value="1.5">1.5배</option>
            <option value="2" selected>2배</option>
            <option value="3">3배</option>
          </select>
        </div>
        <div class="filter">
          <span class="lbl ms-0">제조회사</span>
          <input type="text" class="form-control form-control-sm enter" id="fMakecust" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
          <span class="lbl">브랜드</span>
          <input type="text" class="form-control form-control-sm enter" id="fBrand" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
          <span class="lbl">제품명</span>
          <input type="text" class="form-control form-control-sm enter" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:150px" autocomplete="off">
          <span class="lbl">상태</span>
          <select class="form-select form-select-sm" id="fStatus" style="width:100px">
            <option value="">전체</option>
            <option value="short">부족</option>
            <option value="ok">적정</option>
            <option value="over">과다</option>
            <option value="none">미판매</option>
          </select>
          <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar402Search">조회</button>
          <div class="form-check form-check-inline ms-2 mb-0">
            <input class="form-check-input" type="checkbox" id="fGroup" checked>
            <label class="form-check-label small" for="fGroup">제조회사별 묶기</label>
          </div>
          <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
        </div>
      </div>
      <div class="sum-bar">
        <div data-st=""><div class="k">전체 품목 · 재고금액</div><div class="v" id="sAll">0</div></div>
        <div data-st="short"><div class="k">부족 · 발주권장 금액</div><div class="v short" id="sShort">0</div></div>
        <div data-st="ok"><div class="k">적정</div><div class="v" id="sOk">0</div></div>
        <div data-st="over"><div class="k">과다 · 과다금액</div><div class="v over" id="sOver">0</div></div>
        <div data-st="none"><div class="k">미판매 · 재고금액</div><div class="v none" id="sNone">0</div></div>
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
 * 적정재고 현황 (ar402) — SHOP_JEPM_MST(현재고) + MC20(매출·직판 판매수량)
 *   - 일평균     = 기간 판매수량 ÷ 기간 일수
 *   - 적정재고   = 일평균 × 보유일수 (올림)
 *   - 소진예상일 = 현재고 ÷ 일평균
 *   - 상태 : 미판매 (판매 0 이하, 재고 있음) / 부족 (현재고 < 적정) / 과다 (현재고 > 적정 × 과다기준) / 적정
 *   - 발주권장 = 적정 - 현재고 (부족일 때),  과다재고 = 현재고 - 적정 × 과다기준 (과다), 미판매는 재고 전부
 *   - 보유일수·과다기준·상태를 바꾸면 다시 조회하지 않고 바로 계산
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar402';
  var ST = { short: '부족', ok: '적정', over: '과다', none: '미판매' };
  // 소계·합계를 내는 칸
  var SUMS = ['saleqty', 'jego', 'properqty', 'orderqty', 'orderamt', 'overqty', 'overamt', 'jegoamt'];
  var table = null, raw = [], rows = [], days = 1, cond = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function dec2(n) { return (Math.round(Number(n || 0) * 100) / 100).toFixed(2); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function toDate(s) { var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
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
  function hold()   { var v = parseInt($('fHold').value, 10); return v > 0 ? v : 30; }
  function overX()  { return Number($('fOver').value) || 2; }
  /** 서버 값(raw) → 적정재고·상태 계산 */
  function calc() {
    var h = hold(), x = overX();
    raw.forEach(function (r) {
      r.dayavg    = r.saleqty > 0 ? r.saleqty / days : 0;
      r.properqty = r.saleqty > 0 ? Math.ceil(r.dayavg * h) : 0;
      r.leftdays  = r.dayavg > 0 ? r.jego / r.dayavg : null;
      r.jegoamt   = r.jego * r.inprice;
      r.orderqty = 0; r.overqty = 0;
      if (r.saleqty <= 0)                   { r.status = r.jego > 0 ? 'none' : 'ok'; if (r.jego > 0) r.overqty = r.jego; }
      else if (r.jego < r.properqty)        { r.status = 'short'; r.orderqty = r.properqty - r.jego; }
      else if (r.jego > r.properqty * x)    { r.status = 'over';  r.overqty = r.jego - Math.ceil(r.properqty * x); }
      else                                  { r.status = 'ok'; }
      r.orderamt = r.orderqty * r.inprice;
      r.overamt  = r.overqty * r.inprice;
    });
  }
  function sumOf(list) {
    var s = { cnt: list.length };
    SUMS.forEach(function (k) { s[k] = 0; });
    list.forEach(function (r) { SUMS.forEach(function (k) { s[k] += r[k] || 0; }); });
    return s;
  }
  /** 상태 필터 적용 */
  function filtered() { var st = $('fStatus').value; return st ? raw.filter(function (r) { return r.status === st; }) : raw.slice(); }

  // ---------------- 판매기간 ----------------
  function setDays(n) {
    var d = new Date();
    $('fTo').value = ymd(d);
    $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth(), d.getDate() - n + 1));
  }

  // ---------------- 표시 형식 ----------------
  function badge(st) { return '<span class="st st-' + st + '">' + ST[st] + '</span>'; }
  function leftFmt(v, r) {
    if (v == null) return '';
    var d = Math.round(v);
    return '<span class="' + (r && r.status === 'short' ? 'urgent' : '') + '">' + won(d) + '일</span>';
  }
  function cls(v) { return v < 0 ? 'minus' : (Math.round(v) === 0 ? 'zero' : ''); }

  // ---------------- 한 줄 목록 (묶기 끔) ----------------
  function txt(title, field, width, c, extra) {
    var o = { title: title, field: field, minWidth: width, sorter: 'string',
              formatter: function (x) { return '<span class="' + (c || '') + '">' + esc(x.getValue()) + '</span>'; } };
    for (var k in (extra || {})) o[k] = extra[k];
    return o;
  }
  function num(title, field, width, fmt) {
    var o = { title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
              formatter: function (x) { var v = x.getValue(), r = x.getRow().getData();
                                        return fmt ? fmt(v, r) : '<span class="' + cls(v) + '">' + won(v) + '</span>'; } };
    if (SUMS.indexOf(field) >= 0) {
      o.bottomCalc = function (values) { return values.reduce(function (t, v) { return t + (Number(v) || 0); }, 0); };
      o.bottomCalcFormatter = function (x) { return won(x.getValue()); };
    }
    return o;
  }
  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 제품이 없어요.',
      initialSort: [{ column: 'leftdays', dir: 'asc' }],
      columns: [
        txt('제조회사', 'makecust', 100, 'maker', {
          bottomCalc: function (values) { return values.length; },
          bottomCalcFormatter: function (x) { return x.getValue() ? '합계 ' + won(x.getValue()) + '품목' : ''; } }),
        txt('브랜드',   'brand',     90, 'maker'),
        { title: '제품명', field: 'jepmnm', minWidth: 180, sorter: 'string',
          formatter: function (x) { var r = x.getRow().getData();
            return '<span class="pname">' + esc(r.jepmnm) + '</span> <span class="code">' + esc(r.jepmcd) + '</span>'; } },
        num('매입가',     'inprice',   80),
        num('기간판매',   'saleqty',   80),
        num('일평균',     'dayavg',    70, function (v) { return v ? dec2(v) : '<span class="zero">0</span>'; }),
        num('현재고',     'jego',      70, function (v) { return '<b class="' + cls(v) + '">' + won(v) + '</b>'; }),
        num('적정재고',   'properqty', 80),
        num('소진예상일', 'leftdays',  90, leftFmt),
        { title: '상태', field: 'status', width: 80, hozAlign: 'center', headerHozAlign: 'center', sorter: 'string',
          formatter: function (x) { return badge(x.getValue()); } },
        num('발주권장',   'orderqty',  80, function (v) { return v ? '<span class="need">' + won(v) + '</span>' : ''; }),
        num('과다재고',   'overqty',   80, function (v) { return v ? '<span class="much">' + won(v) + '</span>' : ''; }),
        num('과다금액',   'overamt',  100, function (v) { return v ? '<span class="much">' + won(v) + '</span>' : ''; })
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
  function td(v, html) { return '<td class="r ' + (html ? '' : cls(v)) + '">' + (html != null ? html : won(v)) + '</td>'; }
  function itemTds(r) {
    return td(r.inprice) + td(r.saleqty) + td(0, r.dayavg ? dec2(r.dayavg) : '<span class="zero">0</span>')
         + td(r.jego, '<b class="' + cls(r.jego) + '">' + won(r.jego) + '</b>') + td(r.properqty)
         + td(0, leftFmt(r.leftdays, r)) + '<td class="c">' + badge(r.status) + '</td>'
         + td(0, r.orderqty ? '<span class="need">' + won(r.orderqty) + '</span>' : '')
         + td(0, r.overqty ? '<span class="much">' + won(r.overqty) + '</span>' : '')
         + td(0, r.overamt ? '<span class="much">' + won(r.overamt) + '</span>' : '');
  }
  /** 소계·합계 : 기간판매, 현재고, 적정재고, 발주권장, 과다재고, 과다금액 */
  function sumTds(s) {
    return '<td></td>' + td(s.saleqty, '<b>' + won(s.saleqty) + '</b>') + '<td></td>'
         + td(s.jego, '<b>' + won(s.jego) + '</b>') + td(s.properqty, '<b>' + won(s.properqty) + '</b>')
         + '<td></td><td></td>'
         + td(0, s.orderqty ? '<span class="need">' + won(s.orderqty) + '</span>' : '')
         + td(0, s.overqty ? '<span class="much">' + won(s.overqty) + '</span>' : '')
         + td(0, s.overamt ? '<span class="much">' + won(s.overamt) + '</span>' : '');
  }
  function drawMerged() {
    var html = '<thead><tr><th class="c" style="width:110px">제조회사</th><th>브랜드</th><th>제품명</th>'
             + ['매입가', '기간판매', '일평균', '현재고', '적정재고', '소진예상일'].map(function (h) { return '<th class="r">' + h + '</th>'; }).join('')
             + '<th class="c">상태</th>'
             + ['발주권장', '과다재고', '과다금액'].map(function (h) { return '<th class="r">' + h + '</th>'; }).join('')
             + '</tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="13" class="c text-muted py-5">조회된 제품이 없어요.</td></tr>';
    gs.forEach(function (g) {
      g.rows.forEach(function (r, i) {
        html += '<tr class="item">'
              + (i === 0 ? '<td class="mk" rowspan="' + (g.rows.length + 1) + '"><div class="in">' + esc(g.name) + '</div></td>' : '')
              + '<td class="maker">' + esc(r.brand) + '</td>'
              + '<td><span class="pname">' + esc(r.jepmnm) + '</span> <span class="code">' + esc(r.jepmcd) + '</span></td>'
              + itemTds(r) + '</tr>';
      });
      html += '<tr class="sub"><td class="lbl" colspan="2">소계 · ' + won(g.rows.length) + '품목</td>' + sumTds(sumOf(g.rows)) + '</tr>';
    });
    html += '</tbody>';
    if (rows.length) {
      html += '<tfoot><tr><td class="c">합계</td><td colspan="2">' + won(gs.length) + '개 제조회사 · ' + won(rows.length) + '품목</td>'
            + sumTds(sumOf(rows)) + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
  }

  /** 계산 → 상태 필터 → 요약·표 */
  function draw() {
    calc();
    rows = filtered();
    // 요약 (상태 필터와 상관없이 전체 기준)
    var by = { short: [], ok: [], over: [], none: [] };
    raw.forEach(function (r) { by[r.status].push(r); });
    var all = sumOf(raw);
    $('sAll').innerHTML   = won(raw.length) + '<small>품목</small> ' + won(all.jegoamt);
    $('sShort').innerHTML = won(by.short.length) + '<small>품목</small> ' + won(sumOf(by.short).orderamt);
    $('sOk').innerHTML    = won(by.ok.length) + '<small>품목</small>';
    $('sOver').innerHTML  = won(by.over.length) + '<small>품목</small> ' + won(sumOf(by.over).overamt);
    $('sNone').innerHTML  = won(by.none.length) + '<small>품목</small> ' + won(sumOf(by.none).jegoamt);
    document.querySelectorAll('.sum-bar > div[data-st]').forEach(function (el) {
      el.classList.toggle('on', el.dataset.st === $('fStatus').value);
    });

    var grouped = $('fGroup').checked;
    $('rpTable').classList.toggle('d-none', grouped);
    $('mergeWrap').classList.toggle('d-none', !grouped);
    if (grouped) drawMerged();
    else { table.setData(rows); setTimeout(function () { table.redraw(true); fit(); }, 0); }
    fit();
    if (cond) {
      $('headInfo').innerHTML = '<b>' + cond.from + ' ~ ' + cond.to + '</b> (' + days + '일) · 보유 ' + hold() + '일분 · 과다 ' + overX() + '배'
                              + ($('fStatus').value ? ' · ' + ST[$('fStatus').value] + '만' : '');
    }
  }

  function search() {
    var p = {
      from: $('fFrom').value, to: $('fTo').value,
      makecust: $('fMakecust').value.trim(), brand: $('fBrand').value.trim(), jepmnm: $('fJepmnm').value.trim()
    };
    if (!p.from || !p.to) { alert('판매기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar402Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        raw = (list || []).map(function (r) {
          ['inprice', 'jego', 'saleqty'].forEach(function (k) { r[k] = Number(r[k] || 0); });
          return r;
        });
        days = Math.round((toDate(p.to) - toDate(p.from)) / 86400000) + 1;   // 기간 일수
        cond = p;
        draw();
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar402Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var head = ['제조회사', '브랜드', '제품코드', '제품명', '매입가', '기간판매', '일평균', '현재고', '적정재고', '소진예상일',
                '상태', '발주권장', '과다재고', '과다금액'];
    var line = function (r) {
      return [r.makecust, r.brand, r.jepmcd, r.jepmnm, r.inprice, r.saleqty, Math.round(r.dayavg * 100) / 100, r.jego, r.properqty,
              r.leftdays == null ? '' : Math.round(r.leftdays), ST[r.status], r.orderqty || '', r.overqty || '', r.overamt || ''];
    };
    var sumLine = function (label, s) {
      return [label, '', '', '', '', s.saleqty, '', s.jego, s.properqty, '', '', s.orderqty, s.overqty, s.overamt];
    };
    var data = [], merges = [];
    if ($('fGroup').checked) {                   // 제조회사 칸 병합 + 소계
      groups().forEach(function (g) {
        var start = data.length + 1;             // 0 행은 제목
        g.rows.forEach(function (r, i) { var l = line(r); l[0] = i === 0 ? g.name : ''; data.push(l); });
        var sl = sumLine('', sumOf(g.rows)); sl[1] = '소계 ' + g.rows.length + '품목'; data.push(sl);
        merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
      });
    } else {
      data = table.getData('active').map(line);  // 화면 정렬 순서 그대로
    }
    data.push(sumLine('합계 ' + rows.length + '품목', sumOf(rows)));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    if (merges.length) ws['!merges'] = merges;
    ws['!cols'] = [14, 12, 14, 28, 9, 9, 8, 8, 9, 10, 7, 9, 9, 12].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '적정재고현황').replace(/\s+/g, '');
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
    setDays(90);
    buildTable();
    document.querySelectorAll('[data-days]').forEach(function (b) {
      b.onclick = function () { setDays(Number(b.dataset.days)); search(); };
    });
    $('ar402Search').onclick = search;
    document.querySelectorAll('input.enter').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    // 보유일수·과다기준·상태·묶기 : 다시 조회하지 않고 바로 계산
    $('fHold').addEventListener('input', function () { this.value = this.value.replace(/[^\d]/g, ''); if (raw.length) draw(); });
    ['fOver', 'fStatus', 'fGroup'].forEach(function (id) { $(id).onchange = function () { if (raw.length || id === 'fGroup') draw(); }; });
    // 요약 카드를 누르면 그 상태만 보기
    document.querySelectorAll('.sum-bar > div[data-st]').forEach(function (el) {
      el.onclick = function () { $('fStatus').value = el.dataset.st; draw(); };
    });
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); search(); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
