const express = require('express');
const router = express.Router();
const Comment = require('../models/Comment');
const Post = require('../models/Post');
const Notification = require('../models/Notification');
const { protect } = require('../middleware/auth');
const { decryptUserData } = require('../utils/encryption');
const { moderateContent } = require('../middleware/contentModeration');

function decryptAuthor(obj) {
  if (obj && obj.author && typeof obj.author === 'object') {
    decryptUserData(obj.author);
  }
  return obj;
}

// POST /api/comments
// Add a comment to a post
router.post('/', protect, moderateContent, async (req, res) => {
  try {
    const { postId, content, parentComment } = req.body;

    if (!postId || !content || content.trim().length === 0) {
      return res.status(400).json({ success: false, message: 'Post ID and content are required' });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    const comment = await Comment.create({
      post: postId,
      author: req.user._id,
      content: content.trim(),
      parentComment: parentComment || null,
    });

    // Update post comment count
    post.commentsCount += 1;
    await post.save();

    // Send notification to post author (don't notify yourself)
    if (post.author.toString() !== req.user._id.toString()) {
      await Notification.create({
        recipient: post.author,
        sender: req.user._id,
        type: 'comment',
        post: post._id,
        comment: comment._id,
      });

      // Real-time notification via Socket.io
      const io = req.app.get('io');
      const onlineUsers = req.app.get('onlineUsers');
      const recipientSocket = onlineUsers.get(post.author.toString());
      if (recipientSocket) {
        io.to(recipientSocket).emit('new_notification', {
          type: 'comment',
          message: `${req.user.name} commented on your post`,
          postId: post._id,
        });
      }
    }

    // If it's a reply, notify the parent comment author too
    if (parentComment) {
      const parent = await Comment.findById(parentComment);
      if (parent && parent.author.toString() !== req.user._id.toString()) {
        await Notification.create({
          recipient: parent.author,
          sender: req.user._id,
          type: 'comment',
          post: post._id,
          comment: comment._id,
          message: `${req.user.name} replied to your comment`,
        });
      }
    }

    const populated = await comment.populate('author', 'name handle avatarUrl isVerified');
    const commentObj = populated.toObject();
    decryptAuthor(commentObj);

    res.status(201).json({ success: true, comment: commentObj });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/comments/:postId
// Get all comments for a post (with replies)
router.get('/:postId', protect, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    // Get top-level comments (no parent)
    const comments = await Comment.find({
      post: req.params.postId,
      parentComment: null,
      isReported: false,
    })
      .populate('author', 'name handle avatarUrl isVerified city')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Get replies for each comment
    const commentsWithReplies = await Promise.all(
      comments.map(async (comment) => {
        const replies = await Comment.find({
          parentComment: comment._id,
          isReported: false,
        })
          .populate('author', 'name handle avatarUrl isVerified')
          .sort({ createdAt: 1 })
          .limit(5); // Show first 5 replies

        const totalReplies = await Comment.countDocuments({
          parentComment: comment._id,
          isReported: false,
        });

        const cObj = comment.toObject();
        decryptAuthor(cObj);
        const decryptedReplies = replies.map(r => {
          const rObj = r.toObject();
          decryptAuthor(rObj);
          return rObj;
        });
        return {
          ...cObj,
          replies: decryptedReplies,
          totalReplies,
          hasMoreReplies: totalReplies > 5,
        };
      })
    );

    const totalComments = await Comment.countDocuments({
      post: req.params.postId,
      parentComment: null,
      isReported: false,
    });

    res.json({
      success: true,
      comments: commentsWithReplies,
      page: parseInt(page),
      totalComments,
      hasMore: skip + comments.length < totalComments,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/comments/:postId/replies/:commentId
// Get more replies for a specific comment
router.get('/:postId/replies/:commentId', protect, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (page - 1) * limit;

    const replies = await Comment.find({
      parentComment: req.params.commentId,
      isReported: false,
    })
      .populate('author', 'name handle avatarUrl isVerified')
      .sort({ createdAt: 1 })
      .skip(skip)
      .limit(parseInt(limit));

    const totalReplies = await Comment.countDocuments({
      parentComment: req.params.commentId,
      isReported: false,
    });

    const decryptedReplies = replies.map(r => {
      const rObj = r.toObject();
      decryptAuthor(rObj);
      return rObj;
    });
    res.json({
      success: true,
      replies: decryptedReplies,
      page: parseInt(page),
      totalReplies,
      hasMore: skip + replies.length < totalReplies,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/comments/:id/like
// Like/unlike a comment
router.post('/:id/like', protect, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) {
      return res.status(404).json({ success: false, message: 'Comment not found' });
    }

    const isLiked = comment.likes.includes(req.user._id);

    if (isLiked) {
      comment.likes.pull(req.user._id);
      comment.likesCount = Math.max(0, comment.likesCount - 1);
    } else {
      comment.likes.push(req.user._id);
      comment.likesCount += 1;
    }

    await comment.save();
    res.json({ success: true, isLiked: !isLiked, likesCount: comment.likesCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/comments/:id
// Delete own comment
router.delete('/:id', protect, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) {
      return res.status(404).json({ success: false, message: 'Comment not found' });
    }

    if (comment.author.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    // Count replies BEFORE deleting them
    const replyCount = await Comment.countDocuments({ parentComment: comment._id });

    // Delete all replies to this comment
    await Comment.deleteMany({ parentComment: comment._id });

    // Update post comment count (1 for the comment + replyCount for its replies)
    await Post.findByIdAndUpdate(comment.post, {
      $inc: { commentsCount: -(1 + replyCount) },
    });

    await comment.deleteOne();
    res.json({ success: true, message: 'Comment deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
