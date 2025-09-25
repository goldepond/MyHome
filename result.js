/* =========================================== */
/* HOUSE MVP - 결과 페이지 JavaScript */
/* 주소 검색 결과 및 상세 정보 표시 기능 */
/* =========================================== */

/* =========================================== */
/* 1. API CONFIGURATION - API 설정 */
/* =========================================== */

/**
 * 행정구역코드 API 설정
 * 행정안전부_행정표준코드_법정동코드 API
 */
const REGION_API_CONFIG = {
    baseUrl: 'https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList',
    apiKey: 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==',
    pageNo: 1,
    numOfRows: 10,
    type: 'json',
    flag: 'Y'
};

/**
 * 아파트 목록 API 설정
 * 공동주택 단지 목록제공 서비스 API
 */
const APT_API_CONFIG = {
    baseUrl: 'https://apis.data.go.kr/1613000/AptListService3/getRoadnameAptList3',
    apiKey: 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==',
    pageNo: 1,
    numOfRows: 10
};

/**
 * 공동주택 상세 정보 API 설정
 * 공동주택 상세 정보제공 서비스 API (프록시 서버 사용)
 */
const APT_DETAIL_API_CONFIG = {
    baseUrl: 'https://apis.data.go.kr/1613000/AptBasisInfoServiceV4/getAphusDtlInfoV4',
    apiKey: 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ=='
};

/**
 * 건물 정보 API 설정
 * 건물등기정보제공 서비스 API (프록시 서버 사용)
 */
const BUILDING_API_CONFIG = {
    baseUrl: 'https://apis.data.go.kr/1613000/BldRgstHubService/getBrTitleInfo',
    apiKey: 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==',
    pageNo: 1,
    numOfRows: 10
};

/**
 * VWorld Geocoder API 설정
 * 주소를 좌표로 변환하는 API
 */
const GEOCODER_API_CONFIG = {
    baseUrl: 'https://api.vworld.kr/req/address',
    apiKey: 'C13F9ADA-AA60-36F7-928F-FAC481AA66AE',
    service: 'address',
    request: 'getCoord',
    version: '2.0',
    format: 'json',
    type: 'ROAD',
    crs: 'EPSG:4326',
    refine: 'true',
    simple: 'false'
};

/**
 * VWorld 토지이용계획도 API 설정
 * 좌표를 기반으로 토지이용계획 정보를 조회하는 API
 */
const LAND_USE_API_CONFIG = {
    baseUrl: 'https://api.vworld.kr/ned/data/getLandUseAttr',
    apiKey: 'C13F9ADA-AA60-36F7-928F-FAC481AA66AE',
    service: 'data',
    request: 'GetFeature',
    version: '2.0',
    format: 'json',
    data: 'LT_C_LHBLPN',
    crs: 'EPSG:4326',
    size: 10,
    page: 1,
    geometry: 'true',
    attribute: 'true'
};


/* =========================================== */
/* 2. PAGE INITIALIZATION - 페이지 초기화 */
/* =========================================== */

/**
 * 페이지 로드 시 초기화
 * URL 파라미터에서 주소 정보를 가져와서 표시하고 관련 API 호출
 */
document.addEventListener('DOMContentLoaded', function() {
    // URL 파라미터에서 주소 정보 추출
    const urlParams = new URLSearchParams(window.location.search);
    const roadAddr = urlParams.get('roadAddr');
    const jibunAddr = urlParams.get('jibunAddr');
    const zipCode = urlParams.get('zipCode');
    const fullData = urlParams.get('fullData');
    
    // 기본 주소 정보 표시
    displayBasicAddressInfo(roadAddr, jibunAddr, zipCode);
    
    // 전체 주소 정보 처리
    if (fullData) {
        try {
            const fullJusoData = JSON.parse(decodeURIComponent(fullData));
            displayFullAddressInfo(fullJusoData);
            
            // roadAddrPart1 값을 전역 변수로 저장 (아파트 필터링용)
            window.selectedRoadAddrPart1 = fullJusoData.roadAddrPart1;
            
            // 건물관리번호를 전역 변수로 저장 (토지이용계획도 API용)
            window.buildingManagementNumber = fullJusoData.bdMgtSn;
        } catch (error) {
            // 주소 데이터 파싱 오류 처리
        }
    }
    
    
    // 관련 API 호출
    if (jibunAddr) {
        loadRegionDetails(jibunAddr);
    }
    
    if (fullData) {
        try {
            const fullJusoData = JSON.parse(decodeURIComponent(fullData));
            if (fullJusoData.rnMgtSn) {
                loadAptList(fullJusoData.rnMgtSn);
            }
            
            // 건물 정보 API 호출 (행정구역코드 사용)
            if (fullJusoData.admCd) {
                const sigunguCd = fullJusoData.admCd.substring(0, 5);
                const bjdongCd = fullJusoData.admCd.substring(5, 10);
                
                // 지번본번을 4자리로 변환 (2자리인 경우 앞에 00을 붙임)
                const lnbrMnnm = fullJusoData.lnbrMnnm || '0';
                const bun = lnbrMnnm.toString().padStart(4, '0');
                
                loadBuildingInfo(sigunguCd, bjdongCd, bun);
            }
            
            // Geocoder API 호출 (도로명주소를 좌표로 변환)
            if (fullJusoData.roadAddr) {
                // 괄호와 참고항목을 제거한 깔끔한 주소 사용
                const cleanAddress = fullJusoData.roadAddrPart1 || fullJusoData.roadAddr;
                loadGeocoderInfo(cleanAddress);
            }
        } catch (error) {
            // API 로드 오류 처리
        }
    }
});

/* =========================================== */
/* 3. ADDRESS INFO DISPLAY - 주소 정보 표시 */
/* =========================================== */

/**
 * 기본 주소 정보 표시
 * @param {string} roadAddr - 도로명주소
 * @param {string} jibunAddr - 지번주소
 * @param {string} zipCode - 우편번호
 */
function displayBasicAddressInfo(roadAddr, jibunAddr, zipCode) {
    if (roadAddr) {
        document.getElementById('selectedRoadAddr').textContent = roadAddr;
    }
    if (jibunAddr) {
        document.getElementById('selectedJibunAddr').textContent = jibunAddr;
    }
    if (zipCode) {
        document.getElementById('selectedZipCode').textContent = zipCode;
    }
}

