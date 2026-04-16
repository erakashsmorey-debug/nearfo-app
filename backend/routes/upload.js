const express = require('express');
const router = express.Router();
const multer = require('multer');
const AWS = require('aws-sdk');
const path = require('path');
const sharp = require('sharp');
const { protect } = require('../middleware/auth');

// ===== AWS S3 CONFIG =====
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});

const S3_BUCKET = process.env.S3_MEDIA_BUCKET;
const CLOUDFRONT_DOMAIN = process.env.CLOUDFRONT_DOMAIN; // e.g. daqhrynqi5tav.cloudfront.net

// Convert S3 URL to CloudFront CDN URL for faster delivery
function toCdnUrl(s3UrlOrKey) {
  if (!CLOUDFRONT_DOMAIN) return s3UrlOrKey; // fallback: no CDN configured
  // If it's a full S3 URL, extract the key
  let key = s3UrlOrKey;
  if (s3UrlOrKey.includes('.amazonaws.com/')) {
    key = s3UrlOrKey.split('.amazonaws.com/').pop();
  } else if (s3UrlOrKey.startsWith('http')) {
    // Already a CDN or other URL, return as-is
    return s3UrlOrKey;
  }
  return `https://${CLOUDFRONT_DOMAIN}/${key}`;
}

// ===== MULTER CONFIG =====
// Store in memory for direct S3 upload
const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  const allowedTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime',
    'video/3gpp',
    'audio/mpeg',
    'audio/wav',
    'audio/ogg',
    'audio/aac',
    'audio/mp4',
  ];

  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only images, videos, and audio are allowed.'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: parseInt(process.env.MAX_UPLOAD_SIZE || 10) * 1024 * 1024, // default 10MB
  },
});

// ===== HELPER: Compress image with sharp =====
async function compressImage(buffer, mimetype, options = {}) {
  const { maxWidth = 1920, maxHeight = 1920, quality = 80 } = options;
  try {
    let transformer = sharp(buffer)
      .resize(maxWidth, maxHeight, { fit: 'inside', withoutEnlargement: true })
      .rotate(); // auto-rotate based on EXIF

    if (mimetype === 'image/jpeg' || mimetype === 'image/jpg') {
      transformer = transformer.jpeg({ quality, progressive: true });
    } else if (mimetype === 'image/png') {
      transformer = transformer.png({ quality: Math.min(quality, 90), compressionLevel: 8 });
    } else if (mimetype === 'image/webp') {
      transformer = transformer.webp({ quality });
    } else {
      // Convert HEIC/HEIF/GIF to JPEG
      transformer = transformer.jpeg({ quality, progressive: true });
    }

    return await transformer.toBuffer();
  } catch (err) {
    console.warn('[sharp] Compression failed, using original:', err.message);
    return buffer; // fallback to original if sharp fails
  }
}

// ===== HELPER: Generate thumbnail =====
async function generateThumbnail(buffer, mimetype) {
  try {
    return await sharp(buffer)
      .resize(400, 400, { fit: 'cover' })
      .jpeg({ quality: 60, progressive: true })
      .toBuffer();
  } catch (err) {
    console.warn('[sharp] Thumbnail generation failed:', err.message);
    return null;
  }
}

// ===== HELPER: Upload to S3 =====
async function uploadToS3(file, folder = 'uploads') {
  const fileExtension = path.extname(file.originalname);
  const fileName = `${folder}/${Date.now()}_${Math.random().toString(36).slice(2)}${fileExtension}`;

  // Cache-Control: media files are immutable (unique filename per upload)
  // Browser caches for 1 year, CloudFront caches for 1 year
  const isImage = file.mimetype.startsWith('image/');
  const isVideo = file.mimetype.startsWith('video/');
  const cacheMaxAge = (isImage || isVideo) ? 31536000 : 2592000; // 1yr media, 30d others

  const params = {
    Bucket: S3_BUCKET,
    Key: fileName,
    Body: file.buffer,
    ContentType: file.mimetype,
    CacheControl: `public, max-age=${cacheMaxAge}, immutable`,
  };

  const result = await s3.upload(params).promise();
  return {
    url: toCdnUrl(result.Location),
    key: result.Key,
    bucket: S3_BUCKET,
  };
}

// ===== HELPER: Delete from S3 =====
async function deleteFromS3(key) {
  const params = {
    Bucket: S3_BUCKET,
    Key: key,
  };
  await s3.deleteObject(params).promise();
}

