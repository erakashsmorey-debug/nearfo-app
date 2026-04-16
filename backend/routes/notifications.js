const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');
const { protect } = require('../middleware/auth');
const { decryptUserData } = require('../utils/encryption');

// GET /api/notifications
// Get all notifications for current user
router.get('/', protect, async (req, res) => {
  try {
    const { page = 1, limit = 30 } = req.query;
    const skip = (page - 1) * limit;

    const notifications = await Notification.find({ recipient: req.user._id })
      .populate('sender', 'name handle avatarUrl isVerified')
      .populate('post', 'content images')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const totalNotifications = await Notification.countDocuments({
      recipient: req.user._id,
    });

    const unreadCount = await Notification.countDocuments({
      recipient: req.user._id,
      isRead: false,
    });

    const decryptedNotifications = notifications.map(n => {
      const obj = n.toObject();
      if (obj.sender && typeof obj.sender === 'object') decryptUserData(obj.sender);
      return obj;
    });
    res.json({
      success: true,
      notifications: decryptedNotifications,
      unreadCount,
      page: parseInt(page),
      totalNotifications,
      hasMore: skip + notifications.length < totalNotifications,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/notifications/unread-count
// Get unread notification count (for badge)
router.get('/unread-count', protect, async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      recipient: req.user._id,
      isRead: false,
    });
    res.json({ success: true, unreadCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/notifications/read-all
// Mark all notifications as read
router.put('/read-all', protect, async (req, res) => {
  try {
    await Notification.updateMany(
      { recipient: req.user._id, isRead: false },
      { isRead: true }
    );
    res.json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/notifications/:id/read
// Mark single notification as read
router.put('/:id/read', protect, async (req, res) => {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, recipient: req.user._id },
      { isRead: true },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    res.json({ success: true, notification });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/notifications/:id
// Delete a notification
router.delete('/:id', protect, async (req, res) => {
  try {
    const notification = await Notification.findOneAndDelete({
      _id: req.params.id,
      recipient: req.user._id,
    });

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    res.json({ success: true, message: 'Notification deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/notifications
// Clear all notifications
router.delete('/', protect, async (req, res) => {
  try {
    await Notification.deleteMany({ recipient: req.user._id });
    res.json({ success: true, message: 'All notifications cleared' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
