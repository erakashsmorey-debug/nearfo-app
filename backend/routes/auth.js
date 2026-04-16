const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const admin = require('firebase-admin');
const User = require('../models/User');
const Otp = require('../models/OTP');
const { generateToken, protect } = require('../middleware/auth');
const { reverseGeocode, isValidCoordinates } = require('../utils/location');
const { hmacHash, encryptUpdateData, decryptUserData } = require('../utils/encryption');

// POST /api/auth/send-otp
// Generate and send OTP (dev mode: returns OTP in response)
router.post('/send-otp', async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ success: false, message: 'Phone number required' });
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Store OTP in MongoDB with 5-minute expiry (replaces any existing OTP for this phone)
    await Otp.findOneAndUpdate(
      { phone },
      { otp, expiresAt: new Date(Date.now() + 5 * 60 * 1000) },
      { upsert: true, new: true }
    );

    console.log(`[OTP] Generated for ${phone}: ${otp}`);

    // In production, send SMS here (Twilio, MSG91, etc.)
    // For now, return OTP in response for testing
    res.json({
      success: true,
      message: 'OTP sent successfully',
      otp, // DEV ONLY — remove in production
    });
  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({ success: false, message: 'Failed to send OTP' });
  }
});

// POST /api/auth/verify-otp
// Verify OTP and login/register user
router.post('/verify-otp', async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ success: false, message: 'Phone and OTP required' });
    }

    // Check OTP from MongoDB
    const stored = await Otp.findOne({ phone });
    if (!stored) {
      return res.status(400).json({ success: false, message: 'OTP expired or not found. Please request a new one.' });
    }

    if (new Date() > stored.expiresAt) {
      await Otp.deleteOne({ _id: stored._id });
      return res.status(400).json({ success: false, message: 'OTP expired. Please request a new one.' });
    }

    if (stored.otp !== otp) {
      return res.status(400).json({ success: false, message: 'Invalid OTP' });
    }

    // OTP verified — clear it
    await Otp.deleteOne({ _id: stored._id });

    // Find user by phone hash (encrypted lookup)
    const phoneHashValue = hmacHash(phone);
    let user = await User.findOne({ phoneHash: phoneHashValue });

    // Fallback: check old plain-text phone (for pre-encryption users)
    if (!user) {
      user = await User.findOne({ phone });
    }

    let isNewUser = false;

    if (!user) {
      isNewUser = true;
      // Generate a unique firebaseUid from phone (since we're not using Firebase auth)
      const fakeUid = crypto.createHash('sha256').update(phone).digest('hex').slice(0, 28);
      const handle = `user_${fakeUid.slice(0, 8)}`;
      user = await User.create({
        firebaseUid: fakeUid,
        phone,
        name: handle, // Temporary name (user sets real name in profile setup)
        handle,
      });
    }

    // Update online status
    user.isOnline = true;
    user.lastSeen = new Date();
    await user.save();

    // Generate JWT
    const token = generateToken(user._id);

    res.json({
      success: true,
      token,
      user,
      isNewUser,
    });
  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({ success: false, message: 'Verification failed' });
  }
});

