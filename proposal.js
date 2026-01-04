/* =========================================== */
/* PROPOSAL PAGE - 제안서 작성 페이지 JavaScript */
/* =========================================== */

// 전역 변수
let currentQuoteRequest = null;
let timelineItemCount = 0;

/* =========================================== */
/* 1. 페이지 초기화 */
/* =========================================== */

document.addEventListener('DOMContentLoaded', async function() {
    console.log('📝 제안서 작성 페이지 초기화 시작');
    
    // URL에서 견적문의 ID 가져오기
    const urlParams = new URLSearchParams(window.location.search);
    const quoteRequestId = urlParams.get('id');
    
    if (!quoteRequestId) {
        alert('견적문의 ID가 없습니다. 관리자 대시보드로 이동합니다.');
        window.location.href = 'admin.html';
        return;
    }
    
    // 견적문의 정보 로드
    await loadQuoteRequestInfo(quoteRequestId);
    
    // 기본 타임라인 항목 추가
    addTimelineItem();
    addTimelineItem();
    addTimelineItem();
    
    // 수수료 자동 계산 이벤트
    document.getElementById('suggestedPrice').addEventListener('input', calculateCommission);
    document.getElementById('commissionRate').addEventListener('input', calculateCommission);
    
    // 폼 제출 이벤트
    document.getElementById('proposalForm').addEventListener('submit', handleSubmit);
    
    console.log('✅ 제안서 작성 페이지 초기화 완료');
});

/* =========================================== */
/* 2. 견적문의 정보 로드 */
/* =========================================== */

async function loadQuoteRequestInfo(quoteRequestId) {
    try {
        console.log('📥 견적문의 정보 로드 중:', quoteRequestId);
        
        const db = firebase.firestore();
        const doc = await db.collection('quoteRequests').doc(quoteRequestId).get();
        
        if (!doc.exists) {
            throw new Error('견적문의를 찾을 수 없습니다.');
        }
        
        currentQuoteRequest = {
            id: doc.id,
            ...doc.data()
        };
        
        // UI 업데이트
        document.getElementById('customerName').textContent = currentQuoteRequest.userName || '-';
        document.getElementById('customerEmail').textContent = currentQuoteRequest.userEmail || '-';
        
        // 중개사 정보에서 주소 가져오기
        const address = currentQuoteRequest.brokerData?.rdnmadr || 
                       currentQuoteRequest.brokerData?.mnnmadr || '-';
        document.getElementById('propertyAddress').textContent = address;
        
        // 문의일시
        const requestDate = currentQuoteRequest.timestamp ? 
                           new Date(currentQuoteRequest.timestamp.toDate()).toLocaleString('ko-KR') :
                           new Date(currentQuoteRequest.requestDate).toLocaleString('ko-KR');
        document.getElementById('requestDate').textContent = requestDate;
        
        // 문의내용
        document.getElementById('customerMessage').textContent = currentQuoteRequest.message || '-';
        
        console.log('✅ 견적문의 정보 로드 완료:', currentQuoteRequest);
        
    } catch (error) {
        console.error('❌ 견적문의 정보 로드 실패:', error);
        alert('견적문의 정보를 불러오는데 실패했습니다: ' + error.message);
        window.location.href = 'admin.html';
    }
}

/* =========================================== */
/* 3. 타임라인 관리 */
/* =========================================== */

function addTimelineItem() {
    timelineItemCount++;
    const container = document.getElementById('timelineItems');
    
    const item = document.createElement('div');
    item.className = 'timeline-item';
    item.dataset.index = timelineItemCount;
    
    item.innerHTML = `
        <input type="number" placeholder="일수 (일)" class="timeline-day" min="1" required>
        <input type="text" placeholder="진행 내용 (예: 매물 촬영 및 마케팅 자료 준비)" class="timeline-task" required>
        <button type="button" class="remove-btn" onclick="removeTimelineItem(${timelineItemCount})">삭제</button>
    `;
    
    container.appendChild(item);
}

function removeTimelineItem(index) {
    const item = document.querySelector(`.timeline-item[data-index="${index}"]`);
    if (item) {
        item.remove();
    }
    
    // 최소 1개는 유지
    const remainingItems = document.querySelectorAll('.timeline-item');
    if (remainingItems.length === 0) {
        addTimelineItem();
    }
}

/* =========================================== */
/* 4. 수수료 자동 계산 */
/* =========================================== */

function calculateCommission() {
    const suggestedPrice = parseFloat(document.getElementById('suggestedPrice').value) || 0;
    const commissionRate = parseFloat(document.getElementById('commissionRate').value) || 0;
    
    const commissionAmount = (suggestedPrice * commissionRate / 100).toFixed(0);
    document.getElementById('commissionAmount').value = commissionAmount;
}

/* =========================================== */
/* 5. 제안서 제출 */
/* =========================================== */

