<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품별 판매내역</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 제품별 판매내역 (ar308) ===== */
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
  table.merge tbody tr.item:hover td:not(.day) { background: #cddcf3 !important; }
  table.merge td.code { color: var(--muted); font-size: 11px; }
  table.merge td.muted { color: var(--muted); }
  /* 전표번호별 번갈아 색 */
  table.merge tr.item.alt td:not(.day) { background: #e2ebf8; }
  /* 전표가 바뀌는 줄 위에 구분선 */
  table.merge tr.item.jp-first td:not(.day) { border-top: 1px solid #a9bcd9; }
  .grade { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; border: 1px solid #cbd2dc; color: #4a5568; background: #fff; }
  .grade-GOLD   { color: #9a6b00; background: #fff4d1; border-color: #e7b93c; }
  .grade-SILVER { color: #56606e; background: #eef0f3; border-color: #aab2bd; }
  .grade-YELLO, .grade-YELLOW { color: #8a6d00; background: #fffbd6; border-color: #e6cf3a; }
  .grade-GREEN  { color: #1f7a4d; background: #e3f5ea; border-color: #5cbf8a; }
  /* 반품 (수량 마이너스) — 번갈아 색보다 우선 */
  table.merge tr.item.ret td:not(.day),
  table.merge tr.item.alt.ret td:not(.day) { background: #fff5f5; }
  table.merge tr.item.ret:hover td:not(.day) { background: #ffeaea; }
  .ret-badge { display: inline-block; padding: 0 6px; margin-right: 4px; border-radius: 8px; font-size: 11px; font-weight: 700;
               color: #fff; background: #d63939; vertical-align: 1px; }
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

  /* 영수건 : 줄 클릭 → 판매 상세 */
  table.merge tbody tr.rc { cursor: pointer; }
  table.merge tbody tr.rc:hover td:not(.day) { background: #cddcf3 !important; }
  table.merge td.tot { font-weight: 800; color: #1f6fd1; }
  #modeGrp .btn { font-weight: 700; min-width: 64px; }
  #dtlTable td, #dtlTable th { white-space: nowrap; }
  #dtlTable tfoot td { background: #e9eef7; font-weight: 800; }
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
        <h6>제품별 판매내역</h6>
        <div class="sub" id="headInfo">기간을 정하고 조회하세요</div>
      </div>
      <div class="filter-wrap">
        <div class="filter">
          <div class="btn-group btn-group-sm me-1" role="group" id="modeGrp" aria-label="보고서 형태">
            <button type="button" class="btn btn-primary" data-mode="rcpt">영수건</button>
            <button type="button" class="btn btn-outline-primary" data-mode="item">내역별</button>
          </div>
          <span class="lbl">기간</span>
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
          <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar308Search">조회</button>
          <div class="form-check form-check-inline ms-2 mb-0">
            <input class="form-check-input" type="checkbox" id="fSubD" checked>
            <label class="form-check-label small" for="fSubD">일자 소계</label>
          </div>
          <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
        </div>
      </div>
      <div class="sum-bar" style="grid-template-columns: repeat(4, minmax(0, 1fr));">
        <div><div class="k">판매일수</div><div class="v" id="sDays">0</div></div>
        <div><div class="k">건수</div><div class="v" id="sCnt">0</div></div>
        <div><div class="k">회원수</div><div class="v" id="sMem">0</div></div>
        <div><div class="k">금액</div><div class="v main" id="sAmt">0</div></div>
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

<!-- 영수증 판매 상세 -->
<div class="modal fade" id="dtlModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-xl modal-dialog-scrollable">
    <div class="modal-content">
      <div class="modal-header py-2" style="background:var(--navy);color:#fff">
        <div>
          <h6 class="modal-title fw-bold mb-0">판매 상세</h6>
          <div class="small" id="dtlHead" style="opacity:.9"></div>
        </div>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="닫기"></button>
      </div>
      <div class="modal-body p-2">
        <div class="d-flex flex-wrap gap-3 small px-1 pb-2" id="dtlPay"></div>
        <table class="table table-sm table-hover mb-0" id="dtlTable" style="font-size:13px">
          <thead class="table-light"><tr><th>제조회사</th><th>브랜드</th><th>제품명</th><th class="text-end">정가</th><th class="text-end">판매가</th><th class="text-end">수량</th><th class="text-end">금액</th></tr></thead>
          <tbody></tbody>
          <tfoot></tfoot>
        </table>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 제품별 판매내역 (ar308) — MC20_MST + MC20_DTL + SHOP_JEPM_MST + member, KIND = '매출'
 *   - 보고서 형태 : 영수건(기본, MC20_MST 한 건 = 한 줄, 줄 클릭 → 판매 상세) / 내역별(제품 줄)
 *   - 일자 칸 병합, 일자 소계 · 전체 합계 는 금액만
 *   - 회원 = 찾기에서 고른 회원의 MEMNO 로 검색
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar308';
  var rows = [], cond = null, pickedMem = null, memModal = null, dtlModal = null;
  var mode = 'rcpt';          // 'rcpt' 영수건 (기본) / 'item' 내역별
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
  function amtSum(list) { return list.reduce(function (s, r) { return s + (r.amt || 0); }, 0); }
  function fsum(list, k) { return list.reduce(function (s, r) { return s + (r[k] || 0); }, 0); }
  var PAY = ['cashamt', 'cardamt', 'tot', 'saleamt', 'bonususe', 'bonusamt'];   // 영수건 숫자 칸
  function dayLabel(s) { s = String(s || ''); return s.length === 8 ? s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2) : s; }
  function dayName(s) {
    s = String(s || '');
    if (s.length !== 8) return '';
    var d = new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2));
    return '일월화수목금토'.charAt(d.getDay());
  }
  /** 시간 : 1430 → 14:30, 143015 → 14:30:15, 그 밖에는 그대로 */
  function timeLabel(s) {
    s = String(s || '').trim();
    var d = s.replace(/\D/g, '');
    if (d.length === s.length && d.length === 4) return d.substr(0, 2) + ':' + d.substr(2, 2);
    if (d.length === s.length && d.length === 6) return d.substr(0, 2) + ':' + d.substr(2, 2) + ':' + d.substr(4, 2);
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
  /** 일자 묶음 [{ day, rows }] (서버에서 일자·시간 순으로 옴) */
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
    if (mode === 'rcpt') return drawRcpt();
    var subD = $('fSubD').checked;
    var html = '<thead><tr><th class="c" style="width:110px">일자</th><th class="c">시간</th><th>판매자</th><th>성명</th><th class="c">등급</th><th>전화</th>'
             + '<th>제조회사</th><th>브랜드</th><th>제품명</th><th class="r">정가</th><th class="r">판매가</th>'
             + '<th class="r">수량</th><th class="r">금액</th></tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="13" class="c text-muted py-5">조회된 판매가 없어요.</td></tr>';
    var alt = false, lastJp = null;
    gs.forEach(function (g) {
      var lead = once('day', g.rows.length + (subD ? 1 : 0), '<div class="day-in">' + esc(dayLabel(g.day)) + '<small>(' + dayName(g.day) + ')</small></div>');
      g.rows.forEach(function (r) {
        var ret = r.qty < 0;                       // 수량 마이너스 = 반품
        var first = r.cjpno !== lastJp;
        if (first) { alt = !alt; lastJp = r.cjpno; }                 // 전표가 바뀌면 색 바꿈
        html += '<tr class="item' + (alt ? ' alt' : '') + (first ? ' jp-first' : '') + (ret ? ' ret' : '') + '">' + lead()
              + '<td class="c">' + esc(timeLabel(r.prtime)) + '</td>'
              + '<td>' + esc(r.pruser) + '</td>'
              + '<td><b>' + esc(r.name) + '</b></td>'
              + '<td class="c">' + (r.grade ? '<span class="grade grade-' + esc(r.grade) + '">' + esc(r.grade) + '</span>' : '') + '</td>'
              + '<td>' + esc(fmtTel(r.handno)) + '</td>'
              + '<td class="muted">' + esc(r.makecust) + '</td>'
              + '<td class="muted">' + esc(r.brand) + '</td>'
              + '<td>' + (ret ? '<span class="ret-badge">반품</span>' : '')
              + esc(r.jepmnm) + (r.jepmcd ? ' <span class="code">' + esc(r.jepmcd) + '</span>' : '') + '</td>'
              + numTd(r.price) + numTd(r.saleprice) + numTd(r.qty, ret) + numTd(r.amt, true) + '</tr>';
      });
      if (subD) html += '<tr class="sub-d">' + lead() + '<td class="lbl" colspan="11">소계 · ' + won(g.rows.length) + '건</td>' + numTd(amtSum(g.rows), true) + '</tr>';
    });
    html += '</tbody>';
    if (rows.length) {
      html += '<tfoot><tr><td class="c">합계</td><td colspan="11">' + won(rows.length) + '건 · ' + won(gs.length) + '일</td>'
            + numTd(amtSum(rows), true) + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
    fit();
  }

  /** 영수건 표 (일자 | 영수증들 … | 일자 소계) — 줄을 누르면 판매 상세 */
  function drawRcpt() {
    var subD = $('fSubD').checked;
    var html = '<thead><tr><th class="c" style="width:110px">일자</th><th class="c">시간</th><th>판매자</th><th>성명</th><th class="c">등급</th><th>전화</th>'
             + '<th class="r">현금</th><th class="r">카드</th><th class="r">결제합계</th><th class="r">할인</th>'
             + '<th class="r">포인트사용</th><th class="r">포인트누적</th></tr></thead><tbody>';
    var gs = groups();
    if (!gs.length) html += '<tr><td colspan="12" class="c text-muted py-5">조회된 판매가 없어요.</td></tr>';
    var alt = false, idx = 0;
    gs.forEach(function (g) {
      var lead = once('day', g.rows.length + (subD ? 1 : 0), '<div class="day-in">' + esc(dayLabel(g.day)) + '<small>(' + dayName(g.day) + ')</small></div>');
      g.rows.forEach(function (r) {
        var ret = r.tot < 0;
        alt = !alt;
        html += '<tr class="item rc' + (alt ? ' alt' : '') + (ret ? ' ret' : '') + '" data-i="' + rows.indexOf(r) + '" title="눌러서 판매 상세 보기">' + lead()
              + '<td class="c">' + esc(timeLabel(r.prtime)) + '</td>'
              + '<td>' + esc(r.pruser) + '</td>'
              + '<td>' + (ret ? '<span class="ret-badge">반품</span>' : '') + '<b>' + esc(r.name) + '</b></td>'
              + '<td class="c">' + (r.grade ? '<span class="grade grade-' + esc(r.grade) + '">' + esc(r.grade) + '</span>' : '') + '</td>'
              + '<td>' + esc(fmtTel(r.handno)) + '</td>'
              + numTd(r.cashamt) + numTd(r.cardamt) + numTd(r.tot, true).replace('class="r', 'class="r tot')
              + numTd(r.saleamt) + numTd(r.bonususe) + numTd(r.bonusamt) + '</tr>';
        idx++;
      });
      if (subD) html += '<tr class="sub-d">' + lead() + '<td class="lbl" colspan="5">소계 · ' + won(g.rows.length) + '건</td>'
                      + PAY.map(function (k) { return numTd(fsum(g.rows, k), true); }).join('') + '</tr>';
    });
    html += '</tbody>';
    if (rows.length) {
      html += '<tfoot><tr><td class="c">합계</td><td colspan="5">' + won(rows.length) + '건 · ' + won(gs.length) + '일</td>'
            + PAY.map(function (k) { return numTd(fsum(rows, k), true); }).join('') + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
    fit();
  }

  /** 영수증 한 건 판매 상세 */
  function showDetail(r) {
    $('dtlHead').textContent = dayLabel(r.chdate) + ' ' + timeLabel(r.prtime) + ' · 판매자 ' + (r.pruser || '-')
                             + ' · ' + r.name + (r.handno ? ' (' + fmtTel(r.handno) + ')' : '') + (r.grade ? ' · ' + r.grade : '');
    $('dtlPay').innerHTML = [['현금', r.cashamt], ['카드', r.cardamt], ['결제합계', r.tot], ['할인', r.saleamt], ['포인트사용', r.bonususe], ['포인트누적', r.bonusamt]]
      .map(function (x) { return '<span>' + x[0] + ' <b' + (x[0] === '결제합계' ? ' style="color:#1f6fd1"' : '') + '>' + won(x[1]) + '</b></span>'; }).join('');
    var body = $('dtlTable').querySelector('tbody'), foot = $('dtlTable').querySelector('tfoot');
    body.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">불러오는 중…</td></tr>';
    foot.innerHTML = '';
    dtlModal.show();
    api('/detail', { mc20key: r.mc20key })
      .then(function (list) {
        if (!list.length) { body.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">판매 상세가 없어요.</td></tr>'; return; }
        body.innerHTML = list.map(function (d) {
          var ret = Number(d.qty) < 0;
          return '<tr' + (ret ? ' class="table-danger"' : '') + '><td>' + esc(d.makecust) + '</td><td>' + esc(d.brand) + '</td>'
               + '<td>' + (ret ? '<span class="ret-badge">반품</span>' : '') + esc(d.jepmnm) + (d.jepmcd ? ' <span class="text-muted small">' + esc(d.jepmcd) + '</span>' : '') + '</td>'
               + '<td class="text-end">' + won(d.price) + '</td><td class="text-end">' + won(d.saleprice) + '</td>'
               + '<td class="text-end">' + won(d.qty) + '</td><td class="text-end fw-bold">' + won(d.amt) + '</td></tr>';
        }).join('');
        foot.innerHTML = '<tr><td colspan="5">합계 · ' + list.length + '품목</td><td class="text-end">' + won(fsum(list, 'qty')) + '</td>'
                       + '<td class="text-end">' + won(fsum(list, 'amt')) + '</td></tr>';
      })
      .catch(function (e) { body.innerHTML = '<tr><td colspan="7" class="text-center text-danger py-4">' + esc(e.message || e) + '</td></tr>'; });
  }

  function setMode(m) {
    mode = m;
    document.querySelectorAll('#modeGrp .btn').forEach(function (b) {
      var on = b.dataset.mode === m;
      b.classList.toggle('btn-primary', on);
      b.classList.toggle('btn-outline-primary', !on);
    });
    rows = [];
    search();
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
    $('ar308Search').disabled = true;
    var isR = mode === 'rcpt';
    api(isR ? '/receipts' : '/list', p)
      .then(function (list) {
        rows = (list || []).map(function (r) {
          (isR ? ['cashamt', 'cardamt', 'saleamt', 'bonususe', 'bonusamt'] : ['price', 'saleprice', 'qty', 'amt'])
            .forEach(function (k) { r[k] = Number(r[k] || 0); });
          if (isR) { r.tot = r.cashamt + r.cardamt; r.amt = r.tot; }    // 결제합계 = 현금 + 카드
          return r;
        });
        cond = p;
        draw();
        var mem = {};
        rows.forEach(function (r) { mem[r.name + '|' + r.handno] = 1; });
        $('sDays').textContent = won(groups().length);
        $('sCnt').textContent = won(rows.length);
        $('sMem').textContent = won(Object.keys(mem).length);
        $('sAmt').textContent = won(amtSum(rows));
        var c = [p.pruser && '판매자 ' + p.pruser, p.manager && '담당 ' + p.manager, p.grade && '등급 ' + p.grade,
                 pickedMem && '회원 ' + pickedMem.name, p.makecust && '제조 ' + p.makecust,
                 p.brand && '브랜드 ' + p.brand, p.jepmnm && '제품 ' + p.jepmnm].filter(Boolean);
        $('headInfo').innerHTML = '<b>' + (isR ? '영수건' : '내역별') + ' · ' + p.from + ' ~ ' + p.to + '</b>' + (c.length ? ' · ' + esc(c.join(' · ')) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar308Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    if (mode === 'rcpt') return excelRcpt();
    var subD = $('fSubD').checked;
    var head = ['일자', '시간', '판매자', '성명', '등급', '전화', '제조회사', '브랜드', '제품명', '제품코드', '정가', '판매가', '수량', '금액', '구분'];
    var data = [], merges = [];
    groups().forEach(function (g) {
      var start = data.length + 1;                 // 0 행은 제목
      g.rows.forEach(function (r) {
        data.push(['', timeLabel(r.prtime), r.pruser, r.name, r.grade, fmtTel(r.handno), r.makecust, r.brand, r.jepmnm, r.jepmcd,
                   r.price, r.saleprice, r.qty, r.amt, r.qty < 0 ? '반품' : '']);
      });
      if (subD) data.push(['', '소계 · ' + g.rows.length + '건', '', '', '', '', '', '', '', '', '', '', '', amtSum(g.rows)]);
      data[start - 1][0] = dayLabel(g.day);
      merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
    });
    data.push(['합계', rows.length + '건', '', '', '', '', '', '', '', '', '', '', '', amtSum(rows)]);
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!merges'] = merges;
    ws['!cols'] = [12, 9, 9, 10, 8, 14, 14, 12, 28, 12, 9, 9, 6, 12, 6].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '제품별판매내역').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + (cond ? cond.from + '_' + cond.to : '') + '.xlsx');
  }

  function excelRcpt() {
    var subD = $('fSubD').checked;
    var head = ['일자', '시간', '판매자', '성명', '등급', '전화', '현금', '카드', '결제합계', '할인', '포인트사용', '포인트누적', '구분'];
    var data = [], merges = [];
    groups().forEach(function (g) {
      var start = data.length + 1;
      g.rows.forEach(function (r) {
        data.push(['', timeLabel(r.prtime), r.pruser, r.name, r.grade, fmtTel(r.handno),
                   r.cashamt, r.cardamt, r.tot, r.saleamt, r.bonususe, r.bonusamt, r.tot < 0 ? '반품' : '']);
      });
      if (subD) data.push(['', '소계 · ' + g.rows.length + '건', '', '', '', ''].concat(PAY.map(function (k) { return fsum(g.rows, k); })));
      data[start - 1][0] = dayLabel(g.day);
      merges.push({ s: { r: start, c: 0 }, e: { r: data.length, c: 0 } });
    });
    data.push(['합계', rows.length + '건', '', '', '', ''].concat(PAY.map(function (k) { return fsum(rows, k); })));
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!merges'] = merges;
    ws['!cols'] = [12, 9, 9, 10, 8, 14, 11, 11, 12, 10, 10, 10, 6].map(function (w) { return { wch: w }; });
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, '영수건');
    XLSX.writeFile(wb, '판매내역_영수건_' + (cond ? cond.from + '_' + cond.to : '') + '.xlsx');
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
    dtlModal = bootstrap.Modal.getOrCreateInstance($('dtlModal'));
    document.querySelectorAll('#modeGrp .btn').forEach(function (b) { b.onclick = function () { if (b.dataset.mode !== mode) setMode(b.dataset.mode); }; });
    $('mergeTable').addEventListener('click', function (e) {
      var tr = e.target.closest('tr.rc');
      if (tr && mode === 'rcpt') showDetail(rows[Number(tr.dataset.i)]);
    });
    setRange('today');
    document.querySelectorAll('[data-range]').forEach(function (b) {
      b.onclick = function () { setRange(b.dataset.range); search(); };
    });
    $('ar308Search').onclick = search;
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
    $('fSubD').onchange = draw;
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
