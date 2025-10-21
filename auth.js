/* =========================================== */
/* FIREBASE AUTHENTICATION - Firebase 인증 관리 */
/* =========================================== */

// 현재 로그인한 사용자
let currentUser = null;

/* =========================================== */
/* 1. 인증 상태 변경 감지 */
/* =========================================== */

/**
 * 인증 상태 변경 리스너
 */
if (typeof firebase !== 'undefined' && firebase.auth) {
    firebase.auth().onAuthStateChanged((user) => {
        console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('🔐 인증 상태 변경 감지');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        if (user) {
            // 로그인됨
            currentUser = user;
            console.log('✅ 사용자 로그인됨:');
            console.log('   📧 이메일:', user.email);
            console.log('   🆔 UID:', user.uid);
            console.log('   👤 이름:', user.displayName || '미설정');
            console.log('   📸 프로필 사진:', user.photoURL || '없음');
            
            updateUIForLoggedInUser(user);
        } else {
            // 로그아웃됨
            currentUser = null;
            console.log('❌ 사용자 로그아웃됨');
            
            updateUIForLoggedOutUser();
        }
        
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
}

/* =========================================== */
/* 2. 회원가입 기능 */
/* =========================================== */

/**
 * 이메일/비밀번호 회원가입
 */
async function signupWithEmail(email, password, name) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📝 [회원가입] 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('   📧 이메일:', email);
    console.log('   👤 이름:', name || '미입력');
    
    try {
        // Firebase 회원가입
        const userCredential = await firebase.auth().createUserWithEmailAndPassword(email, password);
        const user = userCredential.user;
        
        console.log('✅ Firebase 회원가입 성공!');
        console.log('   🆔 생성된 UID:', user.uid);
        
        // 사용자 프로필 업데이트 (이름 설정)
        if (name) {
            await user.updateProfile({
                displayName: name
            });
            console.log('✅ 사용자 이름 설정 완료:', name);
        }
        
        // 이메일 인증 발송
        await user.sendEmailVerification();
        console.log('📧 인증 이메일 발송 완료');
        
        alert(`✅ 회원가입 성공!\n\n${email}로 인증 이메일이 발송되었습니다.\n이메일을 확인하고 인증을 완료해주세요.`);
        
        // 회원가입 모달 닫기
        closeSignupModal();
        
        return user;
        
    } catch (error) {
        console.error('❌ 회원가입 실패:', error.code, error.message);
        
        // 에러 메시지 한글화
        let errorMessage = '회원가입 중 오류가 발생했습니다.';
        
        switch (error.code) {
            case 'auth/email-already-in-use':
                errorMessage = '이미 사용 중인 이메일입니다.';
                break;
            case 'auth/invalid-email':
                errorMessage = '유효하지 않은 이메일 형식입니다.';
                break;
            case 'auth/weak-password':
                errorMessage = '비밀번호가 너무 약합니다. (최소 6자 이상)';
                break;
            case 'auth/operation-not-allowed':
                errorMessage = '이메일/비밀번호 인증이 비활성화되어 있습니다.';
                break;
            case 'auth/configuration-not-found':
                errorMessage = 'Firebase Authentication이 활성화되지 않았습니다.\n\nFirebase Console에서:\n1. Authentication > 시작하기 클릭\n2. Sign-in method > 이메일/비밀번호 활성화';
                break;
        }
        
        alert('❌ ' + errorMessage);
        throw error;
    }
}

/* =========================================== */
/* 3. 로그인 기능 */
/* =========================================== */

/**
 * 이메일/비밀번호 로그인
 */
async function loginWithEmail(email, password) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔐 [로그인] 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('   📧 이메일:', email);
    
    try {
        const userCredential = await firebase.auth().signInWithEmailAndPassword(email, password);
        const user = userCredential.user;
        
        console.log('✅ 로그인 성공!');
        console.log('   🆔 UID:', user.uid);
        console.log('   👤 이름:', user.displayName || '미설정');
        console.log('   ✉️ 이메일 인증:', user.emailVerified ? '완료' : '미완료');
        
        alert(`✅ 로그인 성공!\n\n환영합니다, ${user.displayName || user.email}님!`);
        
        // 로그인 모달 닫기
        closeLoginModal();
        
        return user;
        
    } catch (error) {
        console.error('❌ 로그인 실패:', error.code, error.message);
        
        // 에러 메시지 한글화
        let errorMessage = '로그인 중 오류가 발생했습니다.';
        
        switch (error.code) {
            case 'auth/user-not-found':
                errorMessage = '등록되지 않은 이메일입니다.';
                break;
            case 'auth/wrong-password':
                errorMessage = '비밀번호가 올바르지 않습니다.';
                break;
            case 'auth/invalid-email':
                errorMessage = '유효하지 않은 이메일 형식입니다.';
                break;
            case 'auth/user-disabled':
                errorMessage = '비활성화된 계정입니다.';
                break;
            case 'auth/too-many-requests':
                errorMessage = '너무 많은 로그인 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
                break;
        }
        
        alert('❌ ' + errorMessage);
        throw error;
    }
}

