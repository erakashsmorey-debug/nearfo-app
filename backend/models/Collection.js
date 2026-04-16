const mongoose = require('mongoose');

const collectionSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true, trim: true, maxlength: 50 },
  description: { type: String, default: '', maxlength: 200 },
  coverUrl: { type: String, default: '' },
  posts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],
  isPrivate: { type: Boolean, default: true },
}, { timestamps: true });

collectionSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('Collection', collectionSchema);
