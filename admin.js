/* =========================================== */
/* ADMIN DASHBOARD - 관리자 대시보드 JavaScript */
/* 빈 대시보드 버전 */
/* =========================================== */

// 관리자 인증 상태 확인
let isAdminAuthenticated = false;

document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ 관리자 대시보드 로드 완료');
    
    // 관리자 인증 상태 확인
    checkAdminAuth();
    
    // 견적문의 데이터 로드
    loadQuoteRequests();
    
    // 제안서 데이터 로드
    loadProposals();
});

/**
 * 관리자 인증 상태 확인
 */
function checkAdminAuth() {
    const adminAuth = localStorage.getItem('adminAuth');
    const adminUser = localStorage.getItem('adminUser');
    
    if (adminAuth === 'true' && adminUser) {
        isAdminAuthenticated = true;
        console.log('✅ 관리자 인증됨');
        updateAdminUI();
    } else {
        console.log('❌ 관리자 인증되지 않음');
        // 인증되지 않은 경우 로그인 페이지로 리다이렉트
        alert('관리자 권한이 필요합니다.\n\n관리자 로그인: ID: admin, 비밀번호: admin');
        window.location.href = 'index.html';
    }
}

/**
 * 관리자 UI 업데이트
 */
function updateAdminUI() {
    const adminUser = localStorage.getItem('adminUser');
    if (adminUser) {
        const userData = JSON.parse(adminUser);
        document.getElementById('adminUserName').textContent = userData.name || '관리자';
    }
}

/**
 * 관리자 로그아웃
 */
function logoutAdmin() {
    if (confirm('정말 로그아웃하시겠습니까?')) {
        localStorage.removeItem('adminAuth');
        localStorage.removeItem('adminUser');
        isAdminAuthenticated = false;
        
        alert('관리자 로그아웃되었습니다.');
        window.location.href = 'index.html';
    }
}

/**
 * 견적문의 데이터 로드
 */
async function loadQuoteRequests() {
    try {
        const db = firebase.firestore();
        const quoteRequestsRef = db.collection('quoteRequests');
        
        // 실시간 리스너 등록
        quoteRequestsRef.orderBy('timestamp', 'desc').onSnapshot((snapshot) => {
            const quoteRequests = [];
            let totalCount = 0;
            let pendingCount = 0;
            let completedCount = 0;
            let todayCount = 0;
            
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            snapshot.forEach((doc) => {
                const data = doc.data();
                const requestData = {
                    id: doc.id,
                    ...data
                };
                quoteRequests.push(requestData);
                
                // 통계 계산
                totalCount++;
                if (data.status === 'pending') pendingCount++;
                if (data.status === 'completed') completedCount++;
                
                // 오늘 문의 수 계산
                const requestDate = data.timestamp ? data.timestamp.toDate() : new Date(data.requestDate);
                if (requestDate >= today) {
                    todayCount++;
                }
            });
            
            // 통계 업데이트
            updateQuoteStats(totalCount, pendingCount, completedCount, todayCount);
            
            // 견적문의 목록 표시
            displayQuoteRequests(quoteRequests);
            
            console.log('✅ 견적문의 데이터 로드 완료:', quoteRequests.length, '건');
        });
        
    } catch (error) {
        console.error('❌ 견적문의 데이터 로드 실패:', error);
        showError('견적문의 데이터를 불러오는 중 오류가 발생했습니다.');
    }
}

/**
 * 견적문의 통계 업데이트
 */
function updateQuoteStats(total, pending, completed, today) {
    document.getElementById('totalQuoteRequests').textContent = total.toLocaleString();
    document.getElementById('pendingRequests').textContent = pending.toLocaleString();
    document.getElementById('completedRequests').textContent = completed.toLocaleString();
    document.getElementById('todayRequests').textContent = today.toLocaleString();
}

/**
 * 견적문의 목록 표시
 */
