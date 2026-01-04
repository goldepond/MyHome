/**
 * 간단한 로컬 HTTP 서버
 * HouseMVP 프로젝트를 http://localhost:8080 에서 실행합니다.
 */

const express = require('express');
const path = require('path');

const app = express();
const PORT = 8080;

// 정적 파일 제공 (현재 디렉토리)
app.use(express.static(__dirname));

// 모든 HTML 파일에 대한 라우팅
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'landing.html'));
});

app.get('/search', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

app.get('/broker.html', (req, res) => {
    res.sendFile(path.join(__dirname, 'broker.html'));
});

app.get('/result.html', (req, res) => {
    res.sendFile(path.join(__dirname, 'result.html'));
});

app.get('/admin.html', (req, res) => {
    res.sendFile(path.join(__dirname, 'admin.html'));
});

// 서버 시작
app.listen(PORT, () => {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🏠 HouseMVP 로컬 서버 시작!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📡 서버 주소: http://localhost:${PORT}`);
    console.log('🌐 브라우저에서 위 주소로 접속하세요.');
    console.log('');
    console.log('⚠️  주의: Firebase 인증을 사용하려면');
    console.log('   file:// 대신 http://localhost:8080 으로 접속해야 합니다.');
    console.log('');
    console.log('🛑 서버 종료: Ctrl + C');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
});

// 에러 핸들링
app.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`❌ 포트 ${PORT}이(가) 이미 사용 중입니다.`);
        console.error('   다른 프로그램을 종료하거나 다른 포트를 사용하세요.');
    } else {
        console.error('❌ 서버 오류:', err.message);
    }
    process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🛑 서버를 종료합니다...');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    process.exit(0);
});





