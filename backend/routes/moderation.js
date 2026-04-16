const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Post = require('../models/Post');
const { protect } = require('../middleware/auth');

// Simple admin check (Boss PIN verified users or specific admin IDs)
function adminOnly(req, res, next) {
  // For now, check if user is verified (admin). In production, use role-based system.
  if (!req.user.isVerified) {
    return res.status(403).json({ success: false, message: 'Admin access required' });
  }
  next();
}

// POST /api/moderation/ban - Ban a user permanently
router.post('/ban', protect, adminOnly, async (req, res) => {
  try {
    const { userId, reason } = req.body;
    if (!userId) return res.status(400).json({ success: false, message: 'userId required' });

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    user.isBanned = true;
    user.banReason = reason || 'Community guidelines violation';
    user.bannedAt = new Date();
    user.bannedBy = req.user._id;
    user.banHistory.push({
      action: 'ban',
      reason: user.banReason,
      by: req.user._id,
      at: new Date(),
      duration: 'permanent',
    });
    await user.save();

    // Hide all their posts
    await Post.updateMany({ author: userId }, { isHidden: true });

    res.json({ success: true, message: `User ${user.handle} banned permanently` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/moderation/unban - Unban a user
router.post('/unban', protect, adminOnly, async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ success: false, message: 'userId required' });
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    user.isBanned = false;
    user.banReason = '';
    user.bannedAt = null;
    user.bannedBy = null;
    user.banHistory.push({
      action: 'unban',
      reason: 'Admin unbanned',
      by: req.user._id,
      at: new Date(),
    });
    await user.save();

    // Unhide their posts
    await Post.updateMany({ author: userId }, { isHidden: false });

    res.json({ success: true, message: `User ${user.handle} unbanned` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/moderation/suspend - Temporarily suspend a user
router.post('/suspend', protect, adminOnly, async (req, res) => {
  try {
    const { userId, reason, durationHours = 168 } = req.body; // default 7 days
    if (!userId) return res.status(400).json({ success: false, message: 'userId required' });

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const until = new Date(Date.now() + durationHours * 60 * 60 * 1000);
    user.suspendedUntil = until;
    user.suspendReason = reason || 'Temporary suspension';
    user.banHistory.push({
      action: 'suspend',
      reason: user.suspendReason,
      by: req.user._id,
      at: new Date(),
      duration: `${durationHours} hours`,
    });
    await user.save();

    res.json({ success: true, message: `User ${user.handle} suspended until ${until.toISOString()}` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/moderation/unsuspend - Remove suspension
router.post('/unsuspend', protect, adminOnly, async (req, res) => {
  try {
    const { userId } = req.body;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    user.suspendedUntil = null;
    user.suspendReason = '';
    user.banHistory.push({
      action: 'unsuspend',
      reason: 'Admin unsuspended',
      by: req.user._id,
      at: new Date(),
    });
    await user.save();

    res.json({ success: true, message: `User ${user.handle} unsuspended` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/moderation/banned - List all banned users
router.get('/banned', protect, adminOnly, async (req, res) => {
  try {
    const users = await User.find({ isBanned: true })
      .select('name handle avatarUrl banReason bannedAt')
      .sort({ bannedAt: -1 });
    res.json({ success: true, users });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/moderation/suspended - List all suspended users
router.get('/suspended', protect, adminOnly, async (req, res) => {
  try {
    const users = await User.find({ suspendedUntil: { $gt: new Date() } })
      .select('name handle avatarUrl suspendReason suspendedUntil')
      .sort({ suspendedUntil: -1 });
    res.json({ success: true, users });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/moderation/hide-post - Hide a specific post (without banning user)
router.post('/hide-post', protect, adminOnly, async (req, res) => {
  try {
    const { postId, reason } = req.body;
    const post = await Post.findByIdAndUpdate(postId, { isHidden: true }, { new: true });
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    res.json({ success: true, message: 'Post hidden' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
