const mongoose = require('mongoose');
const {
  encrypt,
  decrypt,
  hmacHash,
  isEncrypted,
  ENCRYPTED_FIELDS,
  SEARCHABLE_ENCRYPTED_FIELDS,
  DATE_ENCRYPTED_FIELDS,
} = require('../utils/encryption');

const userSchema = new mongoose.Schema({
  firebaseUid: { type: String, required: true, unique: true },
  name: { type: String, required: true, trim: true, maxlength: 200 },
  handle: { type: String, required: true, unique: true, trim: true, lowercase: true, maxlength: 30 },
  phone: { type: String, required: true },
  phoneHash: { type: String, unique: true, sparse: true },
  email: { type: String, trim: true },
  emailHash: { type: String, sparse: true },
  bio: { type: String, maxlength: 500, default: '' },
  avatarUrl: { type: String, default: '' },

  // Location
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] },
  },
  city: { type: String, default: '' },
  state: { type: String, default: '' },
  country: { type: String, default: 'India' },

  // Stats
  followers: { type: Number, default: 0 },
  following: { type: Number, default: 0 },
  postsCount: { type: Number, default: 0 },
  nearfoScore: { type: Number, default: 0, min: 0, max: 100 },

  // Status
  isVerified: { type: Boolean, default: false },
  isOnline: { type: Boolean, default: false },
  lastSeen: { type: Date, default: Date.now },
  isPremium: { type: Boolean, default: false },

  // Ban/Suspend
  isBanned: { type: Boolean, default: false },
  banReason: { type: String, default: '' },
  bannedAt: { type: Date, default: null },
  bannedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  suspendedUntil: { type: Date, default: null }, // null = not suspended, date = suspended until
  suspendReason: { type: String, default: '' },
  banHistory: [{
    action: { type: String, enum: ['ban', 'unban', 'suspend', 'unsuspend'] },
    reason: String,
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    at: { type: Date, default: Date.now },
    duration: String, // e.g. "7 days", "permanent"
  }],

  // Push Notifications
  fcmToken: { type: String, default: '' },

  // Preferences
  interests: [{ type: String }],
  feedPreference: { type: String, enum: ['local', 'global', 'mixed', 'nearby', 'trending'], default: 'mixed' },
  notificationsEnabled: { type: Boolean, default: true },
  profileVisibility: { type: String, enum: ['public', 'local', 'private'], default: 'public' },
  hideFollowersList: { type: Boolean, default: false },
  showDobOnProfile: { type: Boolean, default: true },
  showOnlineStatus: { type: Boolean, default: true },
  hideOnlineFrom: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // Per-user online visibility
  dateOfBirth: { type: String, default: null },

}, { timestamps: true });

// ===== GETTERS — auto-decrypt when reading fields =====
// This ensures req.user.name, req.user.city etc. return decrypted values
const allEncryptedFields = [...ENCRYPTED_FIELDS, ...Object.keys(SEARCHABLE_ENCRYPTED_FIELDS), ...DATE_ENCRYPTED_FIELDS];

for (const field of allEncryptedFields) {
  userSchema.path(field).get(function (val) {
    if (!val || typeof val !== 'string') return val;
    return decrypt(val);
  });
}

// ===== PRE-SAVE HOOK — encrypt before writing to DB =====
userSchema.pre('save', function (next) {
  // Encrypt regular fields
  for (const field of ENCRYPTED_FIELDS) {
    if (this.isModified(field) && this[field]) {
      // Access raw value (bypass getter) using $__getValue or direct schema path
      const rawVal = this.getValue ? this.getValue(field) : this[field];
      const plainVal = typeof rawVal === 'string' ? rawVal : String(rawVal);
      if (!isEncrypted(plainVal)) {
        this.set(field, encrypt(plainVal));
      }
    }
  }

  // Encrypt searchable fields + generate hash
  for (const [field, hashField] of Object.entries(SEARCHABLE_ENCRYPTED_FIELDS)) {
    if (this.isModified(field) && this[field]) {
      const rawVal = this.getValue ? this.getValue(field) : this[field];
      const plainVal = typeof rawVal === 'string' ? rawVal : String(rawVal);
      if (!isEncrypted(plainVal)) {
        // Hash uses the plain value for deterministic lookups
        this[hashField] = hmacHash(plainVal);
        this.set(field, encrypt(plainVal));
      }
    }
  }

  // Encrypt date fields
  for (const field of DATE_ENCRYPTED_FIELDS) {
    if (this.isModified(field) && this[field]) {
      const rawVal = this.getValue ? this.getValue(field) : this[field];
      const plainVal = rawVal instanceof Date ? rawVal.toISOString() : String(rawVal);
      if (!isEncrypted(plainVal)) {
        this.set(field, encrypt(plainVal));
      }
    }
  }

  next();
});

// ===== toJSON / toObject TRANSFORMS =====
// Getters auto-decrypt fields; transform just cleans up hash fields
const cleanTransform = function (doc, ret) {
  // Remove internal hash fields from API responses
  delete ret.phoneHash;
  delete ret.emailHash;
  return ret;
};

userSchema.set('toJSON', { getters: true, transform: cleanTransform });
userSchema.set('toObject', { getters: true, transform: cleanTransform });

// ===== INDEXES =====
userSchema.index({ location: '2dsphere' });
userSchema.index({ handle: 1 });
userSchema.index({ phoneHash: 1 });
userSchema.index({ emailHash: 1 });
userSchema.index({ nearfoScore: -1 });
userSchema.index({ isBanned: 1 }); // Moderation queries
userSchema.index({ interests: 1 }); // Suggested users queries

module.exports = mongoose.model('User', userSchema);