/**
 * 비밀번호 재설정 이메일 발송
 */
async function resetPassword(email) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔐 [비밀번호 재설정] 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('   📧 이메일:', email);
    
    try {
        await firebase.auth().sendPasswordResetEmail(email);
        
        console.log('✅ 비밀번호 재설정 이메일 발송 성공!');
        console.log('   📬 이메일을 확인해주세요:', email);
        console.log('   ⚠️ 스팸 메일함도 확인하세요!');
        
        alert(`✅ 비밀번호 재설정 이메일이 발송되었습니다!\n\n${email}\n\n메일함을 확인해주세요.\n(스팸 메일함도 확인하세요)`);
        return true;
        
    } catch (error) {
        console.error('❌ 비밀번호 재설정 실패:', error.code, error.message);
        
        let errorMessage = '비밀번호 재설정에 실패했습니다.';
        
        switch (error.code) {
            case 'auth/user-not-found':
                errorMessage = '등록되지 않은 이메일입니다.';
                break;
            case 'auth/invalid-email':
                errorMessage = '유효하지 않은 이메일 형식입니다.';
                break;
            case 'auth/too-many-requests':
                errorMessage = '너무 많은 요청이 있었습니다. 잠시 후 다시 시도해주세요.';
                break;
        }
        
        alert('❌ ' + errorMessage);
        throw error;
    }
}

/**
 * Google 소셜 로그인
 */
async function loginWithGoogle() {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔐 [Google 로그인] 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    try {
        const provider = new firebase.auth.GoogleAuthProvider();
        
        // 한국어로 설정
        provider.setCustomParameters({
            'locale': 'ko'
        });
        
        console.log('   🔑 Google 인증 제공자 생성 완료');
        console.log('   🚀 Google 로그인 팝업 열기 시도...');
        
        const result = await firebase.auth().signInWithPopup(provider);
        const user = result.user;
        
        console.log('✅ Google 로그인 성공!');
        console.log('   🆔 UID:', user.uid);
        console.log('   📧 이메일:', user.email);
        console.log('   👤 이름:', user.displayName);
        console.log('   📸 프로필 사진:', user.photoURL);
        
        alert(`✅ Google 로그인 성공!\n\n환영합니다, ${user.displayName}님!`);
        
        // 로그인 모달 닫기
        closeLoginModal();
        
        return user;
        
    } catch (error) {
        console.error('❌ Google 로그인 실패:', error.code, error.message);
        
        // 에러 메시지 한글화
        let errorMessage = 'Google 로그인 중 오류가 발생했습니다.';
        
        switch (error.code) {
            case 'auth/popup-closed-by-user':
                errorMessage = '로그인 팝업이 닫혔습니다.';
                break;
            case 'auth/cancelled-popup-request':
                errorMessage = '이미 로그인 팝업이 열려 있습니다.';
                break;
            case 'auth/popup-blocked':
                errorMessage = '팝업이 차단되었습니다. 팝업 차단을 해제해주세요.';
                break;
            case 'auth/unauthorized-domain':
                errorMessage = '승인되지 않은 도메인입니다. Firebase 콘솔에서 도메인을 추가해주세요.';
                break;
        }
        
        if (error.code !== 'auth/popup-closed-by-user') {
            alert('❌ ' + errorMessage);
        }
        
        throw error;
    }
}

