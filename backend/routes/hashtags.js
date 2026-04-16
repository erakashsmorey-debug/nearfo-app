const express = require('express');
const router = express.Router();
const Post = require('../models/Post');
const { protect } = require('../middleware/auth');

// GET /api/hashtags/trending — Get trending hashtags
router.get('/trending', protect, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;

    // Aggregate hashtags from recent posts (last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const trending = await Post.aggregate([
      { $match: { createdAt: { $gte: sevenDaysAgo }, type: { $ne: 'story' } } },
      { $project: { hashtags: { $ifNull: ['$hashtags', []] }, content: 1 } },
      { $unwind: '$hashtags' },
      { $group: { _id: { $toLower: '$hashtags' }, count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: limit },
      { $project: { _id: 0, tag: '$_id', count: 1 } },
    ]);

    // If no hashtags found, return popular defaults
    if (trending.length === 0) {
      const defaults = [
        { tag: 'nearfo', count: 100 },
        { tag: 'trending', count: 85 },
        { tag: 'explore', count: 72 },
        { tag: 'local', count: 65 },
        { tag: 'mycircle', count: 58 },
        { tag: 'viral', count: 50 },
        { tag: 'reels', count: 45 },
        { tag: 'photooftheday', count: 40 },
        { tag: 'life', count: 35 },
        { tag: 'vibes', count: 30 },
      ];
      return res.json({ success: true, hashtags: defaults });
    }

    res.json({ success: true, hashtags: trending });
  } catch (err) {
    res.status(500).json({ message: 'Failed to get trending hashtags', error: err.message });
  }
});

// GET /api/hashtags/search — Search hashtags
router.get('/search', protect, async (req, res) => {
  try {
    const query = req.query.q || '';
    if (query.length < 1) return res.json({ success: true, hashtags: [] });

    const results = await Post.aggregate([
      { $project: { hashtags: { $ifNull: ['$hashtags', []] } } },
      { $unwind: '$hashtags' },
      { $match: { hashtags: { $regex: query, $options: 'i' } } },
      { $group: { _id: { $toLower: '$hashtags' }, count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 20 },
      { $project: { _id: 0, tag: '$_id', count: 1 } },
    ]);

    res.json({ success: true, hashtags: results });
  } catch (err) {
    res.status(500).json({ message: 'Failed to search hashtags', error: err.message });
  }
});

// GET /api/hashtags/:tag/feed — Get posts for a hashtag
router.get('/:tag/feed', protect, async (req, res) => {
  try {
    const tag = req.params.tag.toLowerCase();
    const page = parseInt(req.query.page) || 1;
    const limit = 20;
    const skip = (page - 1) * limit;
    const sort = req.query.sort === 'top' ? { likes: -1 } : { createdAt: -1 };

    const query = {
      $or: [
        { hashtags: { $regex: new RegExp(`^${tag}$`, 'i') } },
        { content: { $regex: `#${tag}`, $options: 'i' } },
      ],
      type: { $ne: 'story' },
    };

    const [posts, total] = await Promise.all([
      Post.find(query)
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .populate('author', 'name handle avatarUrl location')
        .lean(),
      Post.countDocuments(query),
    ]);

    res.json({
      success: true,
      posts,
      totalPosts: total,
      hasMore: skip + posts.length < total,
    });
  } catch (err) {
    res.status(500).json({ message: 'Failed to get hashtag feed', error: err.message });
  }
});

module.exports = router;
