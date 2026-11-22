<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>사양서 확인</title>
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

  /* 표 */
  .two { display:flex; gap:6px; }
  .two > div { min-width:0; }
  .two .left  { flex:3 1 0; }
  .two .right { flex:2 1 0; }
  .tbox { border:1px solid #c9d2e3; border-radius:4px; overflow:auto; max-height:170px; background:#fff; }
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
    <h1>사양서 확인</h1>
    <span class="info" id="topInfo"></span>
    <!-- 생산 모드(mes0201 등) : 확정 / 결재 모드(mes03 등) : 반려 · 결재 -->
    <!-- 비활성 버튼은 크롬에서 안내글(title)이 안 보이므로 바깥 span 에 안내글을 담 -->
    <span class="ms-auto d-none" id="wrapConfirm" tabindex="0">
      <button type="button" class="btn btn-sm btn-success" id="btnConfirm">확 정</button>
    </span>
    <button type="button" class="btn btn-sm btn-danger ms-auto d-none" id="btnReject">반 려</button>
    <button type="button" class="btn btn-sm btn-primary d-none" id="btnSign">결 재</button>
    <button type="button" class="btn btn-sm btn-outline-secondary ms-auto" id="btnReload" onclick="load()">새로고침</button>
    <button type="button" class="btn btn-sm btn-secondary" onclick="window.close()">닫기</button>
  </div>

  <!-- ===== 견적 ===== -->
  <div class="sec">
    <div class="sec-label">견<br>적</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_head"></div>

      <div class="frow">
        <span class="lb">구 분</span>
        <span class="v w60 blue" data-f="datagubun"></span><span class="v w90 gray" data-f="jepmkind"></span>
        <span class="lb">수주일</span><span class="v w90 c" data-f="cdate" data-fmt="date"></span>
        <span class="lb">담당</span><span class="v w80" data-f="sabunnm"></span>
        <span class="lb">관리번호</span><span class="v w90" data-f="oldorderno"></span>
        <span class="arrow">→</span><span class="v w90 link" data-f="orderno"></span>
        <span class="lb">Set번호</span><span class="v w90 gray" data-f="setno"></span>
      </div>

      <div class="frow">
        <span class="lb">보관저장</span>
        <span class="v w100 blue" data-f="keepname"></span><span class="v w60 c" data-f="autoorder"></span>
        <span class="v w60" data-f="papmkind"></span>
        <span class="lb">원관리번호/내역</span>
        <span class="v w100" data-f="wonorderno"></span><span class="v w230" data-f="papmmsg"></span>
        <span class="lb">부재료</span><span class="v w90" data-f="custjepmcd"></span>
      </div>

      <div class="frow">
        <span class="lb">매출처</span>
        <span class="v w150 blue" data-f="custname"></span><span class="v w150 gray" data-f="custsectname"></span>
        <span class="lb">제품</span>
        <span class="v w90 blue" data-f="wonjepmcd"></span><span class="v w420 blue" data-f="jepmnm"></span>
      </div>

      <div class="frow">
        <span class="lb">담당자</span>
        <span class="v w80" data-f="designer"></span><span class="v w100" data-f="designertelno"></span>
        <span class="lb">단 가</span><span class="v w90 r" data-f="price" data-fmt="num2"></span>
        <span class="lb">수량</span><span class="v w90 r" data-f="qty" data-fmt="num"></span>
        <span class="lb">금액</span><span class="v w100 r gray" data-f="amt" data-fmt="num"></span>
        <span class="lb">구분</span><span class="v w80" data-f="kind"></span>
        <span class="lb">신상</span><span class="v w40 c chk" data-f="gubun" data-fmt="sinsang"></span>
        <span class="lb">견적서 확인</span><span class="v w40 c chk" data-f="sheet_chk" data-fmt="yn"></span>
      </div>

      <div class="frow">
        <span class="lb">POCode</span><span class="v w90" data-f="pocode"></span>
        <span class="lb">청구</span><span class="v w60" data-f="taxgubun"></span>
        <span class="lb">청구단가</span><span class="v w90 r gray" data-f="taxprice" data-fmt="num2"></span>
        <span class="lb">수량</span><span class="v w90 r gray" data-f="taxqty" data-fmt="num"></span>
        <span class="lb">금액</span><span class="v w100 r gray" data-f="taxamt" data-fmt="num"></span>
        <span class="lb">년월</span><span class="v w90" data-f="taxyymm"></span>
        <span class="lb">물류CD</span><span class="v w100" data-f="outjpno"></span>
      </div>

      <div class="frow" style="align-items:flex-start">
        <div>
          <div class="frow">
            <span class="lb">납품예정일</span><span class="v w90 c" data-f="deliverydate" data-fmt="date"></span>
            <span class="lb">재 고</span><span class="v w80 r gray" data-f="jego" data-fmt="num"></span>
          </div>
          <div class="frow mb-0">
            <span class="lb">구 분</span><span class="v w90 c ok1" data-f="ok1"></span>
            <span class="lb">등록일</span><span class="v w90 c gray" data-f="prdate" data-fmt="date"></span>
            <span class="v w60 c link" data-f="fileatt"></span>
          </div>
        </div>
        <span class="lb">비 고</span><span class="v w420 memo" data-f="remk"></span>
      </div>
    </div>
  </div>

  <!-- ===== 사양 ===== -->
  <div class="sec">
    <div class="sec-label">사<br>양</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_spec"></div>
      <div class="tbox" id="tSpec"></div>
    </div>
  </div>

  <!-- ===== 외주 ===== -->
  <div class="sec">
    <div class="sec-label">외<br>주</div>
    <div class="sec-body two">
      <div class="left">
        <div class="sec-err d-none" id="err_woiju"></div>
        <div class="tbox" id="tWoiju"></div>
      </div>
      <div class="right">
        <div class="sec-err d-none" id="err_woijuPlan"></div>
        <div class="tbox" id="tWoijuPlan"></div>
      </div>
    </div>
  </div>

  <!-- ===== 지류 ===== -->
  <div class="sec">
    <div class="sec-label">지<br>류</div>
    <div class="sec-body two">
      <div class="left">
        <div class="sec-err d-none" id="err_paper"></div>
        <div class="tbox" id="tPaper"></div>
      </div>
      <div class="right">
        <div class="sec-err d-none" id="err_paperOut"></div>
        <div class="tbox" id="tPaperOut"></div>
      </div>
    </div>
  </div>
</div>

<div id="loading">
  <div class="box">
    <div class="spinner-border" role="status"></div>
    <div class="msg">조회 중…</div>
  </div>
</div>

<%@ include file="/WEB-INF/common/mes_sign.jspf" %>
<script>
  const CTX = '${pageContext.request.contextPath}';
  const Q   = new URLSearchParams(location.search);
  const JPNO = (Q.get("jpno") || "").trim();
  let ORDERNO = (Q.get("orderno") || "").trim();
  const MODE = (Q.get("mode") || "생산").trim();          // '생산' (확정 버튼) / '결재' (반려 · 결재 버튼)
  let headData = {};

  /* ---------- 형식 ---------- */
  function num(v) { const n = Number(v); return isNaN(n) ? 0 : n; }
  function isBlank(v) { return v === null || v === undefined || String(v).trim() === ""; }
  function fmtDate(v) {
    if (isBlank(v)) return "";
    const s = String(v).replace(/\D/g, "");
    return s.length >= 8 ? s.substr(0, 4) + "-" + s.substr(4, 2) + "-" + s.substr(6, 2) : String(v);
  }
  function fmtNum(v)  { return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { maximumFractionDigits: 2 }); }
  function fmtNum2(v) { return isBlank(v) ? "" : num(v).toLocaleString("ko-KR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
  function fmtCheck(v) {
    const s = String(v === null || v === undefined ? "" : v).trim().toUpperCase();
    return (s === "" || s === "N" || s === "0") ? "☐" : "☑";
  }
  function fmt(v, kind) {
    if (kind === "date")  return fmtDate(v);
    if (kind === "num")   return fmtNum(v);
    if (kind === "num2")  return fmtNum2(v);
    if (kind === "check") return fmtCheck(v);
    if (kind === "yn")      return String(v || "").trim().toUpperCase() === "Y" ? "☑" : "☐";   // Y 일 때만 체크
    if (kind === "sinsang") return String(v || "").trim() === "신상" ? "☑" : "☐";   // 값이 '신상' 일 때만 체크
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
      rows.forEach(function (r, i) {
        const tr = body.insertRow();
        cols.forEach(function (c) {
          const td = tr.insertCell();
          const v = c.f === "#" ? (i + 1) : r[c.f];
          td.textContent = fmt(v, c.fmt);
          if (c.cls) td.className = c.cls;
          if (c.cls === "wrap" || c.tip) td.title = td.textContent;
        });
      });
    }
    box.innerHTML = "";
    box.appendChild(table);
  }

  const COL_SPEC = [
    { t: "순번",     f: "seq",       cls: "c" },
    { t: "작업분류", f: "workkind" },
    { t: "지류명",   f: "jepmnm",    tip: true },
    { t: "폭",       f: "cutwidth",  cls: "r", fmt: "num" },
    { t: "장",       f: "cutlength", cls: "r", fmt: "num" },
    { t: "PAGE",     f: "sizepage",  cls: "r", fmt: "num" },
    { t: "절수",     f: "sizejul",   cls: "r", fmt: "num2" },
    { t: "부수",     f: "sizebu",    cls: "r", fmt: "num2" },
    { t: "판-전",    f: "panfront",  cls: "r", fmt: "num" },
    { t: "판-후",    f: "panback",   cls: "r", fmt: "num" },
    { t: "도-전",    f: "dofront",   cls: "r", fmt: "num" },
    { t: "도-후",    f: "doback",    cls: "r", fmt: "num" }
  ];
  const COL_WOIJU = [
    { t: "순번",     f: "seq",      cls: "c" },
    { t: "작업분류", f: "workkind" },
    { t: "공정",     f: "flow" },
    { t: "외주처",   f: "custname" },
    { t: "작업상세", f: "remk",     cls: "wrap" },
    { t: "계획",     f: "chk",      cls: "c" },
    { t: "체크",     f: "procchk",  cls: "c", fmt: "check" }
  ];
  const COL_WOIJU_PLAN = [
    { t: "일자",   f: "procdate",     cls: "c", fmt: "date" },
    { t: "외주처", f: "flowcustname" },
    { t: "분류",   f: "kind" },
    { t: "공정",   f: "flow" },
    { t: "단가",   f: "price",  cls: "r", fmt: "num" },
    { t: "수량",   f: "qty",    cls: "r", fmt: "num" },
    { t: "금액",   f: "dtlamt", cls: "r", fmt: "num" },
    { t: "비고",   f: "loadremk" }
  ];
  const COL_PAPER = [
    { t: "순번",     f: "seq",      cls: "c" },
    { t: "작업분류", f: "workkind" },
    { t: "코드",     f: "jepmcd" },
    { t: "지류명",   f: "jepmnm",   tip: true },
    { t: "규격",     f: "size" },
    { t: "단위",     f: "unit",     cls: "c" },
    { t: "정미",     f: "okper",    cls: "r", fmt: "num2" },
    { t: "로스",     f: "lossper",  cls: "r", fmt: "num2" },
    { t: "절감",     f: "editper",  cls: "r", fmt: "num2" },
    { t: "수량",     f: "qty",      cls: "r", fmt: "num2" }
  ];
  const COL_PAPER_OUT = [
    { t: "처리일", f: "cdate",      cls: "c", fmt: "date" },
    { t: "공정",   f: "flow_gubun" },
    { t: "지류명", f: "papernm",    tip: true },
    { t: "수량",   f: "exelqty",    cls: "r", fmt: "num" },
    { t: "처리자", f: "pruser" },
    { t: "금액",   f: "amt",        cls: "r", fmt: "num" }
  ];

  /* ---------- 견적 채우기 ---------- */
  function fillHead(h) {
    h = h || {};
    headData = h;
    applyButtons();
    // 화면 계산 칸
    h.autoorder = isBlank(h.orderloadjpno) ? "" : "자동발주";
    h.taxprice  = num(h.taxqty) === 0 ? 0 : num(h.taxamt) / num(h.taxqty);
    h.fileatt   = isBlank(h.filename) ? "" : "첨부";

    document.querySelectorAll("[data-f]").forEach(function (el) {
      const v = h[el.dataset.f];
      el.textContent = fmt(v, el.dataset.fmt);
      if (!el.classList.contains("memo")) el.title = el.textContent;
    });
    const ok1 = document.querySelector(".ok1");
    ok1.className = ok1.className.replace(/\bst-\S+/g, "").trim();
    if (!isBlank(h.ok1)) ok1.classList.add("st-" + String(h.ok1).trim());
    const fileEl = document.querySelector('[data-f="fileatt"]');
    fileEl.title = h.filename || "";

    document.getElementById("topInfo").textContent =
      "관리번호 " + (h.orderno || ORDERNO || "") + "  ·  전표번호 " + JPNO + (h.custname ? "  ·  " + h.custname : "");
    document.title = "사양서 확인 - " + (h.orderno || ORDERNO || JPNO);
  }

  function showErr(name, msg) {
    const el = document.getElementById("err_" + name);
    if (!el) return;
    el.classList.toggle("d-none", !msg);
    el.textContent = msg ? "조회 오류 : " + msg : "";
  }

  /* 버튼 사용 가능 여부 : 결재된 사양서는 확정 불가 */
  function applyButtons() {
    const signed = String(headData.ok1 || "").trim() === "결재";
    const b = document.getElementById("btnConfirm");
    b.disabled = signed;
    b.classList.toggle("btn-success",   !signed);
    b.classList.toggle("btn-secondary",  signed);                 // 비활성은 회색
    b.style.pointerEvents = signed ? "none" : "";                 // 마우스는 바깥 span 이 받아 안내글 표시
    document.getElementById("wrapConfirm").title = signed ? "결재된 사양서는 확정할 수 없습니다." : "";
  }

  /* ---------- 확정 (생산 모드) / 반려 · 결재 (결재 모드) ---------- */
  function doSign(ok1) {
    const orderno = headData.orderno || ORDERNO || "";
    if (!confirm("관리번호 " + orderno + "\n" + (headData.jepmnm || "") + "\n\n" + ok1 + " 처리할까요?")) return;
    const btns = [document.getElementById("btnConfirm"), document.getElementById("btnReject"), document.getElementById("btnSign")];
    btns.forEach(function (b) { b.disabled = true; });
    (ok1 === "반려" ? rejectJepm(JPNO) : ok1 === "확정" ? confirmJepm(JPNO) : signJepm(JPNO))
      .then(function (d) {
        // 목록 화면(부른 창)에 알려서 해당 줄 상태 갱신
        try { if (window.opener && !window.opener.closed && window.opener.onJepmSigned) window.opener.onJepmSigned(JPNO, ok1); } catch (e) {}
        const done = { "반려": "반려 처리되었습니다.", "확정": "확정 처리되었습니다.", "결재": "결재 완료되었습니다." };
        alert(done[ok1] + "\n관리번호 " + d.orderno);
        load();
      })
      .catch(function (e) { alert(e.message || e); })
      .then(function () { btns.forEach(function (b) { b.disabled = false; }); applyButtons(); });
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
    fetch(CTX + "/mes0201_jepm_info/data?jpno=" + encodeURIComponent(JPNO) + "&orderno=" + encodeURIComponent(ORDERNO), { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); window.close(); return; }
          throw new Error(res.msg || "조회 중 오류가 발생했습니다.");
        }
        const d = res.data || {}, err = d.errors || {};
        ["head", "spec", "woiju", "woijuPlan", "paper", "paperOut"].forEach(function (k) { showErr(k, err[k]); });
        fillHead(d.head);
        drawTable("tSpec",      COL_SPEC,       d.spec,      "사양 자료가 없습니다.");
        drawTable("tWoiju",     COL_WOIJU,      d.woiju,     "외주 자료가 없습니다.");
        drawTable("tWoijuPlan", COL_WOIJU_PLAN, d.woijuPlan, "외주 처리 내역이 없습니다.");
        drawTable("tPaper",     COL_PAPER,      d.paper,     "지류 자료가 없습니다.");
        drawTable("tPaperOut",  COL_PAPER_OUT,  d.paperOut,  "지류 출고 내역이 없습니다.");
        setTimeout(fitWindow, 50);
      })
      .catch(function (e) { alert(e.message || e); })
      .then(function () { document.getElementById("loading").classList.add("hide"); });
  }

  document.addEventListener("DOMContentLoaded", function () {
    if (MODE === "생산") {
      document.getElementById("wrapConfirm").classList.remove("d-none");
      document.getElementById("btnReload").classList.remove("ms-auto");
      document.getElementById("btnConfirm").addEventListener("click", function () { doSign("확정"); });
    }
    if (MODE === "결재") {
      document.getElementById("btnReject").classList.remove("d-none");
      document.getElementById("btnSign").classList.remove("d-none");
      document.getElementById("btnReload").classList.remove("ms-auto");
      document.getElementById("btnReject").addEventListener("click", function () { doSign("반려"); });
      document.getElementById("btnSign").addEventListener("click", function () { doSign("결재"); });
    }
    load();
  });
  document.addEventListener("keydown", function (e) { if (e.key === "Escape") window.close(); });
</script>
</body>
</html>
