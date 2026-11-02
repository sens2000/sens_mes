<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>POS 판매</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://unpkg.com/tabulator-tables@6.2.5/dist/css/tabulator_bootstrap5.min.css" rel="stylesheet">
<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* ===== POS ===== */
  :root {
    --navy: #2d3d5c;
    --navy-soft: #e6ecf6;
    --line: #e3e7ee;
    --muted: #6b7686;
    --accent: #ffd66b;
  }
  .pos { font-size: 14px; flex: 1 1 0; min-width: 0; }
  .pos-grid { display: grid; grid-template-columns: minmax(0, 1fr) 340px; gap: 16px; }
  @media (max-width: 1100px) { .pos-grid { grid-template-columns: 1fr; } }

  .card-box { background: #fff; border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); overflow: hidden; }
  .card-head { background: var(--navy); color: #fff; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
  .card-head h6 { margin: 0; font-size: 15px; font-weight: 700; }
  .card-head .sub { margin-left: auto; font-size: 12px; opacity: .85; }
  .card-head .sub b { color: var(--accent); }

  /* 고객 */
  .cust-search { position: relative; padding: 12px 16px; border-bottom: 1px solid var(--line); }
  .cust-result { position: absolute; z-index: 20; left: 16px; right: 16px; top: calc(100% - 6px); max-height: 260px; overflow-y: auto;
                 background: #fff; border: 1px solid #ccd; border-radius: 6px; box-shadow: 0 6px 16px rgba(0,0,0,.14); }
  .cust-result button { display: grid; grid-template-columns: 90px 1fr 130px 70px; gap: 8px; width: 100%; border: 0; background: none;
                        padding: 8px 12px; text-align: left; font-size: 13px; }
  .cust-result button:hover, .cust-result button.on { background: var(--navy-soft); }
  .cust-info { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); }
  .cust-info > div { padding: 9px 16px; border-right: 1px solid var(--line); border-bottom: 1px solid var(--line); min-width: 0; }
  .cust-info > div:nth-child(4n) { border-right: 0; }
  .cust-info .k { font-size: 11px; color: var(--muted); }
  .cust-info .v { font-weight: 700; font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cust-info .v.num { text-align: right; }
  .cust-info .wide { grid-column: span 2; }
  .cust-info .wide .v { font-weight: 400; font-size: 13px; }
  .cust-empty { padding: 26px 16px; text-align: center; color: var(--muted); }
  .grade { display: inline-block; padding: 1px 9px; border-radius: 10px; font-size: 12px; font-weight: 700; border: 1px solid; }
  .grade-GOLD   { color: #9a6b00; background: #fff4d1; border-color: #e7b93c; }
  .grade-SILVER { color: #56606e; background: #eef0f3; border-color: #aab2bd; }
  .grade-YELLO  { color: #8a6d00; background: #fffbd6; border-color: #e6cf3a; }
  .grade-GREEN  { color: #1f7a4d; background: #e3f5ea; border-color: #5cbf8a; }
  .grade-회원   { color: #4a5568; background: #fff; border-color: #cbd2dc; }

  /* 제품 입력 / 판매 목록 */
  .item-input { position: relative; display: flex; gap: 8px; padding: 12px 16px; border-bottom: 1px solid var(--line); }
  .item-input input { font-size: 15px; }
  .prod-result { position: absolute; z-index: 20; left: 16px; right: 16px; top: calc(100% - 6px); max-height: 300px; overflow-y: auto;
                 background: #fff; border: 1px solid #ccd; border-radius: 6px; box-shadow: 0 6px 16px rgba(0,0,0,.14); }
  .prod-result button { display: grid; grid-template-columns: 130px 1fr 90px 90px; gap: 8px; width: 100%; border: 0; background: none;
                        padding: 8px 12px; text-align: left; font-size: 13px; }
  .prod-result button:hover, .prod-result button.on { background: var(--navy-soft); }
  .prod-result .r { text-align: right; }

  .line-wrap { overflow: auto; }
  table.lines { width: 100%; border-collapse: collapse; font-size: 14px; }
  table.lines th { position: sticky; top: 0; z-index: 2; background: var(--navy-soft); border-bottom: 2px solid #c9d3e3;
                   padding: 8px 6px; font-weight: 700; text-align: center; white-space: nowrap; }
  table.lines td { padding: 6px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  table.lines tr.sel td { background: #fff8e1; }
  table.lines .r, table.lines th.r { text-align: right; }
  table.lines .c { text-align: center; }
  table.lines .brand { color: var(--muted); font-size: 12px; margin-right: 4px; }
  table.lines input { border: 1px solid transparent; background: transparent; padding: 3px 5px; border-radius: 4px; width: 100%; }
  table.lines input:hover, table.lines input:focus { border-color: #b8c3d4; background: #fff; outline: none; }
  table.lines input.r { text-align: right; }
  .qty { display: inline-flex; align-items: center; gap: 2px; }
  .qty button { width: 24px; height: 24px; padding: 0; line-height: 1; border: 1px solid #c5ccd8; background: #fff; border-radius: 4px; }
  .qty input { width: 42px !important; text-align: center; }
  .line-empty td { text-align: center; color: var(--muted); padding: 40px 0 !important; border-bottom: 0 !important; }
  .line-foot { display: flex; gap: 18px; padding: 10px 16px; border-top: 2px solid #c9d3e3; background: #f7f9fc; font-size: 13px; }
  .line-foot b { font-size: 15px; }
  .line-foot .ms-auto { margin-left: auto; }

  /* 결제 */
  .pay { padding: 12px 16px; }
  .pay-row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; }
  .pay-row .k { color: var(--muted); }
  .pay-row .v { font-weight: 700; font-size: 16px; }
  .pay-row input { width: 140px; text-align: right; font-weight: 700; }
  .pay-total { margin: 8px -16px; padding: 12px 16px; background: var(--navy); color: #fff; display: flex; justify-content: space-between; align-items: baseline; }
  .pay-total .v { font-size: 26px; font-weight: 800; color: var(--accent); }
  .pay-btns { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 12px; }
  .pay-btns .btn { padding: 12px 0; font-weight: 700; font-size: 15px; }
  .pay-btns .full { grid-column: span 2; }
  .hint { font-size: 11px; color: var(--muted); }

  /* 탭 */
  .pos-tabs { margin-bottom: 12px; border-bottom: 1px solid #d5dbe5; align-items: center; }

  .pos-tabs .nav-link { color: #555; }
  .pos-tabs .nav-link.active { color: var(--navy); font-weight: 700; background: #fff; }

  /* 매출조회 */
  .sales-grid { display: grid; grid-template-columns: minmax(0, 1fr) 370px; gap: 16px; }
  @media (max-width: 1200px) { .sales-grid { grid-template-columns: 1fr; } }
  .s-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; padding: 12px 16px; border-bottom: 1px solid var(--line); }
  .tabulator { font-size: 13px; border: none; max-width: 100%; }
  .tabulator .tabulator-header .tabulator-col { background: var(--navy-soft); }
  .tabulator .tabulator-cell { padding: 7px 6px; }
  .tabulator .tabulator-col .tabulator-col-content { padding: 8px 6px; }
  .tabulator-row.tabulator-selected { background: #fff3c4 !important; }
  .d-empty { padding: 60px 16px; text-align: center; color: var(--muted); }
  .d-info { display: grid; grid-template-columns: 80px 1fr; gap: 4px 10px; padding: 12px 16px; border-bottom: 1px solid var(--line); font-size: 13px; }
  .d-info .k { color: var(--muted); }
  table.d-lines { width: 100%; font-size: 13px; border-collapse: collapse; }
  table.d-lines th { background: var(--navy-soft); padding: 6px; text-align: center; white-space: nowrap; }
  table.d-lines td { padding: 6px; border-bottom: 1px solid var(--line); }
  table.d-lines .r, table.d-lines th.r { text-align: right; }
  .d-sum { padding: 8px 16px 14px; }
  .d-sum .pay-row { padding: 3px 0; }
  .d-sum .pay-row .v { font-size: 14px; }
  .tabulator-row.row-cancel .tabulator-cell { color: #d9534f; }
  .tabulator-row.row-canceled .tabulator-cell { color: #9aa3af; text-decoration: line-through; }
  .tabulator-row.row-canceled .tabulator-cell:last-child { text-decoration: none; }
  .d-cancel { padding: 0 16px 16px; }
  .loading-mask { position: absolute; inset: 0; z-index: 30; background: rgba(255,255,255,.65);
                  display: flex; align-items: flex-start; justify-content: center; padding-top: 120px; }
  .loading-mask.d-none { display: none !important; }
  .loading-box { background: #fff; border: 1px solid var(--line); border-radius: 8px; padding: 12px 20px;
                 box-shadow: 0 4px 14px rgba(0,0,0,.12); font-size: 14px; color: var(--navy); font-weight: 600; }
  kbd { font-size: 10px; padding: 1px 4px; }
</style>
</head>
<body>
<script>window.CTX = '${pageContext.request.contextPath}';</script>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 pos">
    <ul class="nav nav-tabs pos-tabs" role="tablist">
      <li class="nav-item"><button class="nav-link active" id="tabSaleBtn" data-bs-toggle="tab" data-bs-target="#tabSale" type="button">판매</button></li>
      <li class="nav-item"><button class="nav-link" id="tabSalesBtn" data-bs-toggle="tab" data-bs-target="#tabSales" type="button">매출조회</button></li>
    </ul>
    <div class="tab-content">
    <div class="tab-pane fade show active" id="tabSale">
    <div class="pos-grid">

      <!-- ================= 왼쪽 : 고객 + 판매목록 ================= -->
      <div class="d-flex flex-column gap-3" style="min-width:0">

        <!-- 고객 -->
        <div class="card-box">
          <div class="card-head">
            <h6>고객</h6>
            <div class="sub" id="custHeadInfo">비회원 판매</div>
          </div>
          <div class="cust-search">
            <div class="input-group input-group-sm">
              <input type="text" class="form-control" id="custKw" placeholder="이름 또는 전화번호(뒷자리) 입력 후 Enter  ·  F2">
              <button type="button" class="btn btn-outline-secondary" id="btnCustSearch">검색</button>
              <button type="button" class="btn btn-outline-secondary" id="btnCustClear" title="비회원으로">비회원</button>
            </div>
            <div class="cust-result d-none" id="custResult"></div>
          </div>
          <div id="custBox"></div>
        </div>

        <!-- 판매 목록 -->
        <div class="card-box d-flex flex-column" style="min-height:0">
          <div class="card-head">
            <h6>판매 목록</h6>
            <div class="sub">품목 <b id="headCnt">0</b> · 수량 <b id="headQty">0</b></div>
          </div>
          <div class="item-input">
            <input type="text" class="form-control" id="prodKw" placeholder="제품코드(바코드) 스캔 또는 제품명·브랜드 입력 후 Enter  ·  F3">
            <div class="prod-result d-none" id="prodResult"></div>
          </div>
          <div class="line-wrap" id="lineWrap">
            <table class="lines">
              <colgroup>
                <col style="width:40px"><col style="width:130px"><col><col style="width:90px"><col style="width:100px">
                <col style="width:110px"><col style="width:100px"><col style="width:16%"><col style="width:40px">
              </colgroup>
              <thead>
                <tr><th>No</th><th>제품코드</th><th>브랜드 + 제품명</th><th class="r">정가</th><th class="r">판매가</th><th class="r">수량</th><th class="r">금액</th><th>비고</th><th></th></tr>
              </thead>
              <tbody id="lineBody"></tbody>
            </table>
          </div>
          <div class="line-foot">
            <span>정가합계 <b id="footPrice">0</b></span>
            <span>판매합계 <b id="footSale">0</b></span>
            <span class="ms-auto hint"><kbd>+</kbd>/<kbd>-</kbd> 선택행 수량 · <kbd>Del</kbd> 선택행 삭제</span>
          </div>
        </div>
      </div>

      <!-- ================= 오른쪽 : 결제 ================= -->
      <div>
        <div class="card-box">
          <div class="card-head"><h6>결제</h6><div class="sub" id="payDate"></div></div>
          <div class="pay">
            <div class="pay-row"><span class="k">정가 합계</span><span class="v" id="sumPrice">0</span></div>
            <div class="pay-row"><span class="k">판매 합계</span><span class="v" id="sumSale">0</span></div>
            <div class="pay-row"><span class="k">할인</span><input class="form-control form-control-sm" id="inDisc" value="0"></div>
            <div class="pay-row">
              <span class="k">포인트 사용 <span class="hint" id="pointAvail"></span></span>
              <input class="form-control form-control-sm" id="inPoint" value="0">
            </div>

            <div class="pay-total"><span>받을 금액</span><span class="v" id="sumPay">0</span></div>

            <div class="pay-row"><span class="k">현금</span><input class="form-control form-control-sm" id="inCash" value="0"></div>
            <div class="pay-row"><span class="k">카드</span><input class="form-control form-control-sm" id="inCard" value="0"></div>
            <div class="pay-row"><span class="k">거스름돈</span><span class="v text-danger" id="sumChange">0</span></div>
            <div class="pay-row"><span class="k">포인트 적립 <span class="hint" id="rateInfo"></span>
                <a href="#" class="hint ms-1 d-none" id="bonusAuto" title="계산값으로 되돌리기">↺ 자동</a></span>
              <input class="form-control form-control-sm text-success" id="inBonus" value="0" title="직접 고치면 비고에 '포인트수정'이 남습니다">
            </div>

            <div class="pay-row"><span class="k">판매자</span>
              <select class="form-select form-select-sm" id="inSeller" style="width:140px"><option value="">(로그인 사용자)</option></select>
            </div>
            <div class="mb-2 mt-1">
              <input type="text" class="form-control form-control-sm" id="inRemk" placeholder="비고 (매출 메모)">
            </div>

            <div class="pay-btns">
              <button type="button" class="btn btn-outline-primary" id="btnAllCash">전액 현금</button>
              <button type="button" class="btn btn-outline-primary" id="btnAllCard">전액 카드</button>
              <button type="button" class="btn btn-primary full" id="btnPay">결제 완료 <span class="hint text-white-50">F12</span></button>
              <button type="button" class="btn btn-outline-secondary" id="btnHold">보류</button>
              <button type="button" class="btn btn-outline-danger" id="btnReset">전체 취소</button>
            </div>
          </div>
        </div>
      </div>

    </div>
    </div><!-- /tabSale -->

    <!-- ================= 매출조회 ================= -->
    <div class="tab-pane fade" id="tabSales">
      <div class="sales-grid">
        <div class="card-box" style="min-width:0">
          <div class="card-head">
            <h6>매출조회</h6>
            <div class="sub">건수 <b id="sCnt">0</b> · 매출 <b id="sAmt">0</b> · 적립 <b id="sBonus">0</b></div>
          </div>
          <div class="s-toolbar">
            <button type="button" class="btn btn-sm btn-outline-secondary" id="sPrev" title="이전날">&lsaquo;</button>
            <input type="date" class="form-control form-control-sm" id="sDate" style="width:140px">
            <span class="fw-bold" id="sWeek" style="min-width:24px"></span>
            <button type="button" class="btn btn-sm btn-outline-secondary" id="sNext" title="다음날">&rsaquo;</button>
            <button type="button" class="btn btn-sm btn-outline-secondary" id="sToday">오늘</button>
            <select class="form-select form-select-sm" id="sKind" style="width:100px" title="구분(KIND)">
              <option value="">전체</option>
              <option value="매출">매출</option>
              <option value="WEB">WEB</option>
            </select>
            <input type="text" class="form-control form-control-sm" id="sKeyword" placeholder="회원명·전화" style="width:120px">
            <button type="button" class="btn btn-sm btn-secondary" id="ai101SalesSearch">조회</button>
            <button type="button" class="btn btn-sm btn-outline-success ms-auto" id="btnSalesExcel">엑셀</button>
          </div>
          <div style="position:relative">
            <div id="salesTable"></div>
            <div class="loading-mask d-none" id="sLoading">
              <div class="loading-box"><span class="spinner-border spinner-border-sm text-primary me-2"></span><span id="sLoadingMsg">매출을 조회하고 있어요…</span></div>
            </div>
          </div>
        </div>

        <div class="card-box" style="align-self:start">
          <div class="card-head"><h6>매출 상세</h6><div class="sub" id="dHead"></div></div>
          <div id="dBody"><div class="d-empty">왼쪽 목록에서 매출을 선택하세요.</div></div>
        </div>
      </div>
    </div><!-- /tabSales -->
    </div><!-- /tab-content -->
  </div>
</div>

<!-- 매니저 암호 -->
<div class="modal fade" id="pwModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered modal-sm">
    <div class="modal-content">
      <div class="modal-header py-2" style="background:var(--navy);color:#fff">
        <h6 class="modal-title">판매자 변경 승인</h6>
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

<!-- 회원 수정 -->
<div class="modal fade" id="memModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header py-2" style="background:var(--navy);color:#fff">
        <h6 class="modal-title" id="memTitle">회원 수정</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="row g-2">
          <div class="col-6"><label class="form-label small mb-1">성명</label><input type="text" class="form-control form-control-sm" id="mmName" maxlength="10"></div>
          <div class="col-6"><label class="form-label small mb-1">전화번호</label><input type="text" class="form-control form-control-sm" id="mmHand" maxlength="13" placeholder="010-0000-0000"></div>
          <div class="col-6"><label class="form-label small mb-1">등급</label><select class="form-select form-select-sm" id="mmGrade"></select></div>
          <div class="col-6"><label class="form-label small mb-1">담당</label><select class="form-select form-select-sm" id="mmManager"></select></div>
          <div class="col-12"><label class="form-label small mb-1">비고</label><textarea class="form-control form-control-sm" id="mmRemk" rows="3"></textarea></div>
        </div>
        <div class="hint mt-2">누적판매·포인트잔액은 판매·취소로만 바뀝니다.</div>
        <div class="small text-danger mt-1" id="mmErr"></div>
      </div>
      <div class="modal-footer py-2">
        <button type="button" class="btn btn-sm btn-secondary" data-bs-dismiss="modal">닫기</button>
        <button type="button" class="btn btn-sm btn-primary" id="mmSave">저장</button>
      </div>
    </div>
  </div>
</div>

<!-- 보류 목록 -->
<div class="modal fade" id="holdModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header py-2" style="background:var(--navy);color:#fff">
        <h6 class="modal-title">보류된 판매</h6>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body py-1" id="holdList"></div>
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
 * POS 판매 (ai101)
 *   - 고객 : member (memno, name, handno, member=등급, saleamt=누적판매, bonusamt=포인트잔액, remk, manager, lastdate)
 *   - 제품 : SHOP_JEPM_MST (JEPMCD, BRAND, JEPMNM, PRICE, SALEPRICE, INPRICE, CHK='Y')
 *   - 적립률 : CODE_MST (CODEGU='등급', SHOPNO=매장, CODENM=등급명, CASHCOST=적립률%)
 *             CASHTERM = 현금 적립률(%), CASHCOST = 카드 적립률(%)
 *             적립 포인트 = 현금 × 현금적립률 / 100 + 카드 × 카드적립률 / 100  (원 단위 버림)
 *   - 저장 : MC20_MST / MC20_DTL + member(누적판매·포인트·최근방문)  → /ai101/save
 *   - 보류 : 이 PC 브라우저에 임시 저장 (localStorage)
 * ===================================================================== */
(function () {
  'use strict';

  var API = (window.CTX || '') + '/ai101';
  var RATES = {};           // 등급 → { cash: 현금적립률(CASHTERM), card: 카드적립률(CASHCOST) }  (CODE_MST)

  var holdModal = null;
  var cust = null;          // 선택된 회원
  var lines = [];           // 판매 목록
  var selIdx = -1;          // 선택행
  var $ = function (id) { return document.getElementById(id); };

  // ---------------- 유틸 ----------------
  function num(v) { return Number(String(v == null ? '' : v).replace(/[^\d-]/g, '')) || 0; }
  function won(n) { return Number(n || 0).toLocaleString('ko-KR'); }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtTel(v) {
    var d = String(v || '').replace(/\D/g, '');
    if (d.length === 11) return d.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    if (d.length === 10) return d.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
    return v || '';
  }
  function msg(t) { $('toastMsg').textContent = t; toast.show(); }
  var toast;

  function api(path, params, body) {
    if (window.PosMock) return window.PosMock.handle(path, params, body);   // 미리보기용
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
  function fail(e) { alert(e.message || e); }

  // ---------------- 고객 ----------------
  function searchCustomer() {
    var kw = $('custKw').value.trim().replace(/-/g, '');
    if (kw.length < 2) { msg('2글자 이상 입력하세요.'); return; }
    api('/members', { keyword: kw }).then(showCustomers).catch(fail);
  }

  function showCustomers(list) {
    var box = $('custResult');
    if (!list.length) { box.innerHTML = '<div class="p-3 text-muted small">검색된 회원이 없어요.</div>'; box.classList.remove('d-none'); return; }
    if (list.length === 1) { setCustomer(list[0]); return; }
    box.innerHTML = list.map(function (m, i) {
      return '<button type="button" data-i="' + i + '"><span class="text-muted">' + esc(m.memno) + '</span><b>' + esc(m.name) + '</b>'
           + '<span>' + esc(fmtTel(m.handno)) + '</span><span><span class="grade grade-' + esc(m.grade) + '">' + esc(m.grade) + '</span></span></button>';
    }).join('');
    box.querySelectorAll('button').forEach(function (b) { b.onclick = function () { setCustomer(list[+b.dataset.i]); }; });
    box.classList.remove('d-none');
  }

  function setCustomer(m) {
    cust = m;
    $('custResult').classList.add('d-none');
    $('custKw').value = '';
    $('inPoint').value = '0';
    drawCustomer();
    calc();
    $('prodKw').focus();
  }

  function drawCustomer() {
    if (!cust) {
      $('custHeadInfo').textContent = '비회원 판매';
      $('custBox').innerHTML = '<div class="cust-empty">고객을 검색하세요. 검색하지 않으면 비회원으로 판매합니다.</div>';
      $('pointAvail').textContent = '';
      fit();
      return;
    }
    $('custHeadInfo').innerHTML = '최근방문 <b>' + esc(cust.lastdate || '-') + '</b> '
      + (cust.job === 'WEB'
         ? '<button type="button" class="btn btn-sm btn-light py-0 px-2 ms-2" id="btnMemEdit">✎ 회원 수정</button>'
         : '<span class="ms-2" title="WEB 회원만 수정할 수 있습니다">🔒 POS 회원 · 수정 불가</span>');
    if ($('btnMemEdit')) $('btnMemEdit').onclick = openEditMember;
    $('custBox').innerHTML =
        '<div class="cust-info">'
      + cell('회원번호', esc(cust.memno))
      + cell('성명', esc(cust.name))
      + cell('전화번호', esc(fmtTel(cust.handno)))
      + cell('등급', '<span class="grade grade-' + esc(cust.grade) + '">' + esc(cust.grade) + '</span> <span class="hint">' + rateText(cust.grade) + '</span>')
      + cell('누적판매', won(cust.saleamt), 'num')
      + cell('포인트잔액', won(cust.bonusamt), 'num')
      + cell('담당', esc(cust.manager || '-'))
      + cell('최근방문', esc(cust.lastdate || '-'))
      + '<div class="wide" style="grid-column: span 4"><div class="k">비고</div><div class="v">' + (esc(cust.remk) || '<span class="text-muted">-</span>') + '</div></div>'
      + '</div>';
    $('pointAvail').textContent = '(잔액 ' + won(cust.bonusamt) + ')';
    fit();
    function cell(k, v, cls) { return '<div><div class="k">' + k + '</div><div class="v ' + (cls || '') + '">' + v + '</div></div>'; }
  }

  // ---------------- 회원 수정 (job = 'WEB' 회원만 수정 가능) ----------------
  var memModal;
  function openEditMember() {
    if (!cust) return;
    if (cust.job !== 'WEB') { msg('WEB 회원만 수정할 수 있습니다.'); return; }
    var grades = Object.keys(RATES);
    var g = String(cust.grade || '').trim();
    if (g && grades.indexOf(g.toUpperCase()) < 0) grades.unshift(g);
    $('mmGrade').innerHTML = grades.map(function (n) {
      return '<option' + (n.toUpperCase() === g.toUpperCase() ? ' selected' : '') + '>' + esc(n) + '</option>';
    }).join('');
    $('mmManager').innerHTML = '<option value="">(없음)</option>' + sellerOptions(cust.manager);
    if (!cust.manager) $('mmManager').value = '';
    $('memTitle').textContent = '회원 수정 · ' + cust.memno;
    $('mmName').value = cust.name || '';
    $('mmHand').value = fmtTel(cust.handno);
    $('mmRemk').value = cust.remk || '';
    $('mmErr').textContent = '';
    if (!memModal) memModal = new bootstrap.Modal($('memModal'));
    memModal.show();
    setTimeout(function () { $('mmName').focus(); }, 300);
  }
  // 전화번호는 기존 저장 형식을 따름 (하이픈 있으면 010-0000-0000, 없으면 숫자만)
  function telSave(v, old) { return String(old || '').indexOf('-') >= 0 ? fmtTel(v) : v.replace(/\D/g, ''); }
  function saveMember() {
    var body = { memno: cust.memno, name: $('mmName').value.trim(), handno: telSave($('mmHand').value.trim(), cust.handno),
                 grade: $('mmGrade').value, manager: $('mmManager').value, remk: $('mmRemk').value.trim() };
    if (!body.name) { $('mmErr').textContent = '성명을 입력하세요.'; return; }
    if (body.handno.replace(/\D/g, '').length < 9) { $('mmErr').textContent = '전화번호를 확인하세요.'; return; }
    $('mmSave').disabled = true;
    api('/member/update', null, body)
      .then(function (m) { memModal.hide(); cust = m; drawCustomer(); calc(); msg('회원 정보를 수정했어요.'); })
      .catch(function (e) { $('mmErr').textContent = e.message || e; })
      .then(function () { $('mmSave').disabled = false; });
  }

  // ---------------- 제품 ----------------
  function searchProduct() {
    var kw = $('prodKw').value.trim();
    if (!kw) return;
    api('/products', { keyword: kw }).then(function (list) {
      // 바코드 정확히 일치하면 바로 추가
      var exact = list.filter(function (p) { return p.jepmcd === kw; })[0];
      if (exact) { addLine(exact); return; }
      showProducts(list);
    }).catch(fail);
  }

  function showProducts(list) {
    var box = $('prodResult');
    if (!list.length) { box.innerHTML = '<div class="p-3 text-muted small">검색된 제품이 없어요.</div>'; box.classList.remove('d-none'); return; }
    if (list.length === 1) { addLine(list[0]); return; }
    box.innerHTML = list.map(function (p, i) {
      return '<button type="button" data-i="' + i + '"><span class="text-muted">' + esc(p.jepmcd) + '</span>'
           + '<span><span class="text-muted">' + esc(p.brand) + '</span> <b>' + esc(p.jepmnm) + '</b></span>'
           + '<span class="r text-muted text-decoration-line-through">' + (p.price !== p.saleprice ? won(p.price) : '') + '</span>'
           + '<span class="r"><b>' + won(p.saleprice) + '</b></span></button>';
    }).join('');
    box.querySelectorAll('button').forEach(function (b) { b.onclick = function () { addLine(list[+b.dataset.i]); }; });
    box.classList.remove('d-none');
  }

  // 판매가가 100 보다 작으면 할인율로 보고  판매가 = 정가 - (정가 × 할인율 / 100)  (할인액 원 단위 버림)
  function salePriceOf(price, v) {
    v = Number(v) || 0;
    return v > 0 && v < 100 ? price - Math.floor(price * v / 100) : v;
  }

  function addLine(p) {
    $('prodResult').classList.add('d-none');
    $('prodKw').value = '';
    var sp = salePriceOf(p.price, p.saleprice);
    // 같은 제품이 이미 있으면 수량만 +1
    var i = lines.findIndex(function (l) { return l.jepmcd === p.jepmcd && l.saleprice === sp; });
    if (i >= 0) { lines[i].qty++; selIdx = i; }
    else { lines.push({ jepmcd: p.jepmcd, brand: p.brand, jepmnm: p.jepmnm, price: p.price, saleprice: sp, qty: 1, remk: '' }); selIdx = lines.length - 1; }
    drawLines();
    $('prodKw').focus();
  }

  function drawLines() {
    var tb = $('lineBody');
    if (!lines.length) {
      tb.innerHTML = '<tr class="line-empty"><td colspan="9">제품코드를 스캔하거나 제품명을 검색해서 추가하세요.</td></tr>';
    } else {
      tb.innerHTML = lines.map(function (l, i) {
        return '<tr data-i="' + i + '" class="' + (i === selIdx ? 'sel' : '') + '">'
          + '<td class="c">' + (i + 1) + '</td>'
          + '<td>' + esc(l.jepmcd) + '</td>'
          + '<td><span class="brand">' + esc(l.brand) + '</span>' + esc(l.jepmnm) + '</td>'
          + '<td class="r text-muted">' + won(l.price) + '</td>'
          + '<td><input class="r" data-f="saleprice" value="' + won(l.saleprice) + '" title="100 미만을 입력하면 할인율로 계산 : 정가 - (정가 × 입력값 / 100)"></td>'
          + '<td class="r"><span class="qty"><button type="button" data-q="-1">−</button><input data-f="qty" value="' + l.qty + '"><button type="button" data-q="1">+</button></span></td>'
          + '<td class="r fw-bold">' + won(l.saleprice * l.qty) + '</td>'
          + '<td><input data-f="remk" value="' + esc(l.remk) + '" placeholder="비고"></td>'
          + '<td class="c"><button type="button" class="btn btn-sm btn-link text-danger p-0" data-del="1" title="삭제">✕</button></td>'
          + '</tr>';
      }).join('');
    }
    calc();
    if (holdModal) drawHoldBtn();
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

  // 판매목록 높이 = 화면 아래 끝까지 (하단 합계줄 + 바깥 여백 제외)
  function fit() {
    var wrap = $('lineWrap');
    var top = wrap.getBoundingClientRect().top + window.pageYOffset;
    var foot = wrap.nextElementSibling.offsetHeight;
    wrap.style.height = Math.max(220, window.innerHeight - top - foot - 26) + 'px';
  }

  // ---------------- 계산 ----------------
  function calc() {
    var sumPrice = 0, sumSale = 0, qty = 0;
    lines.forEach(function (l) { sumPrice += l.price * l.qty; sumSale += l.saleprice * l.qty; qty += l.qty; });
    var disc = num($('inDisc').value);
    var point = num($('inPoint').value);
    if (cust && point > cust.bonusamt) { point = cust.bonusamt; $('inPoint').value = won(point); msg('포인트 잔액까지만 사용할 수 있어요.'); }
    if (!cust && point) { point = 0; $('inPoint').value = '0'; }
    var pay = Math.max(0, sumSale - disc - point);
    var cash = num($('inCash').value), card = num($('inCard').value);
    var paid = cash + card;

    // 포인트 적립 = 현금 × 현금적립률 / 100 + 카드 × 카드적립률 / 100 — 현금은 거스름돈 뺀 실제 받은 금액
    var rate = cust ? gradeRate(cust.grade) : { cash: 0, card: 0 };
    var cardNet = Math.min(card, pay);
    var cashNet = Math.max(0, Math.min(cash, pay - cardNet));
    var autoBonus = Math.floor((cashNet * rate.cash + cardNet * rate.card) / 100);
    $('rateInfo').textContent = cust ? '(' + cust.grade + ' ' + rateText(cust.grade) + ')' : '(비회원)';
    // 적립 포인트 : 직접 고친 경우 그 값을 쓰고, 아니면 자동 계산값
    if (!cust) bonusEdited = false;
    var bonus = bonusEdited ? num($('inBonus').value) : autoBonus;
    if (!bonusEdited && document.activeElement !== $('inBonus')) $('inBonus').value = won(autoBonus);
    $('inBonus').disabled = !cust;
    $('inBonus').classList.toggle('border-warning', bonusEdited && bonus !== autoBonus);
    $('bonusAuto').classList.toggle('d-none', !(bonusEdited && bonus !== autoBonus));

    $('headCnt').textContent = lines.length;
    $('headQty').textContent = qty;
    $('footPrice').textContent = won(sumPrice);
    $('footSale').textContent = won(sumSale);
    $('sumPrice').textContent = won(sumPrice);
    $('sumSale').textContent = won(sumSale);
    $('sumPay').textContent = won(pay);
    $('sumChange').textContent = won(Math.max(0, paid - pay));
    return { sumPrice: sumPrice, sumSale: sumSale, disc: disc, point: point, pay: pay, paid: paid, bonus: bonus, rate: rate,
             autoBonus: autoBonus, bonusEdited: bonusEdited && bonus !== autoBonus };
  }

  function gradeRate(g) {
    var r = RATES[String(g || '').trim().toUpperCase()];
    return { cash: r ? Number(r.cash) || 0 : 0, card: r ? Number(r.card) || 0 : 0 };
  }
  function rateText(g) { var r = gradeRate(g); return '현금 ' + r.cash + '% · 카드 ' + r.card + '%'; }

  var bonusEdited = false;   // 적립 포인트를 직접 고쳤는지
  function resetAll() {
    cust = null; lines = []; selIdx = -1; bonusEdited = false;
    ['inDisc', 'inPoint', 'inCash', 'inCard'].forEach(function (id) { $(id).value = '0'; });
    $('inRemk').value = '';
    drawCustomer(); drawLines();
    $('custKw').focus();
  }

  var paying = false;
  function pay() {
    if (paying) return;
    var c = calc();
    if (!lines.length) { msg('판매할 제품을 추가하세요.'); $('prodKw').focus(); return; }
    var cash = num($('inCash').value), card = num($('inCard').value);
    if (card > c.pay) { msg('카드 금액이 받을 금액보다 많아요.'); $('inCard').focus(); return; }
    if (cash + card < c.pay) { msg('받은 금액이 부족해요. (' + won(c.pay - cash - card) + '원 부족)'); return; }
    if (!confirm('받을 금액 ' + won(c.pay) + '원\n현금 ' + won(c.pay - card) + ' / 카드 ' + won(card)
               + (cash + card > c.pay ? '\n거스름돈 ' + won(cash + card - c.pay) : '')
               + (cust ? '\n적립 ' + won(c.bonus) + 'P' + (c.bonusEdited ? ' (포인트수정, 계산값 ' + won(c.autoBonus) + 'P)' : '') : '')
               + '\n\n결제를 완료할까요?')) return;

    var body = {
      memno: cust ? cust.memno : '',
      disc: c.disc, point: c.point, cash: cash, card: card,
      remk: $('inRemk').value.trim(),
      seller: $('inSeller').value,
      bonus: c.bonus, bonusEdited: c.bonusEdited,
      lines: lines.map(function (l) { return { jepmcd: l.jepmcd, saleprice: l.saleprice, qty: l.qty, remk: l.remk }; })
    };
    paying = true;
    $('btnPay').disabled = true;
    api('/save', null, body)
      .then(function (r) {
        var text = '결제 완료 ' + won(r.amt) + '원' + (r.change ? ' · 거스름돈 ' + won(r.change) + '원' : '')
                 + (cust ? ' · 적립 ' + won(r.bonus) + 'P (잔액 ' + won(r.bonusBal) + 'P)' : '');
        resetAll();
        msg(text);
      })
      .catch(fail)
      .then(function () { paying = false; $('btnPay').disabled = false; });
  }

  // ---------------- 보류 (이 PC 브라우저에 임시 저장) ----------------
  var HOLD_KEY = 'ai101_hold';
  function getHolds() { try { return JSON.parse(localStorage.getItem(HOLD_KEY) || '[]'); } catch (e) { return []; } }
  function setHolds(h) { try { localStorage.setItem(HOLD_KEY, JSON.stringify(h)); } catch (e) { msg('이 브라우저에서는 보류를 저장할 수 없어요.'); } drawHoldBtn(); }
  function drawHoldBtn() {
    var n = getHolds().length;
    $('btnHold').innerHTML = (lines.length ? '보류' : '보류 불러오기') + (n ? ' <span class="badge text-bg-warning">' + n + '</span>' : '');
  }
  function hold() {
    if (lines.length) {
      var h = getHolds();
      var d = new Date();
      h.push({ time: String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'),
               cust: cust, lines: lines, disc: num($('inDisc').value), remk: $('inRemk').value });
      setHolds(h);
      resetAll();
      msg('보류했어요. 빈 화면에서 [보류 불러오기]로 다시 열 수 있어요.');
      return;
    }
    var list = getHolds();
    if (!list.length) { msg('보류된 판매가 없어요.'); return; }
    $('holdList').innerHTML = list.map(function (h, i) {
      var amt = h.lines.reduce(function (s, l) { return s + l.saleprice * l.qty; }, 0);
      return '<div class="d-flex align-items-center gap-2 py-2 border-bottom">'
           + '<span class="text-muted">' + esc(h.time) + '</span>'
           + '<b>' + esc(h.cust ? h.cust.name : '비회원') + '</b>'
           + '<span class="text-muted small">' + esc(h.lines[0].jepmnm) + (h.lines.length > 1 ? ' 외 ' + (h.lines.length - 1) + '건' : '') + '</span>'
           + '<span class="ms-auto fw-bold">' + won(amt) + '</span>'
           + '<button type="button" class="btn btn-sm btn-primary" data-load="' + i + '">불러오기</button>'
           + '<button type="button" class="btn btn-sm btn-outline-danger" data-drop="' + i + '">삭제</button></div>';
    }).join('');
    holdModal.show();
  }
  function loadHold(i) {
    var h = getHolds(), x = h.splice(i, 1)[0];
    setHolds(h);
    holdModal.hide();
    resetAll();
    cust = x.cust; lines = x.lines; selIdx = lines.length - 1;
    $('inDisc').value = won(x.disc || 0);
    $('inRemk').value = x.remk || '';
    drawCustomer(); drawLines(); drawHoldBtn();
    $('prodKw').focus();
  }

  // ---------------- 매출조회 ----------------
  var salesTable = null;
  function ymd(d) { return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }

  function salesHeight() {
    var top = $('salesTable').getBoundingClientRect().top + window.pageYOffset;
    return Math.max(300, window.innerHeight - top - 26) + 'px';
  }

  function buildSales() {
    var money = function (c) { return won(c.getValue()); };
    var sumFmt = function (c) { return '<b>' + won(c.getValue()) + '</b>'; };
    salesTable = new Tabulator('#salesTable', {
      layout: 'fitColumns',
      height: salesHeight(),
      selectableRows: 1,
      placeholder: '조회된 매출이 없어요.',
      columnDefaults: { headerSort: false },
      columns: [
        { title: '일자', field: 'date', width: 64, hozAlign: 'center', formatter: function (c) { var v = c.getValue() || ''; return '<span title="' + v + '">' + v.substring(5) + '</span>'; }, bottomCalc: function () { return '합계'; } },
        { title: '시간', field: 'time', width: 60, hozAlign: 'center' },
        { title: '회원', field: 'name', minWidth: 60, formatter: function (c) { return c.getValue() ? esc(c.getValue()) : '<span class="text-muted">비회원</span>'; },
          accessorDownload: function (v) { return v || '비회원'; } },
        { title: '전화번호', field: 'handno', width: 116, formatter: function (c) { return esc(fmtTel(c.getValue())); },
          accessorDownload: function (v) { return fmtTel(v); } },
        { title: '매출', field: 'amt', width: 88, hozAlign: 'right', headerHozAlign: 'right', formatter: function (c) { return '<b>' + won(c.getValue()) + '</b>'; }, bottomCalc: 'sum', bottomCalcFormatter: sumFmt },
        { title: '현금', field: 'cash', width: 78, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '카드', field: 'card', width: 78, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '할인', field: 'disc', width: 60, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '포인트', field: 'point', width: 64, hozAlign: 'right', headerHozAlign: 'right', formatter: money, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '적립', field: 'bonus', width: 62, hozAlign: 'right', headerHozAlign: 'right', formatter: function (c) { return '<span class="text-success">' + won(c.getValue()) + '</span>'; }, bottomCalc: 'sum', bottomCalcFormatter: money },
        { title: '판매자', field: 'pruser', width: 64 },
        { title: '비고', field: 'remk', minWidth: 70, tooltip: true },
        { title: '구분', field: 'kind', width: 56, hozAlign: 'center',
          formatter: function (c) { var d = c.getData();
            return d.isCancel ? '<span class="badge text-bg-danger">취소</span>' : d.canceled ? '<span class="badge text-bg-secondary">취소됨</span>' : esc(d.kind); },
          accessorDownload: function (v, d) { return d.isCancel ? '취소' : d.canceled ? '취소됨' : v; } }
      ],
      rowFormatter: function (row) {
        var d = row.getData(), el = row.getElement();
        el.classList.toggle('row-cancel', !!d.isCancel);
        el.classList.toggle('row-canceled', !!d.canceled);
      }
    });
    salesTable.on('rowClick', function (e, row) { row.getTable().deselectRow(); row.select(); showDetail(row.getData()); });
  }

  function loadSales() {
    if (!salesTable) return;
    var d = $('sDate').value;
    $('sWeek').textContent = d ? '(' + '일월화수목금토'.charAt(new Date(d + 'T00:00:00').getDay()) + ')' : '';
    $('sLoadingMsg').textContent = d + ' 매출을 조회하고 있어요…';
    $('sLoading').classList.remove('d-none');
    $('ai101SalesSearch').disabled = true;
    $('ai101SalesSearch').textContent = '조회 중…';
    api('/sales', { from: d, to: d, kind: $('sKind').value, keyword: $('sKeyword').value.trim() })
      .then(function (list) {
        list = list || [];
        salesTable.setData(list);
        var amt = 0, bonus = 0;
        list.forEach(function (r) { amt += r.amt; bonus += r.bonus; });
        $('sCnt').textContent = won(list.length);
        msg(won(list.length) + '건 조회했어요.');
        $('sAmt').textContent = won(amt);
        $('sBonus').textContent = won(bonus);
        $('dHead').textContent = '';
        $('dBody').innerHTML = '<div class="d-empty">왼쪽 목록에서 매출을 선택하세요.</div>';
      })
      .catch(fail)
      .then(function () {
        $('sLoading').classList.add('d-none');
        $('ai101SalesSearch').disabled = false;
        $('ai101SalesSearch').textContent = '조회';
      });
  }

  function showDetail(r) {
    $('dHead').textContent = r.date + ' ' + r.time;
    $('dBody').innerHTML = '<div class="d-empty">불러오는 중…</div>';
    api('/sales/detail', { key: r.key }).then(function (lines) {
      var sum = 0, qty = 0;
      var rows = (lines || []).map(function (l) {
        sum += l.saleprice * l.qty; qty += l.qty;
        return '<tr><td>' + esc(l.jepmcd) + '</td>'
             + '<td><span class="text-muted small">' + esc(l.brand) + '</span> ' + esc(l.jepmnm)
             + (l.remk ? '<div class="small text-muted">' + esc(l.remk) + '</div>' : '') + '</td>'
             + '<td class="r">' + won(l.saleprice) + (l.price !== l.saleprice ? '<div class="small text-muted text-decoration-line-through">' + won(l.price) + '</div>' : '') + '</td>'
             + '<td class="r">' + won(l.qty) + '</td>'
             + '<td class="r fw-bold">' + won(l.saleprice * l.qty) + '</td></tr>';
      }).join('');
      var ro = r.kind !== 'WEB';   // POS 매출 : 조회만 (판매자 변경·매출 취소는 WEB 매출만 가능)
      $('dBody').innerHTML =
          '<div class="d-info">'
        + '<span class="k">회원</span><span>' + (r.name ? '<b>' + esc(r.name) + '</b> <span class="text-muted">' + esc(fmtTel(r.handno)) + ' · ' + esc(r.memno) + '</span>' : '비회원') + '</span>'
        + '<span class="k">판매자</span><span class="d-flex gap-1 align-items-center">'
        +   (ro ? '<span>' + esc(r.pruser || '-') + '</span>'
                : '<select class="form-select form-select-sm" id="dSeller" style="width:130px">' + sellerOptions(r.pruser) + '</select>'
                + '<button type="button" class="btn btn-sm btn-outline-primary" id="btnSeller">변경</button>')
        +   (r.kind ? ' <span class="text-muted">(' + esc(r.kind) + ')</span>' : '') + '</span>'
        + '<span class="k">전표</span><span class="text-muted">' + esc(r.key) + '</span>'
        + (r.remk ? '<span class="k">비고</span><span>' + esc(r.remk) + '</span>' : '')
        + '</div>'
        + '<div style="max-height:320px;overflow:auto"><table class="d-lines"><thead><tr><th>제품코드</th><th>제품</th><th class="r">판매가</th><th class="r">수량</th><th class="r">금액</th></tr></thead>'
        + '<tbody>' + (rows || '<tr><td colspan="5" class="text-center text-muted py-3">상세 내역이 없어요.</td></tr>') + '</tbody></table></div>'
        + '<div class="d-sum">'
        + row('판매 합계 (' + won(qty) + '개)', won(sum))
        + row('할인', won(r.disc))
        + row('포인트 사용', won(r.point))
        + '<div class="pay-row" style="border-top:1px solid var(--line);margin-top:4px;padding-top:6px"><span class="k">매출</span><span class="v" style="font-size:18px">' + won(r.amt) + '</span></div>'
        + row('현금', won(r.cash))
        + row('카드', won(r.card))
        + row('포인트 적립', '<span class="text-success">' + won(r.bonus) + '</span>')
        + '</div>'
        + (r.isCancel ? '<div class="d-cancel text-danger small">취소전표입니다. (원전표 ' + esc(r.cardno) + ')</div>'
          : r.canceled ? '<div class="d-cancel text-muted small">이미 취소된 매출입니다.</div>'
          : ro ? '<div class="d-cancel text-muted small">🔒 POS 매출은 조회만 가능합니다. (판매자 변경·취소는 WEB 매출만 가능)</div>'
          : r.amt > 0 ? '<div class="d-cancel"><button type="button" class="btn btn-outline-danger w-100" id="btnCancelSale">매출 취소</button>'
                       + '<div class="hint mt-1">오늘 날짜로 마이너스 전표를 만들고, 회원 누적판매·포인트를 되돌립니다.</div></div>' : '');
      if ($('btnCancelSale')) $('btnCancelSale').onclick = function () { cancelSale(r); };
      if ($('btnSeller')) $('btnSeller').onclick = function () { changeSeller(r); };
      function row(k, v) { return '<div class="pay-row"><span class="k">' + k + '</span><span class="v">' + v + '</span></div>'; }
    }).catch(fail);
  }

  // ---------------- 판매자 (user_info.chk = 'Y') ----------------
  var SELLERS = [];
  var SELLER_KEY = 'ai101_seller';
  function sellerOptions(cur) {
    var list = SELLERS.slice();
    if (cur && list.indexOf(cur) < 0) list.unshift(cur);   // 목록에 없는 기존 판매자도 표시
    return list.map(function (n) { return '<option' + (n === cur ? ' selected' : '') + '>' + esc(n) + '</option>'; }).join('');
  }
  function loadSellers() {
    api('/sellers').then(function (list) {
      SELLERS = list || [];
      var last = ''; try { last = localStorage.getItem(SELLER_KEY) || ''; } catch (e) {}
      $('inSeller').innerHTML = '<option value="">(로그인 사용자)</option>' + SELLERS.map(function (n) {
        return '<option' + (n === last ? ' selected' : '') + '>' + esc(n) + '</option>';
      }).join('');
    }).catch(fail);
  }
  // 판매자 변경 : 매니저 암호 입력 후 변경
  var pwModal = null, pwTarget = null;
  function changeSeller(r) {
    var s = $('dSeller').value;
    if (!s || s === r.pruser) { msg('바꿀 판매자를 선택하세요.'); return; }
    pwTarget = { r: r, seller: s };
    if (!pwModal) {
      pwModal = new bootstrap.Modal($('pwModal'));
      $('pwModal').addEventListener('shown.bs.modal', function () { $('pwInput').focus(); });
      $('pwOk').onclick = submitSeller;
      $('pwInput').onkeydown = function (e) { if (e.key === 'Enter') submitSeller(); };
    }
    $('pwInfo').innerHTML = '판매자 <b>' + esc(r.pruser || '-') + '</b> → <b>' + esc(s) + '</b>';
    $('pwInput').value = '';
    $('pwErr').textContent = '';
    pwModal.show();
  }
  function submitSeller() {
    var pw = $('pwInput').value;
    if (!pw) { $('pwErr').textContent = '암호를 입력하세요.'; return; }
    var t = pwTarget;
    $('pwOk').disabled = true;
    api('/seller', null, { key: t.r.key, seller: t.seller, pw: pw })
      .then(function () {
        pwModal.hide();
        msg('판매자를 ' + t.seller + '(으)로 바꿨어요.');
        t.r.pruser = t.seller;
        var row = salesTable.getRows().filter(function (x) { return x.getData().key === t.r.key; })[0];
        if (row) row.update({ pruser: t.seller });
      })
      .catch(function (e) { $('pwErr').textContent = e.message || e; $('pwInput').select(); })
      .then(function () { $('pwOk').disabled = false; });
  }

  function cancelSale(r) {
    var msgTxt = r.date + ' ' + r.time + '  ' + (r.name || '비회원') + '\n매출 ' + won(r.amt) + '원'
               + (r.memno ? '\n\n회원 누적판매 -' + won(r.amt) + ', 포인트 ' + (r.point ? '+' + won(r.point) + ' ' : '') + (r.bonus ? '-' + won(r.bonus) : '') : '')
               + '\n\n이 매출을 취소할까요? (오늘 날짜로 취소전표가 만들어집니다)';
    if (!confirm(msgTxt)) return;
    api('/cancel', null, { key: r.key })
      .then(function () {
        var t = ymd(new Date());
        msg('매출을 취소했어요.' + ($('sDate').value !== t ? ' 취소전표는 오늘(' + t + ') 날짜로 조회됩니다.' : ''));
        loadSales();
      })
      .catch(fail);
  }

  // 매출조회 : 특정일자 하루
  function setSalesDate(d) { $('sDate').value = d; loadSales(); }
  function moveSalesDate(n) {
    var d = new Date(($('sDate').value || ymd(new Date())) + 'T00:00:00');
    d.setDate(d.getDate() + n);
    setSalesDate(ymd(d));
  }

  // ---------------- 이벤트 ----------------
  function init() {
    if (typeof checkLogin === 'function') checkLogin();
    toast = new bootstrap.Toast($('toast'), { delay: 2500 });
    var d = new Date();
    $('payDate').textContent = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    // 상단바 일자·요일은 공통(menu_script.jspf)에서 표시 — 여기서는 결제 칸 날짜만 자정 지나면 갱신
    var showSaleDate = function () { $('payDate').textContent = ymd(new Date()); };
    showSaleDate();
    setInterval(showSaleDate, 60 * 1000);

    $('btnCustSearch').onclick = searchCustomer;
    $('btnCustClear').onclick = function () { cust = null; $('inPoint').value = '0'; drawCustomer(); calc(); };
    $('custKw').onkeydown = function (e) { if (e.key === 'Enter') { e.preventDefault(); searchCustomer(); } };
    $('prodKw').onkeydown = function (e) { if (e.key === 'Enter') { e.preventDefault(); searchProduct(); } };

    // 판매목록 : 행 선택, 수량 버튼, 삭제, 직접 수정
    $('lineBody').addEventListener('click', function (e) {
      var tr = e.target.closest('tr[data-i]'); if (!tr) return;
      var i = +tr.dataset.i;
      if (e.target.dataset.q) { changeQty(i, +e.target.dataset.q); return; }
      if (e.target.dataset.del) { removeLine(i); return; }
      if (selIdx !== i) { selIdx = i; document.querySelectorAll('#lineBody tr').forEach(function (r) { r.classList.toggle('sel', +r.dataset.i === i); }); }
    });
    $('lineBody').addEventListener('change', function (e) {
      var f = e.target.dataset.f; if (!f) return;
      var i = +e.target.closest('tr').dataset.i;
      if (f === 'remk') { lines[i].remk = e.target.value; return; }
      var v = num(e.target.value);
      if (f === 'qty') v = Math.max(1, v);
      if (f === 'saleprice') {
        var rate = v;
        v = salePriceOf(lines[i].price, v);
        if (rate > 0 && rate < 100) msg('할인율 ' + rate + '% 적용 : ' + won(lines[i].price) + ' → ' + won(v) + '원');
      }
      lines[i][f] = v;
      setTimeout(drawLines, 0);   // 입력칸이 포커스를 잃는 중에 다시 그리면 브라우저 오류가 나서 한 박자 늦춤
    });

    ['inDisc', 'inPoint', 'inCash', 'inCard'].forEach(function (id) {
      $(id).addEventListener('input', calc);
      $(id).addEventListener('focus', function () { this.select(); });
      $(id).addEventListener('blur', function () { this.value = won(num(this.value)); calc(); });
    });
    // 적립 포인트 직접 수정
    $('inBonus').addEventListener('input', function () { bonusEdited = true; calc(); });
    $('inBonus').addEventListener('focus', function () { this.select(); });
    $('inBonus').addEventListener('blur', function () { this.value = won(num(this.value)); calc(); });
    $('bonusAuto').onclick = function (e) { e.preventDefault(); bonusEdited = false; calc(); };
    $('btnAllCash').onclick = function () { var c = calc(); $('inCash').value = won(c.pay); $('inCard').value = '0'; calc(); };
    $('btnAllCard').onclick = function () { var c = calc(); $('inCard').value = won(c.pay); $('inCash').value = '0'; calc(); };
    $('btnPay').onclick = pay;
    $('btnReset').onclick = function () { if (!lines.length || confirm('입력한 내용을 모두 지울까요?')) resetAll(); };
    $('btnHold').onclick = hold;

    // 매출조회 탭
    $('sDate').value = ymd(new Date());
    $('sDate').onchange = function () { if (this.value) loadSales(); };
    $('sPrev').onclick = function () { moveSalesDate(-1); };
    $('sNext').onclick = function () { moveSalesDate(1); };
    $('sToday').onclick = function () { setSalesDate(ymd(new Date())); };
    $('tabSalesBtn').addEventListener('shown.bs.tab', function () {
      if (!salesTable) buildSales(); else { salesTable.setHeight(salesHeight()); salesTable.redraw(); }
      loadSales();
    });
    $('tabSaleBtn').addEventListener('shown.bs.tab', function () { fit(); $('prodKw').focus(); });
    $('ai101SalesSearch').addEventListener('click', function (e) { e.preventDefault(); loadSales(); });
    $('sKeyword').onkeydown = function (e) { if (e.key === 'Enter') loadSales(); };
    $('sKind').onchange = loadSales;
    $('btnSalesExcel').onclick = function () {
      if (salesTable) salesTable.download('xlsx', '매출조회_' + $('sDate').value + '.xlsx', { sheetName: '매출조회' });
    };
    holdModal = new bootstrap.Modal($('holdModal'));
    $('mmSave').onclick = saveMember;
    $('holdList').addEventListener('click', function (e) {
      if (e.target.dataset.load) loadHold(+e.target.dataset.load);
      else if (e.target.dataset.drop && confirm('이 보류 건을 삭제할까요?')) {
        var h = getHolds(); h.splice(+e.target.dataset.drop, 1); setHolds(h);
        if (!h.length) holdModal.hide(); else { holdModal.hide(); hold(); }
      }
    });

    document.addEventListener('click', function (e) {
      if (!e.target.closest('#custResult') && e.target.id !== 'btnCustSearch') $('custResult').classList.add('d-none');
      if (!e.target.closest('#prodResult')) $('prodResult').classList.add('d-none');
    });

    // 단축키
    document.addEventListener('keydown', function (e) {
      if (!$('tabSale').classList.contains('active')) return;   // 매출조회 탭에서는 판매 단축키 사용 안 함
      if (e.key === 'F2') { e.preventDefault(); $('custKw').focus(); }
      else if (e.key === 'F3') { e.preventDefault(); $('prodKw').focus(); }
      else if (e.key === 'F12') { e.preventDefault(); pay(); }
      else if (!/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName) || document.activeElement.id === 'prodKw' && !$('prodKw').value) {
        if (e.key === '+') { e.preventDefault(); changeQty(selIdx, 1); }
        else if (e.key === '-') { e.preventDefault(); changeQty(selIdx, -1); }
        else if (e.key === 'Delete') { e.preventDefault(); removeLine(selIdx); }
      }
    });

    window.addEventListener('resize', fit);

    drawCustomer();
    drawLines();
    drawHoldBtn();
    fit();
    $('custKw').focus();
    api('/rates').then(function (r) { RATES = r || {}; if (cust) drawCustomer(); calc(); }).catch(fail);
    loadSellers();
    $('inSeller').onchange = function () { try { localStorage.setItem(SELLER_KEY, this.value); } catch (e) {} };
  }

  document.addEventListener('DOMContentLoaded', init);
})();
</script>
</body>
</html>
