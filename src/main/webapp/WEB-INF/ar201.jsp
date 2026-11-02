<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>입고 내역</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 입고 내역 (ar201) ===== */
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

  .minus { color: #d63939; }
  .zero  { color: #c3c9d3; }
  .diff  { color: #c26a00; font-weight: 700; }     /* 입고가가 제품입고가와 다름 */

  .merge-wrap { overflow: auto; }
  table.merge { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
  table.merge th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); padding: 9px 10px; font-weight: 700;
                   border-bottom: 1px solid #cfd6e2; white-space: nowrap; text-align: left; }
  table.merge td { padding: 7px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
  table.merge .r { text-align: right; }
  table.merge .c { text-align: center; }
  table.merge td.muted { color: var(--muted); }
  table.merge td.code  { color: var(--muted); font-size: 12px; }
  /* 전표번호별 번갈아 색 */
  table.merge tr.item.alt td:not(.cu):not(.day) { background: #f6f8fc; }
  table.merge tbody tr.item:hover td:not(.cu):not(.day) { background: #f0f5ff; }
  /* 거래처 칸 (위아래 병합) — 이름은 맨 위, 스크롤하면 머리글 아래에 붙어 따라옴 */
  table.merge td.cu { vertical-align: top; padding: 0; font-weight: 800; color: var(--navy); text-align: center;
                      background: #f4f7fc; border-right: 1px solid #cfd6e2; border-bottom: 2px solid #b9c5d8; }
  table.merge td.cu .in { position: sticky; top: 38px; padding: 8px 6px; background: #f4f7fc; white-space: normal; }
  /* 입고일 칸 (거래처 안에서 위아래 병합) */
  table.merge td.day { vertical-align: top; padding: 0; font-weight: 700; color: #3d4b66; text-align: center;
                       background: #fafbfd; border-right: 1px solid #e3e7ee; border-bottom: 2px solid #d5deec; }
  table.merge td.day .in { position: sticky; top: 38px; padding: 8px 6px; background: #fafbfd; }
  table.merge td.day small { display: block; font-weight: 600; color: var(--muted); }
  /* 일자 소계 */
  table.merge tr.sub-d td:not(.cu):not(.day) { background: #f7f9fc; font-weight: 700; border-bottom: 2px solid #d5deec; }
  /* 거래처 소계 */
  table.merge tr.sub-c td:not(.cu) { background: #eef3fb; font-weight: 800; color: var(--navy); border-bottom: 2px solid #b9c5d8; }
  table.merge td.lbl { color: var(--muted); }
  table.merge tr.sub-c td.lbl { color: var(--navy); }
  table.merge tfoot td { position: sticky; bottom: 0; background: #e9eef7; font-weight: 800; border-top: 1px solid #b9c5d8; }
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
        <h6>입고 내역</h6>
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
        <span class="lbl">거래처</span>
        <input type="text" class="form-control form-control-sm enter" id="fCust" placeholder="빈칸 = 전체" style="width:130px" autocomplete="off">
        <span class="lbl">제조회사</span>
        <input type="text" class="form-control form-control-sm enter" id="fMakecust" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">브랜드</span>
        <input type="text" class="form-control form-control-sm enter" id="fBrand" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">제품명</span>
        <input type="text" class="form-control form-control-sm enter" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:140px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar201Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="fSubD" checked>
          <label class="form-check-label small" for="fSubD">일자 소계</label>
        </div>
        <div class="form-check form-check-inline mb-0">
          <input class="form-check-input" type="checkbox" id="fSubC" checked>
          <label class="form-check-label small" for="fSubC">거래처 소계</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">거래처</div><div class="v" id="sCust">0</div></div>
        <div><div class="k">전표수</div><div class="v" id="sSlips">0</div></div>
        <div><div class="k">수량</div><div class="v" id="sQty">0</div></div>
        <div><div class="k">서비스</div><div class="v" id="sPack">0</div></div>
        <div><div class="k">금액</div><div class="v main" id="sAmt">0</div></div>
      </div>
      <div class="merge-wrap" id="mergeWrap"><table class="merge" id="mergeTable"></table></div>
      <div class="loading-mask d-none" id="loading">조회 중입니다…</div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 입고 내역 (ar201) — IP01_MST + IP01_DTL + SHOP_JEPM_MST + CUST_MST
 *   - 묶음 : 거래처 > 입고일 칸 병합 (이름은 맨 위, 스크롤해도 보임)
 *   - 소계 : 일자 소계 · 거래처 소계 · 전체 합계 — 수량·서비스·금액만
 *   - 전표번호가 바뀔 때마다 줄 색을 번갈아 바꿈 (전표번호는 안 보임)
 *   - 입고가가 제품입고가와 다르면 주황색으로 표시
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar201';
  var NUMS = ['jinprice', 'jprice', 'ipprice', 'qty', 'amt', 'pack'];
  var rows = [], cond = null;
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

  // ---------------- 계산 ----------------
  function sumOf(list, k) { return list.reduce(function (s, r) { return s + (r[k] || 0); }, 0); }
  function slipCount(list) { var m = {}; list.forEach(function (r) { m[r.ipdate + '|' + r.mjpno] = 1; }); return Object.keys(m).length; }
  function dayLabel(s) { s = String(s || ''); return s.length === 8 ? s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2) : s; }
  function dayName(s) {
    s = String(s || '');
    if (s.length !== 8) return '';
    return '일월화수목금토'.charAt(new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2)).getDay());
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

  // ---------------- 표 ----------------
  /** 거래처 > 입고일 묶음 (서버에서 거래처·입고일·전표·순번 순으로 옴) */
  var NONE = '(거래처 없음)';
  function groups() {
    var out = [];
    rows.forEach(function (r) {
      var cn = r.custname || NONE;
      var c = out[out.length - 1];
      if (!c || c.name !== cn) out.push(c = { name: cn, rows: [], days: [] });
      var d = c.days[c.days.length - 1];
      if (!d || d.day !== r.ipdate) c.days.push(d = { day: r.ipdate, rows: [] });
      d.rows.push(r);
      c.rows.push(r);
    });
    return out;
  }
  function numTd(v, bold, cls) {
    var c = 'r' + (cls ? ' ' + cls : '') + (v < 0 ? ' minus' : (Math.round(v) === 0 ? ' zero' : ''));
    return '<td class="' + c + '">' + (bold ? '<b>' + won(v) + '</b>' : won(v)) + '</td>';
  }
  /** 수량 | 서비스 | 금액 */
  function sumCells(list) { return numTd(sumOf(list, 'qty'), true) + numTd(sumOf(list, 'pack'), true) + numTd(sumOf(list, 'amt'), true); }
  function once(cls, span, html) {
    var done = false;
    return function () {
      if (done) return '';
      done = true;
      return '<td class="' + cls + '" rowspan="' + span + '"><div class="in">' + html + '</div></td>';
    };
  }

  /** 병합 표 (거래처 | 입고일 | 내역 … 일자 소계 | 거래처 소계) */
  function draw() {
    var subD = $('fSubD').checked, subC = $('fSubC').checked;
    var html = '<thead><tr><th class="c" style="width:120px">거래처</th><th class="c" style="width:100px">입고일</th>'
             + '<th>제조회사</th><th>브랜드</th><th>제품명</th><th>제품코드</th>'
             + '<th class="r">정가</th><th class="r">제품입고가</th><th class="r">입고가</th>'
             + '<th class="r">수량</th><th class="r">서비스</th><th class="r">금액</th></tr></thead><tbody>';
    var cs = groups();
    if (!cs.length) html += '<tr><td colspan="12" class="c text-muted py-5">조회된 입고가 없어요.</td></tr>';
    var alt = false, lastJp = null;
    cs.forEach(function (c) {
      // 거래처 칸이 덮을 줄 수 = 내역 + 일자 소계(일자마다 1줄) + 거래처 소계(1줄)
      var leadC = once('cu', c.rows.length + (subD ? c.days.length : 0) + (subC ? 1 : 0), esc(c.name));
      c.days.forEach(function (d) {
        var leadD = once('day', d.rows.length + (subD ? 1 : 0), esc(dayLabel(d.day)) + '<small>(' + dayName(d.day) + ')</small>');
        var lead = function () { return leadC() + leadD(); };
        d.rows.forEach(function (r) {
          var jp = r.ipdate + '|' + r.mjpno;
          if (jp !== lastJp) { alt = !alt; lastJp = jp; }      // 전표가 바뀌면 색 바꿈
          var diff = r.ipprice !== r.jinprice;                 // 입고가 ≠ 제품입고가
          html += '<tr class="item' + (alt ? ' alt' : '') + '">' + lead()
                + '<td class="muted">' + esc(r.makecust) + '</td>'
                + '<td class="muted">' + esc(r.brand) + '</td>'
                + '<td>' + esc(r.jepmnm) + '</td>'
                + '<td class="code">' + esc(r.jepmcd) + '</td>'
                + numTd(r.jprice) + numTd(r.jinprice)
                + numTd(r.ipprice, false, diff ? 'diff' : '')
                + numTd(r.qty) + numTd(r.pack) + numTd(r.amt, true) + '</tr>';
        });
        if (subD) html += '<tr class="sub-d">' + lead() + '<td class="lbl" colspan="7">소계 · 전표 ' + won(slipCount(d.rows)) + '건</td>' + sumCells(d.rows) + '</tr>';
      });
      if (subC) html += '<tr class="sub-c">' + leadC() + '<td class="lbl" colspan="8">' + esc(c.name) + ' 합계 · 전표 ' + won(slipCount(c.rows)) + '건</td>' + sumCells(c.rows) + '</tr>';
    });
    html += '</tbody>';
    if (rows.length) {
      html += '<tfoot><tr><td class="c">합계</td><td colspan="8">거래처 ' + won(cs.length) + '곳 · 전표 ' + won(slipCount(rows)) + '건</td>'
            + sumCells(rows) + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
    fit();
  }

  function search() {
    var p = {
      from: $('fFrom').value, to: $('fTo').value, custname: $('fCust').value.trim(),
      makecust: $('fMakecust').value.trim(), brand: $('fBrand').value.trim(), jepmnm: $('fJepmnm').value.trim()
    };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar201Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = (list || []).map(function (r) {
          NUMS.forEach(function (k) { r[k] = Number(r[k] || 0); });
          return r;
        });
        cond = p;
        draw();
        $('sCust').textContent = won(groups().length);
        $('sSlips').textContent = won(slipCount(rows));
        $('sQty').textContent = won(sumOf(rows, 'qty'));
        $('sPack').textContent = won(sumOf(rows, 'pack'));
        $('sAmt').textContent = won(sumOf(rows, 'amt'));
        var c = [p.custname && '거래처 ' + p.custname, p.makecust && '제조 ' + p.makecust,
                 p.brand && '브랜드 ' + p.brand, p.jepmnm && '제품 ' + p.jepmnm].filter(Boolean);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>' + (c.length ? ' · ' + esc(c.join(' · ')) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar201Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var subD = $('fSubD').checked, subC = $('fSubC').checked;
    var head = ['거래처', '입고일', '제조회사', '브랜드', '제품명', '제품코드', '정가', '제품입고가', '입고가', '수량', '서비스', '금액'];
    var tot = function (list) { return [sumOf(list, 'qty'), sumOf(list, 'pack'), sumOf(list, 'amt')]; };
    var data = [], merges = [];
    groups().forEach(function (c) {
      var cStart = data.length + 1;                // 0 행은 제목
      c.days.forEach(function (d) {
        var dStart = data.length + 1;
        d.rows.forEach(function (r) {
          data.push(['', '', r.makecust, r.brand, r.jepmnm, r.jepmcd, r.jprice, r.jinprice, r.ipprice, r.qty, r.pack, r.amt]);
        });
        if (subD) data.push(['', '', '소계 · 전표 ' + slipCount(d.rows) + '건', '', '', '', '', '', ''].concat(tot(d.rows)));
        data[dStart - 1][1] = dayLabel(d.day);
        if (data.length > dStart) merges.push({ s: { r: dStart, c: 1 }, e: { r: data.length, c: 1 } });
      });
      if (subC) data.push(['', c.name + ' 합계', '전표 ' + slipCount(c.rows) + '건', '', '', '', '', '', ''].concat(tot(c.rows)));
      data[cStart - 1][0] = c.name;
      merges.push({ s: { r: cStart, c: 0 }, e: { r: data.length, c: 0 } });
    });
    data.push(['합계', '', '전표 ' + slipCount(rows) + '건', '', '', '', '', '', ''].concat(tot(rows)));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!merges'] = merges;
    ws['!cols'] = [14, 12, 14, 12, 28, 14, 9, 10, 9, 7, 7, 12].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '입고내역').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + (cond ? cond.from + '_' + cond.to : '') + '.xlsx');
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var w = $('mergeWrap');
    if (w.offsetParent) w.style.height = Math.max(300, window.innerHeight - w.getBoundingClientRect().top - 30) + 'px';
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    setRange('month');
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); search(); };
    });
    $('ar201Search').onclick = search;
    document.querySelectorAll('input.enter').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    ['fSubD', 'fSubC'].forEach(function (id) { $(id).onchange = draw; });
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    fit();
    search();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