function displayQuoteRequests(quoteRequests) {
    const container = document.getElementById('quoteRequestsList');
    
    if (quoteRequests.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div style="text-align: center; padding: 40px; color: #666;">
                    <div style="font-size: 3rem; margin-bottom: 15px;">💬</div>
                    <h3>견적문의가 없습니다</h3>
                    <p>아직 견적문의가 접수되지 않았습니다.</p>
                </div>
            </div>
        `;
        return;
    }
    
    container.innerHTML = quoteRequests.map(request => `
        <div class="quote-request-card">
            <div class="quote-request-header">
                <h3 class="quote-request-title">${request.brokerName} 견적문의</h3>
                <span class="quote-status status-${request.status}">${getStatusText(request.status)}</span>
            </div>
            
            <div class="quote-request-content">
                <div class="quote-info-group">
                    <div class="quote-info-label">👤 사용자</div>
                    <div class="quote-info-value">${request.userName} (${request.userEmail})</div>
                </div>
                
                <div class="quote-info-group">
                    <div class="quote-info-label">📅 문의일시</div>
                    <div class="quote-info-value">${formatDateTime(request.timestamp || request.requestDate)}</div>
                </div>
                
                <div class="quote-info-group">
                    <div class="quote-info-label">🏢 중개사명</div>
                    <div class="quote-info-value">${request.brokerName}</div>
                </div>
                
                ${request.brokerEmail ? `
                <div class="quote-info-group">
                    <div class="quote-info-label">📧 중개사 이메일</div>
                    <div class="quote-info-value" style="color: #059669; font-weight: 600;">
                        ${request.brokerEmail}
                        <span style="color: #666; font-size: 0.8rem; margin-left: 8px;">
                            (첨부됨)
                        </span>
                    </div>
                </div>
                ` : ''}
                
                <div class="quote-info-group">
                    <div class="quote-info-label">📋 상태</div>
                    <div class="quote-info-value">${getStatusText(request.status)}</div>
                </div>
                
                <div class="quote-message">
                    <div class="quote-info-label">💬 문의내용</div>
                    <div style="margin-top: 8px;">${request.message}</div>
                </div>
            </div>
            
            <div class="quote-request-actions">
                ${request.status === 'pending' ? `
                    <button class="action-button btn-contact" onclick="updateQuoteStatus('${request.id}', 'contacted')">
                        연락완료
                    </button>
                ` : ''}
                
                ${request.status === 'contacted' ? `
                    <button class="action-button btn-complete" onclick="updateQuoteStatus('${request.id}', 'completed')">
                        완료처리
                    </button>
                ` : ''}
                
                ${request.status !== 'cancelled' && request.status !== 'completed' ? `
                    <button class="action-button btn-cancel" onclick="updateQuoteStatus('${request.id}', 'cancelled')">
                        취소
                    </button>
                ` : ''}
                
                <button class="action-button btn-email" onclick="attachEmailToBroker('${request.id}')">
                    📧 이메일 첨부
                </button>
                
                <button class="action-button btn-proposal" onclick="createProposal('${request.id}')">
                    📝 제안서 작성
                </button>
            </div>
        </div>
    `).join('');
}

/**
 * 견적문의 상태 업데이트
 */
async function updateQuoteStatus(requestId, newStatus) {
    try {
        const db = firebase.firestore();
        await db.collection('quoteRequests').doc(requestId).update({
            status: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ 견적문의 상태 업데이트 완료: ${requestId} -> ${newStatus}`);
        
    } catch (error) {
        console.error('❌ 견적문의 상태 업데이트 실패:', error);
        alert('상태 업데이트 중 오류가 발생했습니다.');
    }
}

/**
 * 견적문의 새로고침
 */
function refreshQuoteRequests() {
    loadQuoteRequests();
}

/**
 * 상태 텍스트 변환
 */
function getStatusText(status) {
    const statusMap = {
        'pending': '대기중',
        'contacted': '연락완료',
        'completed': '완료',
        'cancelled': '취소됨'
    };
    return statusMap[status] || status;
}

/**
 * 날짜 시간 포맷팅
 */
