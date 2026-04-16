const mongoose = require('mongoose');

const highlightSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true, trim: true, maxlength: 30 },
  coverUrl: { type: String, default: '' }, // Cover image URL
  stories: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }], // References to story posts
  order: { type: Number, default: 0 }, // Display order on profile
}, { timestamps: true });

highlightSchema.index({ user: 1, order: 1 });

module.exports = mongoose.model('Highlight', highlightSchema);