// POST /api/upload/image
// Upload a single image (avatar, post image) — auto-compressed with thumbnail
router.post('/image', protect, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }

    const folder = req.query.folder || 'images';
    const isImage = req.file.mimetype.startsWith('image/');
    const originalBuffer = req.file.buffer; // Keep original for thumbnail generation

    // Compress image if it's an image type
    if (isImage) {
      const compressed = await compressImage(req.file.buffer, req.file.mimetype);
      req.file.buffer = compressed;
      req.file.size = compressed.length;
    }

    const result = await uploadToS3(req.file, folder);

    // Generate and upload thumbnail from ORIGINAL buffer (avoid double compression)
    let thumbnailUrl = null;
    if (isImage) {
      const thumbBuffer = await generateThumbnail(originalBuffer, req.file.mimetype);
      if (thumbBuffer) {
        const thumbFile = {
          buffer: thumbBuffer,
          originalname: `thumb_${req.file.originalname.replace(/\.[^.]+$/, '.jpg')}`,
          mimetype: 'image/jpeg',
          size: thumbBuffer.length,
        };
        const thumbResult = await uploadToS3(thumbFile, `${folder}/thumbs`);
        thumbnailUrl = thumbResult.url;
      }
    }

    res.json({
      success: true,
      url: result.url,
      key: result.key,
      thumbnailUrl,
      size: req.file.size,
      mimetype: req.file.mimetype,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/upload/images
// Upload multiple images (up to 5 for a post) — auto-compressed with thumbnails
router.post('/images', protect, upload.array('images', 5), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ success: false, message: 'No image files provided' });
    }

    const folder = req.query.folder || 'posts';

    const uploads = await Promise.all(
      req.files.map(async (file) => {
        const originalBuffer = file.buffer; // Keep original for thumbnail generation

        // Compress each image
        if (file.mimetype.startsWith('image/')) {
          const compressed = await compressImage(file.buffer, file.mimetype);
          file.buffer = compressed;
          file.size = compressed.length;
        }

        const result = await uploadToS3(file, folder);

        // Generate thumbnail from ORIGINAL buffer (avoid double compression)
        let thumbnailUrl = null;
        if (file.mimetype.startsWith('image/')) {
          const thumbBuffer = await generateThumbnail(originalBuffer, file.mimetype);
          if (thumbBuffer) {
            const thumbFile = {
              buffer: thumbBuffer,
              originalname: `thumb_${file.originalname.replace(/\.[^.]+$/, '.jpg')}`,
              mimetype: 'image/jpeg',
              size: thumbBuffer.length,
            };
            const thumbResult = await uploadToS3(thumbFile, `${folder}/thumbs`);
            thumbnailUrl = thumbResult.url;
          }
        }

        return { url: result.url, key: result.key, thumbnailUrl };
      })
    );

    res.json({
      success: true,
      images: uploads,
      count: uploads.length,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/upload/avatar
// Upload user avatar — compressed to 400x400 for fast loading
router.post('/avatar', protect, upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No avatar file provided' });
    }

    // Compress avatar to small size (avatars don't need to be large)
    if (req.file.mimetype.startsWith('image/')) {
      const compressed = await compressImage(req.file.buffer, req.file.mimetype, {
        maxWidth: 400, maxHeight: 400, quality: 85,
      });
      req.file.buffer = compressed;
      req.file.size = compressed.length;
    }

    const result = await uploadToS3(req.file, 'avatars');

    // Update user's avatar URL
    const User = require('../models/User');
    await User.findByIdAndUpdate(req.user._id, { avatarUrl: result.url });

    res.json({
      success: true,
      url: result.url,
      key: result.key,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/upload/voice
// Upload voice message for chat
router.post('/voice', protect, upload.single('voice'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No voice file provided' });
    }

    const result = await uploadToS3(req.file, 'voice');

    res.json({
      success: true,
      url: result.url,
      key: result.key,
      duration: req.body.duration || 0,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/upload
// Delete a file from S3
router.delete('/', protect, async (req, res) => {
  try {
    const { key } = req.body;

    if (!key) {
      return res.status(400).json({ success: false, message: 'File key required' });
    }

    await deleteFromS3(key);
    res.json({ success: true, message: 'File deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/upload/presigned
// Get presigned URL for large file uploads (video)
router.get('/presigned', protect, async (req, res) => {
  try {
    const { fileName, fileType, folder = 'videos' } = req.query;

    if (!fileName || !fileType) {
      return res.status(400).json({ success: false, message: 'fileName and fileType required' });
    }

    const fileExtension = path.extname(fileName);
    const key = `${folder}/${Date.now()}_${Math.random().toString(36).slice(2)}${fileExtension}`;

    const isMedia = fileType.startsWith('image/') || fileType.startsWith('video/');
    const params = {
      Bucket: S3_BUCKET,
      Key: key,
      ContentType: fileType,
      CacheControl: `public, max-age=${isMedia ? 31536000 : 2592000}, immutable`,
      Expires: 300, // 5 minutes
    };

    const presignedUrl = await s3.getSignedUrlPromise('putObject', params);

    res.json({
      success: true,
      presignedUrl,
      key,
      publicUrl: toCdnUrl(key),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Error handling for multer
router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        message: `File too large. Max size: ${process.env.MAX_UPLOAD_SIZE || 10}MB`,
      });
    }
    if (err.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        success: false,
        message: 'Too many files. Maximum 5 images allowed.',
      });
    }
    return res.status(400).json({ success: false, message: err.message });
  }
  next(err);
});

module.exports = router;
