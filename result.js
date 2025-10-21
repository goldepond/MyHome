/* =========================================== */
/* HOUSE MVP - 결과 페이지 JavaScript */
/* 주소 검색 결과 및 상세 정보 표시 기능 */
/* =========================================== */

/* =========================================== */
/* 1. API CONFIGURATION - API 설정 */
/* =========================================== */

// 전체 데이터를 저장할 객체
let allData = {
    addressInfo: null,
    buildingInfo: null,
    geocoderInfo: null,
    landInfo: null,
};

// API 응답 표시 상태 추적
let apiDisplayStatus = {
    addressInfo: { loaded: false, displayed: false, name: '주소 검색 API' },
    buildingInfo: { loaded: false, displayed: false, name: '건물 정보 API' },
    geocoderInfo: { loaded: false, displayed: false, name: 'Geocoder API' },
    landInfo: { loaded: false, displayed: false, name: '토지특성 API' },
};


/**
 * 건물 정보 API 설정
 * 건물등기정보제공 서비스 API (프록시 서버 사용)
 */
const BUILDING_API_CONFIG = {
    baseUrl: 'https://apis.data.go.kr/1613000/BldRgstHubService/getBrTitleInfo',
    apiKey: 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh%2BTl1KORZJXQTqih1BTBLpxfdixxY0mUQ%3D%3D',
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
 * VWorld 토지특성공간정보 API 설정
 * 토지특성 WFS 서비스 API
 */
const LAND_API_CONFIG = {
    baseUrl: 'https://api.vworld.kr/ned/wfs/getLandCharacteristicsWFS',
    apiKey: 'FA0D6750-3DC2-3389-B8F1-0385C5976B96',
    typename: 'dt_d194',
    maxFeatures: 10,
    resultType: 'results',
    srsName: 'EPSG:4326',
    output: 'GML2'
};


/* =========================================== */
/* 2. PAGE INITIALIZATION - 페이지 초기화 */
/* =========================================== */

/**
 * JSON 데이터 업데이트 및 표시
 */
function updateJsonData() {
    const jsonDisplay = document.getElementById('json-display');
    
    if (jsonDisplay) {
        const jsonString = JSON.stringify(allData, null, 2);
        jsonDisplay.textContent = jsonString;
    }
    
    // API 표시 상태 확인 및 콘솔 출력
    checkApiDisplayStatus();
}

/**
 * API 응답 표시 상태 확인
 */
function checkApiDisplayStatus() {
    // 각 API의 표시 상태 확인
    const addressInfoSection = document.querySelector('.address-info');
    const buildingSections = document.querySelectorAll('[id*="buildingInfoPage"]');
    const geocoderSection = document.getElementById('geocoderInfo');
    
    // 표시 상태 업데이트
    apiDisplayStatus.addressInfo.displayed = !!addressInfoSection;
    apiDisplayStatus.buildingInfo.displayed = buildingSections.length > 0;
    apiDisplayStatus.geocoderInfo.displayed = !!geocoderSection;
    
    // 최종 결과 출력
    printFinalApiStatus();
}

/**
 * 최종 API 상태를 콘솔에 출력 - 원본 데이터 그대로 출력
 */
function printFinalApiStatus() {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📊 API 원본 응답 데이터');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    // 1. 주소 검색 API
    console.log('✅ [주소 검색 API] - business.juso.go.kr');
    console.log(JSON.stringify(allData.addressInfo, null, 2));
    console.log('\n');
    
    // 2. 건물 정보 API
    console.log('✅ [건물 정보 API] - apis.data.go.kr/BldRgstHubService');
    console.log(JSON.stringify(allData.buildingInfo, null, 2));
    console.log('\n');
    
    // 3. Geocoder API (좌표 변환)
    console.log('✅ [Geocoder API] - api.vworld.kr/req/address');
    console.log(JSON.stringify(allData.geocoderInfo, null, 2));
    console.log('\n');
    
    // 4. 토지특성 API
    console.log('✅ [토지특성 API] - api.vworld.kr/ned/wfs/getLandCharacteristicsWFS');
    if (typeof allData.landInfo === 'string') {
        console.log(allData.landInfo.substring(0, 1000) + (allData.landInfo.length > 1000 ? '...' : ''));
    } else {
        console.log(JSON.stringify(allData.landInfo, null, 2));
    }
    console.log('\n');
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}



/**
 * WhatHouse 데이터 매핑 표시
 */
function displayWhatHouseDataMapping() {
    // WhatHouse 데이터 매핑 섹션 생성
    let mappingSection = document.getElementById('whathouse-mapping-section');
    if (!mappingSection) {
        mappingSection = document.createElement('div');
        mappingSection.id = 'whathouse-mapping-section';
        mappingSection.style.cssText = 'margin-top: 30px; padding: 20px; background: #f8f9fa; border-radius: 10px;';
        
        const content = document.getElementById('whathouse-content');
        if (content) {
            content.appendChild(mappingSection);
        }
    }
    
    // 데이터 매핑 테이블 생성
    const mappingData = createWhatHouseMappingData();
    
    mappingSection.innerHTML = `
        <h3 style="color: #333; margin-bottom: 15px;">📋 WhatHouse 데이터 매핑</h3>
        <p style="color: #666; margin-bottom: 20px;">API에서 수집된 데이터가 WhatHouse 문서의 "A" 플레이스홀더에 어떻게 매핑되는지 보여줍니다.</p>
        
        <div style="overflow-x: auto;">
            <table style="width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                <thead>
                    <tr style="background: #007bff; color: white;">
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #0056b3;">카테고리</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #0056b3;">API 데이터</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #0056b3;">변수명</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #0056b3;">실제 값</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #0056b3;">단위</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #0056b3;">상태</th>
                    </tr>
                </thead>
                <tbody>
                    ${mappingData.map(item => `
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 12px; font-weight: bold; color: #495057;">${item.category}</td>
                            <td style="padding: 12px; color: #6c757d;">${item.apiField}</td>
                            <td style="padding: 12px; font-family: monospace; background: #f8f9fa; color: #e83e8c;">${item.variableName}</td>
                            <td style="padding: 12px; color: #28a745; font-weight: bold;">${item.value}</td>
                            <td style="padding: 12px; color: #6c757d;">${item.unit}</td>
                            <td style="padding: 12px;">
                                <span style="padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; ${item.status === '사용가능' ? 'background: #d4edda; color: #155724;' : 'background: #f8d7da; color: #721c24;'}">
                                    ${item.status}
                                </span>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
        
        <div style="margin-top: 20px; padding: 15px; background: #e3f2fd; border-radius: 8px; border-left: 4px solid #2196f3;">
            <h4 style="margin: 0 0 10px 0; color: #1976d2;">📝 사용 방법</h4>
            <p style="margin: 5px 0; color: #1976d2;">
                1. 위의 데이터를 WhatHouse 문서의 "A" 플레이스홀더에 순서대로 삽입<br>
                2. 단위가 있는 데이터는 단위와 함께 표시<br>
                3. 사용불가능한 데이터는 "-" 또는 기본값으로 표시
            </p>
        </div>
        
    `;
}

/**
 * WhatHouse 데이터 매핑 정보 생성
 */
function createWhatHouseMappingData() {
    
    const mappingData = [];
    
    // 1. 주소 정보
    if (allData.addressInfo) {
        const addr = allData.addressInfo;
        mappingData.push(
            { category: '주소정보', apiField: 'roadAddr', variableName: 'ROAD_ADDRESS', value: addr.roadAddr || '-', unit: '', status: addr.roadAddr ? '사용가능' : '사용불가' },
            { category: '주소정보', apiField: 'jibunAddr', variableName: 'JIBUN_ADDRESS', value: addr.jibunAddr || '-', unit: '', status: addr.jibunAddr ? '사용가능' : '사용불가' },
            { category: '주소정보', apiField: 'zipNo', variableName: 'ZIP_CODE', value: addr.zipNo || '-', unit: '', status: addr.zipNo ? '사용가능' : '사용불가' },
            { category: '주소정보', apiField: 'bdNm', variableName: 'BUILDING_NAME', value: addr.bdNm || '-', unit: '', status: addr.bdNm ? '사용가능' : '사용불가' }
        );
    }
    
    // 2. 행정구역 정보
    if (allData.regionDetails && allData.regionDetails.length > 0) {
        const region = allData.regionDetails[0];
        mappingData.push(
            { category: '행정구역', apiField: 'region_cd', variableName: 'REGION_CODE', value: region.region_cd || '-', unit: '', status: region.region_cd ? '사용가능' : '사용불가' },
            { category: '행정구역', apiField: 'sido_cd', variableName: 'SIDO_CODE', value: region.sido_cd || '-', unit: '', status: region.sido_cd ? '사용가능' : '사용불가' },
            { category: '행정구역', apiField: 'sgg_cd', variableName: 'SGG_CODE', value: region.sgg_cd || '-', unit: '', status: region.sgg_cd ? '사용가능' : '사용불가' },
            { category: '행정구역', apiField: 'umd_cd', variableName: 'UMD_CODE', value: region.umd_cd || '-', unit: '', status: region.umd_cd ? '사용가능' : '사용불가' }
        );
    }
    
    // 3. 아파트 정보
    if (allData.apartmentList && allData.apartmentList.items && allData.apartmentList.items.length > 0) {
        const apt = allData.apartmentList.items[0];
        mappingData.push(
            { category: '아파트정보', apiField: 'kaptName', variableName: 'APARTMENT_NAME', value: apt.kaptName || '-', unit: '', status: apt.kaptName ? '사용가능' : '사용불가' },
            { category: '아파트정보', apiField: 'kaptCode', variableName: 'APARTMENT_CODE', value: apt.kaptCode || '-', unit: '', status: apt.kaptCode ? '사용가능' : '사용불가' },
            { category: '아파트정보', apiField: 'doroJuso', variableName: 'APARTMENT_ADDRESS', value: apt.doroJuso || '-', unit: '', status: apt.doroJuso ? '사용가능' : '사용불가' }
        );
    }
    
    // 4. 아파트 상세 정보
    if (allData.apartmentDetail) {
        const detail = allData.apartmentDetail;
        mappingData.push(
            { category: '아파트상세', apiField: 'codeStr', variableName: 'BUILDING_STRUCTURE', value: detail.codeStr || '-', unit: '', status: detail.codeStr ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'codeMgr', variableName: 'MANAGEMENT_TYPE', value: detail.codeMgr || '-', unit: '', status: detail.codeMgr ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'kaptMgrCnt', variableName: 'MANAGEMENT_PERSONNEL', value: detail.kaptMgrCnt || '-', unit: '명', status: detail.kaptMgrCnt ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'codeSec', variableName: 'SECURITY_TYPE', value: detail.codeSec || '-', unit: '', status: detail.codeSec ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'kaptdScnt', variableName: 'SECURITY_PERSONNEL', value: detail.kaptdScnt || '-', unit: '명', status: detail.kaptdScnt ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'codeClean', variableName: 'CLEANING_TYPE', value: detail.codeClean || '-', unit: '', status: detail.codeClean ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'kaptdClcnt', variableName: 'CLEANING_PERSONNEL', value: detail.kaptdClcnt || '-', unit: '명', status: detail.kaptdClcnt ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'kaptdEcnt', variableName: 'ELEVATOR_COUNT', value: detail.kaptdEcnt || '-', unit: '대', status: detail.kaptdEcnt ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'kaptdPcnt', variableName: 'PARKING_COUNT', value: detail.kaptdPcnt || '-', unit: '대', status: detail.kaptdPcnt ? '사용가능' : '사용불가' },
            { category: '아파트상세', apiField: 'kaptdPcntu', variableName: 'UNDERGROUND_PARKING', value: detail.kaptdPcntu || '-', unit: '대', status: detail.kaptdPcntu ? '사용가능' : '사용불가' }
        );
    }
    
    // 5. 건물 정보
    if (allData.buildingInfo && allData.buildingInfo.length > 0) {
        const building = allData.buildingInfo[0].data.items.item;
        if (building) {
            mappingData.push(
                { category: '건물정보', apiField: 'mainPurpsCdNm', variableName: 'BUILDING_PURPOSE', value: building.mainPurpsCdNm || '-', unit: '', status: building.mainPurpsCdNm ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'strctCdNm', variableName: 'BUILDING_STRUCTURE_DETAIL', value: building.strctCdNm || '-', unit: '', status: building.strctCdNm ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'platArea', variableName: 'BUILDING_AREA', value: building.platArea || '-', unit: '㎡', status: building.platArea ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'grndFlrCnt', variableName: 'FLOOR_COUNT', value: building.grndFlrCnt || '-', unit: '층', status: building.grndFlrCnt ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'ugrndFlrCnt', variableName: 'UNDERGROUND_FLOOR_COUNT', value: building.ugrndFlrCnt || '-', unit: '층', status: building.ugrndFlrCnt ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'heit', variableName: 'BUILDING_HEIGHT', value: building.heit || '-', unit: 'm', status: building.heit ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'hhldCnt', variableName: 'HOUSEHOLD_COUNT', value: building.hhldCnt || '-', unit: '세대', status: building.hhldCnt ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'hoCnt', variableName: 'ROOM_COUNT', value: building.hoCnt || '-', unit: '호', status: building.hoCnt ? '사용가능' : '사용불가' },
                { category: '건물정보', apiField: 'pmsDay', variableName: 'CONSTRUCTION_DATE', value: building.pmsDay || '-', unit: '', status: building.pmsDay ? '사용가능' : '사용불가' }
            );
        }
    }
    
    // 6. 좌표 정보
    if (allData.geocoderInfo && allData.geocoderInfo.result && allData.geocoderInfo.result.point) {
        const point = allData.geocoderInfo.result.point;
        mappingData.push(
            { category: '위치정보', apiField: 'point.x', variableName: 'LONGITUDE', value: point.x || '-', unit: '', status: point.x ? '사용가능' : '사용불가' },
            { category: '위치정보', apiField: 'point.y', variableName: 'LATITUDE', value: point.y || '-', unit: '', status: point.y ? '사용가능' : '사용불가' }
        );
    }
    
    // 7. 토지이용계획 정보
    if (allData.landUseInfo && allData.landUseInfo.landUses && allData.landUseInfo.landUses.field && allData.landUseInfo.landUses.field.length > 0) {
        const landUse = allData.landUseInfo.landUses.field[0];
        mappingData.push(
            { category: '토지이용계획', apiField: 'prposAreaDstrcCodeNm', variableName: 'LAND_USE_PURPOSE', value: landUse.prposAreaDstrcCodeNm || '-', unit: '', status: landUse.prposAreaDstrcCodeNm ? '사용가능' : '사용불가' },
            { category: '토지이용계획', apiField: 'prposAreaDstrcCode', variableName: 'LAND_USE_CODE', value: landUse.prposAreaDstrcCode || '-', unit: '', status: landUse.prposAreaDstrcCode ? '사용가능' : '사용불가' },
            { category: '토지이용계획', apiField: 'cnflcAtNm', variableName: 'LAND_USE_CONFLICT', value: landUse.cnflcAtNm || '-', unit: '', status: landUse.cnflcAtNm ? '사용가능' : '사용불가' },
            { category: '토지이용계획', apiField: 'area', variableName: 'LAND_AREA', value: landUse.area || landUse.extent || landUse.size || '-', unit: 'm²', status: (landUse.area || landUse.extent || landUse.size) ? '사용가능' : '사용불가' }
        );
    }
    
    
    // 9. 시스템 정보
    const now = new Date();
    mappingData.push(
        { category: '시스템정보', apiField: 'currentDate', variableName: 'CURRENT_DATE', value: now.toLocaleDateString('ko-KR'), unit: '', status: '사용가능' },
        { category: '시스템정보', apiField: 'currentTime', variableName: 'CURRENT_TIME', value: now.toLocaleTimeString('ko-KR'), unit: '', status: '사용가능' }
    );
    
    return mappingData;
}

/**
 * API 데이터 접근 경로 생성
 */
function createApiAccessPaths() {
    
    const accessPaths = [];
    
    // 값 추출 헬퍼 함수
    const getValue = (obj, path) => {
        try {
            return path.split('.').reduce((acc, part) => {
                // 배열 인덱스 처리 (예: field[0])
                const arrayMatch = part.match(/^(\w+)\[(\d+)\]$/);
                if (arrayMatch) {
                    return acc?.[arrayMatch[1]]?.[parseInt(arrayMatch[2])];
                }
                return acc?.[part];
            }, obj);
        } catch {
            return undefined;
        }
    };
    
    // 1. 주소 정보 접근 경로 (모든 상세 정보 포함)
    if (allData.addressInfo) {
        const addr = allData.addressInfo;
        accessPaths.push(
            { category: '주소정보', dataName: '도로명주소', accessPath: 'allData.addressInfo.roadAddr', value: addr.roadAddr || '-' },
            { category: '주소정보', dataName: '지번주소', accessPath: 'allData.addressInfo.jibunAddr', value: addr.jibunAddr || '-' },
            { category: '주소정보', dataName: '우편번호', accessPath: 'allData.addressInfo.zipNo', value: addr.zipNo || '-' },
            { category: '주소정보', dataName: '건물명', accessPath: 'allData.addressInfo.bdNm', value: addr.bdNm || '-' },
            { category: '주소정보', dataName: '영문주소', accessPath: 'allData.addressInfo.engAddr', value: addr.engAddr || '-' },
            { category: '주소정보', dataName: '도로명', accessPath: 'allData.addressInfo.rn', value: addr.rn || '-' },
            { category: '주소정보', dataName: '읍면동명', accessPath: 'allData.addressInfo.emdNm', value: addr.emdNm || '-' },
            { category: '주소정보', dataName: '시도명', accessPath: 'allData.addressInfo.siNm', value: addr.siNm || '-' },
            { category: '주소정보', dataName: '시군구명', accessPath: 'allData.addressInfo.sggNm', value: addr.sggNm || '-' },
            { category: '주소정보', dataName: '관리번호', accessPath: 'allData.addressInfo.bdMgtSn', value: addr.bdMgtSn || '-' },
            { category: '주소정보', dataName: '상세건물명', accessPath: 'allData.addressInfo.detBdNmList', value: addr.detBdNmList || '-' },
            { category: '주소정보', dataName: '도로명주소참고항목', accessPath: 'allData.addressInfo.roadAddrPart2', value: addr.roadAddrPart2 || '-' },
            { category: '주소정보', dataName: '도로명주소기본', accessPath: 'allData.addressInfo.roadAddrPart1', value: addr.roadAddrPart1 || '-' },
            { category: '주소정보', dataName: '행정구역코드', accessPath: 'allData.addressInfo.admCd', value: addr.admCd || '-' },
            { category: '주소정보', dataName: '지번본번', accessPath: 'allData.addressInfo.lnbrMnnm', value: addr.lnbrMnnm || '-' },
            { category: '주소정보', dataName: '지번부번', accessPath: 'allData.addressInfo.lnbrSlno', value: addr.lnbrSlno || '-' },
            { category: '주소정보', dataName: '건물본번', accessPath: 'allData.addressInfo.buldMnnm', value: addr.buldMnnm || '-' },
            { category: '주소정보', dataName: '건물부번', accessPath: 'allData.addressInfo.buldSlno', value: addr.buldSlno || '-' },
            { category: '주소정보', dataName: '도로명코드', accessPath: 'allData.addressInfo.rnMgtSn', value: addr.rnMgtSn || '-' },
            { category: '주소정보', dataName: '읍면동일련번호', accessPath: 'allData.addressInfo.emdNo', value: addr.emdNo || '-' }
        );
    }
    
    // 2. 행정구역 정보 접근 경로 (국가공공데이터포털 서비스 중단으로 인해 비활성화)
    if (allData.regionDetails && allData.regionDetails.length > 0) {
        const region = allData.regionDetails[0];
        accessPaths.push(
            { category: '행정구역', dataName: '행정구역코드', accessPath: 'allData.regionDetails[0].region_cd', value: region.region_cd || '-' },
            { category: '행정구역', dataName: '시도코드', accessPath: 'allData.regionDetails[0].sido_cd', value: region.sido_cd || '-' },
            { category: '행정구역', dataName: '시군구코드', accessPath: 'allData.regionDetails[0].sgg_cd', value: region.sgg_cd || '-' },
            { category: '행정구역', dataName: '읍면동코드', accessPath: 'allData.regionDetails[0].umd_cd', value: region.umd_cd || '-' }
        );
    } else {
        // 국가공공데이터포털 서비스 중단 안내
        accessPaths.push(
            { category: '행정구역', dataName: '서비스 상태', accessPath: 'N/A', value: '국가공공데이터포털 서비스 중단 (데이터센터 화재)' }
        );
    }
    
    // 3. 아파트 정보 접근 경로 (국가공공데이터포털 서비스 중단으로 인해 비활성화)
    if (allData.apartmentList && allData.apartmentList.items && allData.apartmentList.items.length > 0) {
        const apt = allData.apartmentList.items[0];
        accessPaths.push(
            { category: '아파트정보', dataName: '아파트명', accessPath: 'allData.apartmentList.items[0].kaptName', value: apt.kaptName || '-' },
            { category: '아파트정보', dataName: '아파트코드', accessPath: 'allData.apartmentList.items[0].kaptCode', value: apt.kaptCode || '-' },
            { category: '아파트정보', dataName: '아파트주소', accessPath: 'allData.apartmentList.items[0].doroJuso', value: apt.doroJuso || '-' }
        );
    } else {
        // 국가공공데이터포털 서비스 중단 안내
        accessPaths.push(
            { category: '아파트정보', dataName: '서비스 상태', accessPath: 'N/A', value: '국가공공데이터포털 서비스 중단 (데이터센터 화재)' }
        );
    }
    
    // 4. 아파트 상세 정보 접근 경로
    if (allData.apartmentDetail) {
        const detail = allData.apartmentDetail;
        accessPaths.push(
            { category: '아파트상세', dataName: '건물구조', accessPath: 'allData.apartmentDetail.codeStr', value: detail.codeStr || '-' },
            { category: '아파트상세', dataName: '관리방식', accessPath: 'allData.apartmentDetail.codeMgr', value: detail.codeMgr || '-' },
            { category: '아파트상세', dataName: '관리인원', accessPath: 'allData.apartmentDetail.kaptMgrCnt', value: detail.kaptMgrCnt || '-' },
            { category: '아파트상세', dataName: '경비방식', accessPath: 'allData.apartmentDetail.codeSec', value: detail.codeSec || '-' },
            { category: '아파트상세', dataName: '경비인원', accessPath: 'allData.apartmentDetail.kaptdScnt', value: detail.kaptdScnt || '-' },
            { category: '아파트상세', dataName: '청소방식', accessPath: 'allData.apartmentDetail.codeClean', value: detail.codeClean || '-' },
            { category: '아파트상세', dataName: '청소인원', accessPath: 'allData.apartmentDetail.kaptdClcnt', value: detail.kaptdClcnt || '-' },
            { category: '아파트상세', dataName: '승강기대수', accessPath: 'allData.apartmentDetail.kaptdEcnt', value: detail.kaptdEcnt || '-' },
            { category: '아파트상세', dataName: '주차대수', accessPath: 'allData.apartmentDetail.kaptdPcnt', value: detail.kaptdPcnt || '-' },
            { category: '아파트상세', dataName: '지하주차대수', accessPath: 'allData.apartmentDetail.kaptdPcntu', value: detail.kaptdPcntu || '-' }
        );
    }
    
    // 5. 건물 정보 접근 경로 (국가공공데이터포털 서비스 중단으로 인해 비활성화)
    if (allData.buildingInfo && allData.buildingInfo.length > 0) {
        const building = allData.buildingInfo[0].data.items.item;
        if (building) {
            accessPaths.push(
                { category: '건물정보', dataName: '건물용도', accessPath: 'allData.buildingInfo[0].data.items.item.mainPurpsCdNm', value: building.mainPurpsCdNm || '-' },
                { category: '건물정보', dataName: '건물구조', accessPath: 'allData.buildingInfo[0].data.items.item.strctCdNm', value: building.strctCdNm || '-' },
                { category: '건물정보', dataName: '대지면적', accessPath: 'allData.buildingInfo[0].data.items.item.platArea', value: building.platArea || '-' },
                { category: '건물정보', dataName: '지상층수', accessPath: 'allData.buildingInfo[0].data.items.item.grndFlrCnt', value: building.grndFlrCnt || '-' },
                { category: '건물정보', dataName: '지하층수', accessPath: 'allData.buildingInfo[0].data.items.item.ugrndFlrCnt', value: building.ugrndFlrCnt || '-' },
                { category: '건물정보', dataName: '건물높이', accessPath: 'allData.buildingInfo[0].data.items.item.heit', value: building.heit || '-' },
                { category: '건물정보', dataName: '세대수', accessPath: 'allData.buildingInfo[0].data.items.item.hhldCnt', value: building.hhldCnt || '-' },
                { category: '건물정보', dataName: '호수', accessPath: 'allData.buildingInfo[0].data.items.item.hoCnt', value: building.hoCnt || '-' },
                { category: '건물정보', dataName: '착공일', accessPath: 'allData.buildingInfo[0].data.items.item.pmsDay', value: building.pmsDay || '-' }
            );
        }
    } else {
        // 국가공공데이터포털 서비스 중단 안내
        accessPaths.push(
            { category: '건물정보', dataName: '서비스 상태', accessPath: 'N/A', value: '국가공공데이터포털 서비스 중단 (데이터센터 화재)' }
        );
    }
    
    // 6. 좌표 정보 접근 경로 (모든 Geocoder 정보 포함)
    if (allData.geocoderInfo) {
        const geocoder = allData.geocoderInfo;
        accessPaths.push(
            { category: '위치정보', dataName: '경도', accessPath: 'allData.geocoderInfo.result.point.x', value: geocoder.result?.point?.x || '-' },
            { category: '위치정보', dataName: '위도', accessPath: 'allData.geocoderInfo.result.point.y', value: geocoder.result?.point?.y || '-' },
            { category: '위치정보', dataName: '좌표계', accessPath: 'allData.geocoderInfo.result.crs', value: geocoder.result?.crs || '-' },
            { category: '위치정보', dataName: '입력주소', accessPath: 'allData.geocoderInfo.input.address', value: geocoder.input?.address || '-' },
            { category: '위치정보', dataName: '주소유형', accessPath: 'allData.geocoderInfo.input.type', value: geocoder.input?.type || '-' },
            { category: '위치정보', dataName: '처리상태', accessPath: 'allData.geocoderInfo.status', value: geocoder.status || '-' },
            { category: '위치정보', dataName: '정제된주소', accessPath: 'allData.geocoderInfo.refined.text', value: geocoder.refined?.text || '-' },
            { category: '위치정보', dataName: '시도', accessPath: 'allData.geocoderInfo.refined.structure.level1', value: geocoder.refined?.structure?.level1 || '-' },
            { category: '위치정보', dataName: '시군구', accessPath: 'allData.geocoderInfo.refined.structure.level2', value: geocoder.refined?.structure?.level2 || '-' },
            { category: '위치정보', dataName: '읍면동', accessPath: 'allData.geocoderInfo.refined.structure.level3', value: geocoder.refined?.structure?.level3 || '-' },
            { category: '위치정보', dataName: '도로명', accessPath: 'allData.geocoderInfo.refined.structure.level4L', value: geocoder.refined?.structure?.level4L || '-' },
            { category: '위치정보', dataName: '건물번호', accessPath: 'allData.geocoderInfo.refined.structure.level5', value: geocoder.refined?.structure?.level5 || '-' },
            { category: '위치정보', dataName: '상세주소', accessPath: 'allData.geocoderInfo.refined.structure.detail', value: geocoder.refined?.structure?.detail || '-' }
        );
    }
    
    // 7. 토지이용계획 정보 접근 경로 (모든 계획구역 포함)
    if (allData.landUseInfo && allData.landUseInfo.landUses && allData.landUseInfo.landUses.field && allData.landUseInfo.landUses.field.length > 0) {
        const landUses = allData.landUseInfo.landUses.field;
        
        // 각 계획구역별로 데이터 추가
        landUses.forEach((landUse, index) => {
            accessPaths.push(
                { category: `토지이용계획${index + 1}`, dataName: '용도지역명', accessPath: `allData.landUseInfo.landUses.field[${index}].prposAreaDstrcCodeNm`, value: landUse.prposAreaDstrcCodeNm || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '용도지역코드', accessPath: `allData.landUseInfo.landUses.field[${index}].prposAreaDstrcCode`, value: landUse.prposAreaDstrcCode || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '저촉여부', accessPath: `allData.landUseInfo.landUses.field[${index}].cnflcAtNm`, value: landUse.cnflcAtNm || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '토지코드', accessPath: `allData.landUseInfo.landUses.field[${index}].ldCode`, value: landUse.ldCode || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '토지코드명', accessPath: `allData.landUseInfo.landUses.field[${index}].ldCodeNm`, value: landUse.ldCodeNm || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '지번', accessPath: `allData.landUseInfo.landUses.field[${index}].mnnmSlno`, value: landUse.mnnmSlno || '-' },
                { category: `토지이용계획${index + 1}`, dataName: 'PNU', accessPath: `allData.landUseInfo.landUses.field[${index}].pnu`, value: landUse.pnu || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '면적', accessPath: `allData.landUseInfo.landUses.field[${index}].area`, value: landUse.area || landUse.extent || landUse.size || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '지형정보', accessPath: `allData.landUseInfo.landUses.field[${index}].geometry`, value: landUse.geometry ? '포함됨' : '-' },
                { category: `토지이용계획${index + 1}`, dataName: '최종수정일', accessPath: `allData.landUseInfo.landUses.field[${index}].lastUpdtDt`, value: landUse.lastUpdtDt || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '등록일', accessPath: `allData.landUseInfo.landUses.field[${index}].registDt`, value: landUse.registDt || '-' },
                { category: `토지이용계획${index + 1}`, dataName: '도면번호', accessPath: `allData.landUseInfo.landUses.field[${index}].manageNo`, value: landUse.manageNo || '-' }
            );
        });
        
        // 토지이용계획 전체 정보
        accessPaths.push(
            { category: '토지이용계획전체', dataName: '총 건수', accessPath: 'allData.landUseInfo.landUses.totalCount', value: allData.landUseInfo.landUses.totalCount || '-' },
            { category: '토지이용계획전체', dataName: '현재 페이지', accessPath: 'allData.landUseInfo.landUses.pageNo', value: allData.landUseInfo.landUses.pageNo || '-' },
            { category: '토지이용계획전체', dataName: '페이지당 건수', accessPath: 'allData.landUseInfo.landUses.numOfRows', value: allData.landUseInfo.landUses.numOfRows || '-' }
        );
    }
    
    
    // 9. 시스템 정보 접근 경로
    const now = new Date();
    accessPaths.push(
        { category: '시스템정보', dataName: '현재날짜', accessPath: 'new Date().toLocaleDateString("ko-KR")', value: now.toLocaleDateString('ko-KR') },
        { category: '시스템정보', dataName: '현재시간', accessPath: 'new Date().toLocaleTimeString("ko-KR")', value: now.toLocaleTimeString('ko-KR') }
    );
    
    return accessPaths;
}

/**
 * API 데이터 접근 경로 별도 표시
 */
function displayApiAccessPaths() {
    
    // API 데이터 접근 경로 섹션 생성
    let accessPathsSection = document.getElementById('api-access-paths-section');
    if (!accessPathsSection) {
        accessPathsSection = document.createElement('div');
        accessPathsSection.id = 'api-access-paths-section';
        accessPathsSection.style.cssText = 'margin-top: 30px; padding: 20px; background: #fff3cd; border-radius: 10px; border-left: 4px solid #ffc107;';
        
        // JSON 데이터 섹션 다음에 삽입
        const jsonSection = document.getElementById('json-data-section');
        if (jsonSection && jsonSection.parentNode) {
            jsonSection.parentNode.insertBefore(accessPathsSection, jsonSection.nextSibling);
        }
    }
    
    // API 데이터 접근 경로 테이블 생성
    const accessPaths = createApiAccessPaths();
    
    accessPathsSection.innerHTML = `
        <h3 style="color: #856404; margin-bottom: 15px;">🔍 API 데이터 접근 경로</h3>
        <p style="color: #6c757d; margin-bottom: 20px;">API에서 수집된 모든 데이터의 정확한 JavaScript 접근 경로를 확인할 수 있습니다.</p>
        
        <div style="overflow-x: auto;">
            <table style="width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                <thead>
                    <tr style="background: #ffc107; color: #856404;">
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #ff8f00;">카테고리</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #ff8f00;">데이터명</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #ff8f00;">JavaScript 접근 경로</th>
                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #ff8f00; min-width: 200px;">실제 리턴값</th>
                    </tr>
                </thead>
                <tbody>
                    ${accessPaths.map(item => `
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 12px; font-weight: bold; color: #495057; white-space: nowrap;">${item.category}</td>
                            <td style="padding: 12px; color: #6c757d; white-space: nowrap;">${item.dataName}</td>
                            <td style="padding: 12px; font-family: monospace; background: #f8f9fa; color: #e83e8c; font-size: 11px; word-break: break-all; max-width: 300px;">${item.accessPath}</td>
                            <td style="padding: 12px; color: #28a745; font-weight: 500; max-width: 400px; word-break: break-word;" title="${item.value}">${item.value}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
        
        <div style="margin-top: 20px; padding: 15px; background: #e3f2fd; border-radius: 8px; border-left: 4px solid #2196f3;">
            <h4 style="margin: 0 0 10px 0; color: #1976d2;">💡 사용 방법</h4>
            <p style="margin: 5px 0; color: #1976d2;">
                1. 위의 JavaScript 접근 경로를 복사하여 WhatHouse 문서에서 사용<br>
                2. 예: <code style="background: #f8f9fa; padding: 2px 4px; border-radius: 3px;">allData.landUseInfo.landUses.field[0].prposAreaDstrcCodeNm</code><br>
                3. 모든 데이터는 <code style="background: #f8f9fa; padding: 2px 4px; border-radius: 3px;">allData</code> 객체를 통해 접근 가능
            </p>
        </div>
    `;
}

/**
 * WhatHouse 문서 로드 기능
 */
function setupWhatHouseLoader() {
    const loadBtn = document.getElementById('load-whathouse-btn');
    const toggleBtn = document.getElementById('toggle-whathouse-btn');
    const content = document.getElementById('whathouse-content');
    
    if (loadBtn && toggleBtn && content) {
        let isLoaded = false;
        let isVisible = false;
        
        // 로드 버튼 클릭 이벤트
        loadBtn.addEventListener('click', async function() {
            if (!isLoaded) {
                try {
                    loadBtn.textContent = '로딩 중...';
                    loadBtn.disabled = true;
                    
                    // 모든 WhatHouse HTML 파일들을 순차적으로 로드 (프록시 서버를 통해)
                    const whathouseFiles = [
                        'http://localhost:3001/assest/whathouse/whathouse_01.html',
                        'http://localhost:3001/assest/whathouse/whathouse_02.html',
                        'http://localhost:3001/assest/whathouse/whathouse_03.html',
                        'http://localhost:3001/assest/whathouse/whathouse_04.html',
                        'http://localhost:3001/assest/whathouse/whathouse_05.html',
                        'http://localhost:3001/assest/whathouse/whathouse_06.html',
                        'http://localhost:3001/assest/whathouse/whathouse_07.html',
                        'http://localhost:3001/assest/whathouse/whathouse_08.html',
                        'http://localhost:3001/assest/whathouse/whathouse_09.html',
                        'http://localhost:3001/assest/whathouse/whathouse_10.html',
                        'http://localhost:3001/assest/whathouse/whathouse_11.html',
                        'http://localhost:3001/assest/whathouse/whathouse_12.html'
                    ];
                    
                    let allContent = '';
                    
                    for (let i = 0; i < whathouseFiles.length; i++) {
                        try {
                            const response = await fetch(whathouseFiles[i]);
                            if (response.ok) {
                                const htmlContent = await response.text();
                                allContent += htmlContent;
                            }
                        } catch (error) {
                            // Skip failed files
                        }
                    }
                    
                    if (allContent) {
                        // iframe을 사용하여 WhatHouse 문서들을 개별적으로 표시
                        const iframeContainer = document.createElement('div');
                        iframeContainer.style.cssText = 'width: 100%; height: 600px; border: 1px solid #ddd; overflow: auto;';
                        
                        // 첫 번째 HTML 파일을 iframe으로 로드
                        const iframe = document.createElement('iframe');
                        iframe.src = 'http://localhost:3001/assest/whathouse/whathouse_01.html';
                        iframe.style.cssText = 'width: 100%; height: 100%; border: none; font-family: Arial, sans-serif;';
                        iframe.setAttribute('sandbox', 'allow-same-origin allow-scripts');
                        iframe.setAttribute('loading', 'lazy');
                        
                        // 문자 인코딩 문제 해결을 위한 스타일 추가
                        const style = document.createElement('style');
                        style.textContent = `
                            iframe {
                                font-family: Arial, sans-serif !important;
                                font-size: 14px !important;
                                line-height: 1.4 !important;
                            }
                            iframe body {
                                font-family: Arial, sans-serif !important;
                                font-size: 14px !important;
                                line-height: 1.4 !important;
                                color: #000 !important;
                            }
                        `;
                        document.head.appendChild(style);
                        
                        iframeContainer.appendChild(iframe);
                        
                        // 페이지 네비게이션 버튼 추가
                        const navContainer = document.createElement('div');
                        navContainer.style.cssText = 'margin-bottom: 10px; text-align: center;';
                        
                        const prevBtn = document.createElement('button');
                        prevBtn.textContent = '이전 페이지';
                        prevBtn.style.cssText = 'margin-right: 10px; padding: 5px 10px;';
                        
                        const nextBtn = document.createElement('button');
                        nextBtn.textContent = '다음 페이지';
                        nextBtn.style.cssText = 'padding: 5px 10px;';
                        
                        const pageInfo = document.createElement('span');
                        pageInfo.textContent = '1 / 6';
                        pageInfo.style.cssText = 'margin: 0 10px;';
                        
                        let currentPage = 1;
                        const totalPages = 6;
                        
                        prevBtn.addEventListener('click', () => {
                            if (currentPage > 1) {
                                currentPage--;
                                iframe.src = `http://localhost:3001/assest/whathouse/whathouse_${String(currentPage).padStart(2, '0')}.html`;
                                pageInfo.textContent = `${currentPage} / ${totalPages}`;
                            }
                        });
                        
                        nextBtn.addEventListener('click', () => {
                            if (currentPage < totalPages) {
                                currentPage++;
                                iframe.src = `http://localhost:3001/assest/whathouse/whathouse_${String(currentPage).padStart(2, '0')}.html`;
                                pageInfo.textContent = `${currentPage} / ${totalPages}`;
                            }
                        });
                        
                        navContainer.appendChild(prevBtn);
                        navContainer.appendChild(pageInfo);
                        navContainer.appendChild(nextBtn);
                        
                        content.innerHTML = '';
                        content.appendChild(navContainer);
                        content.appendChild(iframeContainer);
                        
                        isLoaded = true;
                        loadBtn.textContent = '문서 다시 로드';
                        toggleBtn.style.display = 'inline-block';
                        content.style.display = 'block';
                        isVisible = true;
                    } else {
                        content.innerHTML = '<p style="color: red;">문서를 로드할 수 없습니다.</p>';
                    }
                    
                } catch (error) {
                    content.innerHTML = '<p style="color: red;">문서 로드 중 오류가 발생했습니다.</p>';
                } finally {
                    loadBtn.disabled = false;
                }
            } else {
                // 이미 로드된 경우 토글
                isVisible = !isVisible;
                content.style.display = isVisible ? 'block' : 'none';
                toggleBtn.textContent = isVisible ? '문서 숨기기' : '문서 보기';
            }
        });
        
        // 토글 버튼 클릭 이벤트
        toggleBtn.addEventListener('click', function() {
            isVisible = !isVisible;
            content.style.display = isVisible ? 'block' : 'none';
            toggleBtn.textContent = isVisible ? '문서 숨기기' : '문서 보기';
        });
    }
}



/**
 * JSON 토글 버튼 이벤트 설정
 */
function setupJsonToggle() {
    const toggleBtn = document.getElementById('toggle-json-btn');
    const jsonSection = document.getElementById('json-data-section');
    const jsonDisplay = document.getElementById('json-display');
    
    if (toggleBtn && jsonSection && jsonDisplay) {
        let isVisible = false;
        
        toggleBtn.addEventListener('click', function() {
            isVisible = !isVisible;
            jsonSection.style.display = isVisible ? 'block' : 'none';
            toggleBtn.textContent = isVisible ? 'JSON 데이터 숨기기' : 'JSON 데이터 보기/숨기기';
            
            // WhatHouse 데이터 매핑, API 접근 경로, JSON 데이터 표시 제거 (사용자 요청)
        });
    }
}

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
    const dongNm = urlParams.get('dongNm');
    const hoNm = urlParams.get('hoNm');
    const fullData = urlParams.get('fullData');
    
    // 기본 주소 정보 표시
    displayBasicAddressInfo(roadAddr, jibunAddr, zipCode);
    
    // 동/호수 정보 표시
    if (dongNm) {
        document.getElementById('selectedDong').textContent = dongNm;
        document.getElementById('dongInfoDiv').style.display = 'block';
    }
    if (hoNm) {
        document.getElementById('selectedHosu').textContent = hoNm;
        document.getElementById('hosuInfoDiv').style.display = 'block';
    }
    
    // WhatHouse 로더 설정 - 제거됨 (사용자 요청)
    // setupWhatHouseLoader();
    
    // JSON 토글 버튼 설정 - 제거됨 (사용자 요청)
    // setupJsonToggle();
    
    // 페이지 로드 시 JSON 데이터 표시 - 삭제됨 (사용자 요청)
    // setTimeout(() => {
    //     updateJsonData();
    //     
    //     // WhatHouse 데이터 매핑 표시
    //     displayWhatHouseDataMapping();
    //     
    //     // API 데이터 접근 경로 표시
    //     displayApiAccessPaths();
    // }, 1000);
    
    // 모든 API 로드 완료 후 최종 상태 확인 (5초 후)
    setTimeout(() => {
        checkApiDisplayStatus();
    }, 5000);
    
    // 전체 주소 정보 처리
    if (fullData) {
        try {
            const fullJusoData = JSON.parse(decodeURIComponent(fullData));
            displayFullAddressInfo(fullJusoData);
            
            // 주소 정보를 allData에 저장
            allData.addressInfo = fullJusoData;
            apiDisplayStatus.addressInfo.loaded = true;
            // updateJsonData(); // JSON 데이터 업데이트 - 제거됨 (사용자 요청)
            
            // roadAddrPart1 값을 전역 변수로 저장 (아파트 필터링용)
            window.selectedRoadAddrPart1 = fullJusoData.roadAddrPart1;
            
            // 건물관리번호를 전역 변수로 저장 (토지이용계획도 API용)
            window.buildingManagementNumber = fullJusoData.bdMgtSn;
            
            // 주소 요약 카드 즉시 표시 (기본 정보만)
            displayAddressSummaryCard();
        } catch (error) {
            // 주소 데이터 파싱 오류 처리
        }
    }
    
    
    // 관련 API 호출
    if (fullData) {
        try {
            const fullJusoData = JSON.parse(decodeURIComponent(fullData));
            
            // 건물 정보 API 호출 (행정구역코드 사용)
            if (fullJusoData.admCd) {
                const sigunguCd = fullJusoData.admCd.substring(0, 5);
                const bjdongCd = fullJusoData.admCd.substring(5, 10);
                
                // 지번본번을 4자리로 변환 (2자리인 경우 앞에 00을 붙임)
                const lnbrMnnm = fullJusoData.lnbrMnnm || '0';
                const bun = lnbrMnnm.toString().padStart(4, '0');
                
                loadBuildingInfo(sigunguCd, bjdongCd, bun, dongNm);
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
        <h2>📋 주소 검색 API 원본 응답</h2>
        <pre>${JSON.stringify(fullJusoData, null, 2)}</pre>
    `;
    
    detailSection.innerHTML = html;
    addressInfo.appendChild(detailSection);
}

/* =========================================== */
/* 4. BUILDING INFO API - 건물 정보 API */
/* =========================================== */

/**
 * 건물 정보 API 호출 (1-10페이지 순차 호출)
 * @param {string} sigunguCd - 시군구코드 (행정구역코드 앞 5자리)
 * @param {string} bjdongCd - 법정동코드 (행정구역코드 뒤 5자리)
 * @param {string} bun - 지번본번 (4자리, 2자리인 경우 앞에 00을 붙임)
 * @param {string} dongNm - 동명 (옵션)
 */
async function loadBuildingInfo(sigunguCd, bjdongCd, bun, dongNm) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🏗️ [건물 정보 API] 호출 시작 (1-10페이지)');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`   전달 파라미터: sigunguCd=${sigunguCd}, bjdongCd=${bjdongCd}, bun=${bun}, dongNm=${dongNm || '없음'}`);
    if (dongNm) {
        console.log(`   ⚠️  주의: 건물정보 API는 dongNm 필터를 지원하지 않습니다.`);
        console.log(`   📌 클라이언트 측에서 "${dongNm}"으로 필터링합니다.`);
    }
    
    let successCount = 0;
    let failCount = 0;
    
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
            
            // 주의: dongNm은 API 파라미터로 지원되지 않으므로 보내지 않음
            // 대신 응답 후 클라이언트 측에서 필터링
            
        // 프록시 서버를 통해 API 호출
        const url = `http://localhost:3001/api/building?${params.toString()}`;
            
            const response = await fetch(url);
            
            if (!response.ok) {
                failCount++;
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
                // dongNm이 지정된 경우 필터링
                let filteredBody = data.response.body;
                if (dongNm && data.response.body && data.response.body.items && data.response.body.items.item) {
                    const items = Array.isArray(data.response.body.items.item) 
                        ? data.response.body.items.item 
                        : [data.response.body.items.item];
                    
                    const filteredItems = items.filter(item => {
                        // dongNm과 일치하는지 확인 (211, 211동 모두 매칭)
                        const itemDongNm = item.dongNm ? item.dongNm.replace('동', '') : '';
                        const searchDongNm = dongNm.replace('동', '');
                        return itemDongNm === searchDongNm;
                    });
                    
                    if (filteredItems.length > 0) {
                        filteredBody = {
                            ...data.response.body,
                            items: {
                                item: filteredItems
                            },
                            totalCount: filteredItems.length
                        };
                    } else {
                        // 필터링 결과가 없으면 이 페이지는 건너뛰기
                        continue;
                    }
                }
                
                if (!allData.buildingInfo) {
                    allData.buildingInfo = [];
                }
                allData.buildingInfo.push({
                    pageNo: pageNo,
                    data: filteredBody
                });
                apiDisplayStatus.buildingInfo.loaded = true;
                displayBuildingInfo(filteredBody, pageNo);
                // updateJsonData(); // JSON 데이터 업데이트 - 제거됨 (사용자 요청)
                successCount++;
            }
            
        } catch (error) {
            failCount++;
        }
        
        // 페이지 간 간격 (API 서버 부하 방지)
        if (pageNo < 10) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
    
    // 최종 결과 요약
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (successCount > 0) {
        console.log(`✅ [건물 정보 API] 응답 성공 (${successCount}/10 페이지)`);
        if (dongNm) {
            // 필터링된 총 건수 계산
            let totalFiltered = 0;
            if (allData.buildingInfo) {
                allData.buildingInfo.forEach(page => {
                    if (page.data && page.data.items && page.data.items.item) {
                        const items = Array.isArray(page.data.items.item) 
                            ? page.data.items.item 
                            : [page.data.items.item];
                        totalFiltered += items.length;
                    }
                });
            }
            console.log(`📌 동명 "${dongNm}" 필터링 결과: ${totalFiltered}건`);
        }
    }
    if (failCount > 0) {
        console.log(`❌ [건물 정보 API] 응답 실패 (${failCount}/10 페이지)`);
    }
    if (successCount === 0 && failCount === 0) {
        console.log('❌ [건물 정보 API] 응답 없음');
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

/* =========================================== */
/* 8. GEOCODER API - 주소 좌표 변환 API */
/* =========================================== */

/**
 * 주소를 좌표로 변환하는 API 호출
 * @param {string} address - 도로명주소
 */
async function loadGeocoderInfo(address) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🌍 [Geocoder API] 호출 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
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
        
        const url = `http://localhost:3001/api/geocoder?${params.toString()}`;
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.response && data.response.status === 'OK') {
            console.log('✅ [Geocoder API] 응답 성공');
            allData.geocoderInfo = data.response;
            apiDisplayStatus.geocoderInfo.loaded = true;
            displayGeocoderInfo(data.response);
            // updateJsonData(); // JSON 데이터 업데이트 - 제거됨 (사용자 요청)
            
            // 주소 요약 카드 업데이트 (좌표 정보 추가)
            displayAddressSummaryCard();
            
            // Geocoder API 성공 후 토지특성 API 호출
            if (allData.addressInfo) {
                loadLandInfo(allData.addressInfo, data.response);
            }
            
        } else {
            console.log('❌ [Geocoder API] 응답 실패');
            console.log(`   상태: ${data.response?.status}`);
            console.log(`   에러: ${data.response?.error?.message || data.response?.error}`);
        }
        
    } catch (error) {
        console.log('❌ [Geocoder API] 에러 발생');
        console.log(`   에러: ${error.message}`);
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
    
    // 기존 좌표 정보 섹션이 있으면 제거
    const existingGeocoder = document.getElementById('geocoderInfo');
    if (existingGeocoder) {
        existingGeocoder.remove();
    }
    
    // 좌표 정보 섹션 생성
    const geocoderSection = document.createElement('div');
    geocoderSection.id = 'geocoderInfo';
    geocoderSection.className = 'info-card';
    
    const html = `
        <h2>🌍 Geocoder API 원본 응답</h2>
        <pre>${JSON.stringify(geocoderData, null, 2)}</pre>
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
    
    // 건물 정보 섹션 생성 (페이지별로 구분)
    const buildingSection = document.createElement('div');
    buildingSection.id = `buildingInfoPage${pageNo}`;
    buildingSection.className = 'info-card';
    
    const html = `
        <h2>🏗️ 건물 정보 API 원본 응답 (페이지 ${pageNo})</h2>
        <pre>${JSON.stringify(buildingData, null, 2)}</pre>
    `;
    
    buildingSection.innerHTML = html;
    addressInfo.appendChild(buildingSection);
}

/* =========================================== */
/* 8. LAND CHARACTERISTICS API - 토지특성 API */
/* =========================================== */

/**
 * PNU(필지고유번호) 생성 함수
 * PNU = 행정구역코드(10) + 필지구분(1) + 본번(4) + 부번(4) = 19자리
 * 필지구분: 1=일반, 2=산
 * 
 * @param {object} addressData - 주소 검색 API 응답 데이터
 * @returns {string} 19자리 PNU
 */
function generatePNU(addressData) {
    if (!addressData) {
        console.error('❌ PNU 생성 실패: 주소 데이터가 없습니다.');
        return null;
    }
    
    // 행정구역코드 (10자리)
    const admCd = addressData.admCd || '';
    if (admCd.length !== 10) {
        console.error('❌ PNU 생성 실패: 행정구역코드가 10자리가 아닙니다:', admCd);
        return null;
    }
    
    // 필지구분 (1자리)
    // mtYn: '0' = 일반, '1' = 산
    // PNU 필지구분: '1' = 일반, '2' = 산
    const mtYn = addressData.mtYn || '0';
    const piljigubn = mtYn === '1' ? '2' : '1'; // 산이면 2, 일반이면 1
    
    // 본번 (4자리, 0000으로 패딩)
    const lnbrMnnm = addressData.lnbrMnnm || '0';
    const bun = lnbrMnnm.toString().padStart(4, '0');
    
    // 부번 (4자리, 0000으로 패딩)
    const lnbrSlno = addressData.lnbrSlno || '0';
    const ji = lnbrSlno.toString().padStart(4, '0');
    
    const pnu = `${admCd}${piljigubn}${bun}${ji}`;
    
    console.log(`📌 PNU 생성: ${pnu}`);
    console.log(`   행정구역코드: ${admCd} (10자리)`);
    console.log(`   필지구분: ${piljigubn} (${piljigubn === '1' ? '일반' : '산'})`);
    console.log(`   본번: ${bun} (4자리)`);
    console.log(`   부번: ${ji} (4자리)`);
    console.log(`   → ${admCd} + ${piljigubn} + ${bun} + ${ji} = ${pnu}`);
    
    return pnu;
}

/**
 * BBOX(경계 상자) 생성 함수
 * 주어진 좌표(경도, 위도)를 중심으로 약 500m x 500m 크기의 bbox 생성
 * 
 * @param {number} x - 경도(longitude)
 * @param {number} y - 위도(latitude)
 * @param {number} distance - 중심에서의 거리(미터, 기본값: 250m)
 * @returns {string} bbox 문자열 (EPSG:4326 형식: ymin,xmin,ymax,xmax)
 */
function generateBBOX(x, y, distance = 250) {
    // 위도 1도 ≈ 111km
    // 경도 1도 ≈ 111km * cos(위도)
    const latDelta = distance / 111000; // 위도 변화량
    const lonDelta = distance / (111000 * Math.cos(y * Math.PI / 180)); // 경도 변화량
    
    const xmin = x - lonDelta;
    const xmax = x + lonDelta;
    const ymin = y - latDelta;
    const ymax = y + latDelta;
    
    // EPSG:4326의 경우 (ymin,xmin,ymax,xmax) 순서
    const bbox = `${ymin},${xmin},${ymax},${xmax},EPSG:4326`;
    
    console.log(`📐 BBOX 생성 (중심에서 ${distance}m):`);
    console.log(`   중심 좌표: (${x}, ${y})`);
    console.log(`   BBOX: ${bbox}`);
    
    return bbox;
}

/**
 * 토지특성 API 호출 및 표시
 * 
 * @param {object} addressData - 주소 검색 API 응답 데이터
 * @param {object} geocoderData - Geocoder API 응답 데이터
 */
async function loadLandInfo(addressData, geocoderData) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🌍 [토지특성 API] 호출 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // PNU 생성
    const pnu = generatePNU(addressData);
    
    if (!pnu) {
        console.error('❌ [토지특성 API] PNU 생성 실패');
        return;
    }
    
    try {
        const params = new URLSearchParams({
            key: LAND_API_CONFIG.apiKey,
            typename: LAND_API_CONFIG.typename,
            pnu: pnu,
            resultType: LAND_API_CONFIG.resultType,
            srsName: LAND_API_CONFIG.srsName,
            output: LAND_API_CONFIG.output,
            maxFeatures: LAND_API_CONFIG.maxFeatures
        });
        
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│  📤 [토지특성 API - PNU 검색] 요청 내용  │');
        console.log('└─────────────────────────────────────────┘');
        console.log(`   🔑 key: ${LAND_API_CONFIG.apiKey}`);
        console.log(`   📋 typename: ${LAND_API_CONFIG.typename}`);
        console.log(`   🏘️  pnu: ${pnu}`);
        console.log(`   📊 resultType: ${LAND_API_CONFIG.resultType}`);
        console.log(`   🗺️  srsName: ${LAND_API_CONFIG.srsName}`);
        console.log(`   📄 output: ${LAND_API_CONFIG.output}`);
        console.log(`   🔢 maxFeatures: ${LAND_API_CONFIG.maxFeatures}`);
        
        // 프록시 서버를 통해 API 호출
        const url = `http://localhost:3001/api/land?${params.toString()}`;
        
        console.log(`\n   🌐 요청 URL:`);
        console.log(`   ${url}\n`);
        
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const contentType = response.headers.get('content-type');
        let data;
        
        if (contentType && contentType.includes('application/json')) {
            data = await response.json();
        } else {
            // GML/XML 응답
            const xmlText = await response.text();
            
            // 빈 응답 체크 (Feature가 없는 경우)
            if (xmlText.includes('boundedBy') && xmlText.includes('-1,-1 0,0')) {
                console.log('\n┌─────────────────────────────────────────┐');
                console.log('│  📥 [토지특성 API - PNU 검색] 응답 내용  │');
                console.log('└─────────────────────────────────────────┘');
                console.warn('   ⚠️  응답 상태: 데이터 없음');
                console.warn('   원인: 해당 PNU에 대한 토지특성 데이터가 존재하지 않습니다');
                console.log('\n   📄 원본 XML 응답:');
                console.log('   ' + xmlText.replace(/\n/g, '\n   '));
                
                // BBOX 검색 시도
                if (geocoderData && geocoderData.result && geocoderData.result.point) {
                    console.log('\n🔄 [토지특성 API] BBOX 검색으로 재시도...\n');
                    await loadLandInfoByBBOX(geocoderData.result.point);
                    return;
                }
            } else {
                console.log('\n┌─────────────────────────────────────────┐');
                console.log('│  📥 [토지특성 API - PNU 검색] 응답 내용  │');
                console.log('└─────────────────────────────────────────┘');
                console.log('   ✅ 응답 상태: 성공 (XML/GML)');
                console.log('\n   📄 원본 XML 응답:');
                const xmlPreview = xmlText.substring(0, 1000);
                console.log('   ' + xmlPreview.replace(/\n/g, '\n   ') + (xmlText.length > 1000 ? '\n   ...(생략)...' : ''));
            }
            
            // XML 데이터 저장
            allData.landInfo = xmlText;
            apiDisplayStatus.landInfo.loaded = true;
            displayLandInfo(xmlText);
            // updateJsonData(); // JSON 데이터 업데이트 - 제거됨 (사용자 요청)
            
            // 주소 요약 카드 업데이트 (토지 정보 배지 추가)
            displayAddressSummaryCard();
            
            // 자동으로 파싱된 정보 출력
            if (window.parseLandXML) {
                setTimeout(() => window.parseLandXML(), 500);
            }
            
            return;
        }
        
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│  📥 [토지특성 API - PNU 검색] 응답 내용  │');
        console.log('└─────────────────────────────────────────┘');
        console.log('   ✅ 응답 상태: 성공 (JSON)');
        console.log('\n   📄 원본 JSON 응답:');
        console.log(JSON.stringify(data, null, 2));
        
        allData.landInfo = data;
        apiDisplayStatus.landInfo.loaded = true;
        displayLandInfo(data);
        // updateJsonData(); // JSON 데이터 업데이트 - 제거됨 (사용자 요청)
        
        // 자동으로 파싱된 정보 출력
        if (window.parseLandXML) {
            setTimeout(() => window.parseLandXML(), 500);
        }
        
    } catch (error) {
        console.error('❌ [토지특성 API] 에러 발생:', error.message);
    }
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

/**
 * BBOX를 사용한 토지특성 API 호출
 * PNU 검색이 실패했을 때 좌표 범위로 검색
 * 
 * @param {object} point - 좌표 정보 {x: 경도, y: 위도}
 */
async function loadLandInfoByBBOX(point) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🌍 [토지특성 API - BBOX 검색] 호출 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    const x = parseFloat(point.x);
    const y = parseFloat(point.y);
    
    // BBOX 생성 (중심에서 50m 범위)
    const bbox = generateBBOX(x, y, 50);
    
    try {
        const params = new URLSearchParams({
            key: LAND_API_CONFIG.apiKey,
            typename: LAND_API_CONFIG.typename,
            bbox: bbox,
            resultType: LAND_API_CONFIG.resultType,
            srsName: LAND_API_CONFIG.srsName,
            output: LAND_API_CONFIG.output,
            maxFeatures: LAND_API_CONFIG.maxFeatures
        });
        
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│ 📤 [토지특성 API - BBOX 검색] 요청 내용  │');
        console.log('└─────────────────────────────────────────┘');
        console.log(`   🔑 key: ${LAND_API_CONFIG.apiKey}`);
        console.log(`   📋 typename: ${LAND_API_CONFIG.typename}`);
        console.log(`   📦 bbox: ${bbox}`);
        console.log(`   📊 resultType: ${LAND_API_CONFIG.resultType}`);
        console.log(`   🗺️  srsName: ${LAND_API_CONFIG.srsName}`);
        console.log(`   📄 output: ${LAND_API_CONFIG.output}`);
        console.log(`   🔢 maxFeatures: ${LAND_API_CONFIG.maxFeatures}`);
        
        // 프록시 서버를 통해 API 호출
        const url = `http://localhost:3001/api/land?${params.toString()}`;
        
        console.log(`\n   🌐 요청 URL:`);
        console.log(`   ${url}\n`);
        
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const xmlText = await response.text();
        
        // 빈 응답 체크
        if (xmlText.includes('boundedBy') && xmlText.includes('-1,-1 0,0')) {
            console.log('\n┌─────────────────────────────────────────┐');
            console.log('│ 📥 [토지특성 API - BBOX 검색] 응답 내용  │');
            console.log('└─────────────────────────────────────────┘');
            console.warn('   ⚠️  응답 상태: 데이터 없음');
            console.warn('   원인: 해당 좌표 주변 50m 내에 토지특성 데이터가 존재하지 않습니다');
            console.log('\n   📄 원본 XML 응답:');
            console.log('   ' + xmlText.replace(/\n/g, '\n   '));
        } else {
            console.log('\n┌─────────────────────────────────────────┐');
            console.log('│ 📥 [토지특성 API - BBOX 검색] 응답 내용  │');
            console.log('└─────────────────────────────────────────┘');
            console.log('   ✅ 응답 상태: 성공 (XML/GML)');
            console.log('   📦 데이터 포함: 토지특성 정보 있음');
            console.log('\n   📄 원본 XML 응답:');
            const xmlPreview = xmlText.substring(0, 2000);
            console.log('   ' + xmlPreview.replace(/\n/g, '\n   ') + (xmlText.length > 2000 ? '\n   ...(더 보려면 allData.landInfo 확인)...' : ''));
        }
        
        // XML 데이터 저장
        allData.landInfo = xmlText;
        apiDisplayStatus.landInfo.loaded = true;
        displayLandInfo(xmlText);
        // updateJsonData(); // JSON 데이터 업데이트 - 제거됨 (사용자 요청)
        
        // 주소 요약 카드 업데이트 (토지 정보 배지 추가)
        displayAddressSummaryCard();
        
        // 자동으로 파싱된 정보 출력
        if (window.parseLandXML) {
            setTimeout(() => window.parseLandXML(), 500);
        }
        
    } catch (error) {
        console.error('❌ [토지특성 API - BBOX 검색] 에러 발생:', error.message);
    }
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

/**
 * 토지특성 정보 표시
 * 
 * @param {object|string} landData - 토지특성 API 응답 데이터 (JSON 또는 XML/GML)
 */
function displayLandInfo(landData) {
    const addressInfo = document.querySelector('.address-info');
    
    // 기존 토지특성 정보 섹션이 있으면 제거
    const existingLand = document.getElementById('landInfo');
    if (existingLand) {
        existingLand.remove();
    }
    
    // 토지특성 정보 섹션 생성
    const landSection = document.createElement('div');
    landSection.id = 'landInfo';
    landSection.className = 'info-card';
    
    let parsedContent = '';
    let displayContent;
    
    if (typeof landData === 'string') {
        // XML/GML 데이터
        displayContent = landData;
        
        // XML 파싱 시도
        try {
            const parser = new DOMParser();
            const xmlDoc = parser.parseFromString(landData, "text/xml");
            const features = xmlDoc.querySelectorAll('dt_d194');
            
            if (features.length > 0) {
                parsedContent = '<h3>📊 파싱된 토지특성 정보</h3>';
                parsedContent += '<div class="land-parsed-info">';
                
                features.forEach((feature, index) => {
                    const getTagValue = (tagName) => {
                        const element = feature.querySelector(tagName);
                        return element ? element.textContent.trim() : '-';
                    };
                    
                    parsedContent += `<div class="land-item">`;
                    parsedContent += `<strong>[${index + 1}번째 필지]</strong><br>`;
                    parsedContent += `🏘️ PNU: ${getTagValue('pnu')}<br>`;
                    parsedContent += `💰 공시지가: ${getTagValue('pblntf_pclnd')}원/㎡<br>`;
                    parsedContent += `📝 지목명: ${getTagValue('lndcgr_code_nm')}<br>`;
                    parsedContent += `📏 토지면적: ${getTagValue('lndpcl_ar')}㎡<br>`;
                    parsedContent += `🗺️ 용도지역: ${getTagValue('prpos_area_1_nm')}<br>`;
                    parsedContent += `🏗️ 토지이용상황: ${getTagValue('lad_use_sittn_nm')}<br>`;
                    parsedContent += `⛰️ 지형높이: ${getTagValue('tpgrph_hg_code_nm')}<br>`;
                    parsedContent += `📐 지형형상: ${getTagValue('tpgrph_frm_code_nm')}<br>`;
                    parsedContent += `🛣️ 도로접면: ${getTagValue('road_side_code_nm')}<br>`;
                    parsedContent += `📅 기준연도: ${getTagValue('stdr_year')}-${getTagValue('stdr_mt')}<br>`;
                    parsedContent += `</div>`;
                });
                
                parsedContent += '</div>';
                parsedContent += '<button class="land-detail-btn" onclick="parseLandXML()">콘솔에서 상세 정보 보기</button><br>';
            }
        } catch (error) {
            parsedContent = `<p style="color: orange;">⚠️ XML 파싱 실패: ${error.message}</p>`;
        }
    } else {
        // JSON 데이터
        displayContent = JSON.stringify(landData, null, 2);
    }
    
    const html = `
        <h2>🌍 토지특성 API 원본 응답</h2>
        ${parsedContent}
        <pre>${displayContent}</pre>
    `;
    
    landSection.innerHTML = html;
    
    // 페이지에 추가
    if (addressInfo) {
        addressInfo.appendChild(landSection);
    } else {
        console.error('🌍 address-info 요소를 찾을 수 없습니다.');
    }
}

/* =========================================== */
/* 9. UTILITY FUNCTIONS - 유틸리티 함수 */
/* =========================================== */

/**
 * 토지특성 API 전체 XML 출력 함수
 * 콘솔에서 호출: showFullLandXML()
 */
window.showFullLandXML = function() {
    if (!allData.landInfo) {
        console.warn('⚠️  토지특성 API 데이터가 없습니다.');
        return;
    }
    
    console.log('\n┌─────────────────────────────────────────┐');
    console.log('│     📄 토지특성 API 전체 XML 응답       │');
    console.log('└─────────────────────────────────────────┘\n');
    
    if (typeof allData.landInfo === 'string') {
        console.log(allData.landInfo);
    } else {
        console.log(JSON.stringify(allData.landInfo, null, 2));
    }
    
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('💡 Tip: XML 파싱하려면 다음 코드를 실행하세요:');
    console.log('   const parser = new DOMParser();');
    console.log('   const xmlDoc = parser.parseFromString(allData.landInfo, "text/xml");');
    console.log('   const features = xmlDoc.querySelectorAll("dt_d194");');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
};

/**
 * 토지특성 XML 파싱 및 표시 함수
 * 콘솔에서 호출: parseLandXML()
 */
window.parseLandXML = function() {
    if (!allData.landInfo || typeof allData.landInfo !== 'string') {
        console.warn('⚠️  토지특성 API 데이터가 없습니다.');
        return;
    }
    
    try {
        const parser = new DOMParser();
        const xmlDoc = parser.parseFromString(allData.landInfo, "text/xml");
        
        // 에러 체크
        const errorNode = xmlDoc.querySelector('parsererror');
        if (errorNode) {
            console.error('❌ XML 파싱 오류:', errorNode.textContent);
            return;
        }
        
        // Feature 찾기
        const features = xmlDoc.querySelectorAll('dt_d194');
        
        if (features.length === 0) {
            console.warn('⚠️  토지특성 데이터가 없습니다 (Feature 0건)');
            return;
        }
        
        console.log('\n┌─────────────────────────────────────────┐');
        console.log('│     📊 토지특성 데이터 파싱 결과        │');
        console.log('└─────────────────────────────────────────┘');
        console.log(`   총 ${features.length}건의 토지특성 데이터\n`);
        
        features.forEach((feature, index) => {
            console.log(`━━━━━━━ [${index + 1}번째 필지] ━━━━━━━`);
            
            // 모든 태그 추출
            const getTagValue = (tagName) => {
                const element = feature.querySelector(tagName);
                return element ? element.textContent.trim() : '-';
            };
            
            console.log(`🏘️  필지고유번호(PNU): ${getTagValue('pnu')}`);
            console.log(`📍 법정동시도시군구코드: ${getTagValue('ld_cpsg_code')}`);
            console.log(`📍 법정동읍면동리코드: ${getTagValue('ld_emd_li_code')}`);
            console.log(`📋 대장구분: ${getTagValue('regstr_se_code')}`);
            console.log(`📌 본번: ${getTagValue('mnnm')}`);
            console.log(`📌 부번: ${getTagValue('slno')}`);
            console.log(`🏷️  지번지목부호: ${getTagValue('lnm_lndcgr_smbol')}`);
            console.log(`📅 기준연도: ${getTagValue('stdr_year')}-${getTagValue('stdr_mt')}`);
            console.log(`💰 공시지가: ${getTagValue('pblntf_pclnd')}원/㎡`);
            console.log(`📝 지목명: ${getTagValue('lndcgr_code_nm')} (코드: ${getTagValue('lndcgr_code')})`);
            console.log(`📏 토지면적: ${getTagValue('lndpcl_ar')}㎡`);
            console.log(`🗺️  용도지역1: ${getTagValue('prpos_area_1_nm')} (코드: ${getTagValue('prpos_area_1')})`);
            console.log(`🗺️  용도지역2: ${getTagValue('prpos_area_2_nm')} (코드: ${getTagValue('prpos_area_2')})`);
            console.log(`🏗️  토지이용상황: ${getTagValue('lad_use_sittn_nm')} (코드: ${getTagValue('lad_use_sittn')})`);
            console.log(`⛰️  지형높이: ${getTagValue('tpgrph_hg_code_nm')} (코드: ${getTagValue('tpgrph_hg_code')})`);
            console.log(`📐 지형형상: ${getTagValue('tpgrph_frm_code_nm')} (코드: ${getTagValue('tpgrph_frm_code')})`);
            console.log(`🛣️  도로접면: ${getTagValue('road_side_code_nm')} (코드: ${getTagValue('road_side_code')})`);
            console.log(`📅 데이터기준일자: ${getTagValue('frst_regist_dt')}`);
            console.log(``);
        });
        
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
    } catch (error) {
        console.error('❌ XML 파싱 중 오류:', error.message);
    }
};

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
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🏘️ [공인중개사 찾기] 버튼 클릭');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // 데이터 유효성 검사
    console.log('📊 데이터 상태 확인:');
    console.log('   - addressInfo:', allData.addressInfo ? '✓' : '✗');
    console.log('   - buildingInfo:', allData.buildingInfo ? '✓' : '✗');
    console.log('   - geocoderInfo:', allData.geocoderInfo ? '✓' : '✗');
    console.log('   - landInfo:', allData.landInfo ? '✓' : '✗');
    
    // 필수 데이터 체크
    if (!allData.addressInfo) {
        console.error('❌ 주소 정보가 없습니다!');
        alert('❌ 주소 정보가 없습니다. 페이지를 새로고침하고 다시 시도해주세요.');
        return;
    }
    
    if (!allData.geocoderInfo || !allData.geocoderInfo.result || !allData.geocoderInfo.result.point) {
        console.error('❌ 좌표 정보가 없습니다!');
        alert('❌ 좌표 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.');
        return;
    }
    
    console.log('✅ 필수 데이터 확인 완료!');
    
    // 현재 페이지의 모든 데이터를 localStorage에 저장
    const transferData = {
        addressInfo: allData.addressInfo,
        buildingInfo: allData.buildingInfo,
        geocoderInfo: allData.geocoderInfo,
        landInfo: allData.landInfo
    };
    
    console.log('💾 localStorage에 저장 중...');
    const jsonString = JSON.stringify(transferData);
    console.log('   📏 저장할 데이터 크기:', jsonString.length, '바이트');
    
    localStorage.setItem('brokerSearchData', jsonString);
    console.log('✅ localStorage 저장 완료!');
    
    // 공인중개사 찾기 페이지로 이동
    console.log('🚀 broker.html로 이동...');
    window.location.href = 'broker.html';
}

/**
 * 주소 요약 카드 표시 (점진적 업데이트)
 */
function displayAddressSummaryCard() {
    const container = document.getElementById('addressSummaryCard');
    if (!container) return;
    
    const addressInfo = allData.addressInfo;
    const geocoderInfo = allData.geocoderInfo;
    const landInfo = allData.landInfo;
    
    if (!addressInfo) {
        console.warn('⚠️ 주소 정보가 없습니다.');
        return;
    }
    
    // PNU 생성
    const pnu = generatePNU(addressInfo);
    
    // 좌표 정보 (있으면 표시, 없으면 "로딩 중...")
    let coordinates = '로딩 중...';
    if (geocoderInfo && geocoderInfo.result && geocoderInfo.result.point) {
        const point = geocoderInfo.result.point;
        coordinates = `${point.y}, ${point.x}`;
    }
    
    // 토지 정보에서 배지 데이터 추출 (있으면 표시)
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
                    <button class="icon-btn" onclick="addToFavorites()" title="즐겨찾기 추가">
                        ⭐ 즐겨찾기
                    </button>
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
                    <span class="summary-value ${coordinates === '로딩 중...' ? 'loading-text' : ''}">${coordinates}</span>
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
    const addressInfo = allData.addressInfo;
    const geocoderInfo = allData.geocoderInfo;
    
    if (!addressInfo) return;
    
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
    const addressInfo = allData.addressInfo;
    
    if (!addressInfo) return;
    
    // 메인 페이지로 공유 링크 생성 (주소가 미리 채워진 상태)
    const baseUrl = window.location.origin + window.location.pathname.replace('result.html', 'index.html');
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

/**
 * 즐겨찾기 추가 (Firestore + localStorage)
 */
async function addToFavorites() {
    const addressInfo = allData.addressInfo;
    
    if (!addressInfo) {
        alert('❌ 주소 정보가 없습니다.');
        return;
    }
    
    // localStorage에 저장 (항상)
    let favorites = JSON.parse(localStorage.getItem('favoriteAddresses') || '[]');
    
    // 중복 체크
    const isDuplicate = favorites.some(f => f.roadAddr === addressInfo.roadAddr);
    
    if (isDuplicate) {
        alert('⚠️ 이미 즐겨찾기에 추가된 주소입니다.');
        return;
    }
    
    // 즐겨찾기 추가
    const favoriteData = {
        roadAddr: addressInfo.roadAddr,
        jibunAddr: addressInfo.jibunAddr,
        zipNo: addressInfo.zipNo,
        addedAt: new Date().toISOString()
    };
    
    favorites.unshift(favoriteData);
    favorites = favorites.slice(0, 20);
    localStorage.setItem('favoriteAddresses', JSON.stringify(favorites));
    
    // Firestore에도 저장 시도 (로그인된 경우)
    if (typeof saveFavoriteToFirestore === 'function') {
        const firestoreSaved = await saveFavoriteToFirestore(addressInfo);
        
        if (firestoreSaved) {
            alert(`✅ 즐겨찾기에 추가되었습니다!\n\n메인 페이지와 클라우드에 저장되었습니다.`);
        } else {
            alert(`✅ 즐겨찾기에 추가되었습니다!\n\n메인 페이지에서 빠르게 다시 찾을 수 있습니다.`);
        }
    } else {
        alert(`✅ 즐겨찾기에 추가되었습니다!\n\n메인 페이지에서 빠르게 다시 찾을 수 있습니다.`);
    }
}

/**
 * 상세정보 보기 토글
 */
function toggleDetailInfo() {
    const detailSection = document.getElementById('detailInfoSection');
    const toggleIcon = document.getElementById('toggleIcon');
    const toggleBtn = document.querySelector('.detail-toggle-btn');
    
    if (!detailSection) return;
    
    if (detailSection.style.display === 'none') {
        detailSection.style.display = 'block';
        toggleIcon.textContent = '▲';
        toggleBtn.innerHTML = '<span id="toggleIcon">▲</span> 상세정보 닫기';
    } else {
        detailSection.style.display = 'none';
        toggleIcon.textContent = '▼';
        toggleBtn.innerHTML = '<span id="toggleIcon">▼</span> 상세정보 보기';
    }
}

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
