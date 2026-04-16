/**
 * Boss Command Center Routes
 * POST /api/boss/order — Submit an order to AI agents
 * GET  /api/boss/orders — List all orders
 * GET  /api/boss/orders/:id — Get order detail with live status
 * POST /api/boss/quick-command — Execute a quick command
 * GET  /api/boss/agents — List all agents and their capabilities
 * GET  /api/boss/dashboard — Boss dashboard stats
 */

const express = require('express');
const crypto = require('crypto');
const router = express.Router();
const { protect } = require('../middleware/auth');
const AgentOrder = require('../models/AgentOrder');
const { executeOrder } = require('../agents/agentEngine');
const { getAllAgents, quickCommands, getAgent } = require('../agents/agentConfig');

// ===== BOSS ACCESS VERIFICATION =====
// Rate limiting for PIN verification (in-memory, resets on restart)
const pinAttempts = new Map(); // ip -> { count, lastAttempt }
const PIN_RATE_LIMIT = 10; // max attempts per IP per hour
const PIN_RATE_WINDOW = 60 * 60 * 1000; // 1 hour

router.post('/verify-access', (req, res) => {
  const { pin } = req.body;
  const clientIp = req.ip || req.connection.remoteAddress;

  // Rate limit check
  const now = Date.now();
  const attempts = pinAttempts.get(clientIp) || { count: 0, lastAttempt: 0 };
  if (now - attempts.lastAttempt > PIN_RATE_WINDOW) {
    attempts.count = 0; // Reset after window
  }
  if (attempts.count >= PIN_RATE_LIMIT) {
    return res.status(429).json({ success: false, message: 'Too many attempts. Try again later.' });
  }

  if (!pin) {
    return res.status(400).json({ success: false, message: 'PIN is required' });
  }

  // Verify against BOSS_PIN env variable (defaults to 'nearfo2026' if not set)
  const correctPin = process.env.BOSS_PIN || 'nearfo2026';

  if (pin === correctPin) {
    // Generate a time-limited boss session token
    const token = crypto.randomBytes(32).toString('hex');
    const expiry = Date.now() + (30 * 60 * 1000); // 30 min

    // Store valid token in memory
    if (!global.bossTokens) global.bossTokens = new Map();
    global.bossTokens.set(token, { expiry, ip: clientIp });

    // Clean up expired tokens
    for (const [t, data] of global.bossTokens) {
      if (data.expiry < now) global.bossTokens.delete(t);
    }

    // Reset attempts on success
    pinAttempts.delete(clientIp);

    console.log(`Boss access granted from ${clientIp} at ${new Date().toISOString()}`);

    return res.json({
      success: true,
      message: 'Access granted. Welcome, Boss!',
      token,
    });
  }

  // Wrong PIN
  attempts.count++;
  attempts.lastAttempt = now;
  pinAttempts.set(clientIp, attempts);

  console.warn(`Boss PIN failed from ${clientIp} (attempt ${attempts.count}) at ${new Date().toISOString()}`);

  return res.status(401).json({
    success: false,
    message: 'Invalid PIN. Access denied.',
  });
});

