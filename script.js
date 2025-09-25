/* =========================================== */
/* HOUSE MVP - 메인 페이지 JavaScript */
/* 부동산 검색 웹 애플리케이션의 핵심 기능 */
/* =========================================== */

/* =========================================== */
/* 1. APP INITIALIZATION - 애플리케이션 초기화 */
/* =========================================== */
document.addEventListener('DOMContentLoaded', function() {
    console.log('🔍 DOMContentLoaded - 페이지 로드 완료');
    console.log('🔍 JUSO_API_CONFIG:', JUSO_API_CONFIG);
    
    // 추가 초기화 코드가 필요한 경우 여기에 작성
});

/* =========================================== */
/* 2. MODAL MANAGEMENT - 모달 팝업 관리 */
/* =========================================== */

/**
 * 로그인 모달 열기
 */
function openLoginModal() {
    document.getElementById('loginModal').style.display = 'block';
    document.body.style.overflow = 'hidden';
}

/**
 * 로그인 모달 닫기
 */
function closeLoginModal() {
    document.getElementById('loginModal').style.display = 'none';
    document.body.style.overflow = 'auto';
}

/**
 * 회원가입 모달 열기
 */
function openSignupModal() {
    document.getElementById('signupModal').style.display = 'block';
    document.body.style.overflow = 'hidden';
}

/**
 * 회원가입 모달 닫기
 */
function closeSignupModal() {
    document.getElementById('signupModal').style.display = 'none';
    document.body.style.overflow = 'auto';
}

/**
 * 모달 외부 클릭 시 닫기
 */
window.addEventListener('click', function(event) {
    const loginModal = document.getElementById('loginModal');
    const signupModal = document.getElementById('signupModal');
    
    if (event.target === loginModal) {
        closeLoginModal();
    }
    if (event.target === signupModal) {
        closeSignupModal();
    }
});

/* =========================================== */
/* 3. API CONFIGURATION - API 설정 */
/* =========================================== */

/**
 * 환경 감지 함수
 * GitHub Pages인지 로컬 개발 환경인지 자동 감지
 */
function isGitHubPages() {
    // 로컬 개발 환경 우선 감지
    const isLocal = window.location.hostname === 'localhost' ||
                    window.location.hostname === '127.0.0.1' ||
                    window.location.protocol === 'file:' ||
                    window.location.hostname === '';
    
    // GitHub Pages 환경 감지 (로컬이 아닌 경우에만)
    const isGitHub = !isLocal && (
        window.location.hostname === 'github.io' || 
        window.location.hostname.includes('github.io')
    );
    
    console.log('🔍 환경 감지:', {
        hostname: window.location.hostname,
        protocol: window.location.protocol,
        isGitHub: isGitHub,
        isLocal: isLocal,
        result: isGitHub
    });
    
    return isGitHub;
}

/**
 * 도로명주소 검색 API 설정
 * 환경에 따라 자동으로 프록시 또는 직접 호출 선택
 */
const JUSO_API_CONFIG = {
    baseUrl: 'https://business.juso.go.kr/addrlink/addrLinkApi.do',
    confmKey: 'devU01TX0FVVEgyMDI1MDkwNDE5NDkzNDExNjE1MTQ=',
    currentPage: 1,
    countPerPage: 10,
    resultType: 'json'
};

/* =========================================== */
/* 4. SEARCH FUNCTIONALITY - 주소 검색 기능 */
/* =========================================== */

/**
 * 주소 검색 실행
 * 사용자 입력을 검증하고 API 호출
 */
