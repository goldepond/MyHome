/**
 * MyHome Cloud Functions
 *
 * Firestore notifications 컬렉션에 문서가 추가되면
 * 해당 사용자에게 FCM 푸시 알림을 전송합니다.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Firebase Admin 초기화
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * notifications 컬렉션에 새 문서가 생성되면 푸시 알림 전송
 */
exports.sendPushNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const notification = snapshot.data();
    const userId = notification.userId;
    const title = notification.title || "알림";
    const body = notification.message || "";
    const type = notification.type || "general";
    const relatedId = notification.relatedId;

    if (!userId) {
      console.log("No userId in notification");
      return;
    }

    try {
      // 사용자의 FCM 토큰 가져오기
      const userDoc = await db.collection("users").doc(userId).get();

      if (!userDoc.exists) {
        console.log(`User ${userId} not found`);
        return;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${userId}`);
        return;
      }

      // FCM 메시지 구성
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: type,
          relatedId: relatedId || "",
          notificationId: event.params.notificationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "myhome_notifications",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              badge: 1,
              sound: "default",
            },
          },
        },
      };

      // 푸시 알림 전송
      const response = await messaging.send(message);
      console.log(`Successfully sent push to ${userId}:`, response);

      // 전송 성공 기록 (선택)
      await snapshot.ref.update({
        pushSentAt: new Date(),
        pushSuccess: true,
      });

    } catch (error) {
      console.error(`Error sending push to ${userId}:`, error);

      // 토큰이 만료된 경우 삭제
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        console.log(`Removing invalid token for user ${userId}`);
        await db.collection("users").doc(userId).update({
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        });
      }

      // 전송 실패 기록
      await snapshot.ref.update({
        pushSentAt: new Date(),
        pushSuccess: false,
        pushError: error.message,
      });
    }
  }
);

/**
 * 중개사(brokers) 컬렉션의 사용자에게도 푸시 알림 전송
 * (brokers 컬렉션에 별도로 토큰이 저장된 경우)
 */
exports.sendBrokerPushNotification = onDocumentCreated(
  "brokerNotifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notification = snapshot.data();
    const brokerId = notification.brokerId;
    const title = notification.title || "알림";
    const body = notification.message || "";

    if (!brokerId) return;

    try {
      // 브로커 문서에서 FCM 토큰 가져오기
      const brokerDoc = await db.collection("brokers").doc(brokerId).get();

      if (!brokerDoc.exists) {
        // users 컬렉션에서도 확인
        const userDoc = await db.collection("users").doc(brokerId).get();
        if (!userDoc.exists) {
          console.log(`Broker ${brokerId} not found`);
          return;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (fcmToken) {
          await sendFCM(fcmToken, title, body, notification, event.params.notificationId, snapshot.ref);
        }
        return;
      }

      const brokerData = brokerDoc.data();
      const fcmToken = brokerData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for broker ${brokerId}`);
        return;
      }

      await sendFCM(fcmToken, title, body, notification, event.params.notificationId, snapshot.ref);

    } catch (error) {
      console.error(`Error sending push to broker ${brokerId}:`, error);
    }
  }
);

/**
 * FCM 전송 헬퍼 함수
 */
async function sendFCM(fcmToken, title, body, notification, notificationId, docRef) {
  const message = {
    token: fcmToken,
    notification: { title, body },
    data: {
      type: notification.type || "general",
      relatedId: notification.relatedId || "",
      notificationId: notificationId,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "myhome_notifications",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          badge: 1,
          sound: "default",
        },
      },
    },
  };

  const response = await messaging.send(message);
  console.log("Push sent successfully:", response);

  await docRef.update({
    pushSentAt: new Date(),
    pushSuccess: true,
  });
}
