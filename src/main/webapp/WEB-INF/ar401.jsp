<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품 현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제품 현황 (ar401) ===== */
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
  .code  { color: var(--muted); font-size: 12px; }
  .pname { font-weight: 600; }
  .minus { color: #d63939; }
  .zero  { color: #c3c9d3; }
  .rate  { color: #6b7686; }
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
        <h6>제품 현황</h6>
        <div class="sub" id="headInfo">조건을 넣고 조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">제조회사</span>
        <input type="text" class="form-control form-control-sm enter" id="fMakecust" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
        <span class="lbl">브랜드</span>
        <input type="text" class="form-control form-control-sm enter" id="fBrand" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
        <span class="lbl">제품명</span>
        <input type="text" class="form-control form-control-sm enter" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:160px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar401Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="fStock">
          <label class="form-check-label small" for="fStock">재고 있는 제품만</label>
        </div>
        <div class="form-check form-check-inline mb-0">
          <input class="form-check-input" type="checkbox" id="fGroup" checked>
          <label class="form-check-label small" for="fGroup">제조회사별 묶기</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">품목수</div><div class="v" id="sCnt">0</div></div>
        <div><div class="k">재고</div><div class="v" id="sJego">0</div></div>
        <div><div class="k">입고금액</div><div class="v main" id="sInAmt">0</div></div>
        <div><div class="k">판매금액</div><div class="v" id="sSaleAmt">0</div></div>
        <div><div class="k">평균 입고율</div><div class="v" id="sInRate">0%</div></div>
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
 * 제품 현황 (ar401) — SHOP_JEPM_MST, 로그인 매장, SYS = 'N'
 *   - 입고율 % = 입고가 × 100 ÷ 정가
 *   - 할인율 % = 100 - (판매가 × 100 ÷ 정가)
 *   - 입고금액 = 재고 × 입고가
 *   - 판매금액 = 재고 × 판매가
 *   - 합계 : 재고·입고금액·판매금액, 평균 입고율 = 입고금액 합 ÷ (재고 × 정가) 합
 *   - 제조회사별 묶기 : 제조회사 칸을 위아래로 병합 + 제조회사 소계(재고·입고금액·판매금액)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar401';
  var table = null, rows = [], total = null, cond = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function pct(n) { return (Math.round(Number(n || 0) * 10) / 10).toFixed(1) + '%'; }
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

  // ---------------- 목록 ----------------
  function money(v) { return '<span class="' + (v < 0 ? 'minus' : (Math.round(v) === 0 ? 'zero' : '')) + '">' + won(v) + '</span>'; }
  /** 정가가 0 이면 % 는 빈칸 */
  function rateFmt(v, row) { return row.price ? '<span class="rate">' + pct(v) + '</span>' : ''; }
  function txt(title, field, width, cls, extra) {
    var c = { title: title, field: field, minWidth: width, sorter: 'string',
              formatter: function (x) { return '<span class="' + (cls || '') + '">' + esc(x.getValue()) + '</span>'; } };
    for (var k in (extra || {})) c[k] = extra[k];
    return c;
  }
  function num(title, field, width, cellFmt, sum) {
    var c = { title: title, field: field, width: width, hozAlign: 'right', headerHozAlign: 'right', sorter: 'number',
              formatter: function (x) { return (cellFmt || money)(x.getValue(), x.getRow().getData()); } };
    if (sum) {
      c.bottomCalc = function (values) { return values.reduce(function (t, v) { return t + (Number(v) || 0); }, 0); };
      c.bottomCalcFormatter = function (x) { return won(x.getValue()); };
    }
    return c;
  }
  var NONE = '(제조회사 없음)';
  function groupKey(r) { return r.makecust || NONE; }

  function buildTable() {
    table = new Tabulator('#rpTable', {
      layout: 'fitColumns',
      height: 400,
      placeholder: '조회된 제품이 없어요.',
      columns: [
        txt('제조회사', 'makecust', 110, 'maker', {
          bottomCalc: function (values) { return values.length; },
          bottomCalcFormatter: function (x) { return x.getValue() ? '합계 ' + won(x.getValue()) + '품목' : ''; } }),
        txt('브랜드',   'brand',    100, 'maker'),
        txt('제품코드', 'jepmcd',   120, 'code'),
        txt('제품명',   'jepmnm',   200, 'pname'),
        num('정가',     'price',     90),
        num('입고가',   'inprice',   90),
        num('%',        'inRate',    70, rateFmt),
        num('판매가',   'saleprice', 90),
        num('%',        'dcRate',    70, rateFmt),
        num('재고',     'jego',      70, null, true),
        num('입고금액', 'inAmt',    110, function (v) { return '<b>' + money(v) + '</b>'; }, true),
        num('판매금액', 'saleAmt',  110, function (v) { return '<b>' + money(v) + '</b>'; }, true)
      ]
    });
  }

  // ---------------- 제조회사별 묶기 (병합 표) ----------------
  /** 제조회사 묶음 [{ name, rows }] — 서버에서 제조회사·브랜드·제품명 순으로 옴, 없음은 맨 뒤 */
  function groups() {
    var out = [], by = {};
    rows.forEach(function (r) {
      var k = groupKey(r);
      if (!by[k]) { by[k] = { name: k, rows: [] }; out.push(by[k]); }
      by[k].rows.push(r);
    });
    return out.filter(function (g) { return g.name !== NONE; }).concat(out.filter(function (g) { return g.name === NONE; }));
  }
  function sumOf(list) {
    return list.reduce(function (t, r) { t.jego += r.jego; t.inAmt += r.inAmt; t.saleAmt += r.saleAmt; return t; },
                       { jego: 0, inAmt: 0, saleAmt: 0 });
  }
  function td(v, bold) {
    var cls = 'r' + (v < 0 ? ' minus' : (Math.round(v) === 0 ? ' zero' : ''));
    return '<td class="' + cls + '">' + (bold ? '<b>' + won(v) + '</b>' : won(v)) + '</td>';
  }
  function rateTd(v, r) { return '<td class="r">' + (r.price ? '<span class="rate">' + pct(v) + '</span>' : '') + '</td>'; }
  /** 재고 | 입고금액 | 판매금액 */
  function sumTds(s) { return td(s.jego, true) + td(s.inAmt, true) + td(s.saleAmt, true); }

  function drawMerged() {
    var html = '<thead><tr><th class="c" style="width:120px">제조회사</th><th>브랜드</th><th>제품코드</th><th>제품명</th>'
             + '<th class="r">정가</th><th class="r">입고가</th><th class="r">%</th><th class="r">판매가</th><th class="r">%</th>'
             + '<th class="r">재고</th><th class="r">입고금액</th><th class="r">판매금액</th></tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="12" class="c text-muted py-5">조회된 제품이 없어요.</td></tr>';
    gs.forEach(function (g) {
      g.rows.forEach(function (r, i) {
        html += '<tr class="item">'
              + (i === 0 ? '<td class="mk" rowspan="' + (g.rows.length + 1) + '"><div class="in">' + esc(g.name) + '</div></td>' : '')
              + '<td class="maker">' + esc(r.brand) + '</td>'
              + '<td class="code">' + esc(r.jepmcd) + '</td>'
              + '<td class="pname">' + esc(r.jepmnm) + '</td>'
              + td(r.price) + td(r.inprice) + rateTd(r.inRate, r) + td(r.saleprice) + rateTd(r.dcRate, r)
              + td(r.jego) + td(r.inAmt, true) + td(r.saleAmt, true) + '</tr>';
      });
      html += '<tr class="sub"><td class="lbl" colspan="8">소계 · ' + won(g.rows.length) + '품목</td>' + sumTds(sumOf(g.rows)) + '</tr>';
    });
    html += '</tbody>';
    if (rows.length) {
      html += '<tfoot><tr><td class="c">합계</td><td colspan="8">' + won(gs.length) + '개 제조회사 · ' + won(rows.length) + '품목</td>'
            + sumTds(total) + '</tr></tfoot>';
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
      makecust: $('fMakecust').value.trim(), brand: $('fBrand').value.trim(), jepmnm: $('fJepmnm').value.trim(),
      stock: $('fStock').checked ? 'Y' : 'N'
    };
    $('loading').classList.remove('d-none');
    $('ar401Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        var priceStock = 0;
        total = { jego: 0, inAmt: 0, saleAmt: 0 };
        rows = (list || []).map(function (r) {
          ['price', 'inprice', 'saleprice', 'jego'].forEach(function (k) { r[k] = Number(r[k] || 0); });
          r.inRate = r.price ? r.inprice * 100 / r.price : 0;              // 입고율
          r.dcRate = r.price ? 100 - (r.saleprice * 100 / r.price) : 0;    // 할인율
          r.inAmt  = r.jego * r.inprice;                                   // 입고금액
          r.saleAmt = r.jego * r.saleprice;                                // 판매금액
          total.jego += r.jego;
          total.inAmt += r.inAmt;
          total.saleAmt += r.saleAmt;
          priceStock += r.jego * r.price;
          return r;
        });
        cond = p;
        draw();
        $('sCnt').textContent = won(rows.length);
        $('sJego').textContent = won(total.jego);
        $('sInAmt').textContent = won(total.inAmt);
        $('sSaleAmt').textContent = won(total.saleAmt);
        $('sInRate').textContent = pct(priceStock ? total.inAmt * 100 / priceStock : 0);
        var c = [p.makecust && '제조 ' + p.makecust, p.brand && '브랜드 ' + p.brand, p.jepmnm && '제품 ' + p.jepmnm,
                 p.stock === 'Y' && '재고 있는 제품만'].filter(Boolean);
        $('headInfo').innerHTML = c.length ? esc(c.join(' · ')) : '<b>전체 제품</b>';
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar401Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var head = ['제조회사', '브랜드', '제품코드', '제품명', '정가', '입고가', '입고율(%)', '판매가', '할인율(%)', '재고', '입고금액', '판매금액', '비고'];
    var line = function (r) {
      return [r.makecust, r.brand, r.jepmcd, r.jepmnm, r.price, r.inprice, r.price ? r1(r.inRate) : '',
              r.saleprice, r.price ? r1(r.dcRate) : '', r.jego, r.inAmt, r.saleAmt, r.remk];
    };
    var sub = function (name, list) {
      var s = list.reduce(function (t, r) { t.j += r.jego; t.i += r.inAmt; t.s += r.saleAmt; return t; }, { j: 0, i: 0, s: 0 });
      return [name + ' 소계', list.length + '품목', '', '', '', '', '', '', '', s.j, s.i, s.s, ''];
    };
    var data = [], merges = [];
    if ($('fGroup').checked) {                   // 제조회사 칸 병합 + 소계
      groups().forEach(function (g) {
        var start = data.length + 1;             // 0 행은 제목
        g.rows.forEach(function (r, i) { var l = line(r); l[0] = i === 0 ? g.name : ''; data.push(l); });
        var sl = sub(g.name, g.rows); sl[0] = ''; sl[1] = '소계 ' + g.rows.length + '품목'; data.push(sl);
        merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
      });
    } else {
      data = table.getData('active').map(line);  // 화면 정렬 순서 그대로
    }
    data.push(['합계 ' + rows.length + '품목', '', '', '', '', '', '', '', '', total.jego, total.inAmt, total.saleAmt, '']);
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    if (merges.length) ws['!merges'] = merges;
    ws['!cols'] = [14, 12, 14, 30, 9, 9, 9, 9, 9, 7, 12, 12, 20].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제품현황').replace(/\s+/g, '');
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
    $('ar401Search').onclick = search;
    document.querySelectorAll('input.enter').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    $('fStock').onchange = search;
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
