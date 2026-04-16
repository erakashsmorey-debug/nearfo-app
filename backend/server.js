require('dotenv').config();
const express = require('express');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { createServer } = require('http');
const { Server } = require('socket.io');
const admin = require('firebase-admin');
const connectDB = require('./config/db');
const { connectRedis, setCache, getCache, deleteCache, deleteCachePattern, checkRateLimit: redisRateLimit } = require('./utils/redis');

// ===== FIREBASE ADMIN INIT =====
try {
  if (process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_CLIENT_EMAIL) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      }),
    });
    console.log('Firebase Admin initialized with service account');
  } else {
    // Fallback: initialize without credentials (uses default/env-based auth)
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID,
    });
    console.log('Firebase Admin initialized without service account credentials');
  }
} catch (err) {
  console.error('Firebase Admin init error (non-fatal):', err.message);
  try {
    admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
  } catch (e) {
    console.error('Firebase fallback init also failed:', e.message);
  }
}

// Initialize Express
const app = express();
app.set('trust proxy', 1); // Trust first proxy (NGINX)
const httpServer = createServer(app);

// Socket.io for real-time chat
const io = new Server(httpServer, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

// Connect Database
connectDB();

// Connect Redis (non-blocking — falls back to in-memory if unavailable)
connectRedis();

// ===== MIDDLEWARE =====
app.use(cors());
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "https://cdnjs.cloudflare.com"],
      scriptSrcAttr: ["'none'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"], // unsafe-inline needed for inline styles
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "wss:", "ws:"],
      objectSrc: ["'none'"],
      frameAncestors: ["'none'"],
    },
  },
}));
app.use(compression());
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Input sanitization — strip XSS from all requests
const { sanitizeInput } = require('./middleware/sanitize');
app.use(sanitizeInput);

// Force HTTPS in production (skip if behind reverse proxy like Nginx)
if (process.env.NODE_ENV === 'production' && process.env.SKIP_HTTPS_REDIRECT !== 'true') {
  app.use((req, res, next) => {
    // Trust proxy header from Nginx/load balancer
    const proto = req.headers['x-forwarded-proto'];
    const isLocalProxy = req.ip === '127.0.0.1' || req.ip === '::1' || req.ip === '::ffff:127.0.0.1';

    // If request comes from local proxy (Nginx), trust it — SSL is handled by Nginx
    if (isLocalProxy || proto === 'https' || req.secure) {
      return next();
    }
    return res.redirect(301, `https://${req.headers.host}${req.url}`);
  });
}

// Rate Limiting — generous global limit for normal app usage
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // 1000 requests per 15 min per IP (app makes many calls)
  message: { success: false, message: 'Too many requests, try again later' },
  validate: { xForwardedForHeader: false, trustProxy: false },
});
app.use('/api/', limiter);

// Stricter limiter for auth routes only (prevent OTP abuse)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20, // 20 auth attempts per 15 min
  message: { success: false, message: 'Too many login attempts, try again later' },
  validate: { xForwardedForHeader: false, trustProxy: false },
});
app.use('/api/auth/verify-phone', authLimiter);

// ===== API VERSIONING =====
const v1Router = require('./routes/v1');
const { responseEnvelope } = require('./middleware/responseEnvelope');

// Apply response envelope middleware to v1 routes
app.use('/api/v1', responseEnvelope);

// v1 routes (preferred — app 2.1+ uses these)
app.use('/api/v1', v1Router);

// Legacy routes (backward compat — app 2.0 and below)
app.use('/api', v1Router);

// Static files
app.use('/public', express.static(require('path').join(__dirname, 'public')));

// Boss Command Center UI — served but protected client-side with PIN gate
// Also add strict rate limit for boss page access
const bossPageLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30, // max 30 page loads per 15 min
  message: 'Too many requests to Boss Center. Try again later.',
  validate: { xForwardedForHeader: false, trustProxy: false },
});
app.get('/boss', bossPageLimiter, (req, res) => {
  // Set security headers — no caching, no iframe embedding
  res.set({
    'Cache-Control': 'no-store, no-cache, must-revalidate, private',
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
  });
  res.sendFile(require('path').join(__dirname, 'public', 'boss.html'));
});

