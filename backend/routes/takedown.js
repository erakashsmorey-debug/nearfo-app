const express = require('express');
const router = express.Router();
const Takedown = require('../models/Takedown');
const Post = require('../models/Post');
const { protect } = require('../middleware/auth');

// POST /api/takedown - Submit a DMCA takedown request (public, but auth needed)
router.post('/', protect, async (req, res) => {
  try {
    const { complainantName, complainantEmail, complainantCompany, contentType, contentId, contentUrl, originalWorkUrl, description, swornStatement } = req.body;

    if (!complainantName || !complainantEmail || !contentType || !contentId || !description) {
      return res.status(400).json({ success: false, message: 'Required fields: complainantName, complainantEmail, contentType, contentId, description' });
    }

    // Find content author
    let contentAuthor = null;
    if (['post', 'reel', 'story'].includes(contentType)) {
      const post = await Post.findById(contentId).select('author');
      if (post) contentAuthor = post.author;
    }

    const takedown = await Takedown.create({
      complainantName,
      complainantEmail,
      complainantCompany: complainantCompany || '',
      contentType,
      contentId,
      contentUrl: contentUrl || '',
      contentAuthor,
      originalWorkUrl: originalWorkUrl || '',
      description,
      swornStatement: swornStatement === true,
    });

    res.status(201).json({
      success: true,
      message: 'DMCA takedown request submitted. We will review within 48 hours.',
      takedownId: takedown._id,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/takedown - List takedown requests (admin only)
router.get('/', protect, async (req, res) => {
  try {
    if (!req.user.isVerified) return res.status(403).json({ success: false, message: 'Admin access required' });

    const { status = 'pending', page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * parseInt(limit);

    const takedowns = await Takedown.find(status === 'all' ? {} : { status })
      .populate('contentAuthor', 'name handle avatarUrl')
      .populate('reviewedBy', 'name handle')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Takedown.countDocuments(status === 'all' ? {} : { status });

    res.json({ success: true, takedowns, total, page: parseInt(page) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/takedown/:id/review - Approve or reject a takedown (admin)
router.put('/:id/review', protect, async (req, res) => {
  try {
    if (!req.user.isVerified) return res.status(403).json({ success: false, message: 'Admin access required' });

    const { action, notes } = req.body; // action: 'approve' or 'reject'
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ success: false, message: 'Action must be "approve" or "reject"' });
    }

    const takedown = await Takedown.findById(req.params.id);
    if (!takedown) return res.status(404).json({ success: false, message: 'Takedown not found' });

    takedown.status = action === 'approve' ? 'approved' : 'rejected';
    takedown.reviewedBy = req.user._id;
    takedown.reviewedAt = new Date();
    takedown.reviewNotes = notes || '';
    await takedown.save();

    // If approved, hide the content
    if (action === 'approve') {
      if (['post', 'reel', 'story'].includes(takedown.contentType)) {
        await Post.findByIdAndUpdate(takedown.contentId, { isHidden: true });
      }
    }

    res.json({
      success: true,
      message: action === 'approve' ? 'Takedown approved. Content has been removed.' : 'Takedown request rejected.',
      takedown,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/takedown/:id/counter - Submit a counter-notice
router.post('/:id/counter', protect, async (req, res) => {
  try {
    const { name, email, statement } = req.body;
    if (!name || !email || !statement) {
      return res.status(400).json({ success: false, message: 'name, email, and statement required' });
    }

    const takedown = await Takedown.findById(req.params.id);
    if (!takedown) return res.status(404).json({ success: false, message: 'Takedown not found' });

    // Verify the counter-notice is from the content author
    if (takedown.contentAuthor?.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Only the content author can file a counter-notice' });
    }

    takedown.counterNotice = { filed: true, name, email, statement, filedAt: new Date() };
    takedown.status = 'counter_notice';
    await takedown.save();

    res.json({
      success: true,
      message: 'Counter-notice filed. The complainant has 10 business days to respond.',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
