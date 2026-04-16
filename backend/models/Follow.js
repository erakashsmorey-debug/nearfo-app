const mongoose = require('mongoose');

const followSchema = new mongoose.Schema(
  {
    follower: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    following: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true }
);

// Compound index: one user can only follow another once
followSchema.index({ follower: 1, following: 1 }, { unique: true });
// Quick lookup: who follows me?
followSchema.index({ following: 1 });
// Quick lookup: who do I follow?
followSchema.index({ follower: 1 });

module.exports = mongoose.model('Follow', followSchema);
