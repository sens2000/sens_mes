<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>회원별 6개월 실적</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 회원별 6개월 실적 (ar305) ===== */
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

  .sum-bar { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); border-bottom: 1px solid var(--line); background: #fafbfd; }
  .sum-bar > div { padding: 8px 14px; border-right: 1px solid var(--line); }
  .sum-bar > div:last-child { border-right: 0; }
  .sum-bar .k { font-size: 11px; color: var(--muted); }
  .sum-bar .v { font-size: 17px; font-weight: 800; text-align: right; }
  .sum-bar .v.main { color: #1f6fd1; }
  @media (max-width: 1000px) { .sum-bar { grid-template-columns: repeat(3, minmax(0, 1fr)); } }

  .grade { display: inline-block; padding: 0 8px; border-radius: 9px; font-size: 11px; font-weight: 700; border: 1px solid #cbd2dc; color: #4a5568; background: #fff; }
  .grade-GOLD   { color: #9a6b00; background: #fff4d1; border-color: #e7b93c; }
  .grade-SILVER { color: #56606e; background: #eef0f3; border-color: #aab2bd; }
  .grade-YELLO, .grade-YELLOW { color: #8a6d00; background: #fffbd6; border-color: #e6cf3a; }
  .grade-GREEN  { color: #1f7a4d; background: #e3f5ea; border-color: #5cbf8a; }
  .minus { color: #d63939; }
  .zero  { color: #c3c9d3; }

  .merge-wrap { overflow: auto; }
  table.merge { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
  table.merge th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); padding: 9px 10px; font-weight: 700;
                   border-bottom: 1px solid #cfd6e2; white-space: nowrap; text-align: left; }
  table.merge td { padding: 7px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
  table.merge .r { text-align: right; }
  table.merge .c { text-align: center; }
  table.merge th.tot, table.merge td.tot { background-clip: padding-box; border-left: 1px solid #cfd6e2; }
  table.merge tbody tr.mem:hover td:not(.mgr):not(.grp) { background: #f0f5ff; }
  /* 담당 칸 (위아래 병합) */
  table.merge td.mgr { text-align: center; vertical-align: middle; font-weight: 800; color: var(--navy);
                       background: #f4f7fc; border-right: 1px solid #cfd6e2; border-bottom: 2px solid #b9c5d8; }
  /* 등급 칸 (담당 안에서 위아래 병합) */
  table.merge td.grp { text-align: center; vertical-align: middle; background: #fafbfd;
                       border-right: 1px solid #e3e7ee; border-bottom: 2px solid #d5deec; }
  /* 등급 소계 (담당 안) */
  table.merge tr.sub-g td:not(.mgr):not(.grp) { background: #f7f9fc; font-weight: 700; }
  table.merge tr.sub-g.avg td:not(.mgr):not(.grp) { color: #1f6fd1; font-weight: 600; border-bottom: 2px solid #d5deec; }
  /* 담당 소계 */
  table.merge tr.sub-m td:not(.mgr) { background: #eef3fb; font-weight: 800; color: var(--navy); }
  table.merge tr.sub-m.avg td:not(.mgr) { color: #1f6fd1; font-weight: 700; border-bottom: 2px solid #b9c5d8; }
  table.merge td.lbl { color: var(--muted); }
  table.merge tr.sub-m td.lbl { color: var(--navy); }
  /* 전체 합계·평균 */
  table.merge tfoot td { position: sticky; background: #e9eef7; font-weight: 800; }
  table.merge tfoot tr.t-sum td { bottom: 33px; border-top: 1px solid #b9c5d8; }
  table.merge tfoot tr.t-avg td { bottom: 0; color: #1f6fd1; }
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
        <h6>회원별 6개월 실적</h6>
        <div class="sub" id="headInfo">기준월을 정하고 조회하세요</div>
      </div>
      <div class="filter">
        <span class="lbl ms-0">기준월</span>
        <input type="month" class="form-control form-control-sm" id="fBase" style="width:140px">
        <div class="btn-group btn-group-sm">
          <button type="button" class="btn btn-outline-secondary" data-base="0">이번달</button>
          <button type="button" class="btn btn-outline-secondary" data-base="-1">지난달</button>
        </div>
        <span class="lbl">담당자</span>
        <input type="text" class="form-control form-control-sm" id="fManager" placeholder="빈칸 = 전체" style="width:110px" autocomplete="off">
        <span class="lbl">등급</span>
        <select class="form-select form-select-sm" id="fGrade"><option value="">전체</option></select>
        <span class="lbl">기간실적</span>
        <input type="text" class="form-control form-control-sm text-end" id="fMinAmt" placeholder="이상" style="width:110px" inputmode="numeric" autocomplete="off">
        <span class="lbl">방문수</span>
        <input type="text" class="form-control form-control-sm text-end" id="fMinVisit" placeholder="이상" style="width:70px" inputmode="numeric" autocomplete="off">
        <button type="button" class="btn btn-sm btn-secondary ms-1" id="ar305Search">조회</button>
        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="fSubG" checked>
          <label class="form-check-label small" for="fSubG">등급 소계</label>
        </div>
        <div class="form-check form-check-inline mb-0">
          <input class="form-check-input" type="checkbox" id="fSubM" checked>
          <label class="form-check-label small" for="fSubM">담당 소계</label>
        </div>
        <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnExcel">엑셀</button>
      </div>
      <div class="sum-bar">
        <div><div class="k">회원수</div><div class="v" id="sCnt">0</div></div>
        <div><div class="k">기간실적 합계</div><div class="v main" id="sAmt">0</div></div>
        <div><div class="k">월평균</div><div class="v" id="sMon">0</div></div>
        <div><div class="k">1인 평균</div><div class="v" id="sPer">0</div></div>
        <div><div class="k">방문수</div><div class="v" id="sVisit">0</div></div>
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
 * 회원별 6개월 실적 (ar305) — member + MC20_MST, 로그인 매장, member.sys = 'N'
 *   - 기간   : 기준월 포함 6개월 (기준월 10월 → 05월 01일 ~ 10월 말일)
 *   - 실적   = AMT - SALEAMT - BONUSUSE
 *   - 기간실적·방문수 : 6개월 합계가 입력값 이상인 회원만
 *   - 묶음   : 왼쪽 담당 칸 병합 (담당 없음은 맨 뒤), 담당 안에서 등급 > 성명 순
 *   - 소계   : 등급 소계(담당 안), 담당 소계, 전체 — 각각 합계 / 평균(÷ 회원수)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ar305';
  var KEYS = ['amt1', 'amt2', 'amt3', 'amt4', 'amt5', 'amt6', 'amt'];
  var rows = [], months = [], cond = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function won(n) { return Math.round(Number(n || 0)).toLocaleString('ko-KR'); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
  function monLabel(m) { return m.substr(2, 2) + '/' + m.substr(4, 2); }          // 202605 → 26/05
  function ymdLabel(s) { return s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2); }
  function num(s) { return String(s || '').replace(/[^\d]/g, ''); }
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

  // ---------------- 기준월 ----------------
  function setBase(offset) {
    var d = new Date();
    d = new Date(d.getFullYear(), d.getMonth() + (offset || 0), 1);
    $('fBase').value = d.getFullYear() + '-' + pad(d.getMonth() + 1);
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

  // ---------------- 합계 ----------------
  function sums(list) {
    var s = { cnt: list.length, visit: 0 };
    KEYS.forEach(function (k) { s[k] = 0; });
    list.forEach(function (r) {
      KEYS.forEach(function (k) { s[k] += r[k] || 0; });
      s.visit += r.visit || 0;
    });
    return s;
  }
  function avgOf(s) {
    var a = {};
    KEYS.forEach(function (k) { a[k] = s.cnt ? s[k] / s.cnt : 0; });
    return a;
  }

  /** 담당 > 등급 묶음 [{ name, rows, grades:[{ name, rows }] }]
   *  서버에서 담당·등급·성명 순으로 옴, 담당 없음은 맨 뒤로 */
  var NO_MGR = '(담당 없음)', NO_GRADE = '(등급 없음)';
  function groups() {
    var out = [];
    rows.forEach(function (r) {
      var mn = r.manager || NO_MGR, gn = r.grade || NO_GRADE;
      var m = out[out.length - 1];
      if (!m || m.name !== mn) out.push(m = { name: mn, rows: [], grades: [] });
      var g = m.grades[m.grades.length - 1];
      if (!g || g.name !== gn) m.grades.push(g = { name: gn, rows: [] });
      g.rows.push(r);
      m.rows.push(r);
    });
    return out.filter(function (m) { return m.name !== NO_MGR; })
              .concat(out.filter(function (m) { return m.name === NO_MGR; }));
  }

  // ---------------- 표 ----------------
  function cell(v, bold, extra) {
    var cls = 'r' + (extra ? ' ' + extra : '') + (v < 0 ? ' minus' : (Math.round(v) === 0 ? ' zero' : ''));
    return '<td class="' + cls + '">' + (bold ? '<b>' + won(v) + '</b>' : won(v)) + '</td>';
  }
  function amtCells(r, boldTotal) {
    var h = '';
    for (var i = 1; i <= 6; i++) h += cell(r['amt' + i]);
    return h + cell(r.amt, boldTotal, 'tot');
  }
  function gradeBadge(g) { return g ? '<span class="grade grade-' + esc(g) + '">' + esc(g) + '</span>' : ''; }
  /** 소계 두 줄 [합계, 평균] — 줄 앞의 병합 칸(담당·등급)은 lead() 가 붙임, span = 라벨이 차지할 칸 수 */
  function subRows(cls, sumLabel, avgLabel, list, lead, span) {
    var s = sums(list);
    return '<tr class="' + cls + '">' + lead() + '<td class="lbl" colspan="' + span + '">' + sumLabel + ' · ' + won(s.cnt) + '명</td>' + amtCells(s, true) + '</tr>'
         + '<tr class="' + cls + ' avg">' + lead() + '<td class="lbl" colspan="' + span + '">' + avgLabel + '</td>' + amtCells(avgOf(s)) + '</tr>';
  }
  /** 첫 호출 때만 병합 칸(rowspan)을 돌려주는 함수 */
  function once(cls, span, html) {
    var done = false;
    return function () {
      if (done) return '';
      done = true;
      return '<td class="' + cls + '" rowspan="' + span + '">' + html + '</td>';
    };
  }

  /** 병합 표 (담당 | 등급 | 회원들 … 등급 소계 | 담당 소계) */
  function draw() {
    var subM = $('fSubM').checked, subG = $('fSubG').checked;
    var html = '<thead><tr><th class="c" style="width:110px">담당</th><th class="c" style="width:90px">등급</th><th>성명</th><th>전화번호</th>'
             + months.map(function (m) { return '<th class="r">' + monLabel(m) + '</th>'; }).join('')
             + '<th class="r tot">합계</th></tr></thead><tbody>';
    var ms = groups();
    if (!ms.length) html += '<tr><td colspan="11" class="c text-muted py-5">조회된 회원이 없어요.</td></tr>';
    ms.forEach(function (m) {
      // 담당 칸이 덮을 줄 수 = 회원 + 등급 소계(등급마다 2줄) + 담당 소계(2줄)
      var leadM = once('mgr', m.rows.length + (subG ? m.grades.length * 2 : 0) + (subM ? 2 : 0), esc(m.name));
      m.grades.forEach(function (g) {
        // 등급 칸이 덮을 줄 수 = 그 등급 회원 + 등급 소계(2줄)
        var leadG = once('grp', g.rows.length + (subG ? 2 : 0), g.name === NO_GRADE ? esc(g.name) : gradeBadge(g.name));
        var lead = function () { return leadM() + leadG(); };
        g.rows.forEach(function (r) {
          html += '<tr class="mem">' + lead()
                + '<td><b>' + esc(r.name) + '</b></td>'
                + '<td>' + esc(fmtTel(r.handno)) + '</td>'
                + amtCells(r, true) + '</tr>';
        });
        if (subG) html += subRows('sub-g', '소계', '평균', g.rows, lead, 2);
      });
      if (subM) html += subRows('sub-m', '담당 소계', '담당 평균', m.rows, leadM, 3);
    });
    html += '</tbody>';
    if (rows.length) {
      var t = sums(rows);
      html += '<tfoot><tr class="t-sum"><td class="c">합계</td><td colspan="3">' + won(t.cnt) + '명</td>' + amtCells(t, true) + '</tr>'
            + '<tr class="t-avg"><td class="c">평균</td><td colspan="3"></td>' + amtCells(avgOf(t)) + '</tr></tfoot>';
    }
    $('mergeTable').innerHTML = html;
    fit();
  }

  function search() {
    var p = {
      base: $('fBase').value, manager: $('fManager').value.trim(), grade: $('fGrade').value,
      minAmt: num($('fMinAmt').value), minVisit: num($('fMinVisit').value)
    };
    if (!p.base) { alert('기준월을 입력하세요.'); return; }
    $('loading').classList.remove('d-none');
    $('ar305Search').disabled = true;
    api('/list', p)
      .then(function (d) {
        months = d.months || [];
        rows = d.rows || [];
        cond = p;
        draw();
        var t = sums(rows);
        $('sCnt').textContent = won(t.cnt);
        $('sAmt').textContent = won(t.amt);
        $('sMon').textContent = won(t.amt / 6);
        $('sPer').textContent = won(t.cnt ? t.amt / t.cnt : 0);
        $('sVisit').textContent = won(t.visit);
        var c = [p.manager && '담당 ' + p.manager, p.grade && '등급 ' + p.grade,
                 p.minAmt && '실적 ' + won(p.minAmt) + ' 이상', p.minVisit && '방문 ' + p.minVisit + '회 이상'].filter(Boolean);
        $('headInfo').innerHTML = '<b>' + ymdLabel(d.from) + ' ~ ' + monLabel(months[5] || '') + ' 말일</b>'
                                + (c.length ? ' · ' + esc(c.join(' · ')) : '');
      })
      .catch(fail)
      .then(function () { $('loading').classList.add('d-none'); $('ar305Search').disabled = false; });
  }

  // ---------------- 엑셀 ----------------
  function excel() {
    if (!rows.length) { alert('먼저 조회하세요.'); return; }
    if (typeof XLSX === 'undefined') { alert('엑셀 모듈을 불러오지 못했습니다.'); return; }
    var subM = $('fSubM').checked, subG = $('fSubG').checked;
    var head = ['담당', '등급', '성명', '전화번호'].concat(months.map(monLabel)).concat(['합계']);
    var nums = function (r) { return KEYS.map(function (k) { return Math.round(r[k] || 0); }); };
    var data = [], merges = [];
    var sub = function (a, b, sumLabel, avgLabel, list) {
      var s = sums(list);
      data.push([a, b, sumLabel, won(s.cnt) + '명'].concat(nums(s)));
      data.push(['', '', avgLabel, ''].concat(nums(avgOf(s))));
    };
    groups().forEach(function (m) {
      var mStart = data.length + 1;                // 0 행은 제목
      m.grades.forEach(function (g) {
        var gStart = data.length + 1;
        g.rows.forEach(function (r) { data.push(['', '', r.name, fmtTel(r.handno)].concat(nums(r))); });
        if (subG) sub('', '', '소계', '평균', g.rows);
        data[gStart - 1][1] = g.name;              // 등급 이름은 첫 줄에, 아래로 병합
        if (data.length > gStart) merges.push({ s: { r: gStart, c: 1 }, e: { r: data.length, c: 1 } });
      });
      if (subM) sub('', '', '담당 소계', '담당 평균', m.rows);
      data[mStart - 1][0] = m.name;                // 담당 이름은 첫 줄에, 아래로 병합
      merges.push({ s: { r: mStart, c: 0 }, e: { r: data.length, c: 0 } });
    });
    sub('합계', '', '전체 합계', '전체 평균', rows);
    var ws = XLSX.utils.aoa_to_sheet([head].concat(data));
    ws['!merges'] = merges;
    ws['!cols'] = [12, 18, 9, 14, 12, 12, 12, 12, 12, 12, 13].map(function (w) { return { wch: w }; });
    var title = (document.querySelector('.card-head h6').textContent || '회원별실적').replace(/\s+/g, '');
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, title.substr(0, 31));
    XLSX.writeFile(wb, title + '_' + (cond ? cond.base : '') + '.xlsx');
  }

  // ---------------- 화면 크기 ----------------
  function fit() {
    var w = $('mergeWrap');
    if (w.offsetParent) w.style.height = Math.max(300, window.innerHeight - w.getBoundingClientRect().top - 30) + 'px';
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    setBase(0);
    document.querySelectorAll('[data-base]').forEach(function (b) {
      b.onclick = function () { setBase(Number(b.dataset.base)); search(); };
    });
    $('ar305Search').onclick = search;
    $('fBase').onchange = search;
    $('fGrade').onchange = search;
    ['fManager', 'fMinAmt', 'fMinVisit'].forEach(function (id) {
      $(id).addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); search(); } });
    });
    // 기간실적 : 입력하면서 천 단위 쉼표
    $('fMinAmt').addEventListener('input', function () { var v = num(this.value); this.value = v ? Number(v).toLocaleString('ko-KR') : ''; });
    $('fMinVisit').addEventListener('input', function () { this.value = num(this.value); });
    ['fSubM', 'fSubG'].forEach(function (id) { $(id).onchange = draw; });
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
