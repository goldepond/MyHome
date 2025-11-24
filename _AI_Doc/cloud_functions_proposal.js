/**
 * Cloud Functions for Firebase
 * 
 * 이 코드는 'functions/index.js'에 배포되어야 합니다.
 * (현재 프로젝트에는 functions 폴더가 없으므로 코드 제안만 드립니다)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// 1. 견적 선택 시 중요 상태 검증 (Server-side Validation)
exports.validateQuoteSelection = functions.firestore
    .document('quoteRequests/{requestId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const previousData = change.before.data();

        // 상태가 'selected'로 변경되었는지 확인
        if (newData.isSelectedByUser === true && !previousData.isSelectedByUser) {
            
            // 1) 사용자 권한 검증 (요청자와 선택자가 동일한지)
            // Cloud Functions는 이미 관리자 권한으로 실행되지만,
            // 로직상 데이터 무결성을 위해 한 번 더 체크 가능
            
            // 2) 중복 선택 방지 (이미 선택된 건인데 또 선택했는지?)
            // 클라이언트에서 막아도 서버에서 한번 더 체크하면 안전
            
            // 3) 알림 발송 (FCM)
            const brokerRegistrationNumber = newData.brokerRegistrationNumber;
            if (brokerRegistrationNumber) {
                const brokerSnapshot = await admin.firestore()
                    .collection('brokers')
                    .where('brokerRegistrationNumber', '==', brokerRegistrationNumber)
                    .limit(1)
                    .get();

                if (!brokerSnapshot.empty) {
                    const brokerData = brokerSnapshot.docs[0].data();
                    const brokerToken = brokerData.fcmToken; // FCM 토큰이 있다고 가정

                    if (brokerToken) {
                        const payload = {
                            notification: {
                                title: "매칭 성공! 🎉",
                                body: "고객님이 제안주신 견적을 선택했습니다. 지금 바로 확인해보세요.",
                            },
                            data: {
                                type: "quote_selected",
                                requestId: context.params.requestId
                            }
                        };
                        await admin.messaging().sendToDevice(brokerToken, payload);
                    }
                }
            }
        }
    });

// 2. 새로운 견적 요청 시 주변 중개사에게 알림
exports.notifyBrokersOnNewRequest = functions.firestore
    .document('quoteRequests/{requestId}')
    .onCreate(async (snap, context) => {
        const requestData = snap.data();
        const location = requestData.location; // GeoPoint {latitude, longitude}

        if (!location) return;

        // GeoQuery를 사용하여 반경 N km 내의 중개사 찾기
        // (Firestore는 기본적으로 범위 쿼리를 지원하지 않으므로 geohash 라이브러리 등 필요)
        // 여기서는 단순 예시로 모든 중개사에게 보내는 것은 비효율적이므로 생략
        
        // 대신 '관심 지역'을 등록한 중개사에게 발송하는 로직 구현 가능
    });

