<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>사양서출고 확인</title>
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
  .lb.n { min-width:0; }   /* 라벨 앞 여백 없이 */
  .v  { display:inline-block; min-height:22px; line-height:20px; padding:0 5px; border:1px solid #b8c2d6; border-radius:3px;
        background:#f7f9fc; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; vertical-align:middle; }
  .v.gray { background:#d9dde5; }
  .v.blue { background:#dbe7fb; }
  .v.r { text-align:right; }
  .v.c { text-align:center; }
  .v.memo { white-space:pre-wrap; height:46px; overflow:auto; vertical-align:top; }
  .w70{width:70px}
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
  .tbox { border:1px solid #c9d2e3; border-radius:4px; overflow:auto; height:200px; background:#fff; }
  .sub-title { font-weight:800; color:#2f3e5c; margin:0 0 3px 2px; }
  .two .half { flex:1 1 0; }
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
    <h1>사양서출고 확인</h1>
    <span class="info" id="topInfo"></span>
    <button type="button" class="btn btn-sm btn-outline-secondary ms-auto" onclick="load()">새로고침</button>
    <button type="button" class="btn btn-sm btn-secondary" onclick="window.close()">닫기</button>
  </div>

  <!-- ===== 출고 내용 ===== -->
  <div class="sec">
    <div class="sec-label">출<br>고</div>
    <div class="sec-body">
      <div class="sec-err d-none" id="err_head"></div>

      <div class="frow">
        <span class="lb">수주일</span><span class="v w90 c blue" data-f="cdate" data-fmt="date"></span>
        <span class="lb">담당</span><span class="v w80" data-f="sabunnm"></span>
        <span class="lb">관리번호</span><span class="v w100 gray" data-f="fromorderno"></span>
        <span class="arrow">→</span><span class="v w100 link" data-f="orderno"></span>
        <span class="lb">Set번호</span><span class="v w90 gray" data-f="setno"></span>
        <span class="lb">부재료</span><span class="v w90" data-f="custjepmcd"></span>
        <span class="lb">등록일</span><span class="v w90 c gray" data-f="prdate" data-fmt="date"></span>
      </div>

      <div class="frow">
        <span class="lb">매출처</span>
        <span class="v w150 blue" data-f="custname"></span><span class="v w120 gray" data-f="custsectname"></span>
        <span class="lb">담당자</span>
        <span class="v w80" data-f="designer"></span><span class="v w100" data-f="designertelno"></span>
        <span class="lb">제 품</span>
        <span class="v w90 blue" data-f="wonjepmcd"></span><span class="v w300" data-f="jepmnm"></span>
      </div>

      <div class="frow">
        <span class="lb">단 가</span><span class="v w90 r" data-f="price" data-fmt="num2"></span>
        <span class="lb">수량</span><span class="v w70 r" data-f="qty" data-fmt="num"></span>
        <span class="lb">금액</span><span class="v w100 r gray" data-f="amt" data-fmt="num"></span>
        <span class="lb">구분</span><span class="v w60" data-f="kind"></span>
        <span class="lb">원주문수량</span><span class="v w80 r blue" data-f="wonorderqty" data-fmt="num"></span>
        <span class="lb">세금계산서 요청</span><span class="v w40 c chk" data-f="bill_call" data-fmt="yn"></span>
        <span class="v w90 c" data-f="call_date" data-fmt="date"></span>
        <span class="lb">구분</span>
        <span class="v w60 blue" data-f="datagubun"></span><span class="v w90 gray" data-f="jepmkind"></span>
      </div>

      <div class="frow">
        <span class="lb">청구단가</span><span class="v w90 r gray" data-f="taxprice" data-fmt="num2"></span>
        <span class="lb">수량</span><span class="v w70 r gray" data-f="taxqty" data-fmt="num"></span>
        <span class="lb">금액</span><span class="v w100 r gray" data-f="taxamt" data-fmt="num"></span>
        <span class="lb">년월</span><span class="v w60 c" data-f="taxyymm"></span>
        <span class="lb">납품예정일</span><span class="v w90 c" data-f="deliverydate" data-fmt="date"></span>
        <span class="lb n">청구</span><span class="v w60" data-f="taxgubun"></span>
        <span class="lb n">POCode</span><span class="v w90" data-f="pocode"></span>
        <span class="v w60 c link" data-f="fileatt"></span>
        <span class="lb n">물류CD</span><span class="v w100" data-f="outjpno"></span>
      </div>

      <div class="frow">
        <span class="lb">보관업체</span><span class="v w150" data-f="keepname"></span>
        <span class="lb">입찰일자</span><span class="v w90 c" data-f="biddate" data-fmt="date"></span>
      </div>

      <div class="frow mb-0" style="align-items:flex-start">
        <span class="lb">공급처 비고</span><span class="v memo" style="width:38%" data-f="remk"></span>
        <span class="lb">비 고</span><span class="v memo" style="width:38%" data-f="flowlist"></span>
      </div>
    </div>
  </div>

  <!-- ===== 납품현황 / 청구현황 ===== -->
  <div class="two">
    <div class="half">
      <div class="sub-title">납품현황</div>
      <div class="sec-err d-none" id="err_delivery"></div>
      <div class="tbox" id="tDelivery"></div>
    </div>
    <div class="half">
      <div class="sub-title">청구현황</div>
      <div class="sec-err d-none" id="err_tax"></div>
      <div class="tbox" id="tTax"></div>
    </div>
  </div>
</div>

<div id="loading">
  <div class="box">
    <div class="spinner-border" role="status"></div>
    <div class="msg">조회 중…</div>
  </div>
</div>

<script>
  const CTX = '${pageContext.request.contextPath}';
  const Q   = new URLSearchParams(location.search);
  const JPNO = (Q.get("jpno") || "").trim();
  let ORDERNO = (Q.get("orderno") || "").trim();

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
  function fmt(v, kind) {
    if (kind === "date") return fmtDate(v);
    if (kind === "num")  return fmtNum(v);
    if (kind === "num2") return fmtNum2(v);
    if (kind === "yn")   return String(v || "").trim().toUpperCase() === "Y" ? "☑" : "☐";   // Y 일 때만 체크
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
          td.textContent = fmt(c.calc ? c.calc(r) : r[c.f], c.fmt);
          if (c.cls) td.className = c.cls;
          if (c.cls === "wrap" || c.tip) td.title = td.textContent;
        });
      });
    }
    box.innerHTML = "";
    box.appendChild(table);
  }

  const COL_DELIVERY = [
    { t: "등록일",   f: "prdate",        cls: "c", fmt: "date" },
    { t: "납기일",   f: "deliverydate",  cls: "c", fmt: "date" },
    { t: "구분",     f: "excelchk",      cls: "c" },
    { t: "납품수량", f: "deliveryqty",   cls: "r", fmt: "num" },
    { t: "비고",     f: "remk",          cls: "wrap" },
    { t: "납품장소", f: "deliveryplace", tip: true },
    { t: "보증",     cls: "c", calc: function (r) { return isBlank(r.delivery_auth_jpno) ? "" : "출력"; } },
    { t: "확인",     cls: "c", calc: function (r) {
        const v = String(r.delivery_list_jpno || "").trim();
        return v === "" ? "" : (v === "**" ? "출력중" : "출력");
      } }
  ];
  const COL_TAX = [
    { t: "년월",     f: "cdate",     cls: "c" },
    { t: "매출처",   f: "custname",  tip: true },
    { t: "매출부서", f: "subcustnm", tip: true },
    { t: "매출담당", f: "designnm1" },
    { t: "공급가",   f: "amt",       cls: "r", fmt: "num" },
    { t: "수량",     f: "qty",       cls: "r", fmt: "num" }
  ];

  /* ---------- 출고 내용 채우기 ---------- */
  function fillHead(h) {
    h = h || {};
    h.taxprice = num(h.taxqty) === 0 ? 0 : num(h.taxamt) / num(h.taxqty);   // 청구단가
    h.fileatt  = isBlank(h.filename) ? "" : "첨부";

    document.querySelectorAll("[data-f]").forEach(function (el) {
      el.textContent = fmt(h[el.dataset.f], el.dataset.fmt);
      if (!el.classList.contains("memo")) el.title = el.textContent;
    });
    document.querySelector('[data-f="fileatt"]').title = h.filename || "";

    document.getElementById("topInfo").textContent =
      "관리번호 " + (h.orderno || ORDERNO || "") + "  ·  전표번호 " + JPNO + (h.custname ? "  ·  " + h.custname : "");
    document.title = "사양서출고 - " + (h.orderno || ORDERNO || JPNO);
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
    fetch(CTX + "/mes0201_jepm_jego/data?jpno=" + encodeURIComponent(JPNO) + "&orderno=" + encodeURIComponent(ORDERNO), { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); window.close(); return; }
          throw new Error(res.msg || "조회 중 오류가 발생했습니다.");
        }
        const d = res.data || {}, err = d.errors || {};
        ["head", "delivery", "tax"].forEach(function (k) { showErr(k, err[k]); });
        fillHead(d.head);
        drawTable("tDelivery", COL_DELIVERY, d.delivery, "납품 내역이 없습니다.");
        drawTable("tTax",      COL_TAX,      d.tax,      "청구 내역이 없습니다.");
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
