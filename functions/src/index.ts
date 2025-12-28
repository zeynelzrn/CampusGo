import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Helper function to write in-app notification to Firestore
 * This enables iOS devices without FCM to receive notifications via Firestore Stream
 */
async function writeInAppNotification(
  userId: string,
  title: string,
  body: string,
  type: string,
  extraData?: Record<string, string>
): Promise<void> {
  try {
    await db.collection("users").doc(userId).collection("notifications").add({
      title: title,
      body: body,
      type: type,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...extraData,
    });
    console.log(`In-app notification written for user ${userId}`);
  } catch (error) {
    console.error(`Error writing in-app notification for ${userId}:`, error);
  }
}

/**
 * Triggered when a new message is created in a chat
 * Sends push notification AND writes to Firestore for in-app display
 */
export const onNewMessage = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const chatId = context.params.chatId;

    if (!message) return null;

    const senderId = message.senderId as string;
    const text = message.text as string;

    try {
      // Get chat document to find the recipient
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return null;

      const chatData = chatDoc.data();
      if (!chatData) return null;

      const users = chatData.users as string[];
      const recipientId = users.find((uid: string) => uid !== senderId);

      if (!recipientId) return null;

      // Get sender's name
      let senderName = "Birisi";
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        senderName = senderData?.name || "Birisi";
      }

      // Prepare message preview (max 50 chars)
      const messagePreview = text.length > 50 ? text.substring(0, 47) + "..." : text;

      // ALWAYS write to Firestore for in-app notifications (iOS fallback)
      await writeInAppNotification(
        recipientId,
        senderName,
        messagePreview,
        "message",
        { chatId: chatId, senderId: senderId }
      );

      // Try to send FCM (may fail on iOS without paid account)
      const recipientDoc = await db.collection("users").doc(recipientId).get();
      const recipientData = recipientDoc.data();
      const fcmToken = recipientData?.fcmToken as string | undefined;

      if (fcmToken) {
        try {
          const payload: admin.messaging.Message = {
            token: fcmToken,
            notification: {
              title: senderName,
              body: messagePreview,
            },
            data: {
              type: "message",
              chatId: chatId,
              senderId: senderId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              title: senderName,
              body: messagePreview,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "high_importance_channel",
                sound: "default",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          };

          await messaging.send(payload);
          console.log(`FCM notification sent to ${recipientId}`);
        } catch (fcmError) {
          console.log(`FCM failed for ${recipientId}, using Firestore fallback`);
        }
      }

      return null;
    } catch (error) {
      console.error("Error in onNewMessage:", error);
      return null;
    }
  });

/**
 * Triggered when a new like action is created
 * Sends push notification AND writes to Firestore for in-app display
 */
export const onNewLike = functions.firestore
  .document("actions/{actionId}")
  .onCreate(async (snapshot, context) => {
    const action = snapshot.data();

    if (!action) return null;

    const actionType = action.type as string;

    // Only send notification for likes and superlikes
    if (actionType !== "like" && actionType !== "superlike") {
      return null;
    }

    const fromUserId = action.fromUserId as string;
    const toUserId = action.toUserId as string;

    try {
      // Prepare notification content
      const title = actionType === "superlike"
        ? "Biri seni cok begendi!"
        : "Biri seni begendi!";
      const body = "Yeni bir hayranin var, hemen bak!";

      // ALWAYS write to Firestore for in-app notifications (iOS fallback)
      await writeInAppNotification(
        toUserId,
        title,
        body,
        "like",
        { fromUserId: fromUserId }
      );

      // Try to send FCM
      const targetDoc = await db.collection("users").doc(toUserId).get();
      const targetData = targetDoc.data();
      const fcmToken = targetData?.fcmToken as string | undefined;

      if (fcmToken) {
        try {
          const payload: admin.messaging.Message = {
            token: fcmToken,
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: "like",
              fromUserId: fromUserId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              title: title,
              body: body,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "high_importance_channel",
                sound: "default",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          };

          await messaging.send(payload);
          console.log(`FCM like notification sent to ${toUserId}`);
        } catch (fcmError) {
          console.log(`FCM failed for ${toUserId}, using Firestore fallback`);
        }
      }

      return null;
    } catch (error) {
      console.error("Error in onNewLike:", error);
      return null;
    }
  });

/**
 * Triggered when a new match is created
 * Sends push notification AND writes to Firestore for in-app display
 */
export const onNewMatch = functions.firestore
  .document("matches/{matchId}")
  .onCreate(async (snapshot, context) => {
    const match = snapshot.data();
    const matchId = context.params.matchId;

    if (!match) return null;

    const users = match.users as string[];

    if (!users || users.length !== 2) return null;

    const title = "Yeni Eslesme!";
    const body = "Biriyle eslestin, hemen sohbete basla!";

    try {
      // Process both users
      const notifications = users.map(async (userId) => {
        // ALWAYS write to Firestore for in-app notifications
        await writeInAppNotification(
          userId,
          title,
          body,
          "match",
          { matchId: matchId }
        );

        // Try to send FCM
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken as string | undefined;

        if (fcmToken) {
          try {
            const payload: admin.messaging.Message = {
              token: fcmToken,
              notification: {
                title: title,
                body: body,
              },
              data: {
                type: "match",
                matchId: matchId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                title: title,
                body: body,
              },
              android: {
                priority: "high",
                notification: {
                  channelId: "high_importance_channel",
                  sound: "default",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };

            await messaging.send(payload);
            console.log(`FCM match notification sent to ${userId}`);
          } catch (fcmError) {
            console.log(`FCM failed for ${userId}, using Firestore fallback`);
          }
        }
      });

      await Promise.all(notifications);
      return null;
    } catch (error) {
      console.error("Error in onNewMatch:", error);
      return null;
    }
  });