// ===== SUBMIT ORDER =====
router.post('/order', protect, async (req, res) => {
  try {
    const { order, agents, quickCommand } = req.body;

    if (!order || order.trim().length === 0) {
      return res.status(400).json({ success: false, message: 'Order text is required' });
    }

    // Determine target agents
    let targetAgents = agents || ['all'];
    if (typeof targetAgents === 'string') targetAgents = [targetAgents];

    // Create order in DB
    const agentOrder = await AgentOrder.create({
      boss: req.user._id,
      order: order.trim(),
      targetAgents,
      quickCommand: quickCommand || null,
      status: 'pending',
    });

    // Get Socket.io instance
    const io = req.app.get('io');

    // Start execution (non-blocking — runs in background)
    executeOrder(agentOrder._id, io).catch(err => {
      console.error('Order execution error:', err.message);
    });

    // Return immediately with order ID (client tracks via Socket.io)
    res.json({
      success: true,
      message: 'Order submitted! Your agents are on it 🫡',
      data: {
        orderId: agentOrder._id,
        status: 'pending',
        targetAgents,
        quickCommand: quickCommand || null,
      },
    });

  } catch (err) {
    console.error('Boss order error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== QUICK COMMAND =====
router.post('/quick-command', protect, async (req, res) => {
  try {
    const { command } = req.body;

    if (!command || !quickCommands[command]) {
      return res.status(400).json({
        success: false,
        message: 'Invalid quick command',
        availableCommands: Object.keys(quickCommands),
      });
    }

    const qc = quickCommands[command];

    // Create order with quick command
    const agentOrder = await AgentOrder.create({
      boss: req.user._id,
      order: `Quick Command: ${command} — ${qc.description}`,
      targetAgents: qc.agents,
      quickCommand: command,
      status: 'pending',
    });

    const io = req.app.get('io');

    // Execute in background
    executeOrder(agentOrder._id, io).catch(err => {
      console.error('Quick command error:', err.message);
    });

    res.json({
      success: true,
      message: `${command} initiated! Agents assigned: ${qc.agents.map(a => getAgent(a)?.name || a).join(', ')}`,
      data: {
        orderId: agentOrder._id,
        command,
        agents: qc.agents,
      },
    });

  } catch (err) {
    console.error('Quick command error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== LIST ORDERS =====
router.get('/orders', protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const status = req.query.status;

    const query = { boss: req.user._id };
    if (status) query.status = status;

    const orders = await AgentOrder.find(query)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .select('-steps.response -finalSummary'); // Light response

    const total = await AgentOrder.countDocuments(query);

    res.json({
      success: true,
      data: orders,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== GET ORDER DETAIL =====
router.get('/orders/:id', protect, async (req, res) => {
  try {
    const order = await AgentOrder.findOne({
      _id: req.params.id,
      boss: req.user._id,
    });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    res.json({ success: true, data: order });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== LIST AGENTS =====
router.get('/agents', protect, async (req, res) => {
  try {
    const agents = getAllAgents();
    res.json({
      success: true,
      data: agents,
      totalAgents: agents.length,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== AGENT DETAIL =====
router.get('/agents/:id', protect, async (req, res) => {
  try {
    const agent = getAgent(req.params.id);
    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    res.json({
      success: true,
      data: {
        ...agent,
        tools: agent.tools.map(t => ({ name: t.name, description: t.description })),
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== QUICK COMMANDS LIST =====
router.get('/quick-commands', protect, async (req, res) => {
  try {
    const commands = Object.entries(quickCommands).map(([name, config]) => ({
      name,
      description: config.description,
      agents: config.agents.map(a => getAgent(a)?.name || a),
    }));

    res.json({ success: true, data: commands });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== BOSS DASHBOARD =====
router.get('/dashboard', protect, async (req, res) => {
  try {
    const userId = req.user._id;

    const [totalOrders, completedOrders, processingOrders, recentOrders] = await Promise.all([
      AgentOrder.countDocuments({ boss: userId }),
      AgentOrder.countDocuments({ boss: userId, status: 'completed' }),
      AgentOrder.countDocuments({ boss: userId, status: 'processing' }),
      AgentOrder.find({ boss: userId }).sort({ createdAt: -1 }).limit(5).select('order status targetAgents createdAt processingTimeMs'),
    ]);

    // Total tokens used
    const tokenAgg = await AgentOrder.aggregate([
      { $match: { boss: userId } },
      { $group: { _id: null, totalTokens: { $sum: '$totalTokens' }, avgTime: { $avg: '$processingTimeMs' } } },
    ]);

    const stats = tokenAgg[0] || { totalTokens: 0, avgTime: 0 };

    res.json({
      success: true,
      data: {
        totalOrders,
        completedOrders,
        processingOrders,
        failedOrders: totalOrders - completedOrders - processingOrders,
        totalTokensUsed: stats.totalTokens,
        avgProcessingTime: Math.round(stats.avgTime || 0),
        recentOrders,
        agents: getAllAgents(),
      },
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== CANCEL ORDER =====
router.post('/orders/:id/cancel', protect, async (req, res) => {
  try {
    const order = await AgentOrder.findOneAndUpdate(
      { _id: req.params.id, boss: req.user._id, status: { $in: ['pending', 'processing'] } },
      { status: 'cancelled', completedAt: new Date() },
      { new: true }
    );

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found or already completed' });
    }

    const io = req.app.get('io');
    if (io) io.emit('order_status', { orderId: order._id, status: 'cancelled' });

    res.json({ success: true, message: 'Order cancelled', data: order });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
