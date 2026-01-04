/* =========================================== */
/* PROPOSALS LIST - 제안서 목록 페이지 JavaScript */
/* =========================================== */

// 전역 변수
let allProposals = [];
let currentUser = null;

/* =========================================== */
/* 1. 페이지 초기화 */
/* =========================================== */

document.addEventListener('DOMContentLoaded', async function() {
    console.log('📊 제안서 목록 페이지 초기화 시작');
    
    // 로그인 체크
    if (!firebase.auth) {
        console.error('Firebase Auth가 로드되지 않았습니다');
        alert('시스템 오류가 발생했습니다.');
        return;
    }
    
    firebase.auth().onAuthStateChanged(async (user) => {
        if (user) {
            currentUser = user;
            document.getElementById('userName').textContent = user.displayName || user.email.split('@')[0];
            
            // 제안서 로드
            await loadProposals();
        } else {
            alert('로그인이 필요합니다.');
            window.location.href = 'index.html';
        }
    });
    
    console.log('✅ 제안서 목록 페이지 초기화 완료');
});

/* =========================================== */
/* 2. 제안서 데이터 로드 */
/* =========================================== */

async function loadProposals() {
    try {
        console.log('📥 제안서 데이터 로드 중...');
        
        const db = firebase.firestore();
        
        // 현재 사용자의 제안서 가져오기
        const querySnapshot = await db.collection('proposals')
            .where('customerUserId', '==', currentUser.uid)
            .where('status', '!=', 'draft')
            .get();
        
        allProposals = [];
        querySnapshot.forEach((doc) => {
            allProposals.push({
                id: doc.id,
                ...doc.data()
            });
        });
        
        console.log('✅ 제안서 로드 완료:', allProposals.length, '건');
        
        // UI 업데이트
        updateStatistics();
        displayProposals();
        
    } catch (error) {
        console.error('❌ 제안서 로드 실패:', error);
        alert('제안서를 불러오는데 실패했습니다: ' + error.message);
    }
}

/* =========================================== */
/* 3. 통계 업데이트 */
/* =========================================== */

function updateStatistics() {
    const totalProposals = allProposals.length;
    
    if (totalProposals === 0) {
        document.getElementById('totalProposals').textContent = '0';
        document.getElementById('avgPrice').textContent = '0원';
        document.getElementById('avgCommission').textContent = '0%';
        document.getElementById('avgDuration').textContent = '0일';
        return;
    }
    
    // 평균 제안가
    const avgPrice = allProposals.reduce((sum, p) => sum + (p.pricing?.suggestedPrice || 0), 0) / totalProposals;
    
    // 평균 수수료
    const avgCommission = allProposals.reduce((sum, p) => sum + (p.pricing?.commissionRate || 0), 0) / totalProposals;
    
    // 평균 예상기간
    const avgDuration = allProposals.reduce((sum, p) => {
        const maxDay = Math.max(...(p.timeline?.map(t => t.day) || [0]));
        return sum + maxDay;
    }, 0) / totalProposals;
    
    document.getElementById('totalProposals').textContent = totalProposals;
    document.getElementById('avgPrice').textContent = (avgPrice / 10000).toFixed(0) + '억원';
    document.getElementById('avgCommission').textContent = avgCommission.toFixed(2) + '%';
    document.getElementById('avgDuration').textContent = Math.round(avgDuration) + '일';
}

/* =========================================== */
/* 4. 제안서 표시 */
/* =========================================== */

function displayProposals() {
    const grid = document.getElementById('proposalsGrid');
    const emptyState = document.getElementById('emptyState');
    
    if (allProposals.length === 0) {
        grid.style.display = 'none';
        emptyState.style.display = 'block';
        return;
    }
    
    grid.style.display = 'grid';
    emptyState.style.display = 'none';
    
    grid.innerHTML = allProposals.map(proposal => createProposalCard(proposal)).join('');
}