/**
 * 전체 주소 정보 표시
 * Juso API에서 받은 모든 정보를 상세하게 표시
 * @param {Object} fullJusoData - 전체 주소 데이터
 */
function displayFullAddressInfo(fullJusoData) {
    const addressInfo = document.querySelector('.address-info');
    
    // 상세 주소 정보 섹션 생성
    const detailSection = document.createElement('div');
    detailSection.className = 'info-card';
    
    const html = `
        <h2>📋 상세 주소 정보</h2>
        <div class="address-details-grid">
            <div class="detail-group">
                <h4>📍 기본 주소 정보</h4>
                <div class="detail-item">
                    <strong>도로명주소:</strong> ${fullJusoData.roadAddr || '-'}
                </div>
                <div class="detail-item">
                    <strong>도로명주소(참고항목 제외):</strong> ${fullJusoData.roadAddrPart1 || '-'}
                </div>
                <div class="detail-item">
                    <strong>도로명주소 참고항목:</strong> ${fullJusoData.roadAddrPart2 || '-'}
                </div>
                <div class="detail-item">
                    <strong>지번주소:</strong> ${fullJusoData.jibunAddr || '-'}
                </div>
                <div class="detail-item">
                    <strong>도로명주소(영문):</strong> ${fullJusoData.engAddr || '-'}
                </div>
                <div class="detail-item">
                    <strong>우편번호:</strong> ${fullJusoData.zipNo || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🏢 건물 정보</h4>
                <div class="detail-item">
                    <strong>건물명:</strong> ${fullJusoData.bdNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>상세건물명:</strong> ${fullJusoData.detBdNmList || '-'}
                </div>
                <div class="detail-item">
                    <strong>공동주택여부:</strong> ${fullJusoData.bdKdcd === '1' ? '공동주택' : '비공동주택'}
                </div>
                <div class="detail-item">
                    <strong>건물본번:</strong> ${fullJusoData.buldMnnm || '-'}
                </div>
                <div class="detail-item">
                    <strong>건물부번:</strong> ${fullJusoData.buldSlno || '-'}
                </div>
                <div class="detail-item">
                    <strong>지하여부:</strong> ${fullJusoData.udrtYn === '0' ? '지상' : '지하'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🗺️ 행정구역 정보</h4>
                <div class="detail-item">
                    <strong>시도명:</strong> ${fullJusoData.siNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>시군구명:</strong> ${fullJusoData.sggNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>읍면동명:</strong> ${fullJusoData.emdNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>법정리명:</strong> ${fullJusoData.liNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>읍면동일련번호:</strong> ${fullJusoData.emdNo || '-'}
                </div>
                <div class="detail-item">
                    <strong>관할주민센터:</strong> ${fullJusoData.hemdNm || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🛣️ 도로 정보</h4>
                <div class="detail-item">
                    <strong>도로명:</strong> ${fullJusoData.rn || '-'}
                </div>
                <div class="detail-item">
                    <strong>도로명코드:</strong> ${fullJusoData.rnMgtSn || '-'}
                </div>
                <div class="detail-item">
                    <strong>건물관리번호:</strong> ${fullJusoData.bdMgtSn || '-'}
                </div>
                <div class="detail-item">
                    <strong>행정구역코드:</strong> ${fullJusoData.admCd || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>📍 지번 정보</h4>
                <div class="detail-item">
                    <strong>지번본번:</strong> ${fullJusoData.lnbrMnnm || '-'}
                </div>
                <div class="detail-item">
                    <strong>지번부번:</strong> ${fullJusoData.lnbrSlno || '-'}
                </div>
                <div class="detail-item">
                    <strong>산여부:</strong> ${fullJusoData.mtYn === '0' ? '대지' : '산'}
                </div>
                <div class="detail-item">
                    <strong>관련지번:</strong> ${fullJusoData.relJibun || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>📊 기타 정보</h4>
                <div class="detail-item">
                    <strong>변동이력여부:</strong> ${fullJusoData.hstryYn === '0' ? '현행 주소정보' : '변동된 주소정보'}
                </div>
            </div>
        </div>
    `;
    
    detailSection.innerHTML = html;
    addressInfo.appendChild(detailSection);
}

/* =========================================== */
/* 4. REGION API - 행정구역코드 API */
/* =========================================== */

/**
 * 행정구역코드 API 호출
 * @param {string} jibunAddr - 지번주소
 */
async function loadRegionDetails(jibunAddr) {
    try {
        // 지번주소에서 "동"까지 추출
        const dongName = extractDongName(jibunAddr);
        if (!dongName) {
            return;
        }
        
        const params = new URLSearchParams({
            ServiceKey: REGION_API_CONFIG.apiKey,
            type: REGION_API_CONFIG.type,
            pageNo: REGION_API_CONFIG.pageNo,
            numOfRows: REGION_API_CONFIG.numOfRows,
            flag: REGION_API_CONFIG.flag,
            locatadd_nm: dongName
        });
        
        const url = `${REGION_API_CONFIG.baseUrl}?${params.toString()}`;
        
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.StanReginCd && data.StanReginCd.length > 0) {
            displayRegionDetails(data.StanReginCd[1].row);
        } else {
        }
        
    } catch (error) {
        // 행정구역코드 API 호출 오류 처리
    }
}

/**
 * 지번주소에서 동 이름 추출
 * @param {string} jibunAddr - 지번주소
 * @returns {string} - 동 이름
 */
function extractDongName(jibunAddr) {
    // "경기도 성남시 분당구 서현동" -> "서현동"
    const parts = jibunAddr.split(' ');
    for (let i = parts.length - 1; i >= 0; i--) {
        if (parts[i].endsWith('동')) {
            return parts[i];
        }
    }
    return null;
}

/**
 * 행정구역 정보 표시
 * @param {Array} regionData - 행정구역 데이터 배열
 */
