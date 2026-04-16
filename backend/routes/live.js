const express = require('express');
const router = express.Router();
const LiveStream = require('../models/LiveStream');
const { protect } = require('../middleware/auth');

// POST /api/live/start - Start a live stream
router.post('/start', protect, async (req, res) => {
  try {
    const { title, description, visibility } = req.body;

    // Check if user already has an active stream
    const existing = await LiveStream.findOne({ host: req.user._id, status: 'live' });
    if (existing) {
      return res.status(400).json({ success: false, message: 'You already have an active live stream' });
    }

    const stream = await LiveStream.create({
      host: req.user._id,
      title: title || 'Live',
      description: description || '',
      visibility: visibility || 'public',
    });

    // Notify followers via socket
    const io = req.app.get('io');
    io.emit('live_started', {
      streamId: stream._id,
      hostId: req.user._id,
      hostName: req.user.name,
      hostAvatar: req.user.avatarUrl,
      title: stream.title,
    });

    res.status(201).json({ success: true, stream });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/live/active - Get all active live streams
// NOTE: MUST be before /:id routes
router.get('/active', protect, async (req, res) => {
  try {
    const streams = await LiveStream.find({ status: 'live' })
      .populate('host', 'name handle avatarUrl isVerified')
      .sort({ currentViewers: -1, startedAt: -1 })
      .limit(50);
    res.json({ success: true, streams });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/live/:id/end - End a live stream
router.post('/:id/end', protect, async (req, res) => {
  try {
    const stream = await LiveStream.findOneAndUpdate(
      { _id: req.params.id, host: req.user._id, status: 'live' },
      { status: 'ended', endedAt: new Date() },
      { new: true }
    );
    if (!stream) return res.status(404).json({ success: false, message: 'Stream not found' });

    const io = req.app.get('io');
    io.to(`live_${stream._id}`).emit('live_ended', { streamId: stream._id });

    res.json({ success: true, stream });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/live/:id/join - Join as viewer
router.post('/:id/join', protect, async (req, res) => {
  try {
    const stream = await LiveStream.findOneAndUpdate(
      { _id: req.params.id, status: 'live' },
      {
        $addToSet: { viewers: req.user._id },
        $inc: { currentViewers: 1 },
      },
      { new: true }
    );
    if (!stream) return res.status(404).json({ success: false, message: 'Stream not found or ended' });

    // Update peak viewers
    if (stream.currentViewers > stream.peakViewers) {
      stream.peakViewers = stream.currentViewers;
      await stream.save();
    }

    const io = req.app.get('io');
    io.to(`live_${stream._id}`).emit('viewer_joined', {
      viewerId: req.user._id,
      viewerName: req.user.name,
      currentViewers: stream.currentViewers,
    });

    res.json({ success: true, currentViewers: stream.currentViewers });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/live/:id/leave - Leave as viewer
router.post('/:id/leave', protect, async (req, res) => {
  try {
    const stream = await LiveStream.findOneAndUpdate(
      { _id: req.params.id },
      { $inc: { currentViewers: -1 } },
      { new: true }
    );
    if (stream && stream.currentViewers < 0) {
      stream.currentViewers = 0;
      await stream.save();
    }
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/live/:id/comment - Send a live comment
router.post('/:id/comment', protect, async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) return res.status(400).json({ success: false, message: 'Comment text required' });

    const stream = await LiveStream.findOne({ _id: req.params.id, status: 'live' });
    if (!stream) return res.status(404).json({ success: false, message: 'Stream not found' });

    const comment = { user: req.user._id, text: text.substring(0, 200), createdAt: new Date() };
    stream.comments.push(comment);

    // Keep only last 200 comments in DB
    if (stream.comments.length > 200) {
      stream.comments = stream.comments.slice(-200);
    }
    await stream.save();

    // Broadcast to all viewers in real-time
    const io = req.app.get('io');
    io.to(`live_${stream._id}`).emit('live_comment', {
      userId: req.user._id,
      userName: req.user.name,
      userAvatar: req.user.avatarUrl,
      text: comment.text,
    });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/live/:id/like - Like during live
router.post('/:id/like', protect, async (req, res) => {
  try {
    const stream = await LiveStream.findOneAndUpdate(
      { _id: req.params.id, status: 'live' },
      { $inc: { likes: 1 } },
      { new: true }
    );
    if (!stream) return res.status(404).json({ success: false, message: 'Stream not found' });

    const io = req.app.get('io');
    io.to(`live_${stream._id}`).emit('live_like', {
      userId: req.user._id,
      totalLikes: stream.likes,
    });

    res.json({ success: true, likes: stream.likes });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
