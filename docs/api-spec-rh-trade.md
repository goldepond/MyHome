# 국토교통부 연립다세대 매매 실거래가 API 명세

> **Version:** 1.1.0 (2026-02-09)
> **Base URL:** `https://apis.data.go.kr/1613000/RTMSDataSvcRHTrade`

---

## 개요

「부동산 거래신고 등에 관한 법률」에 따라 신고된 자료로서, 행정표준코드관리시스템(www.code.go.kr)의 법정동 코드 중 앞 5자리와 계약년월 6자리로 해당 지역, 해당 기간의 연립다세대 매매 실거래가 상세자료를 조회할 수 있습니다.

### 공개 정책
- 개인정보보호를 위해 연립다세대 매매의 **층 정보만** 제공

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
| 키워드 | 실거래가, 매매, 거래, 연립, 다세대, 주택 |

---

## API 목록

### GET /getRTMSDataSvcRHTrade

연립다세대 매매 실거래가 공개 자료

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
GET https://apis.data.go.kr/1613000/RTMSDataSvcRHTrade/getRTMSDataSvcRHTrade
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
          "mhouseNm": "string",
          "jibun": "string",
          "buildYear": "string",
          "excluUseAr": "string",
          "landAr": "string",
          "dealYear": "string",
          "dealMonth": "string",
          "dealDay": "string",
          "dealAmount": "string",
          "floor": "string",
          "cdealType": "string",
          "cdealDay": "string",
          "dealingGbn": "string",
          "estateAgentSggNm": "string",
          "rgstDate": "string",
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
| `mhouseNm` | string | 연립다세대명 | `"청운빌라"` |
| `jibun` | string | 지번 | `"123-4"` |
| `buildYear` | string | 건축년도 | `"2010"` |
| `excluUseAr` | string | 전용면적 (㎡) | `"59.94"` |
| `landAr` | string | 대지면적 (㎡) | `"45.32"` |
| `dealYear` | string | 거래년도 | `"2025"` |
| `dealMonth` | string | 거래월 | `"1"` |
| `dealDay` | string | 거래일 | `"15"` |
| `dealAmount` | string | 거래금액 (만원, 콤마 포함) | `"35,000"` |
| `floor` | string | 층 | `"3"` |
| `cdealType` | string | 해제여부 | `""` (빈값: 정상) |
| `cdealDay` | string | 해제사유발생일 | `""` |
| `dealingGbn` | string | 거래유형 | `"중개거래"` / `"직거래"` |
| `estateAgentSggNm` | string | 중개사 소재지 | `"서울 종로구"` |
| `rgstDate` | string | 등기일자 | `"25.02.01"` |
| `slerGbn` | string | 매도자 구분 | `"개인"` / `"법인"` |
| `buyerGbn` | string | 매수자 구분 | `"개인"` / `"법인"` |

---

## 필드 상세 설명

### mhouseNm (연립다세대명)

아파트 API의 `aptNm`과 동일한 역할로, 연립주택 또는 다세대주택의 명칭입니다.

> **연립주택 vs 다세대주택**
> - 연립주택: 4층 이하, 연면적 660㎡ 초과
> - 다세대주택: 4층 이하, 연면적 660㎡ 이하

### landAr (대지면적)

**아파트 API에는 없는 필드**로, 연립다세대의 경우 대지권 면적이 함께 제공됩니다.

| Field | Description |
|-------|-------------|
| `excluUseAr` | 전용면적 - 실제 거주 공간 면적 |
| `landAr` | 대지면적 - 토지 지분 면적 |

### cdealType (해제여부)

거래 취소/해제 여부를 나타냅니다.
- 빈 값(`""`): 정상 거래
- `"O"`: 해제된 거래

### dealingGbn (거래유형)

| 값 | 설명 |
|----|------|
| `중개거래` | 공인중개사를 통한 거래 |
| `직거래` | 중개 없이 당사자 간 직접 거래 |

---

## 아파트 매매 API와의 비교

| 항목 | 아파트 매매 | 연립다세대 매매 |
|------|------------|-----------------|
| **Base URL** | RTMSDataSvcAptTrade | RTMSDataSvcRHTrade |
| **건물명 필드** | `aptNm` | `mhouseNm` |
| **대지면적** | 없음 | `landAr` |
| **동 정보** | `aptDong` (등기완료 시) | 없음 |
| **토지임대부** | `landLeaseholdGbn` | 없음 |

### 공통 필드

```
sggCd, umdNm, jibun, excluUseAr, buildYear,
dealYear, dealMonth, dealDay, dealAmount, floor,
cdealType, cdealDay, dealingGbn, estateAgentSggNm,
rgstDate, slerGbn, buyerGbn
```

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
| 데이터명 | 국토교통부_연립다세대 매매 실거래가 자료 |
| 서비스유형 | REST |
| 심의여부 | 자동승인 |
| 신청유형 | 개발계정 \| 활용신청 |
| 처리상태 | 승인 |
| 활용기간 | 2026-02-09 ~ 2028-02-09 |

### 서비스정보

| 항목 | 내용 |
|------|------|
| End Point | `https://apis.data.go.kr/1613000/RTMSDataSvcRHTrade` |
| 데이터포맷 | XML |
| 참고문서 | 연립다세대 매매 실거래가 자료 기술문서.hwp |

### 상세기능정보

| NO | 상세기능 | 설명 | 일일 트래픽 |
|----|----------|------|-------------|
| 1 | 연립다세대 매매 실거래가 공개 자료 `/getRTMSDataSvcRHTrade` | 부동산 거래신고에 관한 법률에 따라 신고된 거래의 실거래 자료를 제공 | 10,000 |

### 활용정보

| 항목 | 내용 |
|------|------|
| 활용목적 | 웹 사이트 개발 |
| 활용내용 | MyHome 개발 |
| 이용허락범위 | 제한 없음 |

---

## 참고

- **법정동코드 조회:** https://www.code.go.kr/stdcode/regCodeL.do
- **공공데이터포털:** https://www.data.go.kr/data/15058038/openapi.do
- **참고문서:** 연립다세대 매매 실거래가 자료 기술문서.hwp (공공데이터포털 다운로드)
