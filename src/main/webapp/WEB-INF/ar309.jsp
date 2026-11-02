<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품별 전표내역</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제품별 전표내역 (ar309) ===== */
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
  table.merge tr.item.alt td:not(.day) { background: #f6f8fc; }
  table.merge tbody tr.item:hover td:not(.day) { background: #f0f5ff; }
  /* 일자 칸 (위아래 병합) */
  table.merge td.day { text-align: center; vertical-align: top; font-weight: 800; color: var(--navy); padding: 0;
                       background: #f4f7fc; border-right: 1px solid #cfd6e2; border-bottom: 2px solid #b9c5d8; }
  /* 일자 글자 : 칸 맨 위에서 시작해 스크롤하면 머리글 바로 아래에 붙어 따라옴 (그 일자 칸 안에서만) */
  table.merge td.day .day-in { position: sticky; top: 38px; padding: 8px 6px; background: #f4f7fc; }
  table.merge td.day small { display: block; font-weight: 600; color: var(--muted); }
  /* 일자 소계 */
  table.merge tr.sub-d td:not(.day) { background: #eef3fb; font-weight: 800; color: var(--navy); border-bottom: 2px solid #b9c5d8; }
  table.merge tr.sub-d td.lbl { color: var(--navy); }
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
        <h6>제품별 전표내역</h6>
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
        <input type="text" class="form-control form-control-sm enter" id="fMakecust" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
        <span class="lbl">브랜드</span>
        <input type="text" class="form-control form-control-sm enter" id="fBrand" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
        <span class="lbl">제품명</span>
        <input type="text" class="form-control form-control-sm enter" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:160px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar309Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="fSubD" checked>
          <label class="form-check-label small" for="fSubD">일자 소계</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">일수</div><div class="v" id="sDays">0</div></div>
        <div><div class="k">전표수</div><div class="v" id="sSlips">0</div></div>
        <div><div class="k">수량</div><div class="v" id="sQty">0</div></div>
        <div><div class="k">금액 (입고가)</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">정가금액</div><div class="v" id="sPriceAmt">0</div></div>
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
 * 제품별 전표내역 (ar309) — MC27_MST + MC27_DTL + SHOP_JEPM_MST
 *   - 금액     = 입고가 × 수량
 *   - 정가금액 = 정가 × 수량
 *   - 일자 칸 병합, 일자 소계 · 전체 합계 는 금액·정가금액만
 *   - 전표번호가 바뀔 때마다 줄 색을 번갈아 바꿈 (전표번호는 안 보임)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar309';
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
  function dayLabel(s) { s = String(s || ''); return s.length === 8 ? s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2) : s; }
  function dayName(s) {
    s = String(s || '');
    if (s.length !== 8) return '';
    return '일월화수목금토'.charAt(new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2)).getDay());
  }
  function slipCount(list) { var m = {}; list.forEach(function (r) { m[r.cjpno] = 1; }); return Object.keys(m).length; }

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
  /** 일자 묶음 [{ day, rows }] (서버에서 일자·전표·순번 순으로 옴) */
  function groups() {
    var out = [];
    rows.forEach(function (r) {
      var g = out[out.length - 1];
      if (!g || g.day !== r.chdate) out.push(g = { day: r.chdate, rows: [] });
      g.rows.push(r);
    });
    return out;
  }
  function numTd(v, bold) {
    var cls = 'r' + (v < 0 ? ' minus' : (Math.round(v) === 0 ? ' zero' : ''));
    return '<td class="' + cls + '">' + (bold ? '<b>' + won(v) + '</b>' : won(v)) + '</td>';
  }
  function once(cls, span, html) {
    var done = false;
    return function () {
      if (done) return '';
      done = true;
      return '<td class="' + cls + '" rowspan="' + span + '">' + html + '</td>';
    };
  }

  /** 병합 표 (일자 | 내역들 … | 일자 소계) */
  function draw() {
    var subD = $('fSubD').checked;
    var html = '<thead><tr><th class="c" style="width:110px">일자</th><th>비고</th><th>제품코드</th><th>제조회사</th><th>브랜드</th>'
             + '<th>제품명</th><th class="r">정가</th><th class="r">입고가</th><th class="r">수량</th>'
             + '<th class="r">금액</th><th class="r">정가금액</th></tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="11" class="c text-muted py-5">조회된 내역이 없어요.</td></tr>';
    var alt = false, lastJp = null;
    gs.forEach(function (g) {
      var lead = once('day', g.rows.length + (subD ? 1 : 0), '<div class="day-in">' + esc(dayLabel(g.day)) + '<small>(' + dayName(g.day) + ')</small></div>');
      g.rows.forEach(function (r) {
        if (r.cjpno !== lastJp) { alt = !alt; lastJp = r.cjpno; }   // 전표가 바뀌면 색 바꿈
        html += '<tr class="item' + (alt ? ' alt' : '') + '">' + lead()
              + '<td>' + esc(r.remk) + '</td>'
              + '<td class="code">' + esc(r.jepmcd) + '</td>'
              + '<td class="muted">' + esc(r.makecust) + '</td>'
              + '<td class="muted">' + esc(r.brand) + '</td>'
              + '<td>' + esc(r.jepmnm) + '</td>'
              + numTd(r.price) + numTd(r.inprice) + numTd(r.qty)
              + numTd(r.amt, true) + numTd(r.priceAmt) + '</tr>';
      });
      if (subD) {
        html += '<tr class="sub-d">' + lead() + '<td class="lbl" colspan="8">소계 · 전표 ' + won(slipCount(g.rows)) + '건</td>'
              + numTd(sumOf(g.rows, 'amt'), true) + numTd(sumOf(g.rows, 'priceAmt'), true) + '</tr>';
      }
    });
    html += '</tbody>';
    if (rows.length) {
      html += '<tfoot><tr><td class="c">합계</td><td colspan="8">전표 ' + won(slipCount(rows)) + '건 · ' + won(gs.length) + '일</td>'
            + numTd(sumOf(rows, 'amt'), true) + numTd(sumOf(rows, 'priceAmt'), true) + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
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
    $('ar309Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = (list || []).map(function (r) {
          ['price', 'inprice', 'qty'].forEach(function (k) { r[k] = Number(r[k] || 0); });
          r.amt      = r.inprice * r.qty;     // 금액 = 입고가 × 수량
          r.priceAmt = r.price * r.qty;       // 정가금액 = 정가 × 수량
          return r;
        });
        cond = p;
        draw();
        $('sDays').textContent = won(groups().length);
        $('sSlips').textContent = won(slipCount(rows));
        $('sQty').textContent = won(sumOf(rows, 'qty'));
        $('sAmt').textContent = won(sumOf(rows, 'amt'));
        $('sPriceAmt').textContent = won(sumOf(rows, 'priceAmt'));
        var c = [p.makecust && '제조 ' + p.makecust, p.brand && '브랜드 ' + p.brand, p.jepmnm && '제품 ' + p.jepmnm].filter(Boolean);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>' + (c.length ? ' · ' + esc(c.join(' · ')) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar309Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var subD = $('fSubD').checked;
    var head = ['일자', '비고', '제품코드', '제조회사', '브랜드', '제품명', '정가', '입고가', '수량', '금액', '정가금액'];
    var data = [], merges = [];
    groups().forEach(function (g) {
      var start = data.length + 1;                 // 0 행은 제목
      g.rows.forEach(function (r) {
        data.push(['', r.remk, r.jepmcd, r.makecust, r.brand, r.jepmnm, r.price, r.inprice, r.qty, r.amt, r.priceAmt]);
      });
      if (subD) data.push(['', '소계 · 전표 ' + slipCount(g.rows) + '건', '', '', '', '', '', '', '', sumOf(g.rows, 'amt'), sumOf(g.rows, 'priceAmt')]);
      data[start - 1][0] = dayLabel(g.day);
      merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
    });
    data.push(['합계', '전표 ' + slipCount(rows) + '건', '', '', '', '', '', '', '', sumOf(rows, 'amt'), sumOf(rows, 'priceAmt')]);
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!merges'] = merges;
    ws['!cols'] = [12, 20, 12, 14, 12, 28, 9, 9, 6, 12, 12].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제품별전표내역').replace(/\s+/g, '');
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
    setRange('today');
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); search(); };
    });
    $('ar309Search').onclick = search;
    document.querySelectorAll('input.enter').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    $('fSubD').onchange = draw;
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
