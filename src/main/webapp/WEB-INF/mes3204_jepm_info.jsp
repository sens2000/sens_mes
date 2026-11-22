<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>수주 정보</title>
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
    <h1>수주 정보</h1>
    <span class="info" id="topInfo"></span>
    <button type="button" class="btn btn-sm btn-outline-secondary ms-auto" onclick="load()">새로고침</button>
    <button type="button" class="btn btn-sm btn-secondary" onclick="window.close()">닫기</button>
  </div>

  <div class="sec">
    <div class="sec-label">수<br>주</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_head"></div>

      <div class="frow">
        <span class="lb">구 분</span><span class="v w100 gray" data-f="jepmkind"></span>
        <span class="lb">수주일</span><span class="v w90 c" data-f="cdate" data-fmt="date"></span>
        <span class="lb">담당</span><span class="v w80 blue" data-f="sabunnm"></span>
        <span class="lb">원제품</span>
        <span class="v w100 blue" data-f="wonjepmcd"></span><span class="v w60" data-f="test"></span>
        <span class="lb">관리번호</span><span class="v w90 link" data-f="orderno"></span>
        <span class="lb">보관업체</span><span class="v w100 blue" data-f="keepname"></span>
      </div>

      <div class="frow">
        <span class="lb">매출처</span>
        <span class="v w150 blue" data-f="custname"></span><span class="v w150 gray" data-f="custsectname"></span>
        <span class="lb">출고</span><span class="v w40 c chk" data-f="cgchk" data-fmt="yn"></span>
        <span class="lb">제 품</span>
        <span class="v w100 blue" data-f="jepmcd"></span><span class="v w420 blue" data-f="jepmnm"></span>
      </div>

      <div class="frow">
        <span class="lb">담당자</span>
        <span class="v w100" data-f="designer"></span><span class="v w100" data-f="designertelno"></span>
        <span class="lb">단 가</span><span class="v w120 r" data-f="price" data-fmt="num2"></span>
        <span class="lb">수량</span><span class="v w100 r" data-f="qty" data-fmt="num"></span>
        <span class="lb">금액</span><span class="v w100 r gray" data-f="amt" data-fmt="num"></span>
        <span class="lb">구분</span>
        <span class="v w80" data-f="kind"></span><span class="v w80" data-f="taxpub"></span>
      </div>

      <div class="frow">
        <span class="lb">POCode</span>
        <span class="v w100" data-f="pocode"></span><span class="v w80" data-f="code"></span>
        <span class="lb">청구단가</span><span class="v w120 r gray" data-f="taxprice" data-fmt="num2"></span>
        <span class="lb">수량</span><span class="v w100 r gray" data-f="taxqty" data-fmt="num"></span>
        <span class="lb">금액</span><span class="v w100 r gray" data-f="taxamt" data-fmt="num"></span>
        <span class="lb">년월</span><span class="v w80" data-f="taxyymm"></span>
        <span class="lb">불량내역</span><span class="v w80" data-f="papmkind"></span>
      </div>

      <div class="frow mb-0" style="align-items:flex-start">
        <div>
          <div class="frow">
            <span class="lb">납품예정일</span>
            <span class="v w90 c blue" data-f="deliverydate" data-fmt="date"></span><span class="v w60 c" data-f="d_day" id="ddayEl"></span>
            <span class="lb">재 고</span><span class="v w80 r gray" data-f="jego" data-fmt="num"></span>
          </div>
          <div class="frow mb-0">
            <span class="lb">등록일</span><span class="v w90 c gray" data-f="prdate" data-fmt="date"></span>
            <span class="lb">저장</span><span class="v w80 gray" data-f="jepmgubun"></span>
            <span class="v w80 c ok1" data-f="ok1"></span>
          </div>
        </div>
        <div class="d-flex flex-column gap-1">
          <span class="lb" style="min-width:0">비 고</span>
          <span class="v w60 c att" data-f="fileatt"></span>
        </div>
        <span class="v memo" style="flex:1 1 0; height:auto; min-height:62px" data-f="remk"></span>
        <div class="d-flex flex-column gap-1">
          <span class="lb" style="min-width:0; text-align:left">부재료</span>
          <span class="v w120" data-f="custjepmcd"></span>
        </div>
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
  const CTX  = '${pageContext.request.contextPath}';
  const Q    = new URLSearchParams(location.search);
  const JPNO = (Q.get("jpno") || "").trim();

  /* ---------- 형식 ---------- */
  function num(v) { const n = Number(v); return isNaN(n) ? 0 : n; }
  function isBlank(v) { return v === null || v === undefined || String(v).trim() === ""; }
  function fmtDate(v) {
    if (isBlank(v)) return "";
    const s = String(v).replace(/\D/g, "");
    return s.length >= 8 ? s.substr(0, 4) + "-" + s.substr(4, 2) + "-" + s.substr(6, 2) : String(v);
  }
  function fmt(v, kind) {
    if (kind === "date") return fmtDate(v);
    if (kind === "num")  return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { maximumFractionDigits: 2 });
    if (kind === "num1") return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { minimumFractionDigits: 1, maximumFractionDigits: 2 });
    if (kind === "num2") return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    if (kind === "yn")   return String(v || "").trim().toUpperCase() === "Y" ? "☑" : "☐";   // Y 일 때만 체크
    if (kind === "pct")  return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { maximumFractionDigits: 2 }) + "%";
    return isBlank(v) ? "" : String(v);
  }

  /* 납품예정일까지 남은 날 : D-11, 지나면 D+2 */
  function ddayOf(v) {
    const s = String(v || "").replace(/\D/g, "");
    if (s.length < 8) return null;
    const due = new Date(+s.substr(0, 4), +s.substr(4, 2) - 1, +s.substr(6, 2));
    const t = new Date(); const today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
    return Math.round((due - today) / 86400000);
  }

  /* ---------- 채우기 ---------- */
  function fillHead(h) {
    h = h || {};
    h.taxprice = num(h.taxqty) === 0 ? 0 : num(h.taxamt) / num(h.taxqty);   // 청구단가
    h.fileatt  = isBlank(h.filename) ? "" : "첨부";                         // 비고 아래
    const n = ddayOf(h.deliverydate);
    h.d_day = n === null ? "" : (n >= 0 ? "D-" + n : "D+" + (-n));

    document.querySelectorAll("[data-f]").forEach(function (el) {
      el.textContent = fmt(h[el.dataset.f], el.dataset.fmt);
      if (!el.classList.contains("memo")) el.title = el.textContent;
    });
    document.querySelector('[data-f="fileatt"]').title = h.filename || "";
    document.getElementById("ddayEl").classList.toggle("dday-red", n !== null && n <= 6);

    const ok1 = document.querySelector(".ok1");
    ok1.className = ok1.className.replace(/\bst-\S+/g, "").trim();
    if (!isBlank(h.ok1)) ok1.classList.add("st-" + String(h.ok1).trim());

    document.getElementById("topInfo").textContent =
      "관리번호 " + (h.orderno || "") + "  ·  전표번호 " + JPNO + (h.custname ? "  ·  " + h.custname : "");
    document.title = "수주 정보 - " + (h.orderno || JPNO);
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
    if (!JPNO) { alert("전표번호(jpno)가 없습니다."); return; }
    document.getElementById("loading").classList.remove("hide");
    fetch(CTX + "/mes3204_jepm_info/data?jpno=" + encodeURIComponent(JPNO), { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); window.close(); return; }
          throw new Error(res.msg || "조회 중 오류가 발생했습니다.");
        }
        const d = res.data || {}, err = d.errors || {};
        showErr("head", err.head);
        fillHead(d.head);
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
