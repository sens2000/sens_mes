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
            <span class="small text-muted fw-normal">총 <b id="newsCount">${fn:length(newsList)}</b>건</span>
          </div>
          <div class="card-body p-2">
            <input type="text" id="searchText" class="form-control form-control-sm mb-2" placeholder="제목·내용 검색">

            <div class="box-scroll top-scroll">
              <table class="table table-hover table-sm mb-0" id="newsTable">
                <thead>
                  <tr>
                    <th class="col-no">번호</th>
                    <th>제목 / 내용</th>
                    <th class="col-date">등록일</th>
                    <th class="col-date">종료일</th>
                  </tr>
                </thead>
                <tbody>
                <c:choose>
                  <c:when test="${empty newsList}">
                    <tr><td colspan="4" class="text-center text-muted py-5">등록된 공지사항이 없습니다.</td></tr>
                  </c:when>
                  <c:otherwise>
                    <c:forEach var="n" items="${newsList}" varStatus="st">
                      <c:set var="endDate"  value="${n.END_DATE}"/>
                      <c:set var="newsDate" value="${n.NEWS_DATE}"/>
                      <tr class="news-row">
                        <td class="col-no">${st.count}</td>
                        <td>
                          <div class="fw-bold news-title"><c:out value="${n.TITLE}"/></div>
                          <div class="news-preview"><c:out value="${n.CONTENT}"/></div>
                        </td>
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
            <span class="small text-muted fw-normal">오늘 · 단위: 원</span>
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
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">닫기</button>
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

  document.addEventListener("DOMContentLoaded", function () {
    checkLogin();

    const rows = document.querySelectorAll("#newsTable .news-row");

    // 공지 행 클릭 → 상세 팝업
    rows.forEach(function (tr) {
      tr.addEventListener("click", function () {
        const newsDate = tr.querySelector(".d-news").textContent.trim();
        const endDate  = tr.querySelector(".news-end").textContent.trim();

        document.getElementById("newsTitle").textContent   = tr.querySelector(".news-title").textContent;
        document.getElementById("newsMeta").textContent    =
          (newsDate ? "등록일 " + newsDate + "  ·  " : "") + "종료일 " + endDate;
        document.getElementById("newsContent").textContent = tr.querySelector(".d-content").textContent;

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
