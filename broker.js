/* =========================================== */
/* HOUSE MVP - 공인중개사 찾기 JavaScript */
/* 부동산중개업WFS조회 API 연동 */
/* =========================================== */

/* =========================================== */
/* 1. API CONFIGURATION - API 설정 */
/* =========================================== */

/**
 * VWorld 부동산중개업WFS조회 API 설정
 */
const BROKER_API_CONFIG = {
    baseUrl: 'https://api.vworld.kr/ned/wfs/getEstateBrkpgWFS', // http → https
    apiKey: 'FA0D6750-3DC2-3389-B8F1-0385C5976B96',
    typename: 'dt_d170',
    maxFeatures: 30, // 10 → 30으로 증가
    resultType: 'results',
    srsName: 'EPSG:4326',
    output: 'GML2'
};

// 이전 페이지에서 전달받은 데이터
let transferData = null;

// 공인중개사 데이터 (거리순 정렬됨)
let allBrokers = [];
let currentFilter = 'top3'; // 'top3' 또는 'all'

/* =========================================== */
/* 2. PAGE INITIALIZATION - 페이지 초기화 */
/* =========================================== */

document.addEventListener('DOMContentLoaded', async () => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🏘️ [공인중개사 찾기 페이지] 초기화 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ 1단계: DOMContentLoaded 이벤트 발생');
    console.log('   📍 현재 위치:', window.location.href);
    console.log('   🌐 호스트명:', window.location.hostname);
    console.log('   🔒 프로토콜:', window.location.protocol);
    
    // localStorage에서 데이터 가져오기
    console.log('\n✅ 2단계: localStorage에서 데이터 읽기 시도');
    const storedData = localStorage.getItem('brokerSearchData');
    
    if (!storedData) {
        console.error('❌ localStorage에 brokerSearchData가 없습니다!');
        console.log('   💾 사용 가능한 localStorage 키:', Object.keys(localStorage));
        alert('검색 데이터가 없습니다. 이전 페이지로 돌아갑니다.');
        window.location.href = 'result.html';
        return;
    }
    
    console.log('✅ brokerSearchData 발견!');
    console.log('   📏 데이터 크기:', storedData.length, '바이트');
    
    try {
        console.log('\n✅ 3단계: JSON 파싱 시도');
        transferData = JSON.parse(storedData);
        console.log('✅ JSON 파싱 성공!');
        console.log('   📦 전달받은 데이터 구조:');
        console.log('      - addressInfo:', transferData.addressInfo ? '✓' : '✗');
        console.log('      - geocoderInfo:', transferData.geocoderInfo ? '✓' : '✗');
        console.log('      - landInfo:', transferData.landInfo ? '✓' : '✗');
        
        if (transferData.geocoderInfo && transferData.geocoderInfo.result) {
            const point = transferData.geocoderInfo.result.point;
            console.log('      - 좌표:', point ? `(${point.y}, ${point.x})` : '없음');
        }
        
        // 주소 요약 카드 표시
        console.log('\n✅ 4단계: 주소 요약 카드 표시');
        displayAddressSummaryCard();
        
        // 공인중개사 검색
        console.log('\n✅ 5단계: 공인중개사 검색 시작');
        await searchBrokers();
        
    } catch (error) {
        console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.error('❌ [치명적 오류] 데이터 처리 실패');
        console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.error('   오류 타입:', error.name);
        console.error('   오류 메시지:', error.message);
        console.error('   스택 트레이스:', error.stack);
        alert('데이터 처리 중 오류가 발생했습니다.');
    }
});

/* =========================================== */
/* 3. DISPLAY FUNCTIONS - 화면 표시 함수 */
/* =========================================== */

/**
 * 주소 요약 카드 표시
 */
