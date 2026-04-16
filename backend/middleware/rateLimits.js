const rateLimit = require('express-rate-limit');

const limiterOptions = { validate: { xForwardedForHeader: false, trustProxy: false } };

// Upload: 30 uploads per 15 min (heavy operation)
const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { success: false, message: 'Too many uploads. Try again in a few minutes.' },
  ...limiterOptions,
});

// Post/Reel creation: 20 per 15 min
const createLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { success: false, message: 'Too many posts. Slow down!' },
  ...limiterOptions,
});

// Like/Comment/Follow: 100 per 15 min (fast actions)
const engagementLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { success: false, message: 'Too many actions. Please slow down.' },
  ...limiterOptions,
});

// Search: 30 per 15 min
const searchLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { success: false, message: 'Too many searches. Try again later.' },
  ...limiterOptions,
});

// Chat messages: 60 per minute
const chatLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  message: { success: false, message: 'Sending messages too fast.' },
  ...limiterOptions,
});

// Live stream: 5 starts per hour
const liveLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  message: { success: false, message: 'Too many live streams. Try again later.' },
  ...limiterOptions,
});

module.exports = { uploadLimiter, createLimiter, engagementLimiter, searchLimiter, chatLimiter, liveLimiter };
