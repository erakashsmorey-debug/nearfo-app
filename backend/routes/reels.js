const express = require('express');
const router = express.Router();
const Reel = require('../models/Reel');
const User = require('../models/User');
const Follow = require('../models/Follow');
const Notification = require('../models/Notification');
const { protect } = require('../middleware/auth');
const { decryptUserData } = require('../utils/encryption');

const NEARFO_RADIUS_KM = parseInt(process.env.NEARFO_RADIUS_KM) || 500;
const EARTH_RADIUS_KM = 6371;

// ===== GET /api/reels/feed =====
// Modes: mixed (default), local, global, following
router.get('/feed', protect, async (req, res) => {
  try {
    const { page = 1, limit = 10, mode = 'mixed' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const userCoords = req.user.location?.coordinates || [0, 0];
    const [lng, lat] = userCoords;

    let reels = [];

    // ===== FOLLOWING FEED =====
    if (mode === 'following') {
      const myFollows = await Follow.find({ follower: req.user._id }).select('following');
      const followingIds = myFollows.map(f => f.following);

      reels = await Reel.find({
        author: { $in: followingIds },
        isHidden: false,
      })
        .populate('author', 'name handle avatarUrl isVerified city nearfoScore')
        .sort({ createdAt: -1 })
        .limit(parseInt(limit))
        .skip(skip);

      reels = reels.map(r => {
        const obj = r.toObject();
        const [rLng, rLat] = obj.location?.coordinates || [0, 0];
        const dist = (lng === 0 && lat === 0) ? 0 : calculateDistance(lat, lng, rLat, rLng);
        return {
          ...obj,
          feedType: 'following',
          distanceKm: Math.round(dist * 10) / 10,
          isLiked: obj.likes.some(id => id.toString() === req.user._id.toString()),
          isBookmarked: obj.bookmarks.some(id => id.toString() === req.user._id.toString()),
        };
      });

      return res.json({ success: true, reels, page: parseInt(page), hasMore: reels.length === parseInt(limit) });
    }

    // ===== LOCAL / MIXED / GLOBAL FEED =====
    if (mode === 'local' || mode === 'mixed') {
      const localReels = await Reel.find({
        isHidden: false,
        location: {
          $geoWithin: {
            $centerSphere: [[lng, lat], NEARFO_RADIUS_KM / EARTH_RADIUS_KM],
          },
        },
      })
        .populate('author', 'name handle avatarUrl isVerified city nearfoScore')
        .sort({ createdAt: -1 })
        .limit(mode === 'local' ? parseInt(limit) : Math.ceil(limit * 0.8))
        .skip(skip);

      reels.push(...localReels.map(r => {
        const obj = r.toObject();
        return {
          ...obj,
          feedType: 'local',
          isLiked: obj.likes.some(id => id.toString() === req.user._id.toString()),
          isBookmarked: obj.bookmarks.some(id => id.toString() === req.user._id.toString()),
        };
      }));
    }

    if (mode === 'global' || mode === 'mixed') {
      const globalReels = await Reel.find({
        isHidden: false,
        location: {
          $not: {
            $geoWithin: {
              $centerSphere: [[lng, lat], NEARFO_RADIUS_KM / EARTH_RADIUS_KM],
            },
          },
        },
      })
        .populate('author', 'name handle avatarUrl isVerified city nearfoScore')
        .sort({ likesCount: -1, createdAt: -1 })
        .limit(mode === 'global' ? parseInt(limit) : Math.floor(limit * 0.2))
        .skip(skip);

      reels.push(...globalReels.map(r => {
        const obj = r.toObject();
        return {
          ...obj,
          feedType: 'global',
          isLiked: obj.likes.some(id => id.toString() === req.user._id.toString()),
          isBookmarked: obj.bookmarks.some(id => id.toString() === req.user._id.toString()),
        };
      }));
    }

    // Shuffle for mixed mode
    if (mode === 'mixed') {
      reels.sort(() => Math.random() - 0.5);
    }

    // Add distance info
    reels = reels.map(reel => {
      const [rLng, rLat] = reel.location?.coordinates || [0, 0];
      const distance = (lng === 0 && lat === 0) ? 0 : calculateDistance(lat, lng, rLat, rLng);
      return { ...reel, distanceKm: Math.round(distance * 10) / 10 };
    });

    res.json({ success: true, reels, page: parseInt(page), hasMore: reels.length === parseInt(limit) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== POST /api/reels =====
// Create a new reel
router.post('/', protect, async (req, res) => {
  try {
    const { videoUrl, thumbnailUrl, caption, audioName, duration, visibility } = req.body;

    if (!videoUrl) {
      return res.status(400).json({ success: false, message: 'Video URL is required' });
    }

    const reel = await Reel.create({
      author: req.user._id,
      videoUrl,
      thumbnailUrl: thumbnailUrl || '',
      caption: (caption || '').trim(),
      audioName: audioName || '',
      duration: duration || 0,
      hashtags: extractHashtags(caption || ''),
      visibility: visibility || 'public',
      location: req.user.location,
      city: req.user.city,
      state: req.user.state,
    });

    const populated = await reel.populate('author', 'name handle avatarUrl isVerified city');

    res.status(201).json({ success: true, reel: populated });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== POST /api/reels/:id/like =====
router.post('/:id/like', protect, async (req, res) => {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.status(404).json({ success: false, message: 'Reel not found' });

    const isLiked = reel.likes.includes(req.user._id);

    if (isLiked) {
      reel.likes.pull(req.user._id);
      reel.likesCount = Math.max(0, reel.likesCount - 1);
    } else {
      reel.likes.push(req.user._id);
      reel.likesCount += 1;

      if (reel.author.toString() !== req.user._id.toString()) {
        await Notification.create({
          recipient: reel.author,
          sender: req.user._id,
          type: 'like',
          post: reel._id,
        });
      }
    }

    await reel.save();
    res.json({ success: true, isLiked: !isLiked, likesCount: reel.likesCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== POST /api/reels/:id/view =====
router.post('/:id/view', protect, async (req, res) => {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.status(404).json({ success: false, message: 'Reel not found' });

    const alreadyViewed = reel.viewers.includes(req.user._id);
    if (!alreadyViewed) {
      reel.viewers.push(req.user._id);
      reel.viewsCount += 1;
    }

    await reel.save();
    res.json({ success: true, viewsCount: reel.viewsCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== GET /api/reels/saved/list — Get user's bookmarked reels =====
router.get('/saved/list', protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const reels = await Reel.find({ bookmarks: req.user._id })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('author', 'name handle avatarUrl');

    const results = reels.map(r => {
      const obj = r.toObject();
      if (obj.author && typeof obj.author === 'object') {
        decryptUserData(obj.author);
      }
      obj.isLiked = obj.likes.some(id => id.toString() === req.user._id.toString());
      obj.isBookmarked = true;
      return obj;
    });

    res.json({ success: true, reels: results });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== POST /api/reels/:id/bookmark =====
router.post('/:id/bookmark', protect, async (req, res) => {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.status(404).json({ success: false, message: 'Reel not found' });

    const isBookmarked = reel.bookmarks.includes(req.user._id);

    if (isBookmarked) {
      reel.bookmarks.pull(req.user._id);
      reel.bookmarksCount = Math.max(0, reel.bookmarksCount - 1);
    } else {
      reel.bookmarks.push(req.user._id);
      reel.bookmarksCount += 1;
    }

    await reel.save();
    res.json({ success: true, isBookmarked: !isBookmarked, bookmarksCount: reel.bookmarksCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== DELETE /api/reels/:id =====
router.delete('/:id', protect, async (req, res) => {
  try {
    const reel = await Reel.findById(req.params.id);
    if (!reel) return res.status(404).json({ success: false, message: 'Reel not found' });
    if (reel.author.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    await reel.deleteOne();
    res.json({ success: true, message: 'Reel deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== GET /api/reels/:id =====
router.get('/:id', protect, async (req, res) => {
  try {
    const reel = await Reel.findById(req.params.id)
      .populate('author', 'name handle avatarUrl isVerified city nearfoScore');
    if (!reel) return res.status(404).json({ success: false, message: 'Reel not found' });
    res.json({ success: true, reel });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== UTILITY =====
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function extractHashtags(text) {
  const matches = text.match(/#(\w+)/g);
  return matches ? matches.map(m => m.slice(1).toLowerCase()) : [];
}

module.exports = router;