function displayAddressSummaryCard() {
    if (!transferData || !transferData.addressInfo) {
        console.warn('⚠️ 주소 정보가 없습니다.');
        return;
    }
    
    const container = document.getElementById('addressSummaryCard');
    if (!container) return;
    
    const addressInfo = transferData.addressInfo;
    const geocoderInfo = transferData.geocoderInfo;
    const landInfo = transferData.landInfo;
    
    // PNU 생성
    const pnu = generatePNU(addressInfo);
    
    // 좌표 정보
    let coordinates = '-';
    if (geocoderInfo && geocoderInfo.result && geocoderInfo.result.point) {
        const point = geocoderInfo.result.point;
        coordinates = `${point.y}, ${point.x}`;
    }
    
    // 토지 정보에서 배지 데이터 추출
    let landBadges = '';
    if (landInfo && typeof landInfo === 'string') {
        try {
            const parser = new DOMParser();
            const xmlDoc = parser.parseFromString(landInfo, "text/xml");
            const feature = xmlDoc.querySelector('dt_d194');
            
            if (feature) {
                const area = feature.querySelector('lndpcl_ar')?.textContent || '-';
                const purpose = feature.querySelector('prpos_area_1_nm')?.textContent || '-';
                const year = feature.querySelector('stdr_year')?.textContent || '-';
                const price = feature.querySelector('pblntf_pclnd')?.textContent || '-';
                
                landBadges = `
                    <div class="summary-badges">
                        <span class="badge badge-area">📏 ${area}㎡</span>
                        <span class="badge badge-purpose">🗺️ ${purpose}</span>
                        <span class="badge badge-price">💰 ${year}년 ${price !== '-' ? price + '원/㎡' : '정보없음'}</span>
                    </div>
                `;
            }
        } catch (error) {
            console.warn('⚠️ 토지 정보 파싱 실패:', error);
        }
    }
    
    // 데이터 기준일 추출
    let dataBadge = '';
    if (landInfo && typeof landInfo === 'string') {
        try {
            const parser = new DOMParser();
            const xmlDoc = parser.parseFromString(landInfo, "text/xml");
            const feature = xmlDoc.querySelector('dt_d194');
            
            if (feature) {
                const year = feature.querySelector('stdr_year')?.textContent || '';
                const month = feature.querySelector('stdr_mt')?.textContent || '';
                
                if (year && month) {
                    dataBadge = `<span class="data-date-badge">📅 데이터 기준: ${year}년 ${month}월</span>`;
                }
            }
        } catch (error) {
            // 무시
        }
    }
    
    container.innerHTML = `
        <div class="info-card address-summary-card">
            <div class="summary-header">
                <h2>📍 주소 요약 ${dataBadge}</h2>
                <div class="summary-actions">
                    <button class="icon-btn" onclick="copyAddressInfo()" title="주소 복사">
                        📋 복사
                    </button>
                    <button class="icon-btn" onclick="shareAddressInfo()" title="공유 링크">
                        🔗 공유
                    </button>
                </div>
            </div>
            
            <div class="summary-content">
                <div class="summary-item">
                    <span class="summary-label">도로명주소</span>
                    <span class="summary-value">${addressInfo.roadAddr || '-'}</span>
                </div>
                <div class="summary-item">
                    <span class="summary-label">지번주소</span>
                    <span class="summary-value">${addressInfo.jibunAddr || '-'}</span>
                </div>
                <div class="summary-item">
                    <span class="summary-label">우편번호</span>
                    <span class="summary-value">${addressInfo.zipNo || '-'}</span>
                </div>
                <div class="summary-item">
                    <span class="summary-label">좌표 (위도, 경도)</span>
                    <span class="summary-value">${coordinates}</span>
                </div>
                <div class="summary-item">
                    <span class="summary-label">PNU (필지고유번호)</span>
                    <span class="summary-value">${pnu || '-'}</span>
                </div>
            </div>
            
            ${landBadges}
        </div>
    `;
}

/**
 * PNU 생성 함수 (19자리)
 */
function generatePNU(addressData) {
    if (!addressData) return null;
    
    const admCd = addressData.admCd || '';
    if (admCd.length !== 10) return null;
    
    const mtYn = addressData.mtYn || '0';
    const piljigubn = mtYn === '1' ? '2' : '1';
    
    const lnbrMnnm = addressData.lnbrMnnm || '0';
    const bun = lnbrMnnm.toString().padStart(4, '0');
    
    const lnbrSlno = addressData.lnbrSlno || '0';
    const ji = lnbrSlno.toString().padStart(4, '0');
    
    return `${admCd}${piljigubn}${bun}${ji}`;
}

/**
 * 주소 정보 복사
 */
function copyAddressInfo() {
    if (!transferData || !transferData.addressInfo) return;
    
    const addressInfo = transferData.addressInfo;
    const geocoderInfo = transferData.geocoderInfo;
    const pnu = generatePNU(addressInfo);
    
    let coordinates = '-';
    if (geocoderInfo && geocoderInfo.result && geocoderInfo.result.point) {
        const point = geocoderInfo.result.point;
        coordinates = `${point.y}, ${point.x}`;
    }
    
    const textToCopy = `
📍 주소 정보
━━━━━━━━━━━━━━━━━━━━━━
도로명주소: ${addressInfo.roadAddr || '-'}
지번주소: ${addressInfo.jibunAddr || '-'}
우편번호: ${addressInfo.zipNo || '-'}
좌표: ${coordinates}
PNU: ${pnu || '-'}
    `.trim();
    
    navigator.clipboard.writeText(textToCopy).then(() => {
        alert('✅ 주소 정보가 클립보드에 복사되었습니다!');
    }).catch(err => {
        console.error('❌ 복사 실패:', err);
        alert('복사에 실패했습니다.');
    });
}

/**
 * 주소 정보 공유 (공유 링크 생성)
 */