/* =========================================== */
/* 4. 로그아웃 기능 */
/* =========================================== */

/**
 * 로그아웃
 */
async function logout() {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🚪 [로그아웃] 시작');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    try {
        await firebase.auth().signOut();
        console.log('✅ 로그아웃 성공!');
        alert('✅ 로그아웃되었습니다.');
        
    } catch (error) {
        console.error('❌ 로그아웃 실패:', error);
        alert('❌ 로그아웃 중 오류가 발생했습니다.');
    }
}

/* =========================================== */
/* 5. UI 업데이트 함수 */
/* =========================================== */

/**
 * 로그인된 사용자를 위한 UI 업데이트
 */
function updateUIForLoggedInUser(user) {
    console.log('🎨 UI 업데이트: 로그인 상태');
    
    // 헤더의 로그인/회원가입 버튼을 사용자 정보로 교체
    const authLinks = document.querySelector('.auth-links');
    
    if (authLinks) {
        const displayName = user.displayName || user.email.split('@')[0];
        const photoURL = user.photoURL;
        
        // 프로필 사진이 있는 경우만 표시
        const avatarHTML = photoURL 
            ? `<img src="${photoURL}" alt="프로필" class="user-avatar" onerror="this.style.display='none'">` 
            : `<div class="user-avatar-placeholder">👤</div>`;
        
        authLinks.innerHTML = `
            <button class="proposals-btn" onclick="goToMyProposals()" title="내 제안서 보기">📊 내 제안서</button>
            <div class="user-info">
                ${avatarHTML}
                <span class="user-name">${displayName}</span>
                <button class="logout-btn" onclick="logout()">로그아웃</button>
            </div>
        `;
        
        console.log('   ✅ 헤더 업데이트 완료');
    }
}

/**
 * 로그아웃된 상태를 위한 UI 업데이트
 */
function updateUIForLoggedOutUser() {
    console.log('🎨 UI 업데이트: 로그아웃 상태');
    
    const authLinks = document.querySelector('.auth-links');
    
    if (authLinks) {
        authLinks.innerHTML = `
            <button class="login-btn" onclick="openLoginModal()">로그인</button>
            <button class="signup-btn" onclick="openSignupModal()">회원가입</button>
            <button class="admin-btn" onclick="openLoginModal()" title="관리자 로그인">⚙️</button>
        `;
        
        console.log('   ✅ 헤더 업데이트 완료');
    }
}

/* =========================================== */
/* 6. 폼 제출 핸들러 */
/* =========================================== */

/**
 * 로그인 폼 초기화
 */
