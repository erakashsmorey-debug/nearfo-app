const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  reporter: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  contentType: { type: String, enum: ['user', 'post', 'reel', 'comment', 'chat', 'story'], required: true },
  contentId: { type: String, required: true },
  reason: { type: String, required: true },
  status: { type: String, enum: ['pending', 'reviewed', 'resolved', 'dismissed'], default: 'pending' },
  actionTaken: { type: String, default: '' },
  reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  reviewedAt: { type: Date },
}, { timestamps: true });

reportSchema.index({ contentType: 1, contentId: 1 });
reportSchema.index({ reporter: 1 });
reportSchema.index({ status: 1 });

module.exports = mongoose.model('Report', reportSchema);