// Legal pages
app.get('/privacy', (req, res) => res.sendFile(require('path').join(__dirname, 'public', 'privacy.html')));
app.get('/terms', (req, res) => res.sendFile(require('path').join(__dirname, 'public', 'terms.html')));
app.get('/child-safety', (req, res) => res.sendFile(require('path').join(__dirname, 'public', 'child-safety.html')));
app.get('/child-safety.html', (req, res) => res.sendFile(require('path').join(__dirname, 'public', 'child-safety.html')));
app.get('/delete-account', (req, res) => res.sendFile(require('path').join(__dirname, 'public', 'delete-account.html')));
app.get('/delete-account.html', (req, res) => res.sendFile(require('path').join(__dirname, 'public', 'delete-account.html')));

// API Documentation page
app.get('/docs', (req, res) => {
  res.sendFile(require('path').join(__dirname, 'public', 'docs.html'));
});

// Health check — v1 endpoint (new standard)
app.get('/api/v1/health', (req, res) => {
  res.json({
    success: true,
    message: 'Nearfo API v1 is running',
    apiVersion: 'v1',
    version: '2.1.0',
    timestamp: new Date().toISOString(),
  });
});

// Health check — legacy endpoint (backward compatibility)
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: 'Nearfo API is running',
    version: '2.1.0',
    timestamp: new Date().toISOString(),
  });
});

// Landing page
app.get('/', (req, res) => {
  res.sendFile(require('path').join(__dirname, 'public', 'index.html'));
});

// ===== SOCKET.IO - REAL-TIME CHAT =====
const onlineUsers = new Map(); // userId -> socketId
const pendingCalls = new Map(); // recipientId -> { offer, callerId, callerName, callerAvatar, isVideo, timeout }

// Socket.IO authentication middleware — verify JWT before allowing connection
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) {
      return next(new Error('Authentication token required'));
    }
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const User = require('./models/User');
    const user = await User.findById(decoded.id).select('_id name isBanned suspendedUntil').lean();
    if (!user) {
      return next(new Error('User not found'));
    }
    if (user.isBanned) {
      return next(new Error('Account banned'));
    }
    if (user.suspendedUntil && new Date(user.suspendedUntil) > new Date()) {
      return next(new Error('Account suspended'));
    }
    // Attach authenticated userId and name to socket for all handlers
    socket.userId = user._id.toString();
    socket.userName = user.name || '';
    next();
  } catch (err) {
    console.error(`[Socket] Auth failed: ${err.message}`);
    next(new Error('Invalid or expired token'));
  }
});

