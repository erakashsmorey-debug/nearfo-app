/**
 * Ban/Suspend Check Middleware
 * Checks if user is banned or suspended before allowing API access.
 * Add this AFTER auth middleware: router.post('/', protect, checkBan, ...)
 */

function checkBan(req, res, next) {
  if (!req.user) return next();

  // Permanently banned
  if (req.user.isBanned) {
    return res.status(403).json({
      success: false,
      message: 'Your account has been permanently banned',
      reason: req.user.banReason || 'Community guidelines violation',
      banned: true,
    });
  }

  // Temporarily suspended
  if (req.user.suspendedUntil) {
    const now = new Date();
    if (now < new Date(req.user.suspendedUntil)) {
      const remaining = Math.ceil((new Date(req.user.suspendedUntil) - now) / (1000 * 60 * 60));
      return res.status(403).json({
        success: false,
        message: `Your account is suspended for ${remaining} more hours`,
        reason: req.user.suspendReason || 'Temporary suspension',
        suspendedUntil: req.user.suspendedUntil,
        suspended: true,
      });
    }
    // Suspension expired — auto-clear
    req.user.suspendedUntil = null;
    req.user.suspendReason = '';
    req.user.save().catch(() => {});
  }

  next();
}

module.exports = { checkBan };
