<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<c:set var="newsList" value="${data.news}"/>
<c:set var="dayList"  value="${data.day}"/>
<c:set var="shopList" value="${data.shop}"/>
<c:set var="myShopNo" value="${sessionScope.USER.SHOPNO}"/>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title></title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">

<style>
<%@ include file="/WEB-INF/common/menu_style.jspf" %>

  /* 표가 넓어져도 왼쪽 메뉴를 밀어내지 않도록 */
  .news-main { min-width:0; flex:1 1 0; overflow-x:auto; }
  div:has(> .news-main) > :not(.news-main) { flex-shrink:0; }

  /* ===== 박스 ===== */
  .box-card { border:0; border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,.08); height:100%; }
  .box-card .card-header {
    background:#2f3e5c; color:#ffffff; border-bottom:0;
    border-radius:10px 10px 0 0; font-weight:700; padding:.75rem 1rem;
  }
  .box-card .card-header .text-muted { color:#c9d3e6 !important; }
  .box-card .card-header b { color:#ffd166; }
  .box-scroll { overflow-y:auto; }

  /* 위 1/3 : 공지·매장별, 아래 2/3 : 일자별 */
  .top-scroll    { height:calc((100vh - 330px) / 3);     min-height:160px; }
  .bottom-scroll { height:calc((100vh - 330px) * 2 / 3); min-height:260px; }

  /* ===== 표 공통 머리줄 ===== */
  .box-card thead th {
    --bs-table-bg:#e8eef8;
    --bs-table-color:#2f3e5c;
    font-weight:700;
    border-bottom:2px solid #9fb3d6;
    position:sticky; top:0; z-index:1;
  }

  /* ===== 공지 ===== */
  #newsTable { table-layout:fixed; }
  #newsTable tbody tr.news-row { cursor:pointer; }
  #newsTable td { vertical-align:middle; }
  .col-no   { width:46px;  text-align:center; }
  .col-date { width:100px; text-align:center; }
  .news-title, .news-preview { overflow:hidden; white-space:nowrap; text-overflow:ellipsis; }
  .news-title { color:#1d4ed8; }
  #newsTable tbody tr.news-row:hover .news-title { color:#0a3aa8; text-decoration:underline; }
  .news-preview { color:#6c757d; font-size:.82rem; }
  .news-full { display:none; }
  #newsContent { white-space:pre-wrap; line-height:1.7; min-height:150px; }
  .col-file { width:42px; text-align:center; }
  #newsTable tbody tr.mine .news-title::after { content:' ✎'; font-size:.8em; color:#9aa8c2; }
  .clip { font-size:1rem; }
  .btn-news-add { --bs-btn-padding-y:.1rem; --bs-btn-padding-x:.6rem; --bs-btn-font-size:.8rem; font-weight:700; }
  #newsFile a { word-break:break-all; }
  #fCur { font-size:.85rem; }

  /* ===== 매출표 (매장별 / 일자별) 공통 ===== */
  .num-table { font-size:.88rem; }
  .num-table th { text-align:right; white-space:nowrap; }
  .num-table th:first-child { text-align:center; }
  .num-table td { text-align:right; white-space:nowrap; }
  .num-table td.c { text-align:center; }
  .num-table td.l { text-align:left; }
  .num-table tfoot td {
    --bs-table-bg:#dfe7f5;
    --bs-table-color:#2f3e5c;
    font-weight:700; position:sticky; bottom:0;
  }
  /* 내 매장 강조 */
  .num-table tr.my-shop td { --bs-table-bg:#fff7db; font-weight:700; }

  /* 정렬 */
  .sortable thead th { cursor:pointer; user-select:none; }
  .sortable thead th:hover { --bs-table-bg:#d6e1f3; }
  .sortable thead th::after { content:"↕"; margin-left:4px; font-size:.75em; color:#9fb3d6; }
  .sortable thead th.asc::after  { content:"▲"; color:#2f3e5c; }
  .sortable thead th.desc::after { content:"▼"; color:#2f3e5c; }
</style>
</head>
<body>

<%@ include file="/WEB-INF/common/menu_nav.jspf" %>

  <!-- 콘텐츠 영역 -->
  <div class="flex-grow-1 p-4 news-main">
    <div class="d-flex justify-content-between align-items-center mb-3">
      <h4 class="fw-bold mb-0"></h4>
      <span class="text-muted small"><c:out value="${sessionScope.USER.SHOPNAME}"/></span>
    </div>

    <div class="row g-3">

      <!-- ===== 왼쪽 위 : 공지사항 ===== -->
      <div class="col-12 col-xl-6">
        <div class="card box-card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <span>공지사항</span>
            <span class="d-flex align-items-center gap-2">
              <span class="small text-muted fw-normal">총 <b id="newsCount">${fn:length(newsList)}</b>건</span>
              <button type="button" class="btn btn-warning btn-news-add" id="btnNewsAdd">공지 등록 · 수정</button>
            </span>
          </div>
          <div class="card-body p-2">
            <input type="text" id="searchText" class="form-control form-control-sm mb-2" placeholder="제목·내용 검색">

            <div class="box-scroll top-scroll">
              <table class="table table-hover table-sm mb-0" id="newsTable">
                <thead>
                  <tr>
                    <th class="col-no">번호</th>
                    <th>제목 / 내용</th>
                    <th class="col-file" title="첨부파일">첨부</th>
                    <th class="col-date">등록일</th>
                    <th class="col-date">종료일</th>
                  </tr>
                </thead>
                <tbody>
                <c:choose>
                  <c:when test="${empty newsList}">
                    <tr><td colspan="5" class="text-center text-muted py-5">등록된 공지사항이 없습니다.</td></tr>
                  </c:when>
                  <c:otherwise>
                    <c:forEach var="n" items="${newsList}" varStatus="st">
                      <c:set var="endDate"  value="${n.END_DATE}"/>
                      <c:set var="newsDate" value="${n.NEWS_DATE}"/>
                      <tr class="news-row" data-key="<c:out value='${n.NEWS_KEY}'/>" data-shop="<c:out value='${n.SHOPNO}'/>"
                          data-file="<c:out value='${n.FILENAME}'/>" data-end="<c:out value='${endDate}'/>">
                        <td class="col-no">${st.count}</td>
                        <td>
                          <div class="fw-bold news-title"><c:out value="${n.TITLE}"/></div>
                          <div class="news-preview"><c:out value="${n.CONTENT}"/></div>
                        </td>
                        <td class="col-file"></td>
                        <td class="col-date"><c:if test="${fn:length(newsDate) >= 8}">${fn:substring(newsDate,0,4)}-${fn:substring(newsDate,4,6)}-${fn:substring(newsDate,6,8)}</c:if></td>
                        <td class="col-date news-end"><c:if test="${fn:length(endDate) >= 8}">${fn:substring(endDate,0,4)}-${fn:substring(endDate,4,6)}-${fn:substring(endDate,6,8)}</c:if></td>
                        <%-- 팝업용 원본 데이터 --%>
                        <td class="news-full">
                          <span class="d-news"><c:if test="${fn:length(newsDate) >= 8}">${fn:substring(newsDate,0,4)}-${fn:substring(newsDate,4,6)}-${fn:substring(newsDate,6,8)}</c:if></span>
                          <span class="d-content"><c:out value="${n.CONTENT}"/></span>
                        </td>
                      </tr>
                    </c:forEach>
                  </c:otherwise>
                </c:choose>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- ===== 오른쪽 위 : 매장별 매출 (오늘) ===== -->
      <div class="col-12 col-xl-6">
        <div class="card box-card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <span>매장별 매출</span>
            <span class="d-flex align-items-center gap-2">
              <span class="small text-muted fw-normal">단위: 원 <span id="shopTime"></span></span>
              <input type="date" id="shopDate" class="form-control form-control-sm" style="width:140px">
              <button type="button" class="btn btn-warning btn-news-add" id="btnShopReload">재조회</button>
            </span>
          </div>
          <div class="card-body p-2">
            <div class="box-scroll top-scroll table-responsive" style="height:calc((100vh - 330px) / 3 + 39px);">
              <table class="table table-hover table-sm mb-0 num-table sortable" id="shopTable" data-text-cols="0">
                <thead>
                  <tr>
                    <th>매장명</th>
                    <th>매출</th>
                    <th>현금</th>
                    <th>카드</th>
                    <th>할인</th>
                    <th>방문수</th>
                    <th>객단가</th>
                  </tr>
                </thead>
                <tbody>
                <c:set var="sAmt"   value="0"/>
                <c:set var="sCash"  value="0"/>
                <c:set var="sCard"  value="0"/>
                <c:set var="sSale"  value="0"/>
                <c:set var="sVisit" value="0"/>
                <c:choose>
                  <c:when test="${empty shopList}">
                    <tr><td colspan="7" class="c text-muted py-5">오늘 매출 자료가 없습니다.</td></tr>
                  </c:when>
                  <c:otherwise>
                    <c:forEach var="s" items="${shopList}">
                      <c:set var="cash"  value="${empty s.CASHAMT  ? 0 : s.CASHAMT}"/>
                      <c:set var="card"  value="${empty s.CARDAMT  ? 0 : s.CARDAMT}"/>
                      <c:set var="visit" value="${empty s.VISITCNT ? 0 : s.VISITCNT}"/>
                      <%-- SHOPNO는 화면에 표시하지 않고 내 매장 강조에만 사용 --%>
                      <tr class="${s.SHOPNO eq myShopNo ? 'my-shop' : ''}" data-shopno="<c:out value='${s.SHOPNO}'/>">
                        <td class="l"><c:out value="${s.SHOPNAME}"/></td>
                        <td class="fw-bold"><fmt:formatNumber value="${s.AMT}"     pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${cash}"                        pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${card}"                        pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${s.SALEAMT}"                   pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${visit}"                       pattern="#,##0"/></td>
                        <td><c:choose>
                              <c:when test="${visit > 0}"><fmt:formatNumber value="${(cash + card) / visit}" pattern="#,##0"/></c:when>
                              <c:otherwise>0</c:otherwise>
                            </c:choose></td>
                      </tr>
                      <c:set var="sAmt"   value="${sAmt   + (empty s.AMT     ? 0 : s.AMT)}"/>
                      <c:set var="sCash"  value="${sCash  + cash}"/>
                      <c:set var="sCard"  value="${sCard  + card}"/>
                      <c:set var="sSale"  value="${sSale  + (empty s.SALEAMT ? 0 : s.SALEAMT)}"/>
                      <c:set var="sVisit" value="${sVisit + visit}"/>
                    </c:forEach>
                  </c:otherwise>
                </c:choose>
                </tbody>
                <c:if test="${not empty shopList}">
                <tfoot>
                  <tr>
                    <td class="c">합계</td>
                    <td><fmt:formatNumber value="${sAmt}"   pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${sCash}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${sCard}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${sSale}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${sVisit}" pattern="#,##0"/></td>
                    <td><c:choose>
                          <c:when test="${sVisit > 0}"><fmt:formatNumber value="${(sCash + sCard) / sVisit}" pattern="#,##0"/></c:when>
                          <c:otherwise>0</c:otherwise>
                        </c:choose></td>
                  </tr>
                </tfoot>
                </c:if>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- ===== 아래 : 일자별 매출현황 ===== -->
      <div class="col-12">
        <div class="card box-card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <span>매출현황</span>
            <span class="small text-muted fw-normal">최근 10일 · 단위: 원</span>
          </div>
          <div class="card-body p-2">
            <div class="box-scroll bottom-scroll table-responsive">
              <table class="table table-hover table-sm mb-0 num-table sortable" id="salesTable" data-text-cols="0">
                <thead>
                  <tr>
                    <th>일자</th>
                    <th>매출</th>
                    <th>현금</th>
                    <th>카드</th>
                    <th>할인</th>
                    <th>포인트사용</th>
                    <th>포인트누적</th>
                    <th>방문수</th>
                    <th>객단가</th>
                  </tr>
                </thead>
                <tbody>
                <c:set var="tAmt"   value="0"/>
                <c:set var="tCash"  value="0"/>
                <c:set var="tCard"  value="0"/>
                <c:set var="tSale"  value="0"/>
                <c:set var="tBUse"  value="0"/>
                <c:set var="tBAmt"  value="0"/>
                <c:set var="tVisit" value="0"/>
                <c:choose>
                  <c:when test="${empty dayList}">
                    <tr><td colspan="9" class="c text-muted py-5">매출 자료가 없습니다.</td></tr>
                  </c:when>
                  <c:otherwise>
                    <c:forEach var="d" items="${dayList}">
                      <c:set var="chDate" value="${d.CHDATE}"/>
                      <c:set var="cash"   value="${empty d.CASHAMT  ? 0 : d.CASHAMT}"/>
                      <c:set var="card"   value="${empty d.CARDAMT  ? 0 : d.CARDAMT}"/>
                      <c:set var="visit"  value="${empty d.VISITCNT ? 0 : d.VISITCNT}"/>
                      <tr>
                        <td class="c"><c:if test="${fn:length(chDate) >= 8}">${fn:substring(chDate,0,4)}-${fn:substring(chDate,4,6)}-${fn:substring(chDate,6,8)}</c:if></td>
                        <td class="fw-bold"><fmt:formatNumber value="${d.AMT}"      pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${cash}"                         pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${card}"                         pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${d.SALEAMT}"                    pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${d.BONUSUSE}"                   pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${d.BONUSAMT}"                   pattern="#,##0"/></td>
                        <td><fmt:formatNumber value="${visit}"                        pattern="#,##0"/></td>
                        <td><c:choose>
                              <c:when test="${visit > 0}"><fmt:formatNumber value="${(cash + card) / visit}" pattern="#,##0"/></c:when>
                              <c:otherwise>0</c:otherwise>
                            </c:choose></td>
                      </tr>
                      <c:set var="tAmt"   value="${tAmt   + (empty d.AMT      ? 0 : d.AMT)}"/>
                      <c:set var="tCash"  value="${tCash  + cash}"/>
                      <c:set var="tCard"  value="${tCard  + card}"/>
                      <c:set var="tSale"  value="${tSale  + (empty d.SALEAMT  ? 0 : d.SALEAMT)}"/>
                      <c:set var="tBUse"  value="${tBUse  + (empty d.BONUSUSE ? 0 : d.BONUSUSE)}"/>
                      <c:set var="tBAmt"  value="${tBAmt  + (empty d.BONUSAMT ? 0 : d.BONUSAMT)}"/>
                      <c:set var="tVisit" value="${tVisit + visit}"/>
                    </c:forEach>
                  </c:otherwise>
                </c:choose>
                </tbody>
                <c:if test="${not empty dayList}">
                <tfoot>
                  <tr>
                    <td class="c">합계</td>
                    <td><fmt:formatNumber value="${tAmt}"   pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${tCash}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${tCard}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${tSale}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${tBUse}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${tBAmt}"  pattern="#,##0"/></td>
                    <td><fmt:formatNumber value="${tVisit}" pattern="#,##0"/></td>
                    <td><c:choose>
                          <c:when test="${tVisit > 0}"><fmt:formatNumber value="${(tCash + tCard) / tVisit}" pattern="#,##0"/></c:when>
                          <c:otherwise>0</c:otherwise>
                        </c:choose></td>
                  </tr>
                </tfoot>
                </c:if>
              </table>
            </div>
          </div>
        </div>
      </div>

    </div>
  </div>
</div>

<!-- 공지 상세 -->
<div class="modal fade" id="newsModal" tabindex="-1">
  <div class="modal-dialog modal-lg modal-dialog-scrollable">
    <div class="modal-content">
      <div class="modal-header">
        <div>
          <h5 class="modal-title fw-bold" id="newsTitle"></h5>
          <div class="small text-muted mt-1" id="newsMeta"></div>
        </div>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div id="newsContent"></div>
        <div id="newsFile" class="mt-3 pt-2 border-top small d-none">📎 첨부파일 : <a href="#" id="newsFileLink"></a></div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline-danger btn-sm me-auto d-none" id="btnNewsDel">삭제</button>
        <button type="button" class="btn btn-outline-primary btn-sm d-none" id="btnNewsEdit">수정</button>
        <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">닫기</button>
      </div>
    </div>
  </div>
</div>

<!-- 공지 등록 · 수정 · 삭제 (왼쪽 : 우리 매장 공지 목록, 오른쪽 : 입력) -->
<div class="modal fade" id="newsEditModal" tabindex="-1">
  <div class="modal-dialog modal-xl modal-dialog-scrollable">
    <div class="modal-content">
      <div class="modal-header" style="background:#2f3e5c;color:#fff">
        <h5 class="modal-title fw-bold">공지 관리 <span class="badge ms-2" id="eMode" style="background:#ffd166;color:#2f3e5c">새 공지</span></h5>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">
        <div class="row g-3">
          <!-- 우리 매장 공지 목록 -->
          <div class="col-lg-5">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <span class="small fw-bold text-muted">우리 매장 공지 <b id="mCnt">0</b>건</span>
              <button type="button" class="btn btn-sm btn-outline-primary" id="btnNewsNew">+ 새로 작성</button>
            </div>
            <div class="border rounded" style="height:420px;overflow:auto">
              <table class="table table-hover table-sm mb-0" id="mineTable" style="table-layout:fixed;font-size:.88rem">
                <thead><tr><th style="width:92px" class="text-center">등록일</th><th>제목</th><th style="width:30px"></th><th style="width:92px" class="text-center">종료일</th></tr></thead>
                <tbody></tbody>
              </table>
            </div>
            <div class="small text-muted mt-1">줄을 누르면 오른쪽에서 수정 · 삭제할 수 있어요.</div>
          </div>
          <!-- 입력 -->
          <div class="col-lg-7">
            <div class="mb-2">
              <label class="form-label small text-muted mb-1" for="eTitle">제목 <span class="text-danger">*</span></label>
              <input type="text" class="form-control" id="eTitle" maxlength="100">
            </div>
            <div class="mb-2">
              <label class="form-label small text-muted mb-1" for="eContent">내용</label>
              <textarea class="form-control" id="eContent" rows="10"></textarea>
            </div>
            <div class="row g-2">
              <div class="col-sm-5">
                <label class="form-label small text-muted mb-1" for="eEnd">게시 종료일 <span class="text-danger">*</span></label>
                <input type="date" class="form-control" id="eEnd">
              </div>
              <div class="col-sm-7">
                <label class="form-label small text-muted mb-1" for="eFile">첨부파일 (10MB 까지)</label>
                <input type="file" class="form-control" id="eFile">
                <div id="fCur" class="mt-1 d-none">현재 : <a href="#" id="fCurName" target="_blank"></a>
                  <label class="ms-2 text-danger"><input type="checkbox" id="eRemoveFile"> 첨부 삭제</label></div>
              </div>
            </div>
            <div class="small text-muted mt-2" id="eMeta"></div>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline-danger me-auto d-none" id="btnNewsDelM">삭제</button>
        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">닫기</button>
        <button type="button" class="btn btn-primary" id="btnNewsSave">등록</button>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<%@ include file="/WEB-INF/common/menu_script.jspf" %>

<script>
  /* 표 제목 클릭 정렬 (data-text-cols: 문자로 비교할 열 번호) */
  function makeSortable(table) {
    const body  = table.tBodies[0];
    const heads = table.querySelectorAll("thead th");
    const textCols = (table.dataset.textCols || "").split(",").map(Number);
    const box = table.closest(".box-scroll");

    function cellValue(tr, idx) {
      const t = tr.cells[idx].textContent.trim();
      if (textCols.includes(idx)) return t;
      const n = parseFloat(t.replace(/,/g, ""));
      return isNaN(n) ? 0 : n;
    }

    heads.forEach(function (th, idx) {
      th.addEventListener("click", function () {
        const rows = Array.from(body.rows).filter(function (r) { return r.cells.length > 1; });
        if (rows.length < 2) return;

        const asc = !th.classList.contains("asc");
        heads.forEach(function (h) { h.classList.remove("asc", "desc"); });
        th.classList.add(asc ? "asc" : "desc");

        rows.sort(function (a, b) {
          const x = cellValue(a, idx), y = cellValue(b, idx);
          const r = textCols.includes(idx) ? x.localeCompare(y, "ko") : (x - y);
          return asc ? r : -r;
        });
        rows.forEach(function (r) { body.appendChild(r); });
        if (box) box.scrollTop = 0;
      });
    });
  }

  /* ===== 공지 등록 · 수정 · 삭제 (s_news_Controller) ===== */
  const CTX = '${pageContext.request.contextPath}';
  const MY_SHOP = '<c:out value="${myShopNo}"/>';
  const MAX_FILE = 10 * 1024 * 1024;
  let curNews = null, editKey = "";

  function newsApi(path, body) {
    return fetch(CTX + "/s_news/" + path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) { if (!res.ok) throw new Error(res.msg || "처리 중 오류가 발생했습니다."); return res.data; });
  }
  function ymdInput(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); }
  function toInput(s) { s = String(s || "").replace(/-/g, ""); return s.length >= 8 ? s.substr(0, 4) + "-" + s.substr(4, 2) + "-" + s.substr(6, 2) : ""; }

  let mineList = [], changed = false;

  /** 공지 관리 창 열기 — tr 이 있으면 그 공지를 선택한 채로 */
  function openEdit(tr) {
    changed = false;
    fillForm(null);
    bootstrap.Modal.getOrCreateInstance(document.getElementById("newsEditModal")).show();
    loadMine(tr ? tr.dataset.key : "");
  }

  function loadMine(selectKey) {
    const body = document.querySelector("#mineTable tbody");
    body.innerHTML = '<tr><td colspan="4" class="text-center text-muted py-4">불러오는 중…</td></tr>';
    return fetch(CTX + "/s_news/mine")
      .then(function (r) { return r.json(); })
      .then(function (res) {
        if (!res.ok) throw new Error(res.msg || "목록을 불러오지 못했습니다.");
        mineList = res.data || [];
        document.getElementById("mCnt").textContent = mineList.length;
        drawMine();
        const hit = selectKey ? mineList.filter(function (m) { return m.news_key === selectKey; })[0] : null;
        if (hit) fillForm(hit);
      })
      .catch(function (e) { body.innerHTML = '<tr><td colspan="4" class="text-center text-danger py-4"></td></tr>'; body.querySelector("td").textContent = e.message || e; });
  }

  function drawMine() {
    const body = document.querySelector("#mineTable tbody");
    if (!mineList.length) { body.innerHTML = '<tr><td colspan="4" class="text-center text-muted py-4">우리 매장이 등록한 공지가 없어요.</td></tr>'; return; }
    const today = ymdInput(new Date()).replace(/-/g, "");
    body.innerHTML = "";
    mineList.forEach(function (m) {
      const tr = document.createElement("tr");
      tr.style.cursor = "pointer";
      if (m.news_key === editKey) tr.className = "table-primary";
      const ended = m.end_date && m.end_date < today;
      tr.innerHTML = '<td class="text-center"></td><td class="text-truncate fw-bold"></td><td class="text-center">' + (m.filename ? "📎" : "") + '</td><td class="text-center"></td>';
      tr.cells[0].textContent = toInput(m.news_date);
      tr.cells[1].textContent = m.title;
      tr.cells[1].title = m.title;
      tr.cells[3].textContent = toInput(m.end_date);
      if (ended) { tr.cells[3].className = "text-center text-danger"; tr.cells[3].title = "게시 종료"; }
      tr.addEventListener("click", function () { fillForm(m); drawMine(); });
      body.appendChild(tr);
    });
  }

  /** 오른쪽 입력칸 채우기 (m 이 없으면 새 공지) */
  function fillForm(m) {
    editKey = m ? m.news_key : "";
    document.getElementById("eMode").textContent = m ? "수정" : "새 공지";
    document.getElementById("btnNewsSave").textContent = m ? "수정 저장" : "등록";
    document.getElementById("btnNewsDelM").classList.toggle("d-none", !m);
    document.getElementById("eTitle").value   = m ? m.title : "";
    document.getElementById("eContent").value = m ? (m.content || "") : "";
    const end = new Date(); end.setDate(end.getDate() + 30);          // 기본 30일 게시
    document.getElementById("eEnd").value = m ? toInput(m.end_date) : ymdInput(end);
    document.getElementById("eFile").value = "";
    document.getElementById("eRemoveFile").checked = false;
    const file = m ? (m.filename || "") : "";
    document.getElementById("fCur").classList.toggle("d-none", !file);
    const link = document.getElementById("fCurName");
    link.textContent = file;
    link.href = m ? CTX + "/s_news/file?key=" + encodeURIComponent(m.news_key) : "#";
    document.getElementById("eMeta").textContent = m
      ? "등록 " + toInput(m.news_date) + (m.news_time && m.news_time.length >= 4 ? " " + m.news_time.substr(0, 2) + ":" + m.news_time.substr(2, 2) : "")
      : "등록일은 오늘로 저장됩니다.";
    setTimeout(function () { document.getElementById("eTitle").focus(); }, 300);
  }

  function readFile(f) {
    return new Promise(function (ok, no) {
      if (!f) return ok(null);
      if (f.size > MAX_FILE) return no(new Error("첨부파일은 10MB 까지 올릴 수 있습니다."));
      const rd = new FileReader();
      rd.onload = function () { ok({ name: f.name, data: String(rd.result).split(",")[1] || "" }); };
      rd.onerror = function () { no(new Error("파일을 읽지 못했습니다.")); };
      rd.readAsDataURL(f);
    });
  }

  function saveNews() {
    const title = document.getElementById("eTitle").value.trim();
    const end   = document.getElementById("eEnd").value;
    if (!title) { alert("제목을 입력하세요."); document.getElementById("eTitle").focus(); return; }
    if (!end)   { alert("게시 종료일을 입력하세요."); document.getElementById("eEnd").focus(); return; }
    const btn = document.getElementById("btnNewsSave");
    btn.disabled = true; btn.textContent = "저장 중…";
    readFile(document.getElementById("eFile").files[0])
      .then(function (f) {
        return newsApi("save", {
          news_key: editKey, title: title, content: document.getElementById("eContent").value, end_date: end,
          file_name: f ? f.name : "", file_data: f ? f.data : "",
          remove_file: document.getElementById("eRemoveFile").checked
        });
      })
      .then(function (r) {
        changed = true;
        alert(r.isNew ? "공지를 등록했어요." : "공지를 수정했어요.");
        return loadMine(r.news_key);
      })
      .catch(function (e) { alert(e.message || e); })
      .then(function () { btn.disabled = false; btn.textContent = editKey ? "수정 저장" : "등록"; });
  }

  /** 공지 관리 창에서 삭제 */
  function deleteFromModal() {
    if (!editKey) return;
    const t = document.getElementById("eTitle").value.trim();
    if (!confirm("[" + t + "]\n공지를 삭제할까요? 첨부파일도 함께 지워집니다.")) return;
    newsApi("delete", { news_key: editKey })
      .then(function () { changed = true; fillForm(null); return loadMine(""); })
      .catch(function (e) { alert(e.message || e); });
  }

  function deleteNews() {
    if (!curNews) return;
    const t = curNews.querySelector(".news-title").textContent.trim();
    if (!confirm("[" + t + "]\n공지를 삭제할까요? 첨부파일도 함께 지워집니다.")) return;
    newsApi("delete", { news_key: curNews.dataset.key })
      .then(function () { location.reload(); })
      .catch(function (e) { alert(e.message || e); });
  }

  /** 줄에 첨부 📎 표시 · 우리 매장 공지 표시(눌러서 수정 · 삭제) */
  function decorate(tr) {
    const file = tr.dataset.file || "";
    tr.querySelector(".col-file").innerHTML = file ? '<span class="clip">📎</span>' : "";
    if (file) tr.querySelector(".clip").title = file;
    const mine = !!tr.dataset.key && (tr.dataset.shop || "") === MY_SHOP;
    tr.classList.toggle("mine", mine);
    tr.title = mine ? "눌러서 수정 · 삭제" : "";
  }

  /** 우리 매장 공지 목록(/s_news/mine)으로 줄마다 키 · 첨부파일을 채움
   *  - 목록 조회에 NEWS_KEY 가 있으면 키로, 없으면 등록일 + 제목 (+ 종료일) 로 짝 맞춤
   *  - 목록 조회에 FILENAME 이 없어도 📎 표시 */
  function digits8(v) { return String(v || "").replace(/\D/g, "").substr(0, 8); }
  function normT(v)   { return String(v || "").replace(/\s+/g, " ").trim(); }

  function matchMine(rows) {
    fetch(CTX + "/s_news/mine")
      .then(function (r) { return r.json(); })
      .then(function (res) {
        if (!res.ok) throw new Error(res.msg);
        const byKey = {}, byFull = {}, byShort = {}, byTitle = {};
        function put(map, k, m) { (map[k] = map[k] || []).push(m); }
        (res.data || []).forEach(function (m) {
          const d = digits8(m.news_date), t = normT(m.title), e = digits8(m.end_date);
          byKey[m.news_key] = m;
          put(byFull, d + "|" + t + "|" + e, m);
          put(byShort, d + "|" + t, m);
          put(byTitle, t, m);
        });
        rows.forEach(function (tr) {
          let hit = tr.dataset.key ? byKey[tr.dataset.key] : null;
          if (!hit && !tr.dataset.key) {
            const d = digits8(tr.querySelector(".d-news").textContent);
            const t = normT(tr.querySelector(".news-title").textContent);
            const e = digits8(tr.dataset.end);
            const list = byFull[d + "|" + t + "|" + e] || byShort[d + "|" + t] ||
                         ((byTitle[t] || []).length === 1 ? byTitle[t] : null) || [];
            hit = list.shift();
          }
          if (!hit) return;
          tr.dataset.key  = hit.news_key;
          tr.dataset.shop = MY_SHOP;
          tr.dataset.file = hit.filename || "";
          decorate(tr);
        });
      })
      .catch(function (e) { console.log("s_news/mine", e); });
  }

  /* ===== 매장별 매출 재조회 ===== */
  function fmtNum(v) { const n = Number(v) || 0; return Math.round(n).toLocaleString("ko-KR"); }
  function numOf(v)  { const n = Number(v); return isNaN(n) ? 0 : n; }

  function reloadShop() {
    const btn = document.getElementById("btnShopReload");
    btn.disabled = true; btn.textContent = "조회 중…";
    const d = document.getElementById("shopDate").value;      // yyyy-MM-dd
    if (!d) { alert("조회할 일자를 선택하세요."); btn.disabled = false; btn.textContent = "재조회"; return; }
    fetch(CTX + "/s_shopDay.do?date=" + encodeURIComponent(d.replace(/-/g, "")), { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("서버 요청 실패 (" + r.status + ")"); return r.json(); })
      .then(function (res) {
        if (!res.ok) {
          if (res.login) { alert(res.msg); location.href = CTX + "/s_news.do"; return; }
          throw new Error(res.msg || "조회 중 오류가 발생했습니다.");
        }
        drawShop(res.data || [], toInput(res.date) === ymdInput(new Date()));
        document.getElementById("shopTime").textContent = "· " + (res.time || "") + " 기준";
      })
      .catch(function (e) { alert(e.message || e); })
      .then(function () { btn.disabled = false; btn.textContent = "재조회"; });
  }

  function drawShop(list, isToday) {
    const table = document.getElementById("shopTable");
    const body  = table.tBodies[0];
    table.querySelectorAll("thead th").forEach(function (h) { h.classList.remove("asc", "desc"); });
    const oldFoot = table.tFoot; if (oldFoot) oldFoot.remove();
    body.innerHTML = "";

    if (!list.length) {
      body.innerHTML = '<tr><td colspan="7" class="c text-muted py-5">' + (isToday ? "오늘" : "선택한 일자의") + ' 매출 자료가 없습니다.</td></tr>';
      return;
    }
    let sAmt = 0, sCash = 0, sCard = 0, sSale = 0, sVisit = 0;
    list.forEach(function (s) {
      const amt = numOf(s.AMT), cash = numOf(s.CASHAMT), card = numOf(s.CARDAMT),
            sale = numOf(s.SALEAMT), visit = numOf(s.VISITCNT);
      const tr = document.createElement("tr");
      if (String(s.SHOPNO || "") === MY_SHOP) tr.className = "my-shop";
      tr.dataset.shopno = s.SHOPNO || "";
      tr.innerHTML = '<td class="l"></td><td class="fw-bold"></td><td></td><td></td><td></td><td></td><td></td>';
      tr.cells[0].textContent = s.SHOPNAME || "";
      tr.cells[1].textContent = fmtNum(amt);
      tr.cells[2].textContent = fmtNum(cash);
      tr.cells[3].textContent = fmtNum(card);
      tr.cells[4].textContent = fmtNum(sale);
      tr.cells[5].textContent = fmtNum(visit);
      tr.cells[6].textContent = visit > 0 ? fmtNum((cash + card) / visit) : "0";
      body.appendChild(tr);
      sAmt += amt; sCash += cash; sCard += card; sSale += sale; sVisit += visit;
    });
    const foot = table.createTFoot();
    foot.innerHTML = '<tr><td class="c">합계</td><td></td><td></td><td></td><td></td><td></td><td></td></tr>';
    const c = foot.rows[0].cells;
    c[1].textContent = fmtNum(sAmt);  c[2].textContent = fmtNum(sCash); c[3].textContent = fmtNum(sCard);
    c[4].textContent = fmtNum(sSale); c[5].textContent = fmtNum(sVisit);
    c[6].textContent = sVisit > 0 ? fmtNum((sCash + sCard) / sVisit) : "0";
  }

  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    // 매장별 매출 일자: 기본 오늘, 미래 날짜 선택 불가, 날짜를 바꾸면 바로 조회
    const shopDate = document.getElementById("shopDate");
    shopDate.value = ymdInput(new Date());
    shopDate.max   = ymdInput(new Date());
    shopDate.addEventListener("change", reloadShop);
    document.getElementById("btnShopReload").addEventListener("click", reloadShop);

    document.getElementById("btnNewsAdd").addEventListener("click", function () { openEdit(null); });
    document.getElementById("btnNewsSave").addEventListener("click", saveNews);
    document.getElementById("btnNewsDelM").addEventListener("click", deleteFromModal);
    document.getElementById("btnNewsNew").addEventListener("click", function () { fillForm(null); drawMine(); });
    // 관리 창을 닫을 때 바뀐 게 있으면 목록 새로 고침
    document.getElementById("newsEditModal").addEventListener("hidden.bs.modal", function () { if (changed) location.reload(); });
    document.getElementById("btnNewsDel").addEventListener("click", deleteNews);
    document.getElementById("btnNewsEdit").addEventListener("click", function () {
      const tr = curNews;
      bootstrap.Modal.getOrCreateInstance(document.getElementById("newsModal")).hide();
      setTimeout(function () { openEdit(tr); }, 300);
    });

    const rows = document.querySelectorAll("#newsTable .news-row");
    rows.forEach(decorate);
    if (rows.length) matchMine(Array.prototype.slice.call(rows));     // 키 · 첨부파일 채우기

    // 공지 행 클릭 → 상세 팝업
    rows.forEach(function (tr) {
      tr.addEventListener("click", function (e) {
        // 우리 매장 공지 → 바로 수정 · 삭제 창 (다른 매장 공지는 보기만)
        if (tr.classList.contains("mine")) { curNews = tr; openEdit(tr); return; }
        const newsDate = tr.querySelector(".d-news").textContent.trim();
        const endDate  = tr.querySelector(".news-end").textContent.trim();

        document.getElementById("newsTitle").textContent   = tr.querySelector(".news-title").textContent;
        document.getElementById("newsMeta").textContent    =
          (newsDate ? "등록일 " + newsDate + "  ·  " : "") + "종료일 " + endDate;
        document.getElementById("newsContent").textContent = tr.querySelector(".d-content").textContent;

        // 첨부파일 · 수정/삭제 (우리 매장 공지만)
        curNews = tr;
        const file = tr.dataset.file || "";
        document.getElementById("newsFile").classList.toggle("d-none", !file);
        const link = document.getElementById("newsFileLink");
        link.textContent = file;
        link.href = CTX + "/s_news/file?key=" + encodeURIComponent(tr.dataset.key || "");
        const mine = (tr.dataset.shop || "") === MY_SHOP && !!tr.dataset.key;
        document.getElementById("btnNewsEdit").classList.toggle("d-none", !mine);
        document.getElementById("btnNewsDel").classList.toggle("d-none", !mine);

        bootstrap.Modal.getOrCreateInstance(document.getElementById("newsModal")).show();
      });
    });

    // 공지 검색 (제목·내용)
    document.getElementById("searchText").addEventListener("keyup", function () {
      const q = this.value.trim().toLowerCase();
      let cnt = 0;
      rows.forEach(function (tr) {
        const text = (tr.querySelector(".news-title").textContent + " " +
                      tr.querySelector(".d-content").textContent).toLowerCase();
        const show = !q || text.includes(q);
        tr.style.display = show ? "" : "none";
        if (show) cnt++;
      });
      document.getElementById("newsCount").textContent = cnt;
    });

    // 정렬 기능 연결
    document.querySelectorAll("table.sortable").forEach(makeSortable);

    // 일자별 매출: 처음엔 일자 오름차순 표시 + 최근 날짜가 보이도록 아래로
    const salesTable = document.getElementById("salesTable");
    salesTable.querySelector("thead th").classList.add("asc");
    const salesBox = salesTable.closest(".box-scroll");
    if (salesBox) salesBox.scrollTop = salesBox.scrollHeight;
  });
</script>

</body>
</html>