function createProposalCard(proposal) {
    const pricing = proposal.pricing || {};
    const timeline = proposal.timeline || [];
    const maxDay = timeline.length > 0 ? Math.max(...timeline.map(t => t.day)) : 0;
    
    const statusBadge = getStatusBadge(proposal.proposalStatus || proposal.status);
    const isSelected = proposal.proposalStatus === 'selected';
    
    return `
        <div class="proposal-card ${isSelected ? 'selected' : ''}" onclick="showProposalDetail('${proposal.id}')">
            <div class="proposal-header">
                <div class="broker-info">
                    <h3>${proposal.brokerName || '중개사'}</h3>
                    <div class="email">${proposal.brokerEmail || '-'}</div>
                </div>
                ${statusBadge}
            </div>
            
            <div class="price-info">
                <div class="price-row">
                    <span class="price-label">희망 판매가</span>
                    <span class="price-value highlight">${(pricing.suggestedPrice || 0).toLocaleString()}만원</span>
                </div>
                <div class="price-row">
                    <span class="price-label">최소 판매가</span>
                    <span class="price-value">${(pricing.minPrice || 0).toLocaleString()}만원</span>
                </div>
                <div class="price-row">
                    <span class="price-label">중개 수수료</span>
                    <span class="price-value">${pricing.commissionRate || 0}% (${(pricing.commissionAmount || 0).toLocaleString()}만원)</span>
                </div>
            </div>
            
            <div class="timeline-preview">
                <h4>📅 예상 일정 (${maxDay}일)</h4>
                ${timeline.slice(0, 3).map(item => `
                    <div class="timeline-item-preview">
                        <span class="timeline-day">${item.day}일차:</span>
                        <span class="timeline-task">${item.task}</span>
                    </div>
                `).join('')}
                ${timeline.length > 3 ? `<div style="color: #666; font-size: 0.85rem; margin-top: 5px;">외 ${timeline.length - 3}개 일정</div>` : ''}
            </div>
            
            <div class="proposal-actions" onclick="event.stopPropagation()">
                <button class="action-btn btn-detail" onclick="showProposalDetail('${proposal.id}')">상세보기</button>
                ${!isSelected ? `
                    <button class="action-btn btn-select" onclick="selectProposal('${proposal.id}')">선택</button>
                    <button class="action-btn btn-reject" onclick="rejectProposal('${proposal.id}')">거절</button>
                ` : ''}
            </div>
        </div>
    `;
}

function getStatusBadge(status) {
    const badges = {
        'submitted': '<span class="proposal-badge badge-submitted">제출됨</span>',
        'selected': '<span class="proposal-badge badge-selected">✓ 선정됨</span>',
        'rejected': '<span class="proposal-badge badge-rejected">거절됨</span>',
        'ready': '<span class="proposal-badge badge-submitted">준비중</span>',
        'reviewing': '<span class="proposal-badge badge-submitted">검토중</span>'
    };
    return badges[status] || '';
}

/* =========================================== */
/* 5. 제안서 상세보기 */
/* =========================================== */

function showProposalDetail(proposalId) {
    const proposal = allProposals.find(p => p.id === proposalId);
    if (!proposal) return;
    
    const pricing = proposal.pricing || {};
    const strategy = proposal.strategy || {};
    const timeline = proposal.timeline || [];
    const services = proposal.additionalServices || [];
    
    const detailHTML = `
        <h2>📝 ${proposal.brokerName} 제안서 상세</h2>
        
        <div class="detail-section">
            <h3>💰 가격 제안</h3>
            <p><strong>희망 판매가:</strong> ${(pricing.suggestedPrice || 0).toLocaleString()}만원</p>
            <p><strong>최소 판매가:</strong> ${(pricing.minPrice || 0).toLocaleString()}만원</p>
            <p><strong>중개 수수료:</strong> ${pricing.commissionRate || 0}% (${(pricing.commissionAmount || 0).toLocaleString()}만원)</p>
            ${pricing.commissionNotes ? `<p><strong>수수료 특이사항:</strong> ${pricing.commissionNotes}</p>` : ''}
        </div>
        
        <div class="detail-section">
            <h3>📅 실행 계획</h3>
            <div class="timeline-full">
                ${timeline.map(item => `
                    <div class="timeline-item-full">
                        <div class="day">${item.day}일차</div>
                        <div class="task">${item.task}</div>
                    </div>
                `).join('')}
            </div>
        </div>
        
        <div class="detail-section">
            <h3>🎯 판매 전략</h3>
            <p><strong>시장 분석:</strong></p>
            <p>${strategy.marketAnalysis || '-'}</p>
            <br>
            <p><strong>매물 강점:</strong></p>
            <p>${strategy.sellingPoints || '-'}</p>
            <br>
            <p><strong>마케팅 전략:</strong></p>
            <p>${strategy.marketingStrategy || '-'}</p>
            <br>
            <p><strong>협상 전략:</strong></p>
            <p>${strategy.negotiationStrategy || '-'}</p>
        </div>
        
        ${services.length > 0 ? `
            <div class="detail-section">
                <h3>✨ 추가 서비스</h3>
                <ul>
                    ${services.map(s => `<li>${getServiceName(s)}</li>`).join('')}
                </ul>
            </div>
        ` : ''}
        
        <div class="proposal-actions" style="margin-top: 30px;">
            ${proposal.proposalStatus !== 'selected' ? `
                <button class="action-btn btn-select" onclick="selectProposal('${proposal.id}'); closeDetailModal();">이 제안 선택하기</button>
                <button class="action-btn btn-reject" onclick="rejectProposal('${proposal.id}'); closeDetailModal();">거절하기</button>
            ` : '<p style="color: #10b981; font-weight: 600; text-align: center;">✓ 선정된 제안서입니다</p>'}
        </div>
    `;
    
    document.getElementById('proposalDetailContent').innerHTML = detailHTML;
    document.getElementById('proposalDetailModal').style.display = 'block';
}

