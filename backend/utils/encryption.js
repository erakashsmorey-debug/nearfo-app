const crypto = require('crypto');

// AES-256-GCM encryption
const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const AUTH_TAG_LENGTH = 16;

// Keys loaded from environment variables
function getKey() {
  const key = process.env.ENCRYPTION_KEY;
  if (!key || key.length !== 64) {
    throw new Error('ENCRYPTION_KEY must be a 64-character hex string (32 bytes)');
  }
  return Buffer.from(key, 'hex');
}

function getHmacKey() {
  const key = process.env.HMAC_KEY;
  if (!key) {
    throw new Error('HMAC_KEY environment variable is required');
  }
  return key;
}

/**
 * Encrypt a plaintext string using AES-256-GCM
 * Returns format: iv:authTag:ciphertext (all hex)
 */
function encrypt(text) {
  if (!text && text !== 0) return text;
  const str = String(text);
  if (!str) return str;

  const key = getKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(str, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');

  return `${iv.toString('hex')}:${authTag}:${encrypted}`;
}

/**
 * Decrypt an encrypted string (iv:authTag:ciphertext format)
 * Returns plaintext string
 */
function decrypt(encryptedText) {
  if (!encryptedText || typeof encryptedText !== 'string') return encryptedText;

  // Check if it's actually encrypted (has the iv:tag:cipher format)
  const parts = encryptedText.split(':');
  if (parts.length !== 3) return encryptedText; // plain text, not encrypted

  // Validate hex format (iv should be 32 hex chars = 16 bytes)
  if (parts[0].length !== 32 || !/^[0-9a-f]+$/i.test(parts[0])) {
    return encryptedText; // not our encrypted format
  }

  try {
    const key = getKey();
    const iv = Buffer.from(parts[0], 'hex');
    const authTag = Buffer.from(parts[1], 'hex');
    const encrypted = parts[2];

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err) {
    // If decryption fails, return original (might be plain text from before encryption was added)
    console.warn('Decryption failed, returning original value:', err.message);
    return encryptedText;
  }
}

/**
 * Create a deterministic HMAC-SHA256 hash for searchable encrypted fields
 * Used for phone/email lookups without decrypting
 */
function hmacHash(text) {
  if (!text) return text;
  return crypto.createHmac('sha256', getHmacKey())
    .update(String(text).toLowerCase().trim())
    .digest('hex');
}

/**
 * Check if a value is already encrypted (matches our format)
 */
function isEncrypted(value) {
  if (!value || typeof value !== 'string') return false;
  const parts = value.split(':');
  return parts.length === 3 && parts[0].length === 32 && /^[0-9a-f]+$/i.test(parts[0]);
}

// Fields configuration
const ENCRYPTED_FIELDS = ['name', 'bio', 'city', 'state', 'country'];
const SEARCHABLE_ENCRYPTED_FIELDS = {
  phone: 'phoneHash',
  email: 'emailHash',
};
const DATE_ENCRYPTED_FIELDS = ['dateOfBirth'];

/**
 * Encrypt fields in an update object (for findByIdAndUpdate calls)
 */
function encryptUpdateData(data) {
  const encrypted = { ...data };

  // Encrypt regular fields
  for (const field of ENCRYPTED_FIELDS) {
    if (encrypted[field] !== undefined && encrypted[field] !== null && encrypted[field] !== '') {
      if (!isEncrypted(encrypted[field])) {
        encrypted[field] = encrypt(encrypted[field]);
      }
    }
  }

  // Encrypt searchable fields + generate hash
  for (const [field, hashField] of Object.entries(SEARCHABLE_ENCRYPTED_FIELDS)) {
    if (encrypted[field] !== undefined && encrypted[field] !== null && encrypted[field] !== '') {
      if (!isEncrypted(encrypted[field])) {
        encrypted[hashField] = hmacHash(encrypted[field]);
        encrypted[field] = encrypt(encrypted[field]);
      }
    }
  }

  // Encrypt date fields (convert to ISO string first)
  for (const field of DATE_ENCRYPTED_FIELDS) {
    if (encrypted[field] !== undefined && encrypted[field] !== null) {
      const dateStr = encrypted[field] instanceof Date
        ? encrypted[field].toISOString()
        : String(encrypted[field]);
      if (!isEncrypted(dateStr)) {
        encrypted[field] = encrypt(dateStr);
      }
    }
  }

  return encrypted;
}

/**
 * Decrypt fields in a plain object (for API responses)
 */
function decryptUserData(obj) {
  if (!obj) return obj;

  const allFields = [...ENCRYPTED_FIELDS, ...Object.keys(SEARCHABLE_ENCRYPTED_FIELDS), ...DATE_ENCRYPTED_FIELDS];

  for (const field of allFields) {
    if (obj[field] && typeof obj[field] === 'string') {
      obj[field] = decrypt(obj[field]);
    }
  }

  // Convert dateOfBirth back to Date object if it was decrypted
  if (obj.dateOfBirth && typeof obj.dateOfBirth === 'string' && !isEncrypted(obj.dateOfBirth)) {
    try {
      obj.dateOfBirth = new Date(obj.dateOfBirth);
    } catch (e) { /* leave as string */ }
  }

  // Remove hash fields from response
  delete obj.phoneHash;
  delete obj.emailHash;

  return obj;
}

module.exports = {
  encrypt,
  decrypt,
  hmacHash,
  isEncrypted,
  encryptUpdateData,
  decryptUserData,
  ENCRYPTED_FIELDS,
  SEARCHABLE_ENCRYPTED_FIELDS,
  DATE_ENCRYPTED_FIELDS,
};
