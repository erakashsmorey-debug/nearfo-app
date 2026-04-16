/**
 * Nearfo Agent Execution Engine
 * Runs AI agents via Anthropic Claude API with real-time Socket.io updates
 */

const Anthropic = require('@anthropic-ai/sdk');
const { agentDefinitions, quickCommands } = require('./agentConfig');
const AgentOrder = require('../models/AgentOrder');

// Lazy-init Anthropic client (only when ANTHROPIC_API_KEY is set)
let anthropic = null;
const getClient = () => {
  if (!anthropic) {
    if (!process.env.ANTHROPIC_API_KEY) {
      throw new Error('ANTHROPIC_API_KEY not set in environment variables');
    }
    anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }
  return anthropic;
};

// ===== TOOL HANDLERS =====
// These simulate real data lookups — replace with actual DB queries in production
const toolHandlers = {
  // Shield tools
  scan_codebase: async (input, context) => {
    const { target } = input;
    const findings = {
      auth: '✅ JWT tokens have expiry. ⚠️ No refresh token rotation. ⚠️ Rate limiting on auth is 20/15min (consider lowering to 10). ✅ Firebase phone OTP is secure.',
      api: '✅ Helmet.js headers active. ✅ CORS configured. ⚠️ Some endpoints missing input validation (Joi not applied on all routes). ⚠️ File upload accepts any MIME type.',
      database: '✅ Mongoose schema validation. ⚠️ No field-level encryption on messages. ✅ MongoDB connection uses TLS. ⚠️ No query timeout limits set.',
      full: '🔍 Full scan: 3 Critical, 5 High, 8 Medium, 12 Low severity issues found. Top: Missing refresh token rotation, no input validation on 6 endpoints, file upload MIME check needed.'
    };
    return findings[target] || findings.full;
  },

  check_user_activity: async (input, context) => {
    const User = require('../models/User');
    const totalUsers = await User.countDocuments();
    const recentUsers = await User.countDocuments({ lastLogin: { $gte: new Date(Date.now() - 24*60*60*1000) } }).catch(() => 0);
    return `Total users: ${totalUsers}. Active in last 24h: ${recentUsers}. No suspicious login patterns detected. Recommend implementing login anomaly detection.`;
  },

  audit_permissions: async (input, context) => {
    return 'Permission audit: Only boss-level users can access /api/boss. Admin panel has role check. ⚠️ No role-based access control (RBAC) on post/reel deletion — any authenticated user can try. Recommend adding ownership check middleware.';
  },

  // Care tools
  analyze_feedback: async (input, context) => {
    return `Feedback analysis (${input.source}): Top themes — 1) Users want dark mode improvements 2) Chat loading slow on poor networks 3) Profile picture upload fails sometimes 4) Want more story features 5) Request for video calling quality improvement. Overall sentiment: 72% positive.`;
  },

  draft_response: async (input, context) => {
    return `Draft response for "${input.issue}": "Hi there! Thanks for reaching out. We understand this is frustrating and we're actively working on a fix. Our team has been notified and you should see an improvement in the next update. Is there anything else we can help with?"`;
  },

  get_user_metrics: async (input, context) => {
    const User = require('../models/User');
    const total = await User.countDocuments();
    return `User metrics: ${total} total users. Avg session: 12min. 7-day retention: ~45%. Top features used: Chat (68%), Feed (52%), Stories (31%), Reels (28%). Churn risk users: ~15%.`;
  },

  // Blaze tools
  analyze_growth: async (input, context) => {
    const User = require('../models/User');
    const Post = require('../models/Post');
    const users = await User.countDocuments();
    const posts = await Post.countDocuments();
    return `Growth metrics (${input.metric}): ${users} total users, ${posts} total posts. User growth: ~12% month-over-month. Engagement rate: ~8.5%. Top acquisition channel: Organic (65%), Referral (20%), Social (15%).`;
  },

  create_campaign: async (input, context) => {
    return `Campaign "${input.goal}" designed:\n🎯 Target: 18-25 age group, college students\n📱 Channels: Instagram Reels, YouTube Shorts, College WhatsApp groups\n💡 Hook: "Your neighborhood, your vibe — Nearfo"\n📊 Expected reach: 50K-100K in first week\n💰 Budget: ${input.budget || 'To be determined'}`;
  },

  competitor_intel: async (input, context) => {
    return `Competitor intel (${input.competitor}): Instagram focusing on AI features. Snapchat losing Gen-Z to BeReal. Twitter/X monetization pushing users away. OPPORTUNITY: Location-based social is underserved — Nearfo's "Know Your Circle" positioning is unique. Key differentiator: Hyperlocal + AI agents.`;
  },

  // Pulse tools
  get_platform_stats: async (input, context) => {
    const User = require('../models/User');
    const Post = require('../models/Post');
    const Chat = require('../models/Chat');
    const [users, posts, chats] = await Promise.all([
      User.countDocuments(),
      Post.countDocuments(),
      Chat.countDocuments(),
    ]);
    return `Platform stats (${input.period}): Users: ${users} | Posts: ${posts} | Active chats: ${chats} | API uptime: 99.2% | Avg response time: 180ms | Storage used: ~2.4GB S3`;
  },

  generate_report: async (input, context) => {
    const User = require('../models/User');
    const Post = require('../models/Post');
    const users = await User.countDocuments();
    const posts = await Post.countDocuments();
    return `📊 ${input.type.toUpperCase()} REPORT\n━━━━━━━━━━━━━━━\nUsers: ${users} | Posts: ${posts}\nDAU estimate: ${Math.floor(users * 0.15)} | WAU estimate: ${Math.floor(users * 0.45)}\nGrowth rate: ~12% MoM\nTop feature: Chat (68% daily usage)\nRevenue: Pre-monetization phase\nRecommendation: Focus on reaching 10K users before monetizing.`;
  },

  forecast: async (input, context) => {
    const User = require('../models/User');
    const users = await User.countDocuments();
    const months = input.months || 6;
    const projections = [];
    let current = users;
    for (let i = 1; i <= months; i++) {
      current = Math.floor(current * 1.12);
      projections.push(`Month ${i}: ${current}`);
    }
    return `Forecast (${input.metric}, ${months} months, 12% MoM growth):\n${projections.join('\n')}\nNote: Assumes consistent organic growth. Marketing campaigns could 2-3x this.`;
  },

  // Vibe tools
  create_content_plan: async (input, context) => {
    return `Content plan for ${input.platform} (${input.duration || '1month'}):\n📅 Mon: Feature spotlight / tip\n📅 Tue: User story / testimonial\n📅 Wed: Behind-the-scenes / team\n📅 Thu: Meme / trending audio\n📅 Fri: Poll / interactive\n📅 Sat: Community highlight\n📅 Sun: Inspirational / vision post\nHashtags: #Nearfo #KnowYourCircle #LocalVibes #HyperLocal`;
  },

  write_post: async (input, context) => {
    return `Post for ${input.platform || 'social media'} about "${input.topic}":\n\n"Your neighborhood has stories. Your circle has vibes. Nearfo connects you to what matters most — the people around you. 🌍✨\n\n#Nearfo #KnowYourCircle #LocalFirst"\n\nAlt versions available on request.`;
  },

  analyze_engagement: async (input, context) => {
    return 'Engagement analysis: Avg likes/post: 24. Avg comments: 8. Best posting time: 7-9 PM IST. Best content type: Stories (3.2x more views than posts). Reels engagement 2.5x higher than static posts. User-generated content gets 40% more engagement.';
  },

  // Sentinel tools
  check_system_health: async (input, context) => {
    return '🟢 Server: Running | 🟢 Database: Connected | 🟢 Socket.io: Active | 🟢 S3: Accessible | 🟢 Firebase: OK | ⚡ Memory: 256MB/512MB | ⚡ CPU: 15% | 📊 Uptime: 99.2% (30d)';
  },

  check_api_performance: async (input, context) => {
    return `API Performance (${input.endpoint}):\n/api/auth: 120ms avg ✅\n/api/posts: 180ms avg ✅\n/api/chat: 95ms avg ✅\n/api/reels: 250ms avg ⚠️ (heavy media)\n/api/users: 110ms avg ✅\nError rate: 0.3% (good)\n⚠️ /api/reels could benefit from pagination optimization`;
  },

  check_database: async (input, context) => {
    const mongoose = require('mongoose');
    const state = mongoose.connection.readyState;
    const states = { 0: 'Disconnected', 1: 'Connected', 2: 'Connecting', 3: 'Disconnecting' };
    return `Database: ${states[state] || 'Unknown'} | Host: MongoDB Atlas | Collections: 8 | Indexes: Optimized | ⚠️ Recommend adding compound indexes on Chat(participants, updatedAt) and Post(user, createdAt) for faster queries.`;
  },

  // Phoenix tools
  assess_incident: async (input, context) => {
    return `Incident Assessment: "${input.description}"\nSeverity: Analyzing...\nImpact: Estimated user impact based on feature criticality\nRecommended: 1) Check server logs 2) Verify database connectivity 3) Check recent deployments 4) Monitor error rates\nEscalation: Notify team if not resolved in 15 minutes.`;
  },

  create_recovery_plan: async (input, context) => {
    return `Recovery Plan (${input.scenario}):\n1️⃣ Immediate: Rollback to last stable deployment\n2️⃣ Short-term: Fix root cause, add monitoring\n3️⃣ Medium-term: Add automated failover\n4️⃣ Long-term: Implement blue-green deployments\n⏱️ Target recovery time: <30 minutes\n📋 Post-incident review: Required within 24 hours`;
  },

  check_backups: async (input, context) => {
    return 'Backup status: MongoDB Atlas auto-backups enabled (daily). S3 media: No backup policy set ⚠️. Recommend: Enable S3 cross-region replication. Code: GitHub repo (good). Env vars: ⚠️ No secure backup of .env — recommend using AWS Secrets Manager.';
  },

  // Hawk tools
  track_competitors: async (input, context) => {
    return `Competitor tracking (${input.competitor}):\n📱 Instagram: Launched AI editing tools, focusing on creators\n📱 Snapchat: AR features, losing engagement\n📱 BeReal: Struggling with daily retention\n📱 Threads: Growing but no location features\n🎯 Nearfo's edge: Hyperlocal + AI agents = no competitor has this combo`;
  },

  analyze_user_flows: async (input, context) => {
    return `User flow analysis (${input.flow}):\nOnboarding: 78% complete phone verification → 65% add profile pic → 45% make first post → 30% start first chat\n⚠️ Biggest drop-off: Profile pic upload (13% drop). Suggest: Make it optional, add AI avatar option.\n⚠️ Second drop-off: First post (20% drop). Suggest: Add post templates/prompts.`;
  },

  market_intel: async (input, context) => {
    return `Market intelligence (${input.topic}):\n📈 Social media market: $230B globally, growing 12% YoY\n🎯 Hyperlocal social: Emerging niche, <5 serious players\n🇮🇳 India: 500M+ smartphone users, 350M+ on social media\n💡 Trend: Users want authenticity over influencer culture\n🔑 Opportunity: Location-based discovery is the next big wave`;
  },

  // Justice tools
  review_reports: async (input, context) => {
    const Report = require('../models/Report');
    const counts = {
      pending: await Report.countDocuments({ status: 'pending' }).catch(() => 0),
      reviewed: await Report.countDocuments({ status: 'reviewed' }).catch(() => 0),
      total: await Report.countDocuments().catch(() => 0),
    };
    return `Report review (${input.status}): Total: ${counts.total} | Pending: ${counts.pending} | Reviewed: ${counts.reviewed} | Action needed on ${counts.pending} reports. Most common report reason: Spam content.`;
  },

  detect_spam: async (input, context) => {
    return 'Spam detection scan: Checked recent accounts and posts. Indicators monitored: Rapid posting (>10/hour), duplicate content, suspicious usernames, new accounts with high activity. Currently: No major spam wave detected. Recommend implementing automated spam scoring.';
  },

  moderate_content: async (input, context) => {
    return `Content moderation (${input.contentType}): Scanned recent ${input.contentType}. Policy compliance: ~96%. Flagged items: 0 critical, 2 medium (potentially inappropriate language in comments). Recommend: Add AI-powered content filtering for images and text.`;
  },

  // Crown tools
  create_roadmap: async (input, context) => {
    return `Product Roadmap (${input.timeframe}):\n\n🏗️ Phase 1 (Month 1-2): Polish core features, fix all bugs, 99.9% stability\n🚀 Phase 2 (Month 2-3): AI Agents live, Premium features, Monetization v1\n📈 Phase 3 (Month 3-4): Scale to 10K users, Influencer partnerships\n💰 Phase 4 (Month 4-6): Revenue optimization, Series-A prep, International expansion planning\n\nKey Milestones: 1K DAU → 5K DAU → 10K DAU → Revenue positive`;
  },

  strategic_analysis: async (input, context) => {
    const analyses = {
      swot: 'SWOT Analysis:\n💪 Strengths: Unique hyperlocal positioning, AI agents (innovative), Strong tech foundation, Passionate founder\n⚠️ Weaknesses: Small user base, Pre-revenue, Small team\n🎯 Opportunities: India\'s growing social market, No hyperlocal competitor, AI trend wave\n🔴 Threats: Big tech cloning features, User acquisition cost, Regulatory changes',
      competitive: 'Competitive positioning: Nearfo occupies unique "hyperlocal + AI" space. No direct competitor. Indirect: Instagram (broad social), NextDoor (hyperlocal but boring), WhatsApp groups (no discovery). Moat: AI agent system + location-based algorithm.',
      market: 'Market analysis: TAM $230B global social. SAM $15B India social. SOM $500M hyperlocal India. Current penetration: <0.01%. Growth potential: Massive if product-market fit achieved.',
      financial: 'Financial analysis: Pre-revenue. Burn rate: Low (solo founder + cloud costs). Revenue potential: Premium features ($2-5/mo), Local business ads, Promoted posts. Break-even estimate: At 50K users with 5% conversion to premium.'
    };
    return analyses[input.type] || analyses.swot;
  },

  investor_prep: async (input, context) => {
    const User = require('../models/User');
    const Post = require('../models/Post');
    const users = await User.countDocuments();
    const posts = await Post.countDocuments();
    return `Investor Prep (${input.stage}):\n\n📊 Key Metrics: ${users} users, ${posts} posts, Growing MoM\n💡 Pitch: "Nearfo is the hyperlocal social network powered by AI agents — connecting people to their neighborhood"\n🎯 Ask: Pre-seed $250K-500K for 18 months runway\n📋 Use of funds: 40% Engineering, 30% Growth, 20% Operations, 10% Buffer\n🏆 Traction: Working product, Growing user base, 13 AI agents (unique moat)\n📈 Vision: Become the #1 hyperlocal social platform in India, then globally`;
  },

  // Shadow tools
  analyze_competitor: async (input, context) => {
    return `Deep analysis — ${input.name}:\n📱 App rating: 4.2★ (declining)\n👥 User base: Varies by competitor\n💰 Revenue model: Ads + Premium\n⚠️ User complaints: Algorithm bias, privacy concerns, creator burnout\n🎯 Their weakness = Our opportunity: They ignore hyperlocal. Build what they won't.`;
  },

  find_gaps: async (input, context) => {
    return `Market gaps in ${input.market}:\n1️⃣ No hyperlocal social discovery in India\n2️⃣ No AI-powered personal assistant in social apps\n3️⃣ No location-based content algorithm\n4️⃣ No neighborhood-level community building\n5️⃣ No local business integration in social feeds\n💡 Nearfo can own ALL of these.`;
  },

  competitive_report: async (input, context) => {
    return 'Competitive Landscape Report:\n🥇 Instagram: Content-heavy, no local focus\n🥈 Snapchat: AR-focused, declining in India\n🥉 WhatsApp: Messaging only, no discovery\n4️⃣ BeReal: Gimmick fatigue\n5️⃣ Threads: Text-only, no local\n\n✅ Nearfo differentiators: Hyperlocal algorithm, AI agents, Know Your Circle concept, Indian-first design';
  },

  // Aura tools
  brand_audit: async (input, context) => {
    return 'Brand audit:\n🎨 Colors: Purple/violet gradient — strong, memorable ✅\n📝 Typography: Clean, modern ✅\n🌟 Logo: Needs refinement for app stores ⚠️\n📱 App screenshots: Need updating for latest features ⚠️\n💬 Tagline "Know Your Circle": Strong, memorable ✅\n🎯 Brand consistency: 7/10 — some screens have inconsistent spacing and colors';
  },

  design_system: async (input, context) => {
    return `Design system (${input.component}):\n🎨 Primary: #7C3AED (Purple)\n🎨 Background: #0A0A10 (Dark)\n🎨 Surface: #1A1A2E\n🎨 Accent: #A855F7\n📏 Spacing: 4px grid system\n📝 Font: System default (consider custom)\n🔲 Border radius: 12px standard\n✨ Animations: 300ms ease-in-out\nRecommend: Document all tokens in a shared design file.`;
  },

  ux_review: async (input, context) => {
    return `UX review (${input.screen}):\n✅ Good: Dark theme, clean layout, intuitive navigation\n⚠️ Improve: Loading states need skeleton screens, Error states need friendly illustrations, Empty states need compelling CTAs\n💡 Suggest: Add haptic feedback on interactions, Micro-animations on like/follow, Pull-to-refresh with branded animation`;
  },

  // Bolt tools
  performance_audit: async (input, context) => {
    return `Performance audit (${input.target}):\n⚡ API avg response: 180ms (target: <200ms ✅)\n⚡ App cold start: ~3s (target: <2s ⚠️)\n⚡ Image loading: Lazy + cached ✅\n⚠️ Bottleneck: No pagination on some list endpoints\n⚠️ Bottleneck: Stories feed loads all at once\n💡 Fix: Add cursor-based pagination, Implement virtual scrolling, Add Redis cache layer`;
  },

  create_automation: async (input, context) => {
    return `Automation plan for "${input.process}":\n🤖 Trigger: Automatic on schedule/event\n⚙️ Steps: 1) Detect condition → 2) Execute action → 3) Notify boss → 4) Log result\n📊 Expected time saved: 2-5 hours/week\n🔧 Implementation: Add cron job + webhook\n⏱️ Build time: ~4 hours`;
  },

  optimize_queries: async (input, context) => {
    return 'Database optimization:\n⚠️ Missing indexes: Chat.participants, Post.location, User.lastLogin\n⚠️ Slow queries: Get feed (no location index), Get chat list (sorting by updatedAt without index)\n💡 Add indexes: db.chats.createIndex({participants:1, updatedAt:-1}), db.posts.createIndex({location:"2dsphere", createdAt:-1})\n⚡ Expected improvement: 3-5x faster on feed and chat queries';
  },
};

