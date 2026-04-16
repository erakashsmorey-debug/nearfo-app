import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

class BossCommandScreen extends StatefulWidget {
  const BossCommandScreen({Key? key}) : super(key: key);

  @override
  State<BossCommandScreen> createState() => _BossCommandScreenState();
}

class _BossCommandScreenState extends State<BossCommandScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _orderController = TextEditingController();
  final Set<String> _selectedAgents = {'all'};
  bool _submitting = false;
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _dashboardData;
  Timer? _pollTimer;

  static const List<Map<String, String>> agents = [
    {'id': 'all', 'name': 'All Agents', 'emoji': '\u{1F465}'},
    {'id': 'shield', 'name': 'Shield', 'emoji': '\u{1F6E1}'},
    {'id': 'care', 'name': 'Care', 'emoji': '\u{1F49C}'},
    {'id': 'blaze', 'name': 'Blaze', 'emoji': '\u{1F525}'},
    {'id': 'pulse', 'name': 'Pulse', 'emoji': '\u{1F4CA}'},
    {'id': 'vibe', 'name': 'Vibe', 'emoji': '\u{1F30A}'},
    {'id': 'sentinel', 'name': 'Sentinel', 'emoji': '\u{1F510}'},
    {'id': 'phoenix', 'name': 'Phoenix', 'emoji': '\u{1F525}'},
    {'id': 'hawk', 'name': 'Hawk', 'emoji': '\u{1F985}'},
    {'id': 'justice', 'name': 'Justice', 'emoji': '\u{2696}'},
    {'id': 'crown', 'name': 'Crown', 'emoji': '\u{1F451}'},
    {'id': 'shadow', 'name': 'Shadow', 'emoji': '\u{1F47B}'},
    {'id': 'aura', 'name': 'Aura', 'emoji': '\u{1F338}'},
    {'id': 'bolt', 'name': 'Bolt', 'emoji': '\u{26A1}'},
  ];

  static const List<Map<String, String>> quickCommands = [
    {'name': 'Status Report', 'icon': '\u{1F4CA}'},
    {'name': 'Find Bugs', 'icon': '\u{1F50D}'},
    {'name': 'Send Email Report', 'icon': '\u{1F4E7}'},
    {'name': 'Full Audit', 'icon': '\u{1F50D}'},
    {'name': 'Growth Ideas', 'icon': '\u{1F4A1}'},
    {'name': 'Security Check', 'icon': '\u{1F510}'},
    {'name': 'Competitor Analysis', 'icon': '\u{1F4CA}'},
    {'name': 'Investor Prep', 'icon': '\u{1F4B0}'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboard();
    _loadOrders();
    // Poll for order updates every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshProcessingOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    final res = await ApiService.getBossDashboard();
    if (res.isSuccess && mounted) {
      setState(() => _dashboardData = res.data);
    }
  }

  Future<void> _loadOrders() async {
    final res = await ApiService.getBossOrders();
    if (res.isSuccess && mounted) {
      setState(() => _orders = List<Map<String, dynamic>>.from(
        (res.data ?? []).map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}),
      ));
    }
  }

  Future<void> _refreshProcessingOrders() async {
    final hasProcessing = _orders.any((o) => o['status'] == 'processing' || o['status'] == 'pending');
    if (!hasProcessing) return;
    await _loadOrders();
    await _loadDashboard();
  }

  void _toggleAgent(String id) {
    setState(() {
      if (id == 'all') {
        _selectedAgents.clear();
        _selectedAgents.add('all');
      } else {
        _selectedAgents.remove('all');
        if (_selectedAgents.contains(id)) {
          _selectedAgents.remove(id);
        } else {
          _selectedAgents.add(id);
        }
        if (_selectedAgents.isEmpty) _selectedAgents.add('all');
      }
    });
  }

  Future<void> _submitOrder() async {
    final text = _orderController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    final res = await ApiService.submitBossOrder(
      order: text,
      agents: _selectedAgents.toList(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.isSuccess) {
      _orderController.clear();
      _showSnack('Order sent! Agents working...', Colors.deepPurpleAccent);
      _loadOrders();
      _loadDashboard();
      _tabController.animateTo(1); // Switch to Orders tab
    } else {
      _showSnack(res.errorMessage ?? 'Failed', Colors.red);
    }
  }

  Future<void> _executeQuickCommand(String command) async {
    final res = await ApiService.executeQuickCommand(command);
    if (res.isSuccess) {
      _showSnack('$command initiated!', Colors.deepPurpleAccent);
      _loadOrders();
      _loadDashboard();
      _tabController.animateTo(1);
    } else {
      _showSnack(res.errorMessage ?? 'Failed', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs for Boss sections
        Container(
          color: const Color(0xFF0A0A10),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFF59E0B),
            labelColor: const Color(0xFFF59E0B),
            unselectedLabelColor: Colors.grey[600],
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: context.l10n.commandTab),
              Tab(text: context.l10n.ordersTab),
              Tab(text: context.l10n.statsTab),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCommandTab(),
              _buildOrdersTab(),
              _buildStatsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ===== COMMAND TAB =====
  Widget _buildCommandTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent Grid
          Text(context.l10n.selectAgent, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: agents.map((a) => _buildAgentChip(a)).toList(),
          ),
          const SizedBox(height: 20),

          // Quick Commands
          Text(context.l10n.quickCommands, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickCommands.map((q) => _buildQuickCmdChip(q)).toList(),
          ),
          const SizedBox(height: 20),

          // Order Input
          Text(context.l10n.yourOrder, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: _orderController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.l10n.orderHint,
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D2D44))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D2D44))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('\u{26A1} ${context.l10n.sendOrder}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentChip(Map<String, String> agent) {
    final selected = _selectedAgents.contains(agent['id']);
    return GestureDetector(
      onTap: () => _toggleAgent(agent['id']!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E1B4B) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFFA855F7) : const Color(0xFF2D2D44), width: 2),
          boxShadow: selected ? [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 12)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(agent['emoji']!, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(agent['name']!, style: TextStyle(color: selected ? Colors.white : Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCmdChip(Map<String, String> cmd) {
    return GestureDetector(
      onTap: () => _executeQuickCommand(cmd['name']!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2D2D44)),
        ),
        child: Text(
          '${cmd['icon']} ${cmd['name']}',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // ===== ORDERS TAB =====
  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('\u{1F4AD}', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No orders yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Give your first command above!', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFF7C3AED),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (ctx, i) => _buildOrderCard(_orders[i]),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] as String?) ?? 'pending';
    final orderText = (order['order'] as String?) ?? '';
    final orderId = (order['_id'] as String?) ?? '';
    final agents = (order['targetAgents'] as List?)?.cast<String>() ?? [];
    final time = order['createdAt'] != null ? _formatTime((order['createdAt'] as String?) ?? '') : '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'processing':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.sync;
        break;
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
    }

    return GestureDetector(
      onTap: () => _showOrderDetail(orderId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: status == 'processing' ? statusColor.withOpacity(0.5) : const Color(0xFF1F2937)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    orderText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'processing') SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: statusColor)),
                      if (status != 'processing') Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.smart_toy, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    agents.join(', '),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
            if (status == 'completed') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.touch_app, size: 13, color: Colors.deepPurpleAccent.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text('Tap to view full report', style: TextStyle(color: Colors.deepPurpleAccent.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== ORDER DETAIL =====
  Future<void> _showOrderDetail(String orderId) async {
    if (orderId.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => _OrderDetailSheet(orderId: orderId, scrollController: scrollCtrl),
      ),
    );
  }

  // ===== STATS TAB =====
  Widget _buildStatsTab() {
    if (_dashboardData == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }
    final d = _dashboardData!;
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: const Color(0xFF7C3AED),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatTile('Total Orders', '${d['totalOrders'] ?? 0}', Icons.receipt_long, const Color(0xFF7C3AED)),
            _buildStatTile('Completed', '${d['completedOrders'] ?? 0}', Icons.check_circle, const Color(0xFF10B981)),
            _buildStatTile('Processing', '${d['processingOrders'] ?? 0}', Icons.sync, const Color(0xFFF59E0B)),
            _buildStatTile('Tokens Used', '${d['totalTokensUsed'] ?? 0}', Icons.token, const Color(0xFF3B82F6)),
            _buildStatTile('Avg Time', '${((d['avgProcessingTime'] ?? 0) / 1000).toStringAsFixed(1)}s', Icons.timer, const Color(0xFFF97316)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

// ===== ORDER DETAIL BOTTOM SHEET =====
class _OrderDetailSheet extends StatefulWidget {
  final String orderId;
  final ScrollController scrollController;

  const _OrderDetailSheet({required this.orderId, required this.scrollController});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_order != null && (_order!['status'] == 'processing' || _order!['status'] == 'pending')) {
        _loadDetail();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final res = await ApiService.getBossOrderDetail(widget.orderId);
    if (res.isSuccess && mounted) {
      setState(() {
        _order = res.data;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _order == null
              ? const Center(child: Text('Order not found', style: TextStyle(color: Colors.white54)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    final status = (order['status'] as String?) ?? 'pending';
    final steps = (order['steps'] as List?) ?? [];
    final totalTokens = (order['totalTokens'] as num?) ?? 0;
    final processingMs = (order['processingTimeMs'] as num?) ?? 0;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Text((order['order'] as String?) ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // Status + meta
        Row(
          children: [
            _statusBadge(status),
            const Spacer(),
            if (totalTokens > 0) Text('$totalTokens tokens', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            if (processingMs > 0) Text(' \u{2022} ${(processingMs / 1000).toStringAsFixed(1)}s', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        const SizedBox(height: 20),

        // Divider
        Container(height: 1, color: const Color(0xFF1F2937)),
        const SizedBox(height: 16),

        // Agent Steps
        const Text('Agent Reports', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),

        ...steps.map((step) => _buildStepCard(step is Map<String, dynamic> ? step : {})),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'processing': color = const Color(0xFFF59E0B); break;
      case 'completed': color = const Color(0xFF10B981); break;
      case 'failed': color = const Color(0xFFEF4444); break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'processing') SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
          if (status != 'processing') Icon(status == 'completed' ? Icons.check_circle : Icons.schedule, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    final agentName = (step['agentName'] as String?) ?? (step['agentId'] as String?) ?? 'Agent';
    final status = (step['status'] as String?) ?? 'queued';
    final toolUsed = (step['toolUsed'] as String?) ?? '';
    final response = (step['response'] as String?) ?? '';
    final tokens = (step['tokensUsed'] as num?) ?? 0;

    // Find emoji for agent
    String emoji = '\u{1F916}';
    final agentId = ((step['agentId'] as String?) ?? '').toString().toLowerCase();
    for (final a in _BossCommandScreenState.agents) {
      if (a['id'] == agentId) { emoji = a['emoji']!; break; }
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case 'thinking': statusColor = const Color(0xFFFCD34D); statusText = 'Thinking...'; break;
      case 'using_tool': statusColor = const Color(0xFF60A5FA); statusText = 'Using: ${toolUsed.isEmpty ? "tool" : toolUsed}'; break;
      case 'completed': statusColor = const Color(0xFF6EE7B7); statusText = 'Done'; break;
      case 'failed': statusColor = const Color(0xFFFCA5A5); statusText = 'Failed'; break;
      default: statusColor = Colors.grey; statusText = 'Queued'; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'completed' ? const Color(0xFF10B981).withOpacity(0.3)
               : status == 'processing' || status == 'thinking' ? const Color(0xFFF59E0B).withOpacity(0.3)
               : const Color(0xFF1F2937),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent header
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              if (tokens > 0) Text('$tokens tok', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ],
          ),

          // Response
          if (response.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                response,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
          ],

          // Tool info
          if (toolUsed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.build, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Tool: $toolUsed', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
