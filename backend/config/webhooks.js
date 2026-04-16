const https = require('https');
const http = require('http');

/**
 * Webhook Dispatcher System
 * Sends event notifications to registered webhook URLs.
 *
 * Webhook URLs are stored in WEBHOOK_URLS env variable as JSON array:
 * WEBHOOK_URLS=["https://hooks.slack.com/services/xxx","https://discord.com/api/webhooks/xxx"]
 *
 * Events: user_signup, post_created, post_viral, report_filed, user_banned, takedown_filed
 */

let webhookUrls = [];

try {
  const raw = process.env.WEBHOOK_URLS;
  if (raw) webhookUrls = JSON.parse(raw);
} catch (e) {
  console.log('[Webhooks] No webhook URLs configured');
}

/**
 * Dispatch event to all registered webhooks
 * @param {string} event - Event name (e.g. 'user_signup')
 * @param {object} data - Event payload
 */
async function dispatchWebhook(event, data = {}) {
  if (webhookUrls.length === 0) return;

  const payload = JSON.stringify({
    event,
    timestamp: new Date().toISOString(),
    app: 'nearfo',
    data,
  });

  for (const url of webhookUrls) {
    try {
      const urlObj = new URL(url);
      const isHttps = urlObj.protocol === 'https:';
      const options = {
        hostname: urlObj.hostname,
        port: urlObj.port || (isHttps ? 443 : 80),
        path: urlObj.pathname + urlObj.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
          'User-Agent': 'Nearfo-Webhook/1.0',
        },
        timeout: 5000,
      };

      const lib = isHttps ? https : http;
      const req = lib.request(options);
      req.on('error', (e) => console.log(`[Webhook] Failed to send to ${urlObj.hostname}: ${e.message}`));
      req.on('timeout', () => { req.destroy(); });
      req.write(payload);
      req.end();
    } catch (e) {
      console.log(`[Webhook] Error sending to ${url}: ${e.message}`);
    }
  }
}

// Convenience methods for common events
const webhooks = {
  userSignup: (user) => dispatchWebhook('user_signup', {
    userId: user._id, name: user.name, handle: user.handle, city: user.city,
  }),

  postCreated: (post) => dispatchWebhook('post_created', {
    postId: post._id, authorId: post.author, type: post.type,
  }),

  postViral: (post) => dispatchWebhook('post_viral', {
    postId: post._id, viralScore: post.viralScore, likesCount: post.likesCount,
  }),

  reportFiled: (report) => dispatchWebhook('report_filed', {
    reportId: report._id, contentType: report.contentType, reason: report.reason,
  }),

  userBanned: (user, reason) => dispatchWebhook('user_banned', {
    userId: user._id, handle: user.handle, reason,
  }),

  takedownFiled: (takedown) => dispatchWebhook('takedown_filed', {
    takedownId: takedown._id, contentType: takedown.contentType,
  }),

  liveStarted: (stream) => dispatchWebhook('live_started', {
    streamId: stream._id, hostId: stream.host, title: stream.title,
  }),
};

module.exports = { dispatchWebhook, webhooks };
