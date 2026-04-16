const express = require('express');
const router = express.Router();
const Post = require('../models/Post');
const User = require('../models/User');
const Follow = require('../models/Follow');
const Notification = require('../models/Notification');
const { protect } = require('../middleware/auth');
const { decryptUserData } = require('../utils/encryption');
const { cacheGet, cacheSet, cacheDel } = require('../config/redis');
const { moderateContent } = require('../middleware/contentModeration');

// Helper: decrypt populated author fields in a post object
function decryptPostAuthor(postObj) {
  if (postObj && postObj.author && typeof postObj.author === 'object') {
    decryptUserData(postObj.author);
  }
  return postObj;
}

const NEARFO_RADIUS_KM = parseInt(process.env.NEARFO_RADIUS_KM) || 500;
const EARTH_RADIUS_KM = 6371;

// ===== VIRAL SCORE ALGORITHM =====
// Instagram-like viral scoring: engagement velocity + time decay
// Higher score = more viral. Score decays with age to keep content fresh.
function calculateViralScore(post) {
  const now = Date.now();
  const ageInHours = (now - new Date(post.createdAt).getTime()) / (1000 * 60 * 60);

  // Engagement weights (shares > comments > likes > bookmarks > views)
  const engagementScore =
    (post.likesCount || 0) * 3 +
    (post.commentsCount || 0) * 5 +
    (post.sharesCount || 0) * 7 +
    (post.bookmarksCount || 0) * 4 +
    (post.viewsCount || 0) * 0.5;

  // Engagement rate = engagement per view (quality signal)
  const views = Math.max(post.viewsCount || 1, 1);
  const engagementRate = ((post.likesCount || 0) + (post.commentsCount || 0) + (post.sharesCount || 0)) / views;
  const rateBonus = engagementRate * 50; // max ~50 bonus points

  // Time decay: posts lose score as they age
  // Gravity factor — higher = faster decay
  const gravity = 1.5;
  const timeFactor = Math.pow(ageInHours + 2, gravity);

  // Velocity bonus: engagement earned in first few hours = big boost
  const isNew = ageInHours < 6;
  const velocityMultiplier = isNew ? 2.0 : 1.0;

  // Promoted posts get a small static boost
  const promoBoost = post.isPromoted ? 20 : 0;

  // Has media? Media posts tend to go viral more
  const mediaBoost = (post.images?.length > 0 || post.video) ? 10 : 0;

  const score = ((engagementScore + rateBonus + promoBoost + mediaBoost) * velocityMultiplier) / timeFactor;

  return Math.round(score * 1000) / 1000; // 3 decimal precision
}