function displayRegionDetails(regionData) {
    if (!regionData || regionData.length === 0) {
        return;
    }
    
    const addressInfo = document.querySelector('.address-info');
    
    // 행정구역 정보 섹션 생성
    const regionSection = document.createElement('div');
    regionSection.className = 'info-card';
    
    const region = regionData[0]; // 첫 번째 결과 사용
    
    const html = `
        <h2>🏛️ 행정구역 정보</h2>
        <div class="region-details">
            <div class="detail-item">
                <strong>지역주소명:</strong> ${region.locatadd_nm || '-'}
            </div>
            <div class="detail-item">
                <strong>지역코드:</strong> ${region.region_cd || '-'}
            </div>
            <div class="detail-item">
                <strong>시도코드:</strong> ${region.sido_cd || '-'}
            </div>
            <div class="detail-item">
                <strong>시군구코드:</strong> ${region.sgg_cd || '-'}
            </div>
            <div class="detail-item">
                <strong>읍면동코드:</strong> ${region.umd_cd || '-'}
            </div>
            <div class="detail-item">
                <strong>리코드:</strong> ${region.ri_cd || '-'}
            </div>
            <div class="detail-item">
                <strong>주민등록 지역코드:</strong> ${region.locatjumin_cd || '-'}
            </div>
            <div class="detail-item">
                <strong>지적 지역코드:</strong> ${region.locatjijuk_cd || '-'}
            </div>
            <div class="detail-item">
                <strong>최하위지역명:</strong> ${region.locallow_nm || '-'}
            </div>
            <div class="detail-item">
                <strong>상위지역코드:</strong> ${region.locathigh_cd || '-'}
            </div>
        </div>
    `;
    
    regionSection.innerHTML = html;
    addressInfo.appendChild(regionSection);
}

/* =========================================== */
/* 5. APARTMENT LIST API - 아파트 목록 API */
/* =========================================== */

/**
 * 아파트 목록 API 호출
 * @param {string} roadCode - 도로명코드
 */
async function loadAptList(roadCode) {
    try {
        const params = new URLSearchParams({
            serviceKey: APT_API_CONFIG.apiKey,
            roadCode: roadCode,
            pageNo: APT_API_CONFIG.pageNo,
            numOfRows: APT_API_CONFIG.numOfRows
        });
        
        const url = `${APT_API_CONFIG.baseUrl}?${params.toString()}`;
        
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.response && data.response.header && data.response.header.resultCode === '00') {
            displayAptList(data.response.body);
        } else {
        }
        
    } catch (error) {
        // 아파트 목록 API 호출 오류 처리
    }
}

/**
 * 아파트 목록 표시
 * @param {Object} aptData - 아파트 데이터
 */
function displayAptList(aptData) {
    const addressInfo = document.querySelector('.address-info');
    
    // 선택된 주소의 roadAddrPart1 가져오기
    const selectedRoadAddrPart1 = window.selectedRoadAddrPart1;
    
    // 아파트 목록 섹션 생성
    const aptSection = document.createElement('div');
    aptSection.id = 'aptListInfo';
    aptSection.className = 'info-card';
    
    let aptListHtml = `
        <h2>🏢 해당 주소의 아파트 목록</h2>
        <div class="apt-list-container">
    `;
    
    if (aptData.items && aptData.items.length > 0) {
        // roadAddrPart1과 doroJuso가 일치하는 아파트만 필터링
        const filteredApts = aptData.items.filter(apt => {
            // doroJuso에서 "서현동" 같은 동 이름을 제거하고 비교
            const cleanDoroJuso = apt.doroJuso.replace(/\s+[가-힣]+동\s+/, ' ');
            const isMatch = cleanDoroJuso === selectedRoadAddrPart1;
            return isMatch;
        });
        
        if (filteredApts.length > 0) {
            filteredApts.forEach((apt, index) => {
                aptListHtml += `
                    <div class="apt-item">
                        <div class="apt-name">${apt.kaptName || '-'}</div>
                        <div class="apt-code">아파트코드: ${apt.kaptCode || '-'}</div>
                        <div class="apt-address">${apt.doroJuso || '-'}</div>
                    </div>
                `;
            });
            
            // 첫 번째 아파트의 상세 정보 자동 로드
            if (filteredApts.length > 0) {
                const firstApt = filteredApts[0];
                // 바로 상세 정보 로드
                loadAptDetail(firstApt.kaptCode, firstApt.kaptName);
            }
        } else {
            aptListHtml += `<div class="no-apt">선택한 주소 "${selectedRoadAddrPart1}"에 해당하는 아파트가 없습니다.</div>`;
        }
    } else {
        aptListHtml += '<div class="no-apt">해당 도로에 등록된 아파트가 없습니다.</div>';
    }
    
    aptListHtml += '</div>';
    aptSection.innerHTML = aptListHtml;
    addressInfo.appendChild(aptSection);
}

/* =========================================== */
/* 6. APARTMENT DETAIL API - 아파트 상세 정보 API */
/* =========================================== */

/**
 * 아파트 상세 정보 API 호출
 * @param {string} kaptCode - 아파트 코드
 * @param {string} kaptName - 아파트 이름
 */
async function loadAptDetail(kaptCode, kaptName) {
    
    try {
        // GET 방식으로 먼저 시도
        const params = new URLSearchParams({
            serviceKey: APT_DETAIL_API_CONFIG.apiKey,
            kaptCode: kaptCode
        });
        
        // 환경에 따른 API 호출 방식 선택
        let url;
        const isLocal = window.location.hostname === 'localhost' || 
                        window.location.hostname === '127.0.0.1' || 
                        window.location.protocol === 'file:' ||
                        window.location.hostname === '';
        const isGitHub = !isLocal && (
            window.location.hostname === 'github.io' || 
            window.location.hostname.includes('github.io')
        );
        
        if (isGitHub) {
            // GitHub Pages: 직접 호출
            url = `${APT_DETAIL_API_CONFIG.baseUrl}?${params.toString()}`;
        } else {
            // 로컬 개발: 프록시 서버 사용
            url = `http://localhost:3001/api/apt-detail?${params.toString()}`;
        }
        
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Accept': 'application/json'
            }
        });
        
        // 응답이 JSON인지 확인
        const contentType = response.headers.get('content-type');
        
        let data;
        if (contentType && contentType.includes('application/json')) {
            data = await response.json();
        } else {
            const textData = await response.text();
            // GET 방식이 실패하면 POST 방식으로 재시도
            
            const postResponse = await fetch(APT_DETAIL_API_CONFIG.baseUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                body: JSON.stringify({
                    ServiceKey: APT_DETAIL_API_CONFIG.apiKey,
                    kaptCode: kaptCode
                })
            });
            
            const postContentType = postResponse.headers.get('content-type');
            
            if (postContentType && postContentType.includes('application/json')) {
                data = await postResponse.json();
            } else {
                const postTextData = await postResponse.text();
                throw new Error('POST 방식도 JSON 형식이 아닙니다.');
            }
        }
        
        
        if (data.response && data.response.header && data.response.header.resultCode === '00') {
            displayAptDetail(data.response.body.item, kaptName);
        } else {
        }
        
    } catch (error) {
        // 아파트 상세 정보 API 호출 오류 처리
    }
}

