# 국토교통부 단독/다가구 매매 실거래가 API 명세

> **Version:** 1.1.0 (2026-02-09)
> **Base URL:** `https://apis.data.go.kr/1613000/RTMSDataSvcSHTrade`

---

## 개요

「부동산 거래신고 등에 관한 법률」에 따라 신고된 자료로서, 행정표준코드관리시스템(www.code.go.kr)의 법정동 코드 중 앞 5자리와 계약년월 6자리로 해당 지역, 해당 기간의 단독/다가구주택 매매 신고정보를 조회할 수 있습니다.

### 공개 정책
- 개인정보보호를 위해 단독/다가구 주택의 **지번정보는 일부만** 제공

---

## OpenAPI 정보

| 항목 | 내용 |
|------|------|
| 분류체계 | 일반공공행정 - 일반행정 |
| 제공기관 | 국토교통부 |
| 관리부서 | 부동산소비자보호기획단 |
| 관리부서 전화번호 | 053-663-8642 |
| API 유형 | REST |
| 데이터포맷 | XML |
| 비용 | 무료 |
| 트래픽 | 개발계정: 10,000건/일, 운영계정: 활용사례 등록 시 증가 가능 |
| 심의유형 | 개발/운영 모두 자동승인 |
| 이용허락범위 | 제한 없음 |
| 키워드 | 실거래가, 매매, 거래, 단독, 다가구, 주택 |

---

## API 목록

### GET /getRTMSDataSvcSHTrade

단독/다가구 매매 실거래가 공개 자료

부동산 거래신고에 관한 법률에 따라 신고된 거래의 실거래 자료를 제공합니다.

---

## 요청 (Request)

### Parameters

| Name | Type | In | Required | Description |
|------|------|-----|----------|-------------|
| `LAWD_CD` | number | query | **필수** | 지역코드. 행정표준코드관리시스템(www.code.go.kr)의 법정동코드 10자리 중 **앞 5자리** |
| `DEAL_YMD` | number | query | **필수** | 계약월. 실거래 자료의 계약년월 **(6자리, YYYYMM)** |
| `serviceKey` | string | query | **필수** | 공공데이터포털에서 발급받은 인증키 |

### 요청 예시

```
GET https://apis.data.go.kr/1613000/RTMSDataSvcSHTrade/getRTMSDataSvcSHTrade
    ?LAWD_CD=11110
    &DEAL_YMD=202501
    &serviceKey={인증키}
```

---

## 응답 (Response)

### HTTP Status Code

| Code | Description |
|------|-------------|
| 200 | 성공 |

### Response Schema

```json
{
  "header": {
    "resultCode": "string",
    "resultMsg": "string"
  },
  "body": {
    "items": {
      "item": [
        {
          "sggCd": "string",
          "umdNm": "string",
          "houseType": "string",
          "jibun": "string",
          "totalFloorAr": "string",
          "plottageAr": "string",
          "dealYear": "string",
          "dealMonth": "string",
          "dealDay": "string",
          "dealAmount": "string",
          "buildYear": "string",
          "cdealType": "string",
          "cdealDay": "string",
          "dealingGbn": "string",
          "estateAgentSggNm": "string",
          "slerGbn": "string",
          "buyerGbn": "string"
        }
      ]
    },
    "totalCount": 0,
    "numOfRows": 0,
    "pageNo": 0
  }
}
```

---

## 응답 필드 상세

### Header

| Field | Type | Description |
|-------|------|-------------|
| `resultCode` | string | 결과 코드 (`00`: 정상) |
| `resultMsg` | string | 결과 메시지 (`NORMAL SERVICE`: 정상) |

### Body

| Field | Type | Description |
|-------|------|-------------|
| `items` | object | 실거래 데이터 목록 |
| `totalCount` | number | 전체 결과 수 |
| `numOfRows` | number | 한 페이지 결과 수 |
| `pageNo` | number | 현재 페이지 번호 |

### Item (거래 정보)

| Field | Type | Description | 예시 |
|-------|------|-------------|------|
| `sggCd` | string | 시군구 코드 | `"11110"` |
| `umdNm` | string | 법정동명 | `"청운동"` |
| `houseType` | string | 주택유형 | `"단독"` / `"다가구"` |
| `jibun` | string | 지번 (일부만 제공) | `"123"` |
| `totalFloorAr` | string | 연면적 (㎡) | `"165.23"` |
| `plottageAr` | string | 대지면적 (㎡) | `"198.45"` |
| `dealYear` | string | 거래년도 | `"2025"` |
| `dealMonth` | string | 거래월 | `"1"` |
| `dealDay` | string | 거래일 | `"15"` |
| `dealAmount` | string | 거래금액 (만원, 콤마 포함) | `"85,000"` |
| `buildYear` | string | 건축년도 | `"1995"` |
| `cdealType` | string | 해제여부 | `""` (빈값: 정상) |
| `cdealDay` | string | 해제사유발생일 | `""` |
| `dealingGbn` | string | 거래유형 | `"중개거래"` / `"직거래"` |
| `estateAgentSggNm` | string | 중개사 소재지 | `"서울 종로구"` |
| `slerGbn` | string | 매도자 구분 | `"개인"` / `"법인"` |
| `buyerGbn` | string | 매수자 구분 | `"개인"` / `"법인"` |

