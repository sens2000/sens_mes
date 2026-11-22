<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>제품 사양 정보</title>
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
    <h1>제품 사양 정보</h1>
    <span class="info" id="topInfo"></span>
    <button type="button" class="btn btn-sm btn-outline-secondary ms-auto" onclick="load()">새로고침</button>
    <button type="button" class="btn btn-sm btn-secondary" onclick="window.close()">닫기</button>
  </div>

  <!-- ===== 기본정보 ===== -->
  <div class="sec">
    <div class="sec-label">기<br>본<br>정<br>보</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_head"></div>

      <div class="frow">
        <span class="lb">제 품</span>
        <span class="v w100 blue" data-f="jepmcd"></span><span class="v w420 blue" data-f="jepmnm"></span>
        <span class="lb">매출처</span>
        <span class="v w150 blue" data-f="custname"></span><span class="v w150 gray" data-f="custsectname"></span>
      </div>

      <div class="frow">
        <span class="lb">구 분</span>
        <span class="v w90 gray" data-f="jepmkind"></span><span class="v w60 gray" data-f="jepmgubun"></span>
        <span class="lb">완제품</span><span class="v w100 blue" data-f="prodjepmcd"></span>
        <span class="lb">관리번호</span><span class="v w100 link" data-f="orderno"></span>
        <span class="lb">담당자</span><span class="v w90" data-f="designer"></span>
        <span class="lb">전화NO</span><span class="v w120" data-f="designertelno"></span>
      </div>

      <div class="frow">
        <span class="lb">접수일</span><span class="v w90 c blue" data-f="cdate" data-fmt="date"></span>
        <span class="lb">담 당</span><span class="v w80 blue" data-f="sabunnm"></span>
        <span class="lb">부코드</span><span class="v w120" data-f="custjepmcd"></span>
        <span class="lb">등록일</span><span class="v w90 c gray" data-f="prdate" data-fmt="date"></span>
        <span class="lb">최종수정</span>
        <span class="v w90 c gray" data-f="moddate" data-fmt="date"></span><span class="v w70 gray" data-f="moduser"></span>
      </div>

      <div class="frow mb-0" style="align-items:stretch">
        <div class="box">
          <div class="frow">
            <span class="lb">판 형</span><span class="v w100" data-f="pantype"></span>
            <span class="lb">장.폭.고</span>
            <span class="v w60 r" data-f="width" data-fmt="num"></span><span class="v w60 r" data-f="length" data-fmt="num"></span><span class="v w60 r" data-f="height" data-fmt="num"></span>
          </div>
          <div class="frow">
            <span class="lb">절 수</span><span class="v w60 r" data-f="sizejul" data-fmt="num"></span>
            <span class="lb">부수</span><span class="v w60 r" data-f="sizebu" data-fmt="num1"></span>
            <span class="lb">종횡</span><span class="v w60 c" data-f="lentype"></span>
          </div>
          <div class="frow">
            <span class="lb">재 단</span>
            <span class="v w50 r" data-f="cutwidth" data-fmt="num"></span><span class="v w50 r" data-f="cutlength" data-fmt="num"></span>
            <span class="lb">판수</span><span class="v w60 r" data-f="pancnt" data-fmt="num"></span>
            <span class="lb">도수</span><span class="v w60 r" data-f="docnt" data-fmt="num"></span>
          </div>
          <div class="frow mb-0">
            <span class="lb">실규격</span>
            <span class="v w50 r" data-f="silwidth" data-fmt="num"></span><span class="v w50 r" data-f="sillength" data-fmt="num"></span>
          </div>
        </div>
        <div class="d-flex flex-column gap-1">
          <span class="lb" style="min-width:0">비 고</span>
          <span class="v w60 c att" data-f="fileatt" title=""></span>
          <span class="v w60 c att" data-f="mcinfoatt" title=""></span>
        </div>
        <span class="v memo" style="flex:1 1 0; height:auto; min-height:90px" data-f="remk"></span>
      </div>
    </div>
  </div>

  <!-- ===== 공정 ===== -->
  <div class="sec">
    <div class="sec-label">공<br>정</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_flow"></div>
      <div class="tbox" id="tFlow"></div>
    </div>
  </div>

  <!-- ===== 지류 ===== -->
  <div class="sec">
    <div class="sec-label">지<br>류</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_paper"></div>
      <div class="tbox" id="tPaper"></div>
    </div>
  </div>

  <!-- ===== 변경정보 ===== -->
  <div class="sec">
    <div class="sec-label">변<br>경<br>정<br>보</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_log"></div>
      <div class="tbox" id="tLog"></div>
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
  const JEPMNO = (Q.get("jepmno") || "").trim();

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
    if (kind === "pct")  return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { maximumFractionDigits: 2 }) + "%";
    return isBlank(v) ? "" : String(v);
  }

  /* ---------- 표 그리기 ---------- */
  function drawTable(boxId, cols, rows, emptyMsg) {
    const box = document.getElementById(boxId);
    const table = document.createElement("table");
    table.className = "t";
    const thead = table.createTHead().insertRow();
    cols.forEach(function (c) { const th = document.createElement("th"); th.textContent = c.t; thead.appendChild(th); });
    const body = table.createTBody();
    if (!rows || !rows.length) {
      const td = body.insertRow().insertCell();
      td.colSpan = cols.length; td.className = "empty"; td.textContent = emptyMsg || "자료가 없습니다.";
    } else {
      rows.forEach(function (r) {
        const tr = body.insertRow();
        cols.forEach(function (c) {
          const td = tr.insertCell();
          td.textContent = fmt(r[c.f], c.fmt);
          if (c.cls) td.className = c.cls;
          if (c.cls === "wrap" || c.tip) td.title = td.textContent;
        });
      });
    }
    box.innerHTML = "";
    box.appendChild(table);
  }

  const COL_FLOW = [
    { t: "순번",     f: "seq",        cls: "c" },
    { t: "작업분류", f: "workkind" },
    { t: "공정구분", f: "flow" },
    { t: "공정명",   f: "flowcdname", tip: true },
    { t: "외주처",   f: "custname" },
    { t: "전면",     f: "frontcnt",   cls: "r", fmt: "num" },
    { t: "후면",     f: "backcnt",    cls: "r", fmt: "num" },
    { t: "LOSS율",   f: "lossper",    cls: "r", fmt: "pct" },
    { t: "작업상세", f: "remk",       cls: "wrap" }
  ];
  const COL_PAPER = [
    { t: "순번",     f: "seq",      cls: "c" },
    { t: "작업분류", f: "workkind" },
    { t: "지류코드", f: "jepmcd" },
    { t: "지류명",   f: "jepmnm",   tip: true },
    { t: "규격",     f: "size" },
    { t: "단위",     f: "unit",     cls: "c" }
  ];
  const COL_LOG = [
    { t: "순번",     f: "seq",     cls: "c" },
    { t: "수정일",   f: "prdate",  cls: "c", fmt: "date" },
    { t: "수정자",   f: "pruser" },
    { t: "구분",     f: "kind" },
    { t: "변경내역", f: "remk",    cls: "wrap" }
  ];

  /* ---------- 기본정보 채우기 ---------- */
  function fillHead(h) {
    h = h || {};
    h.fileatt   = isBlank(h.filename)       ? "" : "견적";      // 견적서 첨부
    h.mcinfoatt = isBlank(h.mcinfofilename) ? "" : "제조";      // 제조사양 첨부

    document.querySelectorAll("[data-f]").forEach(function (el) {
      el.textContent = fmt(h[el.dataset.f], el.dataset.fmt);
      if (!el.classList.contains("memo")) el.title = el.textContent;
    });
    document.querySelector('[data-f="fileatt"]').title   = h.filename || "";
    document.querySelector('[data-f="mcinfoatt"]').title = h.mcinfofilename || "";

    document.getElementById("topInfo").textContent =
      (h.jepmcd ? "제품 " + h.jepmcd + "  ·  " : "") + (h.jepmnm || "") + (h.custname ? "  ·  " + h.custname : "");
    document.title = "제품 사양 - " + (h.jepmnm || JEPMNO);
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
    if (!JEPMNO) { alert("제품번호(jepmno)가 없습니다."); return; }
    document.getElementById("loading").classList.remove("hide");
    fetch(CTX + "/mes3202_jepm_info/data?jepmno=" + encodeURIComponent(JEPMNO), { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); window.close(); return; }
          throw new Error(res.msg || "조회 중 오류가 발생했습니다.");
        }
        const d = res.data || {}, err = d.errors || {};
        ["head", "flow", "paper", "log"].forEach(function (k) { showErr(k, err[k]); });
        fillHead(d.head);
        drawTable("tFlow",  COL_FLOW,  d.flow,  "공정 자료가 없습니다.");
        drawTable("tPaper", COL_PAPER, d.paper, "지류 자료가 없습니다.");
        drawTable("tLog",   COL_LOG,   d.log,   "변경 내역이 없습니다.");
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