/**
 * 아파트 상세 정보 표시
 * @param {Object} detailData - 상세 정보 데이터
 * @param {string} kaptName - 아파트 이름
 */
function displayAptDetail(detailData, kaptName) {
    
    // 기존 상세 정보 섹션이 있으면 제거
    const existingDetail = document.getElementById('aptDetailInfo');
    if (existingDetail) {
        existingDetail.remove();
    }
    
    const addressInfo = document.querySelector('.address-info');
    
    // 아파트 상세 정보 섹션 생성
    const detailSection = document.createElement('div');
    detailSection.id = 'aptDetailInfo';
    detailSection.className = 'info-card';
    
    const html = `
        <h2>🏢 ${kaptName} 상세 정보</h2>
        <div class="apt-detail-grid">
            <div class="detail-group">
                <h4>🏠 기본 정보</h4>
                <div class="detail-item">
                    <strong>단지코드:</strong> ${detailData.kaptCode || '-'}
                </div>
                <div class="detail-item">
                    <strong>단지명:</strong> ${detailData.kaptName || '-'}
                </div>
                <div class="detail-item">
                    <strong>건물구조:</strong> ${detailData.codeStr || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>👥 관리 정보</h4>
                <div class="detail-item">
                    <strong>일반관리방식:</strong> ${detailData.codeMgr || '-'}
                </div>
                <div class="detail-item">
                    <strong>일반관리인원:</strong> ${detailData.kaptMgrCnt || '-'}명
                </div>
                <div class="detail-item">
                    <strong>일반관리 계약업체:</strong> ${detailData.kaptCcompany || '-'}
                </div>
                <div class="detail-item">
                    <strong>경비관리방식:</strong> ${detailData.codeSec || '-'}
                </div>
                <div class="detail-item">
                    <strong>경비관리인원:</strong> ${detailData.kaptdScnt || '-'}명
                </div>
                <div class="detail-item">
                    <strong>경비관리 계약업체:</strong> ${detailData.kaptdSecCom || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🧹 청소 및 환경</h4>
                <div class="detail-item">
                    <strong>청소관리방식:</strong> ${detailData.codeClean || '-'}
                </div>
                <div class="detail-item">
                    <strong>청소관리인원:</strong> ${detailData.kaptdClcnt || '-'}명
                </div>
                <div class="detail-item">
                    <strong>음식물처리방법:</strong> ${detailData.codeGarbage || '-'}
                </div>
                <div class="detail-item">
                    <strong>소독관리방식:</strong> ${detailData.codeDisinf || '-'}
                </div>
                <div class="detail-item">
                    <strong>연간소독횟수:</strong> ${detailData.kaptdDcnt || '-'}회
                </div>
                <div class="detail-item">
                    <strong>소독방법:</strong> ${detailData.disposalType || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>⚡ 전기 및 안전</h4>
                <div class="detail-item">
                    <strong>수전용량:</strong> ${detailData.kaptdEcapa || '-'}kW
                </div>
                <div class="detail-item">
                    <strong>세대전기계약방식:</strong> ${detailData.codeEcon || '-'}
                </div>
                <div class="detail-item">
                    <strong>전기안전관리자법정선임여부:</strong> ${detailData.codeEmgr || '-'}
                </div>
                <div class="detail-item">
                    <strong>화재수신반방식:</strong> ${detailData.codeFalarm || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🚰 급수 및 승강기</h4>
                <div class="detail-item">
                    <strong>급수방식:</strong> ${detailData.codeWsupply || '-'}
                </div>
                <div class="detail-item">
                    <strong>승강기관리형태:</strong> ${detailData.codeElev || '-'}
                </div>
                <div class="detail-item">
                    <strong>승강기대수:</strong> ${detailData.kaptdEcnt || '-'}대
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🚗 주차 및 시설</h4>
                <div class="detail-item">
                    <strong>주차대수(지상):</strong> ${detailData.kaptdPcnt || '-'}대
                </div>
                <div class="detail-item">
                    <strong>주차대수(지하):</strong> ${detailData.kaptdPcntu || '-'}대
                </div>
                <div class="detail-item">
                    <strong>주차관제.홈네트워크:</strong> ${detailData.codeNet || '-'}
                </div>
                <div class="detail-item">
                    <strong>CCTV대수:</strong> ${detailData.kaptdCccnt || '-'}대
                </div>
                <div class="detail-item">
                    <strong>부대.복리시설:</strong> ${detailData.welfareFacility || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🚌 교통 및 편의</h4>
                <div class="detail-item">
                    <strong>버스정류장 거리:</strong> ${detailData.kaptdWtimebus || '-'}분
                </div>
                <div class="detail-item">
                    <strong>지하철호선:</strong> ${detailData.subwayLine || '-'}
                </div>
                <div class="detail-item">
                    <strong>지하철역명:</strong> ${detailData.subwayStation || '-'}
                </div>
                <div class="detail-item">
                    <strong>지하철역 거리:</strong> ${detailData.kaptdWtimesub || '-'}분
                </div>
                <div class="detail-item">
                    <strong>편의시설:</strong> ${detailData.convenientFacility || '-'}
                </div>
                <div class="detail-item">
                    <strong>교육시설:</strong> ${detailData.educationFacility || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🔌 전기차 충전</h4>
                <div class="detail-item">
                    <strong>지상 전기차 충전기:</strong> ${detailData.groundElChargerCnt || '-'}대
                </div>
                <div class="detail-item">
                    <strong>지하 전기차 충전기:</strong> ${detailData.undergroundElChargerCnt || '-'}대
                </div>
            </div>
        </div>
    `;
    
    detailSection.innerHTML = html;
    addressInfo.appendChild(detailSection);
}

