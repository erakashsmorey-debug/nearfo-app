const mongoose = require('mongoose');

const takedownSchema = new mongoose.Schema({
  // Complainant info
  complainantName: { type: String, required: true },
  complainantEmail: { type: String, required: true },
  complainantCompany: { type: String, default: '' },

  // Content being reported
  contentType: { type: String, enum: ['post', 'reel', 'story', 'comment', 'avatar'], required: true },
  contentId: { type: mongoose.Schema.Types.ObjectId, required: true },
  contentUrl: { type: String, default: '' },
  contentAuthor: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

  // Claim details
  originalWorkUrl: { type: String, default: '' }, // URL to original copyrighted work
  description: { type: String, required: true, maxlength: 2000 },
  swornStatement: { type: Boolean, default: false }, // "I swear under penalty of perjury..."

  // Status
  status: { type: String, enum: ['pending', 'approved', 'rejected', 'counter_notice'], default: 'pending' },
  reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  reviewedAt: { type: Date, default: null },
  reviewNotes: { type: String, default: '' },

  // Counter-notice (from content owner)
  counterNotice: {
    filed: { type: Boolean, default: false },
    name: String,
    email: String,
    statement: String,
    filedAt: Date,
  },
}, { timestamps: true });

takedownSchema.index({ status: 1, createdAt: -1 });
takedownSchema.index({ contentAuthor: 1 });

module.exports = mongoose.model('Takedown', takedownSchema);
