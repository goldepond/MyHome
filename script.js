/* =========================================== */
/* HOUSE MVP - 메인 페이지 JavaScript */
/* 부동산 검색 웹 애플리케이션의 핵심 기능 */
/* =========================================== */

/* =========================================== */
/* 1. APP INITIALIZATION - 애플리케이션 초기화 */
/* =========================================== */

// 디바운스 타이머
let searchDebounceTimer = null;

document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ 페이지 로드 완료');
    
    // URL 파라미터에서 공유 링크 처리
    const urlParams = new URLSearchParams(window.location.search);
    const sharedAddress = urlParams.get('address');
    if (sharedAddress) {
        document.getElementById('addressInput').value = decodeURIComponent(sharedAddress);
        // 자동으로 검색 실행
        setTimeout(() => searchAddress(), 500);
    }
    
    // 최근 검색 & 즐겨찾기 로드
    loadRecentSearches();
    loadFavorites();
    
    // 검색창 입력 이벤트 (디바운스)
    const addressInput = document.getElementById('addressInput');
    if (addressInput) {
        addressInput.addEventListener('input', function() {
            // 입력 중일 때 최근 검색/즐겨찾기 표시
            const quickAccess = document.getElementById('quickAccess');
            if (this.value.trim() === '') {
                loadRecentSearches();
                loadFavorites();
                if (quickAccess) quickAccess.style.display = 'block';
            } else {
                if (quickAccess) quickAccess.style.display = 'none';
            }
        });
        
        // Enter 키 감지
        addressInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                searchAddress();
            }
        });
    }
    
    // 로그인 폼 이벤트 리스너는 auth.js의 initLoginForm에서 처리됨
});

/* =========================================== */
/* 1.5. ADMIN LOGIN - 관리자 로그인 기능 */
/* =========================================== */
// 로그인 처리는 auth.js의 initLoginForm에서 처리됨
// (관리자 로그인 + Firebase 로그인 모두 포함)

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
 * 비밀번호 재설정 모달 열기
 */
function showPasswordResetModal() {
    // 로그인 모달 닫기
    closeLoginModal();
    
    // 비밀번호 재설정 모달 열기
    document.getElementById('passwordResetModal').style.display = 'block';
    document.body.style.overflow = 'hidden';
}

/**
 * 비밀번호 재설정 모달 닫기
 */
function closePasswordResetModal() {
    document.getElementById('passwordResetModal').style.display = 'none';
    document.body.style.overflow = 'auto';
    
    // 입력 필드 초기화
    document.getElementById('resetEmail').value = '';
}

/**
 * 비밀번호 재설정 폼 제출
 */
document.addEventListener('DOMContentLoaded', function() {
    const passwordResetForm = document.getElementById('passwordResetForm');
    if (passwordResetForm) {
        passwordResetForm.addEventListener('submit', async function(event) {
            event.preventDefault();
            
            const email = document.getElementById('resetEmail').value.trim();
            
            if (!email) {
                alert('이메일 주소를 입력해주세요.');
                return;
            }
            
            try {
                await resetPassword(email);
                closePasswordResetModal();
            } catch (error) {
                console.error('비밀번호 재설정 오류:', error);
            }
        });
    }
});

/**
 * 모달 외부 클릭 시 닫기
 */
