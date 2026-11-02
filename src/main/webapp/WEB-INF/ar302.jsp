<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>회원별 매출</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 회원별 매출 (ar302) ===== */
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

  .sum-bar { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v.main { color: #1f6fd1; }
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(4, minmax(0, 1fr)); } }

  #rpTable { border: 0; font-size: 13px; }
  #rpTable .tabulator-header { background: var(--navy-soft); }
  #rpTable .tabulator-footer { background: #f7f9fc; font-weight: 700; }
  .grade { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; border: 1px solid #cbd2dc; color: #4a5568; background: #fff; }
  .grade-GOLD   { color: #9a6b00; background: #fff4d1; border-color: #e7b93c; }
  .grade-SILVER { color: #56606e; background: #eef0f3; border-color: #aab2bd; }
  .grade-YELLO  { color: #8a6d00; background: #fffbd6; border-color: #e6cf3a; }
  .grade-GREEN  { color: #1f7a4d; background: #e3f5ea; border-color: #5cbf8a; }
  .minus { color: #d63939; }
  .merge-wrap { overflow: auto; }
  table.merge { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
  table.merge th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); padding: 9px 10px; font-weight: 700;
                   border-bottom: 1px solid #cfd6e2; white-space: nowrap; text-align: left; }
  table.merge td { padding: 8px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
  table.merge .r { text-align: right; }
  table.merge .c { text-align: center; }
  table.merge td.mgr { text-align: center; vertical-align: top; font-weight: 800; color: var(--navy); padding: 0;
                       background: #f4f7fc; border-right: 1px solid #cfd6e2; border-bottom: 2px solid #b9c5d8; }
  /* 담당 이름 : 칸 맨 위에서 시작해 스크롤하면 머리글 바로 아래에 붙어 따라옴 (그 담당 칸 안에서만) */
  table.merge td.mgr .mgr-in { position: sticky; top: 38px; padding: 8px 6px; background: #f4f7fc; }
  table.merge tr.sub td { background: #f7f9fc; font-weight: 700; border-bottom: 2px solid #b9c5d8; }
  table.merge tr.sub td.lbl { color: var(--muted); }
  table.merge tfoot td { position: sticky; bottom: 0; background: #e9eef7; font-weight: 800; border-top: 1px solid #b9c5d8; }
  table.merge tbody tr:not(.sub):hover td:not(.mgr) { background: #f0f5ff; }
  #rpTable .tabulator-group { background: #eef3fb; border-bottom: 1px solid #cfdaeb; font-size: 13px; padding: 6px 10px; }
  #rpTable .tabulator-group .g-name { font-weight: 800; color: var(--navy); }
  #rpTable .tabulator-group .g-info { margin-left: 10px; color: var(--muted); font-weight: 400; }
  #rpTable .tabulator-group .g-amt { margin-left: 10px; color: #1f6fd1; font-weight: 700; }
  #rpTable .tabulator-calcs-holder .tabulator-row, #rpTable .tabulator-row.tabulator-calcs { background: #f7f9fc; font-weight: 700; }

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
        <h6>회원별 매출</h6>
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
        <span class="lbl">담당자</span>
        <input type="text" class="form-control form-control-sm" id="fManager" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
        <span class="lbl">등급</span>
        <select class="form-select form-select-sm" id="fGrade"><option value="">전체</option></select>
        <span class="lbl">판매자</span>
        <select class="form-select form-select-sm" id="fPruser"><option value="">전체</option></select>
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar302Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="fGroup" checked>
          <label class="form-check-label small" for="fGroup">담당별 묶기</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">회원수</div><div class="v" id="sCnt">0</div></div>
        <div><div class="k">매출</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">현금</div><div class="v" id="sCash">0</div></div>
        <div><div class="k">카드</div><div class="v" id="sCard">0</div></div>
        <div><div class="k">포인트사용</div><div class="v" id="sBonus">0</div></div>
        <div><div class="k">할인</div><div class="v" id="sSale">0</div></div>
        <div><div class="k">방문수</div><div class="v" id="sQty">0</div></div>
      </div>
      <div id="rpTable"></div>
      <!-- 담당별 묶기 : 담당 칸 병합 표 -->
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
 * 회원별 매출 (ar302) — member + MC20_MST, 로그인 매장
 *   - 검색 : 기간(CHDATE), 담당자(member.manager), 등급(member.member), 판매자(PRUSER)
 *   - 매출 = CASHAMT + CARDAMT (현금 + 카드)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar302';
  var table = null, rows = [];
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Number(n || 0).toLocaleString('ko-KR'); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
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

  // ---------------- 검색 옵션 ----------------
  function loadInit() {
    return api('/init').then(function (d) {
      var opt = function (n) { return '<option>' + esc(n) + '</option>'; };
      var uniq = function (list) {             // 공백 제거 후 중복 제거
        var seen = {};
        return (list || []).map(function (n) { return String(n || '').trim(); })
          .filter(function (n) { if (!n || seen[n]) return false; seen[n] = 1; return true; });
      };
      $('fGrade').insertAdjacentHTML('beforeend', uniq(d.grades).map(opt).join(''));
      var staff = uniq(d.staff).map(opt).join('');
      $('fPruser').insertAdjacentHTML('beforeend', staff);
    });
  }

  // ---------------- 목록 ----------------
  function money(c) { var v = c.getValue(); return '<span class="' + (v < 0 ? 'minus' : '') + '">' + won(v) + '</span>'; }
  function sumFmt(c) { return won(c.getValue()); }
  function buildTable() {
    var num = function (title, field, width, bold) {
      return { title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right',
               formatter: bold ? function (c) { return '<b>' + money(c) + '</b>'; } : money,
               bottomCalc: 'sum', bottomCalcFormatter: sumFmt };
    };
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 매출이 없어요.',
      columns: [
        { title: '담당', field: 'manager', width: 90 },
        { title: '성명', field: 'name', minWidth: 110,
          formatter: function (c) { return '<b>' + esc(c.getValue()) + '</b>'; },
          bottomCalc: 'count', bottomCalcFormatter: function (c) { return won(c.getValue()) + '명'; } },
        { title: '등급', field: 'grade', width: 85, hozAlign: 'center', headerHozAlign: 'center',
          formatter: function (c) { var g = c.getValue(); return g ? '<span class="grade grade-' + esc(g) + '">' + esc(g) + '</span>' : ''; } },
        { title: '전화번호', field: 'handno', width: 125, formatter: function (c) { return esc(fmtTel(c.getValue())); } },
        num('매출', 'amt', 110, true),
        num('현금', 'cash', 100),
        num('카드', 'card', 100),
        num('포인트사용', 'bonus', 115),
        num('할인', 'sale', 95),
        num('방문수', 'qty', 90),
        { title: 'SMS', field: 'sms', width: 85, headerSort: false, hozAlign: 'center', headerHozAlign: 'center' }
      ]
    });
  }

  function search() {
    var p = { from: $('fFrom').value, to: $('fTo').value, manager: $('fManager').value.trim(), grade: $('fGrade').value, pruser: $('fPruser').value };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar302Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = list || [];
        draw();
        var s = { amt: 0, cash: 0, card: 0, bonus: 0, sale: 0, qty: 0 };
        rows.forEach(function (r) { for (var k in s) s[k] += r[k] || 0; });
        $('sCnt').textContent = won(rows.length);
        $('sAmt').textContent = won(s.amt); $('sCash').textContent = won(s.cash); $('sCard').textContent = won(s.card);
        $('sBonus').textContent = won(s.bonus); $('sSale').textContent = won(s.sale); $('sQty').textContent = won(s.qty);
        var cond = [p.manager && '담당 ' + p.manager, p.grade && '등급 ' + p.grade, p.pruser && '판매자 ' + p.pruser].filter(Boolean);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>' + (cond.length ? ' · ' + esc(cond.join(' · ')) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar302Search').disabled = false; });
  }

  // ---------------- 담당별 묶기 ----------------
  var NO_MGR = '(담당 없음)';
  function mgr(r) { return r.manager || NO_MGR; }
  /** 담당 순 (담당 없음은 맨 뒤), 같은 담당 안에서는 서버 순서(등급·성명) 유지 */
  function sortByManager(list) {
    return list.map(function (r, i) { return { r: r, i: i }; }).sort(function (a, b) {
      var x = a.r.manager, y = b.r.manager;
      if (!x !== !y) return x ? -1 : 1;
      return (x || '').localeCompare(y || '') || a.i - b.i;
    }).map(function (o) { return o.r; });
  }
  var NUMS = ['amt', 'cash', 'card', 'bonus', 'sale', 'qty'];
  function sums(list) {
    var s = {}; NUMS.forEach(function (k) { s[k] = list.reduce(function (t, r) { return t + (r[k] || 0); }, 0); });
    return s;
  }
  /** 담당 순으로 나눈 묶음 [{ name, rows }] */
  function groups() {
    var list = sortByManager(rows), out = [], i = 0;
    while (i < list.length) {
      var g = { name: mgr(list[i]), rows: [] };
      while (i < list.length && mgr(list[i]) === g.name) g.rows.push(list[i++]);
      out.push(g);
    }
    return out;
  }
  function numTd(v, bold) { return '<td class="r' + (v < 0 ? ' minus' : '') + '">' + (bold ? '<b>' + won(v) + '</b>' : won(v)) + '</td>'; }
  function numTds(s) { return numTd(s.amt, true) + numTd(s.cash) + numTd(s.card) + numTd(s.bonus) + numTd(s.sale) + numTd(s.qty); }

  /** 담당 칸을 위아래로 합친 표 (담당 | 회원들 … | 소계) */
  function drawMerged() {
    var html = '<thead><tr><th class="c" style="width:110px">담당</th><th>성명</th><th class="c">등급</th><th>전화번호</th>'
             + '<th class="r">매출</th><th class="r">현금</th><th class="r">카드</th><th class="r">포인트사용</th>'
             + '<th class="r">할인</th><th class="r">방문수</th><th class="c">SMS</th></tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="11" class="c text-muted py-5">조회된 매출이 없어요.</td></tr>';
    gs.forEach(function (g) {
      g.rows.forEach(function (r, i) {
        html += '<tr>'
              + (i === 0 ? '<td class="mgr" rowspan="' + (g.rows.length + 1) + '"><div class="mgr-in">' + esc(g.name) + '</div></td>' : '')
              + '<td><b>' + esc(r.name) + '</b></td>'
              + '<td class="c">' + (r.grade ? '<span class="grade grade-' + esc(r.grade) + '">' + esc(r.grade) + '</span>' : '') + '</td>'
              + '<td>' + esc(fmtTel(r.handno)) + '</td>'
              + numTds(r)
              + '<td class="c">' + esc(r.sms) + '</td></tr>';
      });
      html += '<tr class="sub"><td class="lbl">소계 ' + won(g.rows.length) + '명</td><td></td><td></td>' + numTds(sums(g.rows)) + '<td></td></tr>';
    });
    html += '</tbody><tfoot><tr><td class="c">합계</td><td>' + won(rows.length) + '명</td><td></td><td></td>'
          + numTds(sums(rows)) + '<td></td></tr></tfoot>';
    $('mergeTable').innerHTML = html;
  }

  function draw() {
    var grouped = $('fGroup').checked;
    $('rpTable').classList.toggle('d-none', grouped);
    $('mergeWrap').classList.toggle('d-none', !grouped);
    if (grouped) drawMerged();
    else { table.setData(rows); setTimeout(function () { table.redraw(true); fit(); }, 0); }
    fit();
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var KEYS = ['amt', 'cash', 'card', 'bonus', 'sale', 'qty'];
    var head = ['담당', '성명', '등급', '전화번호', '매출', '현금', '카드', '포인트사용', '할인', '방문수', 'SMS'];
    var sumRow = function (label, list) {
      return [label, won(list.length) + '명', '', ''].concat(KEYS.map(function (k) {
        return list.reduce(function (s, r) { return s + (r[k] || 0); }, 0);
      })).concat(['']);
    };
    var line = function (r) { return [r.manager, r.name, r.grade, fmtTel(r.handno), r.amt, r.cash, r.card, r.bonus, r.sale, r.qty, r.sms]; };
    var data = [], merges = [];
    if ($('fGroup').checked) {                  // 담당별 묶기 : 담당 칸 병합 + 소계
      groups().forEach(function (g) {
        var start = data.length + 1;            // 0 행은 제목
        g.rows.forEach(function (r, i) { var l = line(r); l[0] = i === 0 ? g.name : ''; data.push(l); });
        var sub = sumRow('', g.rows); sub[1] = '소계 ' + won(g.rows.length) + '명'; data.push(sub);
        merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
      });
    } else {
      data = rows.map(line);
    }
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data, [sumRow('합계', rows)]));
    if (merges.length) ws['!merges'] = merges;
    ws['!cols'] = [12, 10, 8, 14, 12, 12, 12, 10, 10, 8, 6].map(function (w) { return { wch: w }; });
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, '회원별매출');
    XLSX.writeFile(wb, '회원별매출_' + $('fFrom').value + '_' + $('fTo').value + '.xlsx');
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var w = $('mergeWrap');
    if (w.offsetParent) { w.style.maxHeight = Math.max(300, window.innerHeight - w.getBoundingClientRect().top - 30) + 'px'; w.style.height = w.style.maxHeight; }
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
    $('ar302Search').onclick = search;
    ['fGrade', 'fPruser'].forEach(function (id) { $(id).onchange = search; });
    $('fManager').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    $('btnExcel').onclick = excel;
    $('fGroup').onchange = draw;
    window.addEventListener('resize', fit);
    table.on('tableBuilt', function () { fit(); loadInit().catch(fail).then(search); });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
