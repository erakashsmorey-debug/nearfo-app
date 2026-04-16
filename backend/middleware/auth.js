const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Protect routes - verify JWT token
const protect = async (req, res, next) => {
  try {
    let token;

    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({ success: false, message: 'Not authorized, no token' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id).select('-__v');

    if (!req.user) {
      return res.status(401).json({ success: false, message: 'User not found' });
    }

    // Block banned/suspended users
    if (req.user.isBanned) {
      return res.status(403).json({ success: false, message: 'Account has been banned' });
    }
    if (req.user.suspendedUntil && new Date(req.user.suspendedUntil) > new Date()) {
      return res.status(403).json({ success: false, message: 'Account is temporarily suspended' });
    }

    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Not authorized, token failed' });
  }
};

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });
};

module.exports = { protect, generateToken };
