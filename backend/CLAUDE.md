# Nearfo — Project Reference (CEO: Akash More)

> This file is the single source of truth for all AI assistants working on Nearfo.
> READ THIS FIRST before making ANY changes.

---

## Project Overview
- **App Name:** Nearfo
- **Tagline:** "Know Your Circle"
- **Type:** Hyperlocal Social Network (India-first)
- **CEO & Founder:** Akash More (er.akashsmorey@gmail.com)
- **Domain:** nearfo.com
- **Tech Stack:** Node.js + Express, MongoDB Atlas, Socket.io, Flutter (mobile), AWS EC2

## Infrastructure
- **EC2 Instance:** i-0486744a26d0426e6 (ap-south-1)
- **EC2 Path:** /home/ec2-user/nearfo-backend/
- **Process Manager:** PM2 (process name: `nearfo-api`, port 3000)
- **Reverse Proxy:** NGINX with SSL
- **GitHub:** github.com/erakashsmorey-debug/nearfo-backend
- **Trust Proxy:** `app.set('trust proxy', 1)` (for NGINX)
- **Helmet CSP:** Custom config allowing `'unsafe-inline'` for scripts and onclick handlers

## Boss Command Center (nearfo.com/boss)
- **PIN:** nearfo2026
- **Auth:** POST /api/boss/verify-access → session token in sessionStorage
- **Session:** 30 min timeout, max 5 attempts before 60s lockout

---

## 13 AI Agents — ORIGINAL ROLES (DO NOT CHANGE)

| # | ID | Name | Emoji | Role | Tagline |
|---|------|----------|-------|------|---------|
| 1 | shield | Shield | 🛡️ | **Content Moderation Agent** | "Protecting Nearfo's community with full dedication." |
| 2 | care | Care | 💜 | **Customer Support Agent** | "Taking care of every Nearfo user." |
| 3 | blaze | Blaze | 🔥 | **Marketing & Growth Agent** | "Hustling for Nearfo's billion-dollar future." |
| 4 | pulse | Pulse | 📊 | **Analytics & Reporting Agent** | "Keeping a pulse on every metric." |
| 5 | vibe | Vibe | 🌊 | **Community Management Agent** | "Building Nearfo's community, one vibe at a time." |
| 6 | sentinel | Sentinel | 🔐 | **DevOps & Infrastructure Agent** | "Standing guard over Nearfo's infrastructure." |
| 7 | phoenix | Phoenix | 🔥 | **App Quality & Innovation Agent** | "From the ashes of every bug, Nearfo rises stronger." |
| 8 | hawk | Hawk | 🦅 | **Website Quality & Performance Agent** | "Every pixel matters, every millisecond counts." |
| 9 | justice | Justice | ⚖️ | **Legal & Compliance Agent** | "The law protects, and so do I." |
| 10 | crown | Crown | 👑 | **CEO Advisory & Strategy Agent** | "Your right hand for billion-dollar decisions." |
| 11 | shadow | Shadow | 👻 | **Competitor Analysis & Intelligence Agent** | "Watching every move they make." |
| 12 | aura | Aura | 🌸 | **Chief Doctor Agent** | "The chief doctor of all agents. Takes care of every agent, keeps them in check, manages their health and performance, and maintains herself too." |
| 13 | bolt | Bolt | ⚡ | **Universal Satellite — Instant Command Agent** | "Executes tasks at lightning speed, delivers results before you even finish thinking." |

### Agent Tools (3 per agent = 39 total)
- **Shield:** scan_codebase, check_user_activity, audit_permissions
- **Care:** analyze_feedback, draft_response, get_user_metrics
- **Blaze:** analyze_growth, create_campaign, competitor_intel
- **Pulse:** get_platform_stats, generate_report, forecast
- **Vibe:** create_content_plan, write_post, analyze_engagement
- **Sentinel:** check_system_health, check_api_performance, check_database
- **Phoenix:** assess_incident, create_recovery_plan, check_backups
- **Hawk:** track_competitors, analyze_user_flows, market_intel
- **Justice:** review_reports, detect_spam, moderate_content
- **Crown:** create_roadmap, strategic_analysis, investor_prep
- **Shadow:** analyze_competitor, find_gaps, competitive_report
- **Aura:** brand_audit, design_system, ux_review
- **Bolt:** performance_audit, create_automation, optimize_queries

### Quick Commands
- Status Report → Pulse
- Find Bugs → Shield + Sentinel
- Send Email Report → Pulse + Crown
- Full Audit → Shield + Sentinel + Justice + Bolt
- Growth Ideas → Blaze + Vibe + Hawk
- Security Check → Shield + Sentinel
- Competitor Analysis → Shadow + Hawk
- Investor Prep → Crown + Pulse + Blaze

---

## Encryption
- **Algorithm:** AES-256-GCM
- **Format:** iv:authTag:ciphertext (all hex)
- **Encrypted Fields:** name, bio, city, state, country
- **Utility:** utils/encryption.js → decryptUserData(), encryptUpdateData(), hmacHash()
- **IMPORTANT:** All API routes returning user data MUST call `decryptUserData()` on the user object

## Key Files
- `server.js` — Express app, helmet, rate limiters, trust proxy
- `agents/agentConfig.js` — AI agent definitions (roles, system prompts, tools)
- `agents/agentEngine.js` — Claude API execution engine with tool handlers
- `public/boss.html` — Boss Command Center frontend (PIN gate + dashboard)
- `routes/boss.js` — Boss API routes (verify-access, order, dashboard)
- `routes/posts.js` — Posts feed (has decryptUserData)
- `routes/users.js` — User routes (has decryptUserData)
- `routes/auth.js` — Auth routes (has decryptUserData)
- `routes/comments.js` — Comments (has decryptUserData)
- `routes/notifications.js` — Notifications (has decryptUserData)
- `utils/encryption.js` — AES-256-GCM encrypt/decrypt utilities

## Deployment Steps
1. Make changes locally
2. `git add` specific files → `git commit` → `git push origin main`
3. SSM command: `export HOME=/root && cd /home/ec2-user/nearfo-backend && git pull origin main && pm2 restart nearfo-api`
4. Verify via browser or API

## Rate Limiters
- General: 1000 req / 15 min
- Auth: 20 req / 15 min
- Boss page: 30 req / 15 min
- All have `validate: { xForwardedForHeader: false, trustProxy: false }`

---

## RULES FOR AI ASSISTANTS
1. **NEVER change agent roles** without explicit permission from Boss (Akash More)
2. **ALWAYS read this file first** before working on the project
3. **ALWAYS call decryptUserData()** when adding new routes that return user data
4. **ALWAYS push to GitHub before deploying** to EC2 (git push → then SSM pull)
5. **NEVER modify .env or credentials**
6. **Test changes in browser** after deploying