// ===== EXECUTE SINGLE AGENT =====
async function executeAgent(agentId, order, orderId, io) {
  const agentDef = agentDefinitions[agentId];
  if (!agentDef) throw new Error(`Unknown agent: ${agentId}`);

  const client = getClient();
  const stepUpdate = async (update) => {
    // Update database
    await AgentOrder.updateOne(
      { _id: orderId, 'steps.agentId': agentId },
      { $set: Object.fromEntries(Object.entries(update).map(([k, v]) => [`steps.$.${k}`, v])) }
    ).catch(() => {});

    // Emit real-time update via Socket.io
    if (io) {
      io.emit('agent_update', { orderId, agentId, ...update });
    }
  };

  // Mark as thinking
  await stepUpdate({ status: 'thinking', startedAt: new Date() });

  try {
    // First API call
    let response = await client.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 2048,
      system: agentDef.systemPrompt,
      tools: agentDef.tools,
      messages: [{ role: 'user', content: `Boss Order: ${order}` }],
    });

    let finalText = '';
    let totalTokens = (response.usage?.input_tokens || 0) + (response.usage?.output_tokens || 0);

    // Handle tool use loop (agent may use multiple tools)
    while (response.stop_reason === 'tool_use') {
      const toolUseBlock = response.content.find(b => b.type === 'tool_use');
      if (!toolUseBlock) break;

      const toolName = toolUseBlock.name;
      const toolInput = toolUseBlock.input;

      // Emit tool usage update
      await stepUpdate({ status: 'using_tool', toolUsed: toolName, toolInput });

      // Execute tool
      let toolResult;
      try {
        if (toolHandlers[toolName]) {
          toolResult = await toolHandlers[toolName](toolInput, { orderId });
        } else {
          toolResult = `Tool ${toolName} executed with input: ${JSON.stringify(toolInput)}`;
        }
      } catch (err) {
        toolResult = `Tool error: ${err.message}`;
      }

      await stepUpdate({ toolResult: toolResult.substring(0, 500) });

      // Continue conversation with tool result
      response = await client.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 2048,
        system: agentDef.systemPrompt,
        tools: agentDef.tools,
        messages: [
          { role: 'user', content: `Boss Order: ${order}` },
          { role: 'assistant', content: response.content },
          { role: 'user', content: [{ type: 'tool_result', tool_use_id: toolUseBlock.id, content: toolResult }] },
        ],
      });

      totalTokens += (response.usage?.input_tokens || 0) + (response.usage?.output_tokens || 0);
    }

    // Extract final text response
    finalText = response.content
      .filter(b => b.type === 'text')
      .map(b => b.text)
      .join('\n');

    // Mark completed
    await stepUpdate({
      status: 'completed',
      response: finalText,
      completedAt: new Date(),
      tokensUsed: totalTokens,
    });

    return { agentId, response: finalText, tokensUsed: totalTokens };

  } catch (err) {
    await stepUpdate({ status: 'failed', response: `Error: ${err.message}`, completedAt: new Date() });
    return { agentId, response: `Agent ${agentDef.name} failed: ${err.message}`, tokensUsed: 0 };
  }
}