async function handleSubmit(event) {
    event.preventDefault();
    
    if (!confirm('제안서를 제출하시겠습니까?\n\n제출 후에는 수정이 불가능합니다.')) {
        return;
    }
    
    try {
        // 폼 데이터 수집
        const proposalData = collectFormData();
        proposalData.status = 'submitted';
        
        // Firestore에 저장
        await saveProposal(proposalData);
        
        alert('✅ 제안서가 성공적으로 제출되었습니다!');
        window.location.href = 'admin.html';
        
    } catch (error) {
        console.error('❌ 제안서 제출 실패:', error);
        alert('제안서 제출에 실패했습니다: ' + error.message);
    }
}

/* =========================================== */
/* 6. 임시저장 */
/* =========================================== */

async function saveDraft() {
    try {
        const proposalData = collectFormData();
        proposalData.status = 'draft';
        
        await saveProposal(proposalData);
        
        alert('✅ 임시저장되었습니다!');
        
    } catch (error) {
        console.error('❌ 임시저장 실패:', error);
        alert('임시저장에 실패했습니다: ' + error.message);
    }
}

/* =========================================== */
/* 7. 폼 데이터 수집 */
/* =========================================== */

function collectFormData() {
    // 가격 제안
    const suggestedPrice = parseFloat(document.getElementById('suggestedPrice').value);
    const minPrice = parseFloat(document.getElementById('minPrice').value);
    
    // 수수료
    const commissionRate = parseFloat(document.getElementById('commissionRate').value);
    const commissionAmount = parseFloat(document.getElementById('commissionAmount').value);
    const commissionNotes = document.getElementById('commissionNotes').value.trim();
    
    // 타임라인
    const timelineItems = [];
    document.querySelectorAll('.timeline-item').forEach(item => {
        const day = parseInt(item.querySelector('.timeline-day').value);
        const task = item.querySelector('.timeline-task').value.trim();
        if (day && task) {
            timelineItems.push({ day, task });
        }
    });
    
    // 타임라인 정렬 (일수 기준)
    timelineItems.sort((a, b) => a.day - b.day);
    
    // 전략
    const marketAnalysis = document.getElementById('marketAnalysis').value.trim();
    const sellingPoints = document.getElementById('sellingPoints').value.trim();
    const marketingStrategy = document.getElementById('marketingStrategy').value.trim();
    const negotiationStrategy = document.getElementById('negotiationStrategy').value.trim();
    
    // 현재 상황
    const currentStatus = document.getElementById('currentStatus').value;
    const statusNotes = document.getElementById('statusNotes').value.trim();
    
    // 추가 서비스
    const services = [];
    document.querySelectorAll('input[name="services"]:checked').forEach(checkbox => {
        services.push(checkbox.value);
    });
    
    return {
        quoteRequestId: currentQuoteRequest.id,
        customerName: currentQuoteRequest.userName,
        customerEmail: currentQuoteRequest.userEmail,
        customerUserId: currentQuoteRequest.userId,
        brokerName: currentQuoteRequest.brokerName,
        brokerEmail: currentQuoteRequest.brokerEmail || null,
        
        // 가격 정보
        pricing: {
            suggestedPrice,
            minPrice,
            commissionRate,
            commissionAmount,
            commissionNotes
        },
        
        // 타임라인
        timeline: timelineItems,
        
        // 전략
        strategy: {
            marketAnalysis,
            sellingPoints,
            marketingStrategy,
            negotiationStrategy
        },
        
        // 현재 상황
        currentStatus,
        statusNotes,
        
        // 추가 서비스
        additionalServices: services,
        
        // 메타데이터
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    };
}

/* =========================================== */
/* 8. Firestore 저장 */
/* =========================================== */

async function saveProposal(proposalData) {
    const db = firebase.firestore();
    
    // 기존 제안서가 있는지 확인
    const existingProposal = await db.collection('proposals')
        .where('quoteRequestId', '==', currentQuoteRequest.id)
        .limit(1)
        .get();
    
    if (!existingProposal.empty) {
        // 기존 제안서 업데이트
        const docId = existingProposal.docs[0].id;
        await db.collection('proposals').doc(docId).update({
            ...proposalData,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ 제안서 업데이트 완료:', docId);
    } else {
        // 새 제안서 생성
        const docRef = await db.collection('proposals').add(proposalData);
        console.log('✅ 제안서 생성 완료:', docRef.id);
    }
    
    // 견적문의 상태 업데이트
    await db.collection('quoteRequests').doc(currentQuoteRequest.id).update({
        hasProposal: true,
        proposalStatus: proposalData.status,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    });
}

/* =========================================== */
/* 9. 네비게이션 함수 */
/* =========================================== */

function goToMainPage() {
    window.location.href = 'index.html';
}

function goToAdminDashboard() {
    window.location.href = 'admin.html';
}

function goBack() {
    if (confirm('작성 중인 내용이 저장되지 않습니다. 정말 취소하시겠습니까?')) {
        window.location.href = 'admin.html';
    }
}

function logout() {
    if (confirm('로그아웃하시겠습니까?')) {
        localStorage.removeItem('adminAuth');
        localStorage.removeItem('adminUser');
        window.location.href = 'index.html';
    }
}

console.log('✅ proposal.js 로드 완료');





