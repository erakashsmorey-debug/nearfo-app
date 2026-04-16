const mongoose = require('mongoose');

const postSchema = new mongoose.Schema({
  author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, default: '', maxlength: 500 },

  // Post type (post = regular, story = 24h story, reel = short video)
  type: { type: String, enum: ['post', 'story', 'reel'], default: 'post' },

  // Media
  images: [{ type: String }], // S3 URLs
  video: { type: String },
  mediaType: { type: String, enum: ['image', 'video'], default: 'image' },

  // Story-specific fields
  expiresAt: { type: Date, default: null },
  duration: { type: Number, default: 5 }, // display duration in seconds
  viewedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  likedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],

  // Location (for local/global feed logic)
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }, // [lng, lat]
  },
  city: { type: String, default: '' },
  state: { type: String, default: '' },

  // Mood & Tags
  mood: { type: String, enum: ['excited', 'chill', 'creative', 'energetic', 'hungry', 'amazed', 'inspired', 'nostalgic', 'Happy', 'Cool', 'Fire', 'Sleepy', 'Thinking', 'Angry', 'Party', 'Love', ''], default: '' },
  hashtags: [{ type: String, lowercase: true }],
  mentions: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],

  // Engagement
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  likesCount: { type: Number, default: 0 },
  commentsCount: { type: Number, default: 0 },
  sharesCount: { type: Number, default: 0 },
  viewsCount: { type: Number, default: 0 },
  viewers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // unique viewers
  bookmarks: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  bookmarksCount: { type: Number, default: 0 },

  // Viral tracking
  viralScore: { type: Number, default: 0 },
  lastViralCalc: { type: Date, default: Date.now },

  // Visibility
  visibility: { type: String, enum: ['public', 'local', 'followers', 'nearby', 'circle'], default: 'public' },
  isPromoted: { type: Boolean, default: false },

  // Edit tracking
  isEdited: { type: Boolean, default: false },
  editedAt: { type: Date, default: null },

  // Moderation
  isReported: { type: Boolean, default: false },
  reportCount: { type: Number, default: 0 },
  isHidden: { type: Boolean, default: false },

}, { timestamps: true });

// Geospatial index for location-based feed queries
postSchema.index({ location: '2dsphere' });
postSchema.index({ author: 1, createdAt: -1 });
postSchema.index({ createdAt: -1 });
postSchema.index({ hashtags: 1 });
postSchema.index({ likesCount: -1 });
postSchema.index({ viralScore: -1 });
postSchema.index({ viralScore: -1, createdAt: -1 });
postSchema.index({ type: 1, expiresAt: 1 }); // Story feed queries
postSchema.index({ bookmarks: 1 }); // Saved posts lookups
postSchema.index({ isHidden: 1 }); // Moderation queries

module.exports = mongoose.model('Post', postSchema);
