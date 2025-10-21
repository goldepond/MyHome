/* =========================================== */
/* HOUSE MVP - 프록시 서버 */
/* CORS 문제 해결을 위한 Node.js Express 프록시 서버 */
/* =========================================== */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = 3001;

/* =========================================== */
/* 1. MIDDLEWARE SETUP - 미들웨어 설정 */
/* =========================================== */

// CORS 설정 - 모든 도메인에서의 요청 허용
app.use(cors());

// JSON 파싱 미들웨어
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 정적 파일 서빙 설정
app.use('/assest', express.static(path.join(__dirname, 'assest')));

/* =========================================== */
/* 2. PROXY ROUTES - 프록시 라우트 설정 */
/* =========================================== */

/**
 * 도로명주소 검색 API 프록시
 * business.juso.go.kr/addrlink/addrLinkApi.do
 */
app.use('/api/juso', createProxyMiddleware({
    target: 'https://business.juso.go.kr',
    changeOrigin: true,
    timeout: 30000, // 30초 타임아웃
    pathRewrite: {
        '^/api/juso': '/addrlink/addrLinkApi.do'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('📍 도로명주소 API 프록시 요청:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('✅ 도로명주소 API 응답:', proxyRes.statusCode);
    },
    onError: (err, req, res) => {
        console.error('❌ 도로명주소 API 프록시 오류:', err.message);
        res.status(500).json({ 
            error: '도로명주소 API 프록시 오류',
            message: err.message 
        });
    }
}));

/**
 * 행정구역코드 API 프록시
 * apis.data.go.kr/1741000/StanReginCd
 */
app.use('/api/region', createProxyMiddleware({
    target: 'https://apis.data.go.kr',
    changeOrigin: true,
    secure: false, // SSL 인증서 검증 비활성화
    pathRewrite: {
        '^/api/region': '/1741000/StanReginCd/getStanReginCdList'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🏛️ 행정구역코드 API 프록시 요청:', proxyReq.path);
    },
    onError: (err, req, res) => {
        console.error('🏛️ 행정구역코드 API 프록시 오류:', err);
        res.status(500).json({ error: '행정구역코드 API 프록시 오류' });
    }
}));

/**
 * 아파트 목록 API 프록시
 * apis.data.go.kr/1613000/AptListService3
 */
app.use('/api/apt', createProxyMiddleware({
    target: 'https://apis.data.go.kr',
    changeOrigin: true,
    secure: false, // SSL 인증서 검증 비활성화
    pathRewrite: {
        '^/api/apt': '/1613000/AptListService3/getRoadnameAptList3'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🏢 아파트 목록 API 프록시 요청:', proxyReq.path);
    },
    onError: (err, req, res) => {
        console.error('🏢 아파트 목록 API 프록시 오류:', err);
        res.status(500).json({ error: '아파트 목록 API 프록시 오류' });
    }
}));

/**
 * 공동주택 상세 정보 API 프록시
 * apis.data.go.kr/1613000/AptBasisInfoServiceV4/getAphusDtlInfoV4
 */
app.use('/api/apt-detail', createProxyMiddleware({
    target: 'https://apis.data.go.kr',
    changeOrigin: true,
    secure: false, // SSL 인증서 검증 비활성화
    pathRewrite: {
        '^/api/apt-detail': '/1613000/AptBasisInfoServiceV4/getAphusDtlInfoV4'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🏢 아파트 상세 정보 API 프록시 요청:', proxyReq.path);
    },
    onError: (err, req, res) => {
        console.error('🏢 아파트 상세 정보 API 프록시 오류:', err);
        res.status(500).json({ error: '아파트 상세 정보 API 프록시 오류' });
    }
}));

/**
 * 건물 정보 API 프록시
 * apis.data.go.kr/1613000/BldRgstHubService
 */
app.use('/api/building', createProxyMiddleware({
    target: 'https://apis.data.go.kr',
    changeOrigin: true,
    secure: false, // SSL 인증서 검증 비활성화
    pathRewrite: {
        '^/api/building': '/1613000/BldRgstHubService/getBrTitleInfo'
    },
    logLevel: 'debug',
    onProxyReq: (proxyReq, req, res) => {
        console.log('🏗️ 건물 정보 API 프록시 요청:', proxyReq.path);
    },
    onError: (err, req, res) => {
        console.error('🏗️ 건물 정보 API 프록시 오류:', err);
        res.status(500).json({ error: '건물 정보 API 프록시 오류' });
    }
}));

/**
 * 부동산 중개업 조회 API 프록시
 * apis.data.go.kr/1613000/RealEstateService
 */
app.use('/api/realestate', createProxyMiddleware({
    target: 'https://apis.data.go.kr',
    changeOrigin: true,
    secure: false, // SSL 인증서 검증 비활성화
    pathRewrite: {
        '^/api/realestate': '/1613000/RealEstateService/getRealEstateBrokerInfo'
    },
    logLevel: 'debug',
    onProxyReq: (proxyReq, req, res) => {
        console.log('🏠 부동산 중개업 조회 API 프록시 요청:', proxyReq.path);
    },
    onError: (err, req, res) => {
        console.error('🏠 부동산 중개업 조회 API 프록시 오류:', err);
        res.status(500).json({ error: '부동산 중개업 조회 API 프록시 오류' });
    }
}));

/**
 * VWorld Geocoder API 프록시
 * api.vworld.kr/req/address
 */
app.use('/api/geocoder', createProxyMiddleware({
    target: 'https://api.vworld.kr',
    changeOrigin: true,
    secure: false,
    pathRewrite: {
        '^/api/geocoder': '/req/address'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🌍 Geocoder API 프록시 요청:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('✅ Geocoder API 응답:', proxyRes.statusCode);
    },
    onError: (err, req, res) => {
        console.error('❌ Geocoder API 프록시 오류:', err.message);
        res.status(500).json({ 
            error: 'Geocoder API 프록시 오류',
            message: err.message 
        });
    }
}));

/**
 * VWorld 토지특성공간정보 API 프록시
 * api.vworld.kr/ned/wfs/getLandCharacteristicsWFS
 */
app.use('/api/land', createProxyMiddleware({
    target: 'https://api.vworld.kr',
    changeOrigin: true,
    secure: false,
    pathRewrite: {
        '^/api/land': '/ned/wfs/getLandCharacteristicsWFS'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🌍 토지특성 API 프록시 요청:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('✅ 토지특성 API 응답:', proxyRes.statusCode);
    },
    onError: (err, req, res) => {
        console.error('❌ 토지특성 API 프록시 오류:', err.message);
        res.status(500).json({ 
            error: '토지특성 API 프록시 오류',
            message: err.message 
        });
    }
}));

/**
 * VWorld 부동산중개업WFS조회 API 프록시
 * api.vworld.kr/ned/wfs/getEstateBrkpgWFS
 */
app.use('/api/broker', createProxyMiddleware({
    target: 'https://api.vworld.kr',
    changeOrigin: true,
    secure: false,
    pathRewrite: {
        '^/api/broker': '/ned/wfs/getEstateBrkpgWFS'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🏘️ 부동산중개업 API 프록시 요청:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('✅ 부동산중개업 API 응답:', proxyRes.statusCode);
    },
    onError: (err, req, res) => {
        console.error('❌ 부동산중개업 API 프록시 오류:', err.message);
        res.status(500).json({ 
            error: '부동산중개업 API 프록시 오류',
            message: err.message 
        });
    }
}));


/* =========================================== */
/* 4. SERVER STARTUP - 서버 시작 */
/* =========================================== */

app.listen(PORT, () => {
    console.log(`🚀 프록시 서버가 http://localhost:${PORT}에서 실행 중입니다.`);
    console.log('📋 사용 가능한 프록시 엔드포인트:');
    console.log('   - /api/juso (도로명주소 검색)');
    console.log('   - /api/region (행정구역코드)');
    console.log('   - /api/apt (아파트 목록)');
    console.log('   - /api/apt-detail (아파트 상세 정보)');
    console.log('   - /api/building (건물 정보)');
    console.log('   - /api/realestate (부동산 중개업 조회)');
    console.log('   - /api/geocoder (Geocoder API)');
    console.log('   - /api/land (토지특성공간정보)');
    console.log('   - /api/broker (부동산중개업WFS조회)');
});

/* =========================================== */
/* 4. ERROR HANDLING - 에러 처리 */
/* =========================================== */

// 전역 에러 핸들러
process.on('uncaughtException', (err) => {
    console.error('❌ 처리되지 않은 예외:', err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ 처리되지 않은 Promise 거부:', reason);
});