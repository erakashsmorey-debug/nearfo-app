const express = require('express');
const router = express.Router();
const CallLog = require('../models/CallLog');
const { protect } = require('../middleware/auth');
const crypto = require('crypto');
const https = require('https');

// GET /api/calls/pending — Get pending incoming call offer (for push-wakeup flow)
router.get('/pending', protect, async (req, res) => {
  try {
    const app = req.app;
    const pendingCalls = app.get('pendingCalls');
    if (!pendingCalls) {
      return res.json({ success: true, pending: null });
    }

    const userId = req.user._id.toString();
    const pending = pendingCalls.get(userId);

    if (pending) {
      return res.json({
        success: true,
        pending: {
          offer: pending.offer,
          callerId: pending.callerId,
          callerName: pending.callerName,
          callerAvatar: pending.callerAvatar,
          isVideo: pending.isVideo,
        },
      });
    }
    res.json({ success: true, pending: null });
  } catch (err) {
    res.status(500).json({ message: 'Failed to get pending call', error: err.message });
  }
});

// Helper: make HTTPS GET request (uses native https module — no external deps needed)
function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (resp) => {
      let data = '';
      resp.on('data', (chunk) => data += chunk);
      resp.on('end', () => {
        try { resolve({ ok: resp.statusCode >= 200 && resp.statusCode < 300, json: JSON.parse(data) }); }
        catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

// Helper: make HTTPS POST request
function httpsPost(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const options = { hostname: parsed.hostname, path: parsed.pathname + parsed.search, method: 'POST', headers };
    const req = https.request(options, (resp) => {
      let data = '';
      resp.on('data', (chunk) => data += chunk);
      resp.on('end', () => {
        try { resolve({ ok: resp.statusCode >= 200 && resp.statusCode < 300, json: JSON.parse(data) }); }
        catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

// GET /api/calls/turn-credentials — Get TURN server credentials for WebRTC
router.get('/turn-credentials', protect, async (req, res) => {
  try {
    // If you have a Metered.ca API key, use it for TURN credentials
    const meteredApiKey = process.env.METERED_API_KEY;
    if (meteredApiKey) {
      try {
        const result = await httpsGet(`https://nearfo.metered.live/api/v1/turn/credentials?apiKey=${meteredApiKey}`);
        if (result.ok) {
          return res.json({ success: true, iceServers: result.json });
        }
      } catch (e) {
        console.log('[TURN] Metered.ca fetch failed:', e.message);
      }
    }

    // If you have Twilio credentials, use Twilio's TURN (more reliable)
    const twilioSid = process.env.TWILIO_ACCOUNT_SID;
    const twilioToken = process.env.TWILIO_AUTH_TOKEN;
    if (twilioSid && twilioToken) {
      try {
        const auth = Buffer.from(`${twilioSid}:${twilioToken}`).toString('base64');
        const result = await httpsPost(
          `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Tokens.json`,
          { 'Authorization': `Basic ${auth}` }
        );
        if (result.ok) {
          return res.json({ success: true, iceServers: result.json.ice_servers });
        }
      } catch (e) {
        console.log('[TURN] Twilio fetch failed:', e.message);
      }
    }

    // If you have a self-hosted coturn with shared secret
    const turnSecret = process.env.TURN_SECRET;
    const turnDomain = process.env.TURN_DOMAIN;
    if (turnSecret && turnDomain) {
      // Generate time-limited TURN credentials using shared secret (RFC 5766)
      const ttl = 86400; // 24 hours
      const timestamp = Math.floor(Date.now() / 1000) + ttl;
      const username = `${timestamp}:nearfo`;
      const hmac = crypto.createHmac('sha1', turnSecret);
      hmac.update(username);
      const credential = hmac.digest('base64');

      return res.json({
        success: true,
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' },
          { urls: 'stun:stun1.l.google.com:19302' },
          {
            urls: `turn:${turnDomain}:3478`,
            username: username,
            credential: credential,
          },
          {
            urls: `turn:${turnDomain}:443?transport=tcp`,
            username: username,
            credential: credential,
          },
        ],
      });
    }

    // Fallback: return Google STUN servers only (no TURN — works on same network/WiFi)
    res.json({
      success: true,
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        { urls: 'stun:stun2.l.google.com:19302' },
        { urls: 'stun:stun3.l.google.com:19302' },
        { urls: 'stun:stun4.l.google.com:19302' },
      ],
      turnAvailable: false,
      message: 'No TURN server configured. Set METERED_API_KEY, TWILIO_ACCOUNT_SID+TWILIO_AUTH_TOKEN, or TURN_SECRET+TURN_DOMAIN in env.',
    });
  } catch (err) {
    // On error, still return STUN so calls work on same network
    res.json({
      success: true,
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
      ],
      turnAvailable: false,
    });
  }
});

// GET /api/calls — Get call history
router.get('/', protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const skip = (page - 1) * limit;

    const logs = await CallLog.find({
      $or: [{ caller: req.user._id }, { receiver: req.user._id }],
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('caller', 'name handle avatarUrl')
      .populate('receiver', 'name handle avatarUrl')
      .lean();

    const total = await CallLog.countDocuments({
      $or: [{ caller: req.user._id }, { receiver: req.user._id }],
    });

    res.json({
      success: true,
      calls: logs,
      hasMore: skip + logs.length < total,
      total,
    });
  } catch (err) {
    res.status(500).json({ message: 'Failed to get call history', error: err.message });
  }
});

// POST /api/calls — Log a call
router.post('/', protect, async (req, res) => {
  try {
    const { receiverId, type, status, duration } = req.body;
    const log = await CallLog.create({
      caller: req.user._id,
      receiver: receiverId,
      type: type || 'audio',
      status: status || 'missed',
      duration: duration || 0,
      endedAt: new Date(),
    });
    res.json({ success: true, callLog: log });
  } catch (err) {
    res.status(500).json({ message: 'Failed to log call', error: err.message });
  }
});

// DELETE /api/calls/:id — Delete a call log
router.delete('/:id', protect, async (req, res) => {
  try {
    await CallLog.findOneAndDelete({
      _id: req.params.id,
      $or: [{ caller: req.user._id }, { receiver: req.user._id }],
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: 'Failed to delete call log', error: err.message });
  }
});

module.exports = router;
