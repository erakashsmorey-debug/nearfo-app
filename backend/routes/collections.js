const express = require('express');
const router = express.Router();
const Collection = require('../models/Collection');
const { protect } = require('../middleware/auth');

// POST /api/collections - Create a collection
router.post('/', protect, async (req, res) => {
  try {
    const { name, description, isPrivate } = req.body;
    if (!name) return res.status(400).json({ success: false, message: 'Collection name required' });

    const collection = await Collection.create({
      user: req.user._id,
      name,
      description: description || '',
      isPrivate: isPrivate !== false,
    });
    res.status(201).json({ success: true, collection });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/collections - Get my collections
router.get('/', protect, async (req, res) => {
  try {
    const collections = await Collection.find({ user: req.user._id })
      .sort({ updatedAt: -1 });

    const enriched = collections.map(c => {
      const obj = c.toObject();
      obj.postCount = obj.posts.length;
      // Only return first 3 post IDs as preview
      obj.previewPosts = obj.posts.slice(0, 3);
      delete obj.posts;
      return obj;
    });

    res.json({ success: true, collections: enriched });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/collections/:id - Get collection with posts
router.get('/:id', protect, async (req, res) => {
  try {
    const collection = await Collection.findById(req.params.id)
      .populate({
        path: 'posts',
        populate: { path: 'author', select: 'name handle avatarUrl isVerified' },
        options: { sort: { createdAt: -1 } },
      });

    if (!collection) return res.status(404).json({ success: false, message: 'Collection not found' });

    // Private collections only visible to owner
    if (collection.isPrivate && collection.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'This collection is private' });
    }

    res.json({ success: true, collection });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/collections/:id - Update collection
router.put('/:id', protect, async (req, res) => {
  try {
    const collection = await Collection.findOne({ _id: req.params.id, user: req.user._id });
    if (!collection) return res.status(404).json({ success: false, message: 'Collection not found' });

    if (req.body.name) collection.name = req.body.name;
    if (req.body.description !== undefined) collection.description = req.body.description;
    if (req.body.coverUrl) collection.coverUrl = req.body.coverUrl;
    if (typeof req.body.isPrivate === 'boolean') collection.isPrivate = req.body.isPrivate;

    await collection.save();
    res.json({ success: true, collection });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/collections/:id - Delete collection
router.delete('/:id', protect, async (req, res) => {
  try {
    const collection = await Collection.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!collection) return res.status(404).json({ success: false, message: 'Collection not found' });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/collections/:id/add - Add post to collection
router.post('/:id/add', protect, async (req, res) => {
  try {
    const { postId } = req.body;
    const collection = await Collection.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id },
      { $addToSet: { posts: postId } },
      { new: true }
    );
    if (!collection) return res.status(404).json({ success: false, message: 'Collection not found' });

    // Set cover from first post if not set
    if (!collection.coverUrl && collection.posts.length === 1) {
      const Post = require('../models/Post');
      const post = await Post.findById(postId);
      if (post?.images?.length > 0) {
        collection.coverUrl = post.images[0];
        await collection.save();
      }
    }

    res.json({ success: true, collection });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/collections/:id/remove - Remove post from collection
router.post('/:id/remove', protect, async (req, res) => {
  try {
    const { postId } = req.body;
    const collection = await Collection.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id },
      { $pull: { posts: postId } },
      { new: true }
    );
    if (!collection) return res.status(404).json({ success: false, message: 'Collection not found' });
    res.json({ success: true, collection });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
