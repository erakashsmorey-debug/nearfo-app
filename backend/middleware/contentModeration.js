/**
 * AI Content Moderation Middleware
 * Checks text content for harmful/inappropriate material before saving.
 * Uses keyword-based detection + pattern matching (no external API needed).
 * For production scale, integrate with AWS Rekognition (images) or OpenAI Moderation API.
 */

// Severity levels: 'block' = reject immediately, 'flag' = allow but flag for review
const BLOCKED_PATTERNS = [
  // Violence/threats
  { pattern: /\b(kill|murder|shoot|bomb|attack|terror)\b.*\b(you|them|him|her|people)\b/i, category: 'violence', severity: 'block' },
  // Hate speech patterns
  { pattern: /\b(hate|destroy|eliminate)\b.*\b(race|religion|community|caste)\b/i, category: 'hate_speech', severity: 'block' },
  // Self-harm
  { pattern: /\b(suicide|kill myself|end my life|self.?harm)\b/i, category: 'self_harm', severity: 'flag' },
  // Spam patterns
  { pattern: /(.)\1{10,}/i, category: 'spam', severity: 'flag' }, // Repeated characters
  { pattern: /(buy now|click here|free money|earn \$|lottery winner)/i, category: 'spam', severity: 'flag' },
  // Phone/WhatsApp spam
  { pattern: /\b(whatsapp|telegram|call me|msg me)\b.*\d{10}/i, category: 'spam', severity: 'flag' },
];

// Nudity/explicit keywords for text content
const EXPLICIT_KEYWORDS = [
  'nude', 'naked', 'xxx', 'porn', 'sex video', 'onlyfans',
  'send nudes', 'hookup', 'escort',
];

/**
 * Moderate text content
 * @param {string} text - Content to check
 * @returns {{ safe: boolean, blocked: boolean, flags: Array, category: string|null }}
 */
function moderateText(text) {
  if (!text || typeof text !== 'string') return { safe: true, blocked: false, flags: [], category: null };

  const textLower = text.toLowerCase();
  const flags = [];
  let blocked = false;
  let category = null;

  // Check blocked patterns
  for (const rule of BLOCKED_PATTERNS) {
    if (rule.pattern.test(textLower)) {
      flags.push({ category: rule.category, severity: rule.severity });
      if (rule.severity === 'block') {
        blocked = true;
        category = rule.category;
      }
    }
  }

  // Check explicit keywords
  for (const keyword of EXPLICIT_KEYWORDS) {
    if (textLower.includes(keyword)) {
      flags.push({ category: 'explicit', severity: 'block' });
      blocked = true;
      category = 'explicit';
      break;
    }
  }

  // Excessive caps (shouting/spam)
  const capsRatio = (text.match(/[A-Z]/g) || []).length / Math.max(text.length, 1);
  if (text.length > 20 && capsRatio > 0.7) {
    flags.push({ category: 'spam', severity: 'flag' });
  }

  // Too many links (spam)
  const linkCount = (text.match(/https?:\/\//g) || []).length;
  if (linkCount > 3) {
    flags.push({ category: 'spam', severity: 'flag' });
  }

  return {
    safe: flags.length === 0,
    blocked,
    flags,
    category,
  };
}

/**
 * Express middleware — checks req.body.content before proceeding
 * Usage: router.post('/', protect, moderateContent, async (req, res) => {...})
 */
function moderateContent(req, res, next) {
  const content = req.body.content || req.body.caption || req.body.text || '';
  const result = moderateText(content);

  if (result.blocked) {
    return res.status(400).json({
      success: false,
      message: 'Content violates community guidelines',
      moderationCategory: result.category,
    });
  }

  // Attach moderation flags for downstream use (flagging in DB)
  req.moderationFlags = result.flags;
  req.contentFlagged = result.flags.length > 0;

  next();
}

/**
 * Check image URL against known patterns (basic check)
 * For production: use AWS Rekognition DetectModerationLabels
 */
function moderateImageUrl(url) {
  if (!url) return { safe: true };
  const suspicious = /\b(nsfw|nude|xxx|porn|adult)\b/i.test(url);
  return { safe: !suspicious, flagged: suspicious };
}

module.exports = { moderateText, moderateContent, moderateImageUrl };
