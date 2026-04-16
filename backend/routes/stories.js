const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { moderateContent } = require('../middleware/contentModeration');
const { decryptUserData } = require('../utils/encryption');

// POST /api/stories - Create story (with moderation)
router.post('/', protect, moderateContent, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const { mediaUrl, mediaType, caption, duration, content, mediaUrls } = req.body;

    // Support both Flutter app format (mediaUrl/mediaType/caption) and legacy format (content/mediaUrls)
    const storyContent = caption || content || '';
    const storyVideo = mediaType === 'video' ? mediaUrl : undefined;
    const storyImages = mediaType !== 'video' && mediaUrl ? [mediaUrl] : (mediaUrls || []);

    const story = await Post.create({
      author: req.user._id,
      content: storyContent,
      images: storyImages,
      video: storyVideo,
      mediaType: mediaType || 'image',
      duration: duration || (mediaType === 'video' ? 15 : 5),
      type: 'story',
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    });
    const populated = await story.populate('author', 'name handle avatarUrl');
    res.status(201).json({ success: true, story: populated });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/stories/feed - Get story feed
router.get('/feed', protect, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const Follow = require('../models/Follow');

    // Get users I follow
    const following = await Follow.find({ follower: req.user._id }).select('following');
    const followingIds = following.map(f => f.following);
    followingIds.push(req.user._id); // Include my own stories

    const stories = await Post.find({
      author: { $in: followingIds },
      type: 'story',
      $or: [
        { expiresAt: { $gt: new Date() } },
        { expiresAt: null },
      ],
    })
      .populate('author', 'name handle avatarUrl isVerified')
      .sort({ createdAt: -1 });

    // Group by user and transform to Flutter-friendly format
    const grouped = {};
    stories.forEach(story => {
      const userId = story.author._id.toString();
      if (!grouped[userId]) {
        grouped[userId] = {
          user: story.author,
          stories: [],
        };
      }
      // Transform story to match Flutter app's expected format
      const storyObj = story.toObject();
      if (storyObj.author) decryptUserData(storyObj.author);
      storyObj.mediaUrl = story.video || (story.images && story.images.length > 0 ? story.images[0] : null);
      storyObj.mediaType = story.mediaType || (story.video ? 'video' : 'image');
      storyObj.caption = story.content || '';
      storyObj.hasViewed = (story.viewedBy || []).some(id => id.toString() === req.user._id.toString());
      grouped[userId].stories.push(storyObj);
    });

    // Add hasUnviewed flag per group
    const result = Object.values(grouped).map(group => {
      if (group.user) {
        const userObj = typeof group.user.toObject === 'function' ? group.user.toObject() : group.user;
        decryptUserData(userObj);
        group.user = userObj;
      }
      return {
        ...group,
        hasUnviewed: group.stories.some(s => !s.hasViewed),
      };
    });

    console.log(`[Stories Feed] user=${req.user._id} followingCount=${followingIds.length} storiesFound=${stories.length} groupCount=${result.length} groups=${result.map(g => ({ userId: g.user._id, name: g.user.name, storyCount: g.stories.length })).map(x => JSON.stringify(x)).join(',')}`);
    res.json({ success: true, storyGroups: result });
  } catch (error) {
    console.error('[Stories Feed] Error:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== NAMED ROUTES (MUST be before /:id routes) =====

// POST /api/stories/repost - Share a post/reel to your story
router.post('/repost', protect, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const { postId, caption } = req.body;
    if (!postId) return res.status(400).json({ success: false, message: 'postId required' });

    const originalPost = await Post.findById(postId).populate('author', 'name handle');
    if (!originalPost) return res.status(404).json({ success: false, message: 'Post not found' });

    const mediaUrl = originalPost.video || (originalPost.images?.length > 0 ? originalPost.images[0] : null);
    if (!mediaUrl) return res.status(400).json({ success: false, message: 'Post has no media to share' });

    const storyCaption = caption || `Shared @${originalPost.author?.handle || 'user'}'s post`;
    const story = await Post.create({
      author: req.user._id,
      content: storyCaption,
      images: originalPost.video ? [] : [mediaUrl],
      video: originalPost.video || undefined,
      mediaType: originalPost.video ? 'video' : 'image',
      duration: originalPost.video ? 15 : 5,
      type: 'story',
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      mentions: [originalPost.author._id],
    });

    originalPost.sharesCount = (originalPost.sharesCount || 0) + 1;
    await originalPost.save();

    const populated = await story.populate('author', 'name handle avatarUrl');
    res.status(201).json({ success: true, story: populated, originalPostId: postId });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/stories/highlights - Create a highlight
router.post('/highlights', protect, async (req, res) => {
  try {
    const Highlight = require('../models/Highlight');
    const { title, storyIds, coverUrl } = req.body;
    if (!title) return res.status(400).json({ success: false, message: 'Title is required' });

    const count = await Highlight.countDocuments({ user: req.user._id });
    const highlight = await Highlight.create({
      user: req.user._id,
      title,
      stories: storyIds || [],
      coverUrl: coverUrl || '',
      order: count,
    });
    res.status(201).json({ success: true, highlight });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/stories/highlights/:userId - Get user's highlights
router.get('/highlights/:userId', protect, async (req, res) => {
  try {
    const Highlight = require('../models/Highlight');
    const highlights = await Highlight.find({ user: req.params.userId })
      .sort({ order: 1 })
      .populate({
        path: 'stories',
        select: 'images video mediaType content duration createdAt viewsCount likesCount',
      });
    res.json({ success: true, highlights });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/stories/highlights/:id - Update highlight
router.put('/highlights/:id', protect, async (req, res) => {
  try {
    const Highlight = require('../models/Highlight');
    const highlight = await Highlight.findOne({ _id: req.params.id, user: req.user._id });
    if (!highlight) return res.status(404).json({ success: false, message: 'Highlight not found' });

    if (req.body.title) highlight.title = req.body.title;
    if (req.body.coverUrl) highlight.coverUrl = req.body.coverUrl;
    if (req.body.storyIds) highlight.stories = req.body.storyIds;
    if (typeof req.body.order === 'number') highlight.order = req.body.order;

    await highlight.save();
    res.json({ success: true, highlight });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/stories/highlights/:id - Delete highlight
router.delete('/highlights/:id', protect, async (req, res) => {
  try {
    const Highlight = require('../models/Highlight');
    const highlight = await Highlight.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!highlight) return res.status(404).json({ success: false, message: 'Highlight not found' });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/stories/highlights/:id/add - Add story to highlight
router.post('/highlights/:id/add', protect, async (req, res) => {
  try {
    const Highlight = require('../models/Highlight');
    const { storyId } = req.body;
    const highlight = await Highlight.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id },
      { $addToSet: { stories: storyId } },
      { new: true }
    );
    if (!highlight) return res.status(404).json({ success: false, message: 'Highlight not found' });
    res.json({ success: true, highlight });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== DYNAMIC :id ROUTES =====

// POST /api/stories/:id/view - View a story (atomic dedup)
router.post('/:id/view', protect, async (req, res) => {
  try {
    const Post = require('../models/Post');
    // Only increment if user hasn't viewed yet (atomic — no race condition)
    const story = await Post.findOneAndUpdate(
      { _id: req.params.id, viewedBy: { $ne: req.user._id } },
      { $addToSet: { viewedBy: req.user._id, viewers: req.user._id }, $inc: { viewsCount: 1 } },
      { new: true }
    );
    if (!story) {
      // Already viewed — just return current count
      const existing = await Post.findById(req.params.id).select('viewsCount').lean();
      return res.json({ success: true, viewsCount: existing?.viewsCount || 0 });
    }
    res.json({ success: true, viewsCount: story.viewsCount || 0 });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/stories/:id/like - Toggle story like (atomic)
router.post('/:id/like', protect, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const userId = req.user._id;

    // Try to like (atomic — only if not already liked)
    let story = await Post.findOneAndUpdate(
      { _id: req.params.id, likedBy: { $ne: userId } },
      { $addToSet: { likedBy: userId }, $inc: { likesCount: 1 } },
      { new: true }
    );
    let isLiked;
    if (story) {
      isLiked = true;
    } else {
      // Already liked → unlike (atomic)
      story = await Post.findOneAndUpdate(
        { _id: req.params.id },
        { $pull: { likedBy: userId }, $inc: { likesCount: -1 } },
        { new: true }
      );
      if (!story) return res.status(404).json({ success: false, message: 'Story not found' });
      isLiked = false;
      // Prevent negative counts
      if (story.likesCount < 0) { story.likesCount = 0; await story.save(); }
    }
    res.json({ success: true, isLiked, likesCount: story.likesCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/stories/:id - Delete story
router.delete('/:id', protect, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const story = await Post.findOneAndDelete({ _id: req.params.id, author: req.user._id });
    if (!story) return res.status(404).json({ success: false, message: 'Story not found' });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/stories/:id/viewers - Get story viewers
router.get('/:id/viewers', protect, async (req, res) => {
  try {
    const Post = require('../models/Post');
    const story = await Post.findById(req.params.id).populate('viewedBy', 'name handle avatarUrl');
    if (!story) return res.status(404).json({ success: false, message: 'Story not found' });
    const viewers = (story.viewedBy || []).map(v => {
      const obj = v.toObject ? v.toObject() : { ...v };
      decryptUserData(obj);
      return obj;
    });
    res.json({ success: true, viewers });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
