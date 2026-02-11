# 국토교통부 아파트 매매 실거래가 자료 API 명세 (일반)

> **Version:** 1.1.0 (2026-02-09)
> **Base URL:** `https://apis.data.go.kr/1613000/RTMSDataSvcAptTrade`

---

## 개요

「부동산 거래신고 등에 관한 법률」에 따라 신고된 자료로서, 행정표준코드관리시스템(www.code.go.kr)의 법정동 코드 중 앞 5자리와 계약년월 6자리로 해당 지역, 해당 기간의 아파트 매매 신고정보를 조회할 수 있습니다.

### 공개 정책
- 개인정보보호를 위해 아파트의 **층 정보만** 제공
- **소유권 이전등기 완료**된 건에 한하여 **동 정보** 추가 공개

### 일반 vs 상세 API

| 구분 | 일반 API (현재) | 상세 API |
|------|----------------|----------|
| Base URL | **RTMSDataSvcAptTrade** | RTMSDataSvcAptTradeDev |
| 도로명주소 | X | O |
| 지번 상세 (본번/부번) | X | O |
| 아파트 시퀀스 | X | O |
| 활용신청 | 7,520 | 4,891 |

> **참고:** 현재 프로젝트에서는 **상세 API** (`RTMSDataSvcAptTradeDev`)를 사용 중입니다.

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
| 키워드 | 실거래가, 매매, 거래, 아파트, 주택 |
| 참고문서 | 아파트 매매 실거래가 자료 기술문서.hwp |

---

## API 목록

### GET /getRTMSDataSvcAptTrade

아파트 매매 실거래가 공개 자료

부동산 거래신고에 관한 법률에 따라 신고된 거래의 실거래 자료를 제공합니다.

---

## 요청 (Request)

### Parameters

| Name | Type | In | Required | Description |
|------|------|-----|----------|-------------|
| `LAWD_CD` | number | query | **필수** | 지역코드. 법정동코드 10자리 중 **앞 5자리** |
| `DEAL_YMD` | number | query | **필수** | 계약월. 계약년월 **(6자리, YYYYMM)** |
| `serviceKey` | string | query | **필수** | 공공데이터포털 인증키 |

### 요청 예시

```
GET https://apis.data.go.kr/1613000/RTMSDataSvcAptTrade/getRTMSDataSvcAptTrade
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
          "aptNm": "string",
          "jibun": "string",
          "excluUseAr": "string",
          "dealYear": "string",
          "dealMonth": "string",
          "dealDay": "string",
          "dealAmount": "string",
          "floor": "string",
          "buildYear": "string",
          "cdealType": "string",
          "cdealDay": "string",
          "dealingGbn": "string",
          "estateAgentSggNm": "string",
          "rgstDate": "string",
          "aptDong": "string",
          "slerGbn": "string",
          "buyerGbn": "string",
          "landLeaseholdGbn": "string"
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
| `aptNm` | string | 아파트명 | `"래미안대치팰리스"` |
| `jibun` | string | 지번 | `"123-4"` |
| `excluUseAr` | string | 전용면적 (㎡) | `"84.99"` |
| `dealYear` | string | 거래년도 | `"2025"` |
| `dealMonth` | string | 거래월 | `"1"` |
| `dealDay` | string | 거래일 | `"15"` |
| `dealAmount` | string | 거래금액 (만원, 콤마 포함) | `"94,500"` |
| `floor` | string | 층 | `"12"` |
| `buildYear` | string | 건축년도 | `"2015"` |
| `cdealType` | string | 해제여부 | `""` (정상) / `"O"` (해제) |
| `cdealDay` | string | 해제사유발생일 | `""` |
| `dealingGbn` | string | 거래유형 | `"중개거래"` / `"직거래"` |
| `estateAgentSggNm` | string | 중개사 소재지 | `"서울 강남구"` |
| `rgstDate` | string | 등기일자 | `"25.02.01"` |
| `aptDong` | string | 아파트 동 (등기완료 시 공개) | `"101"` |
| `slerGbn` | string | 매도자 구분 | `"개인"` / `"법인"` |
| `buyerGbn` | string | 매수자 구분 | `"개인"` / `"법인"` |
| `landLeaseholdGbn` | string | 토지임대부 구분 | `""` (일반) / `"토지임대부"` |

---

## 일반 API vs 상세 API 필드 비교

### 일반 API 필드 (20개)
```
sggCd, umdNm, aptNm, jibun, excluUseAr,
dealYear, dealMonth, dealDay, dealAmount, floor, buildYear,
cdealType, cdealDay, dealingGbn, estateAgentSggNm, rgstDate,
aptDong, slerGbn, buyerGbn, landLeaseholdGbn
```

### 상세 API 추가 필드 (12개)
```
umdCd, landCd, bonbun, bubun,                    // 지번 상세
roadNm, roadNmSggCd, roadNmCd, roadNmSeq,        // 도로명주소
roadNmbCd, roadNmBonbun, roadNmBubun,
aptSeq                                           // 아파트 시퀀스
```

---

## 필드 상세 설명

### cdealType (해제여부)
거래 취소/해제 여부를 나타냅니다.
- 빈 값(`""`): 정상 거래
- `"O"`: 해제된 거래

### dealingGbn (거래유형)
| 값 | 설명 |
|----|------|
| `중개거래` | 공인중개사를 통한 거래 |
| `직거래` | 중개 없이 당사자 간 직접 거래 |

### slerGbn / buyerGbn (매도자/매수자 구분)
| 값 | 설명 |
|----|------|
| `개인` | 개인 거래자 |
| `법인` | 법인 거래자 |

### landLeaseholdGbn (토지임대부)
토지는 임대하고 건물만 분양받는 형태의 아파트 여부를 나타냅니다.

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
| 활용기간 | 2026-02-09 ~ 2028-02-09 |

### 서비스정보

| 항목 | 내용 |
|------|------|
| End Point | `https://apis.data.go.kr/1613000/RTMSDataSvcAptTrade` |

### 상세기능정보

| 항목 | 내용 |
|------|------|
| 일일 트래픽 | 10,000건/일 |
| 운영계정 증가 | 활용사례 등록 시 증가 가능 |

### 활용정보

| 항목 | 내용 |
|------|------|
| 활용 서비스 | MyHome 웹 프로젝트 |
| 활용 목적 | 부동산 실거래가 조회 서비스 |

---

## 참고

- **법정동코드 조회:** https://www.code.go.kr/stdcode/regCodeL.do
- **공공데이터포털:** https://www.data.go.kr/data/15057511/openapi.do
- **참고문서:** 아파트 매매 실거래가 자료 기술문서.hwp (공공데이터포털 다운로드)
- **상세 API 문서:** [api-spec-apt-trade.md](api-spec-apt-trade.md)
