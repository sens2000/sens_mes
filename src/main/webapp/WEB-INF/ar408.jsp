<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품 수불 내역</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제품 수불 내역 (ar408) ===== */
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

  /* 선택한 제품 정보 */
  .prod { display: grid; grid-template-columns: 1.3fr 1fr 2.2fr 1.2fr repeat(4, 1fr); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .prod > div { padding: 8px 14px; border-right: 1px solid var(--line); min-width: 0; }
  .prod > div:last-child { border-right: 0; }
  .prod .k { font-size: 11px; color: var(--muted); }
  .prod .v { font-size: 15px; font-weight: 700; color: var(--navy); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .prod .v.n { text-align: right; }
  .prod .v.big { font-size: 17px; font-weight: 800; color: #1f6fd1; }
  .prod.empty .v { color: #c3c9d3; }
  @media (max-width: 1100px) { .prod { grid-template-columns: repeat(4, minmax(0, 1fr)); } }

  /* 내역 표 */
  .list-wrap { overflow: auto; }
  table.lst { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
  table.lst th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); padding: 9px 10px; font-weight: 700;
                 border-bottom: 1px solid #cfd6e2; white-space: nowrap; text-align: left; }
  table.lst th.grp-in  { background: #e3eefc; }
  table.lst th.grp-out { background: #fdeee4; }
  table.lst td { padding: 7px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
  table.lst .r { text-align: right; }
  table.lst .c { text-align: center; }
  table.lst tbody tr:hover td { background: #f0f5ff; }
  table.lst tr.open td { background: #f7f9fc; font-weight: 700; color: var(--muted); }
  table.lst td.jego { font-weight: 800; color: var(--navy); background: #f7f9fc; }
  table.lst tfoot td { position: sticky; bottom: 0; background: #e9eef7; font-weight: 800; border-top: 1px solid #b9c5d8; }
  .in-n  { color: #1f6fd1; font-weight: 700; }
  .out-n { color: #c26a00; font-weight: 700; }
  .zero  { color: #d5dae2; }
  .minus { color: #d63939; }
  .gb { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; border: 1px solid; }
  .gb-in   { color: #1f6fd1; background: #e8f1fd; border-color: #9cc2f2; }
  .gb-sale { color: #b25b00; background: #fff1e0; border-color: #f0b46b; }
  .gb-jik  { color: #7a5cc7; background: #f1ecfb; border-color: #c4b2ec; }
  .gb-etc  { color: #4a5568; background: #f1f3f6; border-color: #cbd2dc; }
  .gb-ret  { color: #c0262d; background: #fdecec; border-color: #f0a3a6; }

  #prodTable tbody tr { cursor: pointer; }
  #prodTable tbody tr:hover td { background: #f0f5ff; }
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
        <h6>제품 수불 내역</h6>
        <div class="sub" id="headInfo">제품을 찾아 선택하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">제조회사</span>
        <input type="text" class="form-control form-control-sm pfind" id="fMakecust" style="width:110px" autocomplete="off">
        <span class="lbl">브랜드</span>
        <input type="text" class="form-control form-control-sm pfind" id="fBrand" style="width:110px" autocomplete="off">
        <span class="lbl">제품명</span>
        <input type="text" class="form-control form-control-sm pfind" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:150px" autocomplete="off">
        <span class="lbl">제품코드</span>
        <input type="text" class="form-control form-control-sm pfind" id="fJepmcd" placeholder="바코드 스캔 가능" style="width:130px" autocomplete="off">
        <button type="button" class="btn btn-sm btn-primary" id="btnFind">제품 찾기</button>
        <span class="lbl ms-3">기간</span>
        <input type="date" class="form-control form-control-sm" id="fFrom" style="width:138px">
        <span>~</span>
        <input type="date" class="form-control form-control-sm" id="fTo" style="width:138px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-range="month">이번달</button>
          <button type="button" class="btn btn-outline-secondary" data-range="prev">지난달</button>
          <button type="button" class="btn btn-outline-secondary" data-range="m3">3개월</button>
          <button type="button" class="btn btn-outline-secondary" data-range="year">올해</button>
        </div>
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar408Search">조회</button>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="prod empty" id="prodBox">
        <div><div class="k">제조회사</div><div class="v" id="pMakecust">-</div></div>
        <div><div class="k">브랜드</div><div class="v" id="pBrand">-</div></div>
        <div><div class="k">제품명</div><div class="v" id="pJepmnm">-</div></div>
        <div><div class="k">제품코드</div><div class="v" id="pJepmcd">-</div></div>
        <div><div class="k">정가</div><div class="v n" id="pPrice">-</div></div>
        <div><div class="k">입고가</div><div class="v n" id="pInprice">-</div></div>
        <div><div class="k">판매가</div><div class="v n" id="pSaleprice">-</div></div>
        <div><div class="k">현재고</div><div class="v n big" id="pJego">-</div></div>
      </div>
      <div class="list-wrap" id="listWrap"><table class="lst" id="listTable"></table></div>
      <div class="loading-mask d-none" id="loading">조회 중입니다…</div>
    </div>
  </div>
</div>

<!-- 제품 찾기 -->
<div class="modal fade" id="prodModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-lg modal-dialog-scrollable">
    <div class="modal-content">
      <div class="modal-header py-2">
        <h6 class="modal-title fw-bold">제품 찾기</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="닫기"></button>
      </div>
      <div class="modal-body p-2">
        <table class="table table-sm mb-0" id="prodTable" style="font-size:13px">
          <thead class="table-light"><tr><th>제조회사</th><th>브랜드</th><th>제품명</th><th>제품코드</th>
            <th class="text-end">판매가</th><th class="text-end">현재고</th></tr></thead>
          <tbody></tbody>
        </table>
        <div class="small text-muted mt-1 d-none" id="prodMore">결과가 많아 200개까지만 보입니다. 조건을 더 자세히 입력하세요.</div>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 제품 수불 내역 (ar408) — 선택한 제품 하나의 입고 · 출고(매출·직판) · 조정(MC27)
 *   - 제품 찾기 : 제조회사·브랜드·제품명·제품코드 (포함 검색) → 목록에서 선택, 하나면 바로 선택
 *   - 위에서 아래로 최근 → 과거 순서, 재고는 상단 현재고에서 거꾸로 계산
 *       현재고 → (종료일 이후 입출고) → 기말(종료일) → 내역 … → 이월(시작일 전날)
 *   - 줄의 재고 = 그 거래가 끝난 뒤 재고, 바로 아래 줄 재고 = 이 줄 재고 - 입고 + 출고 + 조정
 *   - 같은 날은 조정 → 매출·직판 → 입고 순서 (거꾸로 보므로)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar408';
  var prod = null, rows = [], closing = 0, after = { in: 0, out: 0, etc: 0 }, cond = null, prodRows = [], prodModal = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function ymd(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function dLabel(s) { s = String(s || ''); return s.length === 8 ? s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2) : s; }
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
    if (kind === 'month') { $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth(), 1)); $('fTo').value = ymd(d); }
    if (kind === 'prev')  { $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth() - 1, 1)); $('fTo').value = ymd(new Date(d.getFullYear(), d.getMonth(), 0)); }
    if (kind === 'm3')    { $('fFrom').value = ymd(new Date(d.getFullYear(), d.getMonth() - 2, 1)); $('fTo').value = ymd(d); }
    if (kind === 'year')  { $('fFrom').value = ymd(new Date(d.getFullYear(), 0, 1)); $('fTo').value = ymd(d); }
  }

  // ---------------- 제품 찾기 ----------------
  function findProducts() {
    var p = { makecust: $('fMakecust').value.trim(), brand: $('fBrand').value.trim(), jepmnm: $('fJepmnm').value.trim(),
              jepmcd: $('fJepmcd').value.trim() };
    if (!p.makecust && !p.brand && !p.jepmnm && !p.jepmcd) { alert('제조회사·브랜드·제품명·제품코드 중 하나는 입력하세요.'); $('fJepmnm').focus(); return; }
    var body = $('prodTable').querySelector('tbody');
    body.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-4">찾는 중…</td></tr>';
    api('/products', p)
      .then(function (d) {
        prodRows = d.rows || [];
        if (prodRows.length === 1) { pickProduct(prodRows[0]); return; }   // 하나면 바로 선택
        $('prodMore').classList.toggle('d-none', !d.more);
        body.innerHTML = prodRows.length ? prodRows.map(function (r, i) {
          return '<tr data-i="' + i + '"><td>' + esc(r.makecust) + '</td><td>' + esc(r.brand) + '</td><td><b>' + esc(r.jepmnm) + '</b></td>'
               + '<td class="text-muted">' + esc(r.jepmcd) + '</td><td class="text-end">' + won(r.saleprice) + '</td>'
               + '<td class="text-end">' + won(r.jego) + '</td></tr>';
        }).join('') : '<tr><td colspan="6" class="text-center text-muted py-4">찾는 제품이 없어요.</td></tr>';
        prodModal.show();
      })
      .catch(fail);
  }
  function showProduct(p) {
    $('prodBox').classList.toggle('empty', !p);
    $('pMakecust').textContent  = p ? p.makecust || '-' : '-';
    $('pBrand').textContent     = p ? p.brand || '-' : '-';
    $('pJepmnm').textContent    = p ? p.jepmnm || '-' : '-';
    $('pJepmnm').title          = p ? p.jepmnm : '';
    $('pJepmcd').textContent    = p ? p.jepmcd || '-' : '-';
    $('pPrice').textContent     = p ? won(p.price) : '-';
    $('pInprice').textContent   = p ? won(p.inprice) : '-';
    $('pSaleprice').textContent = p ? won(p.saleprice) : '-';
    $('pJego').textContent      = p ? won(p.jego) : '-';
  }
  function pickProduct(p) {
    prod = p;
    showProduct(p);
    prodModal.hide();
    search();
  }

  // ---------------- 내역 ----------------
  var RANK = { '입고': 0, '매출': 1, '직판': 1, '조정': 2 };
  function gbClass(r) {
    if (r.procgubun === '입고') return 'gb-in';
    if (r.procgubun === '조정') return 'gb-etc';
    if (r.saleqty < 0) return 'gb-ret';                     // 반품
    return r.procgubun === '직판' ? 'gb-jik' : 'gb-sale';
  }
  function gbText(r) { return r.saleqty < 0 && r.procgubun !== '입고' && r.procgubun !== '조정' ? r.procgubun + '(반품)' : r.procgubun; }
  function n(v, c) { return v ? '<span class="' + (v < 0 ? 'minus' : (c || '')) + '">' + won(v) + '</span>' : '<span class="zero">0</span>'; }

  /** 화면·엑셀 공통 : 위(현재고)에서 아래(이월)로 거꾸로 계산한 줄 목록 */
  function lines() {
    var out = [], hasAfter = after.in || after.out || after.etc;
    var today = ymd(new Date());
    out.push({ kind: 'now', date: today.replace(/-/g, ''), label: '현재고', stock: prod.jego });
    if (hasAfter) {
      out.push({ kind: 'after', date: '', label: '종료일 이후', cust: cond.to + ' 이후 ~ 오늘',
                 inqty: after.in, saleqty: after.out, etcqty: after.etc, stock: null });
      out.push({ kind: 'close', date: cond.to.replace(/-/g, ''), label: '기말', stock: closing });
    }
    var cur = closing;
    for (var i = rows.length - 1; i >= 0; i--) {         // 최근 → 과거
      var r = rows[i];
      out.push({ kind: 'row', r: r, date: r.procdate, stock: cur });
      cur = cur - r.inqty + r.saleqty + r.etcqty;         // 이 거래 전 재고
    }
    out.push({ kind: 'open', date: cond.from.replace(/-/g, ''), label: '이월', stock: cur });
    return out;
  }

  function draw() {
    var html = '<thead><tr><th class="c" style="width:110px">일자</th><th class="c" style="width:100px">구분</th><th>매입처 / 매출처</th>'
             + '<th class="r grp-in">입고</th><th class="r grp-in">가격</th>'
             + '<th class="r grp-out">출고</th><th class="r grp-out">판매</th>'
             + '<th class="r">조정</th><th class="r">재고</th></tr></thead><tbody>';
    if (!prod || !cond) {
      html += '<tr><td colspan="9" class="c text-muted py-5">위에서 제품을 찾아 선택하세요.</td></tr></tbody>';
      $('listTable').innerHTML = html;
      return;
    }
    var t = { in: 0, out: 0, etc: 0 };
    lines().forEach(function (l) {
      var stockTd = '<td class="r jego' + (l.stock < 0 ? ' minus' : '') + '">' + (l.stock == null ? '' : won(l.stock)) + '</td>';
      if (l.kind !== 'row') {
        var qty = l.kind === 'after'
          ? '<td class="r">' + n(l.inqty, 'in-n') + '</td><td></td><td class="r">' + n(l.saleqty, 'out-n') + '</td><td></td><td class="r">' + n(l.etcqty) + '</td>'
          : '<td></td><td></td><td></td><td></td><td></td>';
        html += '<tr class="open"><td class="c">' + dLabel(l.date) + '</td><td class="c">' + l.label + '</td><td>' + esc(l.cust || '') + '</td>'
              + qty + stockTd + '</tr>';
        if (l.kind === 'open' && !rows.length) html += '';
        return;
      }
      var r = l.r;
      t.in += r.inqty; t.out += r.saleqty; t.etc += r.etcqty;
      html += '<tr><td class="c">' + dLabel(r.procdate) + '</td>'
            + '<td class="c"><span class="gb ' + gbClass(r) + '">' + esc(gbText(r)) + '</span></td>'
            + '<td>' + esc(r.custname) + '</td>'
            + '<td class="r">' + n(r.inqty, 'in-n') + '</td><td class="r">' + (r.inprice ? won(r.inprice) : '') + '</td>'
            + '<td class="r">' + n(r.saleqty, 'out-n') + '</td><td class="r">' + (r.saleprice ? won(r.saleprice) : '') + '</td>'
            + '<td class="r">' + n(r.etcqty) + '</td>' + stockTd + '</tr>';
    });
    if (!rows.length) html += '<tr><td colspan="9" class="c text-muted py-3">기간 안에 입출고가 없어요.</td></tr>';
    html += '</tbody><tfoot><tr><td class="c">기간 합계</td><td colspan="2">' + won(rows.length) + '건</td>'
          + '<td class="r">' + won(t.in) + '</td><td></td><td class="r">' + won(t.out) + '</td><td></td>'
          + '<td class="r">' + won(t.etc) + '</td><td class="r">' + won(closing) + '</td></tr></tfoot>';
    $('listTable').innerHTML = html;
    fit();
  }

  function search() {
    if (!prod) { alert('제품을 먼저 찾아 선택하세요.'); $('fJepmnm').focus(); return; }
    var p = { jepmkey: prod.jepmkey, from: $('fFrom').value, to: $('fTo').value };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar408Search').disabled = true;
    api('/list', p)
      .then(function (d) {
        prod = d.product || prod;
        showProduct(prod);
        closing = Number(d.closing || 0);
        after = { in: Number(d.afterIn || 0), out: Number(d.afterOut || 0), etc: Number(d.afterEtc || 0) };
        rows = (d.rows || []).map(function (r) {
          ['inqty', 'inprice', 'saleqty', 'saleprice', 'etcqty'].forEach(function (k) { r[k] = Number(r[k] || 0); });
          return r;
        }).sort(function (a, b) {                     // 일자 → 입고·판매·조정 순 (화면에는 거꾸로 보여 줌)
          return a.procdate < b.procdate ? -1 : a.procdate > b.procdate ? 1 : (RANK[a.procgubun] || 0) - (RANK[b.procgubun] || 0);
        });
        cond = p;
        draw();
        $('headInfo').innerHTML = '<b>' + esc(prod.jepmnm) + '</b> · ' + p.from + ' ~ ' + p.to;
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar408Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!prod || !cond) { alert('먼저 제품을 선택하고 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var info = [['제조회사', prod.makecust, '브랜드', prod.brand, '제품명', prod.jepmnm, '제품코드', prod.jepmcd],
                ['정가', prod.price, '입고가', prod.inprice, '판매가', prod.saleprice, '현재고', prod.jego],
                ['기간', cond.from + ' ~ ' + cond.to], []];
    var head = ['일자', '구분', '매입처/매출처', '입고', '가격', '출고', '판매', '조정', '재고'];
    var t = { in: 0, out: 0, etc: 0 }, data = [];
    lines().forEach(function (l) {
      if (l.kind !== 'row') {
        data.push([dLabel(l.date), l.label, l.cust || '', l.inqty || '', '', l.saleqty || '', '', l.etcqty || '', l.stock == null ? '' : l.stock]);
        return;
      }
      var r = l.r;
      t.in += r.inqty; t.out += r.saleqty; t.etc += r.etcqty;
      data.push([dLabel(r.procdate), gbText(r), r.custname, r.inqty, r.inprice || '', r.saleqty, r.saleprice || '', r.etcqty, l.stock]);
    });
    data.push(['기간 합계', rows.length + '건', '', t.in, '', t.out, '', t.etc, closing]);
    var ws = XLSX.utils.aoa_to_sheet(info.concat([head], data));
    ws['!cols'] = [12, 12, 24, 8, 10, 8, 10, 8, 9].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제품수불내역').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + (prod.jepmcd || prod.jepmnm) + '_' + cond.from + '_' + cond.to + '.xlsx');
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var w = $('listWrap');
    if (w.offsetParent) w.style.height = Math.max(300, window.innerHeight - w.getBoundingClientRect().top - 30) + 'px';
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    prodModal = bootstrap.Modal.getOrCreateInstance($('prodModal'));
    setRange('month');
    $('btnFind').onclick = findProducts;
    document.querySelectorAll('input.pfind').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); findProducts(); } });
    });
    $('prodTable').addEventListener('click', function (e) {
      var tr = e.target.closest('tr[data-i]');
      if (tr) pickProduct(prodRows[Number(tr.dataset.i)]);
    });
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); if (prod) search(); };
    });
    $('ar408Search').onclick = search;
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    draw();
    fit();
    $('fJepmnm').focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