io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id} (userId: ${socket.userId})`);

  // User comes online — use authenticated userId from JWT, ignore client-sent value
  socket.on('user_online', async (_clientUserId) => {
    const userId = socket.userId; // Always trust JWT-authenticated identity
    onlineUsers.set(userId, socket.id);
    // Persist online status to DB
    try {
      const User = require('./models/User');
      await User.findByIdAndUpdate(userId, { isOnline: true, lastSeen: new Date() });
      // Only broadcast online status if user has showOnlineStatus enabled
      const user = await User.findById(userId).select('showOnlineStatus hideOnlineFrom').lean();
      if (!user || user.showOnlineStatus !== false) {
        // Send "online" to everyone EXCEPT users in hideOnlineFrom list
        const hideFromIds = (user?.hideOnlineFrom || []).map(id => id.toString());
        if (hideFromIds.length === 0) {
          io.emit('user_status', { userId, isOnline: true });
        } else {
          // Broadcast to all, then send fake "offline" to hidden users
          io.emit('user_status', { userId, isOnline: true });
          for (const hiddenUserId of hideFromIds) {
            const hiddenSocket = onlineUsers.get(hiddenUserId);
            if (hiddenSocket) {
              io.to(hiddenSocket).emit('user_status', { userId, isOnline: false });
            }
          }
        }
      }
    } catch (e) {
      // Fallback: broadcast anyway if DB check fails
      io.emit('user_status', { userId, isOnline: true });
    }
  });

  // User toggles online visibility (ghost mode)
  socket.on('toggle_online_visibility', async (data) => {
    const userId = socket.userId; // Use authenticated userId
    const { visible } = data || {};
    if (!userId) return;
    try {
      const User = require('./models/User');
      await User.findByIdAndUpdate(userId, { showOnlineStatus: visible });
      if (!visible) {
        // Immediately appear offline to everyone
        io.emit('user_status', { userId, isOnline: false });
      } else if (onlineUsers.has(userId)) {
        // If user is actually online, show them as online again
        io.emit('user_status', { userId, isOnline: true });
      }
    } catch (e) {
      console.error('[Socket] toggle_online_visibility error:', e.message);
    }
  });

  // Join a chat room
  socket.on('join_chat', (chatId) => {
    socket.join(chatId);
    const room = io.sockets.adapter.rooms.get(chatId);
    console.log(`[Socket] User ${socket.userId} joined chat room ${chatId} — now ${room ? room.size : 0} sockets in room`);
  });

  // Leave a chat room
  socket.on('leave_chat', (chatId) => {
    socket.leave(chatId);
    console.log(`[Socket] User ${socket.userId} left chat room ${chatId}`);
  });

  // Send message — skip room broadcast for restricted messages (restriction handled by REST API)
  socket.on('send_message', async (data) => {
    const { chatId, message } = data;
    // Check if sender is restricted in this chat before broadcasting
    try {
      const Chat = require('./models/Chat');
      const chat = await Chat.findById(chatId).select('restrictedUsers').lean();
      const isRestricted = chat && (chat.restrictedUsers || []).some(
        id => id.toString() === socket.userId
      );
      if (isRestricted) {
        // Only emit back to sender (they see their own message), NOT to room
        socket.emit('new_message', message);
      } else {
        socket.to(chatId).emit('new_message', message);
      }
    } catch (e) {
      // Fallback: broadcast normally if DB check fails
      socket.to(chatId).emit('new_message', message);
    }
  });

  // Typing indicator — use authenticated socket.userId, not client-provided
  socket.on('typing', (data) => {
    if (!data.chatId) return;
    socket.to(data.chatId).emit('user_typing', {
      userId: socket.userId,
      userName: socket.userName || data.userName || '',
    });
  });

  // Stop typing — use authenticated socket.userId
  socket.on('stop_typing', (data) => {
    if (!data.chatId) return;
    socket.to(data.chatId).emit('user_stop_typing', { userId: socket.userId });
  });

  // ===== REACTIONS (real-time sync to receiver) =====

  socket.on('add_reaction', (data) => {
    const { chatId, messageId, emoji } = data;
    if (!chatId || !messageId || !emoji) return;
    const room = io.sockets.adapter.rooms.get(chatId);
    console.log(`[Socket] add_reaction from user ${socket.userId} — room ${chatId} has ${room ? room.size : 0} sockets, emoji=${emoji}`);
    // Broadcast to everyone in the chat room except the sender
    socket.to(chatId).emit('message_reaction', {
      chatId,
      messageId,
      emoji,
      userId: socket.userId,
      userName: socket.userName || '',
    });
  });

  socket.on('remove_reaction', (data) => {
    const { chatId, messageId } = data;
    if (!chatId || !messageId) return;
    socket.to(chatId).emit('message_reaction_removed', {
      chatId,
      messageId,
      userId: socket.userId,
    });
  });

  // ===== MESSAGE UNSEND / DELETE (real-time sync to receiver) =====

  socket.on('message_deleted', (data) => {
    const { chatId, messageId } = data;
    if (!chatId || !messageId) return;
    socket.to(chatId).emit('message_deleted', {
      chatId,
      messageId,
      userId: socket.userId,
    });
  });

  // ===== MESSAGE EDIT (real-time sync to receiver) =====

  socket.on('message_edited', (data) => {
    const { chatId, messageId, content } = data;
    if (!chatId || !messageId) return;
    socket.to(chatId).emit('message_edited', {
      chatId,
      messageId,
      content: content || '',
      userId: socket.userId,
    });
  });

  // ===== CALL SIGNALING (WebRTC) =====

  // Initiate a call — relay offer to recipient (use authenticated socket.userId as callerId)
  socket.on('call_initiate', (data) => {
    const { recipientId, offer, callerName, callerAvatar, isVideo } = data;
    const callerId = socket.userId; // Use authenticated ID, not client-provided
    const recipientSocket = onlineUsers.get(recipientId);
    if (recipientSocket) {
      // Recipient is online — relay offer directly via socket
      io.to(recipientSocket).emit('incoming_call', {
        callerId,
        callerName,
        callerAvatar,
        isVideo,
        offer,
      });
    } else {
      // Recipient is offline — store offer and send push notification
      // IMPORTANT: Do NOT send call_unavailable immediately!
      // The push notification may wake the app and the recipient can answer.

      // Clear any previous pending call for this recipient
      const prev = pendingCalls.get(recipientId);
      if (prev && prev.timeout) clearTimeout(prev.timeout);

      // Store the offer so the recipient can fetch it when app wakes
      const callTimeout = setTimeout(() => {
        pendingCalls.delete(recipientId);
        // NOW tell the caller that the recipient didn't answer (60s timeout)
        const callerSock = onlineUsers.get(callerId);
        if (callerSock) {
          io.to(callerSock).emit('call_unavailable', { recipientId });
        }
        console.log(`[Call] Pending call to ${recipientId} expired after 60s`);
      }, 60000); // 60 seconds to answer from push

      pendingCalls.set(recipientId, {
        offer,
        callerId,
        callerName,
        callerAvatar: callerAvatar || '',
        isVideo,
        timeout: callTimeout,
        createdAt: Date.now(),
      });

      // Send push notification (fire-and-forget with error logging)
      try {
        const { push } = require('./utils/pushNotify');
        push.incomingCall(recipientId, callerId, callerName, callerAvatar, isVideo);
        console.log(`[Call] Stored pending call for ${recipientId}, push sent`);
      } catch (pushErr) {
        console.error(`[Call] Push notification failed for ${recipientId}:`, pushErr.message);
      }
    }
  });

  // Answer a call — relay answer back to caller
  socket.on('call_answer', (data) => {
    const { callerId, answer } = data;
    // Clean up pending call if it was a push-based call — use authenticated userId
    const userId = socket.userId;
    if (userId) {
      const pending = pendingCalls.get(userId);
      if (pending && pending.timeout) clearTimeout(pending.timeout);
      pendingCalls.delete(userId);
    }

    const callerSocket = onlineUsers.get(callerId);
    if (callerSocket) {
      io.to(callerSocket).emit('call_answered', { answer });
    }
  });

  // Reject a call
  socket.on('call_reject', (data) => {
    const { callerId } = data;
    // Clean up pending call — use authenticated userId
    const userId = socket.userId;
    if (userId) {
      const pending = pendingCalls.get(userId);
      if (pending && pending.timeout) clearTimeout(pending.timeout);
      pendingCalls.delete(userId);
    }

    const callerSocket = onlineUsers.get(callerId);
    if (callerSocket) {
      io.to(callerSocket).emit('call_rejected', { callerId });
    }
  });

  // End a call
  socket.on('call_end', (data) => {
    const { recipientId } = data;
    // Clean up any pending call
    const pending = pendingCalls.get(recipientId);
    if (pending && pending.timeout) clearTimeout(pending.timeout);
    pendingCalls.delete(recipientId);

    const recipientSocket = onlineUsers.get(recipientId);
    if (recipientSocket) {
      io.to(recipientSocket).emit('call_ended', {});
    }
  });

  // ICE candidate exchange for WebRTC NAT traversal
  socket.on('ice_candidate', (data) => {
    const { recipientId, candidate } = data;
    if (!recipientId || !candidate || typeof candidate !== 'object') return;
    const recipientSocket = onlineUsers.get(recipientId);
    if (recipientSocket) {
      io.to(recipientSocket).emit('ice_candidate', { candidate });
    }
  });

  // ===== BOSS COMMAND CENTER =====

  // Boss joins their command room for live updates
  socket.on('boss_connect', (userId) => {
    socket.join(`boss_${userId}`);
    console.log(`Boss ${userId} connected to command center`);
  });

  // ===== LIVE STREAMING =====

  // Join a live stream room
  socket.on('live_join', (streamId) => {
    socket.join(`live_${streamId}`);
  });

  // Leave a live stream room
  socket.on('live_leave', (streamId) => {
    socket.leave(`live_${streamId}`);
  });

  // WebRTC signaling for live — host sends offer to room
  socket.on('live_offer', (data) => {
    socket.to(`live_${data.streamId}`).emit('live_offer', { offer: data.offer });
  });

  // Viewer sends answer back to host
  socket.on('live_answer', (data) => {
    const hostSocket = onlineUsers.get(data.hostId);
    if (hostSocket) {
      io.to(hostSocket).emit('live_answer', { answer: data.answer, viewerId: data.viewerId });
    }
  });

  // ICE candidate for live streams
  socket.on('live_ice', (data) => {
    if (data.targetId) {
      const targetSocket = onlineUsers.get(data.targetId);
      if (targetSocket) {
        io.to(targetSocket).emit('live_ice', { candidate: data.candidate, senderId: data.senderId });
      }
    } else {
      socket.to(`live_${data.streamId}`).emit('live_ice', { candidate: data.candidate });
    }
  });

  // ===== READ RECEIPTS =====

  // Mark messages as read, persist to DB, and notify sender
  socket.on('messages_read', async (data) => {
    const { chatId } = data;
    const userId = socket.userId; // Use authenticated userId
    socket.to(chatId).emit('messages_read', { chatId, userId });
    // Persist read status to DB (readBy is ObjectId array, not objects)
    try {
      const { Message } = require('./models/Chat');
      await Message.updateMany(
        { chat: chatId, sender: { $ne: userId }, readBy: { $ne: userId } },
        { $addToSet: { readBy: userId } }
      );
    } catch (e) {
      console.error('[Socket] messages_read DB error:', e.message);
    }
  });

  // Message delivered confirmation
  socket.on('messages_delivered', (data) => {
    const { chatId } = data;
    const userId = socket.userId; // Use authenticated userId
    socket.to(chatId).emit('messages_delivered', { chatId, userId });
  });

  // Disconnect
  socket.on('disconnect', async () => {
    const userId = socket.userId;
    // Only remove if this socket is still the active one for this user (prevents race with reconnect)
    if (userId && onlineUsers.get(userId) === socket.id) {
      onlineUsers.delete(userId);

      // Clean up any pending calls initiated by this user
      for (const [recipientId, call] of pendingCalls.entries()) {
        if (call.callerId === userId) {
          if (call.timeout) clearTimeout(call.timeout);
          pendingCalls.delete(recipientId);
          console.log(`[Cleanup] Removed pending call from disconnected user ${userId} to ${recipientId}`);
        }
      }

      // Persist offline status + last seen
      try {
        const User = require('./models/User');
        await User.findByIdAndUpdate(userId, { isOnline: false, lastSeen: new Date() });
        // Only broadcast offline if user has showOnlineStatus enabled (otherwise they're already appearing offline)
        const user = await User.findById(userId).select('showOnlineStatus').lean();
        if (!user || user.showOnlineStatus !== false) {
          io.emit('user_status', { userId, isOnline: false });
        }
      } catch (e) {
        io.emit('user_status', { userId, isOnline: false });
      }
    }
    console.log(`User disconnected: ${socket.id} (userId: ${userId || 'unknown'})`);
  });
});

// Periodic cleanup — remove stale entries from onlineUsers and pendingCalls
setInterval(() => {
  // Clean pendingCalls older than 5 minutes (timeout should have fired at 60s, this is a safety net)
  const now = Date.now();
  for (const [recipientId, call] of pendingCalls.entries()) {
    if (now - (call.createdAt || 0) > 5 * 60 * 1000) {
      if (call.timeout) clearTimeout(call.timeout);
      pendingCalls.delete(recipientId);
      console.log(`[Cleanup] Removed stale pending call for ${recipientId}`);
    }
  }
  // Clean onlineUsers where socket is no longer connected
  for (const [userId, socketId] of onlineUsers.entries()) {
    const sock = io.sockets.sockets.get(socketId);
    if (!sock || !sock.connected) {
      onlineUsers.delete(userId);
      console.log(`[Cleanup] Removed stale online entry for ${userId}`);
    }
  }
}, 5 * 60 * 1000); // Every 5 minutes

// Make io and Redis caching accessible to routes
app.set('io', io);
app.set('onlineUsers', onlineUsers);
app.set('pendingCalls', pendingCalls);
app.set('redis', { setCache, getCache, deleteCache, deleteCachePattern, checkRateLimit: redisRateLimit });

// ===== ERROR HANDLING =====
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

// ===== START SERVER =====
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`
  ========================================
       NEARFO API SERVER
       Know Your Circle

       Port: ${PORT}
       Env: ${process.env.NODE_ENV || 'development'}
  ========================================
  `);
});

module.exports = { app, io };
