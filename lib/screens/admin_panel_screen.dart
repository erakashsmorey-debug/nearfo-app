import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'boss_command_screen.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text(
            context.l10n.adminTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: TabBar(
              isScrollable: true,
              onTap: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              indicatorColor: Colors.deepPurpleAccent,
              indicatorWeight: 3,
              labelColor: Colors.deepPurpleAccent,
              unselectedLabelColor: Colors.grey[600],
              tabs: [
                Tab(
                  text: context.l10n.dashboardTab,
                  icon: const Icon(Icons.dashboard),
                ),
                Tab(
                  text: context.l10n.aiAgentsTab,
                  icon: const Icon(Icons.smart_toy),
                ),
                Tab(
                  text: context.l10n.usersTab,
                  icon: const Icon(Icons.people),
                ),
                Tab(
                  text: context.l10n.reportsTab,
                  icon: const Icon(Icons.flag),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildDashboardTab(),
            const BossCommandScreen(),
            _buildUsersTab(),
            _buildReportsTab(),
          ],
        ),
      ),
    );
  }

  // DASHBOARD TAB
  Widget _buildDashboardTab() {
    return FutureBuilder(
      future: ApiService.getAdminDashboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading dashboard: ${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'No data available',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final dashboardData = (snapshot.data is Map<String, dynamic>) ? (snapshot.data as Map<String, dynamic>) : <String, dynamic>{};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                title: context.l10n.totalUsersLabel,
                value: dashboardData['totalUsers']?.toString() ?? '0',
                icon: Icons.person,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: context.l10n.postsTodayLabel,
                value: dashboardData['postsToday']?.toString() ?? '0',
                icon: Icons.article,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: context.l10n.reelsTodayLabel,
                value: dashboardData['reelsToday']?.toString() ?? '0',
                icon: Icons.video_library,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: context.l10n.activeStoriesLabel,
                value: dashboardData['activeStories']?.toString() ?? '0',
                icon: Icons.image,
                color: Colors.pink,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: context.l10n.onlineUsersLabel,
                value: dashboardData['onlineUsers']?.toString() ?? '0',
                icon: Icons.cloud_done,
                color: Colors.cyan,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: context.l10n.pendingReportsLabel,
                value: dashboardData['pendingReports']?.toString() ?? '0',
                icon: Icons.warning,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: context.l10n.totalMessagesLabel,
                value: dashboardData['totalMessages']?.toString() ?? '0',
                icon: Icons.mail,
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: context.l10n.totalFollowsLabel,
                value: dashboardData['totalFollows']?.toString() ?? '0',
                icon: Icons.favorite,
                color: Colors.deepOrange,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // USERS TAB
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) {
              setState(() {});
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.l10n.searchUsersPlaceholder,
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[800]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[800]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.deepPurpleAccent),
              ),
              filled: true,
              fillColor: Colors.grey[900],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: ApiService.getAdminUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading users: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data == null || (snapshot.data is List<dynamic> && (snapshot.data as List<dynamic>).isEmpty)) {
                return Center(
                  child: Text(
                    context.l10n.noUsersFound,
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }

              final users = (snapshot.data is List) ? (snapshot.data as List<dynamic>) : <dynamic>[];

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index] as Map<String, dynamic>;
                  return _buildUserTile(user);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    bool isVerified = (user['isVerified'] as bool?) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.deepPurpleAccent.withOpacity(0.3),
            child: Text(
              ((user['name'] as String?) ?? 'U')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user['name'] as String?) ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (user['email'] as String?) ?? 'No email',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: isVerified
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              color: Colors.grey[900],
              onSelected: (value) async {
                await _handleUserVerification(user, value == 'verify');
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'verify',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isVerified ? Colors.grey[600] : Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Verify',
                        style: TextStyle(
                          color: isVerified ? Colors.grey[600] : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'unverify',
                  child: Row(
                    children: [
                      Icon(
                        Icons.cancel,
                        color: !isVerified ? Colors.grey[600] : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Unverify',
                        style: TextStyle(
                          color: !isVerified ? Colors.grey[600] : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.verified_user : Icons.person,
                      color: isVerified ? Colors.green : Colors.grey[500],
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Verified' : 'Unverified',
                      style: TextStyle(
                        color: isVerified ? Colors.green : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUserVerification(
      Map<String, dynamic> user, bool verify) async {
    try {
      await ApiService.updateAdminUser(
        user['id']?.toString() ?? '',
        {'isVerified': verify},
      );
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              verify
                  ? '${user['name']} verified successfully'
                  : '${user['name']} unverified successfully',
            ),
            backgroundColor: Colors.deepPurpleAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // REPORTS TAB
  Widget _buildReportsTab() {
    return FutureBuilder(
      future: ApiService.getReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading reports: ${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null || (snapshot.data is List && (snapshot.data as List).isEmpty)) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pending reports',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final reports = (snapshot.data is List) ? (snapshot.data as List<dynamic>) : <dynamic>[];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index] as Map<String, dynamic>;
            return _buildReportCard(report);
          },
        );
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final contentType = (report['contentType'] as String?) ?? 'Unknown';
    final reason = (report['reason'] as String?) ?? 'No reason provided';
    final description = (report['description'] as String?) ?? 'No description';
    final reporterName = (report['reporterName'] as String?) ?? 'Anonymous';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Report from $reporterName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildReportDetail(
                  label: 'Content Type',
                  value: contentType,
                  color: Colors.cyan,
                ),
                const SizedBox(height: 8),
                _buildReportDetail(
                  label: 'Reason',
                  value: reason,
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildReportDetail(
                  label: 'Description',
                  value: description,
                  color: Colors.grey,
                  isMultiline: true,
                ),
              ],
            ),
          ),
          Divider(
            color: Colors.grey[800],
            height: 1,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _handleTakeAction(report);
                    },
                    icon: const Icon(Icons.block),
                    label: const Text('Take Action'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _handleDismiss(report);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      side: BorderSide(color: Colors.grey[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetail({
    required String label,
    required String value,
    required Color color,
    bool isMultiline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
          maxLines: isMultiline ? 3 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _handleTakeAction(Map<String, dynamic> report) async {
    try {
      await ApiService.reviewReport(
        report['id']?.toString() ?? '',
        status: 'resolved',
        actionTaken: 'hide',
      );
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content hidden successfully'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDismiss(Map<String, dynamic> report) async {
    try {
      await ApiService.reviewReport(
        report['id']?.toString() ?? '',
        status: 'dismissed',
      );
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report dismissed'),
            backgroundColor: Colors.deepPurpleAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dismissing report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