// GET /api/posts/feed
// Get mixed feed: 80% local (500km) + 20% global
// Supports both page-based (?page=2) and cursor-based (?cursor=<postId>) pagination
router.get('/feed', protect, async (req, res) => {
  try {
    const { page = 1, limit = 20, mode = 'mixed', cursor } = req.query;
    const skip = cursor ? 0 : (page - 1) * limit; // cursor mode skips page-based offset
    const userCoords = req.user.location?.coordinates || [0, 0];
    const [lng, lat] = userCoords;

    // Cursor filter: only show posts older than the cursor post
    let cursorFilter = {};
    if (cursor) {
      const cursorPost = await Post.findById(cursor).select('createdAt');
      if (cursorPost) {
        cursorFilter = { createdAt: { $lt: cursorPost.createdAt } };
      }
    }

    let posts = [];

    // ===== FOLLOWING FEED =====
    if (mode === 'following') {
      const myFollows = await Follow.find({ follower: req.user._id }).select('following');
      const followingIds = myFollows.map(f => f.following);

      const followingPosts = await Post.find({
        author: { $in: followingIds },
        isHidden: false,
        type: { $ne: 'story' },
        ...cursorFilter,
      })
        .populate('author', 'name handle avatarUrl isVerified city nearfoScore')
        .sort({ createdAt: -1 })
        .limit(parseInt(limit))
        .skip(skip);

      posts = followingPosts.map(p => {
        const obj = p.toObject();
        decryptPostAuthor(obj);
        const [pLng, pLat] = obj.location?.coordinates || [0, 0];
        const distance = (lng === 0 && lat === 0) ? 0 : calculateDistance(lat, lng, pLat, pLng);
        return {
          ...obj,
          feedType: 'following',
          distanceKm: Math.round(distance * 10) / 10,
          isLiked: obj.likes.some(id => id.toString() === req.user._id.toString()),
          isBookmarked: obj.bookmarks.some(id => id.toString() === req.user._id.toString()),
        };
      });

      const nextCursor = cursor && posts.length > 0 ? posts[posts.length - 1]._id : undefined;
      return res.json({ success: true, posts, page: parseInt(page), hasMore: posts.length === parseInt(limit), ...(nextCursor && { nextCursor }) });
    }

    if (mode === 'local' || mode === 'mixed') {
      // LOCAL POSTS: within 500km radius using MongoDB geospatial query
      const localPosts = await Post.find({
        isHidden: false,
        type: { $ne: 'story' },
        ...cursorFilter,
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

      posts.push(...localPosts.map(p => {
        const obj = p.toObject();
        decryptPostAuthor(obj);
        return {
          ...obj,
          feedType: 'local',
          isLiked: obj.likes.some(id => id.toString() === req.user._id.toString()),
          isBookmarked: obj.bookmarks.some(id => id.toString() === req.user._id.toString()),
        };
      }));
    }

    if (mode === 'global' || mode === 'mixed') {
      // GLOBAL POSTS: outside 500km, sorted by engagement
      const globalPosts = await Post.find({
        isHidden: false,
        type: { $ne: 'story' },
        ...cursorFilter,
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

      posts.push(...globalPosts.map(p => {
        const obj = p.toObject();
        decryptPostAuthor(obj);
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
      posts.sort(() => Math.random() - 0.5);
    }

    // Add distance info
    posts = posts.map(post => {
      const [pLng, pLat] = post.location?.coordinates || [0, 0];
      const distance = (lng === 0 && lat === 0) ? 0 : calculateDistance(lat, lng, pLat, pLng);
      return { ...post, distanceKm: Math.round(distance * 10) / 10 };
    });

    // Cursor for next page (only in cursor mode)
    const response = { success: true, posts, page: parseInt(page), hasMore: posts.length === parseInt(limit) };
    if (cursor && posts.length > 0) {
      response.nextCursor = posts[posts.length - 1]._id;
    }
    res.json(response);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/posts
// Create a new post (with AI content moderation)
router.post('/', protect, moderateContent, async (req, res) => {
  try {
    const { content, images, video, mood, hashtags, visibility } = req.body;

    if ((!content || content.trim().length === 0) && (!images || images.length === 0) && !video) {
      return res.status(400).json({ success: false, message: 'Content, images, or video is required' });
    }

    const post = await Post.create({
      author: req.user._id,
      content: (content || '').trim(),
      images: images || [],
      video: video || undefined,
      mood: mood || '',
      hashtags: hashtags || extractHashtags(content || ''),
      mentions: extractMentions(content || ''),
      visibility: visibility || 'public',
      location: req.user.location,
      city: req.user.city,
      state: req.user.state,
    });

    // Update user post count + invalidate caches
    await User.findByIdAndUpdate(req.user._id, { $inc: { postsCount: 1 } });
    await cacheDel('trending:*');

    const populated = await post.populate('author', 'name handle avatarUrl isVerified city');
    const postObj = populated.toObject();
    decryptPostAuthor(postObj);

    res.status(201).json({ success: true, post: postObj });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/posts/:id/like
router.post('/:id/like', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    const isLiked = post.likes.includes(req.user._id);

    if (isLiked) {
      post.likes.pull(req.user._id);
      post.likesCount = Math.max(0, post.likesCount - 1);
    } else {
      post.likes.push(req.user._id);
      post.likesCount += 1;

      // Send notification + push (don't notify yourself)
      if (post.author.toString() !== req.user._id.toString()) {
        await Notification.create({
          recipient: post.author,
          sender: req.user._id,
          type: 'like',
          post: post._id,
        });
        const { push } = require('../utils/pushNotify');
        push.like(post.author.toString(), req.user.name);
      }
    }

    // Recalculate viral score on like/unlike
    post.viralScore = calculateViralScore(post);
    post.lastViralCalc = new Date();

    await post.save();
    res.json({ success: true, isLiked: !isLiked, likesCount: post.likesCount, viralScore: post.viralScore });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/posts/trending/posts — Get viral/trending posts
// NOTE: This MUST be defined BEFORE /:id route to avoid Express treating 'trending' as a post ID
router.get('/trending/posts', protect, async (req, res) => {
  try {
    const { page = 1, limit = 20, timeWindow = '24h', scope = 'all' } = req.query;
    const skip = (page - 1) * parseInt(limit);

    // Time window filter
    let timeFilter = {};
    switch (timeWindow) {
      case '1h':
        timeFilter = { createdAt: { $gte: new Date(Date.now() - 1 * 60 * 60 * 1000) } };
        break;
      case '6h':
        timeFilter = { createdAt: { $gte: new Date(Date.now() - 6 * 60 * 60 * 1000) } };
        break;
      case '24h':
        timeFilter = { createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } };
        break;
      case '7d':
        timeFilter = { createdAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } };
        break;
      case '30d':
        timeFilter = { createdAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) } };
        break;
      default:
        timeFilter = { createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } };
    }

    // Location scope
    const userCoords = req.user.location?.coordinates || [0, 0];
    let locationFilter = {};
    if (scope === 'local' && userCoords[0] !== 0 && userCoords[1] !== 0) {
      const [lng, lat] = userCoords;
      locationFilter = {
        location: {
          $geoWithin: {
            $centerSphere: [[lng, lat], NEARFO_RADIUS_KM / EARTH_RADIUS_KM],
          },
        },
      };
    }

    // First, recalculate viral scores for recent posts (batch update)
    const recentPosts = await Post.find({
      ...timeFilter,
      isHidden: false,
      visibility: 'public',
      ...locationFilter,
    });

    // Batch update viral scores
    const bulkOps = recentPosts.map(post => ({
      updateOne: {
        filter: { _id: post._id },
        update: {
          $set: {
            viralScore: calculateViralScore(post),
            lastViralCalc: new Date(),
          },
        },
      },
    }));

    if (bulkOps.length > 0) {
      await Post.bulkWrite(bulkOps);
    }

    // Now fetch sorted by viralScore
    const posts = await Post.find({
      ...timeFilter,
      isHidden: false,
      visibility: 'public',
      ...locationFilter,
    })
      .populate('author', 'name handle avatarUrl isVerified city nearfoScore')
      .sort({ viralScore: -1, likesCount: -1 })
      .limit(parseInt(limit))
      .skip(skip);

    // Add distance + isLiked info
    const [tLng, tLat] = req.user.location?.coordinates || [0, 0];
    const enrichedPosts = posts.map(p => {
      const post = p.toObject();
      decryptPostAuthor(post);
      const [pLng, pLat] = post.location?.coordinates || [0, 0];
      const distance = (tLng === 0 && tLat === 0) ? 0 : calculateDistance(tLat, tLng, pLat, pLng);
      return {
        ...post,
        distanceKm: Math.round(distance * 10) / 10,
        feedType: distance <= NEARFO_RADIUS_KM ? 'local' : 'global',
        isLiked: post.likes.some(id => id.toString() === req.user._id.toString()),
        isBookmarked: post.bookmarks.some(id => id.toString() === req.user._id.toString()),
      };
    });

    res.json({
      success: true,
      posts: enrichedPosts,
      page: parseInt(page),
      hasMore: posts.length === parseInt(limit),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/posts/trending/hashtags
// NOTE: This MUST also be before /:id route
router.get('/trending/hashtags', protect, async (req, res) => {
  try {
    // Check cache first (trending doesn't change frequently)
    const cached = await cacheGet('trending:hashtags');
    if (cached) return res.json({ success: true, trending: cached });

    const trending = await Post.aggregate([
      {
        $match: {
          createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
          isHidden: false,
        },
      },
      { $unwind: '$hashtags' },
      { $group: { _id: '$hashtags', count: { $sum: 1 }, totalLikes: { $sum: '$likesCount' } } },
      { $sort: { count: -1 } },
      { $limit: 10 },
    ]);
    // Cache for 10 minutes
    await cacheSet('trending:hashtags', trending, 600);
    res.json({ success: true, trending });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/posts/hashtag/:tag — Get posts by hashtag (dedicated hashtag feed)
// NOTE: MUST be before /:id route
router.get('/hashtag/:tag', protect, async (req, res) => {
  try {
    const tag = req.params.tag.toLowerCase().replace(/^#/, '');
    const { page = 1, limit = 20, sort = 'recent' } = req.query;
    const skip = (page - 1) * parseInt(limit);

    const sortOption = sort === 'top'
      ? { likesCount: -1, createdAt: -1 }
      : { createdAt: -1 };

    const posts = await Post.find({
      hashtags: tag,
      isHidden: false,
      type: { $ne: 'story' },
    })
      .populate('author', 'name handle avatarUrl isVerified city nearfoScore')
      .sort(sortOption)
      .skip(skip)
      .limit(parseInt(limit));

    const totalPosts = await Post.countDocuments({
      hashtags: tag,
      isHidden: false,
      type: { $ne: 'story' },
    });

    const enrichedPosts = posts.map(p => {
      const obj = p.toObject();
      decryptPostAuthor(obj);
      return {
        ...obj,
        isLiked: obj.likes.some(id => id.toString() === req.user._id.toString()),
        isBookmarked: obj.bookmarks.some(id => id.toString() === req.user._id.toString()),
      };
    });

    res.json({
      success: true,
      hashtag: tag,
      posts: enrichedPosts,
      totalPosts,
      page: parseInt(page),
      hasMore: skip + posts.length < totalPosts,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/posts/saved/list — Get user's bookmarked posts
// NOTE: MUST be before /:id route to avoid Express treating 'saved' as a post ID
router.get('/saved/list', protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const posts = await Post.find({ bookmarks: req.user._id })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('author', 'name handle avatarUrl');

    const results = posts.map(p => {
      const obj = p.toObject();
      decryptPostAuthor(obj);
      obj.isLiked = obj.likes.some(id => id.toString() === req.user._id.toString());
      obj.isBookmarked = true;
      return obj;
    });

    res.json({ success: true, posts: results });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/posts/:id
router.get('/:id', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id)
      .populate('author', 'name handle avatarUrl isVerified city nearfoScore');
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    const postObj = post.toObject();
    decryptPostAuthor(postObj);
    res.json({ success: true, post: postObj });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/posts/:id - Edit post caption/content
router.put('/:id', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    if (post.author.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    // Only allow editing content, mood, hashtags, visibility (not media)
    if (req.body.content !== undefined) {
      post.content = req.body.content.trim();
      post.hashtags = extractHashtags(post.content);
      post.mentions = extractMentions(post.content);
    }
    if (req.body.mood !== undefined) post.mood = req.body.mood;
    if (req.body.visibility) post.visibility = req.body.visibility;

    post.isEdited = true;
    post.editedAt = new Date();
    await post.save();

    const populated = await post.populate('author', 'name handle avatarUrl isVerified city');
    const postObj = populated.toObject();
    decryptPostAuthor(postObj);

    res.json({ success: true, post: postObj });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/posts/:id
router.delete('/:id', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    if (post.author.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    await post.deleteOne();
    await User.findByIdAndUpdate(req.user._id, { $inc: { postsCount: -1 } });
    res.json({ success: true, message: 'Post deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/posts/:id/view — Record a view (unique per user)
router.post('/:id/view', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    // Only count unique views
    const alreadyViewed = post.viewers.includes(req.user._id);
    if (!alreadyViewed) {
      post.viewers.push(req.user._id);
      post.viewsCount += 1;
    }

    // Recalculate viral score
    post.viralScore = calculateViralScore(post);
    post.lastViralCalc = new Date();
    await post.save();

    res.json({ success: true, viewsCount: post.viewsCount, viralScore: post.viralScore });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/posts/:id/share — Record a share
router.post('/:id/share', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    post.sharesCount += 1;

    // Recalculate viral score
    post.viralScore = calculateViralScore(post);
    post.lastViralCalc = new Date();
    await post.save();

    // Notify post author about share
    if (post.author.toString() !== req.user._id.toString()) {
      await Notification.create({
        recipient: post.author,
        sender: req.user._id,
        type: 'share',
        post: post._id,
      });
    }

    res.json({ success: true, sharesCount: post.sharesCount, viralScore: post.viralScore });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/posts/:id/bookmark — Toggle bookmark
router.post('/:id/bookmark', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    const isBookmarked = post.bookmarks.includes(req.user._id);

    if (isBookmarked) {
      post.bookmarks.pull(req.user._id);
      post.bookmarksCount = Math.max(0, post.bookmarksCount - 1);
    } else {
      post.bookmarks.push(req.user._id);
      post.bookmarksCount += 1;
    }

    // Recalculate viral score (bookmarks contribute to engagement)
    post.viralScore = calculateViralScore(post);
    post.lastViralCalc = new Date();

    await post.save();
    res.json({ success: true, isBookmarked: !isBookmarked, bookmarksCount: post.bookmarksCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== UTILITY FUNCTIONS =====
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

function extractHashtags(text) {
  const matches = text.match(/#(\w+)/g);
  return matches ? matches.map(m => m.slice(1).toLowerCase()) : [];
}

function extractMentions(text) {
  // Returns handles, needs to be resolved to user IDs
  const matches = text.match(/@(\w+)/g);
  return matches ? matches.map(m => m.slice(1).toLowerCase()) : [];
}

module.exports = router;
