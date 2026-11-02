<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>장기재고 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 장기재고 현황 (ar404) ===== */
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

  /* 요약 : 구분별 카드 (누르면 그 구분만 보기) */
  .sum-bar { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); cursor: pointer; }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar > div:hover { background: #f0f5ff; }
  .sum-bar > div.on { box-shadow: inset 0 -3px 0 var(--navy); background: #eef3fb; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v small { font-size: 12px; font-weight: 600; color: var(--muted); margin-left: 4px; }
  .sum-bar .v.a9 { color: #8a6d00; } .sum-bar .v.a1 { color: #b25b00; } .sum-bar .v.a2 { color: #c0262d; } .sum-bar .v.a3 { color: #7a1d22; } .sum-bar .v.a0 { color: #6b7686; }
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  /* 구분 배지 */
  .ag { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; border: 1px solid; white-space: nowrap; }
  .ag-a9 { color: #8a6d00; background: #fffbd6; border-color: #e6cf3a; }   /* 판매 부진 (최근 판매 있음) */
  .ag-a1 { color: #b25b00; background: #fff1e0; border-color: #f0b46b; }   /* 3개월+ */
  .ag-a2 { color: #c0262d; background: #fdecec; border-color: #f0a3a6; }   /* 6개월+ */
  .ag-a3 { color: #fff;    background: #a3262d; border-color: #a3262d; }   /* 1년+ */
  .ag-a0 { color: #6b7686; background: #f1f3f6; border-color: #cbd2dc; }   /* 판매기록 없음 */

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
  .dt    { color: #4a5568; }
  .none  { color: #c3c9d3; }
  .long  { color: #c0262d; font-weight: 800; }
  .zero  { color: #c3c9d3; }
  .minus { color: #d63939; }
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
        <h6>장기재고 현황</h6>
        <div class="sub" id="headInfo">조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">판정</span>
        <select class="form-select form-select-sm" id="fMode" style="width:150px">
          <option value="qty" selected>판매수량 기준</option>
          <option value="last">마지막 판매일 기준</option>
        </select>
        <span class="lbl">기간</span>
        <select class="form-select form-select-sm" id="fDays" style="width:100px">
          <option value="90" selected>90일</option>
          <option value="180">180일</option>
          <option value="365">1년</option>
        </select>
        <div class="form-check form-check-inline mb-0" id="adjBox" title="기간 안에 새로 입고한 수량은 오래된 재고가 아니라고 봅니다 (먼저 들어온 것부터 팔린다는 가정)">
          <input class="form-check-input" type="checkbox" id="fAdj" checked>
          <label class="form-check-label small" for="fAdj">최근 입고 보정</label>
        </div>
        <span class="lbl">제조회사</span>
        <input type="text" class="form-control form-control-sm enter" id="fMakecust" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">브랜드</span>
        <input type="text" class="form-control form-control-sm enter" id="fBrand" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">제품명</span>
        <input type="text" class="form-control form-control-sm enter" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:150px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar404Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="fGroup" checked>
          <label class="form-check-label small" for="fGroup">제조회사별 묶기</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div data-ag=""><div class="k">장기재고 전체 · 장기재고금액</div><div class="v" id="sAll">0</div></div>
        <div data-ag="a9"><div class="k">판매 부진 (최근 판매 있음)</div><div class="v a9" id="sA9">0</div></div>
        <div data-ag="a1"><div class="k">3개월 이상</div><div class="v a1" id="sA1">0</div></div>
        <div data-ag="a2"><div class="k">6개월 이상</div><div class="v a2" id="sA2">0</div></div>
        <div data-ag="a3"><div class="k">1년 이상</div><div class="v a3" id="sA3">0</div></div>
        <div data-ag="a0"><div class="k">판매기록 없음</div><div class="v a0" id="sA0">0</div></div>
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
 * 장기재고 현황 (ar404) — 재고 있는 제품 중 기간 안에 다 못 판 재고
 *   [판매수량 기준] (기본)
 *     - 장기재고수량 = 현재고 - MAX(기간 판매수량, 기간 입고수량)    ※ 최근 입고 보정을 끄면 현재고 - 기간 판매수량
 *     - 장기재고수량이 0보다 큰 제품만 표시
 *   [마지막 판매일 기준]
 *     - 마지막 판매 후 기간이 지난 제품 (판매기록 없으면 입고 후), 장기재고수량 = 현재고 전부
 *   - 장기재고금액 = 장기재고수량 × 매입가
 *   - 구분 (마지막 판매일로) : 판매 부진(90일 안에 판매 있음) / 3개월 / 6개월 / 1년 이상 / 판매기록 없음
 *   - 판정·기간·보정을 바꾸면 다시 조회하지 않고 바로 반영
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar404';
  var AG = { a9: '판매 부진', a1: '3개월 이상', a2: '6개월 이상', a3: '1년 이상', a0: '판매기록 없음' };
  var SUMS = ['jego', 'saleq', 'inq', 'longqty', 'longamt', 'jegoamt'];
  var table = null, raw = [], rows = [], agFilter = '', cond = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function fail(e) { alert(e.message || e); }
  function dLabel(s) { s = String(s || ''); return s.length === 8 ? s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2) : ''; }
  function toDate(s) { return new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2)); }
  function isDay(s) { return /^\d{8}$/.test(s); }

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
  function days() { return Number($('fDays').value) || 90; }
  function mode() { return $('fMode').value; }
  function calc() {
    var today = new Date(); today.setHours(0, 0, 0, 0);
    var d = days(), adj = $('fAdj').checked, m = mode();
    raw.forEach(function (r) {
      var base = isDay(r.lastsale) ? r.lastsale : (isDay(r.lastin) ? r.lastin : '');
      r.basis   = isDay(r.lastsale) ? '판매' : (base ? '입고' : '');
      r.elapsed = base ? Math.round((today - toDate(base)) / 86400000) : null;
      r.saleq   = r['s' + d] || 0;                               // 기간 판매수량 (반품 차감)
      r.inq     = r['i' + d] || 0;                               // 기간 입고수량
      r.jegoamt = r.jego * r.inprice;
      if (!isDay(r.lastsale))   r.ag = 'a0';                     // 판매기록 없음
      else if (r.elapsed >= 365) r.ag = 'a3';
      else if (r.elapsed >= 180) r.ag = 'a2';
      else if (r.elapsed >= 90)  r.ag = 'a1';
      else                       r.ag = 'a9';                    // 최근 판매는 있지만 부진
      if (m === 'qty') {
        r.longqty = Math.max(0, r.jego - Math.max(r.saleq, adj ? r.inq : 0, 0));
      } else {
        var old = r.ag === 'a0' ? (r.elapsed == null || r.elapsed >= d) : (r.elapsed != null && r.elapsed >= d);
        r.longqty = old ? r.jego : 0;
      }
      r.longamt = r.longqty * r.inprice;
    });
  }
  function isLong(r) { return r.longqty > 0; }
  function sumOf(list) {
    var t = { cnt: list.length };
    SUMS.forEach(function (k) { t[k] = 0; });
    list.forEach(function (r) { SUMS.forEach(function (k) { t[k] += r[k] || 0; }); });
    return t;
  }

  // ---------------- 표시 형식 ----------------
  function badge(ag) { return ag ? '<span class="ag ag-' + ag + '">' + AG[ag] + '</span>' : ''; }
  function elapsedHtml(r) {
    if (r.elapsed == null) return '<span class="none">-</span>';
    return won(r.elapsed) + '일' + (r.basis === '입고' ? ' <span class="code">(입고 후)</span>' : '');
  }
  function numHtml(v, c) { return '<span class="' + (c || (v < 0 ? 'minus' : (Math.round(v) === 0 ? 'zero' : ''))) + '">' + won(v) + '</span>'; }
  function dateHtml(s) { return s ? '<span class="dt">' + dLabel(s) + '</span>' : '<span class="none">없음</span>'; }

  // ---------------- 한 줄 목록 (묶기 끔) ----------------
  function buildTable() {
    var num = function (title, field, width, fmt) {
      var o = { title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
                formatter: function (x) { return fmt ? fmt(x.getValue()) : numHtml(x.getValue()); } };
      if (SUMS.indexOf(field) >= 0) {
        o.bottomCalc = function (values) { return values.reduce(function (t, v) { return t + (Number(v) || 0); }, 0); };
        o.bottomCalcFormatter = function (x) { return won(x.getValue()); };
      }
      return o;
    };
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '장기재고가 없어요.',
      initialSort: [{ column: 'longamt', dir: 'desc' }],
      columns: [
        { title: '제조회사', field: 'makecust', minWidth: 100, sorter: 'string',
          formatter: function (x) { return '<span class="maker">' + esc(x.getValue()) + '</span>'; },
          bottomCalc: function (values) { return values.length; },
          bottomCalcFormatter: function (x) { return x.getValue() ? '합계 ' + won(x.getValue()) + '품목' : ''; } },
        { title: '브랜드', field: 'brand', minWidth: 90, sorter: 'string',
          formatter: function (x) { return '<span class="maker">' + esc(x.getValue()) + '</span>'; } },
        { title: '제품명', field: 'jepmnm', minWidth: 170, sorter: 'string',
          formatter: function (x) { var r = x.getRow().getData();
            return '<span class="pname">' + esc(r.jepmnm) + '</span> <span class="code">' + esc(r.jepmcd) + '</span>'; } },
        num('매입가',     'inprice',  80),
        num('현재고',     'jego',     75, function (v) { return '<b>' + won(v) + '</b>'; }),
        num('기간판매',   'saleq',    80),
        num('기간입고',   'inq',      80),
        num('장기재고',   'longqty',  80, function (v) { return numHtml(v, v > 0 ? 'long' : 'zero'); }),
        num('장기재고금액', 'longamt', 110, function (v) { return numHtml(v, v > 0 ? 'long' : 'zero'); }),
        { title: '최종판매일', field: 'lastsale', width: 105, hozAlign: 'center', headerHozAlign: 'center', sorter: 'string',
          formatter: function (x) { return dateHtml(x.getValue()); } },
        { title: '경과일', field: 'elapsed', width: 115, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
          formatter: function (x) { return elapsedHtml(x.getRow().getData()); } },
        { title: '구분', field: 'ag', width: 105, hozAlign: 'center', headerHozAlign: 'center', sorter: 'string',
          formatter: function (x) { return badge(x.getValue()); } }
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
  function drawMerged() {
    var td = function (v, c) { return '<td class="r">' + numHtml(v, c) + '</td>'; };
    var html = '<thead><tr><th class="c" style="width:110px">제조회사</th><th>브랜드</th><th>제품명</th>'
             + ['매입가', '현재고', '기간판매', '기간입고', '장기재고', '장기재고금액'].map(function (h) { return '<th class="r">' + h + '</th>'; }).join('')
             + '<th class="c">최종판매일</th><th class="r">경과일</th><th class="c">구분</th></tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="12" class="c text-muted py-5">장기재고가 없어요.</td></tr>';
    gs.forEach(function (g) {
      g.rows.forEach(function (r, i) {
        html += '<tr class="item">'
              + (i === 0 ? '<td class="mk" rowspan="' + (g.rows.length + 1) + '"><div class="in">' + esc(g.name) + '</div></td>' : '')
              + '<td class="maker">' + esc(r.brand) + '</td>'
              + '<td><span class="pname">' + esc(r.jepmnm) + '</span> <span class="code">' + esc(r.jepmcd) + '</span></td>'
              + td(r.inprice) + '<td class="r"><b>' + won(r.jego) + '</b></td>' + td(r.saleq) + td(r.inq)
              + td(r.longqty, 'long') + td(r.longamt, 'long')
              + '<td class="c">' + dateHtml(r.lastsale) + '</td>'
              + '<td class="r">' + elapsedHtml(r) + '</td>'
              + '<td class="c">' + badge(r.ag) + '</td></tr>';
      });
      var t = sumOf(g.rows);
      html += '<tr class="sub"><td class="lbl" colspan="3">소계 · ' + won(t.cnt) + '품목</td>'
            + td(t.jego) + td(t.saleq) + td(t.inq) + td(t.longqty, 'long') + td(t.longamt, 'long') + '<td colspan="3"></td></tr>';
    });
    html += '</tbody>';
    if (rows.length) {
      var a = sumOf(rows), td2 = function (v, c) { return '<td class="r">' + numHtml(v, c) + '</td>'; };
      html += '<tfoot><tr><td class="c">합계</td><td colspan="3">' + won(gs.length) + '개 제조회사 · ' + won(a.cnt) + '품목</td>'
            + td2(a.jego) + td2(a.saleq) + td2(a.inq) + td2(a.longqty, 'long') + td2(a.longamt, 'long') + '<td colspan="3"></td></tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
  }

  /** 계산 → 기준·구분 필터 → 요약·표 */
  function draw() {
    calc();
    var longs = raw.filter(isLong);
    rows = agFilter ? longs.filter(function (r) { return r.ag === agFilter; }) : longs;
    // 요약 (구분 필터와 상관없이 기준 이상 전체)
    var by = { a9: [], a1: [], a2: [], a3: [], a0: [] };
    longs.forEach(function (r) { if (by[r.ag]) by[r.ag].push(r); });
    var line = function (list) { var t = sumOf(list); return won(t.cnt) + '<small>품목</small> ' + won(t.longamt); };
    $('sAll').innerHTML = line(longs);
    $('sA9').innerHTML = line(by.a9);
    $('sA1').innerHTML = line(by.a1); $('sA2').innerHTML = line(by.a2);
    $('sA3').innerHTML = line(by.a3); $('sA0').innerHTML = line(by.a0);
    document.querySelectorAll('.sum-bar > div[data-ag]').forEach(function (el) { el.classList.toggle('on', el.dataset.ag === agFilter); });

    $('adjBox').classList.toggle('d-none', mode() !== 'qty');
    var grouped = $('fGroup').checked;
    $('rpTable').classList.toggle('d-none', grouped);
    $('mergeWrap').classList.toggle('d-none', !grouped);
    if (grouped) drawMerged();
    else { table.setData(rows); setTimeout(function () { table.redraw(true); fit(); }, 0); }
    fit();
    if (cond) {
      var c = [cond.makecust && '제조 ' + cond.makecust, cond.brand && '브랜드 ' + cond.brand, cond.jepmnm && '제품 ' + cond.jepmnm].filter(Boolean);
      var how = mode() === 'qty'
        ? '최근 ' + days() + '일 판매수량 기준' + ($('fAdj').checked ? ' · 입고 보정' : '')
        : '마지막 판매 후 ' + days() + '일 이상';
      $('headInfo').innerHTML = '<b>' + esc(how) + '</b>'
                              + (agFilter ? ' · ' + AG[agFilter] + '만' : '') + (c.length ? ' · ' + esc(c.join(' · ')) : '');
    }
  }

  function search() {
    var p = { makecust: $('fMakecust').value.trim(), brand: $('fBrand').value.trim(), jepmnm: $('fJepmnm').value.trim() };
    $('loading').classList.remove('d-none');
    $('ar404Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        raw = (list || []).map(function (r) {
          ['inprice', 'jego', 's90', 's180', 's365', 'i90', 'i180', 'i365'].forEach(function (k) { r[k] = Number(r[k] || 0); });
          r.lastsale = String(r.lastsale || '').trim();
          r.lastin = String(r.lastin || '').trim();
          return r;
        });
        cond = p;
        draw();
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar404Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var head = ['제조회사', '브랜드', '제품코드', '제품명', '매입가', '현재고', '재고금액', '기간판매', '기간입고',
                '장기재고', '장기재고금액', '최종입고일', '최종판매일', '경과일', '구분'];
    var line = function (r) {
      return [r.makecust, r.brand, r.jepmcd, r.jepmnm, r.inprice, r.jego, r.jegoamt, r.saleq, r.inq, r.longqty, r.longamt,
              dLabel(r.lastin), dLabel(r.lastsale), r.elapsed == null ? '' : r.elapsed + (r.basis === '입고' ? ' (입고 후)' : ''), AG[r.ag] || ''];
    };
    var sumLine = function (label, t) { return [label, '', '', '', '', t.jego, t.jegoamt, t.saleq, t.inq, t.longqty, t.longamt, '', '', '', '']; };
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
    ws['!cols'] = [14, 12, 14, 28, 9, 8, 12, 9, 9, 9, 13, 11, 11, 13, 12].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '장기재고현황').replace(/\s+/g, '');
    var d = new Date(), pad = function (n) { return (n < 10 ? '0' : '') + n; };
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + '.xlsx');
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
    buildTable();
    $('ar404Search').onclick = search;
    document.querySelectorAll('input.enter').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    // 기준·묶기 : 다시 조회하지 않고 바로 반영
    ['fMode', 'fDays', 'fAdj'].forEach(function (id) { $(id).onchange = function () { if (raw.length) draw(); }; });
    $('fGroup').onchange = draw;
    // 요약 카드를 누르면 그 구분만 보기 (다시 누르면 전체)
    document.querySelectorAll('.sum-bar > div[data-ag]').forEach(function (el) {
      el.onclick = function () { agFilter = (agFilter === el.dataset.ag) ? '' : el.dataset.ag; draw(); };
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