/* =========================================== */
/* 7. BUILDING INFO API - 건물 정보 API */
/* =========================================== */

/**
 * 건물 정보 API 호출 (1-10페이지 순차 호출)
 * @param {string} sigunguCd - 시군구코드 (행정구역코드 앞 5자리)
 * @param {string} bjdongCd - 법정동코드 (행정구역코드 뒤 5자리)
 * @param {string} bun - 지번본번 (4자리, 2자리인 경우 앞에 00을 붙임)
 */
async function loadBuildingInfo(sigunguCd, bjdongCd, bun) {
    // 1-10페이지 순차 호출
    for (let pageNo = 1; pageNo <= 10; pageNo++) {
        try {
            const params = new URLSearchParams({
                serviceKey: BUILDING_API_CONFIG.apiKey,
                sigunguCd: sigunguCd,
                bjdongCd: bjdongCd,
                _type: 'json',
                bun: bun,
                pageNo: pageNo,
                numOfRows: BUILDING_API_CONFIG.numOfRows
            });
            
            // 환경에 따른 API 호출 방식 선택
            let url;
            const isLocal = window.location.hostname === 'localhost' || 
                            window.location.hostname === '127.0.0.1' || 
                            window.location.protocol === 'file:' ||
                            window.location.hostname === '';
            const isGitHub = !isLocal && (
                window.location.hostname === 'github.io' || 
                window.location.hostname.includes('github.io')
            );
            
            if (isGitHub) {
                // GitHub Pages: 직접 호출
                url = `${BUILDING_API_CONFIG.baseUrl}?${params.toString()}`;
            } else {
                // 로컬 개발: 프록시 서버 사용
                url = `http://localhost:3001/api/building?${params.toString()}`;
            }
            
            const response = await fetch(url);
            
            if (!response.ok) {
                console.error(`🏗️ 페이지 ${pageNo} HTTP 오류:`, response.status, response.statusText);
                continue; // 다음 페이지로 계속
            }
            
            const contentType = response.headers.get('content-type');
            
            let data;
            if (contentType && contentType.includes('application/json')) {
                data = await response.json();
            } else {
                const xmlText = await response.text();
                data = parseBuildingXML(xmlText);
            }
            
            if (data.response && data.response.header && data.response.header.resultCode === '00') {
                displayBuildingInfo(data.response.body, pageNo);
            }
            
        } catch (error) {
            console.error(`🏗️ 페이지 ${pageNo} API 호출 오류:`, error);
        }
        
        // 페이지 간 간격 (API 서버 부하 방지)
        if (pageNo < 10) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
}

/* =========================================== */
/* 8. GEOCODER API - 주소 좌표 변환 API */
/* =========================================== */

/**
 * 주소를 좌표로 변환하는 API 호출
 * @param {string} address - 도로명주소
 */
async function loadGeocoderInfo(address) {
    try {
        const params = new URLSearchParams({
            service: GEOCODER_API_CONFIG.service,
            request: GEOCODER_API_CONFIG.request,
            version: GEOCODER_API_CONFIG.version,
            key: GEOCODER_API_CONFIG.apiKey,
            format: GEOCODER_API_CONFIG.format,
            type: GEOCODER_API_CONFIG.type,
            crs: GEOCODER_API_CONFIG.crs,
            refine: GEOCODER_API_CONFIG.refine,
            simple: GEOCODER_API_CONFIG.simple,
            address: address
        });
        
        const url = `${GEOCODER_API_CONFIG.baseUrl}?${params.toString()}`;
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.response && data.response.status === 'OK') {
            displayGeocoderInfo(data.response);
            
            // 좌표 정보가 있으면 토지이용계획도 API 호출
            if (data.response.result && data.response.result.point) {
                const point = data.response.result.point;
                console.log('🏗️ Geocoder에서 좌표 획득:', point);
                console.log('🏗️ 토지이용계획도 API 호출 시작:', { x: point.x, y: point.y });
                loadLandUseInfo(point.x, point.y);
            } else {
                console.log('🏗️ Geocoder에서 좌표 정보를 찾을 수 없습니다.');
                console.log('🏗️ data.response.result:', data.response.result);
            }
        } else {
            console.error('🌍 Geocoder API 실패:', data.response?.status, data.response?.error);
        }
        
    } catch (error) {
        console.error('🌍 Geocoder API 호출 오류:', error);
    }
}

/**
 * 좌표 정보 표시 함수
 * @param {Object} geocoderData - 좌표 데이터
 */
function displayGeocoderInfo(geocoderData) {
    const addressInfo = document.querySelector('.address-info');
    
    if (!geocoderData.result || !geocoderData.result.point) {
        return;
    }
    
    const point = geocoderData.result.point;
    const refined = geocoderData.refined;
    const input = geocoderData.input;
    
    // 기존 좌표 정보 섹션이 있으면 제거
    const existingGeocoder = document.getElementById('geocoderInfo');
    if (existingGeocoder) {
        existingGeocoder.remove();
    }
    
    // 좌표 정보 섹션 생성
    const geocoderSection = document.createElement('div');
    geocoderSection.id = 'geocoderInfo';
    geocoderSection.className = 'info-card';
    
    // 좌표 정보를 HTML 문자열로 구성
    const html = `
        <h2>🌍 좌표 정보</h2>
        <div class="building-detail-grid">
            <div class="detail-group">
                <h4>📍 좌표 정보</h4>
                <div class="detail-item">
                    <strong>X좌표 (경도):</strong> ${point.x || '-'}
                </div>
                <div class="detail-item">
                    <strong>Y좌표 (위도):</strong> ${point.y || '-'}
                </div>
                <div class="detail-item">
                    <strong>좌표계:</strong> ${geocoderData.result.crs || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🏠 정제된 주소 정보</h4>
                <div class="detail-item">
                    <strong>전체 주소:</strong> ${refined?.text || '-'}
                </div>
                <div class="detail-item">
                    <strong>시도:</strong> ${refined?.structure?.level1 || '-'}
                </div>
                <div class="detail-item">
                    <strong>시군구:</strong> ${refined?.structure?.level2 || '-'}
                </div>
                <div class="detail-item">
                    <strong>읍면동:</strong> ${refined?.structure?.level4L || '-'}
                </div>
                <div class="detail-item">
                    <strong>도로명:</strong> ${refined?.structure?.level4L || '-'}
                </div>
                <div class="detail-item">
                    <strong>건물번호:</strong> ${refined?.structure?.level5 || '-'}
                </div>
                <div class="detail-item">
                    <strong>상세주소:</strong> ${refined?.structure?.detail || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🔍 입력 정보</h4>
                <div class="detail-item">
                    <strong>입력 주소:</strong> ${geocoderData.input?.address || '-'}
                </div>
                <div class="detail-item">
                    <strong>주소 유형:</strong> ${geocoderData.input?.type || '-'}
                </div>
                <div class="detail-item">
                    <strong>처리 상태:</strong> ${geocoderData.status || '-'}
                </div>
            </div>
        </div>
    `;
    
    geocoderSection.innerHTML = html;
    
    // 페이지에 추가
    if (addressInfo) {
        addressInfo.appendChild(geocoderSection);
    } else {
        console.error('🌍 address-info 요소를 찾을 수 없습니다.');
    }
}