function shareAddressInfo() {
    if (!transferData || !transferData.addressInfo) return;
    
    const addressInfo = transferData.addressInfo;
    
    // 메인 페이지로 공유 링크 생성 (주소가 미리 채워진 상태)
    const baseUrl = window.location.origin + window.location.pathname.replace('broker.html', 'index.html');
    const shareUrl = `${baseUrl}?address=${encodeURIComponent(addressInfo.roadAddr || addressInfo.jibunAddr)}`;
    const shareText = `📍 ${addressInfo.roadAddr || addressInfo.jibunAddr}\n\nHouseMVP에서 확인하기:`;
    
    if (navigator.share) {
        navigator.share({
            title: 'HouseMVP - 주소 정보',
            text: shareText,
            url: shareUrl
        }).catch(err => {
            console.log('공유 취소 또는 실패:', err);
        });
    } else {
        // Web Share API 미지원 시 URL 복사
        const fullShareText = `${shareText}\n${shareUrl}`;
        navigator.clipboard.writeText(fullShareText).then(() => {
            alert('✅ 공유 링크가 클립보드에 복사되었습니다!\n\n이 링크를 공유하면 주소가 미리 입력된 상태로 열립니다.');
        }).catch(err => {
            console.error('❌ 복사 실패:', err);
        });
    }
}

/* =========================================== */
/* 4. API FUNCTIONS - API 호출 함수 */
/* =========================================== */

/**
 * 주변 공인중개사 검색
 */