// POST /api/auth/firebase-login
// Verify Firebase ID token from Phone Auth & create/login user (FREE SMS via Firebase)
router.post('/firebase-login', async (req, res) => {
  try {
    const { idToken, phone, email, displayName, photoUrl } = req.body;

    if (!idToken) {
      return res.status(400).json({ success: false, message: 'Firebase ID token required' });
    }

    // Verify Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const firebaseUid = decodedToken.uid;
    const firebasePhone = decodedToken.phone_number || phone;
    const firebaseEmail = decodedToken.email || email;
    const isGoogleLogin = !!firebaseEmail && !firebasePhone;

    if (!firebasePhone && !firebaseEmail) {
      return res.status(400).json({ success: false, message: 'Phone or email required for login' });
    }

    // Find user by Firebase UID
    let user = await User.findOne({ firebaseUid });
    let isNewUser = false;

    // Fallback: find by phone hash (for users who were created via old OTP flow)
    if (!user && firebasePhone) {
      const phoneHashValue = hmacHash(firebasePhone);
      user = await User.findOne({ phoneHash: phoneHashValue });
      if (user) {
        // Link existing user to Firebase UID
        user.firebaseUid = firebaseUid;
        if (firebaseEmail) user.email = firebaseEmail;
        await user.save();
      }
    }

    // Fallback: find by email hash (for Google login users)
    if (!user && firebaseEmail) {
      const emailHashValue = hmacHash(firebaseEmail);
      user = await User.findOne({ emailHash: emailHashValue });
      if (user) {
        user.firebaseUid = firebaseUid;
        await user.save();
      }
    }

    // Fallback: find by plain phone (for pre-encryption users)
    if (!user && firebasePhone) {
      user = await User.findOne({ phone: firebasePhone });
      if (user) {
        user.firebaseUid = firebaseUid;
        await user.save();
      }
    }

    if (!user) {
      // New user — create account
      isNewUser = true;
      const handle = `user_${firebaseUid.slice(0, 8)}`;
      const userData = {
        firebaseUid,
        name: displayName || '',
        handle,
      };

      if (firebasePhone) {
        userData.phone = firebasePhone;
        userData.phoneHash = hmacHash(firebasePhone);
      }
      if (firebaseEmail) {
        userData.email = firebaseEmail;
        userData.emailHash = hmacHash(firebaseEmail);
      }
      if (photoUrl) {
        userData.avatarUrl = photoUrl;
      }

      user = await User.create(userData);
    }

    // Update online status
    user.isOnline = true;
    user.lastSeen = new Date();
    await user.save();

    // Generate JWT
    const token = generateToken(user._id);

    res.json({
      success: true,
      token,
      user,
      isNewUser,
    });
  } catch (error) {
    console.error('Firebase login error:', error);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ success: false, message: 'Token expired. Please try again.' });
    }
    if (error.code === 'auth/argument-error' || error.code === 'auth/invalid-argument') {
      return res.status(400).json({ success: false, message: 'Invalid token format.' });
    }
    res.status(500).json({ success: false, message: 'Authentication failed' });
  }
});

// POST /api/auth/verify-phone
// Verify Firebase phone token & create/login user (legacy)
router.post('/verify-phone', async (req, res) => {
  try {
    const { firebaseToken } = req.body;

    if (!firebaseToken) {
      return res.status(400).json({ success: false, message: 'Firebase token required' });
    }

    // Verify Firebase token
    const decodedToken = await admin.auth().verifyIdToken(firebaseToken);
    const { uid, phone_number } = decodedToken;

    // Check if user exists
    let user = await User.findOne({ firebaseUid: uid });
    let isNewUser = false;

    if (!user) {
      // New user - create account
      isNewUser = true;
      user = await User.create({
        firebaseUid: uid,
        phone: phone_number,
        name: '',
        handle: `user_${uid.slice(0, 8)}`, // temporary handle
      });
    }

    // Update online status
    user.isOnline = true;
    user.lastSeen = new Date();
    await user.save();

    // Generate JWT
    const token = generateToken(user._id);

    res.json({
      success: true,
      token,
      user,
      isNewUser,
    });
  } catch (error) {
    console.error('Auth error:', error);
    res.status(500).json({ success: false, message: 'Authentication failed' });
  }
});