/**
 * 토지이용계획도 API 호출
 * @param {string} x - X좌표 (경도)
 * @param {string} y - Y좌표 (위도)
 */
async function loadLandUseInfo(x, y) {
    try {
        console.log('🏗️ 토지이용계획도 API 호출 시작:', { x, y });
        console.log('🏗️ 건물관리번호 (pnu):', window.buildingManagementNumber);
        
        const params = new URLSearchParams({
            service: LAND_USE_API_CONFIG.service,
            request: LAND_USE_API_CONFIG.request,
            version: LAND_USE_API_CONFIG.version,
            key: LAND_USE_API_CONFIG.apiKey,
            format: LAND_USE_API_CONFIG.format,
            data: LAND_USE_API_CONFIG.data,
            crs: LAND_USE_API_CONFIG.crs,
            size: LAND_USE_API_CONFIG.size,
            page: LAND_USE_API_CONFIG.page,
            geometry: LAND_USE_API_CONFIG.geometry,
            attribute: LAND_USE_API_CONFIG.attribute,
            geomFilter: `POINT(${x} ${y})`,
            pnu: window.buildingManagementNumber || ''
        });
        
        const url = `${LAND_USE_API_CONFIG.baseUrl}?${params.toString()}`;
        console.log('🏗️ 토지이용계획도 API 호출 URL:', url);
        console.log('🏗️ 전달 파라미터:', {
            service: LAND_USE_API_CONFIG.service,
            request: LAND_USE_API_CONFIG.request,
            version: LAND_USE_API_CONFIG.version,
            key: LAND_USE_API_CONFIG.apiKey,
            format: LAND_USE_API_CONFIG.format,
            data: LAND_USE_API_CONFIG.data,
            crs: LAND_USE_API_CONFIG.crs,
            size: LAND_USE_API_CONFIG.size,
            page: LAND_USE_API_CONFIG.page,
            geometry: LAND_USE_API_CONFIG.geometry,
            attribute: LAND_USE_API_CONFIG.attribute,
            geomFilter: `POINT(${x} ${y})`,
            pnu: window.buildingManagementNumber || ''
        });
        
        const response = await fetch(url);
        console.log('🏗️ 응답 상태:', response.status);
        console.log('🏗️ 응답 헤더:', response.headers);
        
        if (!response.ok) {
            console.error('🏗️ HTTP 오류:', response.status, response.statusText);
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log('🏗️ 토지이용계획도 API 응답:', data);
        console.log('🏗️ 응답 구조 분석:', {
            hasService: !!data.service,
            hasStatus: !!data.status,
            hasRecord: !!data.record,
            hasPage: !!data.page,
            hasResult: !!data.result,
            hasError: !!data.error,
            status: data.status,
            error: data.error,
            serviceInfo: data.service,
            recordInfo: data.record,
            pageInfo: data.page,
            resultInfo: data.result
        });
        
        if (data.landUses && data.landUses.field) {
            console.log('🏗️ 성공 응답 - 토지이용계획 정보 표시');
            displayLandUseInfo(data);
        } else {
            console.error('🏗️ 토지이용계획도 API 실패:', data.resultCode, data.resultMsg);
            console.log('🏗️ 전체 응답 데이터:', JSON.stringify(data, null, 2));
        }
        
    } catch (error) {
        console.error('🏗️ 토지이용계획도 API 호출 오류:', error);
        console.error('🏗️ 오류 스택:', error.stack);
    }
}

/**
 * 토지이용계획 정보 표시 함수
 * @param {Object} landUseData - 토지이용계획 데이터
 */
function displayLandUseInfo(landUseData) {
    console.log('🏗️ displayLandUseInfo 함수 호출됨:', landUseData);
    
    const addressInfo = document.querySelector('.address-info');
    console.log('🏗️ address-info 요소 찾음:', addressInfo);
    
    if (!landUseData.landUses || !landUseData.landUses.field || landUseData.landUses.field.length === 0) {
        console.log('🏗️ 토지이용계획 데이터가 없습니다.');
        console.log('🏗️ landUseData.landUses:', landUseData.landUses);
        console.log('🏗️ 전체 landUseData:', landUseData);
        return;
    }
    
    const features = landUseData.landUses.field;
    console.log('🏗️ 토지이용계획 features:', features);
    console.log('🏗️ features 개수:', features.length);
    
    // 첫 번째 feature의 상세 확인
    if (features.length > 0) {
        console.log('🏗️ 첫 번째 feature:', features[0]);
        console.log('🏗️ feature 키들:', Object.keys(features[0] || {}));
    }
    
    // 기존 토지이용계획 정보 섹션이 있으면 제거
    const existingLandUse = document.getElementById('landUseInfo');
    if (existingLandUse) {
        console.log('🏗️ 기존 토지이용계획 정보 섹션 제거');
        existingLandUse.remove();
    }
    
    // 토지이용계획 정보 섹션 생성
    const landUseSection = document.createElement('div');
    landUseSection.id = 'landUseInfo';
    landUseSection.className = 'info-card';
    
    const html = `
        <div class="info-card-header">
            <h3>🏗️ 토지이용계획 정보</h3>
        </div>
        <div class="info-card-content">
            <div class="detail-group">
                <h4>📊 계획 정보</h4>
                <div class="detail-item">
                    <strong>총 건수:</strong> ${landUseData.landUses?.totalCount || '-'}
                </div>
                <div class="detail-item">
                    <strong>현재 페이지:</strong> ${landUseData.landUses?.pageNo || '-'}
                </div>
                <div class="detail-item">
                    <strong>페이지당 건수:</strong> ${landUseData.landUses?.numOfRows || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🏘️ 토지이용계획 상세</h4>
                ${features.map((feature, index) => `
                    <div class="feature-item">
                        <h5>계획구역 ${index + 1}</h5>
                        <div class="detail-item">
                            <strong>고유번호 (pnu):</strong> ${feature.pnu || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>법정동코드:</strong> ${feature.ldCode || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>법정동명:</strong> ${feature.ldCodeNm || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>대장구분코드:</strong> ${feature.regstrSeCode || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>대장구분명:</strong> ${feature.regstrSeCodeNm || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>지번:</strong> ${feature.mnnmSlno || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>도면번호:</strong> ${feature.manageNo || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>저촉여부코드:</strong> ${feature.cnflcAt || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>저촉여부:</strong> ${feature.cnflcAtNm || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>용도지역지구코드:</strong> ${feature.prposAreaDstrcCode || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>용도지역지구명:</strong> ${feature.prposAreaDstrcCodeNm || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>등록일자:</strong> ${feature.registDt || '-'}
                        </div>
                        <div class="detail-item">
                            <strong>데이터기준일자:</strong> ${feature.lastUpdtDt || '-'}
                        </div>
                    </div>
                `).join('')}
            </div>
        </div>
    `;
    
    landUseSection.innerHTML = html;
    
    // 페이지에 추가
    if (addressInfo) {
        addressInfo.appendChild(landUseSection);
        console.log('🏗️ 토지이용계획 정보 섹션 추가 완료');
    } else {
        console.error('🏗️ address-info 요소를 찾을 수 없습니다.');
    }
}

    /**
     * XML 응답을 JSON으로 파싱하는 함수
     * @param {string} xmlText - XML 텍스트
     * @returns {Object} 파싱된 JSON 객체
     */
    function parseBuildingXML(xmlText) {
        try {
            // 간단한 XML 파싱 (정규식 사용)
            const parser = new DOMParser();
            const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
            
            // 에러 체크
            const errorNode = xmlDoc.querySelector('parsererror');
            if (errorNode) {
                // XML 파싱 오류 처리
                return { header: { resultCode: '99', resultMsg: 'XML 파싱 오류' } };
            }
            
            // 응답 구조 파싱
            const result = {
                header: {
                    resultCode: '00',
                    resultMsg: 'NORMAL SERVICE'
                },
                body: {
                    items: {
                        item: {}
                    }
                }
            };
            
            // XML에서 데이터 추출
            const item = xmlDoc.querySelector('item');
            if (item) {
                const buildingData = {};
                const fields = [
                    'bldNm', 'platPlc', 'newPlatPlc', 'dongNm', 'bun', 'ji',
                    'mainPurpsCdNm', 'etcPurps', 'strctCdNm', 'etcStrct', 'roofCdNm', 'etcRoof',
                    'platArea', 'archArea', 'totArea', 'bcRat', 'vlRat',
                    'grndFlrCnt', 'ugrndFlrCnt', 'heit', 'hhldCnt', 'hoCnt',
                    'rideUseElvtCnt', 'emgenUseElvtCnt', 'indrAutoUtcnt', 'indrAutoArea',
                    'oudrAutoUtcnt', 'oudrAutoArea', 'indrMechUtcnt', 'indrMechArea',
                    'oudrMechUtcnt', 'oudrMechArea', 'useAprDay', 'stcnsDay', 'pmsDay',
                    'pmsnoYear', 'pmsnoKikCdNm', 'pmsnoGbCdNm', 'engrGrade', 'engrRat',
                    'engrEpi', 'gnBldGrade', 'gnBldCert', 'itgBldGrade', 'itgBldCert'
                ];
                
                fields.forEach(field => {
                    const element = item.querySelector(field);
                    buildingData[field] = element ? element.textContent : '-';
                });
                
                result.body.items.item = buildingData;
            }
            
            return result;
        } catch (error) {
            // XML 파싱 오류 처리
            return { header: { resultCode: '99', resultMsg: 'XML 파싱 오류' } };
        }
    }

/**
 * 건물 정보 표시
 * @param {Object} buildingData - 건물 데이터
 */
function displayBuildingInfo(buildingData, pageNo) {
    // 기존 건물 정보 섹션이 있으면 제거 (페이지별로 구분)
    const existingBuilding = document.getElementById(`buildingInfoPage${pageNo}`);
    if (existingBuilding) {
        existingBuilding.remove();
    }
    
    const addressInfo = document.querySelector('.address-info');
    
    if (!buildingData.items || !buildingData.items.item) {
        return;
    }
    
    const building = buildingData.items.item;
    
    // 건물 데이터가 없는 경우 처리
    if (!building || (Array.isArray(building) && building.length === 0)) {
        return;
    }
    
    // 건물 정보 섹션 생성 (페이지별로 구분)
    const buildingSection = document.createElement('div');
    buildingSection.id = `buildingInfoPage${pageNo}`;
    buildingSection.className = 'info-card';
    
    // 실제 건물 데이터 (배열인 경우 첫 번째 항목 사용)
    const buildingInfo = Array.isArray(building) ? building[0] : building;
    
    // buildingInfo가 유효한지 확인
    if (!buildingInfo) {
        return;
    }
    
    const html = `
        <h2>🏗️ 건물 정보 (페이지 ${pageNo})</h2>
        <div class="building-detail-grid">
            <div class="detail-group">
                <h4>📍 기본 정보</h4>
                <div class="detail-item">
                    <strong>건물명:</strong> ${buildingInfo.bldNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>소재지:</strong> ${buildingInfo.platPlc || '-'}
                </div>
                <div class="detail-item">
                    <strong>신소재지:</strong> ${buildingInfo.newPlatPlc || '-'}
                </div>
                <div class="detail-item">
                    <strong>동명:</strong> ${buildingInfo.dongNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>본번:</strong> ${buildingInfo.bun || '-'}
                </div>
                <div class="detail-item">
                    <strong>부번:</strong> ${buildingInfo.ji || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🏠 용도 및 구조</h4>
                <div class="detail-item">
                    <strong>주용도:</strong> ${buildingInfo.mainPurpsCdNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>기타용도:</strong> ${buildingInfo.etcPurps || '-'}
                </div>
                <div class="detail-item">
                    <strong>구조:</strong> ${buildingInfo.strctCdNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>기타구조:</strong> ${buildingInfo.etcStrct || '-'}
                </div>
                <div class="detail-item">
                    <strong>지붕:</strong> ${buildingInfo.roofCdNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>기타지붕:</strong> ${buildingInfo.etcRoof || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>📊 면적 정보</h4>
                <div class="detail-item">
                    <strong>대지면적:</strong> ${buildingInfo.platArea || '-'}㎡
                </div>
                <div class="detail-item">
                    <strong>건축면적:</strong> ${buildingInfo.archArea || '-'}㎡
                </div>
                <div class="detail-item">
                    <strong>연면적:</strong> ${buildingInfo.totArea || '-'}㎡
                </div>
                <div class="detail-item">
                    <strong>건폐율:</strong> ${buildingInfo.bcRat || '-'}%
                </div>
                <div class="detail-item">
                    <strong>용적율:</strong> ${buildingInfo.vlRat || '-'}%
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🏢 건물 규모</h4>
                <div class="detail-item">
                    <strong>지상층수:</strong> ${buildingInfo.grndFlrCnt || '-'}층
                </div>
                <div class="detail-item">
                    <strong>지하층수:</strong> ${buildingInfo.ugrndFlrCnt || '-'}층
                </div>
                <div class="detail-item">
                    <strong>높이:</strong> ${buildingInfo.heit || '-'}m
                </div>
                <div class="detail-item">
                    <strong>세대수:</strong> ${buildingInfo.hhldCnt || '-'}세대
                </div>
                <div class="detail-item">
                    <strong>호수:</strong> ${buildingInfo.hoCnt || '-'}호
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🚗 주차 및 승강기</h4>
                <div class="detail-item">
                    <strong>승용승강기:</strong> ${buildingInfo.rideUseElvtCnt || '-'}대
                </div>
                <div class="detail-item">
                    <strong>비상승강기:</strong> ${buildingInfo.emgenUseElvtCnt || '-'}대
                </div>
                <div class="detail-item">
                    <strong>지하주차:</strong> ${buildingInfo.indrAutoUtcnt || '-'}대 (${buildingInfo.indrAutoArea || '-'}㎡)
                </div>
                <div class="detail-item">
                    <strong>지상주차:</strong> ${buildingInfo.oudrAutoUtcnt || '-'}대 (${buildingInfo.oudrAutoArea || '-'}㎡)
                </div>
                <div class="detail-item">
                    <strong>지하기계식:</strong> ${buildingInfo.indrMechUtcnt || '-'}대 (${buildingInfo.indrMechArea || '-'}㎡)
                </div>
                <div class="detail-item">
                    <strong>지상기계식:</strong> ${buildingInfo.oudrMechUtcnt || '-'}대 (${buildingInfo.oudrMechArea || '-'}㎡)
                </div>
            </div>
            
            <div class="detail-group">
                <h4>📅 건축 정보</h4>
                <div class="detail-item">
                    <strong>사용승인일:</strong> ${buildingInfo.useAprDay || '-'}
                </div>
                <div class="detail-item">
                    <strong>착공일:</strong> ${buildingInfo.stcnsDay || '-'}
                </div>
                <div class="detail-item">
                    <strong>준공일:</strong> ${buildingInfo.pmsDay || '-'}
                </div>
                <div class="detail-item">
                    <strong>건축연도:</strong> ${buildingInfo.pmsnoYear || '-'}
                </div>
                <div class="detail-item">
                    <strong>건축주:</strong> ${buildingInfo.pmsnoKikCdNm || '-'}
                </div>
                <div class="detail-item">
                    <strong>설계자:</strong> ${buildingInfo.pmsnoGbCdNm || '-'}
                </div>
            </div>
            
            <div class="detail-group">
                <h4>🏆 인증 정보</h4>
                <div class="detail-item">
                    <strong>에너지등급:</strong> ${buildingInfo.engrGrade || '-'}
                </div>
                <div class="detail-item">
                    <strong>에너지효율:</strong> ${buildingInfo.engrRat || '-'}
                </div>
                <div class="detail-item">
                    <strong>에너지EPI:</strong> ${buildingInfo.engrEpi || '-'}
                </div>
                <div class="detail-item">
                    <strong>녹색건물등급:</strong> ${buildingInfo.gnBldGrade || '-'}
                </div>
                <div class="detail-item">
                    <strong>녹색건물인증:</strong> ${buildingInfo.gnBldCert || '-'}
                </div>
                <div class="detail-item">
                    <strong>통합건물등급:</strong> ${buildingInfo.itgBldGrade || '-'}
                </div>
                <div class="detail-item">
                    <strong>통합건물인증:</strong> ${buildingInfo.itgBldCert || '-'}
                </div>
            </div>
        </div>
    `;
    
    buildingSection.innerHTML = html;
    addressInfo.appendChild(buildingSection);
}

/* =========================================== */
/* 8. UTILITY FUNCTIONS - 유틸리티 함수 */
/* =========================================== */

/**
 * 페이지 뒤로가기
 */
function goBack() {
    window.history.back();
}

/**
 * 매물 요청 제출
 */
function submitRequest() {
    // 실제 구현에서는 서버로 데이터 전송
    alert('매물 요청이 제출되었습니다. 빠른 시일 내에 연락드리겠습니다.');
}