function initLoginForm() {
    const loginForm = document.querySelector('#loginModal .login-form, #loginModal form');
    
    console.log('🔍 로그인 폼 찾기 시도...');
    console.log('   - loginForm:', loginForm ? '✓ 찾음' : '✗ 없음');
    
    if (loginForm) {
        loginForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            console.log('📝 로그인 폼 제출 이벤트 발생');
            
            const loginIdInput = document.getElementById('loginId');
            const passwordInput = document.getElementById('loginPassword');
            
            console.log('   - loginId input:', loginIdInput ? '✓ 찾음' : '✗ 없음');
            console.log('   - password input:', passwordInput ? '✓ 찾음' : '✗ 없음');
            
            if (!loginIdInput || !passwordInput) {
                console.error('❌ 로그인 폼 요소를 찾을 수 없습니다');
                alert('로그인 폼 오류가 발생했습니다. 페이지를 새로고침해주세요.');
                return;
            }
            
            const loginId = loginIdInput.value.trim();
            const password = passwordInput.value.trim();
            
            if (!loginId || !password) {
                alert('이메일과 비밀번호를 입력해주세요.');
                return;
            }
            
            // 관리자 로그인 체크
            if (loginId === 'admin' && password === 'admin') {
                localStorage.setItem('adminAuth', 'true');
                localStorage.setItem('adminUser', JSON.stringify({
                    id: 'admin',
                    name: '관리자',
                    loginTime: new Date().toISOString()
                }));
                alert('관리자 로그인 성공! 관리자 대시보드로 이동합니다.');
                closeLoginModal();
                window.location.href = 'admin.html';
                return;
            }
            
            // 로그인 버튼 비활성화
            const submitBtn = loginForm.querySelector('button[type="submit"]');
            const originalText = submitBtn.textContent;
            submitBtn.textContent = '로그인 중...';
            submitBtn.disabled = true;
            
            try {
                await loginWithEmail(loginId, password);
                // 성공 시 폼 초기화
                loginForm.reset();
            } catch (error) {
                // 에러는 loginWithEmail에서 처리됨
            } finally {
                // 버튼 복구
                submitBtn.textContent = originalText;
                submitBtn.disabled = false;
            }
        });
        
        console.log('✅ 로그인 폼 이벤트 리스너 등록 완료');
    }
}

/**
 * 회원가입 폼 초기화
 */
function initSignupForm() {
    const signupForm = document.querySelector('#signupModal .signup-form, #signupModal form');
    
    if (signupForm) {
        signupForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const name = signupForm.querySelector('input[type="text"]').value;
            const email = signupForm.querySelector('input[type="email"]').value;
            const passwords = signupForm.querySelectorAll('input[type="password"]');
            const password = passwords[0].value;
            const passwordConfirm = passwords[1].value;
            
            // 유효성 검사
            if (!email || !password || !passwordConfirm) {
                alert('모든 필드를 입력해주세요.');
                return;
            }
            
            if (password !== passwordConfirm) {
                alert('비밀번호가 일치하지 않습니다.');
                return;
            }
            
            if (password.length < 6) {
                alert('비밀번호는 최소 6자 이상이어야 합니다.');
                return;
            }
            
            // 회원가입 버튼 비활성화
            const submitBtn = signupForm.querySelector('button[type="submit"]');
            const originalText = submitBtn.textContent;
            submitBtn.textContent = '가입 중...';
            submitBtn.disabled = true;
            
            try {
                await signupWithEmail(email, password, name);
                // 성공 시 폼 초기화
                signupForm.reset();
            } catch (error) {
                // 에러는 signupWithEmail에서 처리됨
            } finally {
                // 버튼 복구
                submitBtn.textContent = originalText;
                submitBtn.disabled = false;
            }
        });
        
        console.log('✅ 회원가입 폼 이벤트 리스너 등록 완료');
    }
}

/* =========================================== */
/* 7. 페이지 로드 시 초기화 */
/* =========================================== */

document.addEventListener('DOMContentLoaded', function() {
    console.log('🔐 Firebase 인증 시스템 초기화 중...');
    
    // Firebase가 로드되었는지 확인
    if (typeof firebase === 'undefined') {
        console.error('❌ Firebase SDK가 로드되지 않았습니다!');
        console.log('   💡 index.html에 Firebase SDK를 추가했는지 확인하세요.');
        return;
    }
    
    if (!firebase.auth) {
        console.error('❌ Firebase Auth가 로드되지 않았습니다!');
        return;
    }
    
    console.log('✅ Firebase SDK 로드 확인 완료');
    
    // 폼 이벤트 리스너 등록
    initLoginForm();
    initSignupForm();
    
    console.log('✅ Firebase 인증 시스템 초기화 완료\n');
});

/* =========================================== */
/* 8. 유틸리티 함수 */
/* =========================================== */

/**
 * 현재 사용자 가져오기
 */