// ===== EXECUTE ORDER (Multiple Agents) =====
async function executeOrder(orderId, io) {
  const order = await AgentOrder.findById(orderId);
  if (!order) throw new Error('Order not found');

  const startTime = Date.now();

  // Update order status
  order.status = 'processing';
  await order.save();
  if (io) io.emit('order_status', { orderId, status: 'processing' });

  // Determine which agents to run
  let agentIds = order.targetAgents;
  if (agentIds.includes('all')) {
    agentIds = Object.keys(agentDefinitions);
  }

  // If it's a quick command, use predefined agent assignments
  if (order.quickCommand && quickCommands[order.quickCommand]) {
    agentIds = quickCommands[order.quickCommand].agents;
  }

  // Initialize steps
  order.steps = agentIds.map(id => ({
    agentId: id,
    agentName: agentDefinitions[id]?.name || id,
    status: 'queued',
  }));
  await order.save();

  // Execute agents in parallel
  try {
    const results = await Promise.all(
      agentIds.map(id => executeAgent(id, order.order, orderId, io))
    );

    // Calculate totals
    const totalTokens = results.reduce((sum, r) => sum + r.tokensUsed, 0);
    const processingTime = Date.now() - startTime;

    // Create final summary from all agent responses
    const summary = results
      .map(r => {
        const agent = agentDefinitions[r.agentId];
        return `${agent?.emoji || '🤖'} **${agent?.name || r.agentId}**:\n${r.response}`;
      })
      .join('\n\n---\n\n');

    // Update order as completed
    order.status = 'completed';
    order.finalSummary = summary;
    order.totalTokens = totalTokens;
    order.processingTimeMs = processingTime;
    order.completedAt = new Date();
    await order.save();

    if (io) {
      io.emit('order_status', { orderId, status: 'completed', processingTimeMs: processingTime });
      io.emit('order_complete', { orderId, summary, totalTokens, processingTimeMs: processingTime });
    }

    return { orderId, status: 'completed', summary, totalTokens, processingTimeMs: processingTime };

  } catch (err) {
    order.status = 'failed';
    order.finalSummary = `Execution failed: ${err.message}`;
    order.processingTimeMs = Date.now() - startTime;
    order.completedAt = new Date();
    await order.save();

    if (io) io.emit('order_status', { orderId, status: 'failed', error: err.message });
    throw err;
  }
}

module.exports = { executeAgent, executeOrder, toolHandlers };
