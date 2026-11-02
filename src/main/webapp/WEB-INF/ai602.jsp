<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<meta name="theme-color" content="#2d3d5c">
<title>재고조사 (모바일)</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  /* ===== 재고조사 모바일 입력 (ai602) — 등록만 ===== */
  :root {
    --navy: #2d3d5c; --line: #e3e7ee; --muted: #5f6b7a; --accent: #ffd66b;
    --red: #a8321a; --red-bg: #fde9e4; --blue: #1f5fbf; --blue-bg: #e4eefc;
    --green: #1f6b45; --green-bg: #e1f3e8;
  }
  html, body { background: #eef1f5; }
  body { font-family: 'Noto Sans KR', system-ui, sans-serif; color: #1f2733; font-size: 15px; margin: 0;
         -webkit-tap-highlight-color: transparent; }
  .wrap { max-width: 520px; margin: 0 auto; min-height: 100vh; display: flex; flex-direction: column; }

  header { background: var(--navy); color: #fff; padding: 12px 14px; position: sticky; top: 0; z-index: 10; }
  header .top { display: flex; align-items: center; gap: 8px; }
  header h1 { margin: 0; font-size: 18px; font-weight: 800; }
  header .back { width: 40px; height: 40px; margin-left: -8px; display: flex; align-items: center; justify-content: center;
                 color: #fff; background: none; border: 0; }
  header .cnt { margin-left: auto; font-size: 12px; font-weight: 700; padding: 3px 10px; border-radius: 10px; background: var(--accent); color: #3b2f00; }
  header .shop { font-size: 12px; color: #d7deea; margin-top: 2px; }

  main { flex: 1; padding: 12px; display: flex; flex-direction: column; gap: 12px; }
  .card2 { background: #fff; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,.08); }

  /* 검색 */
  .sbar { display: flex; gap: 8px; }
  .sbar input { flex: 1; height: 50px; border: 2px solid var(--navy); border-radius: 10px; padding: 0 14px; font-size: 16px; background: #fff; min-width: 0; }
  .sbar button { width: 70px; height: 50px; border-radius: 10px; border: 0; background: var(--navy); color: #fff; font-size: 16px; font-weight: 700; }
  .more-t { background: none; border: 0; color: var(--blue); font-size: 13px; padding: 2px 0; }
  .more { display: none; grid-template-columns: 1fr 1fr; gap: 8px; }
  .more.on { display: grid; }
  .more input { height: 44px; border: 1px solid #cfd6e2; border-radius: 8px; padding: 0 12px; font-size: 15px; background: #fff; min-width: 0; }

  /* 검색 결과 */
  .res-h { font-size: 12px; font-weight: 700; color: var(--muted); padding: 10px 14px 4px; display: flex; justify-content: space-between; }
  .res { max-height: 42vh; overflow: auto; }
  .it { width: 100%; display: flex; justify-content: space-between; align-items: center; gap: 8px; min-height: 56px; padding: 8px 14px;
        border: 0; border-top: 1px solid #eef1f5; background: #fff; text-align: left; font: inherit; }
  .it.on { background: var(--blue-bg); box-shadow: inset 4px 0 0 var(--navy); }
  .it .nm { display: block; font-size: 15px; font-weight: 700; }
  .it .sb { display: block; font-size: 12px; color: var(--muted); }
  .it .rt { font-size: 12px; color: var(--muted); text-align: right; white-space: nowrap; }
  .empty { padding: 18px; text-align: center; color: var(--muted); font-size: 14px; }

  .st { display: inline-block; padding: 1px 8px; border-radius: 10px; font-size: 11px; font-weight: 700; }
  .st-none  { color: var(--muted); background: #eef1f5; }
  .st-ok    { color: var(--green); background: var(--green-bg); }
  .st-short { color: var(--red); background: var(--red-bg); }
  .st-over  { color: var(--blue); background: var(--blue-bg); }

  /* 선택한 제품 · 수량 */
  .sel { padding: 14px 16px; display: flex; flex-direction: column; gap: 10px; }
  .sel .lb { font-size: 12px; font-weight: 700; color: var(--blue); }
  .sel .nm { font-size: 19px; font-weight: 800; line-height: 1.3; }
  .sel .sb { font-size: 13px; color: var(--muted); }
  .nums { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .nums div { background: #f6f8fb; border-radius: 8px; padding: 8px 12px; }
  .nums .k { font-size: 11px; color: var(--muted); }
  .nums .v { font-size: 20px; font-weight: 800; }
  .qty-l { font-size: 13px; font-weight: 700; color: var(--navy); }
  .qrow { display: flex; gap: 8px; align-items: stretch; }
  .step { width: 56px; border-radius: 10px; border: 1px solid #cfd6e2; background: #f6f8fb; font-size: 26px; color: var(--navy); }
  #eQty { flex: 1; min-width: 0; height: 60px; border: 2px solid var(--navy); border-radius: 10px; padding: 0 14px;
          font-size: 28px; font-weight: 800; text-align: right; }
  .preview { font-size: 13px; color: var(--muted); min-height: 18px; }
  .neg { color: var(--red); font-weight: 700; }
  .posv { color: var(--blue); font-weight: 700; }
  #btnSave { height: 56px; border-radius: 10px; border: 0; background: var(--accent); color: var(--navy); font-size: 17px; font-weight: 800; }
  #btnSave:disabled { opacity: .5; }

  /* 최근 입력 */
  .rec-h { font-size: 12px; font-weight: 700; color: var(--muted); padding: 10px 16px 2px; }
  .rec div { display: flex; justify-content: space-between; align-items: center; padding: 10px 16px; border-top: 1px solid #eef1f5; font-size: 14px; }
  .rec .t { font-size: 12px; color: var(--muted); }

  /* 햄버거 메뉴 */
  header .ham { width: 40px; height: 40px; margin-right: -8px; display: flex; align-items: center; justify-content: center;
                color: #fff; background: none; border: 0; }
  #sidebarOffcanvas { width: 82vw; max-width: 320px; }
  #sidebarOffcanvas .offcanvas-header { background: var(--navy); color: #fff; }
  #sidebarOffcanvas .user { font-size: 14px; font-weight: 700; }
  #sidebarOffcanvas .nav-item.mt-3 { margin-top: 4px !important; }
  #sidebarOffcanvas .nav-link { color: #1f2733; font-size: 15px; padding-top: 11px; padding-bottom: 11px; border-bottom: 1px solid #eef1f5; }
  #sidebarOffcanvas .menu-group-link { font-weight: 800; color: var(--navy); background: #f6f8fb; }
  #sidebarOffcanvas .menu-program-link { font-weight: 500 !important; text-transform: none !important; font-size: 15px !important; }
  #sidebarOffcanvas .menu-program-link.cur { background: var(--blue-bg); color: var(--blue); font-weight: 800 !important; }
  #sidebarOffcanvas .chevron { font-size: 12px; color: var(--muted); }
  #sidebarOffcanvas .top-date { position: static; transform: none; font-size: 12px; color: #d7deea; display: block; }
  #sidebarMenu { display: none; }

  /* 알림 */
  #toast { position: fixed; left: 50%; bottom: 24px; transform: translateX(-50%); background: rgba(31,39,51,.94); color: #fff;
           padding: 12px 18px; border-radius: 10px; font-size: 14px; max-width: 90vw; display: none; z-index: 50; text-align: center; }
  #toast.err { background: rgba(168,50,26,.95); }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>
<div class="wrap">

  <header>
    <div class="top">
      <button type="button" class="back" id="btnBack" aria-label="뒤로">
        <svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"></path></svg>
      </button>
      <h1>재고조사</h1>
      <span class="cnt" id="hCnt">입력 0건</span>
      <button type="button" class="ham" data-bs-toggle="offcanvas" data-bs-target="#sidebarOffcanvas" aria-controls="sidebarOffcanvas" aria-label="메뉴 열기">
        <svg aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 6h16M4 12h16M4 18h16"></path></svg>
      </button>
    </div>
    <div class="shop">${sessionScope.USER.SHOPNAME} · 수량 등록 전용</div>
  </header>

  <main>
    <!-- 검색 -->
    <div>
      <div class="sbar">
        <input type="search" id="q" placeholder="제품명 또는 제품코드" autocomplete="off" enterkeyhint="search" aria-label="제품명 또는 제품코드">
        <button type="button" id="btnFind">검색</button>
      </div>
      <button type="button" class="more-t" id="btnMore">+ 제조회사 · 브랜드로 찾기</button>
      <div class="more" id="more">
        <input type="text" id="qMaker" placeholder="제조회사" autocomplete="off" enterkeyhint="search" aria-label="제조회사">
        <input type="text" id="qBrand" placeholder="브랜드" autocomplete="off" enterkeyhint="search" aria-label="브랜드">
      </div>
    </div>

    <!-- 검색 결과 -->
    <section class="card2" id="resBox" style="display:none">
      <div class="res-h"><span>검색 결과 <b id="fCnt">0</b>건</span><span>눌러서 선택</span></div>
      <div class="res" id="res"></div>
    </section>

    <!-- 선택한 제품 · 수량 입력 -->
    <section class="card2" id="selBox" style="display:none">
      <div class="sel">
        <div class="d-flex justify-content-between align-items-center"><span class="lb">선택한 제품</span><span id="sSt"></span></div>
        <div>
          <div class="nm" id="sNm"></div>
          <div class="sb" id="sSb"></div>
        </div>
        <div class="nums">
          <div><div class="k">전산재고</div><div class="v" id="sJego">0</div></div>
          <div><div class="k">지금까지 실사</div><div class="v" id="sReal">-</div></div>
        </div>
        <label class="qty-l" for="eQty" id="qtyLbl">실사 수량</label>
        <div class="qrow">
          <button type="button" class="step" id="btnMinus" aria-label="1 빼기">−</button>
          <input type="number" id="eQty" inputmode="numeric" pattern="[0-9]*" min="0" max="999999" autocomplete="off" enterkeyhint="done">
          <button type="button" class="step" id="btnPlus" aria-label="1 더하기">+</button>
        </div>
        <div class="preview" id="preview"></div>
        <button type="button" id="btnSave">수량 등록</button>
      </div>
    </section>

    <!-- 최근 입력 -->
    <section class="card2">
      <div class="rec-h">최근 입력</div>
      <div class="rec" id="rec"><div class="empty" style="border:0">아직 입력한 수량이 없어요.</div></div>
    </section>
  </main>
</div>

<div id="toast" role="status" aria-live="polite"></div>

<!-- ===== 햄버거 메뉴 (menu_script.jspf 가 #sidebarMenuMobile 에 메뉴를 그림) ===== -->
<div class="offcanvas offcanvas-end" tabindex="-1" id="sidebarOffcanvas" aria-labelledby="sidebarOffcanvasLabel">
  <div class="offcanvas-header">
    <div>
      <h5 class="offcanvas-title fw-bold mb-0" id="sidebarOffcanvasLabel">메뉴</h5>
      <span class="user" id="userLabel"></span>
    </div>
    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="offcanvas" aria-label="닫기"></button>
  </div>
  <div class="offcanvas-body p-0 d-flex flex-column">
    <div id="sidebarMenuMobile" class="flex-grow-1"></div>
    <div class="p-3 border-top">
      <button type="button" class="btn btn-outline-secondary w-100" onclick="handleLogout()">로그아웃</button>
    </div>
  </div>
</div>
<div id="sidebarMenu"></div><!-- PC 메뉴 자리 (모바일 화면에선 숨김, 공통 스크립트용) -->

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>

<script>
/* =====================================================================
 * 재고조사 모바일 입력 (ai602) — 등록만
 *   - 검색 : 숫자만 넣으면 제품코드, 그 밖은 제품명 (+ 제조회사·브랜드)
 *   - 선택 → 수량 입력 → 등록 (REAL_JEGO 한 건, 같은 제품은 합계에 더해짐)
 *   - 마감 · 재고 반영 · 입력 삭제는 PC 화면(ai601)에서
 *   - API 는 ai601 것을 그대로 사용
 *   - 메뉴 : 오른쪽 위 ☰ (공통 menu_script.jspf 의 메뉴 데이터 · 로그아웃 · 로그인 확인 사용)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai601';
  var found = [], sel = null, toastTimer = null;
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function n(v) { return Number(v || 0).toLocaleString('ko-KR'); }
  function sn(v) { v = Number(v || 0); return (v > 0 ? '+' : '') + v.toLocaleString('ko-KR'); }
  function tLabel(s) { s = String(s || ''); return s.length >= 12 ? s.substr(8, 2) + ':' + s.substr(10, 2) : s; }
  function toast(t, err) {
    var el = $('toast'); el.textContent = t; el.className = err ? 'err' : ''; el.style.display = 'block';
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { el.style.display = 'none'; }, err ? 3500 : 2000);
  }
  function fail(e) { toast(e.message || e, true); }

  function api(path, params, body) {
    if (window.ReportMock) return window.ReportMock.handle(path, params, body);   // 미리보기용
    var url = API + path + (params ? '?' + new URLSearchParams(params) : '');
    var opt = body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {};
    return fetch(url, opt)
      .then(function (r) {
        if (!r.ok) throw new Error('서버 요청 실패 (' + r.status + ')');
        return r.json();
      })
      .then(function (res) {
        if (!res.ok) throw new Error(res.msg || '처리 중 오류가 발생했습니다.');
        return res.data;
      });
  }

  function calc(r) {
    var done = r.realqty !== null && r.realqty !== undefined;
    r.diff = done ? r.realqty - r.jego : null;
    r.status = !done ? 'none' : r.diff === 0 ? 'ok' : r.diff < 0 ? 'short' : 'over';
    return r;
  }
  var ST = { none: ['미조사', 'st-none'], ok: ['일치', 'st-ok'], short: ['부족', 'st-short'], over: ['초과', 'st-over'] };
  function badge(s) { return '<span class="st ' + ST[s][1] + '">' + ST[s][0] + '</span>'; }

  // ---------------- 검색 ----------------
  function find() {
    var q = $('q').value.trim(), mk = $('qMaker').value.trim(), br = $('qBrand').value.trim();
    if (!q && !mk && !br) { toast('제품명이나 제품코드를 입력하세요.', true); $('q').focus(); return; }
    var p = { makecust: mk, brand: br, jepmcd: '', jepmnm: '' };
    if (/^\d{4,}$/.test(q)) p.jepmcd = q; else p.jepmnm = q;        // 숫자만이면 제품코드(바코드)
    $('q').blur();
    $('btnFind').disabled = true;
    api('/products', p)
      .then(function (d) {
        found = (d.rows || []).map(calc);
        $('fCnt').textContent = found.length + (d.more ? '+' : '');
        $('resBox').style.display = '';
        drawFound();
        if (found.length === 1) select(found[0]);
        else { select(null); if (!found.length) $('q').select(); }
      })
      .catch(fail)
      .then(function () { $('btnFind').disabled = false; });
  }

  function drawFound() {
    if (!found.length) { $('res').innerHTML = '<div class="empty">검색된 제품이 없어요.</div>'; return; }
    $('res').innerHTML = found.map(function (f, i) {
      return '<button type="button" class="it' + (sel && sel.jepmkey === f.jepmkey ? ' on' : '') + '" data-i="' + i + '">' +
             '<span style="min-width:0"><span class="nm">' + esc(f.jepmnm) + '</span>' +
             '<span class="sb">' + esc(f.makecust) + (f.brand ? ' · ' + esc(f.brand) : '') + ' · ' + esc(f.jepmcd) + '</span></span>' +
             '<span class="rt">전산 <b style="color:#1f2733">' + n(f.jego) + '</b><br>' +
             (f.status === 'none' ? badge('none') : '실사 <b style="color:#1f2733">' + n(f.realqty) + '</b>') + '</span></button>';
    }).join('');
  }

  // ---------------- 선택 · 등록 ----------------
  function select(p) {
    sel = p;
    drawFound();
    if (!p) { $('selBox').style.display = 'none'; return; }
    var done = p.status !== 'none';
    $('selBox').style.display = '';
    $('sSt').innerHTML = badge(p.status);
    $('sNm').textContent = p.jepmnm;
    $('sSb').textContent = p.makecust + (p.brand ? ' · ' + p.brand : '') + ' · ' + p.jepmcd;
    $('sJego').textContent = n(p.jego);
    $('sReal').textContent = done ? n(p.realqty) + (p.cnt > 1 ? ' (' + p.cnt + '회)' : '') : '-';
    $('qtyLbl').textContent = done ? '추가할 수량 (지금까지 실사에 더해짐)' : '실사 수량';
    $('eQty').value = '';
    preview();
    $('btnSave').disabled = false;
    $('selBox').scrollIntoView({ behavior: 'smooth', block: 'start' });
    setTimeout(function () { $('eQty').focus(); }, 250);
  }

  function preview() {
    if (!sel) return;
    var v = $('eQty').value;
    if (v === '') { $('preview').textContent = '0 도 등록할 수 있어요 (재고 없음 확인).'; return; }
    var tot = (sel.realqty || 0) + Number(v), d = tot - sel.jego;
    $('preview').innerHTML = '등록하면 실사 <b>' + n(tot) + '</b> · 차이 <b class="' + (d < 0 ? 'neg' : d > 0 ? 'posv' : '') + '">' + sn(d) + '</b>';
  }

  function step(k) {
    var v = Math.max(0, Number($('eQty').value || 0) + k);
    $('eQty').value = String(v);
    preview();
  }

  function save() {
    if (!sel) return;
    var v = $('eQty').value.trim();
    if (!/^\d+$/.test(v)) { toast('수량을 숫자로 입력하세요.', true); $('eQty').focus(); return; }
    if (Number(v) >= 1000 && !confirm(sel.jepmnm + '\n수량 ' + n(v) + ' 개가 맞나요?')) { $('eQty').select(); return; }
    var name = sel.jepmnm;
    $('btnSave').disabled = true;
    api('/save', null, { jepmkey: sel.jepmkey, qty: v })
      .then(function (p) {
        calc(p);
        found.forEach(function (f, k) { if (f.jepmkey === p.jepmkey) found[k] = p; });
        toast(name + ' ' + n(v) + '개 등록 · 실사 ' + n(p.realqty));
        if (navigator.vibrate) { try { navigator.vibrate(40); } catch (e) {} }
        // 다음 제품 : 선택 해제하고 검색칸으로
        select(null);
        drawFound();
        $('q').value = '';
        loadRecent();
        window.scrollTo({ top: 0, behavior: 'smooth' });
        setTimeout(function () { $('q').focus(); }, 250);
      })
      .catch(function (e) { fail(e); $('btnSave').disabled = false; });
  }

  // ---------------- 최근 입력 ----------------
  function loadRecent() {
    return api('/recent').then(function (list) {
      $('hCnt').textContent = '최근 ' + list.length + '건';
      $('rec').innerHTML = list.length ? list.map(function (e) {
        return '<div><span><b>' + esc(e.jepmnm || e.jepmcd) + '</b><br><span class="t">' + tLabel(e.prdatetime) + '</span></span>' +
               '<b style="font-size:17px">' + n(e.qty) + '</b></div>';
      }).join('') : '<div class="empty" style="border:0">아직 입력한 수량이 없어요.</div>';
    }).catch(fail);
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    // 지금 화면 메뉴 표시
    Array.prototype.forEach.call(document.querySelectorAll('#sidebarMenuMobile a.menu-program-link'), function (a) {
      if (/\/ai602\.do$/i.test(a.pathname)) a.classList.add('cur');
    });
    $('btnFind').onclick = find;
    ['q', 'qMaker', 'qBrand'].forEach(function (id) {
      $(id).addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); find(); } });
    });
    $('btnMore').onclick = function () {
      var on = $('more').classList.toggle('on');
      this.textContent = (on ? '− ' : '+ ') + '제조회사 · 브랜드로 찾기';
      if (on) $('qMaker').focus();
    };
    $('res').addEventListener('click', function (e) {
      var b = e.target.closest('.it'); if (b) select(found[Number(b.getAttribute('data-i'))]);
    });
    $('eQty').addEventListener('input', function () { this.value = this.value.replace(/\D/g, '').substr(0, 6); preview(); });
    $('eQty').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); save(); } });
    $('btnMinus').onclick = function () { step(-1); };
    $('btnPlus').onclick = function () { step(1); };
    $('btnSave').onclick = save;
    $('btnBack').onclick = function () { if (history.length > 1) history.back(); else location.href = (window.CTX || '') + '/'; };

    loadRecent();
    $('q').focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
