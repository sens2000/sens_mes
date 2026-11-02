package com.sens.lush;

import javax.servlet.http.HttpServletRequest;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;

/**
 * 재고조사 모바일 입력 (ai602) — 화면만
 *  - 제품 검색 → 실사 수량 등록만 가능 (마감 · 초기화 · 조회는 PC 화면 ai601)
 *  - 데이터는 ai601 과 같은 API 사용 : /ai601/products, /ai601/save, /ai601/recent
 */
@Controller
public class ai602_Controller {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    @RequestMapping(value = "/ai602.do")
    public String ai602(HttpServletRequest request, Model model) throws Exception {
        logger.info("Start Page: ai602");
        return "ai602";
    }
}