// PUT /api/auth/setup-profile
// Complete profile setup for new users
// Location is auto-resolved via Nominatim (FREE) from lat/long
router.put('/setup-profile', protect, async (req, res) => {
  try {
    const { name, handle, bio, avatarUrl, latitude, longitude, interests, dateOfBirth, showDobOnProfile } = req.body;

    // Validate handle uniqueness
    if (handle) {
      const cleanHandle = handle.toLowerCase().replace(/[^a-z0-9_]/g, '');
      if (cleanHandle.length < 3) {
        return res.status(400).json({ success: false, message: 'Handle must be at least 3 characters' });
      }
      const existing = await User.findOne({ handle: cleanHandle, _id: { $ne: req.user._id } });
      if (existing) {
        return res.status(400).json({ success: false, message: 'Handle already taken' });
      }
    }

    const updateData = {};
    if (name) updateData.name = name.trim();
    if (handle) updateData.handle = handle.toLowerCase().replace(/[^a-z0-9_]/g, '');
    if (bio !== undefined) updateData.bio = bio.trim();
    if (avatarUrl) updateData.avatarUrl = avatarUrl;
    if (interests && Array.isArray(interests)) updateData.interests = interests;
    if (dateOfBirth) updateData.dateOfBirth = new Date(dateOfBirth).toISOString();
    if (typeof showDobOnProfile === 'boolean') updateData.showDobOnProfile = showDobOnProfile;

    // ===== LOCATION HANDLING (FREE via Nominatim) =====
    if (latitude && longitude && isValidCoordinates(latitude, longitude)) {
      updateData.location = {
        type: 'Point',
        coordinates: [longitude, latitude],
      };

      const geo = await reverseGeocode(latitude, longitude);
      updateData.city = geo.city;
      updateData.state = geo.state;
      updateData.country = geo.country;

      console.log(`📍 Location resolved: ${geo.city}, ${geo.state} (${latitude}, ${longitude})`);
    }

    // Encrypt personal data before update
    const encryptedData = encryptUpdateData(updateData);

    const user = await User.findByIdAndUpdate(req.user._id, encryptedData, {
      new: true,
      runValidators: true,
    });

    const userObj = user.toObject();
    decryptUserData(userObj);
    res.json({ success: true, user: userObj });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/auth/update-profile
// Update existing profile (name, bio, avatar, interests)
router.put('/update-profile', protect, async (req, res) => {
  try {
    const { name, bio, avatarUrl, interests, feedPreference, notificationsEnabled, profileVisibility, hideFollowersList, showDobOnProfile, showOnlineStatus, dateOfBirth } = req.body;

    const updateData = {};
    if (name) updateData.name = name.trim();
    if (bio !== undefined) updateData.bio = bio.trim();
    if (avatarUrl) updateData.avatarUrl = avatarUrl;
    if (interests && Array.isArray(interests)) updateData.interests = interests;
    if (feedPreference) updateData.feedPreference = feedPreference;
    if (typeof notificationsEnabled === 'boolean') updateData.notificationsEnabled = notificationsEnabled;
    if (profileVisibility) updateData.profileVisibility = profileVisibility;
    if (typeof hideFollowersList === 'boolean') updateData.hideFollowersList = hideFollowersList;
    if (typeof showDobOnProfile === 'boolean') updateData.showDobOnProfile = showDobOnProfile;
    if (typeof showOnlineStatus === 'boolean') updateData.showOnlineStatus = showOnlineStatus;
    if (dateOfBirth) updateData.dateOfBirth = new Date(dateOfBirth).toISOString();
    if (dateOfBirth === null) updateData.dateOfBirth = null;

    // Encrypt personal data before update
    const encryptedData = encryptUpdateData(updateData);

    const user = await User.findByIdAndUpdate(req.user._id, encryptedData, {
      new: true,
      runValidators: true,
    });

    const userObj = user.toObject();
    decryptUserData(userObj);
    res.json({ success: true, user: userObj });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/me
// Get current user profile
router.get('/me', protect, async (req, res) => {
  const Follow = require('../models/Follow');
  const followersCount = await Follow.countDocuments({ following: req.user._id });
  const followingCount = await Follow.countDocuments({ follower: req.user._id });

  const userObj = req.user.toObject();
  decryptUserData(userObj);
  res.json({
    success: true,
    user: {
      ...userObj,
      followersCount,
      followingCount,
    },
  });
});

// POST /api/auth/fcm-token - Register FCM push token
router.post('/fcm-token', protect, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) return res.status(400).json({ success: false, message: 'fcmToken required' });

    req.user.fcmToken = fcmToken;
    await req.user.save();
    res.json({ success: true, message: 'FCM token registered' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/logout
router.post('/logout', protect, async (req, res) => {
  try {
    req.user.isOnline = false;
    req.user.lastSeen = new Date();
    await req.user.save();
    res.json({ success: true, message: 'Logged out' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/update-location
// Update location in background (when user moves)
router.post('/update-location', protect, async (req, res) => {
  try {
    const { latitude, longitude } = req.body;

    if (!isValidCoordinates(latitude, longitude)) {
      return res.status(400).json({ success: false, message: 'Invalid coordinates' });
    }

    req.user.location = {
      type: 'Point',
      coordinates: [longitude, latitude],
    };

    // Only resolve city if it changed significantly (> 5km from last known)
    const geo = await reverseGeocode(latitude, longitude);
    if (geo.city !== 'Unknown') {
      // These will be encrypted by the pre-save hook
      req.user.city = geo.city;
      req.user.state = geo.state;
    }

    await req.user.save();

    // Return full updated user so Flutter can refresh the UI
    const userObj = req.user.toObject();
    decryptUserData(userObj);
    res.json({ success: true, message: 'Location updated', city: geo.city, user: userObj });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/location-search
// Search places (for manual location selection) — FREE via Nominatim
router.get('/location-search', protect, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.length < 2) {
      return res.status(400).json({ success: false, message: 'Search query too short' });
    }

    const { forwardGeocode } = require('../utils/location');
    const results = await forwardGeocode(q);

    res.json({ success: true, results });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/analytics
const Post = require('../models/Post');
const Reel = require('../models/Reel');
const Follow = require('../models/Follow');

router.get('/analytics', protect, async (req, res) => {
  try {
    const userId = req.user._id;

    const [postStats, reelStats, followersCount, followingCount] = await Promise.all([
      Post.aggregate([
        { $match: { author: userId } },
        { $group: { _id: null, totalPosts: { $sum: 1 }, totalLikes: { $sum: { $size: '$likes' } }, totalComments: { $sum: '$commentsCount' }, totalViews: { $sum: '$viewsCount' } } }
      ]),
      Reel.aggregate([
        { $match: { author: userId } },
        { $group: { _id: null, totalReels: { $sum: 1 }, totalLikes: { $sum: { $size: '$likes' } }, totalComments: { $sum: '$commentsCount' }, totalViews: { $sum: '$viewsCount' } } }
      ]),
      Follow.countDocuments({ following: userId }),
      Follow.countDocuments({ follower: userId }),
    ]);

    const ps = postStats[0] || { totalPosts: 0, totalLikes: 0, totalComments: 0, totalViews: 0 };
    const rs = reelStats[0] || { totalReels: 0, totalLikes: 0, totalComments: 0, totalViews: 0 };

    const totalContent = ps.totalPosts + rs.totalReels;
    const totalEngagement = ps.totalLikes + ps.totalComments + rs.totalLikes + rs.totalComments;
    const totalViews = ps.totalViews + rs.totalViews;
    const engagementRate = totalViews > 0 ? ((totalEngagement / totalViews) * 100).toFixed(2) : 0;

    const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const [weeklyPosts, weeklyReels, weeklyFollowers] = await Promise.all([
      Post.countDocuments({ author: userId, createdAt: { $gte: oneWeekAgo } }),
      Reel.countDocuments({ author: userId, createdAt: { $gte: oneWeekAgo } }),
      Follow.countDocuments({ following: userId, createdAt: { $gte: oneWeekAgo } }),
    ]);

    const nearfoScore = Math.min(100, Math.round(
      (followersCount * 0.3) + (totalEngagement * 0.25) + (totalContent * 0.2) + (totalViews * 0.001 * 0.15) + (engagementRate * 0.1)
    ));

    await User.findByIdAndUpdate(userId, { nearfoScore });

    res.json({
      success: true,
      analytics: {
        posts: ps, reels: rs,
        followers: followersCount, following: followingCount,
        totalContent, totalEngagement, totalViews, engagementRate: Number(engagementRate),
        weekly: { posts: weeklyPosts, reels: weeklyReels, newFollowers: weeklyFollowers },
        nearfoScore,
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
