/**
 * Input Sanitization Middleware
 * Strips HTML tags, script tags, and dangerous characters from user input.
 * Prevents XSS attacks and injection.
 */

// Regex to strip HTML/script tags
const SCRIPT_REGEX = /<script[^>]*>[\s\S]*?<\/script>/gi;
const HTML_TAG_REGEX = /<[^>]+>/g;
const EVENT_HANDLER_REGEX = /\bon\w+\s*=/gi;

function sanitizeString(str) {
  if (typeof str !== 'string') return str;
  return str
    .replace(SCRIPT_REGEX, '')      // Remove <script> tags
    .replace(EVENT_HANDLER_REGEX, '') // Remove onclick=, onload= etc
    .replace(HTML_TAG_REGEX, '')      // Remove all HTML tags
    .trim();
}

function sanitizeObject(obj) {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === 'string') return sanitizeString(obj);
  if (Array.isArray(obj)) return obj.map(sanitizeObject);
  if (typeof obj === 'object') {
    const sanitized = {};
    for (const [key, value] of Object.entries(obj)) {
      // Don't sanitize password, token, or media URL fields
      if (['password', 'token', 'mediaUrl', 'avatarUrl', 'coverUrl', 'imageUrl', 'videoUrl', 'presignedUrl', 'publicUrl', 'originalWorkUrl', 'contentUrl'].includes(key)) {
        sanitized[key] = value;
      } else {
        sanitized[key] = sanitizeObject(value);
      }
    }
    return sanitized;
  }
  return obj;
}

/**
 * Express middleware — sanitizes req.body, req.query, req.params
 */
function sanitizeInput(req, res, next) {
  if (req.body) req.body = sanitizeObject(req.body);
  if (req.query) req.query = sanitizeObject(req.query);
  if (req.params) req.params = sanitizeObject(req.params);
  next();
}

module.exports = { sanitizeInput, sanitizeString };
