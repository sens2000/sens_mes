<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>거래처</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background:#eef1f6; font-size:.8rem; }
  .wrap { padding:8px; }

  /* 상단 */
  .top { display:flex; align-items:center; gap:8px; margin-bottom:6px; }
  .top h1 { font-size:.95rem; font-weight:800; margin:0; color:#2f3e5c; }
  .top .info { color:#6c757d; }

  /* 구역 (왼쪽 세로 글자 + 내용) */
  .sec { display:flex; background:#fff; border:1px solid #c9d2e3; border-radius:6px; margin-bottom:6px; overflow:hidden; }
  .sec-label { width:28px; flex:0 0 28px; background:#2f3e5c; color:#fff; font-weight:800; font-size:1rem;
               display:flex; align-items:center; justify-content:center; text-align:center; line-height:1.5; }
  .sec-body { flex:1 1 0; min-width:0; padding:6px; }
  .sec-err { color:#dc2626; font-weight:700; padding:4px; }

  /* 견적 (입력칸처럼 보이는 읽기 전용 칸) */
  .frow { display:flex; flex-wrap:wrap; align-items:center; gap:4px 6px; margin-bottom:4px; }
  .lb { font-weight:700; color:#2f3e5c; white-space:nowrap; min-width:58px; text-align:right; }
  .v  { display:inline-block; min-height:22px; line-height:20px; padding:0 5px; border:1px solid #b8c2d6; border-radius:3px;
        background:#f7f9fc; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; vertical-align:middle; }
  .v.gray { background:#d9dde5; }
  .v.blue { background:#dbe7fb; }
  .v.r { text-align:right; }
  .v.c { text-align:center; }
  .v.memo { white-space:pre-wrap; height:46px; overflow:auto; vertical-align:top; }
  .w50{width:50px}.w70{width:70px}
  .w40{width:40px}.w60{width:60px}.w80{width:80px}.w90{width:90px}.w100{width:100px}.w120{width:120px}
  .w150{width:150px}.w180{width:180px}.w230{width:230px}.w300{width:300px}.w420{width:420px}
  .chk { font-size:1rem; line-height:1; }
  .ok1 { font-weight:800; }
  .ok1.st-결재 { background:#d38ad8; color:#fff; }
  .ok1.st-확정 { background:#cfe8d5; color:#14532d; }
  .ok1.st-미확정 { background:#fde2c7; color:#9a3412; }
  .ok1.st-반려 { background:#fecaca; color:#991b1b; }
  .arrow { color:#6c757d; font-weight:700; }
  .link { color:#1d4ed8; font-weight:700; }

  .box { border:1px solid #b8c2d6; border-radius:4px; padding:6px; }
  .att { color:#1d4ed8; font-weight:700; }
  .dday-red { color:#dc2626; font-weight:700; }
  /* 표 */
  .two { display:flex; gap:6px; }
  .two > div { min-width:0; }
  .two .left  { flex:3 1 0; }
  .two .right { flex:2 1 0; }
  .tbox { border:1px solid #c9d2e3; border-radius:4px; overflow:auto; max-height:190px; background:#fff; }
  table.t { width:100%; border-collapse:collapse; font-size:.78rem; }
  table.t th { position:sticky; top:0; background:#e8eef8; color:#2f3e5c; font-weight:700; text-align:center;
               border-bottom:2px solid #9fb3d6; padding:3px 4px; white-space:nowrap; z-index:1; }
  table.t td { border-bottom:1px solid #edf0f5; padding:2px 4px; white-space:nowrap; }
  table.t td.r { text-align:right; }
  table.t td.c { text-align:center; }
  table.t td.wrap { white-space:normal; min-width:160px; }
  table.t tr:hover td { background:#f5f8ff; }
  table.t td.empty { text-align:center; color:#9aa3b2; padding:10px; }

  .lb { min-width:46px; }
  .grow { flex:1 1 0; min-width:120px; }
  /* 조회 중 */
  #loading { position:fixed; inset:0; z-index:2000; display:flex; align-items:center; justify-content:center;
             background:rgba(255,255,255,.6); }
  #loading.hide { display:none; }
  #loading .box { background:#2f3e5c; color:#fff; border-radius:14px; padding:1.6rem 2.6rem; text-align:center; }
  #loading .spinner-border { width:3rem; height:3rem; color:#ffd166; }
  #loading .msg { font-size:1.5rem; font-weight:800; margin-top:.6rem; }
</style>
</head>
<body>
<div class="wrap">

  <div class="top">
    <h1>거래처</h1>
    <span class="info" id="topInfo"></span>
    <button type="button" class="btn btn-sm btn-outline-secondary ms-auto" onclick="load()">새로고침</button>
    <button type="button" class="btn btn-sm btn-secondary" onclick="window.close()">닫기</button>
  </div>

  <div class="sec">
    <div class="sec-label">거<br>래<br>처</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_head"></div>

      <div class="frow">
        <span class="lb">회 사</span><span class="v w60 blue" data-f="company"></span>
        <span class="lb">담당자</span><span class="v w90 gray" data-f="sabunnm"></span>
        <span class="lb">구분</span><span class="v w60" data-f="mimc"></span>
        <span class="lb">처리</span><span class="v w60" data-f="gubun"></span>
        <span class="lb">거래처</span><span class="v grow" data-f="custname"></span>
      </div>

      <div class="frow">
        <span class="lb">대 표</span><span class="v w90" data-f="owner"></span>
        <span class="lb">대표전화</span><span class="v w120" data-f="telno"></span>
        <span class="lb">조건</span><span class="v w60 r" data-f="term" data-fmt="num"></span>
        <span class="lb">FAX NO</span><span class="v grow" data-f="faxno"></span>
      </div>

      <div class="frow">
        <span class="lb">비 고</span><span class="v grow" data-f="remk"></span>
        <span class="lb">ID</span><span class="v w80" data-f="userid"></span>
        <span class="lb">Pass</span><span class="v w60 c" data-f="haspass" data-fmt="pass" title="비밀번호는 표시하지 않습니다"></span>
        <span class="lb">거래구분</span><span class="v w40 c chk" data-f="chk" data-fmt="yn"></span>
      </div>

      <div class="frow">
        <span class="lb">사업자명</span><span class="v grow" data-f="taxname"></span>
        <span class="lb">사업자번호</span><span class="v w150" data-f="sano"></span>
      </div>

      <div class="frow mb-0">
        <span class="lb">주 소</span><span class="v grow" data-f="addr"></span>
      </div>
    </div>
  </div>

  <div class="sec">
    <div class="sec-label">부<br>서</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_dtl"></div>
      <div class="tbox">
        <table class="t">
          <thead><tr><th>부서</th><th>사원명</th><th>거래처부서</th><th>거래처담당</th><th>전화번호</th></tr></thead>
          <tbody id="dtlBody"><tr><td class="empty" colspan="5">조회 중…</td></tr></tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<div id="loading">
  <div class="box" style="border:0">
    <div class="spinner-border" role="status"></div>
    <div class="msg">조회 중…</div>
  </div>
</div>

<script>
  const CTX    = '${pageContext.request.contextPath}';
  const Q      = new URLSearchParams(location.search);
  const CUSTCD = (Q.get("custcd") || "").trim();

  /* ---------- 형식 ---------- */
  function num(v) { const n = Number(v); return isNaN(n) ? 0 : n; }
  function isBlank(v) { return v === null || v === undefined || String(v).trim() === ""; }
  function esc(v) { return String(v == null ? "" : v).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function fmtDate(v) {
    if (isBlank(v)) return "";
    const s = String(v).replace(/\D/g, "");
    return s.length >= 8 ? s.substr(0, 4) + "-" + s.substr(4, 2) + "-" + s.substr(6, 2) : String(v);
  }
  function fmt(v, kind) {
    if (kind === "date") return fmtDate(v);
    if (kind === "num")  return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { maximumFractionDigits: 2 });
    if (kind === "yn")   return String(v || "").trim().toUpperCase() === "Y" ? "☑" : "☐";   // 거래구분 : Y 일 때 체크
    if (kind === "pass") return v === "Y" ? "●●●●" : "";                                   // 비밀번호는 있음 / 없음만
    return isBlank(v) ? "" : String(v);
  }

  /* ---------- 채우기 ---------- */
  function fillHead(h) {
    h = h || {};
    h.addr = [h.addr1, h.addr2].filter(function (x) { return !isBlank(x); }).join(" ");   // 주소 1 + 2
    document.querySelectorAll("[data-f]").forEach(function (el) {
      el.textContent = fmt(h[el.dataset.f], el.dataset.fmt);
      if (el.dataset.fmt !== "pass") el.title = el.textContent;
    });
    document.getElementById("topInfo").textContent = "거래처코드 " + CUSTCD;
    document.title = "거래처 - " + (h.custname || CUSTCD);
  }

  function fillDtl(rows) {
    const tb = document.getElementById("dtlBody");
    if (!rows || !rows.length) { tb.innerHTML = '<tr><td class="empty" colspan="5">부서가 없습니다.</td></tr>'; return; }
    tb.innerHTML = rows.map(function (r) {
      return "<tr>" +
        "<td>" + esc(r.sectname) + "</td>" +
        "<td>" + esc(r.sabunnm) + "</td>" +
        '<td class="wrap">' + esc(r.custsectname) + "</td>" +
        "<td>" + esc(r.custmanager) + "</td>" +
        "<td>" + esc(r.telno) + "</td>" +
        "</tr>";
    }).join("");
  }

  function showErr(name, msg) {
    const el = document.getElementById("err_" + name);
    if (!el) return;
    el.classList.toggle("d-none", !msg);
    el.textContent = msg ? "조회 오류 : " + msg : "";
  }

  /* ---------- 팝업 창 높이를 내용에 맞춤 ---------- */
  function fitWindow() {
    try {
      const need   = document.querySelector(".wrap").scrollHeight + 4;
      const frameH = window.outerHeight - window.innerHeight;          // 제목줄·주소줄 높이
      const h = Math.min(screen.availHeight, need + frameH);
      if (Math.abs(window.outerHeight - h) > 4) window.resizeTo(window.outerWidth, h);
    } catch (e) { /* 팝업이 아닌 일반 탭이면 크기 조절 불가 — 무시 */ }
  }

  /* ---------- 조회 ---------- */
  function load() {
    if (!CUSTCD) { alert("거래처코드(custcd)가 없습니다."); return; }
    document.getElementById("loading").classList.remove("hide");
    fetch(CTX + "/mes0105_cust_mst/data?custcd=" + encodeURIComponent(CUSTCD), { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); window.close(); return; }
          throw new Error(res.msg || "조회 중 오류가 발생했습니다.");
        }
        const d = res.data || {}, err = d.errors || {};
        showErr("head", err.head);
        showErr("dtl", err.dtl);
        fillHead(d.head);
        fillDtl(d.dtl);
        setTimeout(fitWindow, 50);
      })
      .catch(function (e) { alert(e.message || e); })
      .then(function () { document.getElementById("loading").classList.add("hide"); });
  }

  document.addEventListener("DOMContentLoaded", load);
  document.addEventListener("keydown", function (e) { if (e.key === "Escape") window.close(); });
</script>
</body>
</html>
