<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>생산계획 대상</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@5.5.2/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">

<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  .mes-main { min-width:0; flex:1 1 0; }
  div:has(> .mes-main) > :not(.mes-main) { flex-shrink:0; }

  .card-head { display:flex; justify-content:space-between; align-items:center; margin-bottom:.5rem; }
  .card-head h6 { font-weight:700; font-size:.6rem; margin:0; }

  /* 검색 영역 */
  .search-box { background:#fff; border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,.08); padding:.6rem .8rem; margin-bottom:.6rem; }
  .search-box .form-control, .search-box .form-select { font-size:.85rem; padding-top:.2rem; padding-bottom:.2rem; }
  .search-box .lbl { font-size:.82rem; color:#495057; white-space:nowrap; font-weight:600; }
  .search-box .w-date { width:135px; }
  .search-box .w-sel  { width:105px; }
  .search-box .w-mid  { width:130px; }
  .search-box .w-long { width:200px; }
  .search-box .form-check-label { font-size:.85rem; }

  /* 표 */
  #grid { background:#fff; border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,.08); font-size:.82rem; }
  .tabulator .tabulator-header .tabulator-col { background:#e8eef8; color:#2f3e5c; }
  .tabulator .tabulator-header .tabulator-col-title { font-weight:700; text-align:center; }
  /* 열 제목 : 작은 글자 + 정렬 화살표 공간 최소화 (제목이 … 으로 잘리지 않게) */
  .tabulator .tabulator-header { font-size:.72rem; }
  .tabulator .tabulator-header .tabulator-col .tabulator-col-content { padding:4px 2px; }
  .tabulator .tabulator-header .tabulator-col.tabulator-sortable .tabulator-col-title { padding-right:9px; }
  .tabulator .tabulator-header .tabulator-col .tabulator-col-content .tabulator-col-sorter { right:1px; }
  .tabulator .tabulator-header .tabulator-col .tabulator-col-sorter .tabulator-arrow {
    border-left-width:3px; border-right-width:3px; border-bottom-width:4px; }
  .tabulator .tabulator-tableholder .tabulator-placeholder .tabulator-placeholder-contents { font-size:1rem; }
  .tabulator .tabulator-row .tabulator-cell { padding:1px 5px; line-height:1.25; }   /* 줄 간격 좁게 */
  .cell-prod { background:#ffd6e0; color:#c2185b; font-weight:700; border-radius:3px; padding:0 4px; }
  .st-wait   { color:#c2410c; font-weight:700; }
  .st-reject { color:#dc2626; font-weight:700; }
  .row-info  { font-size:.82rem; color:#6c757d; }
  .dday-red  { color:#dc2626; font-weight:700; }
  .chk-box   { font-size:1rem; line-height:1; }

  /* 조회 중 표시 */
  #loading {
    position:fixed; inset:0; z-index:2000; display:none;
    align-items:center; justify-content:center;
    background:rgba(255,255,255,.55); backdrop-filter:blur(1px);
  }
  #loading.show { display:flex; }
  #loading .box {
    background:#2f3e5c; color:#fff; border-radius:16px; padding:2.2rem 3.5rem;
    box-shadow:0 10px 30px rgba(0,0,0,.25); text-align:center;
  }
  #loading .spinner-border { width:4rem; height:4rem; border-width:.45rem; color:#ffd166; }
  #loading .msg { font-size:2rem; font-weight:800; margin-top:1rem; letter-spacing:2px; }
  #loading .sub { font-size:1rem; color:#c9d3e6; margin-top:.3rem; }
</style>
</head>
<body>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-3 mes-main">
    <div class="card-head">
      <h6>생산계획 대상</h6>
      <span class="row-info"><span id="rowInfo"></span></span>
    </div>

    <!-- ===== 검색 조건 ===== -->
    <div class="search-box">
      <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
        <span class="lbl">외주처</span>
        <input type="text" id="custName" class="form-control form-control-sm w-long" list="custList" placeholder="이름 입력 후 선택" autocomplete="off">
        <datalist id="custList"></datalist>

        <span class="lbl ms-2">공정</span>
        <input type="text" id="flow" class="form-control form-control-sm w-mid" title="입력하면 사업장은 오산으로 조회">

        <span class="lbl ms-2">등록월</span>
        <input type="month" id="ym" class="form-control form-control-sm w-date">

        <span class="lbl ms-2" title="생산계획 조회에서 쓰는 계획일(plandate) 기간">계획기간</span>
        <input type="date" id="pfdate" class="form-control form-control-sm w-date">
        <span>~</span>
        <input type="date" id="ptdate" class="form-control form-control-sm w-date">

        <span class="lbl ms-2">사업장</span>
        <select id="comp" class="form-select form-select-sm w-sel">
          <option>전체</option><option>서울</option><option>오산</option>
        </select>

        <div class="form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="force" checked><label class="form-check-label" for="force" title="앞 공정 완료 여부와 관계없이 조회">강제조회</label>
        </div>
      </div>

      <div class="d-flex flex-wrap align-items-center gap-2">
        <select id="keyKind" class="form-select form-select-sm w-sel">
          <option value="orderno">수주번호</option>
          <option value="jepmnm">제품명</option>
        </select>
        <input type="text" id="keyText" class="form-control form-control-sm w-long" title="입력하면 이 값으로만 조회 (다른 조건 무시)">

        <!-- 생산계획 조회 전용 -->
        <span class="plan-only lbl ms-3 text-warning-emphasis">[생산계획]</span>
        <span class="plan-only lbl">구분</span>
        <select id="proc1" class="plan-only form-select form-select-sm w-sel">
          <option>전체</option><option>생산</option><option>완료</option><option>중지</option>
        </select>
        <span class="plan-only lbl ms-2">생산라인</span>
        <select id="line" class="plan-only form-select form-select-sm w-sel">
          <option>전체</option><option>인쇄1호</option><option>인쇄2호</option><option>인쇄3호</option><option>스테이너만</option><option>처리안함</option>
        </select>
        <span class="plan-only lbl ms-2">주야</span>
        <select id="worktime" class="plan-only form-select form-select-sm" style="width:80px">
          <option>전체</option><option>주</option><option>야</option>
        </select>

        <div class="ms-auto d-flex gap-2">
          <button type="button" class="btn btn-sm btn-primary px-4" id="btnSearch">조 회</button>
          <button type="button" class="btn btn-sm btn-warning fw-bold" id="btnPlan">생산계획 조회</button>
          <button type="button" class="btn btn-sm btn-outline-success" id="btnExcel">엑셀</button>
        </div>
      </div>
    </div>

    <!-- ===== 목록 ===== -->
    <div id="grid"></div>
  </div>
</div>

<!-- 조회 중 표시 -->
<div id="loading">
  <div class="box">
    <div class="spinner-border" role="status"></div>
    <div class="msg">조회 중…</div>
    <div class="sub" id="loadingSub">잠시만 기다려 주세요</div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://unpkg.com/tabulator-tables@5.5.2/dist/js/tabulator.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<%@ include file="/WEB-INF/common/jepm_info_popup.jspf" %>

<script>
  const CTX    = '${pageContext.request.contextPath}';
  let grid = null, custMap = {};

  /* ---------- 공통 ---------- */
  function $(id) { return document.getElementById(id); }
  function ymdInput(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); }
  function num(v) { const n = Number(v); return isNaN(n) ? 0 : n; }

  function getJson(url) {
    return fetch(url, { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); location.href = CTX + "/sens.jsp"; }
          throw new Error(res.msg || "처리 중 오류가 발생했습니다.");
        }
        return res;
      });
  }

  /* yyyymmdd / yyyy-mm-dd / 날짜 → 2026-11-17 */
  function fmtDate(v) {
    if (v === null || v === undefined || v === "") return "";
    const s = String(v).replace(/\D/g, "");
    return s.length >= 8 ? s.substr(0, 4) + "-" + s.substr(4, 2) + "-" + s.substr(6, 2) : "";
  }
  /* 여러 날짜 (list 결과 "20261110,20261111") */
  function fmtDates(v) {
    if (!v) return "";
    return String(v).split(",").map(function (x) { return fmtDate(x.trim()); }).filter(Boolean).join(", ");
  }

  /* ---------- Tabulator 포매터 ---------- */
  const fDate  = function (c) { return fmtDate(c.getValue()); };
  const fDates = function (c) { return fmtDates(c.getValue()); };
  const fNum   = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR"); };
  const fNum2  = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); };
  const fZero  = function (c) { const v = num(c.getValue()); return v === 0 ? "" : v.toLocaleString("ko-KR"); };
  const fProd  = function (c) { const v = c.getValue() || ""; return v === "생산" ? '<span class="cell-prod">생산</span>' : v; };
  const fStat  = function (c) {
    const v = c.getValue() || "";
    if (v === "미확정" || v === "결재") return '<span class="st-wait">' + v + '</span>';
    if (v === "반려") return '<span class="st-reject">' + v + '</span>';
    return v;
  };
  const fCheck = function (c) { return c.getValue() === "Y" ? "☑" : "☐"; };
  const sumCalc = { bottomCalc: "sum", bottomCalcFormatter: function (c) { return num(c.getValue()).toLocaleString("ko-KR"); } };

  function numCol(title, field, extra) {
    return Object.assign({ title: title, field: field, hozAlign: "right", formatter: fNum, sorter: "number", width: 70 }, extra || {});
  }

  /* ---------- 컬럼 (PB 화면 순서) ---------- */
  const fYn = function (c) { return '<span class="chk-box">' + (c.getValue() === "Y" ? "☑" : "☐") + '</span>'; };   // 처리 (Y = 체크)

  const COLUMNS = [
    { title: "사업장",     field: "company",      width: 55, hozAlign: "center", frozen: true },
    { title: "외주처",     field: "flowcustname", width: 90, frozen: true },
    { title: "공정",       field: "flow",         width: 75, frozen: true },
    { title: "공정상세",   field: "flowname",     width: 140, tooltip: true },
    { title: "담당",       field: "sabunnm",      width: 60 },
    { title: "제품명",     field: "prodjepmnm",   width: 260, tooltip: true },
    { title: "납기일",     field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "등록일",     field: "prdate",       width: 85, hozAlign: "center", formatter: fDate },
    { title: "관리번호",   field: "orderno",      width: 85 },
    { title: "작업",       field: "papmkind",     width: 50, hozAlign: "center" },
    Object.assign({ title: "수주량",    field: "mst_qty",  hozAlign: "right", formatter: fNum,  sorter: "number", width: 70 }, sumCalc),
    { title: "정미+Loss",  field: "okloss",       width: 70, hozAlign: "right", formatter: fNum, sorter: "number" },
    { title: "처리",       field: "datachk",      width: 45, hozAlign: "center", formatter: fYn },
    { title: "생산라인",   field: "workflow",     width: 80 },
    { title: "주야",       field: "worktime",     width: 45, hozAlign: "center" },
    { title: "순서",       field: "jobseq",       width: 45, hozAlign: "right" },
    { title: "계획일",     field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    Object.assign({ title: "계획량",    field: "jisiqty",  hozAlign: "right", formatter: fNum,  sorter: "number", width: 70 }, sumCalc),
    Object.assign({ title: "지류출고",  field: "papertuip", hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    Object.assign({ title: "생산완료",  field: "prodqty",  hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    { title: "구분",       field: "proc1",        width: 50, hozAlign: "center" },
    { title: "생산일",     field: "procdate",     width: 85, hozAlign: "center", formatter: fDate },
    Object.assign({ title: "생산-통",   field: "dtl_qty",  hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    { title: "작업분류",   field: "workkind",     width: 70 },
    { title: "지질",       field: "paperjepmnm",  width: 130, tooltip: true },
    { title: "규격",       field: "paper_size",   width: 80 },
    { title: "재단규격",   field: "cutsize",      width: 80 },
    { title: "절",         field: "sizejul",      width: 45, hozAlign: "right", formatter: fNum2 },
    { title: "부",         field: "sizebu",       width: 45, hozAlign: "right", formatter: fNum2 },
    { title: "판전",       field: "prodcnt",      width: 45, hozAlign: "right" },
    { title: "판후",       field: "docnt",        width: 45, hozAlign: "right" },
    { title: "비고",       field: "planremk",     width: 200, tooltip: true }
  ];

  /* ---------- 조회 중 표시 ---------- */
  let loadingTimer = null;
  function showLoading(on) {
    const el = $("loading");
    clearInterval(loadingTimer);
    if (!on) { el.classList.remove("show"); return; }
    const start = Date.now();
    $("loadingSub").textContent = "잠시만 기다려 주세요";
    el.classList.add("show");
    loadingTimer = setInterval(function () {        // 오래 걸리면 경과 시간 표시
      const sec = Math.floor((Date.now() - start) / 1000);
      if (sec >= 3) $("loadingSub").textContent = sec + "초 경과… 잠시만 기다려 주세요";
    }, 1000);
  }

  /* ---------- 생산계획 컬럼 ---------- */
  const fDec1 = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR", { maximumFractionDigits: 1 }); };
  const PLAN_COLUMNS = [
    { title: "사업장",       field: "company",      width: 55, hozAlign: "center", frozen: true },
    { title: "외주처",       field: "flowcustname", width: 90, frozen: true },
    { title: "공정",         field: "flow",         width: 75, frozen: true },
    { title: "공정명",       field: "flowname",     width: 140, tooltip: true },
    { title: "담당",         field: "sabunnm",      width: 60 },
    { title: "매출처",       field: "custname",     width: 100 },
    { title: "제품명",       field: "prodjepmnm",   width: 240, tooltip: true },
    { title: "납기일",       field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "관리번호",     field: "orderno",      width: 85 },
    { title: "작업",         field: "papmkind",     width: 50, hozAlign: "center" },
    Object.assign({ title: "수주량",   field: "mst_qty",  hozAlign: "right", formatter: fNum, sorter: "number", width: 70 }, sumCalc),
    { title: "정미+Loss",    field: "okloss",       width: 70, hozAlign: "right", formatter: fNum, sorter: "number" },
    { title: "구분",         field: "proc1",        width: 50, hozAlign: "center" },
    { title: "현장입력",     field: "sgubun",       width: 65, hozAlign: "center" },
    { title: "생산라인",     field: "workflow",     width: 85 },
    { title: "주야",         field: "worktime",     width: 45, hozAlign: "center" },
    { title: "순서",         field: "jobseq",       width: 45, hozAlign: "right" },
    { title: "계획일",       field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    Object.assign({ title: "계획량",   field: "jisiqty",  hozAlign: "right", formatter: fNum,  sorter: "number", width: 70 }, sumCalc),
    { title: "생산일",       field: "procdate",     width: 85, hozAlign: "center", formatter: fDate },
    Object.assign({ title: "생산량",   field: "qty",      hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    Object.assign({ title: "생산완료", field: "prodqty",  hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    Object.assign({ title: "지류출고", field: "papertuip", hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    Object.assign({ title: "지류불량", field: "papmqty",  hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    Object.assign({ title: "생산불량", field: "realpapm", hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    Object.assign({ title: "재사용지", field: "yarigeqty", hozAlign: "right", formatter: fZero, sorter: "number", width: 70 }, sumCalc),
    { title: "실로스",       field: "sil_loss",     width: 60, hozAlign: "right", formatter: fZero },
    { title: "준비(분)",     field: "readyterm",    width: 60, hozAlign: "right", formatter: fZero },
    { title: "준비시작",     field: "readyfrom",    width: 70, hozAlign: "center" },
    { title: "준비종료",     field: "readyto",      width: 70, hozAlign: "center" },
    { title: "생산시작",     field: "ftime",        width: 70, hozAlign: "center" },
    { title: "생산종료",     field: "ttime",        width: 70, hozAlign: "center" },
    { title: "생산(분)",     field: "prodmin",      width: 60, hozAlign: "right", formatter: fZero, sorter: "number" },
    { title: "분당생산",     field: "minqty",       width: 65, hozAlign: "right", formatter: fDec1, sorter: "number" },
    { title: "시간당생산",   field: "hourqty",      width: 75, hozAlign: "right", formatter: fNum,  sorter: "number" },
    { title: "작업분류",     field: "workkind",     width: 70 },
    { title: "지질",         field: "paperjepmnm",  width: 130, tooltip: true },
    { title: "규격",         field: "paper_size",   width: 80 },
    { title: "절",           field: "sizejul",      width: 45, hozAlign: "right", formatter: fNum2 },
    { title: "부",           field: "sizebu",       width: 45, hozAlign: "right", formatter: fNum2 },
    { title: "전",           field: "prodcnt",      width: 40, hozAlign: "right" },
    { title: "후",           field: "docnt",        width: 40, hozAlign: "right" },
    { title: "최종실적접수", field: "lostprdate",   width: 110 },
    { title: "Cnt",          field: "mod_cnt",      width: 45, hozAlign: "right", formatter: fZero },
    { title: "비고",         field: "planremk",     width: 180, tooltip: true },
    { title: "생산비고",     field: "prodremk",     width: 180, tooltip: true }
  ];

  /* 생산계획 계산 칸 (PB 계산식과 같음) */
  function calcPlan(r) {
    r.okloss  = num(r.okper) + num(r.lossper);                       // 정미+Loss
    r.sgubun  = String(r.proc2 || "").trim() === "임시" ? "현장입력" : "";   // 현장입력
    r.prodmin = num(r.timeterm) - num(r.parttime);                    // 생산(분) = timeterm - parttime(0)
    r.minqty  = r.prodmin > 0 ? num(r.qty) / r.prodmin : 0;          // 분당생산
    r.hourqty = Math.round(r.minqty * 60);                            // 시간당생산
    return r;
  }

  /* 열 폭이 제목 글자보다 좁으면 제목이 보이도록 넓힘 */
  COLUMNS.concat(PLAN_COLUMNS).forEach(function (c) {
    const need = String(c.title).length * 11 + 18;
    if (!c.width || c.width < need) c.width = need;
  });

  /* ---------- 조회 ---------- */
  function params() {
    const p = new URLSearchParams();
    p.set("keyKind", $("keyKind").value);
    p.set("keyText", $("keyText").value.trim());
    p.set("custcd",  custMap[$("custName").value.trim()] || "");
    p.set("flow",    $("flow").value.trim());
    p.set("comp",    $("comp").value);
    p.set("force",   $("force").checked ? "Y" : "");
    // 등록월 → 등록월 + '01' ~ 등록월 + '31' (PB 와 같음)
    const ym = $("ym").value.replace("-", "");      // yyyyMM
    if (ym) {
      p.set("fdate", ym + "01");
      p.set("tdate", ym + "31");
    }
    return p;
  }

  /* 화면 계산 칸 (PB 계산식과 같음) */
  function calcRow(r) {
    r.okloss  = num(r.prodok) + num(r.prodloss);                                       // 정미+Loss
    r.cutsize = (r.cutwidth == null ? "" : num(r.cutwidth)) + "*" + (r.cutlength == null ? "" : num(r.cutlength));   // 재단규격
    return r;
  }

  function soloLabel() {
    return $("keyText").value.trim() ? "[" + $("keyKind").options[$("keyKind").selectedIndex].text + " 단독 검색] " : "";
  }

  /* 지금 표가 어떤 목록인지 : 'target' (생산계획 대상) / 'plan' (생산계획) */
  let mode = "target";
  function setMode(m) {
    if (mode === m) return;
    mode = m;
    grid.setColumns(m === "plan" ? PLAN_COLUMNS : COLUMNS);
    grid.clearData();
  }

  function planParams() {
    const p = new URLSearchParams();
    p.set("keyKind",  $("keyKind").value);
    p.set("keyText",  $("keyText").value.trim());
    p.set("custcd",   custMap[$("custName").value.trim()] || "");
    p.set("flow",     $("flow").value.trim());
    p.set("comp",     $("comp").value);
    p.set("force",    $("force").checked ? "Y" : "");
    p.set("proc1",    $("proc1").value);
    p.set("line",     $("line").value);
    p.set("worktime", $("worktime").value);
    p.set("pfdate",   $("pfdate").value.replace(/-/g, ""));
    p.set("ptdate",   $("ptdate").value.replace(/-/g, ""));
    return p;
  }

  /* 생산계획 조회 */
  function searchPlan() {
    if ($("custName").value.trim() && !custMap[$("custName").value.trim()]) {
      alert("외주처는 목록에서 선택하세요."); $("custName").focus(); return;
    }
    setMode("plan");
    const btn = $("btnPlan");
    btn.disabled = true;
    showLoading(true);
    getJson(CTX + "/mes35/plan?" + planParams().toString())
      .then(function (res) {
        showLoading(false);
        const rows = (res.data || []).map(calcPlan);
        grid.setData(rows);
        $("rowInfo").textContent = "[생산계획] " + soloLabel() + "조회 " + rows.length.toLocaleString("ko-KR") + "건";
        if (res.msg) alert(res.msg);
      })
      .catch(function (e) { showLoading(false); alert(e.message || e); })
      .then(function () { showLoading(false); btn.disabled = false; });
  }

  function search() {
    setMode("target");
    if ($("custName").value.trim() && !custMap[$("custName").value.trim()]) {
      alert("외주처는 목록에서 선택하세요."); $("custName").focus(); return;
    }
    const btn = $("btnSearch");
    btn.disabled = true; btn.textContent = "조회 중…";
    showLoading(true);
    getJson(CTX + "/mes35/list?" + params().toString())
      .then(function (res) {
        showLoading(false);
        const rows = (res.data || []).map(calcRow);
        grid.setData(rows);
        $("rowInfo").textContent = "[생산계획 대상] " + soloLabel() + "조회 " + rows.length.toLocaleString("ko-KR") + "건";
        if (res.msg) alert(res.msg);
      })
      .catch(function (e) { showLoading(false); alert(e.message || e); })
      .then(function () { showLoading(false); btn.disabled = false; btn.textContent = "조 회"; });
  }

  /* ---------- 외주처 (mes0201 것을 같이 씀) ---------- */
  let custTimer = null;
  function findCust() {
    const q = $("custName").value.trim();
    if (custMap[q]) return;                                  // 목록에서 고른 경우
    clearTimeout(custTimer);
    if (q.length < 1) return;
    custTimer = setTimeout(function () {
      getJson(CTX + "/mes0201/cust?q=" + encodeURIComponent(q))
        .then(function (res) {
          const dl = $("custList");
          dl.innerHTML = "";
          custMap = {};
          (res.data || []).forEach(function (c) {
            custMap[c.custname] = c.custcd;
            const o = document.createElement("option");
            o.value = c.custname;
            dl.appendChild(o);
          });
        })
        .catch(function (e) { console.log(e); });
    }, 250);
  }

  /* ---------- 시작 ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    $("ym").value = ymdInput(new Date()).substr(0, 7);      // 등록월 : 이번 달 (조회는 조회 버튼을 눌러야 함)

    grid = new Tabulator("#grid", {
      height: "calc(100vh - 235px)",
      layout: "fitData",
      columns: COLUMNS,
      selectable: 1,
      placeholder: "조회 버튼을 눌러 주세요.",
      columnDefaults: { headerSort: true, resizable: true, headerHozAlign: "center" }
    });

    $("btnSearch").addEventListener("click", search);
    $("btnPlan").addEventListener("click", searchPlan);

    // 계획기간 (생산계획 조회용) : 15일 전 ~ 오늘
    const pt = new Date(), pf = new Date(); pf.setDate(pf.getDate() - 15);
    $("pfdate").value = ymdInput(pf);
    $("ptdate").value = ymdInput(pt);
    $("btnExcel").addEventListener("click", function () {
      if (!grid.getDataCount()) { alert("조회된 자료가 없습니다."); return; }
      const nm = mode === "plan" ? "생산계획" : "생산계획대상";
      grid.download("xlsx", nm + "_" + ymdInput(new Date()).replace(/-/g, "") + ".xlsx", { sheetName: nm });
    });

    // 입력칸에서 ENTER = 조회
    ["keyText", "flow"].forEach(function (id) {
      $(id).addEventListener("keydown", function (e) { if (e.key === "Enter") (mode === "plan" ? searchPlan : search)(); });
    });

    $("custName").addEventListener("input", findCust);
    $("custName").addEventListener("change", findCust);

  });
</script>

</body>
</html>