function getCurrentUser() {
    return currentUser;
}

/**
 * 로그인 여부 확인
 */
function isLoggedIn() {
    return currentUser !== null;
}

/**
 * 이메일 인증 여부 확인
 */
function isEmailVerified() {
    return currentUser && currentUser.emailVerified;
}

/**
 * 비밀번호 재설정 이메일 발송
 */
async function sendPasswordResetEmail(email) {
    console.log('📧 비밀번호 재설정 이메일 발송:', email);
    
    try {
        await firebase.auth().sendPasswordResetEmail(email);
        console.log('✅ 재설정 이메일 발송 완료');
        alert(`✅ 비밀번호 재설정 이메일이 ${email}로 발송되었습니다.`);
    } catch (error) {
        console.error('❌ 이메일 발송 실패:', error);
        alert('❌ 이메일 발송에 실패했습니다. 이메일을 확인해주세요.');
    }
}

/* =========================================== */
/* 9. FIRESTORE 연동 - 즐겨찾기/저장 기능 */
/* =========================================== */

/**
 * Firestore에 즐겨찾기 주소 저장
 * @param {Object} addressData - 주소 정보
 */
async function saveFavoriteToFirestore(addressData) {
    if (!currentUser) {
        console.warn('⚠️ 로그인이 필요합니다.');
        alert('⚠️ 즐겨찾기는 로그인 후 사용 가능합니다.');
        return false;
    }
    
    if (!db) {
        console.warn('⚠️ Firestore가 초기화되지 않았습니다. localStorage 사용');
        return false;
    }
    
    try {
        console.log('💾 Firestore에 즐겨찾기 저장 중...');
        
        await db.collection('users').doc(currentUser.uid).collection('favorites').add({
            roadAddr: addressData.roadAddr,
            jibunAddr: addressData.jibunAddr,
            zipNo: addressData.zipNo,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            userId: currentUser.uid,
            userEmail: currentUser.email
        });
        
        console.log('✅ Firestore 저장 성공!');
        return true;
        
    } catch (error) {
        console.error('❌ Firestore 저장 실패:', error);
        return false;
    }
}

/**
 * Firestore에서 즐겨찾기 주소 불러오기
 * @returns {Array} 즐겨찾기 배열
 */
async function loadFavoritesFromFirestore() {
    if (!currentUser || !db) {
        return [];
    }
    
    try {
        console.log('📥 Firestore에서 즐겨찾기 불러오기...');
        
        const snapshot = await db.collection('users')
            .doc(currentUser.uid)
            .collection('favorites')
            .orderBy('createdAt', 'desc')
            .limit(20)
            .get();
        
        const favorites = [];
        snapshot.forEach(doc => {
            favorites.push({
                id: doc.id,
                ...doc.data()
            });
        });
        
        console.log(`✅ Firestore에서 ${favorites.length}개 불러옴`);
        return favorites;
        
    } catch (error) {
        console.error('❌ Firestore 불러오기 실패:', error);
        return [];
    }
}

/**
 * Firestore에 저장된 중개사 저장
 * @param {Object} brokerData - 중개사 정보
 */
async function saveBrokerToFirestore(brokerData) {
    if (!currentUser) {
        console.warn('⚠️ 로그인이 필요합니다.');
        alert('⚠️ 중개사 저장은 로그인 후 사용 가능합니다.');
        return false;
    }
    
    if (!db) {
        console.warn('⚠️ Firestore가 초기화되지 않았습니다. localStorage 사용');
        return false;
    }
    
    try {
        console.log('💾 Firestore에 중개사 저장 중...');
        
        await db.collection('users').doc(currentUser.uid).collection('savedBrokers').add({
            ...brokerData,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            userId: currentUser.uid,
            userEmail: currentUser.email
        });
        
        console.log('✅ Firestore 저장 성공!');
        return true;
        
    } catch (error) {
        console.error('❌ Firestore 저장 실패:', error);
        return false;
    }
}

