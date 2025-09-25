/* =========================================== */
/* HOUSE MVP - 프록시 서버 */
/* CORS 문제 해결을 위한 Node.js Express 프록시 서버 */
/* =========================================== */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 3001;

/* =========================================== */
/* 1. MIDDLEWARE SETUP - 미들웨어 설정 */
/* =========================================== */

// CORS 설정 - 모든 도메인에서의 요청 허용
app.use(cors());

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
    pathRewrite: {
        '^/api/juso': '/addrlink/addrLinkApi.do'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('📍 도로명주소 API 프록시 요청:', proxyReq.path);
    },
    onError: (err, req, res) => {
        console.error('📍 도로명주소 API 프록시 오류:', err);
        res.status(500).json({ error: '도로명주소 API 프록시 오류' });
    }
}));

/**
 * 행정구역코드 API 프록시
 * apis.data.go.kr/1741000/StanReginCd
 */
app.use('/api/region', createProxyMiddleware({
    target: 'https://apis.data.go.kr',
    changeOrigin: true,
    pathRewrite: {
        '^/api/region': '/1741000/StanReginCd'
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
    pathRewrite: {
        '^/api/apt': '/1613000/AptListService3'
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
    pathRewrite: {
        '^/api/building': '/1613000/BldRgstHubService'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🏗️ 건물 정보 API 프록시 요청:', proxyReq.path);
    },
    onError: (err, req, res) => {
        console.error('🏗️ 건물 정보 API 프록시 오류:', err);
        res.status(500).json({ error: '건물 정보 API 프록시 오류' });
    }
}));

/* =========================================== */
/* 3. SERVER STARTUP - 서버 시작 */
/* =========================================== */

app.listen(PORT, () => {
    console.log(`🚀 프록시 서버가 http://localhost:${PORT}에서 실행 중입니다.`);
    console.log('📋 사용 가능한 프록시 엔드포인트:');
    console.log('   - /api/juso (도로명주소 검색)');
    console.log('   - /api/region (행정구역코드)');
    console.log('   - /api/apt (아파트 목록)');
    console.log('   - /api/apt-detail (아파트 상세 정보)');
    console.log('   - /api/building (건물 정보)');
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