window.addEventListener('click', function(event) {
    const loginModal = document.getElementById('loginModal');
    const signupModal = document.getElementById('signupModal');
    const passwordResetModal = document.getElementById('passwordResetModal');
    
    if (event.target === loginModal) {
        closeLoginModal();
    }
    if (event.target === signupModal) {
        closeSignupModal();
    }
    if (event.target === passwordResetModal) {
        closePasswordResetModal();
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
    
    // 강제로 로컬 환경으로 설정 (테스트용)
    if (window.location.hostname === '' || window.location.protocol === 'file:') {
        console.log('🔍 강제 로컬 환경 설정');
        return false;
    }
    
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
    const addressInput = document.getElementById('addressInput');
    const keyword = addressInput.value.trim();
    
    // 입력값 검증
    if (!checkSearchedWord(keyword)) {
        return;
    }
    
    if (!keyword) {
        alert('검색할 주소를 입력해주세요.');
        addressInput.focus();
        return;
    }
    
    // 로딩 상태 표시
    showLoading();
    
    try {
        console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📍 [도로명주소 검색 API] 호출 시작');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        // 환경에 따른 API 호출 방식 선택
        if (isGitHubPages()) {
            // GitHub Pages: 직접 호출 (CORS 우회 시도)
            
            const params = new URLSearchParams({
                confmKey: JUSO_API_CONFIG.confmKey,
                currentPage: JUSO_API_CONFIG.currentPage,
                countPerPage: JUSO_API_CONFIG.countPerPage,
                keyword: keyword,
                resultType: JUSO_API_CONFIG.resultType
            });
            
            const url = `${JUSO_API_CONFIG.baseUrl}?${params.toString()}`;
            
            try {
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
                
                if (data.results && data.results.common.errorCode === '0') {
                    console.log('✅ [도로명주소 검색 API] 응답 성공');
                    console.log(`   결과 건수: ${data.results.juso?.length || 0}건`);
                    displaySearchResults(data.results.juso);
                } else {
                    console.log('❌ [도로명주소 검색 API] 응답 실패');
                    console.log(`   에러: ${data.results?.common?.errorMessage}`);
                    showError(data.results?.common?.errorMessage || '검색 결과가 없습니다.');
                }
            } catch (corsError) {
                console.log('❌ [도로명주소 검색 API] CORS 오류 발생');
                console.log(`   에러: ${corsError.message}`);
                console.log('   → 모의 데이터 사용');
                // CORS 오류 시 모의 데이터 사용
                const mockData = {
                    results: {
                        common: {
                            errorCode: "0",
                            errorMessage: "정상 처리"
                        },
                        juso: [
                            {
                                roadAddr: "경기도 성남시 분당구 중앙공원로 54",
                                roadAddrPart1: "경기도 성남시 분당구 중앙공원로 54",
                                roadAddrPart2: "(서현동, 시범단지우성아파트)",
                                jibunAddr: "경기도 성남시 분당구 서현동 96 시범단지우성아파트",
                                engAddr: "54 Junganggongwon-ro, Bundang-gu, Seongnam-si, Gyeonggi-do",
                                zipNo: "13589",
                                admCd: "4113510500",
                                rnMgtSn: "411353180049",
                                bdMgtSn: "4113510500100960000001848",
                                detBdNmList: "229동,226동,206동,221동,222동,206동,221동,222동,상가동,216동,223동,상가동,212동,관리동,209동,211동,225동,210동,208동,205동,213동,215동,224동,노인정,227동,219동,218동,220동,214동,228동,230동,201동,202동,203동,207동,217동,유치원동",
                                bdNm: "시범단지우성아파트",
                                bdKdcd: "1",
                                siNm: "경기도",
                                sggNm: "성남시 분당구",
                                emdNm: "서현동",
                                liNm: "",
                                rn: "중앙공원로",
                                udrtYn: "0",
                                buldMnnm: 54,
                                buldSlno: 0,
                                mtYn: "0",
                                lnbrMnnm: 96,
                                lnbrSlno: 0,
                                emdNo: "01",
                                hstryYn: "0",
                                relJibun: "",
                                hemdNm: ""
                            }
                        ]
                    }
                };
                
                displaySearchResults(mockData.results.juso);
            }
            
        } else {
            // 로컬 개발: 프록시 서버 사용
            console.log('   ✅ 로컬 환경 감지 → 프록시 서버 사용');
            
            const params = new URLSearchParams({
                confmKey: JUSO_API_CONFIG.confmKey,
                currentPage: JUSO_API_CONFIG.currentPage,
                countPerPage: JUSO_API_CONFIG.countPerPage,
                keyword: keyword,
                resultType: JUSO_API_CONFIG.resultType
            });
            
            const url = `http://localhost:3001/api/juso?${params.toString()}`;
            console.log('   🌐 요청 URL:', url);
            console.log('   ⏳ fetch() 호출 중...');
            
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                }
            });
            
            console.log('   ✅ fetch() 완료!');
            console.log('   📊 응답 상태:', response.status, response.statusText);
            
            if (!response.ok) {
                console.error('   ❌ HTTP 오류:', response.status, response.statusText);
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            console.log('   📥 JSON 파싱 중...');
            const data = await response.json();
            console.log('   ✅ JSON 파싱 완료');
            console.log('   📦 응답 데이터:', data);
            
            if (data.results && data.results.common.errorCode === '0') {
                console.log('✅ [도로명주소 검색 API] 응답 성공');
                console.log(`   결과 건수: ${data.results.juso?.length || 0}건`);
                
                // 최근 검색 저장
                saveRecentSearch(keyword);
                displaySearchResults(data.results.juso);
            } else {
                console.log('❌ [도로명주소 검색 API] 응답 실패');
                console.log(`   에러 코드: ${data.results?.common?.errorCode}`);
                console.log(`   에러 메시지: ${data.results?.common?.errorMessage}`);
                showError(data.results?.common?.errorMessage || '검색 결과가 없습니다.');
            }
        }
        
    } catch (error) {
        console.log('❌ [도로명주소 검색 API] 에러 발생');
        console.log(`   에러: ${error.message}`);
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

// 선택된 주소 정보를 저장할 전역 변수
let selectedAddressData = null;

/**
 * 주소 선택 처리
 * 선택된 주소 정보를 저장하고 동/호수 입력 폼 표시
 * @param {string} roadAddr - 도로명주소
 * @param {string} jibunAddr - 지번주소
 * @param {string} zipNo - 우편번호
 * @param {Object} fullJusoData - 전체 주소 데이터
 */
function selectAddress(roadAddr, jibunAddr, zipNo, fullJusoData) {
    // 선택된 주소 데이터를 전역 변수에 저장
    selectedAddressData = {
        roadAddr: roadAddr,
        jibunAddr: jibunAddr,
        zipNo: zipNo,
        fullJusoData: fullJusoData
    };
    
    // 기존 입력 폼이 있으면 제거
    const existingForm = document.querySelector('.detail-input-form');
    if (existingForm) {
        existingForm.remove();
    }
    
    // 동/호수 입력 폼 생성
    const detailForm = document.createElement('div');
    detailForm.className = 'detail-input-form';
    detailForm.innerHTML = `
        <div class="selected-address-display">
            <h3>선택된 주소</h3>
            <p class="selected-addr">${roadAddr}</p>
        </div>
        <div class="detail-input-container">
            <div class="input-group">
                <label for="dongInput">동</label>
                <input type="text" id="dongInput" placeholder="예: 101동" class="detail-input">
            </div>
            <div class="input-group">
                <label for="hosuInput">호수</label>
                <input type="text" id="hosuInput" placeholder="예: 1201호" class="detail-input">
            </div>
        </div>
        <button class="confirm-btn" onclick="confirmAddressDetail()">
            확인
        </button>
    `;
    
    // 검색 결과 아래에 추가
    const searchSection = document.querySelector('.search-section');
    searchSection.appendChild(detailForm);
    
    // 스크롤을 입력 폼으로 이동
    detailForm.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

/**
 * 동/호수 정보 확인 후 결과 페이지로 이동
 */
function confirmAddressDetail() {
    if (!selectedAddressData) {
        alert('주소 정보가 없습니다.');
        return;
    }
    
    const dongNm = document.getElementById('dongInput').value.trim();
    const hoNm = document.getElementById('hosuInput').value.trim();
    
    // 동/호수가 입력되지 않으면 경고
    if (!dongNm && !hoNm) {
        alert('동 또는 호수를 입력해주세요.');
        return;
    }
    
    // URL 파라미터로 주소 정보 전달하여 결과 페이지로 이동
    const params = new URLSearchParams({
        roadAddr: selectedAddressData.roadAddr,
        jibunAddr: selectedAddressData.jibunAddr,
        zipCode: selectedAddressData.zipNo,
        admCd: selectedAddressData.fullJusoData.admCd, // 행정구역코드 추가
        dongNm: dongNm,
        hoNm: hoNm,
        // 모든 주소 정보를 JSON으로 인코딩하여 전달
        fullData: JSON.stringify(selectedAddressData.fullJusoData)
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
 * 내 제안서 페이지로 이동
 */
function goToMyProposals() {
    window.location.href = 'proposals-list.html';
}

/**
 * 메인 페이지로 이동 (로고 클릭 시)
 */
function goToMainPage() {
    // 현재 페이지가 이미 메인 페이지(index.html)인 경우 페이지 상단으로 스크롤
    if (window.location.pathname.endsWith('index.html') || 
        window.location.pathname === '/' || 
        window.location.pathname === '') {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
        // 다른 페이지에서 메인 페이지로 이동
        window.location.href = 'index.html';
    }
}

/**
 * 매물 요청 제출 (결과 페이지에서 사용)
 */
function submitRequest() {
    // 실제 구현에서는 서버로 데이터 전송
    alert('매물 요청이 제출되었습니다. 빠른 시일 내에 연락드리겠습니다.');
}

/* =========================================== */
/* 8. RECENT SEARCHES & FAVORITES - 최근 검색 & 즐겨찾기 */
/* =========================================== */

/**
 * 최근 검색 로드
 */
function loadRecentSearches() {
    const recentSearches = JSON.parse(localStorage.getItem('recentSearches') || '[]');
    const recentSection = document.getElementById('recentSearches');
    const recentList = document.getElementById('recentList');
    
    if (!recentList) return;
    
    if (recentSearches.length === 0) {
        recentSection.style.display = 'none';
        return;
    }
    
    recentSection.style.display = 'block';
    document.getElementById('quickAccess').style.display = 'block';
    
    recentList.innerHTML = recentSearches.slice(0, 5).map(search => `
        <div class="quick-item" onclick="selectQuickSearch('${search.keyword.replace(/'/g, "\\'")}')">
            <span class="quick-icon">🕐</span>
            <span class="quick-text">${search.keyword}</span>
            <span class="quick-time">${getTimeAgo(search.timestamp)}</span>
        </div>
    `).join('');
}

/**
 * 즐겨찾기 로드 (Firestore + localStorage)
 */
async function loadFavorites() {
    const favSection = document.getElementById('favorites');
    const favList = document.getElementById('favoriteList');
    
    if (!favList) return;
    
    let favorites = [];
    
    // Firestore에서 불러오기 시도 (로그인된 경우)
    if (typeof loadFavoritesFromFirestore === 'function' && typeof isLoggedIn === 'function' && isLoggedIn()) {
        try {
            const firestoreFavorites = await loadFavoritesFromFirestore();
            if (firestoreFavorites.length > 0) {
                favorites = firestoreFavorites;
                console.log('✅ Firestore에서 즐겨찾기 로드:', favorites.length, '개');
            }
        } catch (error) {
            console.warn('⚠️ Firestore 로드 실패, localStorage 사용');
        }
    }
    
    // Firestore에서 못 가져왔으면 localStorage 사용
    if (favorites.length === 0) {
        favorites = JSON.parse(localStorage.getItem('favoriteAddresses') || '[]');
    }
    
    if (favorites.length === 0) {
        favSection.style.display = 'none';
        return;
    }
    
    favSection.style.display = 'block';
    document.getElementById('quickAccess').style.display = 'block';
    
    favList.innerHTML = favorites.slice(0, 5).map((fav, index) => `
        <div class="quick-item favorite-item">
            <span class="quick-icon">⭐</span>
            <span class="quick-text" onclick="selectQuickSearch('${fav.roadAddr.replace(/'/g, "\\'")}')">${fav.roadAddr}</span>
            <button class="remove-fav-btn" onclick="removeFavorite(${index})" title="삭제">✕</button>
        </div>
    `).join('');
}

/**
 * 최근 검색 저장
 */
function saveRecentSearch(keyword) {
    let recentSearches = JSON.parse(localStorage.getItem('recentSearches') || '[]');
    
    // 중복 제거
    recentSearches = recentSearches.filter(s => s.keyword !== keyword);
    
    // 새 검색어 추가
    recentSearches.unshift({
        keyword: keyword,
        timestamp: new Date().toISOString()
    });
    
    // 최대 10개까지만 저장
    recentSearches = recentSearches.slice(0, 10);
    
    localStorage.setItem('recentSearches', JSON.stringify(recentSearches));
}

/**
 * 빠른 검색 선택
 */
function selectQuickSearch(keyword) {
    document.getElementById('addressInput').value = keyword;
    document.getElementById('quickAccess').style.display = 'none';
    searchAddress();
}

/**
 * 즐겨찾기 제거
 */
function removeFavorite(index) {
    event.stopPropagation();
    
    let favorites = JSON.parse(localStorage.getItem('favoriteAddresses') || '[]');
    favorites.splice(index, 1);
    localStorage.setItem('favoriteAddresses', JSON.stringify(favorites));
    
    loadFavorites();
}

/**
 * 시간 경과 표시
 */
function getTimeAgo(timestamp) {
    const now = new Date();
    const past = new Date(timestamp);
    const diff = Math.floor((now - past) / 1000); // 초 단위
    
    if (diff < 60) return '방금';
    if (diff < 3600) return `${Math.floor(diff / 60)}분 전`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}시간 전`;
    if (diff < 2592000) return `${Math.floor(diff / 86400)}일 전`;
    return past.toLocaleDateString();
}
