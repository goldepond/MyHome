/**
 * @fileoverview 유틸리티 함수 모음
 * @description Google JavaScript Style Guide 준수
 */

/**
 * 프로덕션 모드 여부 확인
 * @const {boolean}
 */
const IS_PRODUCTION = window.location.hostname !== 'localhost' && 
                      window.location.hostname !== '127.0.0.1';

/**
 * 로깅 유틸리티 (프로덕션 모드에서 비활성화)
 */
const Logger = {
  /**
   * 일반 로그
   * @param {...*} args
   */
  log: function(...args) {
    if (!IS_PRODUCTION) {
      console.log(...args);
    }
  },

  /**
   * 에러 로그 (항상 표시)
   * @param {...*} args
   */
  error: function(...args) {
    console.error(...args);
  },

  /**
   * 경고 로그
   * @param {...*} args
   */
  warn: function(...args) {
    if (!IS_PRODUCTION) {
      console.warn(...args);
    }
  },

  /**
   * 정보 로그
   * @param {...*} args
   */
  info: function(...args) {
    if (!IS_PRODUCTION) {
      console.info(...args);
    }
  }
};

/**
 * 디바운스 함수
 * @param {Function} func
 * @param {number} wait
 * @return {Function}
 */
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

/**
 * 스로틀 함수
 * @param {Function} func
 * @param {number} limit
 * @return {Function}
 */
function throttle(func, limit) {
  let inThrottle;
  return function(...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

/**
 * 안전한 JSON 파싱
 * @param {string} jsonString
 * @param {*=} defaultValue
 * @return {*}
 */
function safeJsonParse(jsonString, defaultValue = null) {
  try {
    return JSON.parse(jsonString);
  } catch (e) {
    Logger.error('JSON 파싱 실패:', e);
    return defaultValue;
  }
}

/**
 * URL 파라미터 가져오기
 * @param {string} name
 * @param {string=} defaultValue
 * @return {string}
 */
function getUrlParam(name, defaultValue = '') {
  const params = new URLSearchParams(window.location.search);
  return params.get(name) || defaultValue;
}

/**
 * 요소가 존재하는지 확인
 * @param {string|Element} selector
 * @return {Element|null}
 */
function $(selector) {
  if (typeof selector === 'string') {
    return document.querySelector(selector);
  }
  return selector;
}

/**
 * 모든 요소 선택
 * @param {string} selector
 * @return {NodeList}
 */
function $$(selector) {
  return document.querySelectorAll(selector);
}


