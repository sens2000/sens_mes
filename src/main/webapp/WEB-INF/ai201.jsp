<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>입고</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== 입고 (ai201) ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
  }
  .ip { font-size: 14px; flex: 1 1 0; min-width: 0; }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .sub { margin-left: auto; font-size: 12px; opacity: .9; }
  .card-head .sub b { color: var(--accent); }
  .hint { font-size: 11px; color: var(--muted); }
  kbd { font-size: 10px; padding: 1px 4px; }

  /* 거래처 */
  .cust-search { position: relative; padding: 12px 16px; border-bottom: 1px solid var(--line); }
  .drop { position: absolute; z-index: 20; left: 16px; right: 16px; top: calc(100% - 6px); max-height: 280px; overflow-y: auto;
          background: #fff; border: 1px solid #ccd; border-radius: 6px; box-shadow: 0 6px 16px rgba(0,0,0,.14); }
  .drop button { display: grid; gap: 8px; width: 100%; border: 0; background: none; padding: 8px 12px; text-align: left; font-size: 13px; }
  .drop button:hover { background: var(--navy-soft); }
  .drop .r { text-align: right; }
  #custResult button { grid-template-columns: 70px 1fr 130px 130px 110px; }
  #prodResult button { grid-template-columns: 130px 1fr 90px 90px; }
  .cust-info { display: grid; grid-template-columns: 160px repeat(4, minmax(0, 1fr)) 160px; }
  .cust-info .in-date { font-weight: 700; margin-top: 1px; }
  .cust-info > div { padding: 9px 16px; border-right: 1px solid var(--line); min-width: 0; }
  .cust-info > div:last-child { border-right: 0; }
  .cust-info .k { font-size: 11px; color: var(--muted); }
  .cust-info .v { font-weight: 700; font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cust-info .v.mibul { text-align: right; color: #d9534f; font-size: 17px; }
  .cust-empty { padding: 18px 16px; text-align: center; color: var(--muted); }

  /* 입고내역 */
  .toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; padding: 10px 16px; border-bottom: 1px solid var(--line); }
  .tabulator { font-size: 13px; border: none; max-width: 100%; }
  .tabulator .tabulator-header .tabulator-col { background: var(--navy-soft); }
  .tabulator .tabulator-cell { padding: 6px 6px; }
  .tabulator .tabulator-col .tabulator-col-content { padding: 7px 6px; }
  .btn-dtl { padding: 0 7px; font-size: 12px; line-height: 20px; }
  .loading-mask { position: absolute; inset: 0; z-index: 30; background: rgba(255,255,255,.65);
                  display: flex; align-items: center; justify-content: center; }
  .loading-mask.d-none { display: none !important; }
  .loading-box { background: #fff; border: 1px solid var(--line); border-radius: 8px; padding: 10px 18px;
                 box-shadow: 0 4px 14px rgba(0,0,0,.12); font-size: 14px; color: var(--navy); font-weight: 600; }

  /* 입고 입력 */
  .in-grid { display: grid; grid-template-columns: minmax(0, 1fr) 320px; gap: 16px; }
  @media (max-width: 1200px) { .in-grid { grid-template-columns: 1fr; } }
  .item-input { position: relative; display: flex; gap: 8px; padding: 10px 16px; border-bottom: 1px solid var(--line); }
  .line-wrap { overflow: auto; }
  table.lines { width: 100%; border-collapse: collapse; font-size: 14px; }
  table.lines th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); border-bottom: 2px solid #c9d3e3;
                   padding: 7px 6px; font-weight: 700; text-align: center; white-space: nowrap; }
  table.lines td { padding: 5px 6px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  table.lines tr.sel td { background: #fff8e1; }
  table.lines .r, table.lines th.r { text-align: right; }
  table.lines .c { text-align: center; }
  table.lines .brand { color: var(--muted); font-size: 12px; margin-right: 4px; }
  table.lines input { border: 1px solid transparent; background: transparent; padding: 3px 5px; border-radius: 4px; width: 100%; }
  table.lines input:hover, table.lines input:focus { border-color: #b8c3d4; background: #fff; outline: none; }
  table.lines input.r { text-align: right; }
  .src { display: block; font-size: 10px; color: var(--muted); text-align: right; line-height: 1; }
  .src.last { color: #2f9e6e; }
  .pct { display: flex; align-items: center; gap: 2px; }
  .pct span { color: var(--muted); font-size: 12px; }
  .qty { display: inline-flex; align-items: center; gap: 2px; }
  .qty button { width: 24px; height: 24px; padding: 0; line-height: 1; border: 1px solid #c5ccd8; background: #fff; border-radius: 4px; }
  .qty input { width: 46px !important; text-align: center; }
  .line-empty td { text-align: center; color: var(--muted); padding: 34px 0 !important; border-bottom: 0 !important; }
  .line-foot { display: flex; gap: 18px; padding: 9px 16px; border-top: 2px solid #c9d3e3; background: #f7f9fc; font-size: 13px; }
  .line-foot b { font-size: 15px; }
  .line-foot .ms-auto { margin-left: auto; }

  /* 지급 */
  .pay { padding: 12px 16px; }
  .pay-row { display: flex; justify-content: space-between; align-items: center; padding: 3px 0; }
  .pay-row .k { color: var(--muted); }
  .pay-row .v { font-weight: 700; font-size: 16px; }
  .pay-row input { width: 140px; text-align: right; font-weight: 700; }
  .pay-total { margin: 6px -16px; padding: 8px 16px; background: var(--navy); color: #fff; display: flex; justify-content: space-between; align-items: baseline; }
  .pay-total .v { font-size: 24px; font-weight: 800; color: var(--accent); }
  .pay-btns { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; }
  .pay-btns .btn { padding: 8px 0; font-weight: 700; }
  .pay-btns .full { grid-column: span 2; padding: 10px 0; font-size: 15px; }
  .card-box.editing { box-shadow: 0 0 0 2px #f0ad4e; }
  #histTable .tabulator-row { cursor: pointer; }

  /* 탭 */
  .ip-tabs { margin-bottom: 12px; border-bottom: 1px solid #d5dbe5; }
  .ip-tabs .nav-link { color: #555; }
  .ip-tabs .nav-link.active { color: var(--navy); font-weight: 700; background: #fff; }

  /* 입고조회 */
  .list-grid { display: grid; grid-template-columns: minmax(0, 1fr) 400px; gap: 16px; }
  @media (max-width: 1200px) { .list-grid { grid-template-columns: 1fr; } }
  .tabulator-row.tabulator-selected { background: #fff3c4 !important; }
  .ld-empty { padding: 60px 16px; text-align: center; color: var(--muted); }
  .ld-info { display: grid; grid-template-columns: 70px 1fr; gap: 4px 10px; padding: 12px 16px; border-bottom: 1px solid var(--line); font-size: 13px; }
  .ld-info .k { color: var(--muted); }
  .ld-sum { padding: 8px 16px 14px; }
  .ld-sum .pay-row .v { font-size: 14px; }

  /* 상세 팝업 */
  .modal-header.navy { background: var(--navy); color: #fff; }
  .d-info { display: grid; grid-template-columns: 70px 1fr 70px 1fr; gap: 4px 10px; font-size: 13px; margin-bottom: 10px; }
  .d-info .k { color: var(--muted); }
  table.d-lines { width: 100%; font-size: 13px; border-collapse: collapse; }
  table.d-lines th { background: var(--navy-soft); padding: 6px; text-align: center; white-space: nowrap; }
  table.d-lines th.r, table.d-lines td.r { text-align: right; }
  table.d-lines td { padding: 6px; border-bottom: 1px solid var(--line); }
  table.d-lines tfoot td { font-weight: 700; background: #f7f9fc; }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 ip">
    <ul class="nav nav-tabs ip-tabs" role="tablist">
      <li class="nav-item"><button class="nav-link active" id="tabInBtn" data-bs-toggle="tab" data-bs-target="#tabIn" type="button">입고</button></li>
      <li class="nav-item"><button class="nav-link" id="tabListBtn" data-bs-toggle="tab" data-bs-target="#tabList" type="button">입고조회</button></li>
    </ul>
    <div class="tab-content">
    <div class="tab-pane fade show active" id="tabIn">

    <!-- ================= 거래처 ================= -->
    <div class="card-box mb-3">
      <div class="card-head">
        <h6>입고 · 거래처</h6>
        <div class="sub" id="custHead">거래처를 검색하세요</div>
      </div>
      <div class="cust-search">
        <div class="input-group input-group-sm">
          <input type="text" class="form-control" id="custKw" placeholder="거래처명 입력 후 Enter  ·  F2">
          <button type="button" class="btn btn-outline-secondary" id="btnCustSearch">검색</button>
          <button type="button" class="btn btn-outline-primary" id="btnCustNew">+ 거래처 등록</button>
        </div>
        <div class="drop d-none" id="custResult"></div>
      </div>
      <div class="cust-info" id="custBox">
        <div><div class="k">입고일</div><input type="date" class="form-control form-control-sm in-date" id="inDate"></div>
        <div><div class="k">거래처명</div><div class="v" id="ciName"></div></div>
        <div><div class="k">전화번호</div><div class="v" id="ciTel"></div></div>
        <div><div class="k">담당자</div><div class="v" id="ciMan"></div></div>
        <div><div class="k">핸드폰</div><div class="v" id="ciHp"></div></div>
        <div><div class="k">미불금</div><div class="v mibul" id="ciMibul"></div></div>
      </div>
    </div>

    <!-- ================= 입고 입력 ================= -->
    <div class="in-grid">
      <div class="d-flex flex-column gap-3" style="min-width:0">
      <!-- ================= 입고내역 ================= -->
      <div class="card-box">
        <div class="card-head">
          <h6>입고 내역</h6>
          <div class="sub">건수 <b id="hCnt">0</b> · 입고 <b id="hAmt">0</b> · 지급 <b id="hCash">0</b> · 할인 <b id="hDisc">0</b></div>
        </div>
        <div class="toolbar">
          <input type="date" class="form-control form-control-sm" id="hFrom" style="width:140px">
          <span>~</span>
          <input type="date" class="form-control form-control-sm" id="hTo" style="width:140px">
          <div class="btn-group btn-group-sm">
            <button type="button" class="btn btn-outline-secondary" data-months="1">1개월</button>
            <button type="button" class="btn btn-outline-secondary" data-months="3">3개월</button>
            <button type="button" class="btn btn-outline-secondary" data-months="12">1년</button>
          </div>
          <button type="button" class="btn btn-sm btn-secondary" id="ai201HistSearch">조회</button>
          <span class="hint ms-auto">줄을 누르면 아래 입고등록으로 불러와 수정·삭제 · 🔒 POS 전표는 조회만 가능 · 🔍 는 상세 보기</span>
        </div>
        <div style="position:relative">
          <div id="histTable"></div>
          <div class="loading-mask d-none" id="hLoading">
            <div class="loading-box"><span class="spinner-border spinner-border-sm text-primary me-2"></span>입고 내역을 조회하고 있어요…</div>
          </div>
        </div>
      </div>

      <div class="card-box d-flex flex-column" style="min-width:0">
        <div class="card-head">
          <h6 id="entryTitle">입고 등록</h6>
          <span class="badge text-bg-warning d-none" id="editBadge"></span>
          <div class="sub">품목 <b id="headCnt">0</b> · 수량 <b id="headQty">0</b></div>
        </div>
        <div class="item-input">
          <input type="text" class="form-control" id="prodKw" placeholder="제품코드(바코드) 스캔 또는 제품명·브랜드 입력 후 Enter  ·  F3">
          <div class="drop d-none" id="prodResult"></div>
        </div>
        <div class="line-wrap" id="lineWrap">
          <table class="lines">
            <colgroup>
              <col style="width:38px"><col style="width:125px"><col><col style="width:85px"><col style="width:100px">
              <col style="width:78px"><col style="width:112px"><col style="width:110px"><col style="width:34px">
            </colgroup>
            <thead>
              <tr><th>No</th><th>제품코드</th><th>브랜드 + 제품명</th><th class="r">정가</th><th class="r">입고가</th>
                  <th class="r">입고율</th><th class="r">수량</th><th class="r">금액</th><th></th></tr>
            </thead>
            <tbody id="lineBody"></tbody>
          </table>
        </div>
        <div class="line-foot">
          <span>정가합계 <b id="footPrice">0</b></span>
          <span>입고합계 <b id="footAmt">0</b></span>
          <span class="ms-auto hint">입고율 = 입고가 ÷ 정가 × 100 · 입고율을 바꾸면 입고가 = 정가 × 입고율 ÷ 100 · <kbd>+</kbd>/<kbd>-</kbd> 수량 · <kbd>Del</kbd> 삭제</span>
        </div>
      </div>

      </div>

      <div>
        <div class="card-box" style="position:sticky;top:16px">
          <div class="card-head"><h6>지급</h6><div class="sub" id="payCust">-</div></div>
          <div class="pay">
            <div class="pay-row"><span class="k">현재 미불금</span><span class="v" id="sumMibul">0</span></div>
            <div class="pay-row"><span class="k">입고 금액</span><span class="v" id="sumAmt">0</span></div>
            <div class="pay-row"><span class="k">지급금</span><input class="form-control form-control-sm" id="inCash" value="0"></div>
            <div class="pay-row"><span class="k">할인</span><input class="form-control form-control-sm" id="inDisc" value="0"></div>
            <div class="pay-row d-none" id="rowOrig"><span class="k">수정 전 이 전표 미지급</span><span class="v text-muted" id="sumOrig">0</span></div>
            <div class="pay-row"><span class="k" id="lblDiff">이번 미지급</span><span class="v" id="sumDiff">0</span></div>
            <div class="pay-total"><span>저장 후 미불금</span><span class="v" id="sumAfter">0</span></div>
            <input type="text" class="form-control form-control-sm mt-1" id="inRemk" placeholder="비고">
            <div class="pay-btns">
              <button type="button" class="btn btn-outline-primary" id="btnPayIn" title="이번 입고금액(할인 뺀 금액)만 지급">입고액 지급</button>
              <button type="button" class="btn btn-outline-primary" id="btnPayAll" title="미불금까지 전부 지급">미불 전액 지급</button>
              <button type="button" class="btn btn-primary full" id="btnSave">저장 <span class="hint text-white-50">F12</span></button>
              <button type="button" class="btn btn-outline-danger full d-none" id="btnDelete" style="padding:6px 0;font-size:14px">이 전표 삭제</button>
              <button type="button" class="btn btn-outline-secondary full" id="btnReset" style="padding:6px 0;font-size:14px">입력 취소</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    </div><!-- /tabIn -->

    <!-- ================= 입고조회 ================= -->
    <div class="tab-pane fade" id="tabList">
      <div class="list-grid">
        <div class="card-box" style="min-width:0">
          <div class="card-head">
            <h6>입고조회</h6>
            <div class="sub">건수 <b id="lCnt">0</b> · 입고 <b id="lAmt">0</b> · 지급 <b id="lCash">0</b> · 할인 <b id="lDisc">0</b></div>
          </div>
          <div class="toolbar">
            <input type="date" class="form-control form-control-sm" id="lFrom" style="width:138px">
            <span>~</span>
            <input type="date" class="form-control form-control-sm" id="lTo" style="width:138px">
            <div class="btn-group btn-group-sm">
              <button type="button" class="btn btn-outline-secondary" data-lrange="0">오늘</button>
              <button type="button" class="btn btn-outline-secondary" data-lrange="7">7일</button>
              <button type="button" class="btn btn-outline-secondary" data-lrange="month">이번달</button>
            </div>
            <select class="form-select form-select-sm" id="lKind" style="width:100px" title="구분">
              <option value="">전체</option>
              <option value="매입">매입</option>
              <option value="WEB">WEB</option>
            </select>
            <input type="text" class="form-control form-control-sm" id="lKeyword" placeholder="거래처명" style="width:130px">
            <button type="button" class="btn btn-sm btn-secondary" id="ai201ListSearch">조회</button>
            <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnListExcel">엑셀</button>
          </div>
          <div style="position:relative">
            <div id="listTable"></div>
            <div class="loading-mask d-none" id="lLoading" style="align-items:flex-start;padding-top:120px">
              <div class="loading-box"><span class="spinner-border spinner-border-sm text-primary me-2"></span><span id="lLoadingMsg">입고를 조회하고 있어요…</span></div>
            </div>
          </div>
        </div>

        <div class="card-box" style="align-self:start">
          <div class="card-head"><h6>입고 상세</h6><div class="sub" id="ldHead"></div></div>
          <div id="ldBody"><div class="ld-empty">왼쪽 목록에서 입고를 선택하세요.</div></div>
        </div>
      </div>
    </div><!-- /tabList -->
    </div><!-- /tab-content -->

  </div>
</div>

<!-- 입고 상세 -->
<div class="modal fade" id="dtlModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered modal-lg">
    <div class="modal-content">
      <div class="modal-header navy py-2">
        <h6 class="modal-title" id="dtlTitle">입고 상세</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body" id="dtlBody"></div>
    </div>
  </div>
</div>

<!-- 거래처 등록 -->
<div class="modal fade" id="custModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header navy py-2">
        <h6 class="modal-title" id="ncTitle">거래처 등록</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="row g-2">
          <div class="col-12"><label class="form-label small mb-1">거래처명 <span class="text-danger">*</span></label>
            <input type="text" class="form-control form-control-sm" id="ncName"></div>
          <div class="col-6"><label class="form-label small mb-1">전화번호</label>
            <input type="text" class="form-control form-control-sm" id="ncTel"></div>
          <div class="col-6"><label class="form-label small mb-1">담당자</label>
            <input type="text" class="form-control form-control-sm" id="ncMan"></div>
          <div class="col-6"><label class="form-label small mb-1">핸드폰</label>
            <input type="text" class="form-control form-control-sm" id="ncHp"></div>
          <div class="col-12"><label class="form-label small mb-1">비고</label>
            <textarea class="form-control form-control-sm" id="ncRemk" rows="2"></textarea></div>
        </div>
        <div class="hint mt-2" id="ncHint">거래처코드는 700000~900000 중 마지막 번호 다음으로 자동 부여됩니다.</div>
      </div>
      <div class="modal-footer py-2">
        <button type="button" class="btn btn-sm btn-secondary" data-bs-dismiss="modal">닫기</button>
        <button type="button" class="btn btn-sm btn-primary" id="ncSave">등록</button>
      </div>
    </div>
  </div>
</div>

<!-- 제품 수정 -->
<div class="modal fade" id="prodModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header navy py-2">
        <h6 class="modal-title">제품 정보 수정</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="row g-2">
          <div class="col-6"><label class="form-label small mb-1">제품코드</label>
            <input type="text" class="form-control form-control-sm" id="pmCode" readonly></div>
          <div class="col-6"><label class="form-label small mb-1">브랜드</label>
            <input type="text" class="form-control form-control-sm" id="pmBrand"></div>
          <div class="col-12"><label class="form-label small mb-1">제품명 <span class="text-danger">*</span></label>
            <input type="text" class="form-control form-control-sm" id="pmName"></div>
          <div class="col-4"><label class="form-label small mb-1">정가</label>
            <input type="text" class="form-control form-control-sm text-end" id="pmPrice"></div>
          <div class="col-4"><label class="form-label small mb-1">판매가</label>
            <input type="text" class="form-control form-control-sm text-end" id="pmSale"></div>
          <div class="col-4"><label class="form-label small mb-1">입고가 <span class="hint" id="pmRate"></span></label>
            <input type="text" class="form-control form-control-sm text-end" id="pmIn"></div>
          <div class="col-12">
            <div class="form-check mt-1">
              <input class="form-check-input" type="checkbox" id="pmChk">
              <label class="form-check-label small" for="pmChk">사용 (CHK = Y)</label>
            </div>
          </div>
        </div>
        <div class="hint mt-2">제품 마스터(SHOP_JEPM_MST)가 바뀝니다. 이미 저장된 입고·매출 전표는 바뀌지 않습니다.</div>
      </div>
      <div class="modal-footer py-2">
        <button type="button" class="btn btn-sm btn-secondary" data-bs-dismiss="modal">닫기</button>
        <button type="button" class="btn btn-sm btn-primary" id="pmSave">수정</button>
      </div>
    </div>
  </div>
</div>

<!-- 매니저 암호 -->
<div class="modal fade" id="pwModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered modal-sm">
    <div class="modal-content">
      <div class="modal-header navy py-2">
        <h6 class="modal-title">처리자 변경 승인</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="small mb-2" id="pwInfo"></div>
        <label class="form-label small mb-1">매니저 암호</label>
        <input type="password" class="form-control" id="pwInput" autocomplete="off">
        <div class="small text-danger mt-1" id="pwErr"></div>
      </div>
      <div class="modal-footer py-2">
        <button type="button" class="btn btn-sm btn-secondary" data-bs-dismiss="modal">닫기</button>
        <button type="button" class="btn btn-sm btn-primary" id="pwOk">확인</button>
      </div>
    </div>
  </div>
</div>

<!-- 토스트 -->
<div class="position-fixed bottom-0 end-0 p-3" style="z-index:2000">
  <div id="toast" class="toast align-items-center text-bg-dark border-0" role="alert">
    <div class="d-flex"><div class="toast-body" id="toastMsg"></div>
      <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button></div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://unpkg.com/tabulator-tables@6.2.5/dist/js/tabulator.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>
<script>
/* =====================================================================
 * 입고 (ai201)
 *   - 거래처 : CUST_MST (CUSTCD 700000~900000, JIKPAN='N', 거래종료 제외)
 *   - 입고   : IP01_MST / IP01_DTL  (KIND='매입')
 *   - 미불금 : 저장 시 MIBULAMT + 입고금액 - 지급금 - 할인
 *   - 입고가 : 최근 입고단가, 없으면 SHOP_JEPM_MST.INPRICE
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai201';
  var cust = null;          // 선택된 거래처
  var lines = [];           // 입고 목록
  var selIdx = -1;
  var histTable = null, dtlModal = null, custModal = null, toast = null;
  var $ = function (id) { return document.getElementById(id); };

  // ---------------- 유틸 ----------------
  function num(v) { return Number(String(v == null ? '' : v).replace(/[^\d-]/g, '')) || 0; }
  function dec(v) { return parseFloat(String(v == null ? '' : v).replace(/[^\d.\-]/g, '')) || 0; }
  function won(n) { return Number(n || 0).toLocaleString('ko-KR'); }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.indexOf('02') === 0 ? d.replace(/(\d{2})(\d{4})(\d{4})/, '$1-$2-$3') : d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    if (d.length === 9) return d.replace(/(\d{2})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
  function ymd(d) { return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
  function msg(t) { $('toastMsg').textContent = t; toast.show(); }
  function fail(e) { alert(e.message || e); }

  function api(path, params, body) {
    if (window.IpMock) return window.IpMock.handle(path, params, body);   // 미리보기용
    var url = API + path + (params ? '?' + new URLSearchParams(params) : '');
    var opt = body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {};
    return fetch(url, opt)
      .then(function (r) {
        if (!r.ok) throw new Error('서버 요청 실패 (' + r.status + ') : ' + url);
        return r.json();
      })
      .then(function (res) {
        if (!res.ok) throw new Error(res.msg || '처리 중 오류가 발생했습니다.');
        return res.data;
      });
  }

  // ---------------- 거래처 ----------------
  function searchCust() {
    var kw = $('custKw').value.trim();
    if (!kw) { msg('거래처명을 입력하세요.'); return; }
    api('/custs', { keyword: kw }).then(function (list) {
      var box = $('custResult');
      if (!list.length) { box.innerHTML = '<div class="p-3 text-muted small">검색된 거래처가 없어요. [+ 거래처 등록]으로 추가할 수 있어요.</div>'; box.classList.remove('d-none'); return; }
      if (list.length === 1) { setCust(list[0]); return; }
      box.innerHTML = list.map(function (c, i) {
        return '<button type="button" data-i="' + i + '"><span class="text-muted">' + esc(c.custcd) + '</span><b>' + esc(c.custname) + '</b>'
             + '<span>' + esc(fmtTel(c.telno)) + '</span><span>' + esc(c.mannm) + (c.hp ? ' ' + esc(fmtTel(c.hp)) : '') + '</span>'
             + '<span class="r text-danger">' + won(c.mibul) + '</span></button>';
      }).join('');
      box.querySelectorAll('button').forEach(function (b) { b.onclick = function () { setCust(list[+b.dataset.i]); }; });
      box.classList.remove('d-none');
    }).catch(fail);
  }

  function setCust(c) {
    if (cust && cust.custcd !== c.custcd && (lines.length || num($('inCash').value) || num($('inDisc').value))) {
      if (!confirm('입력 중인 입고 내용이 있어요. 거래처를 바꿀까요?\n(입력한 품목은 그대로 남습니다)')) return;
    }
    if (edit && cust && cust.custcd !== c.custcd) { edit = null; setEditUI(); lines = []; resetInput(); }
    cust = c;
    $('custResult').classList.add('d-none');
    $('custKw').value = '';
    drawCust();
    calc();
    loadHist();
    $('prodKw').focus();
  }

  // 거래처 정보 (첫 칸은 입고일 입력)
  function drawCust() {
    if (!cust) {
      $('custHead').textContent = '거래처를 검색하세요';
      $('payCust').textContent = '-';
      $('ciName').innerHTML = '<span class="text-muted fw-normal" style="font-size:13px">거래처를 검색해서 선택하세요</span>';
      ['ciTel', 'ciMan', 'ciHp', 'ciMibul'].forEach(function (id) { $(id).textContent = '-'; });
      return;
    }
    if (cust.sopost !== 'WEB') {      // POS 거래처 : 조회만 (WEB 등록 거래처만 수정 가능)
      $('custHead').innerHTML = '<span class="small text-white-50" title="WEB 등록 거래처만 수정할 수 있습니다">🔒 POS 거래처 · 수정 불가</span>';
    } else {
      $('custHead').innerHTML = '<button type="button" class="btn btn-sm btn-light py-0 px-2" id="btnCustEdit">✎ 거래처 수정</button>';
      $('btnCustEdit').onclick = openEditCust;
    }
    $('payCust').textContent = cust.custname;
    $('ciName').textContent = cust.custname;
    if (cust.remk) $('ciName').insertAdjacentHTML('beforeend',
      '<div class="small text-muted fw-normal text-truncate" style="font-size:11px;max-width:220px">' + esc(cust.remk) + '</div>');
    $('ciName').title = '거래처코드 ' + cust.custcd + (cust.remk ? '\n비고 : ' + cust.remk : '');
    $('ciTel').textContent = fmtTel(cust.telno) || '-';
    $('ciMan').textContent = cust.mannm || '-';
    $('ciHp').textContent = fmtTel(cust.hp) || '-';
    $('ciMibul').textContent = won(cust.mibul);
  }

  // 거래처 등록 / 수정 (같은 창 사용)
  var custEditMode = false;
  function openNewCust() {
    custEditMode = false;
    $('ncTitle').textContent = '거래처 등록';
    $('ncSave').textContent = '등록';
    $('ncHint').textContent = '거래처코드는 700000~900000 중 마지막 번호 다음으로 자동 부여됩니다.';
    ['ncName', 'ncTel', 'ncMan', 'ncHp', 'ncRemk'].forEach(function (id) { $(id).value = ''; });
    custModal.show();
    setTimeout(function () { $('ncName').focus(); }, 300);
  }
  function openEditCust() {
    if (!cust) return;
    custEditMode = true;
    $('ncTitle').textContent = '거래처 수정 · ' + cust.custcd;
    $('ncSave').textContent = '수정';
    $('ncHint').textContent = '거래처코드와 미불금은 수정되지 않습니다.';
    $('ncName').value = cust.custname || '';
    $('ncTel').value = cust.telno || '';
    $('ncMan').value = cust.mannm || '';
    $('ncHp').value = cust.hp || '';
    $('ncRemk').value = cust.remk || '';
    custModal.show();
    setTimeout(function () { $('ncName').focus(); }, 300);
  }
  function saveNewCust() {
    var body = { custname: $('ncName').value.trim(), telno: $('ncTel').value.trim(), mannm: $('ncMan').value.trim(), hp: $('ncHp').value.trim(), remk: $('ncRemk').value.trim() };
    if (!body.custname) { msg('거래처명을 입력하세요.'); $('ncName').focus(); return; }
    $('ncSave').disabled = true;
    var req = custEditMode
      ? api('/cust/update', null, Object.assign({ custcd: cust.custcd }, body))
          .then(function (c) { custModal.hide(); msg('거래처를 수정했어요.'); cust = c; drawCust(); calc(); })
      : api('/cust', null, body)
          .then(function (c) { custModal.hide(); msg('거래처를 등록했어요. (코드 ' + c.custcd + ')'); setCust(c); });
    req.catch(fail).then(function () { $('ncSave').disabled = false; });
  }

  // ---------------- 입고내역 ----------------
  function buildHist() {
    var money = function (c) { return won(c.getValue()); };
    histTable = new Tabulator('#histTable', {
      layout: 'fitColumns',
      height: '210px',
      placeholder: '입고 내역이 없어요.',
      selectableRows: 1,
      columnDefaults: { headerSort: false },
      columns: [
        { title: '일자', field: 'date', width: 100, hozAlign: 'center', bottomCalc: function () { return '합계'; } },
        { title: '시간', field: 'time', width: 60, hozAlign: 'center' },
        { title: '입고금액', field: 'amt', width: 110, hozAlign: 'right', headerHozAlign: 'right',
          formatter: function (c) { return '<b>' + won(c.getValue()) + '</b>'; }, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '지급금', field: 'cash', width: 100, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '할인', field: 'disc', width: 85, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '미지급금', field: 'bal', width: 110, hozAlign: 'right', headerHozAlign: 'right',
          formatter: function (c) { return '<span class="text-danger fw-bold">' + won(c.getValue()) + '</span>'; } },
        { title: '비고', field: 'remk', minWidth: 120, tooltip: true },
        { title: '처리자', field: 'pruser', width: 80,
          formatter: function (c) { return (c.getData().kind !== 'WEB' && c.getData().amt ? '<span title="POS 전표 : 조회만 가능">🔒</span> ' : '') + esc(c.getValue() || ''); } },
        { title: '상세', field: 'key', width: 56, hozAlign: 'center',
          formatter: function (c) { return c.getData().amt ? '<button type="button" class="btn btn-outline-primary btn-dtl" title="입고 상세">🔍</button>' : '<span class="hint">지급</span>'; },
          cellClick: function (e, cell) { if (e.target.closest('.btn-dtl')) openDetail(cell.getData()); } }
      ]
    });
    histTable.on('rowClick', function (e, row) {
      if (e.target.closest('.btn-dtl')) return;      // 🔍 는 상세 팝업
      loadForEdit(row.getData());
    });
  }

  function loadHist() {
    if (!histTable) return;
    if (!cust) { histTable.setData([]); sumHist([]); return; }
    $('hLoading').classList.remove('d-none');
    $('ai201HistSearch').disabled = true;
    api('/history', { custcd: cust.custcd, from: $('hFrom').value, to: $('hTo').value })
      .then(function (d) {
        cust.mibul = d.mibul;          // 최신 미불금으로 갱신
        drawCust(); calc();
        histTable.setData(d.rows || []);
        sumHist(d.rows || []);
      })
      .catch(fail)
      .then(function () { $('hLoading').classList.add('d-none'); $('ai201HistSearch').disabled = false; });
  }
  function sumHist(list) {
    var a = 0, c = 0, s = 0;
    list.forEach(function (r) { a += r.amt; c += r.cash; s += r.disc; });
    $('hCnt').textContent = won(list.length);
    $('hAmt').textContent = won(a);
    $('hCash').textContent = won(c);
    $('hDisc').textContent = won(s);
  }
  function setMonths(n) {
    var t = new Date(), f = new Date();
    f.setMonth(f.getMonth() - n);
    $('hFrom').value = ymd(f); $('hTo').value = ymd(t);
    loadHist();
  }

  function openDetail(r) {
    $('dtlTitle').textContent = '입고 상세 · ' + (cust ? cust.custname : '') + ' · ' + r.date;
    $('dtlBody').innerHTML = '<div class="text-center text-muted py-4">불러오는 중…</div>';
    dtlModal.show();
    api('/detail', { key: r.key }).then(function (list) {
      var qty = 0, amt = 0;
      var rows = (list || []).map(function (l, i) {
        qty += l.qty; amt += l.amt;
        var rate = l.price ? Math.round(l.inprice / l.price * 1000) / 10 : '';
        return '<tr><td class="text-center">' + (i + 1) + '</td><td>' + esc(l.jepmcd) + '</td>'
             + '<td><span class="text-muted small">' + esc(l.brand) + '</span> ' + esc(l.jepmnm)
             + (l.remk ? '<div class="small text-muted">' + esc(l.remk) + '</div>' : '') + '</td>'
             + '<td class="r">' + won(l.price) + '</td><td class="r">' + won(l.inprice) + '</td>'
             + '<td class="r">' + (rate === '' ? '' : rate + '%') + '</td>'
             + '<td class="r">' + won(l.qty) + '</td><td class="r fw-bold">' + won(l.amt) + '</td></tr>';
      }).join('');
      $('dtlBody').innerHTML =
          '<div class="d-info">'
        + '<span class="k">입고일</span><span>' + esc(r.date) + (r.time ? ' ' + esc(r.time) : '') + '</span>'
        + '<span class="k">처리자</span><span>' + esc(r.pruser || '-') + '</span>'
        + '<span class="k">전표</span><span class="text-muted">' + esc(r.key) + '</span>'
        + '<span class="k">비고</span><span>' + esc(r.remk || '-') + '</span>'
        + '</div>'
        + '<div style="max-height:50vh;overflow:auto"><table class="d-lines"><thead><tr><th>No</th><th>제품코드</th><th>제품</th>'
        + '<th class="r">정가</th><th class="r">입고가</th><th class="r">입고율</th><th class="r">수량</th><th class="r">금액</th></tr></thead>'
        + '<tbody>' + (rows || '<tr><td colspan="8" class="text-center text-muted py-3">상세 내역이 없어요.</td></tr>') + '</tbody>'
        + '<tfoot><tr><td colspan="6" class="text-center">합계</td><td class="r">' + won(qty) + '</td><td class="r">' + won(amt) + '</td></tr></tfoot></table></div>'
        + '<div class="d-flex justify-content-end gap-4 mt-3">'
        + '<span>입고금액 <b>' + won(r.amt) + '</b></span><span>지급금 <b>' + won(r.cash) + '</b></span>'
        + '<span>할인 <b>' + won(r.disc) + '</b></span><span>처리 후 미지급금 <b class="text-danger">' + won(r.bal) + '</b></span></div>';
    }).catch(fail);
  }

  // ---------------- 제품 / 입고 목록 ----------------
  function searchProduct() {
    var kw = $('prodKw').value.trim();
    if (!kw) return;
    api('/products', { keyword: kw }).then(function (list) {
      var exact = list.filter(function (p) { return p.jepmcd === kw; })[0];
      if (exact) { addLine(exact); return; }
      var box = $('prodResult');
      if (!list.length) { box.innerHTML = '<div class="p-3 text-muted small">검색된 제품이 없어요.</div>'; box.classList.remove('d-none'); return; }
      if (list.length === 1) { addLine(list[0]); return; }
      box.innerHTML = list.map(function (p, i) {
        var inp = p.lastin > 0 ? p.lastin : p.inprice;
        return '<button type="button" data-i="' + i + '"><span class="text-muted">' + esc(p.jepmcd) + '</span>'
             + '<span><span class="text-muted">' + esc(p.brand) + '</span> <b>' + esc(p.jepmnm) + '</b></span>'
             + '<span class="r text-muted">정가 ' + won(p.price) + '</span>'
             + '<span class="r"><b>' + won(inp) + '</b></span></button>';
      }).join('');
      box.querySelectorAll('button').forEach(function (b) { b.onclick = function () { addLine(list[+b.dataset.i]); }; });
      box.classList.remove('d-none');
    }).catch(fail);
  }

  function addLine(p) {
    $('prodResult').classList.add('d-none');
    $('prodKw').value = '';
    var last = p.lastin > 0;
    var inprice = last ? p.lastin : p.inprice;
    var i = lines.findIndex(function (l) { return l.jepmcd === p.jepmcd && l.inprice === inprice; });
    if (i >= 0) { lines[i].qty++; selIdx = i; }
    else {
      lines.push({ jepmcd: p.jepmcd, brand: p.brand, jepmnm: p.jepmnm, price: p.price, inprice: inprice,
                   src: last ? 'last' : 'base', qty: 1, remk: '' });
      selIdx = lines.length - 1;
    }
    drawLines();
    $('prodKw').focus();
  }

  function rateOf(l) { return l.price ? Math.round(l.inprice / l.price * 1000) / 10 : 0; }

  function drawLines() {
    var tb = $('lineBody');
    if (!lines.length) {
      tb.innerHTML = '<tr class="line-empty"><td colspan="9">제품코드를 스캔하거나 제품명을 검색해서 추가하세요. 품목 없이 지급금만 저장할 수도 있어요.</td></tr>';
    } else {
      tb.innerHTML = lines.map(function (l, i) {
        var srcTxt = l.src === 'last' ? '최근입고가' : l.src === 'base' ? '기본입고가' : l.src === 'orig' ? '기존입고가' : '직접입력';
        return '<tr data-i="' + i + '" class="' + (i === selIdx ? 'sel' : '') + '">'
          + '<td class="c">' + (i + 1) + '</td>'
          + '<td>' + esc(l.jepmcd) + '</td>'
          + '<td><span class="brand">' + esc(l.brand) + '</span>' + esc(l.jepmnm)
          + ' <button type="button" class="btn btn-link btn-sm p-0 ms-1 text-secondary" data-edit="1" title="제품 정보 수정">✎</button></td>'
          + '<td class="r text-muted">' + won(l.price) + '</td>'
          + '<td><input class="r" data-f="inprice" value="' + won(l.inprice) + '"><span class="src ' + l.src + '">' + srcTxt + '</span></td>'
          + '<td><div class="pct"><input class="r" data-f="rate" value="' + rateOf(l) + '"><span>%</span></div></td>'
          + '<td class="r"><span class="qty"><button type="button" data-q="-1">−</button><input data-f="qty" value="' + l.qty + '"><button type="button" data-q="1">+</button></span></td>'
          + '<td class="r fw-bold">' + won(l.inprice * l.qty) + '</td>'
          + '<td class="c"><button type="button" class="btn btn-sm btn-link text-danger p-0" data-del="1" title="삭제">✕</button></td>'
          + '</tr>';
      }).join('');
    }
    calc();
  }

  function changeQty(i, d) {
    if (i < 0 || !lines[i]) return;
    lines[i].qty = Math.max(1, lines[i].qty + d);
    selIdx = i;
    drawLines();
  }
  function removeLine(i) {
    if (i < 0 || !lines[i]) return;
    lines.splice(i, 1);
    selIdx = Math.min(i, lines.length - 1);
    drawLines();
  }

  // ---------------- 계산 ----------------
  function calc() {
    var sumPrice = 0, amt = 0, qty = 0;
    lines.forEach(function (l) { sumPrice += l.price * l.qty; amt += l.inprice * l.qty; qty += l.qty; });
    var cash = num($('inCash').value), disc = num($('inDisc').value);
    var mibul = cust ? Number(cust.mibul) || 0 : 0;
    var diff = amt - cash - disc;
    var orig = edit ? edit.diff : 0;                  // 수정 전 이 전표의 미지급분
    $('headCnt').textContent = lines.length;
    $('headQty').textContent = won(qty);
    $('footPrice').textContent = won(sumPrice);
    $('footAmt').textContent = won(amt);
    $('sumMibul').textContent = won(mibul);
    $('sumAmt').textContent = won(amt);
    $('sumDiff').textContent = (diff > 0 ? '+' : '') + won(diff);
    $('sumDiff').className = 'v ' + (diff > 0 ? 'text-danger' : diff < 0 ? 'text-primary' : '');
    $('rowOrig').classList.toggle('d-none', !edit);
    $('sumOrig').textContent = won(orig);
    $('lblDiff').textContent = edit ? '수정 후 이 전표 미지급' : '이번 미지급';
    $('sumAfter').textContent = won(mibul - orig + diff);
    return { amt: amt, cash: cash, disc: disc, diff: diff, mibul: mibul, orig: orig, after: mibul - orig + diff };
  }

  // ---------------- 입고 수정 모드 ----------------
  var edit = null;   // { key, date, diff, kind } : 입고내역에서 불러온 전표

  function setEditUI() {
    var on = !!edit;
    $('entryTitle').textContent = on ? '입고 수정' : '입고 등록';
    $('editBadge').classList.toggle('d-none', !on);
    $('editBadge').textContent = on ? edit.date + (edit.time ? ' ' + edit.time : '') + ' 전표' + (edit.kind !== 'WEB' ? ' · 포스 입력' : '') : '';
    $('btnSave').innerHTML = (on ? '수정 저장' : '저장') + ' <span class="hint text-white-50">F12</span>';
    $('btnDelete').classList.toggle('d-none', !on);
    $('btnReset').textContent = on ? '수정 취소' : '입력 취소';
    $('entryTitle').closest('.card-box').classList.toggle('editing', on);
    $('btnSave').closest('.card-box').classList.toggle('editing', on);
    if (!on && histTable) histTable.deselectRow();
  }

  function loadForEdit(r) {
    if (r.kind !== 'WEB') {           // POS 전표 : 조회만 가능 → 상세 팝업 (WEB 전표만 수정·삭제)
      if (histTable) histTable.deselectRow();
      msg('POS 입고 전표는 조회만 가능합니다. (WEB 전표만 수정·삭제)');
      if (r.amt) openDetail(r);
      return;
    }
    if (edit && edit.key === r.key) return;
    if ((lines.length || num($('inCash').value) || num($('inDisc').value)) &&
        !confirm('입력 중인 내용이 있어요. 이 전표를 불러올까요?\n(입력 중인 내용은 지워집니다)')) {
      if (histTable) histTable.deselectRow();
      return;
    }
    api('/detail', { key: r.key }).then(function (list) {
      lines = (list || []).map(function (l) {
        return { jepmcd: l.jepmcd, brand: l.brand, jepmnm: l.jepmnm, price: l.price, inprice: l.inprice, src: 'orig', qty: l.qty };
      });
      selIdx = lines.length - 1;
      $('inDate').value = r.date;
      $('inCash').value = won(r.cash);
      $('inDisc').value = won(r.disc);
      $('inRemk').value = r.remk || '';
      edit = { key: r.key, date: r.date, time: r.time, kind: r.kind, diff: r.amt - r.cash - r.disc };
      var row = histTable.getRows().filter(function (x) { return x.getData().key === r.key; })[0];
      if (row) { histTable.deselectRow(); row.select(); }
      setEditUI();
      drawLines();
      msg(r.date + ' 입고 전표를 불러왔어요. 고친 뒤 [수정 저장]을 누르세요.');
    }).catch(fail);
  }

  function deleteEdit() {
    if (!edit) return;
    var c = calc();
    if (!confirm('[' + cust.custname + '] ' + edit.date + ' 입고 전표를 삭제할까요?\n\n'
               + '미불금 ' + won(c.mibul) + ' → ' + won(c.mibul - edit.diff)
               + (edit.kind !== 'WEB' ? '\n\n※ 포스에서 입력된 전표입니다.' : '')
               + '\n\n삭제하면 되돌릴 수 없어요.')) return;
    $('btnDelete').disabled = true;
    api('/delete', null, { key: edit.key })
      .then(function (r) {
        cust.mibul = r.mibul;
        resetInput();
        drawCust(); calc();
        msg('입고 전표를 삭제했어요. 미불금 ' + won(r.mibul));
        loadHist();
      })
      .catch(fail)
      .then(function () { $('btnDelete').disabled = false; });
  }

  function resetInput() {
    edit = null;
    setEditUI();
    lines = []; selIdx = -1;
    ['inCash', 'inDisc'].forEach(function (id) { $(id).value = '0'; });
    $('inRemk').value = '';
    $('inDate').value = ymd(new Date());
    drawLines();
  }

  var saving = false;
  function save() {
    if (saving) return;
    if (!cust) { msg('거래처를 먼저 선택하세요.'); $('custKw').focus(); return; }
    var c = calc();
    if (!lines.length && !c.cash && !c.disc) { msg('입고할 제품이나 지급금을 입력하세요.'); $('prodKw').focus(); return; }
    if (!$('inDate').value) { msg('입고일을 입력하세요.'); $('inDate').focus(); return; }
    var txt = (edit ? '[입고 수정]  ' : '') + '[' + cust.custname + ']  입고일 ' + $('inDate').value + '\n\n'
            + (lines.length ? '입고 ' + lines.length + '품목 ' + won(c.amt) + '원\n' : '품목 없이 지급만 저장합니다.\n')
            + '지급금 ' + won(c.cash) + ' / 할인 ' + won(c.disc) + '\n'
            + '미불금 ' + won(c.mibul) + ' → ' + won(c.after)
            + (c.after < 0 ? '\n\n※ 저장 후 미불금이 마이너스(선지급)가 됩니다.' : '')
            + (edit && edit.kind !== 'WEB' ? '\n\n※ 포스에서 입력된 전표를 수정합니다.' : '')
            + '\n\n저장할까요?';
    if (!confirm(txt)) return;

    var body = {
      custcd: cust.custcd,
      ipdate: $('inDate').value,
      cash: c.cash, disc: c.disc,
      remk: $('inRemk').value.trim(),
      lines: lines.map(function (l) { return { jepmcd: l.jepmcd, inprice: l.inprice, qty: l.qty }; })
    };
    if (edit) body.key = edit.key;
    var isEdit = !!edit;
    saving = true;
    $('btnSave').disabled = true;
    api(isEdit ? '/update' : '/save', null, body)
      .then(function (r) {
        cust.mibul = r.mibul;
        resetInput();
        drawCust();
        calc();
        msg((isEdit ? '수정했어요. ' : '저장했어요. ') + '입고 ' + won(r.amt) + ' · 지급 ' + won(r.cash) + ' · 미불금 ' + won(r.mibul));
        if ($('hTo').value < ymd(new Date())) $('hTo').value = ymd(new Date());
        loadHist();
      })
      .catch(fail)
      .then(function () { saving = false; $('btnSave').disabled = false; });
  }

  // ---------------- 입고조회 (특정일자 하루) ----------------
  var listTable = null;
  function listHeight() {
    var top = $('listTable').getBoundingClientRect().top + window.pageYOffset;
    return Math.max(300, window.innerHeight - top - 26) + 'px';
  }
  function buildList() {
    var money = function (c) { return won(c.getValue()); };
    listTable = new Tabulator('#listTable', {
      layout: 'fitColumns',
      height: listHeight(),
      selectableRows: 1,
      placeholder: '조회된 입고가 없어요.',
      columnDefaults: { headerSort: false },
      columns: [
        { title: '일자', field: 'date', width: 64, hozAlign: 'center', bottomCalc: function () { return '합계'; },
          formatter: function (c) { var v = c.getValue() || ''; return '<span title="' + v + '">' + v.substring(5) + '</span>'; } },
        { title: '시간', field: 'time', width: 56, hozAlign: 'center' },
        { title: '코드', field: 'custcd', width: 66, hozAlign: 'center' },
        { title: '거래처', field: 'custname', minWidth: 110, tooltip: true },
        { title: '전화번호', field: 'telno', width: 116, formatter: function (c) { return esc(fmtTel(c.getValue())); },
          accessorDownload: function (v) { return fmtTel(v); } },
        { title: '입고금액', field: 'amt', width: 100, hozAlign: 'right', headerHozAlign: 'right',
          formatter: function (c) { return '<b>' + won(c.getValue()) + '</b>'; }, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '지급금', field: 'cash', width: 92, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '할인', field: 'disc', width: 72, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '처리자', field: 'pruser', width: 72 },
        { title: '비고', field: 'remk', minWidth: 80, tooltip: true },
        { title: '구분', field: 'kind', width: 56, hozAlign: 'center' }
      ]
    });
    listTable.on('rowClick', function (e, row) { row.getTable().deselectRow(); row.select(); showListDetail(row.getData()); });
  }
  function loadList() {
    if (!listTable) return;
    var f = $('lFrom').value, t = $('lTo').value;
    if (!f || !t) { msg('조회 기간을 입력하세요.'); return; }
    if (f > t) { msg('시작일이 종료일보다 늦어요.'); return; }
    $('lLoadingMsg').textContent = f + ' ~ ' + t + ' 입고를 조회하고 있어요…';
    $('lLoading').classList.remove('d-none');
    $('ai201ListSearch').disabled = true;
    $('ai201ListSearch').textContent = '조회 중…';
    api('/list', { from: f, to: t, kind: $('lKind').value, keyword: $('lKeyword').value.trim() })
      .then(function (list) {
        list = list || [];
        listTable.setData(list);
        var a = 0, c = 0, s = 0;
        list.forEach(function (r) { a += r.amt; c += r.cash; s += r.disc; });
        $('lCnt').textContent = won(list.length);
        $('lAmt').textContent = won(a);
        $('lCash').textContent = won(c);
        $('lDisc').textContent = won(s);
        $('ldHead').textContent = '';
        $('ldBody').innerHTML = '<div class="ld-empty">왼쪽 목록에서 입고를 선택하세요.</div>';
        msg(won(list.length) + '건 조회했어요.');
      })
      .catch(fail)
      .then(function () {
        $('lLoading').classList.add('d-none');
        $('ai201ListSearch').disabled = false;
        $('ai201ListSearch').textContent = '조회';
      });
  }
  function setListRange(r) {
    var t = new Date(), f = new Date();
    if (r === '7') f.setDate(t.getDate() - 6);
    else if (r === 'month') f = new Date(t.getFullYear(), t.getMonth(), 1);
    $('lFrom').value = ymd(f); $('lTo').value = ymd(t);
    loadList();
  }
  function showListDetail(r) {
    $('ldHead').textContent = r.date + (r.time ? ' ' + r.time : '');
    $('ldBody').innerHTML = '<div class="ld-empty">불러오는 중…</div>';
    api('/detail', { key: r.key }).then(function (lines) {
      var qty = 0, amt = 0;
      var rows = (lines || []).map(function (l) {
        qty += l.qty; amt += l.amt;
        var rate = l.price ? Math.round(l.inprice / l.price * 1000) / 10 + '%' : '';
        return '<tr><td>' + esc(l.jepmcd) + '</td>'
             + '<td><span class="text-muted small">' + esc(l.brand) + '</span> ' + esc(l.jepmnm) + '</td>'
             + '<td class="r">' + won(l.inprice) + '<div class="small text-muted">' + won(l.price) + (rate ? ' · ' + rate : '') + '</div></td>'
             + '<td class="r">' + won(l.qty) + '</td>'
             + '<td class="r fw-bold">' + won(l.amt) + '</td></tr>';
      }).join('');
      $('ldBody').innerHTML =
          '<div class="ld-info">'
        + '<span class="k">거래처</span><span><b>' + esc(r.custname || '-') + '</b> <span class="text-muted">' + esc(r.custcd) + '</span></span>'
        + '<span class="k">전화</span><span>' + esc(fmtTel(r.telno) || '-') + (r.mannm ? ' · ' + esc(r.mannm) : '') + (r.hp ? ' ' + esc(fmtTel(r.hp)) : '') + '</span>'
        + '<span class="k">처리자</span><span class="d-flex gap-1 align-items-center">'
        +   (r.kind !== 'WEB'
              ? '<span>' + esc(r.pruser || '-') + '</span>'
              : '<select class="form-select form-select-sm" id="ldPruser" style="width:120px">' + sellerOptions(r.pruser) + '</select>'
              + '<button type="button" class="btn btn-sm btn-outline-primary" id="btnPruser">변경</button>')
        +   ' <span class="text-muted">(' + esc(r.kind) + ')</span></span>'
        + (r.kind !== 'WEB' ? '<span class="k"></span><span class="text-muted small">🔒 POS 전표는 조회만 가능합니다. (수정·삭제·처리자 변경은 WEB 전표만)</span>' : '')
        + '<span class="k">전표</span><span class="text-muted">' + esc(r.key) + '</span>'
        + (r.remk ? '<span class="k">비고</span><span>' + esc(r.remk) + '</span>' : '')
        + '</div>'
        + (rows ? '<div style="max-height:320px;overflow:auto"><table class="d-lines"><thead><tr><th>제품코드</th><th>제품</th>'
                + '<th class="r">입고가</th><th class="r">수량</th><th class="r">금액</th></tr></thead><tbody>' + rows + '</tbody></table></div>'
                : '<div class="ld-empty" style="padding:24px 16px">품목 없는 지급 전표입니다.</div>')
        + '<div class="ld-sum">'
        + row('입고 합계 (' + won(qty) + '개)', won(amt))
        + '<div class="pay-row" style="border-top:1px solid var(--line);margin-top:4px;padding-top:6px"><span class="k">입고금액</span><span class="v" style="font-size:18px">' + won(r.amt) + '</span></div>'
        + row('지급금', won(r.cash))
        + row('할인', won(r.disc))
        + row('현재 미불금', '<span class="text-danger">' + won(r.mibul) + '</span>')
        + '</div>';
      function row(k, v) { return '<div class="pay-row"><span class="k">' + k + '</span><span class="v">' + v + '</span></div>'; }
      if ($('btnPruser')) $('btnPruser').onclick = function () { changePruser(r); };
    }).catch(fail);
  }

  // ---------------- 처리자 변경 (매니저 암호) ----------------
  var SELLERS = [], pwModal = null, pwTarget = null;
  function loadSellers() { api('/sellers').then(function (l) { SELLERS = l || []; }).catch(fail); }
  function sellerOptions(cur) {
    var list = SELLERS.slice();
    if (cur && list.indexOf(cur) < 0) list.unshift(cur);
    if (!list.length) list = [''];
    return list.map(function (n) { return '<option' + (n === cur ? ' selected' : '') + '>' + esc(n) + '</option>'; }).join('');
  }
  function changePruser(r) {
    var s = $('ldPruser').value;
    if (!s || s === r.pruser) { msg('바꿀 처리자를 선택하세요.'); return; }
    pwTarget = { r: r, pruser: s };
    if (!pwModal) {
      pwModal = new bootstrap.Modal($('pwModal'));
      $('pwModal').addEventListener('shown.bs.modal', function () { $('pwInput').focus(); });
      $('pwOk').onclick = submitPruser;
      $('pwInput').onkeydown = function (e) { if (e.key === 'Enter') submitPruser(); };
    }
    $('pwInfo').innerHTML = '처리자 <b>' + esc(r.pruser || '-') + '</b> → <b>' + esc(s) + '</b>';
    $('pwInput').value = '';
    $('pwErr').textContent = '';
    pwModal.show();
  }
  function submitPruser() {
    var pw = $('pwInput').value;
    if (!pw) { $('pwErr').textContent = '암호를 입력하세요.'; return; }
    var t = pwTarget;
    $('pwOk').disabled = true;
    api('/pruser', null, { key: t.r.key, pruser: t.pruser, pw: pw })
      .then(function () {
        pwModal.hide();
        msg('처리자를 ' + t.pruser + '(으)로 바꿨어요.');
        t.r.pruser = t.pruser;
        var row = listTable.getRows().filter(function (x) { return x.getData().key === t.r.key; })[0];
        if (row) row.update({ pruser: t.pruser });
        if (histTable) loadHist();
      })
      .catch(function (e) { $('pwErr').textContent = e.message || e; $('pwInput').select(); })
      .then(function () { $('pwOk').disabled = false; });
  }

  // ---------------- 제품 수정 (SHOP_JEPM_MST) ----------------
  var prodModal = null, prodIdx = -1;
  function openProduct(i) {
    var l = lines[i]; if (!l) return;
    prodIdx = i;
    if (!prodModal) prodModal = new bootstrap.Modal($('prodModal'));
    api('/product', { jepmcd: l.jepmcd }).then(function (p) {
      $('pmCode').value = p.jepmcd;
      $('pmBrand').value = p.brand;
      $('pmName').value = p.jepmnm;
      $('pmPrice').value = won(p.price);
      $('pmSale').value = won(p.saleprice);
      $('pmIn').value = won(p.inprice);
      $('pmChk').checked = p.chk !== 'N';
      pmRate();
      prodModal.show();
      setTimeout(function () { $('pmName').focus(); }, 300);
    }).catch(fail);
  }
  function pmRate() {
    var pr = num($('pmPrice').value), inp = num($('pmIn').value);
    $('pmRate').textContent = pr ? '입고율 ' + (Math.round(inp / pr * 1000) / 10) + '%' : '';
  }
  function saveProduct() {
    var body = {
      jepmcd: $('pmCode').value, brand: $('pmBrand').value.trim(), jepmnm: $('pmName').value.trim(),
      price: num($('pmPrice').value), saleprice: num($('pmSale').value), inprice: num($('pmIn').value),
      chk: $('pmChk').checked ? 'Y' : 'N'
    };
    if (!body.jepmnm) { msg('제품명을 입력하세요.'); $('pmName').focus(); return; }
    if (!body.chk || body.chk === 'N') { if (!confirm('사용 안 함으로 바꾸면 제품 검색에 나오지 않아요. 저장할까요?')) return; }
    $('pmSave').disabled = true;
    api('/product/update', null, body)
      .then(function () {
        prodModal.hide();
        msg('제품 정보를 수정했어요.');
        lines.forEach(function (l) {          // 입고 목록의 같은 제품에도 반영
          if (l.jepmcd !== body.jepmcd) return;
          l.brand = body.brand; l.jepmnm = body.jepmnm; l.price = body.price;
          if (l.src === 'base') l.inprice = body.inprice;   // 기본입고가로 들어온 줄만 입고가 갱신
        });
        drawLines();
      })
      .catch(fail)
      .then(function () { $('pmSave').disabled = false; });
  }

  // 입고 목록 높이 = 화면 아래까지
  function fit() {
    var wrap = $('lineWrap');
    var top = wrap.getBoundingClientRect().top + window.pageYOffset;
    var foot = wrap.nextElementSibling.offsetHeight;
    wrap.style.height = Math.max(240, window.innerHeight - top - foot - 26) + 'px';
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    toast = new bootstrap.Toast($('toast'), { delay: 2800 });
    dtlModal = new bootstrap.Modal($('dtlModal'));
    custModal = new bootstrap.Modal($('custModal'));

    // 거래처
    $('btnCustSearch').onclick = searchCust;
    $('custKw').onkeydown = function (e) { if (e.key === 'Enter') { e.preventDefault(); searchCust(); } };
    $('btnCustNew').onclick = openNewCust;
    $('ncSave').onclick = saveNewCust;
    $('pmSave').onclick = saveProduct;
    ['pmPrice', 'pmSale', 'pmIn'].forEach(function (id) {
      $(id).addEventListener('input', pmRate);
      $(id).addEventListener('focus', function () { this.select(); });
      $(id).addEventListener('blur', function () { this.value = won(num(this.value)); pmRate(); });
    });
    loadSellers();
    $('ncHp').onkeydown = function (e) { if (e.key === 'Enter') saveNewCust(); };

    // 입고내역
    var t = new Date(), f = new Date(); f.setMonth(f.getMonth() - 3);
    $('hFrom').value = ymd(f); $('hTo').value = ymd(t);
    buildHist();
    $('ai201HistSearch').addEventListener('click', function (e) { e.preventDefault(); loadHist(); });
    document.querySelectorAll('[data-months]').forEach(function (b) { b.onclick = function () { setMonths(+b.dataset.months); }; });

    // 제품
    $('prodKw').onkeydown = function (e) { if (e.key === 'Enter') { e.preventDefault(); searchProduct(); } };
    $('lineBody').addEventListener('click', function (e) {
      var tr = e.target.closest('tr[data-i]'); if (!tr) return;
      var i = +tr.dataset.i;
      if (e.target.dataset.q) { changeQty(i, +e.target.dataset.q); return; }
      if (e.target.dataset.del) { removeLine(i); return; }
      if (e.target.dataset.edit) { openProduct(i); return; }
      if (selIdx !== i) { selIdx = i; document.querySelectorAll('#lineBody tr').forEach(function (r) { r.classList.toggle('sel', +r.dataset.i === i); }); }
    });
    $('lineBody').addEventListener('change', function (e) {
      var f = e.target.dataset.f; if (!f) return;
      var i = +e.target.closest('tr').dataset.i, l = lines[i];
      if (f === 'remk') { l.remk = e.target.value; return; }
      if (f === 'qty') l.qty = Math.max(1, num(e.target.value));
      else if (f === 'inprice') { l.inprice = Math.max(0, num(e.target.value)); l.src = 'edit'; }
      else if (f === 'rate') {   // 입고가 = 정가 × 입고율 / 100
        var r = dec(e.target.value);
        if (!l.price) { msg('정가가 없어서 입고율로 계산할 수 없어요.'); }
        else { l.inprice = Math.floor(l.price * r / 100); l.src = 'edit'; }
      }
      setTimeout(drawLines, 0);
    });
    $('lineBody').addEventListener('focusin', function (e) { if (e.target.tagName === 'INPUT') e.target.select(); });

    // 지급
    $('inDate').value = ymd(new Date());
    ['inCash', 'inDisc'].forEach(function (id) {
      $(id).addEventListener('input', calc);
      $(id).addEventListener('focus', function () { this.select(); });
      $(id).addEventListener('blur', function () { this.value = won(num(this.value)); calc(); });
    });
    $('btnPayIn').onclick = function () { var c = calc(); $('inCash').value = won(Math.max(0, c.amt - c.disc)); calc(); };
    $('btnPayAll').onclick = function () { var c = calc(); $('inCash').value = won(Math.max(0, c.mibul + c.amt - c.disc)); calc(); };
    $('btnSave').onclick = save;
    $('btnReset').onclick = function () {
      if (edit) { if (confirm('수정을 취소할까요? (저장되지 않은 내용은 지워집니다)')) resetInput(); return; }
      if ((!lines.length && !num($('inCash').value)) || confirm('입력한 입고 내용을 지울까요?')) resetInput();
    };
    $('btnDelete').onclick = deleteEdit;

    document.addEventListener('click', function (e) {
      if (!e.target.closest('#custResult') && e.target.id !== 'btnCustSearch') $('custResult').classList.add('d-none');
      if (!e.target.closest('#prodResult')) $('prodResult').classList.add('d-none');
    });

    // 단축키
    document.addEventListener('keydown', function (e) {
      if (document.querySelector('.modal.show')) return;
      if (!$('tabIn').classList.contains('active')) return;   // 입고조회 탭에서는 입고 단축키 사용 안 함
      if (e.key === 'F2') { e.preventDefault(); $('custKw').focus(); }
      else if (e.key === 'F3') { e.preventDefault(); $('prodKw').focus(); }
      else if (e.key === 'F12') { e.preventDefault(); save(); }
      else if (!/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName) || document.activeElement.id === 'prodKw' && !$('prodKw').value) {
        if (e.key === '+') { e.preventDefault(); changeQty(selIdx, 1); }
        else if (e.key === '-') { e.preventDefault(); changeQty(selIdx, -1); }
        else if (e.key === 'Delete') { e.preventDefault(); removeLine(selIdx); }
      }
    });

    window.addEventListener('resize', fit);

    // 입고조회 탭
    var lt = new Date();
    $('lFrom').value = ymd(new Date(lt.getFullYear(), lt.getMonth(), 1));   // 기본 : 이번달
    $('lTo').value = ymd(lt);
    $('tabListBtn').addEventListener('shown.bs.tab', function () {
      if (!listTable) buildList(); else { listTable.setHeight(listHeight()); listTable.redraw(); }
      loadList();
    });
    $('tabInBtn').addEventListener('shown.bs.tab', function () { fit(); if (histTable) histTable.redraw(); $('prodKw').focus(); });
    document.querySelectorAll('[data-lrange]').forEach(function (b) { b.onclick = function () { setListRange(b.dataset.lrange); }; });
    $('lKind').onchange = loadList;
    $('lKeyword').onkeydown = function (e) { if (e.key === 'Enter') loadList(); };
    $('ai201ListSearch').addEventListener('click', function (e) { e.preventDefault(); loadList(); });
    $('btnListExcel').onclick = function () {
      if (listTable) listTable.download('xlsx', '입고조회_' + $('lFrom').value + '_' + $('lTo').value + '.xlsx', { sheetName: '입고조회' });
    };
    drawCust();
    drawLines();
    fit();
    $('custKw').focus();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