async function searchBrokers() {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🏘️ [부동산중개업 API] 호출 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // BBOX 생성 (좌표 기반)
    const bbox = generateBBOX();
    
    if (!bbox) {
        console.error('❌ BBOX 생성 실패');
        displayNoResults('좌표 정보를 찾을 수 없습니다.');
        return;
    }
    
    try {
        const params = new URLSearchParams({
            key: BROKER_API_CONFIG.apiKey,
            typename: BROKER_API_CONFIG.typename,
            bbox: bbox,
            resultType: BROKER_API_CONFIG.resultType,
            srsName: BROKER_API_CONFIG.srsName,
            output: BROKER_API_CONFIG.output,
            maxFeatures: BROKER_API_CONFIG.maxFeatures
        });
        
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│  📤 [부동산중개업 API] 요청 내용        │');
        console.log('└─────────────────────────────────────────┘');
        console.log(`   🔑 key: ${BROKER_API_CONFIG.apiKey}`);
        console.log(`   📋 typename: ${BROKER_API_CONFIG.typename}`);
        console.log(`   📐 bbox: ${bbox}`);
        console.log(`   📊 resultType: ${BROKER_API_CONFIG.resultType}`);
        console.log(`   🗺️  srsName: ${BROKER_API_CONFIG.srsName}`);
        console.log(`   📄 output: ${BROKER_API_CONFIG.output}`);
        console.log(`   🔢 maxFeatures: ${BROKER_API_CONFIG.maxFeatures}`);
        
        // 환경 감지
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│  🔍 환경 감지                            │');
        console.log('└─────────────────────────────────────────┘');
        console.log('   🌐 hostname:', window.location.hostname);
        console.log('   🔒 protocol:', window.location.protocol);
        
        let url;
        const isLocal = window.location.hostname === 'localhost' || 
                        window.location.hostname === '127.0.0.1' || 
                        window.location.protocol === 'file:' ||
                        window.location.hostname === '';
        
        console.log('   📍 환경 판정:', isLocal ? '로컬 (프록시 사용)' : '웹 (직접 호출)');
        
        if (isLocal) {
            url = `http://localhost:3001/api/broker?${params.toString()}`;
            console.log('   ✓ 프록시 서버 사용');
        } else {
            url = `${BROKER_API_CONFIG.baseUrl}?${params.toString()}`;
            console.log('   ✓ VWorld API 직접 호출');
        }
        
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│  🚀 API 요청 전송                        │');
        console.log('└─────────────────────────────────────────┘');
        console.log('   🌐 요청 URL:');
        console.log('   ' + url);
        console.log('\n   ⏳ fetch() 호출 중...');
        
        const response = await fetch(url);
        
        console.log('   ✅ fetch() 완료!');
        console.log('   📊 응답 상태 코드:', response.status);
        console.log('   📄 응답 상태 텍스트:', response.statusText);
        console.log('   📋 응답 헤더:');
        console.log('      - Content-Type:', response.headers.get('Content-Type'));
        console.log('      - Content-Length:', response.headers.get('Content-Length'));
        
        if (!response.ok) {
            console.error('   ❌ HTTP 오류 발생!');
            console.error('   상태 코드:', response.status);
            console.error('   상태 텍스트:', response.statusText);
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        console.log('\n   📥 응답 본문 읽기 중...');
        const xmlText = await response.text();
        console.log('   ✅ 응답 본문 읽기 완료!');
        console.log('   📏 응답 크기:', xmlText.length, '바이트');
        
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│  📥 [부동산중개업 API] 응답 내용        │');
        console.log('└─────────────────────────────────────────┘');
        console.log('   ✅ 응답 상태: 성공 (XML/GML)');
        console.log('\n   📄 원본 XML 응답:');
        const xmlPreview = xmlText.substring(0, 1000);
        console.log('   ' + xmlPreview.replace(/\n/g, '\n   ') + (xmlText.length > 1000 ? '\n   ...(생략)...' : ''));
        
        // XML 파싱 및 표시
        parseBrokerXML(xmlText);
        
    } catch (error) {
        console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.error('❌ [부동산중개업 API] 에러 발생');
        console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.error('   오류 타입:', error.name);
        console.error('   오류 메시지:', error.message);
        console.error('   스택 트레이스:', error.stack);
        
        // fetch 에러의 경우 추가 정보
        if (error instanceof TypeError) {
            console.error('\n   💡 TypeError 발생 (네트워크 또는 CORS 문제 가능)');
            console.error('   원인 가능성:');
            console.error('      1. CORS 정책 위반');
            console.error('      2. 네트워크 연결 문제');
            console.error('      3. URL이 잘못됨');
            console.error('      4. Mixed Content (http/https 혼용)');
        }
        
        displayNoResults('공인중개사 정보를 불러오는 중 오류가 발생했습니다.');
    }
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

/**
 * BBOX 생성 (좌표 기반 사각형 영역)
 * @param {number} distance - 중심점으로부터의 거리 (미터, 기본값: 1000m = 1km)
 */
function generateBBOX(distance = 1000) {
    console.log('\n┌─────────────────────────────────────────┐');
    console.log('│  📐 BBOX 생성                            │');
    console.log('└─────────────────────────────────────────┘');
    console.log('   📏 검색 반경:', distance, 'm');
    
    if (!transferData) {
        console.error('   ❌ transferData가 없습니다!');
        return null;
    }
    
    if (!transferData.geocoderInfo) {
        console.error('   ❌ geocoderInfo가 없습니다!');
        console.log('   transferData 내용:', Object.keys(transferData));
        return null;
    }
    
    if (!transferData.geocoderInfo.result) {
        console.error('   ❌ geocoderInfo.result가 없습니다!');
        console.log('   geocoderInfo 내용:', Object.keys(transferData.geocoderInfo));
        return null;
    }
    
    const point = transferData.geocoderInfo.result.point;
    if (!point) {
        console.error('   ❌ point가 없습니다!');
        console.log('   result 내용:', Object.keys(transferData.geocoderInfo.result));
        return null;
    }
    
    if (!point.x || !point.y) {
        console.error('   ❌ 좌표값이 유효하지 않습니다!');
        console.log('   point.x:', point.x);
        console.log('   point.y:', point.y);
        return null;
    }
    
    console.log('   ✅ 좌표 정보 확인 완료');
    console.log('   📍 중심 좌표:');
    console.log('      - 경도(X):', point.x);
    console.log('      - 위도(Y):', point.y);
    
    const x = parseFloat(point.x);
    const y = parseFloat(point.y);
    
    // 위도/경도 1도당 거리 (대략적)
    // 위도 1도 ≈ 111km
    // 경도 1도 ≈ 111km * cos(위도)
    const latDelta = distance / 111000;
    const lonDelta = distance / (111000 * Math.cos(y * Math.PI / 180));
    
    const ymin = y - latDelta;
    const xmin = x - lonDelta;
    const ymax = y + latDelta;
    const xmax = x + lonDelta;
    
    // EPSG:4326의 경우 (ymin,xmin,ymax,xmax) 순서
    const bbox = `${ymin},${xmin},${ymax},${xmax},EPSG:4326`;
    
    console.log('\n   🔢 계산된 BBOX:');
    console.log('      - ymin (최소 위도):', ymin);
    console.log('      - xmin (최소 경도):', xmin);
    console.log('      - ymax (최대 위도):', ymax);
    console.log('      - xmax (최대 경도):', xmax);
    console.log('   ✅ 최종 BBOX 문자열:', bbox);
    
    return bbox;
}

/**
 * XML 응답 파싱 및 화면 표시
 * @param {string} xmlText - XML 텍스트
 */
function parseBrokerXML(xmlText) {
    console.log('\n┌─────────────────────────────────────────┐');
    console.log('│  🔍 XML 파싱 시작                        │');
    console.log('└─────────────────────────────────────────┘');
    console.log('   📄 XML 텍스트 길이:', xmlText.length, '바이트');
    
    try {
        console.log('   ⏳ DOMParser로 XML 파싱 중...');
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(xmlText, "text/xml");
        console.log('   ✅ DOMParser 파싱 완료');
        
        // 에러 체크
        console.log('   🔍 파서 오류 체크 중...');
        const parserError = xmlDoc.querySelector('parsererror');
        if (parserError) {
            console.error('   ❌ XML 파싱 오류 발견!');
            console.error('   오류 내용:', parserError.textContent);
            throw new Error('XML 파싱 오류');
        }
        console.log('   ✅ 파서 오류 없음');
        
        // dt_d170 피처 찾기
        console.log('\n   🔍 dt_d170 피처 검색 중...');
        const features = xmlDoc.querySelectorAll('dt_d170');
        
        console.log('   ✅ dt_d170 피처 검색 완료');
        console.log('   📊 검색된 공인중개사 수:', features.length, '개');
        
        if (features.length === 0) {
            console.warn('   ⚠️ 공인중개사가 0개입니다.');
            console.log('   🔍 다른 태그 확인:');
            console.log('      - wfs:FeatureCollection:', xmlDoc.querySelectorAll('wfs\\:FeatureCollection, FeatureCollection').length);
            console.log('      - gml:featureMember:', xmlDoc.querySelectorAll('gml\\:featureMember, featureMember').length);
            
            // 전체 XML 구조 출력
            console.log('\n   📄 XML 루트 엘리먼트:', xmlDoc.documentElement.tagName);
            console.log('   📄 전체 XML (처음 500자):');
            console.log('   ' + xmlText.substring(0, 500).replace(/\n/g, '\n   '));
            
            displayNoResults('주변에 등록된 공인중개사가 없습니다.');
            return;
        }
        
        // 거리 계산 및 정렬
        console.log('\n   📏 거리 계산 및 정렬 시작...');
        allBrokers = calculateDistances(features);
        console.log('   ✅ 거리 계산 완료:', allBrokers.length, '개');
        
        // 상위 3곳 먼저 표시
        console.log('\n   🎨 화면에 표시 (상위 3곳)');
        displayBrokerList(allBrokers.slice(0, 3));
        console.log('   ✅ 표시 완료!');
        
    } catch (error) {
        console.error('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.error('❌ [XML 파싱 오류] 파싱 실패');
        console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.error('   오류 타입:', error.name);
        console.error('   오류 메시지:', error.message);
        console.error('   스택 트레이스:', error.stack);
        displayNoResults('데이터 처리 중 오류가 발생했습니다.');
    }
}

/**
 * 각 공인중개사까지의 거리 계산 및 정렬
 * @param {NodeList} features - XML 피처 노드 리스트
 * @returns {Array} 거리순으로 정렬된 공인중개사 배열
 */
function calculateDistances(features) {
    console.log('\n   ┌─────────────────────────────────────┐');
    console.log('   │  📏 거리 계산                        │');
    console.log('   └─────────────────────────────────────┘');
    
    if (!transferData || !transferData.geocoderInfo || !transferData.geocoderInfo.result) {
        console.warn('   ⚠️ 기준 좌표가 없습니다.');
        return Array.from(features).map((feature, index) => ({
            feature: feature,
            distance: null,
            index: index
        }));
    }
    
    const basePoint = transferData.geocoderInfo.result.point;
    const baseLat = parseFloat(basePoint.y);
    const baseLon = parseFloat(basePoint.x);
    
    console.log('   📍 기준 좌표: (위도:', baseLat, ', 경도:', baseLon, ')');
    console.log('   🔢 처리할 중개사 수:', features.length, '개');
    
    const brokersWithDistance = Array.from(features).map((feature, index) => {
        const xCrdnt = feature.querySelector('x_crdnt')?.textContent;
        const yCrdnt = feature.querySelector('y_crdnt')?.textContent;
        const name = feature.querySelector('bsnm_cmpnm')?.textContent || `중개사${index + 1}`;
        
        let distance = null;
        
        // EPSG:5186 좌표를 WGS84로 변환 (간단한 근사치)
        // 또는 좌표가 이미 WGS84인 경우
        if (xCrdnt && yCrdnt) {
            const brokerLon = parseFloat(xCrdnt);
            const brokerLat = parseFloat(yCrdnt);
            
            console.log(`   ${index + 1}. ${name}: (${brokerLat}, ${brokerLon})`);
            
            // Haversine 공식으로 거리 계산 (미터 단위)
            distance = calculateHaversineDistance(baseLat, baseLon, brokerLat, brokerLon);
            console.log(`      → 거리: ${distance !== null ? distance.toFixed(0) + 'm' : '계산 불가'}`);
        } else {
            console.log(`   ${index + 1}. ${name}: 좌표 없음 (x:${xCrdnt}, y:${yCrdnt})`);
        }
        
        return {
            feature: feature,
            distance: distance,
            index: index
        };
    });
    
    // 거리순으로 정렬 (가까운 순)
    console.log('\n   🔄 거리순 정렬 중...');
    brokersWithDistance.sort((a, b) => {
        if (a.distance === null) return 1;
        if (b.distance === null) return -1;
        return a.distance - b.distance;
    });
    
    console.log('   ✅ 거리순 정렬 완료!');
    console.log('\n   📊 정렬 결과 (상위 5개):');
    brokersWithDistance.slice(0, 5).forEach((broker, idx) => {
        const name = broker.feature.querySelector('bsnm_cmpnm')?.textContent || `공인중개사 ${broker.index + 1}`;
        const distanceText = broker.distance !== null ? `${broker.distance.toFixed(0)}m` : '거리 계산 불가';
        console.log(`      ${idx + 1}위. ${name} - ${distanceText}`);
    });
    
    return brokersWithDistance;
}

/**
 * Haversine 공식으로 두 좌표 간 거리 계산
 * @param {number} lat1 - 위도 1
 * @param {number} lon1 - 경도 1
 * @param {number} lat2 - 위도 2
 * @param {number} lon2 - 경도 2
 * @returns {number} 거리 (미터)
 */
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
    // EPSG:5186 (TM 중부원점) 좌표인 경우 간단한 유클리드 거리로 계산
    if (lon1 > 1000 && lon2 > 1000) {
        const dx = lon2 - lon1;
        const dy = lat2 - lat1;
        return Math.sqrt(dx * dx + dy * dy);
    }
    
    // WGS84 좌표인 경우 Haversine 공식 사용
    const R = 6371000; // 지구 반지름 (미터)
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distance = R * c;
    
    return distance;
}

/**
 * 공인중개사 목록 화면에 표시
 * @param {Array} brokers - 거리 정보가 포함된 공인중개사 배열
 */
function displayBrokerList(brokers) {
    console.log('\n   ┌─────────────────────────────────────┐');
    console.log('   │  🎨 화면 표시                        │');
    console.log('   └─────────────────────────────────────┘');
    console.log('   📊 표시할 중개사 수:', brokers.length, '개');
    
    const container = document.getElementById('brokerListContainer');
    if (!container) {
        console.error('   ❌ brokerListContainer DOM 요소를 찾을 수 없습니다!');
        return;
    }
    
    console.log('   ✅ brokerListContainer 발견');
    
    // 기존 내용 제거
    console.log('   🧹 기존 내용 제거 중...');
    container.innerHTML = '';
    
    console.log('   🔨 중개사 카드 생성 중...');
    brokers.forEach((brokerData, displayIndex) => {
        console.log(`      카드 ${displayIndex + 1} 생성 중...`);
        const feature = brokerData.feature;
        const distance = brokerData.distance;
        
        const getTagValue = (tagName) => {
            const element = feature.querySelector(tagName);
            return element ? element.textContent.trim() : '-';
        };
        
        // 각 공인중개사 정보 카드 생성
        const brokerCard = document.createElement('div');
        brokerCard.className = 'info-card broker-card';
        
        const bsnmCmpnm = getTagValue('bsnm_cmpnm'); // 사업자상호
        const rdnmadr = getTagValue('rdnmadr'); // 도로명주소
        const mnnmadr = getTagValue('mnnmadr'); // 지번주소
        const brkpgRegistNo = getTagValue('brkpg_regist_no'); // 등록번호
        const etcAdres = getTagValue('etc_adres'); // 기타주소
        const emplymCo = getTagValue('emplym_co'); // 고용수
        const frstRegistDt = getTagValue('frst_regist_dt'); // 데이터기준일자
        
        // 중개사명 설정 (견적문의 버튼에서 사용)
        const brokerName = bsnmCmpnm || '공인중개사';
        
        // 거리 표시
        let distanceBadge = '';
        if (distance !== null) {
            const distanceKm = distance >= 1000 ? `${(distance / 1000).toFixed(1)}km` : `${distance.toFixed(0)}m`;
            distanceBadge = `<span class="distance-badge">📍 ${distanceKm}</span>`;
        }
        
        
        brokerCard.innerHTML = `
            <div class="broker-card-header">
                <h3 title="${bsnmCmpnm || '공인중개사 ' + (displayIndex + 1)}">🏢 ${bsnmCmpnm || '공인중개사 ' + (displayIndex + 1)}</h3>
                ${distanceBadge}
            </div>
            <div class="broker-details">
                <div class="broker-item">
                    <strong>📍 도로명주소</strong>
                    <span>${rdnmadr}${etcAdres && etcAdres !== '-' ? ' ' + etcAdres : ''}</span>
                </div>
                <div class="broker-item">
                    <strong>📍 지번주소</strong>
                    <span>${mnnmadr}</span>
                </div>
                <div class="broker-item">
                    <strong>📋 등록번호</strong>
                    <span>${brkpgRegistNo}</span>
                </div>
                ${emplymCo && emplymCo !== '-' && emplymCo !== '0' ? `
                <div class="broker-item">
                    <strong>👥 고용인원</strong>
                    <span>${emplymCo}명</span>
                </div>
                ` : ''}
                ${frstRegistDt && frstRegistDt !== '-' ? `
                <div class="broker-item">
                    <strong>📅 데이터기준일</strong>
                    <span>${frstRegistDt}</span>
                </div>
                ` : ''}
            </div>
            <div class="broker-actions">
                <button class="action-btn" onclick="requestQuote('${brokerName}')" title="견적문의">
                    💬 견적문의
                </button>
                <button class="action-btn" onclick="findRoute('${encodeURIComponent(rdnmadr)}')" title="길찾기">
                    🗺️ 길찾기
                </button>
                <button class="action-btn" onclick="saveBroker(${brokerData.index})" title="저장하기">
                    ⭐ 저장
                </button>
            </div>
        `;
        
        container.appendChild(brokerCard);
        console.log(`      ✅ 카드 ${displayIndex + 1} 생성 완료`);
    });
    
    console.log('\n   ✅ 모든 카드 생성 및 표시 완료!');
    console.log('   📊 최종 표시된 카드 수:', brokers.length, '개');
}

/**
 * 결과 없음 메시지 표시
 * @param {string} message - 표시할 메시지
 */
function displayNoResults(message) {
    console.log('\n   ⚠️ displayNoResults 호출됨');
    console.log('   메시지:', message);
    const container = document.getElementById('brokerListContainer');
    if (!container) return;
    
    container.innerHTML = `
        <div class="info-card">
            <h3>⚠️ 검색 결과 없음</h3>
            <p>${message}</p>
        </div>
    `;
}

/* =========================================== */
/* 5. FILTER FUNCTIONS - 필터링 함수 */
/* =========================================== */

/**
 * 상위 3곳만 보기
 */
function showTop3Brokers() {
    currentFilter = 'top3';
    updateFilterButtons();
    displayBrokerList(allBrokers.slice(0, 3));
    console.log('📍 가까운 3곳 표시');
}

/**
 * 전체 보기
 */
function showAllBrokers() {
    currentFilter = 'all';
    updateFilterButtons();
    displayBrokerList(allBrokers);
    console.log('📋 전체 공인중개사 표시:', allBrokers.length + '곳');
}

/**
 * 필터 버튼 상태 업데이트
 */
function updateFilterButtons() {
    const buttons = document.querySelectorAll('.filter-btn');
    buttons.forEach(btn => {
        btn.classList.remove('active');
    });
    
    if (currentFilter === 'top3') {
        buttons[0]?.classList.add('active');
    } else {
        buttons[1]?.classList.add('active');
    }
}

/* =========================================== */
/* 5.5. LOGIN CHECK FUNCTIONS - 로그인 확인 함수 */
/* =========================================== */

/**
 * 로그인 상태 확인
 */
function isLoggedIn() {
    // Firebase 인증 상태 확인
    if (typeof firebase !== 'undefined' && firebase.auth) {
        return firebase.auth().currentUser !== null;
    }
    
    // 관리자 로그인 상태 확인
    const adminAuth = localStorage.getItem('adminAuth');
    return adminAuth === 'true';
}

/**
 * 로그인 모달 열기
 */
function openLoginModal() {
    const loginModal = document.getElementById('loginModal');
    if (loginModal) {
        loginModal.style.display = 'block';
        document.body.style.overflow = 'hidden';
    } else {
        alert('로그인 기능을 사용하려면 메인 페이지로 이동해주세요.');
        window.location.href = 'index.html';
    }
}

/* =========================================== */
/* 6. ACTION FUNCTIONS - 액션 버튼 함수 */
/* =========================================== */

/**
 * 견적문의
 * @param {string} brokerName - 중개사 이름
 */
function requestQuote(brokerName) {
    // 로그인 상태 확인
    if (!isLoggedIn()) {
        alert('견적 문의를 하려면 로그인이 필요합니다.\n\n로그인 후 다시 시도해주세요.');
        openLoginModal();
        return;
    }
    
    const message = prompt(`${brokerName}에 견적을 문의하시겠습니까?\n\n문의 내용을 입력해주세요:`);
    if (message) {
        // 견적문의 데이터를 Firestore에 저장
        saveQuoteRequest(brokerName, message);
        alert(`견적 문의가 전송되었습니다!\n\n중개사: ${brokerName}\n문의내용: ${message}\n\n빠른 시일 내에 연락드리겠습니다.`);
    }
}

/**
 * 견적문의 데이터를 Firestore에 저장
 * @param {string} brokerName - 중개사 이름
 * @param {string} message - 문의 내용
 */
async function saveQuoteRequest(brokerName, message) {
    try {
        // 현재 사용자 정보 가져오기
        const currentUser = firebase.auth().currentUser;
        const userEmail = currentUser ? currentUser.email : 'guest@example.com';
        const userName = currentUser ? (currentUser.displayName || currentUser.email.split('@')[0]) : '게스트';
        
        // 공인중개사 정보 가져오기 (현재 페이지의 중개사 데이터에서)
        const brokerData = getCurrentBrokerData(brokerName);
        
        // 견적문의 데이터 구성
        const quoteRequestData = {
            // 사용자 정보
            userEmail: userEmail,
            userName: userName,
            userId: currentUser ? currentUser.uid : 'guest',
            
            // 공인중개사 정보
            brokerName: brokerName,
            brokerData: brokerData,
            
            // 문의 정보
            message: message,
            requestDate: new Date().toISOString(),
            status: 'pending', // pending, contacted, completed, cancelled
            
            // 추가 정보
            userAgent: navigator.userAgent,
            timestamp: firebase.firestore.FieldValue.serverTimestamp()
        };
        
        // Firestore에 저장
        const db = firebase.firestore();
        await db.collection('quoteRequests').add(quoteRequestData);
        
        console.log('✅ 견적문의 데이터 저장 완료:', quoteRequestData);
        
    } catch (error) {
        console.error('❌ 견적문의 데이터 저장 실패:', error);
        alert('견적문의 저장 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
}

/**
 * 현재 중개사 데이터 가져오기
 * @param {string} brokerName - 중개사 이름
 * @returns {Object} - 중개사 데이터
 */
function getCurrentBrokerData(brokerName) {
    // 현재 표시된 중개사 목록에서 해당 중개사 찾기
    const brokerCards = document.querySelectorAll('.broker-card');
    
    for (let card of brokerCards) {
        const cardTitle = card.querySelector('.broker-card-header h3');
        if (cardTitle && cardTitle.textContent.includes(brokerName)) {
            // 중개사 카드에서 정보 추출
            const brokerDetails = card.querySelector('.broker-details');
            if (brokerDetails) {
                const details = {};
                const items = brokerDetails.querySelectorAll('.broker-item');
                
                items.forEach(item => {
                    const label = item.querySelector('strong');
                    const value = item.querySelector('span');
                    if (label && value) {
                        details[label.textContent.trim()] = value.textContent.trim();
                    }
                });
                
                return {
                    name: brokerName,
                    details: details
                };
            }
        }
    }
    
    return {
        name: brokerName,
        details: {}
    };
}

/**
 * 길찾기
 * @param {string} address - 주소
 */
function findRoute(address) {
    const decodedAddress = decodeURIComponent(address);
    // 카카오맵, 네이버 지도 등으로 연결
    const kakaoMapUrl = `https://map.kakao.com/link/search/${encodeURIComponent(decodedAddress)}`;
    window.open(kakaoMapUrl, '_blank');
}

/**
 * 공인중개사 저장
 * @param {number} index - 공인중개사 인덱스
 */
async function saveBroker(index) {
    const broker = allBrokers.find(b => b.index === index);
    if (!broker) {
        alert('❌ 공인중개사 정보를 찾을 수 없습니다.');
        return;
    }
    
    const feature = broker.feature;
    const getTagValue = (tagName) => {
        const element = feature.querySelector(tagName);
        return element ? element.textContent.trim() : '-';
    };
    
    const bsnmCmpnm = getTagValue('bsnm_cmpnm');
    const registNo = getTagValue('brkpg_regist_no');
    
    // localStorage에 저장
    let savedBrokers = JSON.parse(localStorage.getItem('savedBrokers') || '[]');
    
    // 중복 체크
    const isDuplicate = savedBrokers.some(b => b.registNo === registNo);
    
    if (isDuplicate) {
        alert('⚠️ 이미 저장된 공인중개사입니다.');
        return;
    }
    
    const brokerData = {
        name: bsnmCmpnm,
        address: getTagValue('rdnmadr'),
        registNo: registNo,
        employeeCount: getTagValue('emplym_co'),
        savedAt: new Date().toISOString()
    };
    
    savedBrokers.push(brokerData);
    localStorage.setItem('savedBrokers', JSON.stringify(savedBrokers));
    
    // Firestore에도 저장 시도 (로그인된 경우)
    if (typeof saveBrokerToFirestore === 'function') {
        const firestoreSaved = await saveBrokerToFirestore(brokerData);
        
        if (firestoreSaved) {
            alert(`✅ ${bsnmCmpnm}이(가) 저장되었습니다!\n\n로컬 및 클라우드에 저장되었습니다.`);
        } else {
            alert(`✅ ${bsnmCmpnm}이(가) 저장되었습니다!`);
        }
    } else {
        alert(`✅ ${bsnmCmpnm}이(가) 저장되었습니다!`);
    }
}

/* =========================================== */
/* 7. NAVIGATION FUNCTIONS - 네비게이션 함수 */
/* =========================================== */

/**
 * 이전 페이지로 돌아가기
 */
function goBack() {
    window.history.back();
}

/* =========================================== */
/* 8. MODAL FUNCTIONS - 모달 관련 함수 */
/* =========================================== */

function openLoginModal() {
    document.getElementById('loginModal').style.display = 'flex';
}

function closeLoginModal() {
    document.getElementById('loginModal').style.display = 'none';
}

function openSignupModal() {
    document.getElementById('signupModal').style.display = 'flex';
}

function closeSignupModal() {
    document.getElementById('signupModal').style.display = 'none';
}

// 모달 외부 클릭 시 닫기
window.onclick = function(event) {
    const loginModal = document.getElementById('loginModal');
    const signupModal = document.getElementById('signupModal');
    
    if (event.target === loginModal) {
        closeLoginModal();
    }
    if (event.target === signupModal) {
        closeSignupModal();
    }
};

// 로그인 폼 제출
document.getElementById('loginForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    alert('로그인 기능은 준비 중입니다.');
    closeLoginModal();
});

// 회원가입 폼 제출
document.getElementById('signupForm')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const password = document.getElementById('signupPassword').value;
    const passwordConfirm = document.getElementById('signupPasswordConfirm').value;
    
    if (password !== passwordConfirm) {
        alert('비밀번호가 일치하지 않습니다.');
        return;
    }
    
    alert('회원가입 기능은 준비 중입니다.');
    closeSignupModal();
});

/**
 * 메인 페이지로 이동 (로고 클릭 시)
 */
function goToMainPage() {
    window.location.href = 'index.html';
}

/**
 * 내 제안서 페이지로 이동
 */
function goToMyProposals() {
    window.location.href = 'proposals-list.html';
}

