/* =========================================== */
/* PROPERTY REGISTER - 매물 등록 페이지 JavaScript */
/* =========================================== */

// 전역 변수
let selectedProposal = null;
let selectedPhotos = [];

/* =========================================== */
/* 1. 페이지 초기화 */
/* =========================================== */

document.addEventListener('DOMContentLoaded', async function() {
    console.log('🏡 매물 등록 페이지 초기화 시작');
    
    // URL에서 제안서 ID 가져오기
    const urlParams = new URLSearchParams(window.location.search);
    const proposalId = urlParams.get('id');
    
    if (!proposalId) {
        alert('제안서 ID가 없습니다. 관리자 대시보드로 이동합니다.');
        window.location.href = 'admin.html';
        return;
    }
    
    // 제안서 정보 로드
    await loadProposalInfo(proposalId);
    
    // 사진 업로드 이벤트
    document.getElementById('photoInput').addEventListener('change', handlePhotoSelect);
    
    // 폼 제출 이벤트
    document.getElementById('propertyForm').addEventListener('submit', handleSubmit);
    
    console.log('✅ 매물 등록 페이지 초기화 완료');
});

/* =========================================== */
/* 2. 제안서 정보 로드 */
/* =========================================== */

async function loadProposalInfo(proposalId) {
    try {
        console.log('📥 제안서 정보 로드 중:', proposalId);
        
        const db = firebase.firestore();
        const doc = await db.collection('proposals').doc(proposalId).get();
        
        if (!doc.exists) {
            throw new Error('제안서를 찾을 수 없습니다.');
        }
        
        selectedProposal = {
            id: doc.id,
            ...doc.data()
        };
        
        // 선정된 제안서인지 확인
        if (selectedProposal.proposalStatus !== 'selected') {
            throw new Error('선정되지 않은 제안서입니다.');
        }
        
        // UI 업데이트
        document.getElementById('customerName').textContent = selectedProposal.customerName || '-';
        document.getElementById('customerEmail').textContent = selectedProposal.customerEmail || '-';
        document.getElementById('suggestedPrice').textContent = 
            (selectedProposal.pricing?.suggestedPrice || 0).toLocaleString() + '만원';
        document.getElementById('commission').textContent = 
            `${selectedProposal.pricing?.commissionRate || 0}% (${(selectedProposal.pricing?.commissionAmount || 0).toLocaleString()}만원)`;
        
        // 제안가를 판매가 기본값으로 설정
        document.getElementById('salePrice').value = selectedProposal.pricing?.suggestedPrice || '';
        
        console.log('✅ 제안서 정보 로드 완료:', selectedProposal);
        
    } catch (error) {
        console.error('❌ 제안서 정보 로드 실패:', error);
        alert('제안서 정보를 불러오는데 실패했습니다: ' + error.message);
        window.location.href = 'admin.html';
    }
}

/* =========================================== */
/* 3. 사진 업로드 처리 */
/* =========================================== */

function handlePhotoSelect(event) {
    const files = Array.from(event.target.files);
    
    if (selectedPhotos.length + files.length > 10) {
        alert('최대 10장까지만 업로드할 수 있습니다.');
        return;
    }
    
    files.forEach(file => {
        if (!file.type.startsWith('image/')) {
            alert('이미지 파일만 업로드할 수 있습니다.');
            return;
        }
        
        const reader = new FileReader();
        reader.onload = (e) => {
            selectedPhotos.push({
                file: file,
                dataUrl: e.target.result
            });
            updatePhotoPreview();
        };
        reader.readAsDataURL(file);
    });
}

function updatePhotoPreview() {
    const preview = document.getElementById('photoPreview');
    preview.innerHTML = selectedPhotos.map((photo, index) => `
        <div class="photo-item">
            <img src="${photo.dataUrl}" alt="매물 사진 ${index + 1}">
            <button type="button" class="photo-remove" onclick="removePhoto(${index})">×</button>
        </div>
    `).join('');
}

function removePhoto(index) {
    selectedPhotos.splice(index, 1);
    updatePhotoPreview();
}

/* =========================================== */
/* 4. 폼 제출 */
/* =========================================== */

