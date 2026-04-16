const mongoose = require('mongoose');
const { encrypt, decrypt, isEncrypted } = require('../utils/encryption');

// ===== Chat Room / Conversation =====
const chatSchema = new mongoose.Schema({
  participants: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  isGroup: { type: Boolean, default: false },
  groupName: { type: String, default: '' },
  groupAvatar: { type: String, default: '' },
  groupAdmin: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  lastMessage: { type: String, default: '' },
  lastMessageAt: { type: Date, default: Date.now },
  lastMessageBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

  // Chat settings (per-chat)
  theme: { type: String, default: 'Default' },
  disappearingMode: { type: String, enum: ['Off', '24 hours', '7 days', '90 days'], default: 'Off' },
  nicknames: { type: Map, of: String, default: {} },
  mutedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  restrictedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  blockedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
}, { timestamps: true });

// Auto-decrypt lastMessage on read
chatSchema.path('lastMessage').get(function (val) {
  if (!val || typeof val !== 'string') return val;
  return decrypt(val);
});

// Auto-encrypt lastMessage before save
chatSchema.pre('save', function (next) {
  if (this.isModified('lastMessage') && this.lastMessage) {
    const rawVal = this.getValue ? this.getValue('lastMessage') : this.lastMessage;
    const plainVal = typeof rawVal === 'string' ? rawVal : String(rawVal);
    if (!isEncrypted(plainVal)) {
      this.set('lastMessage', encrypt(plainVal));
    }
  }
  next();
});

chatSchema.set('toJSON', { getters: true });
chatSchema.set('toObject', { getters: true });

chatSchema.index({ participants: 1 });
chatSchema.index({ lastMessageAt: -1 });

const Chat = mongoose.model('Chat', chatSchema);

// ===== Individual Messages =====
const messageSchema = new mongoose.Schema({
  chat: { type: mongoose.Schema.Types.ObjectId, ref: 'Chat', required: true },
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, default: '' },
  type: { type: String, enum: ['text', 'image', 'voice', 'location', 'system'], default: 'text' },
  mediaUrl: { type: String, default: '' },
  readBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  isDeleted: { type: Boolean, default: false },
  isEdited: { type: Boolean, default: false },
  editedAt: { type: Date, default: null },
  // Reply support
  replyTo: {
    messageId: { type: mongoose.Schema.Types.ObjectId, ref: 'Message', default: null },
    content: { type: String, default: '' },
    senderName: { type: String, default: '' },
    senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  },
  // Reactions
  reactions: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    emoji: String,
    createdAt: { type: Date, default: Date.now },
  }],
}, { timestamps: true });

// Auto-decrypt content and mediaUrl on read
const MESSAGE_ENCRYPTED_FIELDS = ['content', 'mediaUrl'];
for (const field of MESSAGE_ENCRYPTED_FIELDS) {
  messageSchema.path(field).get(function (val) {
    if (!val || typeof val !== 'string') return val;
    return decrypt(val);
  });
}

// Auto-encrypt content and mediaUrl before save
messageSchema.pre('save', function (next) {
  for (const field of MESSAGE_ENCRYPTED_FIELDS) {
    if (this.isModified(field) && this[field]) {
      const rawVal = this.getValue ? this.getValue(field) : this[field];
      const plainVal = typeof rawVal === 'string' ? rawVal : String(rawVal);
      if (!isEncrypted(plainVal)) {
        this.set(field, encrypt(plainVal));
      }
    }
  }
  next();
});

messageSchema.set('toJSON', { getters: true });
messageSchema.set('toObject', { getters: true });

messageSchema.index({ chat: 1, createdAt: -1 });

const Message = mongoose.model('Message', messageSchema);

module.exports = { Chat, Message };
