const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Follow = require('../models/Follow');
const Post = require('../models/Post');
const Reel = require('../models/Reel');
const Notification = require('../models/Notification');
const { protect } = require('../middleware/auth');
const { decryptUserData } = require('../utils/encryption');

const NEARFO_RADIUS_KM = parseInt(process.env.NEARFO_RADIUS_KM) || 500;
const EARTH_RADIUS_KM = 6371;

// GET /api/users/nearby
// Find users within 500km radius
router.get('/nearby', protect, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const [lng, lat] = req.user.location.coordinates;

    const users = await User.find({
      _id: { $ne: req.user._id },
      location: {
        $geoWithin: {
          $centerSphere: [[lng, lat], NEARFO_RADIUS_KM / EARTH_RADIUS_KM],
        },
      },
    })
      .select('name handle avatarUrl bio city isVerified nearfoScore isOnline')
      .sort({ nearfoScore: -1 })
      .limit(parseInt(limit))
      .skip((page - 1) * limit);

    // Check follow status & add distance
    const myFollows = await Follow.find({ follower: req.user._id }).select('following');
    const followingSet = new Set(myFollows.map((f) => f.following.toString()));

    const usersWithDistance = users.map((u) => {
      const [uLng, uLat] = u.location?.coordinates || [0, 0];
      const dist = calculateDistance(lat, lng, uLat, uLng);
      const obj = u.toObject();
      decryptUserData(obj);
      return {
        ...obj,
        distanceKm: Math.round(dist * 10) / 10,
        isFollowing: followingSet.has(u._id.toString()),
      };
    });

    res.json({ success: true, users: usersWithDistance, count: users.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/users/search/:query
// Search users by name or handle
router.get('/search/:query', protect, async (req, res) => {
  try {
    const query = req.params.query;
    const users = await User.find({
      $or: [
        { name: { $regex: query, $options: 'i' } },
        { handle: { $regex: query, $options: 'i' } },
      ],
    })
      .select('name handle avatarUrl bio city isVerified nearfoScore')
      .limit(20);

    // Check follow status
    const myFollows = await Follow.find({ follower: req.user._id }).select('following');
    const followingSet = new Set(myFollows.map((f) => f.following.toString()));

    const usersWithFollowStatus = users.map((u) => {
      const obj = u.toObject();
      decryptUserData(obj);
      return {
        ...obj,
        isFollowing: followingSet.has(u._id.toString()),
      };
    });

    res.json({ success: true, users: usersWithFollowStatus });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/users/nearfo-score
// Calculate and return the user's Nearfo Score with breakdown
router.get('/nearfo-score', protect, async (req, res) => {
  try {
    const userId = req.user._id;

    // Fetch counts
    const [postsCount, reelsCount, followersCount] = await Promise.all([
      Post.countDocuments({ author: userId }),
      Reel.countDocuments({ author: userId }),
      Follow.countDocuments({ following: userId }),
    ]);

    // Fetch engagement stats
    const postStats = await Post.aggregate([
      { $match: { author: userId } },
      { $group: { _id: null, totalLikes: { $sum: '$likesCount' }, totalViews: { $sum: '$viewsCount' }, totalComments: { $sum: '$commentsCount' } } }
    ]);
    const reelStats = await Reel.aggregate([
      { $match: { author: userId } },
      { $group: { _id: null, totalLikes: { $sum: '$likesCount' }, totalViews: { $sum: '$viewsCount' } } }
    ]);

    const totalLikes = (postStats[0]?.totalLikes || 0) + (reelStats[0]?.totalLikes || 0);
    const totalViews = (postStats[0]?.totalViews || 0) + (reelStats[0]?.totalViews || 0);
    const totalComments = postStats[0]?.totalComments || 0;
    const engagementRate = totalViews > 0 ? Math.round(((totalLikes + totalComments) / totalViews) * 100) : 0;

    // Score calculation (each category max 20, total max 100)
    const postsScore = Math.min(20, postsCount * 4);
    const reelsScore = Math.min(20, reelsCount * 4);
    const followersScore = Math.min(20, followersCount * 2);
    const engagementScore = Math.min(20, engagementRate);
    const activityScore = Math.min(20, Math.floor((totalLikes + totalViews) / 5));

    const totalScore = postsScore + reelsScore + followersScore + engagementScore + activityScore;

    // Update user's nearfoScore in DB
    await User.findByIdAndUpdate(userId, { nearfoScore: totalScore });

    const user = req.user.toObject ? req.user.toObject() : req.user;
    decryptUserData(user);

    res.json({
      success: true,
      score: totalScore,
      user: { name: user.name, handle: user.handle, avatarUrl: user.avatarUrl },
      breakdown: {
        posts: { score: postsScore, weight: 20, count: postsCount },
        reels: { score: reelsScore, weight: 20, count: reelsCount },
        followers: { score: followersScore, weight: 20, count: followersCount },
        engagement: { score: engagementScore, weight: 20, rate: engagementRate },
        activity: { score: activityScore, weight: 20, likes: totalLikes, views: totalViews },
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/users/suggested - Personalized user suggestions (Explore/Discover)
// Respects user's feedPreference: 'local'/'nearby' = 500km only, 'global'/'trending' = no geo, 'mixed' = both
router.get('/suggested', protect, async (req, res) => {
  try {
    const { limit = 20, mode } = req.query;

    // Determine filter mode: query param > user preference > default 'mixed'
    const pref = mode || req.user.feedPreference || 'mixed';
    const isLocal = pref === 'local' || pref === 'nearby';
    const isGlobal = pref === 'global' || pref === 'trending';

    // Get who I already follow
    const myFollows = await Follow.find({ follower: req.user._id }).select('following');
    const followingIds = myFollows.map(f => f.following.toString());
    followingIds.push(req.user._id.toString()); // exclude self

    // Strategy 1: Friends of friends (people my friends follow, but I don't)
    const friendsFollows = await Follow.find({
      follower: { $in: myFollows.map(f => f.following) },
      following: { $nin: followingIds },
    }).select('following');

    // Count how many mutual friends follow each suggested user
    const mutualCount = {};
    friendsFollows.forEach(f => {
      const id = f.following.toString();
      if (!followingIds.includes(id)) {
        mutualCount[id] = (mutualCount[id] || 0) + 1;
      }
    });

    // Strategy 2: Same interests
    const myInterests = req.user.interests || [];

    // Strategy 3: Nearby users — only apply geo filter for local/nearby/mixed
    const [lng, lat] = req.user.location?.coordinates || [0, 0];
    const hasLocation = lng !== 0 || lat !== 0;

    let nearbyQuery = {};
    if (hasLocation && !isGlobal) {
      // For 'local'/'nearby' or 'mixed' — apply 500km radius filter
      nearbyQuery = {
        location: {
          $geoWithin: {
            $centerSphere: [[lng, lat], NEARFO_RADIUS_KM / EARTH_RADIUS_KM],
          },
        },
      };
    }

    // Fetch candidate users (not already following)
    const candidates = await User.find({
      _id: { $nin: followingIds },
      ...nearbyQuery,
    })
      .select('name handle avatarUrl bio city interests isVerified nearfoScore isOnline followers location')
      .limit(isLocal ? 200 : 100);

    // Score each candidate
    const scored = candidates.map(u => {
      const userObj = u.toObject();
      decryptUserData(userObj);
      let score = 0;

      // Calculate distance if both users have location
      let distanceKm = null;
      const [uLng, uLat] = u.location?.coordinates || [0, 0];
      if (hasLocation && (uLng !== 0 || uLat !== 0)) {
        distanceKm = Math.round(calculateDistance(lat, lng, uLat, uLng) * 10) / 10;
      }

      // For local mode, STRICTLY filter to 500km (double-check in case index returns edge cases)
      if (isLocal && distanceKm !== null && distanceKm > NEARFO_RADIUS_KM) {
        return null; // skip — outside radius
      }

      // Mutual friends boost (strongest signal)
      const mutuals = mutualCount[u._id.toString()] || 0;
      score += mutuals * 30;

      // Shared interests boost
      const sharedInterests = (u.interests || []).filter(i => myInterests.includes(i)).length;
      score += sharedInterests * 15;

      // Nearby boost for local mode (closer = higher score)
      if (isLocal && distanceKm !== null) {
        score += Math.max(0, 50 - (distanceKm / 4)); // 0-50 points based on proximity
      }

      // Popular users boost (follower count)
      score += Math.min(u.followers || 0, 100) * 0.5;

      // Verified boost
      if (u.isVerified) score += 20;

      // Nearfo score boost
      score += (u.nearfoScore || 0) * 0.3;

      // Remove location from response (privacy)
      delete userObj.location;

      return {
        ...userObj,
        distanceKm,
        mutualFriends: mutuals,
        sharedInterests,
        suggestionScore: Math.round(score),
        reason: mutuals > 0 ? `${mutuals} mutual friend${mutuals > 1 ? 's' : ''}`
          : sharedInterests > 0 ? 'Similar interests'
          : distanceKm !== null && distanceKm < 50 ? `${distanceKm}km away`
          : u.isVerified ? 'Popular creator'
          : 'Suggested for you',
      };
    }).filter(Boolean); // remove nulls (filtered out users)

    // Sort by score descending, take top N
    scored.sort((a, b) => b.suggestionScore - a.suggestionScore);
    const suggestions = scored.slice(0, parseInt(limit));

    res.json({ success: true, suggestions, total: suggestions.length, mode: pref });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/users/id/:userId
// Get user profile by MongoDB _id (used when handle is not available, e.g., from chat)
router.get('/id/:userId', protect, async (req, res) => {
  try {
    const user = await User.findById(req.params.userId)
      .select('-firebaseUid -phone -__v');

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const followersCount = await Follow.countDocuments({ following: user._id });
    const followingCount = await Follow.countDocuments({ follower: user._id });

    const isFollowing = await Follow.exists({
      follower: req.user._id,
      following: user._id,
    });

    const userObj = user.toObject();
    decryptUserData(userObj);
    res.json({
      success: true,
      user: {
        ...userObj,
        followersCount,
        followingCount,
        isFollowing: !!isFollowing,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/users/:handle
// Get user profile by handle
router.get('/:handle', protect, async (req, res) => {
  try {
    const user = await User.findOne({ handle: req.params.handle })
      .select('-firebaseUid -phone -__v');

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Get follower/following counts from Follow collection
    const followersCount = await Follow.countDocuments({ following: user._id });
    const followingCount = await Follow.countDocuments({ follower: user._id });

    // Check if current user follows this user
    const isFollowing = await Follow.exists({
      follower: req.user._id,
      following: user._id,
    });

    const userObj = user.toObject();
    decryptUserData(userObj);
    res.json({
      success: true,
      user: {
        ...userObj,
        followersCount,
        followingCount,
        isFollowing: !!isFollowing,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/users/:id/follow
// Follow/Unfollow a user (toggle)
router.post('/:id/follow', protect, async (req, res) => {
  try {
    if (req.params.id === req.user._id.toString()) {
      return res.status(400).json({ success: false, message: "Can't follow yourself" });
    }

    const targetUser = await User.findById(req.params.id);
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Check if already following
    const existingFollow = await Follow.findOne({
      follower: req.user._id,
      following: targetUser._id,
    });

    let isFollowing;

    if (existingFollow) {
      // Unfollow
      await existingFollow.deleteOne();
      isFollowing = false;
    } else {
      // Follow
      await Follow.create({
        follower: req.user._id,
        following: targetUser._id,
      });
      isFollowing = true;

      // Send notification
      await Notification.create({
        recipient: targetUser._id,
        sender: req.user._id,
        type: 'follow',
      });

      // Real-time notification + push for offline
      const io = req.app.get('io');
      const onlineUsers = req.app.get('onlineUsers');
      const recipientSocket = onlineUsers.get(targetUser._id.toString());
      if (recipientSocket) {
        io.to(recipientSocket).emit('new_notification', {
          type: 'follow',
          message: `${req.user.name} started following you`,
          userId: req.user._id,
        });
      } else {
        const { push } = require('../utils/pushNotify');
        push.follow(targetUser._id.toString(), req.user.name);
      }
    }

    // Get updated counts
    const followersCount = await Follow.countDocuments({ following: targetUser._id });
    const followingCount = await Follow.countDocuments({ follower: req.user._id });

    res.json({
      success: true,
      isFollowing,
      followersCount,
      followingCount,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/users/:id/followers
// Get followers list
router.get('/:id/followers', protect, async (req, res) => {
  try {
    // Check if user has hidden their followers list
    if (req.params.id !== req.user._id.toString()) {
      const targetUser = await User.findById(req.params.id).select('hideFollowersList');
      if (targetUser && targetUser.hideFollowersList) {
        return res.status(403).json({ success: false, message: 'This user has hidden their followers list' });
      }
    }

    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const follows = await Follow.find({ following: req.params.id })
      .populate('follower', 'name handle avatarUrl bio city isVerified nearfoScore')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const totalFollowers = await Follow.countDocuments({ following: req.params.id });

    // Check if current user follows each follower
    const myFollows = await Follow.find({ follower: req.user._id }).select('following');
    const followingSet = new Set(myFollows.map((f) => f.following.toString()));

    const followers = follows.map((f) => {
      const obj = f.follower.toObject();
      decryptUserData(obj);
      return {
        ...obj,
        isFollowing: followingSet.has(f.follower._id.toString()),
      };
    });

    res.json({
      success: true,
      followers,
      totalFollowers,
      page: parseInt(page),
      hasMore: skip + follows.length < totalFollowers,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/users/:id/following
// Get following list
router.get('/:id/following', protect, async (req, res) => {
  try {
    // Check if user has hidden their following list
    if (req.params.id !== req.user._id.toString()) {
      const targetUser = await User.findById(req.params.id).select('hideFollowersList');
      if (targetUser && targetUser.hideFollowersList) {
        return res.status(403).json({ success: false, message: 'This user has hidden their following list' });
      }
    }

    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const follows = await Follow.find({ follower: req.params.id })
      .populate('following', 'name handle avatarUrl bio city isVerified nearfoScore')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const totalFollowing = await Follow.countDocuments({ follower: req.params.id });

    // Check if current user follows each user
    const myFollows = await Follow.find({ follower: req.user._id }).select('following');
    const followingSet = new Set(myFollows.map((f) => f.following.toString()));

    const following = follows.map((f) => {
      const obj = f.following.toObject();
      decryptUserData(obj);
      return {
        ...obj,
        isFollowing: followingSet.has(f.following._id.toString()),
      };
    });

    res.json({
      success: true,
      following,
      totalFollowing,
      page: parseInt(page),
      hasMore: skip + follows.length < totalFollowing,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/users/online-status - Get online status for multiple users
router.post('/online-status', protect, async (req, res) => {
  try {
    const { userIds } = req.body;
    if (!userIds || !Array.isArray(userIds)) {
      return res.status(400).json({ success: false, message: 'userIds array required' });
    }
    const onlineUsers = req.app.get('onlineUsers');
    const statuses = {};
    for (const uid of userIds) {
      statuses[uid] = {
        isOnline: onlineUsers.has(uid),
      };
    }
    // Also fetch lastSeen from DB for offline users
    const users = await User.find({ _id: { $in: userIds } }).select('isOnline lastSeen');
    users.forEach(u => {
      if (statuses[u._id.toString()]) {
        statuses[u._id.toString()].lastSeen = u.lastSeen;
        // Override with real socket status
        statuses[u._id.toString()].isOnline = onlineUsers.has(u._id.toString()) || false;
      }
    });
    res.json({ success: true, statuses });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/users/location
// Update user location
router.put('/location', protect, async (req, res) => {
  try {
    const { latitude, longitude, city, state } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({ success: false, message: 'Latitude and longitude required' });
    }

    req.user.location = { type: 'Point', coordinates: [longitude, latitude] };
    if (city) req.user.city = city;
    if (state) req.user.state = state;
    await req.user.save();

    res.json({ success: true, message: 'Location updated' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ===== UTILITY =====
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

module.exports = router;
