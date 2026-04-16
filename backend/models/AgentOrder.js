const mongoose = require('mongoose');

const agentStepSchema = new mongoose.Schema({
  agentId: { type: String, required: true },
  agentName: { type: String, required: true },
  status: { type: String, enum: ['queued', 'thinking', 'using_tool', 'completed', 'failed'], default: 'queued' },
  toolUsed: { type: String, default: null },
  toolInput: { type: mongoose.Schema.Types.Mixed, default: null },
  toolResult: { type: String, default: null },
  response: { type: String, default: null },
  startedAt: { type: Date, default: null },
  completedAt: { type: Date, default: null },
  tokensUsed: { type: Number, default: 0 },
});

const agentOrderSchema = new mongoose.Schema({
  boss: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  order: { type: String, required: true },
  targetAgents: [{ type: String }], // ['shield', 'pulse'] or ['all']
  quickCommand: { type: String, default: null }, // 'Status Report', etc.
  status: { type: String, enum: ['pending', 'processing', 'completed', 'failed', 'cancelled'], default: 'pending' },
  steps: [agentStepSchema],
  finalSummary: { type: String, default: null },
  totalTokens: { type: Number, default: 0 },
  processingTimeMs: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
  completedAt: { type: Date, default: null },
});

agentOrderSchema.index({ boss: 1, createdAt: -1 });
agentOrderSchema.index({ status: 1 });

module.exports = mongoose.model('AgentOrder', agentOrderSchema);
