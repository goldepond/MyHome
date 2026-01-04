/* =========================================== */
/* HOUSE MVP - 간소화된 프록시 서버 */
/* 공공데이터포털 API 제거 (VWorld API만 사용) */
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

// CORS 설정
app.use(cors());

// JSON 파싱 미들웨어
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 정적 파일 서빙
app.use('/assest', express.static(path.join(__dirname, 'assest')));

// 요청 로깅 미들웨어
app.use((req, res, next) => {
    const startTime = Date.now();
    console.log('\n🌐 들어온 요청:', {
        method: req.method,
        url: req.url,
        시간: new Date().toLocaleTimeString('ko-KR')
    });
    
    res.on('finish', () => {
        const duration = Date.now() - startTime;
        console.log(`✅ 요청 완료: ${req.url} (${duration}ms) - 상태: ${res.statusCode}\n`);
    });
    
    next();
});

/* =========================================== */
/* 2. PROXY ROUTES - 프록시 라우트 (VWorld + 주소검색만) */
/* =========================================== */

/**
 * 도로명주소 검색 API 프록시
 * business.juso.go.kr/addrlink/addrLinkApi.do
 */
app.use('/api/juso', createProxyMiddleware({
    target: 'https://business.juso.go.kr',
    changeOrigin: true,
    timeout: 30000,
    pathRewrite: {
        '^/api/juso': '/addrlink/addrLinkApi.do'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📍 [도로명주소 API] 프록시 요청');
        console.log('   요청 경로:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('   📥 응답 상태:', proxyRes.statusCode);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    },
    onError: (err, req, res) => {
        console.error('\n❌ [도로명주소 API] 프록시 오류:', err.message);
        res.status(500).json({ 
            error: '도로명주소 API 프록시 오류',
            message: err.message 
        });
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
        console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('🌍 [Geocoder API] 프록시 요청');
        console.log('   요청 경로:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('   📥 응답 상태:', proxyRes.statusCode);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    },
    onError: (err, req, res) => {
        console.error('\n❌ [Geocoder API] 프록시 오류:', err.message);
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
        console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('🌍 [토지특성 API] 프록시 요청');
        console.log('   요청 경로:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('   📥 응답 상태:', proxyRes.statusCode);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    },
    onError: (err, req, res) => {
        console.error('\n❌ [토지특성 API] 프록시 오류:', err.message);
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
        console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('🏘️ [부동산중개업 API] 프록시 요청');
        console.log('   요청 경로:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('   📥 응답 상태:', proxyRes.statusCode);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    },
    onError: (err, req, res) => {
        console.error('\n❌ [부동산중개업 API] 프록시 오류:', err.message);
        res.status(500).json({ 
            error: '부동산중개업 API 프록시 오류',
            message: err.message 
        });
    }
}));

/**
 * 건축물대장 API 프록시
 * apick.app/rest/building_register
 */
app.post('/api/building-register', async (req, res) => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📄 [건축물대장 API] 프록시 요청');
    console.log('   요청 데이터:', req.body);
    
    try {
        const FormData = require('form-data');
        const fetch = require('node-fetch');
        
        const formData = new FormData();
        formData.append('address', req.body.address);
        formData.append('b_name', req.body.b_name);
        formData.append('dong', req.body.dong);
        formData.append('ho', req.body.ho || '');
        
        const response = await fetch('https://apick.app/rest/building_register', {
            method: 'POST',
            headers: {
                'CL_AUTH_KEY': '79d716e9c6106372ebd9322825112e86',
                ...formData.getHeaders()
            },
            body: formData
        });
        
        console.log('   📥 응답 상태:', response.status);
        
        // 응답 헤더 전달
        const headers = {
            'success': response.headers.get('success'),
            'result': response.headers.get('result'),
            'ic_id': response.headers.get('ic_id'),
            'cost': response.headers.get('cost'),
            'ms': response.headers.get('ms'),
            'Content-Type': response.headers.get('Content-Type') || 'application/pdf',
            'Content-Disposition': response.headers.get('Content-Disposition') || 'inline; filename="building_register.pdf"'
        };
        
        console.log('   📋 응답 헤더:', headers);
        
        // 헤더 설정
        Object.keys(headers).forEach(key => {
            if (headers[key]) res.setHeader(key, headers[key]);
        });
        
        // PDF 바이너리 스트림 전달
        const buffer = await response.buffer();
        console.log('   📦 PDF 크기:', (buffer.length / 1024).toFixed(2), 'KB');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        res.send(buffer);
        
    } catch (error) {
        console.error('\n❌ [건축물대장 API] 프록시 오류:', error.message);
        console.error('   스택:', error.stack);
        res.status(500).json({ 
            error: '건축물대장 API 프록시 오류',
            message: error.message 
        });
    }
});

/* =========================================== */
/* 3. SERVER STARTUP - 서버 시작 */
/* =========================================== */

app.listen(PORT, () => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🚀 간소화된 프록시 서버 시작 완료!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📡 서버 주소: http://localhost:${PORT}`);
    console.log(`⏰ 시작 시간: ${new Date().toLocaleString('ko-KR')}`);
    console.log('\n📋 사용 가능한 API (공공데이터포털 API 제거됨):');
    console.log('   ✅ /api/juso (도로명주소 검색 - 행정안전부)');
    console.log('   ✅ /api/geocoder (좌표 변환 - VWorld)');
    console.log('   ✅ /api/land (토지특성 정보 - VWorld)');
    console.log('   ✅ /api/broker (부동산중개업 - VWorld)');
    console.log('\n❌ 제거된 API (401 인증 오류):');
    console.log('   - /api/building (건물 정보)');
    console.log('   - /api/apt (아파트 목록)');
    console.log('   - /api/apt-detail (아파트 상세)');
    console.log('   - /api/region (행정구역코드)');
    console.log('   - /api/realestate (부동산 중개업)');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('💡 Ctrl+C로 서버를 종료할 수 있습니다.\n');
});

/* =========================================== */
/* 4. ERROR HANDLING - 에러 처리 */
/* =========================================== */

process.on('uncaughtException', (err) => {
    console.error('❌ 처리되지 않은 예외:', err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ 처리되지 않은 Promise 거부:', reason);
});

