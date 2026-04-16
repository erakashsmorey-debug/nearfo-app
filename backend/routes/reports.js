const express = require('express');
const router = express.Router();
const Report = require('../models/Report');
const { protect } = require('../middleware/auth');

// POST /api/reports
// Submit a report
router.post('/', protect, async (req, res) => {
  try {
    const { contentType, contentId, reason } = req.body;

    if (!contentType || !contentId || !reason) {
      return res.status(400).json({ success: false, message: 'contentType, contentId, and reason are required' });
    }

    // Check for duplicate report
    const existing = await Report.findOne({
      reporter: req.user._id,
      contentType,
      contentId,
    });
    if (existing) {
      return res.json({ success: true, message: 'Already reported', report: existing });
    }

    const report = await Report.create({
      reporter: req.user._id,
      contentType,
      contentId,
      reason,
    });

    res.status(201).json({ success: true, report });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/reports (admin)
// Get reports list
router.get('/', protect, async (req, res) => {
  try {
    const { status = 'pending', page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const reports = await Report.find({ status })
      .populate('reporter', 'name handle avatarUrl')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Report.countDocuments({ status });

    res.json({ success: true, reports, total, page: parseInt(page) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/reports/:reportId/review
// Review a report (admin)
router.put('/:reportId/review', protect, async (req, res) => {
  try {
    const { status, actionTaken = '' } = req.body;
    const report = await Report.findByIdAndUpdate(
      req.params.reportId,
      { status, actionTaken, reviewedBy: req.user._id, reviewedAt: new Date() },
      { new: true }
    );
    if (!report) {
      return res.status(404).json({ success: false, message: 'Report not found' });
    }
    res.json({ success: true, report });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
