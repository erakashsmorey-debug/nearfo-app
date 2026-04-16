const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { Chat, Message } = require('../models/Chat');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const { decryptUserData } = require('../utils/encryption');
const { push } = require('../utils/pushNotify');
const validate = require('../middleware/validate');
const schemas = require('../validators');
const { chatLimiter, engagementLimiter } = require('../middleware/rateLimits');

// Helper: validate MongoDB ObjectId
const isValidId = (id) => mongoose.Types.ObjectId.isValid(id);

// Helper: ensure populated participants have decrypted fields
function decryptParticipants(chatObj) {
  if (chatObj.participants && Array.isArray(chatObj.participants)) {
    chatObj.participants = chatObj.participants.map(p => {
      if (p && typeof p === 'object' && p._id) {
        return decryptUserData({ ...p });
      }
      return p;
    });
  }
  return chatObj;
}

// POST /api/chat
// Create or get existing 1-on-1 chat
router.post('/', protect, async (req, res) => {
  try {
    const { participantId } = req.body;

    if (!participantId) {
      return res.status(400).json({ success: false, message: 'Participant ID required' });
    }

    if (participantId === req.user._id.toString()) {
      return res.status(400).json({ success: false, message: 'Cannot chat with yourself' });
    }

    // Check if participant exists
    const participant = await User.findById(participantId);
    if (!participant) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Check if chat already exists between these two users
    let chat = await Chat.findOne({
      isGroup: false,
      participants: { $all: [req.user._id, participantId], $size: 2 },
    }).populate('participants', 'name handle avatarUrl isVerified isOnline lastSeen');

    if (!chat) {
      // Create new chat
      chat = await Chat.create({
        participants: [req.user._id, participantId],
        isGroup: false,
      });
      chat = await chat.populate('participants', 'name handle avatarUrl isVerified isOnline lastSeen');
    }

    res.json({ success: true, chat: decryptParticipants(chat.toObject()) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/chat
// Get all chats for current user
router.get('/', protect, async (req, res) => {
  try {
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const skip = (page - 1) * limit;

    const chats = await Chat.find({
      participants: req.user._id,
    })
      .populate('participants', 'name handle avatarUrl isVerified isOnline lastSeen')
      .sort({ lastMessageAt: -1 })
      .skip(skip)
      .limit(limit);

    // Get unread count for each chat + decrypt participant names
    // Restricted messages are excluded from unread count (FB Messenger style)
    const chatsWithUnread = await Promise.all(
      chats.map(async (chat) => {
        const restrictedIds = (chat.restrictedUsers || []).map(id => id.toString());

        // Unread: exclude own messages AND messages from restricted users
        const unreadQuery = {
          chat: chat._id,
          readBy: { $ne: req.user._id },
        };
        const excludeFromUnread = [req.user._id];
        restrictedIds.forEach(id => excludeFromUnread.push(id));
        unreadQuery.sender = { $nin: excludeFromUnread };
        const unreadCount = await Message.countDocuments(unreadQuery);

        // Restricted count: messages from restricted users (regardless of isRestricted flag)
        let restrictedCount = 0;
        if (restrictedIds.length > 0) {
          restrictedCount = await Message.countDocuments({
            chat: chat._id,
            sender: { $in: restrictedIds, $ne: req.user._id },
          });
        }

        const chatObj = decryptParticipants(chat.toObject());
        return { ...chatObj, unreadCount, restrictedMessageCount: restrictedCount };
      })
    );

    res.json({ success: true, chats: chatsWithUnread });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/chat/search - Search messages across all chats
// NOTE: MUST be before /:chatId routes
router.get('/search', protect, async (req, res) => {
  try {
    const { q, chatId } = req.query;
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    if (!q || q.length < 2) {
      return res.status(400).json({ success: false, message: 'Search query must be at least 2 characters' });
    }

    const skip = (page - 1) * limit;
    const myChats = await Chat.find({ participants: req.user._id }).select('_id');
    const chatIds = chatId ? [chatId] : myChats.map(c => c._id);

    // Escape regex special chars in user query to prevent ReDoS
    const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const messages = await Message.find({
      chat: { $in: chatIds },
      isDeleted: false,
      content: { $regex: escaped, $options: 'i' },
    })
      .populate('sender', 'name handle avatarUrl')
      .populate('chat', 'participants isGroup groupName')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const matched = messages;

    res.json({
      success: true,
      messages: matched.map(m => {
        const obj = m.toObject();
        return {
          _id: obj._id,
          chat: obj.chat,
          sender: obj.sender,
          content: obj.content,
          type: obj.type,
          createdAt: obj.createdAt,
        };
      }),
      query: q,
      page,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/hide-online — Toggle hiding online status from a specific user
// NOTE: MUST be before /:chatId routes to avoid Express param conflict
router.post('/hide-online', protect, async (req, res) => {
  try {
    const { targetUserId, hide } = req.body;
    if (!targetUserId) {
      return res.status(400).json({ success: false, message: 'targetUserId is required' });
    }

    const User = require('../models/User');
    const me = await User.findById(req.user._id);
    if (!me) return res.status(404).json({ success: false, message: 'User not found' });

    if (!me.hideOnlineFrom) me.hideOnlineFrom = [];
    const myId = req.user._id.toString();
    const alreadyHidden = me.hideOnlineFrom.some(id => id.toString() === targetUserId);

    if (hide && !alreadyHidden) {
      me.hideOnlineFrom.push(targetUserId);
    } else if (!hide && alreadyHidden) {
      me.hideOnlineFrom = me.hideOnlineFrom.filter(id => id.toString() !== targetUserId);
    }

    await me.save();

    // If hiding, also emit offline status to that specific user via socket
    if (hide) {
      const io = req.app.get('io');
      const onlineUsers = req.app.get('onlineUsers');
      if (io && onlineUsers) {
        const targetSocket = onlineUsers.get(targetUserId);
        if (targetSocket) {
          io.to(targetSocket).emit('user_status', { userId: myId, isOnline: false });
        }
      }
    }

    res.json({ success: true, hidden: !!hide });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/chat/hide-online/:targetUserId — Check if hiding online from a user
// NOTE: MUST be before /:chatId routes
router.get('/hide-online/:targetUserId', protect, async (req, res) => {
  try {
    const User = require('../models/User');
    const me = await User.findById(req.user._id).select('hideOnlineFrom').lean();
    const isHidden = (me?.hideOnlineFrom || []).some(id => id.toString() === req.params.targetUserId);
    res.json({ success: true, hidden: isHidden });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/chat/:chatId/messages
// Get messages for a specific chat
router.get('/:chatId/messages', protect, async (req, res) => {
  try {
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 200);
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const skip = (page - 1) * limit;

    // Verify user is part of this chat
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });

    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    // Check which users the current user has restricted
    const restrictedUserIds = (chat.restrictedUsers || []).map(id => id.toString());
    const myId = req.user._id.toString();

    const messages = await Message.find({ chat: req.params.chatId })
      .populate('sender', 'name handle avatarUrl')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    // Server-side: ensure ALL messages from restricted users are marked isRestricted
    // This catches old messages that were created before the restriction was applied
    const processedMessages = messages.map(msg => {
      const msgObj = msg.toObject();
      const senderId = msgObj.sender?._id?.toString() || msgObj.sender?.toString() || '';
      if (senderId !== myId && restrictedUserIds.includes(senderId) && !msgObj.isRestricted) {
        msgObj.isRestricted = true; // Mark as restricted on-the-fly
      }
      return msgObj;
    });

    // Mark messages as read — but NOT messages from restricted users
    const readQuery = {
      chat: req.params.chatId,
      readBy: { $ne: req.user._id },
    };
    // Exclude own messages AND restricted users' messages from read marking
    const excludeSenders = [req.user._id];
    if (restrictedUserIds.length > 0) {
      restrictedUserIds.forEach(id => excludeSenders.push(id));
    }
    readQuery.sender = { $nin: excludeSenders };
    await Message.updateMany(readQuery, { $addToSet: { readBy: req.user._id } });

    const totalMessages = await Message.countDocuments({ chat: req.params.chatId });

    res.json({
      success: true,
      messages: processedMessages.reverse(), // oldest first for display
      page,
      totalMessages,
      hasMore: skip + messages.length < totalMessages,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/:chatId/messages
// Send a message in a chat
router.post('/:chatId/messages', protect, chatLimiter, validate(schemas.chatIdParam, 'params'), validate(schemas.sendMessage), async (req, res) => {
  try {
    const { content, type = 'text', mediaUrl, replyTo } = req.body;

    if (!content && !mediaUrl) {
      console.log(`[SendMsg] 400 — body keys: ${Object.keys(req.body)}, content="${content}", type="${type}", mediaUrl="${mediaUrl}", raw body: ${JSON.stringify(req.body).substring(0, 300)}`);
      return res.status(400).json({ success: false, message: 'Content or media required' });
    }

    // Verify user is part of this chat
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });

    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    // Check if sender is restricted in this chat (FB Messenger-style restriction)
    const senderIsRestricted = (chat.restrictedUsers || []).some(
      id => id.toString() === req.user._id.toString()
    );

    console.log(`[SendMsg] Step1: chatId=${req.params.chatId}, type=${type}, restricted=${senderIsRestricted}, content="${(content||'').substring(0,30)}", mediaUrl="${(mediaUrl||'').substring(0,80)}"`);

    const messageData = {
      chat: req.params.chatId,
      sender: req.user._id,
      content: content || '',
      type,
      mediaUrl: mediaUrl || '',
      readBy: [req.user._id], // Sender has read it
      isRestricted: senderIsRestricted, // Mark if sender is restricted
    };

    // Attach reply reference if replying to a message (validate it exists in same chat)
    if (replyTo && replyTo.messageId) {
      const replyMsg = await Message.findOne({ _id: replyTo.messageId, chat: req.params.chatId }).select('_id').lean();
      if (replyMsg) {
        messageData.replyTo = {
          messageId: replyTo.messageId,
          content: replyTo.content || '',
          senderName: replyTo.senderName || '',
          senderId: replyTo.senderId || null,
        };
      }
    }

    console.log(`[SendMsg] Step2: Creating message...`);
    const message = await Message.create(messageData);
    console.log(`[SendMsg] Step3: Message created: ${message._id}`);

    // Update chat's last message — but NOT for restricted messages (restrictor shouldn't see it in chat list)
    if (!senderIsRestricted) {
      chat.lastMessage = content || `Sent ${type}`;
      chat.lastMessageAt = new Date();
    }
    // Fix: groupAdmin may be [] in DB (invalid for ObjectId field) — sanitize before save
    if (Array.isArray(chat.groupAdmin) || chat.groupAdmin === '') {
      chat.groupAdmin = null;
    }
    await chat.save();
    console.log(`[SendMsg] Step4: Chat updated`);

    const populated = await message.populate('sender', 'name handle avatarUrl');
    console.log(`[SendMsg] Step5: Populated, sending response`);

    // Real-time: emit to chat room via Socket.io
    const io = req.app.get('io');
    if (senderIsRestricted) {
      // Restricted message — only emit to sender (so their UI updates), NOT to restrictor
      const onlineUsers = req.app.get('onlineUsers');
      const senderSocketId = onlineUsers?.get(req.user._id.toString());
      if (io && senderSocketId) {
        io.to(senderSocketId).emit('new_message', populated);
      }
      // NO push notifications, NO chat_update for restrictor — they don't know about this message
    } else {
      // Normal message — broadcast to all in room
      if (io) io.to(req.params.chatId).emit('new_message', populated);

      // Notify other participants — socket for online, push for offline
      const onlineUsers = req.app.get('onlineUsers');
      if (io && onlineUsers) chat.participants.forEach((participantId) => {
        if (participantId.toString() !== req.user._id.toString()) {
          const socketId = onlineUsers.get(participantId.toString());
          if (socketId) {
            // Online — send socket event
            io.to(socketId).emit('chat_update', {
              chatId: chat._id,
              lastMessage: chat.lastMessage,
              lastMessageAt: chat.lastMessageAt,
              senderName: req.user.name,
            });
          } else {
            // Offline — send push notification
            const preview = type === 'text' ? (content || '') : `Sent ${type}`;
            push.chatMessage(participantId.toString(), req.user._id.toString(), req.user.name, preview);
          }
        }
      });
    }

    res.status(201).json({ success: true, message: populated });
  } catch (error) {
    console.error(`[SendMsg] 500 — ${error.name}: ${error.message}`);
    console.error(`[SendMsg] Stack: ${error.stack}`);
    console.error(`[SendMsg] Body: ${JSON.stringify(req.body).substring(0, 500)}`);
    res.status(500).json({ success: false, message: error.message, errorName: error.name });
  }
});

// POST /api/chat/group
// Create a group chat
router.post('/group', protect, async (req, res) => {
  try {
    const { participantIds, groupName, groupDescription } = req.body;

    if (!participantIds || participantIds.length < 2) {
      return res.status(400).json({ success: false, message: 'At least 2 participants required' });
    }

    if (!groupName) {
      return res.status(400).json({ success: false, message: 'Group name required' });
    }

    // Add current user to participants
    const allParticipants = [...new Set([req.user._id.toString(), ...participantIds])];

    const chat = await Chat.create({
      participants: allParticipants,
      isGroup: true,
      groupName,
      groupDescription: groupDescription || '',
      groupAdmin: req.user._id,
    });

    const populated = await chat.populate(
      'participants',
      'name handle avatarUrl isVerified isOnline'
    );

    res.status(201).json({ success: true, chat: decryptParticipants(populated.toObject()) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/chat/:chatId/settings
// Get chat settings (theme, nicknames, mute, disappearing, etc.)
router.get('/:chatId/settings', protect, async (req, res) => {
  try {
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    const myId = req.user._id.toString();
    const otherId = chat.participants.find(p => p.toString() !== myId)?.toString();

    // Check if current user hides online from the other participant
    const User = require('../models/User');
    const me = await User.findById(req.user._id).select('hideOnlineFrom showOnlineStatus').lean();
    const isOnlineHiddenFromRecipient = otherId ? (me?.hideOnlineFrom || []).some(id => id.toString() === otherId) : false;

    res.json({
      success: true,
      settings: {
        theme: chat.theme || 'Default',
        disappearingMode: chat.disappearingMode || 'Off',
        isMuted: (chat.mutedBy || []).some(id => id.toString() === myId),
        readReceipts: !(chat.readReceiptsDisabled || []).some(id => id.toString() === myId), // true = enabled
        isBlocked: (chat.blockedBy || []).some(id => id.toString() === myId),
        isRestricted: otherId ? (chat.restrictedUsers || []).some(id => id.toString() === otherId) : false,
        showOnlineStatus: me?.showOnlineStatus !== false,
        hideOnlineFromRecipient: isOnlineHiddenFromRecipient,
        myNickname: chat.nicknames?.get(myId) || null,
        theirNickname: otherId ? (chat.nicknames?.get(otherId) || null) : null,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/chat/:chatId/settings
// Update chat settings
router.put('/:chatId/settings', protect, async (req, res) => {
  try {
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    const myId = req.user._id.toString();
    const otherId = chat.participants.find(p => p.toString() !== myId)?.toString();
    const { theme, disappearingMode, isMuted, readReceipts, myNickname, theirNickname } = req.body;

    if (theme !== undefined) chat.theme = theme;
    if (disappearingMode !== undefined) chat.disappearingMode = disappearingMode;

    if (isMuted !== undefined) {
      if (!chat.mutedBy) chat.mutedBy = [];
      if (isMuted && !chat.mutedBy.some(id => id.toString() === myId)) {
        chat.mutedBy.push(req.user._id);
      } else if (!isMuted) {
        chat.mutedBy = chat.mutedBy.filter(id => id.toString() !== myId);
      }
    }

    // Read receipts: true = enabled (remove from disabled list), false = disabled (add to list)
    if (readReceipts !== undefined) {
      if (!chat.readReceiptsDisabled) chat.readReceiptsDisabled = [];
      if (!readReceipts && !chat.readReceiptsDisabled.some(id => id.toString() === myId)) {
        chat.readReceiptsDisabled.push(req.user._id);
      } else if (readReceipts) {
        chat.readReceiptsDisabled = chat.readReceiptsDisabled.filter(id => id.toString() !== myId);
      }
    }

    if (myNickname !== undefined) {
      if (!chat.nicknames) chat.nicknames = new Map();
      if (myNickname) chat.nicknames.set(myId, myNickname);
      else chat.nicknames.delete(myId);
    }
    if (theirNickname !== undefined && otherId) {
      if (!chat.nicknames) chat.nicknames = new Map();
      if (theirNickname) chat.nicknames.set(otherId, theirNickname);
      else chat.nicknames.delete(otherId);
    }

    await chat.save();
    res.json({ success: true, message: 'Settings updated' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/chat/:chatId/restriction-status
// Get list of restricted user IDs in this chat
router.get('/:chatId/restriction-status', protect, async (req, res) => {
  try {
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }
    const restrictedUserIds = (chat.restrictedUsers || []).map(id => id.toString());
    res.json({ success: true, restrictedUserIds });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/:chatId/accept-restricted
// Accept restricted messages — marks all restricted messages as normal (like accepting a message request)
router.post('/:chatId/accept-restricted', protect, async (req, res) => {
  try {
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    // Mark all restricted messages in this chat as normal
    const result = await Message.updateMany(
      { chat: req.params.chatId, isRestricted: true },
      { $set: { isRestricted: false } }
    );

    res.json({ success: true, accepted: result.modifiedCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/:chatId/delete-restricted
// Delete all restricted messages (decline message request)
router.post('/:chatId/delete-restricted', protect, async (req, res) => {
  try {
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    // Delete all restricted messages
    const result = await Message.deleteMany(
      { chat: req.params.chatId, isRestricted: true }
    );

    res.json({ success: true, deleted: result.deletedCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/chat/:chatId/media
// Get shared media (images/videos) from a chat
router.get('/:chatId/media', protect, async (req, res) => {
  try {
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    const media = await Message.find({
      chat: req.params.chatId,
      type: { $in: ['image', 'voice', 'video'] },
      isDeleted: { $ne: true },
    })
      .select('mediaUrl type createdAt sender')
      .populate('sender', 'name handle')
      .sort({ createdAt: -1 })
      .limit(100);

    res.json({ success: true, media });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/chat/:chatId/messages/:messageId/edit
// Edit a text message (only by sender, within 15 minutes)
router.put('/:chatId/messages/:messageId/edit', protect, async (req, res) => {
  try {
    const { content } = req.body;
    if (!content || !content.trim()) {
      return res.status(400).json({ success: false, message: 'Message content required' });
    }
    if (!isValidId(req.params.chatId) || !isValidId(req.params.messageId)) {
      return res.status(400).json({ success: false, message: 'Invalid ID format' });
    }

    const message = await Message.findOne({
      _id: req.params.messageId,
      chat: req.params.chatId,
      sender: req.user._id,
    });
    if (!message) {
      return res.status(404).json({ success: false, message: 'Message not found or not your message' });
    }

    // Only allow editing text messages
    if (message.type !== 'text') {
      return res.status(400).json({ success: false, message: 'Only text messages can be edited' });
    }

    // 15-minute edit window
    const fifteenMin = 15 * 60 * 1000;
    if (Date.now() - message.createdAt.getTime() > fifteenMin) {
      return res.status(400).json({ success: false, message: 'Edit window expired (15 minutes)' });
    }

    message.content = content.trim();
    message.isEdited = true;
    message.editedAt = new Date();
    await message.save();

    // Update Chat.lastMessage if this was the latest message
    try {
      const chat = await Chat.findById(req.params.chatId);
      if (chat) {
        const latestMsg = await Message.findOne({ chat: req.params.chatId }).sort({ createdAt: -1 });
        if (latestMsg && latestMsg._id.toString() === req.params.messageId) {
          chat.lastMessage = content.trim();
          await chat.save();
        }
      }
    } catch (e) {
      console.error('[Chat] lastMessage update error:', e.message);
    }

    // Notify via socket
    const io = req.app.get('io');
    if (io) io.to(req.params.chatId).emit('message_edited', {
      chatId: req.params.chatId,
      messageId: req.params.messageId,
      content: content.trim(),
      isEdited: true,
      editedAt: message.editedAt,
    });

    res.json({ success: true, message: 'Message edited', data: { messageId: req.params.messageId, content: content.trim(), isEdited: true, editedAt: message.editedAt } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/chat/:chatId/messages/:messageId/unsend
// Unsend a message (only by sender, deletes for everyone)
router.delete('/:chatId/messages/:messageId/unsend', protect, async (req, res) => {
  try {
    const message = await Message.findOne({
      _id: req.params.messageId,
      chat: req.params.chatId,
      sender: req.user._id,
    });
    if (!message) {
      return res.status(404).json({ success: false, message: 'Message not found or not your message' });
    }

    await message.deleteOne();

    // Notify via socket
    const io = req.app.get('io');
    io.to(req.params.chatId).emit('message_unsent', {
      chatId: req.params.chatId,
      messageId: req.params.messageId,
    });

    res.json({ success: true, message: 'Message unsent' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/chat/:chatId/messages/:messageId
// Delete a message for me (soft delete by marking isDeleted)
router.delete('/:chatId/messages/:messageId', protect, async (req, res) => {
  try {
    const message = await Message.findOne({
      _id: req.params.messageId,
      chat: req.params.chatId,
    });
    if (!message) {
      return res.status(404).json({ success: false, message: 'Message not found' });
    }

    // Verify user is part of the chat
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    message.isDeleted = true;
    await message.save();

    res.json({ success: true, message: 'Message deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/:chatId/restrict
// Toggle restrict a user in chat
router.post('/:chatId/restrict', protect, async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId || !isValidId(userId)) {
      return res.status(400).json({ success: false, message: 'Valid userId required' });
    }
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });
    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }
    // Verify target user is a participant in this chat
    if (!chat.participants.some(p => p.toString() === userId)) {
      return res.status(400).json({ success: false, message: 'User not in this chat' });
    }

    if (!chat.restrictedUsers) chat.restrictedUsers = [];
    const isRestricted = chat.restrictedUsers.some(id => id.toString() === userId);

    if (isRestricted) {
      chat.restrictedUsers = chat.restrictedUsers.filter(id => id.toString() !== userId);
    } else {
      chat.restrictedUsers.push(userId);
    }
    await chat.save();

    res.json({ success: true, isRestricted: !isRestricted });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/users/:userId/block
// Toggle block a user
router.post('/block/:userId', protect, async (req, res) => {
  try {
    const targetId = req.params.userId;
    const myId = req.user._id.toString();

    // Validate target user exists
    const User = require('../models/User');
    const targetUser = await User.findById(targetId).select('_id').lean();
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Find all chats between these users and toggle block
    const chats = await Chat.find({
      participants: { $all: [req.user._id, targetId] },
      isGroup: false,
    });

    let isBlocked = false;
    for (const chat of chats) {
      if (!chat.blockedBy) chat.blockedBy = [];
      const alreadyBlocked = chat.blockedBy.some(id => id.toString() === myId);
      if (alreadyBlocked) {
        chat.blockedBy = chat.blockedBy.filter(id => id.toString() !== myId);
      } else {
        chat.blockedBy.push(req.user._id);
        isBlocked = true;
      }
      await chat.save();
    }

    res.json({ success: true, isBlocked });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/chat/:chatId
// Delete a chat (only for current user - soft delete)
router.delete('/:chatId', protect, async (req, res) => {
  try {
    const chat = await Chat.findOne({
      _id: req.params.chatId,
      participants: req.user._id,
    });

    if (!chat) {
      return res.status(404).json({ success: false, message: 'Chat not found' });
    }

    // Remove user from participants (soft delete)
    chat.participants.pull(req.user._id);

    // If no participants left, delete the chat and its messages
    if (chat.participants.length === 0) {
      await Message.deleteMany({ chat: chat._id });
      await chat.deleteOne();
    } else {
      await chat.save();
    }

    res.json({ success: true, message: 'Chat deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/:chatId/messages/:messageId/react — Add reaction to message
router.post('/:chatId/messages/:messageId/react', protect, engagementLimiter, async (req, res) => {
  try {
    const { emoji } = req.body;
    if (!emoji || typeof emoji !== 'string' || emoji.length > 10) {
      return res.status(400).json({ success: false, message: 'Valid emoji required' });
    }
    if (!isValidId(req.params.chatId) || !isValidId(req.params.messageId)) {
      return res.status(400).json({ success: false, message: 'Invalid ID format' });
    }

    const chat = await Chat.findById(req.params.chatId);
    if (!chat) return res.status(404).json({ success: false, message: 'Chat not found' });

    const message = await Message.findOne({
      _id: req.params.messageId,
      chat: req.params.chatId,
    });
    if (!message) return res.status(404).json({ success: false, message: 'Message not found' });

    // Initialize reactions array if not present
    if (!message.reactions) message.reactions = [];

    // Remove existing reaction by this user
    message.reactions = message.reactions.filter(
      r => r.userId.toString() !== req.user._id.toString()
    );

    // Add new reaction
    message.reactions.push({
      userId: req.user._id,
      emoji: emoji,
      createdAt: new Date(),
    });

    await message.save();

    // Broadcast reaction to chat room in real-time
    const io = req.app.get('io');
    if (io) {
      const room = io.sockets.adapter.rooms.get(req.params.chatId);
      const socketsInRoom = room ? room.size : 0;
      console.log(`[React] Broadcasting message_reaction to room ${req.params.chatId} — ${socketsInRoom} sockets in room, emoji=${emoji}, userId=${req.user._id.toString()}`);
      io.to(req.params.chatId).emit('message_reaction', {
        chatId: req.params.chatId,
        messageId: req.params.messageId,
        emoji,
        userId: req.user._id.toString(),
        userName: req.user.name || '',
      });
    } else {
      console.log('[React] ERROR: io is null — cannot broadcast reaction');
    }

    res.json({ success: true, reactions: message.reactions });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to add reaction', error: err.message });
  }
});

// DELETE /api/chat/:chatId/messages/:messageId/react — Remove reaction
router.delete('/:chatId/messages/:messageId/react', protect, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId);
    if (!chat) return res.status(404).json({ success: false, message: 'Chat not found' });

    const message = await Message.findOne({
      _id: req.params.messageId,
      chat: req.params.chatId,
    });
    if (!message) return res.status(404).json({ success: false, message: 'Message not found' });

    if (message.reactions) {
      message.reactions = message.reactions.filter(
        r => r.userId.toString() !== req.user._id.toString()
      );
    }

    await message.save();

    // Broadcast reaction removal to chat room in real-time
    const io = req.app.get('io');
    if (io) {
      io.to(req.params.chatId).emit('message_reaction_removed', {
        chatId: req.params.chatId,
        messageId: req.params.messageId,
        userId: req.user._id.toString(),
      });
    }

    res.json({ success: true, reactions: message.reactions || [] });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to remove reaction', error: err.message });
  }
});

// GET /api/chat/group/:chatId — Get group info
router.get('/group/:chatId', protect, async (req, res) => {
  try {
    if (!isValidId(req.params.chatId)) {
      return res.status(400).json({ success: false, message: 'Invalid chat ID' });
    }
    const chat = await Chat.findById(req.params.chatId)
      .populate('participants', 'name handle avatarUrl isVerified isOnline lastSeen')
      .populate('groupAdmin', 'name handle avatarUrl');

    if (!chat || !chat.isGroup) {
      return res.status(404).json({ success: false, message: 'Group not found' });
    }

    const chatObj = decryptParticipants(chat.toObject());
    res.json({ success: true, group: chatObj });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to get group info', error: err.message });
  }
});

// PUT /api/chat/group/:chatId — Update group info (name, description, avatar)
router.put('/group/:chatId', protect, async (req, res) => {
  try {
    if (!isValidId(req.params.chatId)) {
      return res.status(400).json({ success: false, message: 'Invalid chat ID' });
    }
    const chat = await Chat.findById(req.params.chatId);
    if (!chat || !chat.isGroup) {
      return res.status(404).json({ success: false, message: 'Group not found' });
    }

    // Only admin can update group info
    if (chat.groupAdmin?.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Only admin can update group info' });
    }

    const { groupName, groupDescription, groupAvatar } = req.body;
    if (groupName !== undefined) chat.groupName = groupName;
    if (groupDescription !== undefined) chat.groupDescription = groupDescription;
    if (groupAvatar !== undefined) chat.groupAvatar = groupAvatar;

    // Sanitize groupAdmin before save
    if (Array.isArray(chat.groupAdmin) || chat.groupAdmin === '') {
      chat.groupAdmin = null;
    }

    await chat.save();

    const updated = await Chat.findById(chat._id)
      .populate('participants', 'name handle avatarUrl isVerified isOnline lastSeen')
      .populate('groupAdmin', 'name handle avatarUrl');

    res.json({ success: true, chat: decryptParticipants(updated.toObject()) });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to update group', error: err.message });
  }
});

// PUT/POST /api/chat/group/:chatId/add — Add member(s) to group
const addGroupMemberHandler = async (req, res) => {
  try {
    if (!isValidId(req.params.chatId)) {
      return res.status(400).json({ success: false, message: 'Invalid chat ID' });
    }
    const { userId, userIds } = req.body;
    const chat = await Chat.findById(req.params.chatId);

    if (!chat || !chat.isGroup) {
      return res.status(404).json({ success: false, message: 'Group not found' });
    }

    if (chat.groupAdmin?.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Only admin can add members' });
    }

    // Support both single userId and array of userIds — validate each
    const idsToAdd = userIds ? userIds : (userId ? [userId] : []);
    for (const id of idsToAdd) {
      if (!isValidId(id)) {
        return res.status(400).json({ success: false, message: `Invalid user ID: ${id}` });
      }
    }

    // Enforce group size limit
    const MAX_GROUP_SIZE = 500;
    if (chat.participants.length + idsToAdd.length > MAX_GROUP_SIZE) {
      return res.status(400).json({ success: false, message: `Group cannot exceed ${MAX_GROUP_SIZE} members` });
    }

    let added = 0;
    for (const id of idsToAdd) {
      if (!chat.participants.some(p => p.toString() === id)) {
        chat.participants.push(id);
        added++;
      }
    }

    if (added > 0) {
      // Sanitize groupAdmin before save
      if (Array.isArray(chat.groupAdmin) || chat.groupAdmin === '') {
        chat.groupAdmin = null;
      }
      await chat.save();
    }

    const updated = await Chat.findById(chat._id)
      .populate('participants', 'name handle avatarUrl isVerified isOnline lastSeen');

    res.json({ success: true, group: decryptParticipants(updated.toObject()) });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to add member', error: err.message });
  }
};
router.put('/group/:chatId/add', protect, addGroupMemberHandler);
router.post('/group/:chatId/add', protect, addGroupMemberHandler);

// PUT/POST /api/chat/group/:chatId/remove — Remove member from group
const removeGroupMemberHandler = async (req, res) => {
  try {
    if (!isValidId(req.params.chatId)) {
      return res.status(400).json({ success: false, message: 'Invalid chat ID' });
    }
    const { userId } = req.body;
    if (!userId || !isValidId(userId)) {
      return res.status(400).json({ success: false, message: 'Valid userId required' });
    }
    const chat = await Chat.findById(req.params.chatId);

    if (!chat || !chat.isGroup) {
      return res.status(404).json({ success: false, message: 'Group not found' });
    }

    if (chat.groupAdmin?.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Only admin can remove members' });
    }

    chat.participants = chat.participants.filter(p => p.toString() !== userId);

    // Sanitize groupAdmin before save
    if (Array.isArray(chat.groupAdmin) || chat.groupAdmin === '') {
      chat.groupAdmin = null;
    }
    await chat.save();

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to remove member', error: err.message });
  }
};
router.put('/group/:chatId/remove', protect, removeGroupMemberHandler);
router.post('/group/:chatId/remove', protect, removeGroupMemberHandler);

// POST /api/chat/group/:chatId/leave — Leave group
router.post('/group/:chatId/leave', protect, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId);
    if (!chat || !chat.isGroup) {
      return res.status(404).json({ success: false, message: 'Group not found' });
    }

    // Verify user is a participant
    if (!chat.participants.some(p => p.toString() === req.user._id.toString())) {
      return res.status(400).json({ success: false, message: 'You are not in this group' });
    }

    // Remove user from participants
    chat.participants = chat.participants.filter(p => p.toString() !== req.user._id.toString());

    // If admin is leaving, transfer to first remaining participant
    if (chat.groupAdmin?.toString() === req.user._id.toString()) {
      chat.groupAdmin = chat.participants.length > 0 ? chat.participants[0] : null;
    }

    // Sanitize groupAdmin before save
    if (Array.isArray(chat.groupAdmin) || chat.groupAdmin === '') {
      chat.groupAdmin = null;
    }

    if (chat.participants.length === 0) {
      // No one left, delete chat and messages
      await Message.deleteMany({ chat: chat._id });
      await chat.deleteOne();
    } else {
      await chat.save();

      // Send system message about leaving
      await Message.create({
        chat: chat._id,
        sender: req.user._id,
        content: `${req.user.name || 'Someone'} left the group`,
        type: 'system',
      });
    }

    res.json({ success: true, message: 'Left group' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to leave group', error: err.message });
  }
});

module.exports = router;
