const mongoose = require('mongoose');

const callLogSchema = new mongoose.Schema({
  caller: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { type: String, enum: ['audio', 'video'], default: 'audio' },
  status: { type: String, enum: ['missed', 'answered', 'declined', 'ongoing'], default: 'missed' },
  duration: { type: Number, default: 0 }, // seconds
  startedAt: { type: Date, default: Date.now },
  endedAt: { type: Date },
}, { timestamps: true });

module.exports = mongoose.model('CallLog', callLogSchema);