function getServiceName(serviceCode) {
    const services = {
        'photography': '전문 사진 촬영',
        'staging': '홈 스테이징',
        'virtual-tour': 'VR 투어',
        'legal-support': '법률 자문',
        'tax-consulting': '세무 상담'
    };
    return services[serviceCode] || serviceCode;
}

function closeDetailModal() {
    document.getElementById('proposalDetailModal').style.display = 'none';
}

/* =========================================== */
/* 6. 제안서 선택/거절 */
/* =========================================== */

async function selectProposal(proposalId) {
    if (!confirm('이 제안을 선택하시겠습니까?\n\n다른 모든 제안은 자동으로 거절됩니다.')) {
        return;
    }
    
    try {
        const db = firebase.firestore();
        
        // 선택한 제안서 상태 업데이트
        await db.collection('proposals').doc(proposalId).update({
            proposalStatus: 'selected',
            selectedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        
        // 다른 제안서들 거절
        const otherProposals = allProposals.filter(p => p.id !== proposalId);
        for (const proposal of otherProposals) {
            await db.collection('proposals').doc(proposal.id).update({
                proposalStatus: 'rejected',
                rejectedAt: firebase.firestore.FieldValue.serverTimestamp()
            });
        }
        
        alert('✅ 제안이 선택되었습니다!\n\n중개사에게 알림이 전송됩니다.');
        await loadProposals();
        
    } catch (error) {
        console.error('❌ 제안 선택 실패:', error);
        alert('제안 선택에 실패했습니다: ' + error.message);
    }
}

async function rejectProposal(proposalId) {
    const reason = prompt('거절 사유를 입력해주세요 (선택사항):');
    
    if (reason === null) return; // 취소
    
    try {
        const db = firebase.firestore();
        
        await db.collection('proposals').doc(proposalId).update({
            proposalStatus: 'rejected',
            rejectedAt: firebase.firestore.FieldValue.serverTimestamp(),
            rejectionReason: reason || '사유 없음'
        });
        
        alert('제안이 거절되었습니다.');
        
        // 다른 중개사에게 재요청할지 물어보기
        if (confirm('다른 중개사에게 제안서를 새로 요청하시겠습니까?')) {
            requestNewProposal();
        } else {
            await loadProposals();
        }
        
    } catch (error) {
        console.error('❌ 제안 거절 실패:', error);
        alert('제안 거절에 실패했습니다: ' + error.message);
    }
}

/**
 * 새로운 제안서 요청
 */
function requestNewProposal() {
    // 중개사 검색 페이지로 이동
    alert('중개사 검색 페이지로 이동하여 다른 중개사를 선택해주세요.');
    window.location.href = 'broker.html';
}

/* =========================================== */
/* 7. 정렬 */
/* =========================================== */

function sortProposals() {
    const sortBy = document.getElementById('sortBy').value;
    
    switch(sortBy) {
        case 'price-high':
            allProposals.sort((a, b) => (b.pricing?.suggestedPrice || 0) - (a.pricing?.suggestedPrice || 0));
            break;
        case 'price-low':
            allProposals.sort((a, b) => (a.pricing?.suggestedPrice || 0) - (b.pricing?.suggestedPrice || 0));
            break;
        case 'commission-low':
            allProposals.sort((a, b) => (a.pricing?.commissionRate || 0) - (b.pricing?.commissionRate || 0));
            break;
        case 'duration-short':
            allProposals.sort((a, b) => {
                const aDays = Math.max(...(a.timeline?.map(t => t.day) || [0]));
                const bDays = Math.max(...(b.timeline?.map(t => t.day) || [0]));
                return aDays - bDays;
            });
            break;
        case 'date-new':
            allProposals.sort((a, b) => {
                const aTime = a.createdAt?.toDate?.() || new Date(0);
                const bTime = b.createdAt?.toDate?.() || new Date(0);
                return bTime - aTime;
            });
            break;
    }
    
    displayProposals();
}

/* =========================================== */
/* 8. 유틸리티 */
/* =========================================== */

function goToMainPage() {
    window.location.href = 'index.html';
}

function logout() {
    if (confirm('로그아웃하시겠습니까?')) {
        firebase.auth().signOut();
        window.location.href = 'index.html';
    }
}

console.log('✅ proposals-list.js 로드 완료');

