const admin = require('firebase-admin');

/**
 * Send push notification to a user via Firebase Cloud Messaging
 * @param {string} fcmToken - User's FCM device token
 * @param {object} notification - { title, body }
 * @param {object} data - Custom data payload (for deep linking)
 */
async function sendPush(fcmToken, notification, data = {}) {
  if (!fcmToken || fcmToken.length < 10) return;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: 'nearfo_notifications',
          priority: 'high',
          sound: 'default',
          defaultVibrateTimings: true,
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1,
          },
        },
      },
    });
    console.log(`[Push] Sent to token: ${fcmToken.substring(0, 15)}...`);
  } catch (err) {
    console.log(`[Push] Failed: ${err.message}`);
    // If token is invalid, clear it from DB
    if (err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token') {
      try {
        const User = require('../models/User');
        await User.findOneAndUpdate({ fcmToken }, { fcmToken: '' });
        console.log('[Push] Cleared invalid token from DB');
      } catch (e) { /* non-critical */ }
    }
  }
}

/**
 * Send push to a user by their userId (fetches token from DB)
 */
async function sendPushToUser(userId, notification, data = {}) {
  try {
    const User = require('../models/User');
    const user = await User.findById(userId).select('fcmToken');
    if (user?.fcmToken) {
      await sendPush(user.fcmToken, notification, data);
    }
  } catch (e) {
    console.log(`[Push] User push failed: ${e.message}`);
  }
}

// Convenience methods
const push = {
  // New chat message
  chatMessage: (recipientId, senderId, senderName, messagePreview) => sendPushToUser(recipientId, {
    title: senderName,
    body: messagePreview.length > 100 ? messagePreview.substring(0, 100) + '...' : messagePreview,
  }, { type: 'message', senderId: senderId }),

  // Incoming call
  incomingCall: (recipientId, callerId, callerName, callerAvatar, isVideo) => sendPushToUser(recipientId, {
    title: isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
    body: `${callerName} is calling you`,
  }, { type: 'incoming_call', callerId, callerName, callerAvatar: callerAvatar || '', isVideo: String(isVideo) }),

  // Like
  like: (recipientId, senderName) => sendPushToUser(recipientId, {
    title: 'Nearfo',
    body: `${senderName} liked your post`,
  }, { type: 'like' }),

  // Comment
  comment: (recipientId, senderName, commentPreview) => sendPushToUser(recipientId, {
    title: 'Nearfo',
    body: `${senderName}: ${commentPreview.substring(0, 80)}`,
  }, { type: 'comment' }),

  // Follow
  follow: (recipientId, senderName) => sendPushToUser(recipientId, {
    title: 'Nearfo',
    body: `${senderName} started following you`,
  }, { type: 'follow' }),

  // Live started
  liveStarted: (recipientId, hostName, title) => sendPushToUser(recipientId, {
    title: `${hostName} is live!`,
    body: title || 'Watch now on Nearfo',
  }, { type: 'live' }),
};

module.exports = { sendPush, sendPushToUser, push };
