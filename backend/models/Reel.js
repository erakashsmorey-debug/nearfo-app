const mongoose = require('mongoose');

const reelSchema = new mongoose.Schema({
  author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },

  // Media
  videoUrl: { type: String, required: true },
  thumbnailUrl: { type: String, default: '' },
  caption: { type: String, maxlength: 500, default: '' },
  duration: { type: Number, default: 0 }, // in seconds
  audioName: { type: String, default: '' },

  // Tags
  hashtags: [{ type: String, lowercase: true }],
  mentions: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],

  // Location (for local/global feed logic)
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }, // [lng, lat]
  },
  city: { type: String, default: '' },
  state: { type: String, default: '' },

  // Engagement
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  likesCount: { type: Number, default: 0 },
  commentsCount: { type: Number, default: 0 },
  sharesCount: { type: Number, default: 0 },
  viewsCount: { type: Number, default: 0 },
  viewers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  bookmarks: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  bookmarksCount: { type: Number, default: 0 },

  // Viral tracking
  viralScore: { type: Number, default: 0 },

  // Visibility
  visibility: { type: String, enum: ['public', 'local', 'followers', 'nearby', 'circle'], default: 'public' },

  // Moderation
  isReported: { type: Boolean, default: false },
  reportCount: { type: Number, default: 0 },
  isHidden: { type: Boolean, default: false },

}, { timestamps: true });

// Indexes
reelSchema.index({ location: '2dsphere' });
reelSchema.index({ author: 1, createdAt: -1 });
reelSchema.index({ createdAt: -1 });
reelSchema.index({ viralScore: -1 });
reelSchema.index({ hashtags: 1 });

module.exports = mongoose.model('Reel', reelSchema);
