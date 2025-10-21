/* =========================================== */
/* FIREBASE CONFIGURATION - Firebase 설정 */
/* =========================================== */

/**
 * Firebase 프로젝트 설정
 * 
 * 🔧 설정 방법:
 * 1. https://console.firebase.google.com/ 접속
 * 2. 새 프로젝트 생성 또는 기존 프로젝트 선택
 * 3. 프로젝트 설정 > 일반 > "웹 앱에 Firebase 추가" 클릭
 * 4. 앱 등록 후 표시되는 구성 객체를 아래에 복사
 * 5. Authentication > Sign-in method에서 다음 활성화:
 *    - 이메일/비밀번호
 *    - Google
 */

const firebaseConfig = {
    apiKey: "AIzaSyAJ1x-P0FDq2oJrogKypZ2lU66pF8zTrDY",
    authDomain: "housewebproject.firebaseapp.com",
    projectId: "housewebproject",
    storageBucket: "housewebproject.appspot.com", // .firebasestorage.app → .appspot.com
    messagingSenderId: "402958233297",
    appId: "1:402958233297:web:11d3be04889a5017b61ff0",
    measurementId: "G-EJNWCVZ416"
};

/**
 * Firebase 초기화
 */
let app;
let auth;
let db;

try {
    // Firebase 앱 초기화
    if (typeof firebase !== 'undefined') {
        app = firebase.initializeApp(firebaseConfig);
        auth = firebase.auth();
        
        // Firestore 초기화 (있으면)
        if (firebase.firestore) {
            db = firebase.firestore();
            console.log('✅ Firebase 초기화 성공 (Auth + Firestore)');
        } else {
            console.log('✅ Firebase 초기화 성공 (Auth만)');
        }
    } else {
        console.error('❌ Firebase SDK가 로드되지 않았습니다.');
    }
} catch (error) {
    console.error('❌ Firebase 초기화 실패:', error);
}

/* =========================================== */
/* FIREBASE 설정 가이드 */
/* =========================================== */

/**
 * 📝 Firebase 프로젝트 설정 단계별 가이드
 * 
 * 1단계: Firebase 프로젝트 생성
 *    → https://console.firebase.google.com/
 *    → "프로젝트 추가" 클릭
 *    → 프로젝트 이름 입력 (예: "HouseMVP")
 * 
 * 2단계: 웹 앱 등록
 *    → 프로젝트 개요 > 웹 앱 추가 (</> 아이콘)
 *    → 앱 닉네임 입력
 *    → "Firebase Hosting도 설정합니다" 체크 (선택사항)
 * 
 * 3단계: 구성 정보 복사
 *    → firebaseConfig 객체 전체를 복사
 *    → 위의 firebaseConfig 변수에 붙여넣기
 * 
 * 4단계: Authentication 활성화
 *    → 좌측 메뉴 > Authentication > 시작하기
 *    → Sign-in method 탭
 *    → "이메일/비밀번호" 활성화
 *    → "Google" 활성화 (프로젝트 지원 이메일 입력)
 * 
 * 5단계: 도메인 승인
 *    → Authentication > Settings > 승인된 도메인
 *    → localhost (자동 추가됨)
 *    → GitHub Pages 도메인 추가 (예: username.github.io)
 * 
 * 6단계: 테스트
 *    → 웹 페이지 새로고침
 *    → 콘솔에서 "✅ Firebase 초기화 성공" 확인
 */