async function searchAddress() {
    console.log('🔍 searchAddress 함수 시작');
    
    const addressInput = document.getElementById('addressInput');
    const keyword = addressInput.value.trim();
    
    console.log('🔍 검색 키워드:', keyword);
    
    // 입력값 검증
    if (!checkSearchedWord(keyword)) {
        console.log('🔍 검색어 유효성 검사 실패');
        return;
    }
    
    if (!keyword) {
        console.log('🔍 검색어가 비어있음');
        alert('검색할 주소를 입력해주세요.');
        addressInput.focus();
        return;
    }
    
    // 로딩 상태 표시
    console.log('🔍 로딩 상태 표시');
    showLoading();
    
    try {
        console.log('🔍 API 호출 시작');
        console.log('🔍 JUSO_API_CONFIG:', JUSO_API_CONFIG);
        
        // 환경에 따른 API 호출 방식 선택
        if (isGitHubPages()) {
            // GitHub Pages: 직접 호출 (CORS 우회)
            console.log('🌐 GitHub Pages 환경 - 직접 호출 사용');
            
            const params = new URLSearchParams({
                confmKey: JUSO_API_CONFIG.confmKey,
                currentPage: JUSO_API_CONFIG.currentPage,
                countPerPage: JUSO_API_CONFIG.countPerPage,
                keyword: keyword,
                resultType: JUSO_API_CONFIG.resultType
            });
            
            const url = `${JUSO_API_CONFIG.baseUrl}?${params.toString()}`;
            console.log('🔍 직접 API 호출 URL:', url);
            
            // 직접 fetch 호출 (CORS 우회 시도)
            const response = await fetch(url, {
                method: 'GET',
                mode: 'cors',
                headers: {
                    'Accept': 'application/json'
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            console.log('🔍 Juso API 응답:', data);
            
            if (data.results && data.results.common.errorCode === '0') {
                console.log('🔍 검색 결과 표시');
                displaySearchResults(data.results.juso);
            } else {
                console.log('🔍 검색 결과 없음 또는 오류:', data.results?.common?.errorMessage);
                showError(data.results?.common?.errorMessage || '검색 결과가 없습니다.');
            }
            
        } else {
            // 로컬 개발: 프록시 서버 사용
            console.log('🏠 로컬 개발 환경 - 프록시 서버 사용');
            
            const params = new URLSearchParams({
                confmKey: JUSO_API_CONFIG.confmKey,
                currentPage: JUSO_API_CONFIG.currentPage,
                countPerPage: JUSO_API_CONFIG.countPerPage,
                keyword: keyword,
                resultType: JUSO_API_CONFIG.resultType
            });
            
            const url = `http://localhost:3001/api/juso?${params.toString()}`;
            console.log('🔍 프록시 API 호출 URL:', url);
            
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                }
            });
            
            console.log('🔍 응답 상태:', response.status);
            console.log('🔍 응답 헤더:', response.headers);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            console.log('🔍 Juso API 응답:', data);
            
            if (data.results && data.results.common.errorCode === '0') {
                console.log('🔍 검색 결과 표시');
                displaySearchResults(data.results.juso);
            } else {
                console.log('🔍 검색 결과 없음 또는 오류:', data.results?.common?.errorMessage);
                showError(data.results?.common?.errorMessage || '검색 결과가 없습니다.');
            }
        }
        
    } catch (error) {
        console.error('🔍 API 호출 오류:', error);
        // 주소 검색 오류 처리
        showError('주소 검색 중 오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
        hideLoading();
    }
}

/**
 * 검색어 유효성 검사
 * 특수문자 및 SQL 예약어 체크
 * @param {string} keyword - 검색어
 * @returns {boolean} - 유효성 여부
 */
function checkSearchedWord(keyword) {
    if (keyword.length === 0) return true;
    
    // 특수문자 검사
    const expText = /[%=><]/;
    if (expText.test(keyword)) {
        alert('특수문자를 입력할 수 없습니다.');
        return false;
    }
    
    // SQL 예약어 검사
    const sqlArray = [
        'OR', 'SELECT', 'INSERT', 'DELETE', 'UPDATE', 'CREATE', 'DROP', 
        'EXEC', 'UNION', 'FETCH', 'DECLARE', 'TRUNCATE'
    ];
    
    for (let i = 0; i < sqlArray.length; i++) {
        const regex = new RegExp(sqlArray[i], 'gi');
        if (regex.test(keyword)) {
            alert(`"${sqlArray[i]}"와(과) 같은 특정문자로 검색할 수 없습니다.`);
            return false;
        }
    }
    
    return true;
}

/**
 * 검색 결과 표시
 * @param {Array} results - 검색 결과 배열
 */
function displaySearchResults(results) {
    // 기존 결과 제거
    const existingResults = document.querySelector('.search-results');
    if (existingResults) {
        existingResults.remove();
    }
    
    if (!results || results.length === 0) {
        showError('검색 결과가 없습니다. 다른 키워드로 검색해보세요.');
        return;
    }
    
    // 결과 컨테이너 생성
    const resultContainer = createResultContainer();
    
    // 결과 헤더
    const resultsHeader = document.createElement('div');
    resultsHeader.className = 'results-header';
    resultsHeader.textContent = `검색 결과 ${results.length}건`;
    resultContainer.appendChild(resultsHeader);
    
    // 결과 아이템들
    results.forEach((result, index) => {
        const resultItem = document.createElement('div');
        resultItem.className = 'result-item';
        resultItem.innerHTML = `
            <div class="road-addr">${result.roadAddr}</div>
            <div class="jibun-addr">${result.jibunAddr}</div>
            <div class="zip-code">우편번호: ${result.zipNo}</div>
        `;
        
        // 클릭 이벤트 추가
        resultItem.addEventListener('click', () => {
            selectAddress(result.roadAddr, result.jibunAddr, result.zipNo, result);
        });
        
        resultContainer.appendChild(resultItem);
    });
    
    // 검색 섹션에 결과 추가
    const searchSection = document.querySelector('.search-section');
    searchSection.appendChild(resultContainer);
}

/**
 * 결과 컨테이너 생성
 * @returns {HTMLElement} - 결과 컨테이너 요소
 */
function createResultContainer() {
    const container = document.createElement('div');
    container.className = 'search-results';
    return container;
}

/**
 * 주소 선택 처리
 * 선택된 주소 정보를 결과 페이지로 전달
 * @param {string} roadAddr - 도로명주소
 * @param {string} jibunAddr - 지번주소
 * @param {string} zipNo - 우편번호
 * @param {Object} fullJusoData - 전체 주소 데이터
 */
function selectAddress(roadAddr, jibunAddr, zipNo, fullJusoData) {
    // URL 파라미터로 주소 정보 전달하여 결과 페이지로 이동
    const params = new URLSearchParams({
        roadAddr: roadAddr,
        jibunAddr: jibunAddr,
        zipCode: zipNo,
        admCd: fullJusoData.admCd, // 행정구역코드 추가
        // 모든 주소 정보를 JSON으로 인코딩하여 전달
        fullData: JSON.stringify(fullJusoData)
    });
    
    window.location.href = `result.html?${params.toString()}`;
}

/* =========================================== */
/* 5. UI STATE MANAGEMENT - UI 상태 관리 */
/* =========================================== */

/**
 * 로딩 상태 표시
 */
function showLoading() {
    const searchBtn = document.querySelector('.search-btn');
    const originalText = searchBtn.textContent;
    searchBtn.textContent = '검색 중...';
    searchBtn.disabled = true;
    searchBtn.style.opacity = '0.7';
}

/**
 * 로딩 상태 숨기기
 */
function hideLoading() {
    const searchBtn = document.querySelector('.search-btn');
    searchBtn.textContent = '검색';
    searchBtn.disabled = false;
    searchBtn.style.opacity = '1';
}

/**
 * 에러 메시지 표시
 * @param {string} message - 에러 메시지
 */
function showError(message) {
    console.log('🔍 showError 호출:', message);
    
    // 기존 에러 메시지 제거
    const existingError = document.querySelector('.error-message');
    if (existingError) {
        existingError.remove();
    }
    
    // 에러 메시지 생성
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.textContent = message;
    
    // 검색 섹션에 에러 메시지 추가
    const searchSection = document.querySelector('.search-section');
    searchSection.appendChild(errorDiv);
    
    console.log('🔍 에러 메시지 표시 완료');
}

/* =========================================== */
/* 6. KEYBOARD EVENTS - 키보드 이벤트 */
/* =========================================== */

/**
 * 엔터키 검색 이벤트
 */
document.addEventListener('keydown', function(event) {
    if (event.key === 'Enter') {
        const addressInput = document.getElementById('addressInput');
        if (document.activeElement === addressInput) {
            searchAddress();
        }
    }
});

/* =========================================== */
/* 7. UTILITY FUNCTIONS - 유틸리티 함수 */
/* =========================================== */

/**
 * 페이지 뒤로가기
 */
function goBack() {
    window.history.back();
}

/**
 * 매물 요청 제출 (결과 페이지에서 사용)
 */
function submitRequest() {
    // 실제 구현에서는 서버로 데이터 전송
    alert('매물 요청이 제출되었습니다. 빠른 시일 내에 연락드리겠습니다.');
}