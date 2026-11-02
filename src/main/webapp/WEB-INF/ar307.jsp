<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품별 판매현황</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제품별 판매현황 (ar307) ===== */
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
  .filter .form-select { width: 110px; }
  .mem-pick { display: inline-flex; align-items: center; gap: 4px; padding: 2px 4px 2px 10px; border: 1px solid #b9c5d8;
              border-radius: 14px; background: #eef3fb; font-size: 12px; font-weight: 700; color: var(--navy); }
  .mem-pick button { border: 0; background: transparent; color: var(--muted); font-size: 15px; line-height: 1; padding: 0 4px; }

  .sum-bar { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v.main { color: #1f6fd1; }
  .sum-bar .v.profit { color: #1f7a4d; }
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
  table.merge tbody tr.item:hover td:not(.mk):not(.br) { background: #f0f5ff; }
  table.merge td.code { color: var(--muted); font-size: 11px; margin-left: 6px; }
  /* 제조회사 칸 (위아래 병합) */
  table.merge td.mk { text-align: center; vertical-align: middle; font-weight: 800; color: var(--navy);
                      background: #f4f7fc; border-right: 1px solid #cfd6e2; border-bottom: 2px solid #b9c5d8; }
  /* 브랜드 칸 (제조회사 안에서 위아래 병합) */
  table.merge td.br { text-align: center; vertical-align: middle; font-weight: 700; color: #3d4b66;
                      background: #fafbfd; border-right: 1px solid #e3e7ee; border-bottom: 2px solid #d5deec; }
  /* 브랜드 소계 */
  table.merge tr.sub-b td:not(.mk):not(.br) { background: #f7f9fc; font-weight: 700; border-bottom: 2px solid #d5deec; }
  /* 제조회사 소계 */
  table.merge tr.sub-m td:not(.mk) { background: #eef3fb; font-weight: 800; color: var(--navy); border-bottom: 2px solid #b9c5d8; }
  table.merge td.lbl { color: var(--muted); }
  table.merge tr.sub-m td.lbl { color: var(--navy); }
  table.merge tfoot td { position: sticky; bottom: 0; background: #e9eef7; font-weight: 800; border-top: 1px solid #b9c5d8; }

  #memTable tbody tr { cursor: pointer; }
  #memTable tbody tr:hover td { background: #f0f5ff; }
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
        <h6>제품별 판매현황</h6>
        <div class="sub" id="headInfo">기간을 정하고 조회하세요</div>
      </div>
      <div class="filter-wrap">
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
          <span class="lbl">판매자</span>
          <input type="text" class="form-control form-control-sm enter" id="fPruser" placeholder="빈칸 = 전체" style="width:100px" autocomplete="off">
          <span class="lbl">담당자</span>
          <input type="text" class="form-control form-control-sm enter" id="fManager" placeholder="빈칸 = 전체" style="width:100px" autocomplete="off">
          <span class="lbl">등급</span>
          <select class="form-select form-select-sm" id="fGrade"><option value="">전체</option></select>
          <span class="lbl">회원</span>
          <div class="input-group input-group-sm" id="memSearchBox" style="width:170px">
            <input type="text" class="form-control" id="fMemQ" placeholder="이름·전화번호" autocomplete="off">
            <button type="button" class="btn btn-outline-secondary" id="btnMemFind" title="회원 찾기">찾기</button>
          </div>
          <span class="mem-pick d-none" id="memPick"><span id="memPickName"></span><button type="button" id="btnMemClear" title="회원 조건 지우기">&times;</button></span>
        </div>
        <div class="filter">
          <span class="lbl ms-0">제조회사</span>
          <input type="text" class="form-control form-control-sm enter" id="fMakecust" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
          <span class="lbl">브랜드</span>
          <input type="text" class="form-control form-control-sm enter" id="fBrand" placeholder="빈칸 = 전체" style="width:120px" autocomplete="off">
          <span class="lbl">제품명</span>
          <input type="text" class="form-control form-control-sm enter" id="fJepmnm" placeholder="일부만 입력해도 됨" style="width:160px" autocomplete="off">
          <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar307Search">조회</button>
          <div class="form-check form-check-inline ms-2 mb-0">
            <input class="form-check-input" type="checkbox" id="fSubB" checked>
            <label class="form-check-label small" for="fSubB">브랜드 소계</label>
          </div>
          <div class="form-check form-check-inline mb-0">
            <input class="form-check-input" type="checkbox" id="fSubM" checked>
            <label class="form-check-label small" for="fSubM">제조회사 소계</label>
          </div>
          <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
        </div>
      </div>
      <div class="sum-bar">
        <div><div class="k">품목수</div><div class="v" id="sItems">0</div></div>
        <div><div class="k">수량</div><div class="v" id="sQty">0</div></div>
        <div><div class="k">서비스</div><div class="v" id="sSvc">0</div></div>
        <div><div class="k">판매</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">이익</div><div class="v profit" id="sProfit">0</div></div>
        <div><div class="k">이익율</div><div class="v" id="sRate">0%</div></div>
      </div>
      <div class="merge-wrap" id="mergeWrap"><table class="merge" id="mergeTable"></table></div>
      <div class="loading-mask d-none" id="loading">조회 중입니다…</div>
    </div>
  </div>
</div>

<!-- 회원 찾기 -->
<div class="modal fade" id="memModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-dialog-scrollable">
    <div class="modal-content">
      <div class="modal-header py-2">
        <h6 class="modal-title fw-bold">회원 찾기</h6>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="닫기"></button>
      </div>
      <div class="modal-body p-2">
        <div class="input-group input-group-sm mb-2">
          <input type="text" class="form-control" id="memQ" placeholder="이름 또는 전화번호(숫자만, 3자리 이상)" autocomplete="off">
          <button type="button" class="btn btn-secondary" id="btnMemQ">검색</button>
        </div>
        <table class="table table-sm mb-0" id="memTable" style="font-size:13px">
          <thead class="table-light"><tr><th>성명</th><th>전화번호</th><th class="text-center">등급</th><th>담당</th></tr></thead>
          <tbody><tr><td colspan="4" class="text-center text-muted py-4">이름이나 전화번호로 검색하세요.</td></tr></tbody>
        </table>
        <div class="small text-muted mt-1 d-none" id="memMore">결과가 많아 100명까지만 보입니다. 더 자세히 입력하세요.</div>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 제품별 판매현황 (ar307) — MC20_MST + MC20_DTL + SHOP_JEPM_MST + member, KIND = '매출'
 *   - 평균판매가 = 판매 ÷ 수량
 *   - 이익       = 판매 - 원가(INPRICE × QTY)
 *   - %          = 이익 × 100 ÷ 판매
 *   - 묶음       = 제조회사 > 브랜드 칸 병합, 브랜드 소계 · 제조회사 소계 · 전체 합계
 *   - 회원       = 찾기에서 고른 회원의 MEMNO 로 검색
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar307';
  var SUMS = ['qty', 'svc', 'amt', 'inamt', 'jego'];
  var rows = [], cond = null, pickedMem = null, memModal = null;
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
  function div(a, b) { return b ? a / b : 0; }
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

  // ---------------- 계산 ----------------
  function derive(r) {
    r.avgPrice = div(r.amt, r.qty);
    r.profit   = r.amt - r.inamt;
    r.rate     = div(r.profit * 100, r.amt);
    return r;
  }
  function sums(list) {
    var s = { cnt: list.length };
    SUMS.forEach(function (k) { s[k] = 0; });
    list.forEach(function (r) { SUMS.forEach(function (k) { s[k] += r[k] || 0; }); });
    return derive(s);
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
      var seen = {};
      var list = (d.grades || []).map(function (n) { return String(n || '').trim(); })
        .filter(function (n) { if (!n || seen[n]) return false; seen[n] = 1; return true; });
      $('fGrade').insertAdjacentHTML('beforeend', list.map(function (n) { return '<option>' + esc(n) + '</option>'; }).join(''));
    });
  }

  // ---------------- 회원 찾기 ----------------
  var memRows = [];
  function openMemFind() {
    $('memQ').value = $('fMemQ').value.trim();
    memModal.show();
    if ($('memQ').value) findMembers();
  }
  function findMembers() {
    var q = $('memQ').value.trim();
    if (!q) { alert('이름이나 전화번호를 입력하세요.'); return; }
    var body = $('memTable').querySelector('tbody');
    body.innerHTML = '<tr><td colspan="4" class="text-center text-muted py-4">찾는 중…</td></tr>';
    api('/members', { q: q })
      .then(function (d) {
        memRows = d.rows || [];
        $('memMore').classList.toggle('d-none', !d.more);
        if (!memRows.length) { body.innerHTML = '<tr><td colspan="4" class="text-center text-muted py-4">찾는 회원이 없어요.</td></tr>'; return; }
        if (memRows.length === 1) { pickMember(memRows[0]); return; }    // 한 명이면 바로 선택
        body.innerHTML = memRows.map(function (m, i) {
          return '<tr data-i="' + i + '"><td><b>' + esc(m.name) + '</b></td><td>' + esc(fmtTel(m.handno)) + '</td>'
               + '<td class="text-center">' + esc(m.grade) + '</td><td>' + esc(m.manager) + '</td></tr>';
        }).join('');
      })
      .catch(function (e) { body.innerHTML = '<tr><td colspan="4" class="text-center text-danger py-4">' + esc(e.message || e) + '</td></tr>'; });
  }
  function pickMember(m) {
    pickedMem = m;
    $('memPickName').textContent = m.name + (m.handno ? ' · ' + fmtTel(m.handno).slice(-4) : '');
    $('memPick').classList.remove('d-none');
    $('memSearchBox').classList.add('d-none');
    $('fMemQ').value = '';
    memModal.hide();
    search();
  }
  function clearMember() {
    pickedMem = null;
    $('memPick').classList.add('d-none');
    $('memSearchBox').classList.remove('d-none');
    search();
  }

  // ---------------- 표 ----------------
  /** 제조회사 > 브랜드 묶음 (서버에서 제조회사·브랜드·제품명 순으로 옴) */
  var NONE = '(없음)';
  function groups() {
    var out = [];
    rows.forEach(function (r) {
      var mn = r.makecust || NONE, bn = r.brand || NONE;
      var m = out[out.length - 1];
      if (!m || m.name !== mn) out.push(m = { name: mn, rows: [], brands: [] });
      var b = m.brands[m.brands.length - 1];
      if (!b || b.name !== bn) m.brands.push(b = { name: bn, rows: [] });
      b.rows.push(r);
      m.rows.push(r);
    });
    return out;
  }
  function numTd(v, fmt, bold) {
    var cls = 'r' + (v < 0 ? ' minus' : (Math.round(v) === 0 ? ' zero' : ''));
    return '<td class="' + cls + '">' + (bold ? '<b>' + fmt(v) + '</b>' : fmt(v)) + '</td>';
  }
  /** 평균판매가 | 수량 | 서비스 | 판매 | 이익 | % | 현재고 */
  function numCells(r) {
    return numTd(r.avgPrice, won) + numTd(r.qty, won) + numTd(r.svc, won) + numTd(r.amt, won, true)
         + '<td class="r fw-bold ' + (r.profit < 0 ? 'minus' : 'text-success') + '">' + won(r.profit) + '</td>'
         + numTd(r.rate, pct) + numTd(r.jego, won);
  }
  function once(cls, span, html) {
    var done = false;
    return function () {
      if (done) return '';
      done = true;
      return '<td class="' + cls + '" rowspan="' + span + '">' + html + '</td>';
    };
  }

  /** 병합 표 (제조회사 | 브랜드 | 제품들 … 브랜드 소계 | 제조회사 소계) */
  function draw() {
    var subB = $('fSubB').checked, subM = $('fSubM').checked;
    var html = '<thead><tr><th class="c" style="width:120px">제조회사</th><th class="c" style="width:110px">브랜드</th>'
             + '<th>제품명</th><th class="r">정가</th><th class="r">평균판매가</th><th class="r">수량</th><th class="r">서비스</th>'
             + '<th class="r">판매</th><th class="r">이익</th><th class="r">%</th><th class="r">현재고</th></tr></thead><tbody>';
    var ms = groups();
    if (!ms.length) html += '<tr><td colspan="11" class="c text-muted py-5">조회된 판매가 없어요.</td></tr>';
    ms.forEach(function (m) {
      // 제조회사 칸이 덮을 줄 수 = 제품 + 브랜드 소계(브랜드마다 1줄) + 제조회사 소계(1줄)
      var leadM = once('mk', m.rows.length + (subB ? m.brands.length : 0) + (subM ? 1 : 0), esc(m.name));
      m.brands.forEach(function (b) {
        var leadB = once('br', b.rows.length + (subB ? 1 : 0), esc(b.name));
        var lead = function () { return leadM() + leadB(); };
        b.rows.forEach(function (r) {
          html += '<tr class="item">' + lead()
                + '<td>' + esc(r.jepmnm) + (r.jepmcd ? ' <span class="code">' + esc(r.jepmcd) + '</span>' : '') + '</td>'
                + numTd(r.price, won) + numCells(r) + '</tr>';
        });
        if (subB) {
          var s = sums(b.rows);
          html += '<tr class="sub-b">' + lead() + '<td class="lbl" colspan="2">소계 · ' + won(s.cnt) + '품목</td>' + numCells(s) + '</tr>';
        }
      });
      if (subM) {
        var s = sums(m.rows);
        html += '<tr class="sub-m">' + leadM() + '<td class="lbl" colspan="3">' + esc(m.name) + ' 소계 · ' + won(s.cnt) + '품목</td>' + numCells(s) + '</tr>';
      }
    });
    html += '</tbody>';
    if (rows.length) {
      var t = sums(rows);
      html += '<tfoot><tr><td class="c">합계</td><td colspan="3">' + won(t.cnt) + '품목</td>' + numCells(t) + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
    fit();
  }

  function search() {
    var p = {
      from: $('fFrom').value, to: $('fTo').value,
      pruser: $('fPruser').value.trim(), manager: $('fManager').value.trim(), grade: $('fGrade').value,
      memno: pickedMem ? pickedMem.memno : '',
      makecust: $('fMakecust').value.trim(), brand: $('fBrand').value.trim(), jepmnm: $('fJepmnm').value.trim()
    };
    if (!p.from || !p.to) { alert('기간을 입력하세요.'); return; }
    if (p.from > p.to) { alert('시작일이 종료일보다 늦습니다.'); return; }
    $('loading').classList.remove('d-none');
    $('ar307Search').disabled = true;
    api('/list', p)
      .then(function (list) {
        rows = (list || []).map(function (r) {
          SUMS.concat(['price']).forEach(function (k) { r[k] = Number(r[k] || 0); });
          return derive(r);
        });
        cond = p;
        draw();
        var t = sums(rows);
        $('sItems').textContent = won(t.cnt);
        $('sQty').textContent = won(t.qty);
        $('sSvc').textContent = won(t.svc);
        $('sAmt').textContent = won(t.amt);
        $('sProfit').textContent = won(t.profit);
        $('sRate').textContent = pct(t.rate);
        var c = [p.pruser && '판매자 ' + p.pruser, p.manager && '담당 ' + p.manager, p.grade && '등급 ' + p.grade,
                 pickedMem && '회원 ' + pickedMem.name, p.makecust && '제조 ' + p.makecust,
                 p.brand && '브랜드 ' + p.brand, p.jepmnm && '제품 ' + p.jepmnm].filter(Boolean);
        $('headInfo').innerHTML = '<b>' + p.from + ' ~ ' + p.to + '</b>' + (c.length ? ' · ' + esc(c.join(' · ')) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar307Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var subB = $('fSubB').checked, subM = $('fSubM').checked;
    var r1 = function (n) { return Math.round(n * 10) / 10; };
    var head = ['제조회사', '브랜드', '제품명', '제품코드', '정가', '평균판매가', '수량', '서비스', '판매', '이익', '이익율(%)', '현재고'];
    var nums = function (r) { return [Math.round(r.avgPrice), r.qty, r.svc, r.amt, r.profit, r1(r.rate), r.jego]; };
    var data = [], merges = [];
    groups().forEach(function (m) {
      var mStart = data.length + 1;                // 0 행은 제목
      m.brands.forEach(function (b) {
        var bStart = data.length + 1;
        b.rows.forEach(function (r) { data.push(['', '', r.jepmnm, r.jepmcd, r.price].concat(nums(r))); });
        if (subB) { var s = sums(b.rows); data.push(['', '', '소계 · ' + s.cnt + '품목', '', ''].concat(nums(s))); }
        data[bStart - 1][1] = b.name;
        if (data.length > bStart) merges.push({ s: { r: bStart, c: 1 }, e: { r: data.length, c: 1 } });
      });
      if (subM) { var s = sums(m.rows); data.push(['', m.name + ' 소계', s.cnt + '품목', '', ''].concat(nums(s))); }
      data[mStart - 1][0] = m.name;
      merges.push({ s: { r: mStart, c: 0 }, e: { r: data.length, c: 0 } });
    });
    var t = sums(rows);
    data.push(['합계', '', t.cnt + '품목', '', ''].concat(nums(t)));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!merges'] = merges;
    ws['!cols'] = [14, 12, 30, 12, 10, 11, 8, 8, 13, 12, 9, 8].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제품별판매현황').replace(/\s+/g, '');
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
    memModal = bootstrap.Modal.getOrCreateInstance($('memModal'));
    setRange('today');
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); search(); };
    });
    $('ar307Search').onclick = search;
    $('fGrade').onchange = search;
    document.querySelectorAll('input.enter').forEach(function (el) {
      el.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    // 회원 찾기
    $('btnMemFind').onclick = openMemFind;
    $('fMemQ').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); openMemFind(); } });
    $('btnMemQ').onclick = findMembers;
    $('memQ').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); findMembers(); } });
    $('memModal').addEventListener('shown.bs.modal', function () { $('memQ').focus(); });
    $('memTable').addEventListener('click', function (e) {
      var tr = e.target.closest('tr[data-i]');
      if (tr) pickMember(memRows[Number(tr.dataset.i)]);
    });
    $('btnMemClear').onclick = clearMember;
    ['fSubB', 'fSubM'].forEach(function (id) { $(id).onchange = draw; });
    $('btnExcel').onclick = excel;
    window.addEventListener('resize', fit);
    fit();
    loadInit().catch(fail).then(search);
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
