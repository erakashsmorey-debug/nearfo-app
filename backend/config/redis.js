const Redis = require('ioredis');

let redis = null;

function getRedis() {
  if (redis) return redis;

  const redisUrl = process.env.REDIS_URL || 'redis://127.0.0.1:6379';

  try {
    redis = new Redis(redisUrl, {
      maxRetriesPerRequest: 3,
      retryStrategy(times) {
        if (times > 3) return null; // Stop retrying after 3 attempts
        return Math.min(times * 200, 2000);
      },
      lazyConnect: true,
    });

    redis.on('connect', () => console.log('[Redis] Connected'));
    redis.on('error', (err) => console.log('[Redis] Error (non-fatal):', err.message));

    redis.connect().catch(() => {
      console.log('[Redis] Connection failed — running without cache');
      redis = null;
    });
  } catch (err) {
    console.log('[Redis] Init failed — running without cache');
    redis = null;
  }

  return redis;
}

// Cache helpers with graceful fallback (app works without Redis)
async function cacheGet(key) {
  try {
    const r = getRedis();
    if (!r) return null;
    const data = await r.get(key);
    return data ? JSON.parse(data) : null;
  } catch (e) {
    return null;
  }
}

async function cacheSet(key, value, ttlSeconds = 300) {
  try {
    const r = getRedis();
    if (!r) return;
    await r.set(key, JSON.stringify(value), 'EX', ttlSeconds);
  } catch (e) {
    // Non-critical
  }
}

async function cacheDel(pattern) {
  try {
    const r = getRedis();
    if (!r) return;
    if (pattern.includes('*')) {
      const keys = await r.keys(pattern);
      if (keys.length > 0) await r.del(...keys);
    } else {
      await r.del(pattern);
    }
  } catch (e) {
    // Non-critical
  }
}

module.exports = { getRedis, cacheGet, cacheSet, cacheDel };
