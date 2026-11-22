<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>생산계획 (후가공)</title>
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
  #flowBox .form-check-input { margin-right:2px; }

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
      <h6>생산계획 (후가공)</h6>
      <span class="row-info"><span id="rowInfo"></span></span>
    </div>

    <!-- ===== 검색 조건 ===== -->
    <div class="search-box">
      <div class="d-flex flex-wrap align-items-center gap-2 mb-2">
        <span class="lbl">공정</span>
        <div class="d-flex flex-wrap align-items-center gap-2" id="flowBox">
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="라미" checked> 라미</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="박"> 박</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="실크"> 실크</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="톰슨"> 톰슨</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="수작업"> 수작업</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="접착"> 접착</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="지함"> 지함</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="용역작업"> 용역작업</label>
          <label class="form-check-label fw-bold"><input class="form-check-input" type="radio" name="flow" value="스테이너만"> 스테이너만</label>
        </div>

        <!-- 생산계획 조회 전용 -->
        <span class="lbl ms-3 text-warning-emphasis">[생산계획]</span>
        <span class="lbl">구분</span>
        <select id="proc1" class="form-select form-select-sm w-sel">
          <option>전체</option><option>생산</option><option>완료</option><option>중지</option>
        </select>
        <span class="lbl ms-2">생산라인</span>
        <select id="line" class="form-select form-select-sm w-sel"></select>
        <span class="lbl ms-2">주야</span>
        <select id="worktime" class="form-select form-select-sm" style="width:80px">
          <option>전체</option><option>주</option><option>야</option>
        </select>
        <span class="lbl ms-2">계획일</span>
        <input type="date" id="pfdate" class="form-control form-control-sm w-date">
        <span>~</span>
        <input type="date" id="ptdate" class="form-control form-control-sm w-date">
      </div>

      <div class="d-flex flex-wrap align-items-center gap-2">
        <span class="lbl">수주번호</span>
        <input type="text" id="keyText" class="form-control form-control-sm w-mid" title="입력하면 이 값으로만 조회 (다른 조건 무시)">

        <span class="lbl ms-2">등록월</span>
        <input type="month" id="ym" class="form-control form-control-sm w-date">

        <!-- 외주처 · 사업장 : 라미/박/실크/톰슨/수작업/스테이너만 조회 + 모든 공정의 생산계획 조회 -->
        <span class="out-only lbl ms-2">외주처</span>
        <input type="text" id="custName" class="out-only form-control form-control-sm w-long" list="custList" placeholder="이름 입력 후 선택" autocomplete="off">
        <datalist id="custList"></datalist>
        <span class="out-only lbl ms-2">사업장</span>
        <select id="comp" class="out-only form-select form-select-sm w-sel">
          <option>전체</option><option>서울</option><option>오산</option>
        </select>
        <div class="force-only form-check form-check-inline ms-2 mb-0">
          <input class="form-check-input" type="checkbox" id="force" checked>
          <label class="form-check-label" for="force" title="앞 공정 완료 여부와 관계없이 조회">강제조회</label>
        </div>

        <span class="ms-2 small text-danger fw-bold">더블클릭 : 자세히</span>

        <div class="ms-auto d-flex gap-2">
          <button type="button" class="btn btn-sm btn-primary px-4" id="btnSearch">조 회</button>
          <button type="button" class="btn btn-sm btn-warning fw-bold" id="btnPlan">생산계획</button>
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
  const MY_SABUN = '<c:out value="${sessionScope.USER.SABUN}"/>';      // 세션 사번
  const MY_NAME  = '<c:out value="${sessionScope.USER.NAME}"/>';       // 세션 이름 (본인 버튼)
  let grid = null;

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
  const fNum   = function (c) { const v = c.getValue(); return (v === null || v === undefined || v === "") ? "" : num(v).toLocaleString("ko-KR"); };
  const fProc  = function (c) { const v = c.getValue() || ""; return v === "생산" ? '<span class="cell-prod">생산</span>' : v; };
  const fCheck = function (c) { return c.getValue() === "Y" ? "☑" : "☐"; };
  const sumCalc = { bottomCalc: "sum", bottomCalcFormatter: function (c) { return num(c.getValue()).toLocaleString("ko-KR"); } };

  function numCol(title, field, extra) {
    return Object.assign({ title: title, field: field, hozAlign: "right", formatter: fNum, sorter: "number", width: 70 }, extra || {});
  }

  /* 더블클릭 : 수주 조회 팝업 (mes33 과 같음, mes3205_jepm_info 를 같이 사용, jpno 기준) */
  function openDetail(r) {
    const jpno = (mode !== "plan" && flowValue() === "용역작업") ? r.mstjpno : r.jpno;
    if (!jpno) return;                            // 주차수당 줄은 수주가 없음
    openJepmOrderView(jpno);
  }

  /* ---------- 컬럼 (접착 / 지함) ---------- */
  const COLUMNS = [
    { title: "사업장",     field: "company",      width: 50, hozAlign: "center", frozen: true },
    { title: "외주처",     field: "flowcustname", width: 90, frozen: true },
    { title: "담당",       field: "sabunnm",      width: 65 },
    { title: "완제품",     field: "goodjepmnm",   width: 280, tooltip: true },
    { title: "납기일",     field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "등록일",     field: "prdate",       width: 85, hozAlign: "center", formatter: fDate },
    { title: "관리번호",   field: "orderno",      width: 80 },
    numCol("수주량",   "totqty",  Object.assign({ width: 75 }, sumCalc)),
    { title: "처리",       field: "datachk",      width: 45, hozAlign: "center", formatter: fCheck, headerSort: false },
    { title: "생산라인",   field: "workflow",     width: 80 },
    { title: "주야",       field: "worktime",     width: 45, hozAlign: "center" },
    numCol("순서",     "jobseq",  { width: 45 }),
    { title: "계획일",     field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("계획량",   "jisiqty", Object.assign({ width: 75 }, sumCalc)),
    numCol("생산완료", "prodqty", Object.assign({ width: 75 }, sumCalc)),
    { title: "구분",       field: "proc1",        width: 50, hozAlign: "center", formatter: fProc },
    { title: "접착",       field: "stick",        width: 60 },
    { title: "비고",       field: "planremk",     width: 200, tooltip: true }
  ];

  /* ---------- 컬럼 (라미 / 박 / 실크 / 톰슨 / 수작업 / 스테이너만) ---------- */
  const OUT_FLOWS = ["라미", "박", "실크", "톰슨", "수작업", "스테이너만"];
  const OUT_COLUMNS = [
    { title: "사업장",     field: "company",      width: 50, hozAlign: "center", frozen: true },
    { title: "외주처",     field: "flowcustname", width: 90, frozen: true },
    { title: "매출처",     field: "custname",     width: 110 },
    { title: "공정",       field: "flow",         width: 80 },
    { title: "공정상세",   field: "flowname",     width: 130, tooltip: true },
    { title: "담당",       field: "sabunnm",      width: 60 },
    { title: "제품명",     field: "prodjepmnm",   width: 260, tooltip: true },
    { title: "납기일",     field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "등록일",     field: "prdate",       width: 85, hozAlign: "center", formatter: fDate },
    { title: "관리번호",   field: "orderno",      width: 80 },
    { title: "작업",       field: "papmkind",     width: 50, hozAlign: "center", formatter: fProc },
    numCol("수주량",   "mst_qty", Object.assign({ width: 75 }, sumCalc)),
    { title: "처리",       field: "datachk",      width: 45, hozAlign: "center", formatter: fCheck, headerSort: false },
    { title: "생산라인",   field: "workflow",     width: 80 },
    { title: "주야",       field: "worktime",     width: 45, hozAlign: "center" },
    numCol("순서",     "jobseq",  { width: 45 }),
    { title: "계획일",     field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("계획량",   "jisiqty", Object.assign({ width: 75 }, sumCalc)),
    numCol("지류출고", "papertuip", { width: 75 }),
    numCol("생산완료", "prodqty", Object.assign({ width: 75 }, sumCalc)),
    { title: "구분",       field: "proc1",        width: 50, hozAlign: "center", formatter: fProc },
    { title: "생산일",     field: "procdate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("생산량",   "dtl_qty", Object.assign({ width: 75 }, sumCalc)),
    { title: "작업분류",   field: "workkind",     width: 80 },
    { title: "재단규격",   field: "cutsize",      width: 80 },          // cutwidth*cutlength
    { title: "비고",       field: "planremk",     width: 200, tooltip: true }
  ];

  /* ---------- 컬럼 (용역작업) ---------- */
  /* 1230 / 12:30 / 시각 → 12:30 */
  function fmtTime(v) {
    if (v === null || v === undefined || v === "") return "";
    const m = String(v).match(/(\d{1,2}):?(\d{2})(?::\d{2}(?:\.\d+)?)?\s*$/);
    return m ? m[1].padStart(2, "0") + ":" + m[2] : String(v);
  }
  const fTime = function (c) { return fmtTime(c.getValue()); };
  const f2    = function (c) { const v = c.getValue(); return (v === null || v === "") ? "" : num(v).toLocaleString("ko-KR", { maximumFractionDigits: 2 }); };

  const YONG_COLUMNS = [
    { title: "날짜",       field: "cdate",        width: 85, hozAlign: "center", formatter: fDate, frozen: true },
    { title: "작업명",     field: "workflow",     width: 90, frozen: true },
    { title: "계획지시자", field: "proder",       width: 75 },
    { title: "원코드",     field: "wonjepmcd",    width: 80 },
    { title: "관리번호",   field: "orderno",      width: 80 },
    { title: "제품명",     field: "jepmnm",       width: 260, tooltip: true },
    { title: "작업품목",   field: "prodremk",     width: 150, tooltip: true },
    numCol("계획수량", "jisiqty",  Object.assign({ width: 75 }, sumCalc)),
    numCol("정규직",   "length",   { width: 55 }),
    numCol("용역",     "restlength", { width: 50 }),
    { title: "시작",       field: "readyfrom",    width: 55, hozAlign: "center", formatter: fTime },
    { title: "마침",       field: "readyto",      width: 55, hozAlign: "center", formatter: fTime },
    numCol("근무시간(분)", "proctime", Object.assign({ width: 85 }, sumCalc)),
    numCol("생산실적", "qty",      Object.assign({ width: 75 }, sumCalc)),
    numCol("분당 작업수당", "perqty", { width: 90, formatter: f2 }),
    { title: "비고",       field: "remk",         width: 200, tooltip: true }
  ];

  /* 근무시간(분) : PB 계산식 그대로 (810 = 13:30, 점심 60분 빼기) */
  function workMin(r) {
    const tt = num(r.timeterm), rt = num(r.readyterm);
    if (tt - rt <= 0) return 0;
    if (rt >= 810)    return tt - rt;
    if (tt < 810)     return tt - rt;
    return tt - rt - 60;
  }

  /* 열 폭이 제목 글자보다 좁으면 제목이 보이도록 넓힘 */
  COLUMNS.concat(YONG_COLUMNS, OUT_COLUMNS).forEach(function (c) {
    const need = String(c.title).length * 11 + 18;
    if (!c.width || c.width < need) c.width = need;
  });

  /* ---------- 조회 중 표시 ---------- */
  let loadingTimer = null;
  function showLoading(on) {
    const el = $("loading");
    clearInterval(loadingTimer);
    if (!on) { el.classList.remove("show"); return; }
    const start = Date.now();
    $("loadingSub").textContent = "잠시만 기다려 주세요";
    el.classList.add("show");
    loadingTimer = setInterval(function () {
      const sec = Math.floor((Date.now() - start) / 1000);
      if (sec >= 3) $("loadingSub").textContent = sec + "초 경과… 잠시만 기다려 주세요";
    }, 1000);
  }

  /* ---------- 조회 ---------- */
  function flowValue() {
    const r = document.querySelector('input[name="flow"]:checked');
    return r ? r.value : "";
  }

  /* ---------- 생산계획 컬럼 (모든 공정 같음) ---------- */
  const fAvg2 = function (c) { return num(c.getValue()).toLocaleString("ko-KR", { maximumFractionDigits: 2 }); };
  const PLAN_COLUMNS = [
    { title: "사업장",     field: "company",      width: 50, hozAlign: "center", frozen: true },
    { title: "담당",       field: "sabunnm",      width: 60, frozen: true },
    { title: "매출처",     field: "custname",     width: 110 },
    { title: "완제품",     field: "goodjepmnm",   width: 260, tooltip: true },
    { title: "납품예정",   field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "등록일",     field: "prdate",       width: 85, hozAlign: "center", formatter: fDate },
    { title: "관리번호",   field: "orderno",      width: 80 },
    numCol("수주량",   "totqty",  { width: 75 }),
    { title: "처리",       field: "datachk",      width: 45, hozAlign: "center", formatter: fCheck, headerSort: false },
    { title: "접착",       field: "stick",        width: 60 },
    { title: "생산라인",   field: "workflow",     width: 90 },
    { title: "주야",       field: "worktime",     width: 45, hozAlign: "center" },
    numCol("순서",     "jobseq",  { width: 45 }),
    numCol("Cnt",      "mod_cnt", { width: 45 }),
    { title: "계획일",     field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("계획량",   "jisiqty", Object.assign({ width: 75 }, sumCalc)),
    numCol("생산완료", "prodqty", Object.assign({ width: 75 }, sumCalc)),
    { title: "현장생산",   field: "sgubun",       width: 70, hozAlign: "center" },
    { title: "구분",       field: "proc1",        width: 50, hozAlign: "center", formatter: fProc },
    { title: "생산일",     field: "procdate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("분당생산",   "minqty",  { width: 70, formatter: f2, bottomCalc: "avg", bottomCalcFormatter: fAvg2 }),
    numCol("시간당 생산", "hourqty", { width: 80, formatter: f2, bottomCalc: "avg", bottomCalcFormatter: fAvg2 }),
    numCol("생산량",   "qty",     Object.assign({ width: 75 }, sumCalc)),
    numCol("불량",     "papmqty", Object.assign({ width: 60 }, sumCalc)),
    numCol("재사용지", "yarigeqty", { width: 70 }),
    numCol("준비(분)", "readyterm", { width: 65 }),
    numCol("생산(분)", "timeterm",  { width: 65 }),
    { title: "비고",       field: "planremk",     width: 180, tooltip: true },
    { title: "생산비고",   field: "prodremk",     width: 150, tooltip: true },
    { title: "준비시작",   field: "readyfrom",    width: 65, hozAlign: "center", formatter: fTime },
    { title: "준비종료",   field: "readyto",      width: 65, hozAlign: "center", formatter: fTime },
    { title: "생산시작",   field: "ftime",        width: 65, hozAlign: "center", formatter: fTime },
    { title: "생산종료",   field: "ttime",        width: 65, hozAlign: "center", formatter: fTime }
  ];
  /* ---------- 생산계획 컬럼 (접착 / 지함 이 아닐 때 : 지류 기준) ---------- */
  const PLAN2_COLUMNS = [
    { title: "사업장",     field: "company",      width: 50, hozAlign: "center", frozen: true },
    { title: "외주처",     field: "flowcustname", width: 90, frozen: true },
    { title: "매출처",     field: "custname",     width: 110 },
    { title: "공정",       field: "flow",         width: 80 },
    { title: "공정상세",   field: "flowname",     width: 130, tooltip: true },
    { title: "담당",       field: "sabunnm",      width: 60 },
    { title: "제품명",     field: "prodjepmnm",   width: 260, tooltip: true },
    { title: "납품예정",   field: "deliverydate", width: 85, hozAlign: "center", formatter: fDate },
    { title: "관리번호",   field: "orderno",      width: 80 },
    { title: "작업",       field: "papmkind",     width: 50, hozAlign: "center", formatter: fProc },
    numCol("수주량",   "mst_qty", { width: 75 }),
    { title: "처리",       field: "datachk",      width: 45, hozAlign: "center", formatter: fCheck, headerSort: false },
    { title: "이력",       field: "plandetail",   width: 45, hozAlign: "center", formatter: fCheck, headerSort: false },
    { title: "생산라인",   field: "workflow",     width: 90 },
    { title: "주야",       field: "worktime",     width: 45, hozAlign: "center" },
    numCol("순서",     "jobseq",  { width: 45 }),
    numCol("Cnt",      "mod_cnt", { width: 45 }),
    { title: "계획일",     field: "plandate",     width: 85, hozAlign: "center", formatter: fDate },
    numCol("계획량",   "jisiqty", Object.assign({ width: 75 }, sumCalc)),
    numCol("생산완료", "prodqty", Object.assign({ width: 75 }, sumCalc)),
    { title: "현장입력",   field: "sgubun",       width: 70, hozAlign: "center" },
    { title: "구분",       field: "proc1",        width: 50, hozAlign: "center", formatter: fProc },
    { title: "지질",       field: "paperjepmnm",  width: 130, tooltip: true },
    { title: "규격",       field: "size",         width: 80 },
    { title: "작업분류",   field: "workkind",     width: 80 },
    { title: "재단규격",   field: "cutsize",      width: 80 },
    numCol("절",       "sizejul",  { width: 45, formatter: f2 }),
    numCol("부",       "sizebu",   { width: 45, formatter: f2 }),
    numCol("전",       "prodcnt",  { width: 40 }),
    numCol("후",       "docnt",    { width: 40 }),
    numCol("정미+Loss", "okloss",  Object.assign({ width: 80 }, sumCalc)),
    numCol("지류출고", "papertuip", { width: 75 }),
    numCol("지류잔량", "paperprodtuip", { width: 75 }),
    numCol("생산량",   "qty",      Object.assign({ width: 75 }, sumCalc)),
    numCol("지류불량", "papmqty",  Object.assign({ width: 70 }, sumCalc)),
    numCol("생산불량", "realpapm", Object.assign({ width: 70 }, sumCalc)),
    numCol("실로스",   "sil_loss", { width: 60 }),
    numCol("재사용지", "yarigeqty", { width: 70 }),
    numCol("분당생산",   "minqty",  { width: 70, formatter: f2, bottomCalc: "avg", bottomCalcFormatter: fAvg2 }),
    numCol("시간당생산", "hourqty", { width: 80, formatter: f2, bottomCalc: "avg", bottomCalcFormatter: fAvg2 }),
    numCol("준비(분)", "readyterm", { width: 65 }),
    numCol("생산(분)", "timeterm",  { width: 65 }),
    { title: "준비시작",   field: "readyfrom",    width: 65, hozAlign: "center", formatter: fTime },
    { title: "준비종료",   field: "readyto",      width: 65, hozAlign: "center", formatter: fTime },
    { title: "생산시작",   field: "ftime",        width: 65, hozAlign: "center", formatter: fTime },
    { title: "생산종료",   field: "ttime",        width: 65, hozAlign: "center", formatter: fTime },
    { title: "비고",       field: "planremk",     width: 180, tooltip: true },
    { title: "생산비고",   field: "prodremk",     width: 150, tooltip: true },
    { title: "최종실적접수일", field: "lostprdate", width: 110 }
  ];

  PLAN_COLUMNS.concat(PLAN2_COLUMNS).forEach(function (c) {
    const need = String(c.title).length * 11 + 18;
    if (!c.width || c.width < need) c.width = need;
  });

  /* 공정별 생산라인 목록 (PB ddlb_2) */
  const LINES = {
    "라미":       ["전체", "라미", "라미2", "스테이너만", "처리안함"],
    "박":         ["전체", "박", "박(닛코)", "박(하이델1)", "박(하이델2)", "처리안함"],
    "실크":       ["전체", "실크", "처리안함"],
    "톰슨":       ["전체", "톰슨1", "톰슨2", "스가노", "처리안함"],
    "수작업":     ["수작업", "처리안함"],
    "접착":       ["전체", "접착", "접착2", "처리안함"],
    "지함":       ["전체", "지함1", "지함2", "지함3", "지함4", "수동지함", "처리안함"],
    "용역작업":   ["용역", "처리안함"],
    "스테이너만": ["전체", "스테이너만", "처리안함"]
  };
  function fillLines() {
    const sel = $("line");
    sel.innerHTML = "";
    (LINES[flowValue()] || ["전체"]).forEach(function (v) {
      const o = document.createElement("option"); o.textContent = v; sel.appendChild(o);
    });
  }

  /* 공정 · 조회종류에 맞는 컬럼 + 조건 보이기 */
  let mode = "target";          // target = [조 회], plan = [생산계획]
  function isOut() { return OUT_FLOWS.indexOf(flowValue()) >= 0; }
  function isStick() { const f = flowValue(); return f === "접착" || f === "지함"; }
  function columnsFor() {
    if (mode === "plan") return isStick() ? PLAN_COLUMNS : PLAN2_COLUMNS;
    const f = flowValue();
    return f === "용역작업" ? YONG_COLUMNS : (isOut() ? OUT_COLUMNS : COLUMNS);
  }
  function applyFlow() {
    const showOut = isOut() || mode === "plan";
    document.querySelectorAll(".out-only").forEach(function (el) { el.style.display = showOut ? "" : "none"; });
    document.querySelectorAll(".force-only").forEach(function (el) { el.style.display = (isOut() && mode !== "plan") ? "" : "none"; });
  }
  function setMode(m) {
    if (m === mode) return;
    mode = m;
    grid.clearData();
    grid.setColumns(columnsFor());
    applyFlow();
  }

  /* 외주처 찾기 */
  let custMap = {}, custTimer = null;
  function findCust() {
    const q = $("custName").value.trim();
    if (custMap[q]) return;
    clearTimeout(custTimer);
    if (!q) return;
    custTimer = setTimeout(function () {
      getJson(CTX + "/mes0201/cust?q=" + encodeURIComponent(q))
        .then(function (res) {
          const dl = $("custList");
          dl.innerHTML = ""; custMap = {};
          (res.data || []).forEach(function (c) {
            custMap[c.custname] = c.custcd;
            const o = document.createElement("option"); o.value = c.custname; dl.appendChild(o);
          });
        })
        .catch(function (e) { console.log(e); });
    }, 250);
  }

  function params() {
    const p = new URLSearchParams();
    p.set("flow",     flowValue());
    p.set("custcd",   custMap[$("custName").value.trim()] || "");
    p.set("comp",     $("comp").value);
    p.set("force",    $("force").checked ? "Y" : "N");
    p.set("keyText",  $("keyText").value.trim());
    p.set("ym",       $("ym").value.replace(/-/g, ""));
    p.set("proc1",    $("proc1").value);
    p.set("line",     $("line").value);
    p.set("worktime", $("worktime").value);
    p.set("pfdate",   $("pfdate").value.replace(/-/g, ""));
    p.set("ptdate",   $("ptdate").value.replace(/-/g, ""));
    return p;
  }

  /* 생산계획 계산 : 현장생산, 분당 / 시간당 생산 */
  function calcPlan(r) {
    r.sgubun = (r.proc2 === "임시") ? "현장입력" : "";
    const min = num(r.timeterm) - num(r.parttime);
    r.minqty  = min > 0 ? num(r.qty) / min : 0;          // 분당생산 = qty / (timeterm - parttime)
    r.hourqty = r.minqty * 60;                           // 시간당생산 = 분당생산 * 60
    if (!isStick()) {
      r.okloss  = num(r.okper) + num(r.lossper);         // 정미+Loss
      r.cutsize = (r.cutwidth == null ? "" : num(r.cutwidth)) + "*" + (r.cutlength == null ? "" : num(r.cutlength));
    }
    return r;
  }

  function search(m) {
    setMode(m === "plan" ? "plan" : "target");
    if ((isOut() || mode === "plan") && $("custName").value.trim() && !custMap[$("custName").value.trim()]) {
      alert("외주처는 목록에서 선택하세요."); $("custName").focus(); return;
    }
    const btn = $(mode === "plan" ? "btnPlan" : "btnSearch"), btnText = btn.textContent;
    btn.disabled = true; btn.textContent = "조회 중…";
    showLoading(true);
    getJson(CTX + (mode === "plan" ? "/mes36/plan?" : "/mes36/list?") + params().toString())
      .then(function (res) {
        showLoading(false);
        const rows = (res.data || []).map(function (r) {
          if (mode === "plan") return calcPlan(r);
          if (isOut()) r.cutsize = (r.cutwidth == null ? "" : num(r.cutwidth)) + "*" + (r.cutlength == null ? "" : num(r.cutlength));
          if (flowValue() === "용역작업") {
            r.proctime = workMin(r);
            r.perqty   = r.proctime > 0 ? num(r.qty) / r.proctime : 0;    // 분당 작업수당 = qty / 근무시간
          }
          return r;
        });
        grid.setData(rows);
        const solo = $("keyText").value.trim() && (mode === "plan" || flowValue() !== "용역작업");
        $("rowInfo").textContent = (mode === "plan" ? "[생산계획] " : "[조 회] ") + "[" + flowValue() + "] " +
          (solo ? "[수주번호 단독 검색] " : "") +
          "조회 " + rows.length.toLocaleString("ko-KR") + "건";
        if (res.msg) alert(res.msg);
      })
      .catch(function (e) { showLoading(false); alert(e.message || e); })
      .then(function () { showLoading(false); btn.disabled = false; btn.textContent = btnText; });
  }

  /* ---------- 시작 ---------- */
  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    const t = new Date();
    $("ym").value = t.getFullYear() + "-" + String(t.getMonth() + 1).padStart(2, "0");   // 등록월 : 이번 달
    $("pfdate").value = ymdInput(t);                                                       // 계획일 : 오늘 ~ 오늘
    $("ptdate").value = ymdInput(t);
    fillLines();

    grid = new Tabulator("#grid", {
      height: "calc(100vh - 235px)",
      layout: "fitData",
      columns: columnsFor(),
      selectable: 1,
      placeholder: "조회 버튼을 눌러 주세요.",
      columnDefaults: { headerSort: true, resizable: true, headerHozAlign: "center" }
    });
    grid.on("rowDblClick", function (e, row) { openDetail(row.getData()); });   // 자세히

    $("btnSearch").addEventListener("click", function () { search("target"); });
    $("btnPlan").addEventListener("click", function () { search("plan"); });
    $("btnExcel").addEventListener("click", function () {
      if (!grid.getDataCount()) { alert("조회된 자료가 없습니다."); return; }
      const nm = (mode === "plan" ? "생산계획조회_" : "생산계획대상_") + flowValue();
      grid.download("xlsx", nm + "_" + ymdInput(new Date()).replace(/-/g, "") + ".xlsx", { sheetName: nm });
    });

    $("keyText").addEventListener("keydown", function (e) { if (e.key === "Enter") search(mode); });
    $("custName").addEventListener("input", findCust);
    applyFlow();

    // 공정을 바꾸면 목록 비움 (다른 공정 자료와 섞이지 않게) + 생산라인 목록 바꿈
    document.querySelectorAll('input[name="flow"]').forEach(function (r) {
      r.addEventListener("change", function () {
        grid.clearData(); $("rowInfo").textContent = "";
        grid.setColumns(columnsFor());
        fillLines();
        applyFlow();
      });
    });
  });
</script>

</body>
</html>