---

## 필드 상세 설명

### houseType (주택유형)

단독/다가구 주택의 구분을 나타냅니다.

| 값 | 설명 |
|----|------|
| `단독` | 단독주택 - 1개 가구가 거주하는 독립 주택 |
| `다가구` | 다가구주택 - 여러 가구가 거주하나 소유권은 1개 |

> **단독주택 vs 다가구주택 vs 다세대주택**
> - **단독주택**: 1개 가구 거주, 단일 소유권
> - **다가구주택**: 여러 가구 거주, 단일 소유권 (건물 전체 매매)
> - **다세대주택**: 여러 가구 거주, 각 가구별 분리 소유권 (호별 매매 가능)

### totalFloorAr (연면적)

건물 **전체 층의 바닥면적 합계**입니다.

- 지하층, 지상층 모든 층의 면적 포함
- 아파트/연립다세대의 `excluUseAr`(전용면적)과는 다른 개념

### plottageAr (대지면적)

건물이 위치한 **토지의 면적**입니다.

| API | 대지면적 필드명 |
|-----|----------------|
| 연립다세대 매매 | `landAr` |
| 단독/다가구 매매 | `plottageAr` |

### jibun (지번)

개인정보보호를 위해 **일부만 제공**됩니다.
- 예: `"123-4"` → `"123"` (부번 생략)

### cdealType (해제여부)

거래 취소/해제 여부를 나타냅니다.
- 빈 값(`""`): 정상 거래
- `"O"`: 해제된 거래

---

## 다른 주택 유형 API와의 비교

| 항목 | 아파트 매매 | 연립다세대 매매 | 단독/다가구 매매 |
|------|------------|-----------------|------------------|
| **Base URL** | RTMSDataSvcAptTrade | RTMSDataSvcRHTrade | RTMSDataSvcSHTrade |
| **건물명** | `aptNm` | `mhouseNm` | 없음 |
| **주택유형** | 없음 | 없음 | `houseType` |
| **면적** | `excluUseAr` (전용) | `excluUseAr` (전용) | `totalFloorAr` (연면적) |
| **대지면적** | 없음 | `landAr` | `plottageAr` |
| **층** | `floor` | `floor` | 없음 |
| **동** | `aptDong` | 없음 | 없음 |
| **등기일자** | `rgstDate` | `rgstDate` | 없음 |
| **토지임대부** | `landLeaseholdGbn` | 없음 | 없음 |

### 단독/다가구 특징
- **건물명 없음**: 개별 주택이므로 명칭 대신 지번으로 식별
- **층 정보 없음**: 건물 전체 거래이므로 특정 층 개념 없음
- **연면적 제공**: 전용면적 대신 건물 전체 면적 제공
- **주택유형 제공**: 단독/다가구 구분 가능

---

## 에러 코드

| resultCode | resultMsg | 설명 |
|------------|-----------|------|
| `00` | NORMAL SERVICE | 정상 |
| `01` | APPLICATION ERROR | 어플리케이션 에러 |
| `04` | HTTP ERROR | HTTP 에러 |
| `12` | NO OPENAPI SERVICE ERROR | 해당 API 서비스 없음 |
| `20` | SERVICE ACCESS DENIED ERROR | 서비스 접근 거부 |
| `22` | LIMITED NUMBER OF SERVICE REQUESTS EXCEEDS ERROR | 일일 요청 한도 초과 |
| `30` | SERVICE KEY IS NOT REGISTERED ERROR | 등록되지 않은 서비스키 |
| `31` | DEADLINE HAS EXPIRED ERROR | 서비스키 기한 만료 |
| `32` | UNREGISTERED IP ERROR | 등록되지 않은 IP |

---

## 활용신청 정보

### 기본정보

| 항목 | 내용 |
|------|------|
| 데이터명 | 국토교통부_단독/다가구 매매 실거래가 자료 |
| 서비스유형 | REST |
| 심의여부 | 자동승인 |
| 신청유형 | 개발계정 \| 활용신청 |
| 처리상태 | 승인 |
| 활용기간 | 2026-02-09 ~ 2028-02-09 |

### 서비스정보

| 항목 | 내용 |
|------|------|
| End Point | `https://apis.data.go.kr/1613000/RTMSDataSvcSHTrade` |
| 데이터포맷 | XML |
| 참고문서 | 단독다가구 매매 실거래가 자료 기술문서.hwp |

### 상세기능정보

| NO | 상세기능 | 설명 | 일일 트래픽 |
|----|----------|------|-------------|
| 1 | 단독/다가구 매매 실거래가 공개 자료 `/getRTMSDataSvcSHTrade` | 부동산 거래신고에 관한 법률에 따라 신고된 거래의 실거래 자료를 제공 | 10,000 |

### 활용정보

| 항목 | 내용 |
|------|------|
| 활용목적 | 웹 사이트 개발 |
| 활용내용 | MyHome 개발 |
| 이용허락범위 | 제한 없음 |

---

## 참고

- **법정동코드 조회:** https://www.code.go.kr/stdcode/regCodeL.do
- **공공데이터포털:** https://www.data.go.kr/data/15058022/openapi.do
- **참고문서:** 단독다가구 매매 실거래가 자료 기술문서.hwp (공공데이터포털 다운로드)
