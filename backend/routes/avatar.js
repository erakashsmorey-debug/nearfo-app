const express = require('express');
const router = express.Router();
const https = require('https');
const AWS = require('aws-sdk');
const User = require('../models/User');
const { protect } = require('../middleware/auth');

// ===== AWS S3 CONFIG =====
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});
const S3_BUCKET = process.env.S3_MEDIA_BUCKET;
const CLOUDFRONT_DOMAIN = process.env.CLOUDFRONT_DOMAIN;

function toCdnUrl(s3UrlOrKey) {
  if (!CLOUDFRONT_DOMAIN) return s3UrlOrKey;
  let key = s3UrlOrKey;
  if (s3UrlOrKey.includes('.amazonaws.com/')) {
    key = s3UrlOrKey.split('.amazonaws.com/').pop();
  } else if (s3UrlOrKey.startsWith('http')) {
    return s3UrlOrKey;
  }
  return `https://${CLOUDFRONT_DOMAIN}/${key}`;
}

// DiceBear API base URL
const DICEBEAR_BASE = 'https://api.dicebear.com/9.x';

// Supported avatar styles
const VALID_STYLES = [
  'adventurer', 'adventurer-neutral', 'avataaars', 'big-ears',
  'big-ears-neutral', 'lorelei', 'lorelei-neutral', 'notionists',
  'notionists-neutral', 'open-peeps', 'personas', 'pixel-art',
];

// Stock beautiful avatars (pre-defined seeds for each style)
const STOCK_SEEDS = [
  'Luna', 'Phoenix', 'Aurora', 'Blaze', 'Crystal', 'Mystic',
  'Storm', 'Velvet', 'Neon', 'Shadow', 'Cosmic', 'Ember',
  'Frost', 'Jade', 'Coral', 'Echo', 'Sage', 'Vibe',
  'Glow', 'Drift', 'Spark', 'Bloom', 'Stellar', 'Zephyr',
];

// POST /api/avatar/generate-variations
// Generate avatar variations with DiceBear URLs
router.post('/generate-variations', protect, async (req, res) => {
  try {
    const { style = 'adventurer', count = 12 } = req.body;

    if (!VALID_STYLES.includes(style)) {
      return res.status(400).json({ success: false, message: 'Invalid avatar style' });
    }

    const actualCount = Math.min(Math.max(count, 1), 24);

    // Generate variations using random seeds
    const variations = [];
    for (let i = 0; i < actualCount; i++) {
      const seed = `${STOCK_SEEDS[i % STOCK_SEEDS.length]}_${Date.now()}_${i}`;
      variations.push({
        seed,
        previewUrl: `${DICEBEAR_BASE}/${style}/png?seed=${encodeURIComponent(seed)}&size=256`,
      });
    }

    res.json({
      success: true,
      style,
      variations,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/avatar/generate
// Generate a single avatar URL
router.post('/generate', protect, async (req, res) => {
  try {
    const { style = 'adventurer', seed, options } = req.body;

    if (!VALID_STYLES.includes(style)) {
      return res.status(400).json({ success: false, message: 'Invalid avatar style' });
    }

    const avatarSeed = seed || `user_${req.user._id}_${Date.now()}`;
    let url = `${DICEBEAR_BASE}/${style}/png?seed=${encodeURIComponent(avatarSeed)}&size=512`;

    // Add optional customization parameters
    if (options) {
      const params = new URLSearchParams();
      Object.entries(options).forEach(([key, value]) => {
        params.append(key, String(value));
      });
      const extra = params.toString();
      if (extra) url += `&${extra}`;
    }

    res.json({ success: true, url });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/avatar/set-profile
// Download DiceBear avatar, upload to S3, set as profile picture
router.post('/set-profile', protect, async (req, res) => {
  try {
    const { style = 'adventurer', seed, options } = req.body;

    if (!seed) {
      return res.status(400).json({ success: false, message: 'Seed is required' });
    }

    if (!VALID_STYLES.includes(style)) {
      return res.status(400).json({ success: false, message: 'Invalid avatar style' });
    }

    // Build DiceBear URL
    let dicebearUrl = `${DICEBEAR_BASE}/${style}/png?seed=${encodeURIComponent(seed)}&size=512`;
    if (options) {
      Object.entries(options).forEach(([key, value]) => {
        dicebearUrl += `&${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`;
      });
    }

    // Download the avatar image from DiceBear using built-in https
    const imageBuffer = await new Promise((resolve, reject) => {
      const request = https.get(dicebearUrl, { timeout: 15000 }, (response) => {
        // Follow redirects
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          https.get(response.headers.location, { timeout: 15000 }, (redirectRes) => {
            const chunks = [];
            redirectRes.on('data', (chunk) => chunks.push(chunk));
            redirectRes.on('end', () => resolve(Buffer.concat(chunks)));
            redirectRes.on('error', reject);
          }).on('error', reject);
          return;
        }
        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => resolve(Buffer.concat(chunks)));
        response.on('error', reject);
      });
      request.on('error', reject);
      request.on('timeout', () => { request.destroy(); reject(new Error('Download timeout')); });
    });

    // Upload to S3
    const fileName = `avatars/${req.user._id}_${Date.now()}.png`;
    const uploadParams = {
      Bucket: S3_BUCKET,
      Key: fileName,
      Body: imageBuffer,
      ContentType: 'image/png',
      CacheControl: 'public, max-age=86400, must-revalidate', // 24h (avatars change)
    };

    const uploadResult = await s3.upload(uploadParams).promise();
    const avatarUrl = toCdnUrl(uploadResult.Location);

    // Update user profile
    await User.findByIdAndUpdate(req.user._id, { avatarUrl });

    res.json({
      success: true,
      url: avatarUrl,
      message: 'Avatar set as profile picture',
    });
  } catch (error) {
    console.error('Avatar set-profile error:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/avatar/stock
// Get stock beautiful avatars for all styles
router.get('/stock', protect, async (req, res) => {
  try {
    const { style } = req.query;
    const styles = style ? [style] : ['adventurer', 'lorelei', 'avataaars', 'big-ears', 'notionists', 'pixel-art'];

    const stock = {};
    styles.forEach((s) => {
      if (!VALID_STYLES.includes(s)) return;
      stock[s] = STOCK_SEEDS.slice(0, 12).map((seed) => ({
        seed,
        previewUrl: `${DICEBEAR_BASE}/${s}/png?seed=${encodeURIComponent(seed)}&size=256`,
        fullUrl: `${DICEBEAR_BASE}/${s}/png?seed=${encodeURIComponent(seed)}&size=512`,
      }));
    });

    res.json({ success: true, stock });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
