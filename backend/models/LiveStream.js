const mongoose = require('mongoose');

const liveStreamSchema = new mongoose.Schema({
  host: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, default: 'Live', maxlength: 100 },
  description: { type: String, default: '', maxlength: 300 },
  thumbnailUrl: { type: String, default: '' },

  // Status
  status: { type: String, enum: ['live', 'ended', 'scheduled'], default: 'live' },
  startedAt: { type: Date, default: Date.now },
  endedAt: { type: Date, default: null },

  // Audience
  viewers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  peakViewers: { type: Number, default: 0 },
  currentViewers: { type: Number, default: 0 },

  // Engagement
  likes: { type: Number, default: 0 },
  comments: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    text: { type: String, maxlength: 200 },
    createdAt: { type: Date, default: Date.now },
  }],

  // Visibility
  visibility: { type: String, enum: ['public', 'followers', 'local'], default: 'public' },
}, { timestamps: true });

liveStreamSchema.index({ host: 1, status: 1 });
liveStreamSchema.index({ status: 1, startedAt: -1 });

module.exports = mongoose.model('LiveStream', liveStreamSchema);