function formatDateTime(date) {
    if (!date) return '-';
    
    const d = date.toDate ? date.toDate() : new Date(date);
    return d.toLocaleString('ko-KR', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

/**
 * 공인중개사에게 이메일 첨부
 */
async function attachEmailToBroker(requestId) {
    try {
        // 견적문의 정보 가져오기
        const db = firebase.firestore();
        const requestDoc = await db.collection('quoteRequests').doc(requestId).get();
        
        if (!requestDoc.exists) {
            alert('견적문의 정보를 찾을 수 없습니다.');
            return;
        }
        
        const requestData = requestDoc.data();
        const brokerName = requestData.brokerName;
        
        // 이메일 입력 받기
        const email = prompt(`${brokerName}의 이메일 주소를 입력해주세요:`, '');
        
        if (!email) {
            return; // 취소된 경우
        }
        
        // 이메일 형식 검증
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            alert('올바른 이메일 형식을 입력해주세요.');
            return;
        }
        
        // 확인 메시지
        const confirmMessage = `다음 정보로 이메일을 첨부하시겠습니까?\n\n` +
                              `중개사명: ${brokerName}\n` +
                              `이메일: ${email}\n` +
                              `사용자: ${requestData.userName} (${requestData.userEmail})\n` +
                              `문의내용: ${requestData.message}`;
        
        if (!confirm(confirmMessage)) {
            return;
        }
        
        // 이메일 정보를 견적문의 데이터에 추가
        await db.collection('quoteRequests').doc(requestId).update({
            brokerEmail: email,
            emailAttachedAt: firebase.firestore.FieldValue.serverTimestamp(),
            emailAttachedBy: 'admin',
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        
        // 성공 메시지
        alert(`✅ 이메일 첨부 완료!\n\n중개사: ${brokerName}\n이메일: ${email}\n\n이메일 정보가 데이터베이스에 저장되었습니다.`);
        
        console.log('✅ 이메일 첨부 완료:', {
            requestId: requestId,
            brokerName: brokerName,
            email: email,
            userEmail: requestData.userEmail,
            userName: requestData.userName
        });
        
    } catch (error) {
        console.error('❌ 이메일 첨부 실패:', error);
        alert('이메일 첨부 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
}

/**
 * 제안서 작성 페이지로 이동
 */
function createProposal(requestId) {
    window.location.href = `proposal.html?id=${requestId}`;
}

/**
 * 메인 페이지로 이동 (로고 클릭 시)
 */
function goToMainPage() {
    window.location.href = 'index.html';
}

/* =========================================== */
/* 제안서 관리 */
/* =========================================== */

/**
 * 제안서 목록 로드
 */
async function loadProposals() {
    try {
        const db = firebase.firestore();
        const proposalsRef = db.collection('proposals');
        
        proposalsRef.where('status', '!=', 'draft')
            .orderBy('status')
            .orderBy('createdAt', 'desc')
            .onSnapshot((snapshot) => {
                const proposals = [];
                
                snapshot.forEach((doc) => {
                    proposals.push({
                        id: doc.id,
                        ...doc.data()
                    });
                });
                
                displayProposals(proposals);
                console.log('✅ 제안서 데이터 로드 완료:', proposals.length, '건');
            });
            
    } catch (error) {
        console.error('❌ 제안서 데이터 로드 실패:', error);
    }
}

/**
 * 제안서 목록 표시
 */
function displayProposals(proposals) {
    const container = document.getElementById('proposalsList');
    
    if (proposals.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div style="text-align: center; padding: 40px; color: #666;">
                    <div style="font-size: 3rem; margin-bottom: 15px;">📝</div>
                    <h3>제출된 제안서가 없습니다</h3>
                    <p>중개사가 제안서를 작성하면 여기에 표시됩니다.</p>
                </div>
            </div>
        `;
        return;
    }
    
    container.innerHTML = proposals.map(proposal => {
        const pricing = proposal.pricing || {};
        const timeline = proposal.timeline || [];
        const maxDay = timeline.length > 0 ? Math.max(...timeline.map(t => t.day)) : 0;
        const status = proposal.proposalStatus || proposal.status;
        
        return `
            <div class="quote-request-card" style="border-left: 4px solid #8b5cf6;">
                <div class="quote-request-header">
                    <h3 class="quote-request-title">${proposal.brokerName} 제안서</h3>
                    <span class="quote-status status-${status}">${getProposalStatusText(status)}</span>
                </div>
                
                <div class="quote-request-content">
                    <div class="quote-info-group">
                        <div class="quote-info-label">👤 의뢰인</div>
                        <div class="quote-info-value">${proposal.customerName}</div>
                    </div>
                    
                    <div class="quote-info-group">
                        <div class="quote-info-label">💰 희망 판매가</div>
                        <div class="quote-info-value">${(pricing.suggestedPrice || 0).toLocaleString()}만원</div>
                    </div>
                    
                    <div class="quote-info-group">
                        <div class="quote-info-label">💳 수수료</div>
                        <div class="quote-info-value">${pricing.commissionRate || 0}% (${(pricing.commissionAmount || 0).toLocaleString()}만원)</div>
                    </div>
                    
                    <div class="quote-info-group">
                        <div class="quote-info-label">⏱️ 예상기간</div>
                        <div class="quote-info-value">${maxDay}일</div>
                    </div>
                </div>
                
                <div class="quote-request-actions">
                    ${status === 'selected' && !proposal.propertyRegistered ? `
                        <button class="action-button btn-complete" onclick="registerProperty('${proposal.id}')">
                            🏡 매물 등록
                        </button>
                    ` : ''}
                    ${proposal.propertyRegistered ? `
                        <span style="color: #10b981; font-weight: 600;">✓ 매물 등록 완료</span>
                    ` : ''}
                </div>
            </div>
        `;
    }).join('');
}

/**
 * 제안서 상태 텍스트
 */
function getProposalStatusText(status) {
    const statusTexts = {
        'submitted': '제출됨',
        'selected': '✓ 선정됨',
        'rejected': '거절됨',
        'ready': '준비중',
        'reviewing': '검토중'
    };
    return statusTexts[status] || status;
}

/**
 * 매물 등록 페이지로 이동
 */
function registerProperty(proposalId) {
    window.location.href = `property-register.html?id=${proposalId}`;
}

/**
 * 제안서 새로고침
 */
function refreshProposals() {
    loadProposals();
}

console.log('✅ 관리자 대시보드 JavaScript 로드 완료');