async function handleSubmit(event) {
    event.preventDefault();
    
    if (!confirm('매물을 등록하시겠습니까?\n\n등록 후 플랫폼에 즉시 게시됩니다.')) {
        return;
    }
    
    try {
        // 폼 데이터 수집
        const propertyData = collectFormData();
        
        // 사진 업로드
        if (selectedPhotos.length > 0) {
            const photoUrls = await uploadPhotos();
            propertyData.photos = photoUrls;
        }
        
        // Firestore에 저장
        await saveProperty(propertyData);
        
        alert('✅ 매물이 성공적으로 등록되었습니다!');
        window.location.href = 'admin.html';
        
    } catch (error) {
        console.error('❌ 매물 등록 실패:', error);
        alert('매물 등록에 실패했습니다: ' + error.message);
    }
}

/* =========================================== */
/* 5. 폼 데이터 수집 */
/* =========================================== */

function collectFormData() {
    // 추가 옵션
    const options = [];
    document.querySelectorAll('input[name="options"]:checked').forEach(checkbox => {
        options.push(checkbox.value);
    });
    
    return {
        // 관련 ID
        proposalId: selectedProposal.id,
        quoteRequestId: selectedProposal.quoteRequestId,
        customerId: selectedProposal.customerUserId,
        customerName: selectedProposal.customerName,
        customerEmail: selectedProposal.customerEmail,
        brokerName: selectedProposal.brokerName,
        brokerEmail: selectedProposal.brokerEmail,
        
        // 기본 정보
        propertyType: document.getElementById('propertyType').value,
        transactionType: document.getElementById('transactionType').value,
        title: document.getElementById('propertyTitle').value.trim(),
        description: document.getElementById('propertyDescription').value.trim(),
        
        // 면적 정보
        exclusiveArea: parseFloat(document.getElementById('exclusiveArea').value) || 0,
        supplyArea: parseFloat(document.getElementById('supplyArea').value) || 0,
        
        // 가격 정보
        salePrice: parseFloat(document.getElementById('salePrice').value) || 0,
        deposit: parseFloat(document.getElementById('deposit').value) || 0,
        monthlyRent: parseFloat(document.getElementById('monthlyRent').value) || 0,
        
        // 상세 정보
        rooms: parseInt(document.getElementById('rooms').value) || 0,
        bathrooms: parseInt(document.getElementById('bathrooms').value) || 0,
        floor: document.getElementById('floor').value.trim(),
        direction: document.getElementById('direction').value,
        parking: parseInt(document.getElementById('parking').value) || 0,
        moveInDate: document.getElementById('moveInDate').value,
        
        // 추가 옵션
        options: options,
        
        // 메타데이터
        status: 'active',
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    };
}

/* =========================================== */
/* 6. 사진 업로드 */
/* =========================================== */

async function uploadPhotos() {
    console.log('📸 사진 업로드 시작:', selectedPhotos.length, '장');
    
    const photoUrls = [];
    
    // Firebase Storage 사용 (간단한 구현을 위해 Base64로 저장)
    // 실제 프로덕션에서는 Firebase Storage를 사용해야 합니다
    for (let i = 0; i < selectedPhotos.length; i++) {
        photoUrls.push(selectedPhotos[i].dataUrl);
    }
    
    console.log('✅ 사진 업로드 완료');
    return photoUrls;
}

/* =========================================== */
/* 7. Firestore 저장 */
/* =========================================== */

async function saveProperty(propertyData) {
    const db = firebase.firestore();
    
    // 매물 등록
    const docRef = await db.collection('properties').add(propertyData);
    console.log('✅ 매물 등록 완료:', docRef.id);
    
    // 제안서 상태 업데이트
    await db.collection('proposals').doc(selectedProposal.id).update({
        propertyRegistered: true,
        propertyId: docRef.id,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    });
}

/* =========================================== */
/* 8. 임시저장 */
/* =========================================== */

async function saveDraft() {
    try {
        const propertyData = collectFormData();
        propertyData.status = 'draft';
        
        const db = firebase.firestore();
        
        // 기존 임시저장 확인
        const existingDraft = await db.collection('properties')
            .where('proposalId', '==', selectedProposal.id)
            .where('status', '==', 'draft')
            .limit(1)
            .get();
        
        if (!existingDraft.empty) {
            // 업데이트
            const docId = existingDraft.docs[0].id;
            await db.collection('properties').doc(docId).update({
                ...propertyData,
                updatedAt: firebase.firestore.FieldValue.serverTimestamp()
            });
        } else {
            // 새로 생성
            await db.collection('properties').add(propertyData);
        }
        
        alert('✅ 임시저장되었습니다!');
        
    } catch (error) {
        console.error('❌ 임시저장 실패:', error);
        alert('임시저장에 실패했습니다: ' + error.message);
    }
}

/* =========================================== */
/* 9. 네비게이션 */
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

console.log('✅ property-register.js 로드 완료');



