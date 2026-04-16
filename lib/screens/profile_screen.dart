import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/highlights_row.dart';
import 'followers_following_screen.dart';
import '../l10n/l10n_helper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(context.l10n.profileTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: NearfoColors.text)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, NearfoRoutes.settings),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NearfoColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NearfoColors.border),
                        boxShadow: [
                          BoxShadow(color: NearfoColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: 1),
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Icon(Icons.settings_rounded, color: NearfoColors.primary, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // Profile Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1a1040), Color(0xFF12121a)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.15), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  // Avatar with Gradient Ring
                  Stack(
                    children: [
                      // Gradient Ring Background - 3 color gradient ring
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFFF0050), Color(0xFFFF8800)],
                          ),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.5), blurRadius: 14, spreadRadius: 2),
                            BoxShadow(color: const Color(0xFFFF0050).withOpacity(0.3), blurRadius: 10, spreadRadius: 0),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFF1a1040),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: NearfoColors.primaryGradient,
                            ),
                            child: (user?.avatarUrl ?? '').isNotEmpty
                                ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(user!.avatarUrl!), fit: BoxFit.cover, placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), errorWidget: (_, __, ___) => Center(child: Text(user.initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)))))
                                : Center(
                                    child: Text(
                                      user?.initials ?? '?',
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: NearfoColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: NearfoColors.bg, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(user?.name ?? 'Loading...', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      if (user?.isVerified == true) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified, color: NearfoColors.accent, size: 20),
                      ],
                      if (user?.isPremium == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: NearfoColors.secondaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(context.l10n.profilePro, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('@${user?.handle ?? '...'}', style: TextStyle(color: NearfoColors.textMuted, fontSize: 15)),

                  // 👑 Owner + Premium badges row
                  if (NearfoAdmin.isOwner(user?.handle, phone: user?.phone)) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            gradient: LinearGradient(
                              colors: [NearfoColors.gold.withOpacity(0.15), NearfoColors.gold.withOpacity(0.05)],
                            ),
                            border: Border.all(color: NearfoColors.gold.withOpacity(0.2)),
                          ),
                          child: Text(
                            context.l10n.profileOwner,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NearfoColors.gold),
                          ),
                        ),
                        if (user?.isPremium == true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9999),
                              color: NearfoColors.primary.withOpacity(0.15),
                            ),
                            child: Text(
                              context.l10n.profilePremium,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NearfoColors.primaryLight),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  if ((user?.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(user!.bio!, style: TextStyle(color: NearfoColors.textMuted, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 14, color: NearfoColors.accent),
                      const SizedBox(width: 4),
                      Text(user?.displayLocation ?? '...', style: TextStyle(color: NearfoColors.accent, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statColumn('${user?.postsCount ?? 0}', context.l10n.profilePosts),
                      Container(width: 1, height: 30, color: NearfoColors.border),
                      GestureDetector(
                        onTap: () {
                          if (user != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowersFollowingScreen(
                                userId: user.id,
                                userName: user.name,
                                initialTab: 0,
                              ),
                            ));
                          }
                        },
                        child: _statColumn('${user?.followers ?? 0}', context.l10n.profileFollowers),
                      ),
                      Container(width: 1, height: 30, color: NearfoColors.border),
                      GestureDetector(
                        onTap: () {
                          if (user != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowersFollowingScreen(
                                userId: user.id,
                                userName: user.name,
                                initialTab: 1,
                              ),
                            ));
                          }
                        },
                        child: _statColumn('${user?.following ?? 0}', context.l10n.profileFollowing),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nearfo Score
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, NearfoRoutes.nearfoScore),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [NearfoColors.primary.withOpacity(0.15), NearfoColors.accent.withOpacity(0.15)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: NearfoColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: NearfoColors.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                '${user?.nearfoScore ?? 0}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.profileNearfoScore, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(context.l10n.profileNearfoScoreDesc, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: NearfoColors.textDim, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, NearfoRoutes.editProfile),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: NearfoColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(context.l10n.profileEditProfile, style: TextStyle(color: NearfoColors.primaryLight, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Story Highlights
                  if (user != null) HighlightsRow(userId: user.id, isOwner: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu Items
            _menuItem(context, Icons.bookmark_rounded, context.l10n.profileSavedPosts, NearfoColors.warning, NearfoRoutes.savedPosts),
            _menuItem(context, Icons.video_library_rounded, context.l10n.profileSavedReels, NearfoColors.accent, NearfoRoutes.savedReels),
            _menuItem(context, Icons.analytics_rounded, context.l10n.profileAnalytics, NearfoColors.primaryLight, NearfoRoutes.analytics),
            _menuItem(context, Icons.people_rounded, context.l10n.profileMyCircle, NearfoColors.success, NearfoRoutes.myCircle),
            _menuItem(context, Icons.star_rounded, context.l10n.profileGoPremium, NearfoColors.pink, NearfoRoutes.premium),
            if (NearfoAdmin.isOwner(user?.handle, phone: user?.phone)) ...[
              _menuItem(context, Icons.monetization_on_rounded, context.l10n.profileEarningsDashboard, const Color(0xFF00E676), NearfoRoutes.monetization),
              _menuItem(context, Icons.admin_panel_settings_rounded, context.l10n.profileAdminPanel, const Color(0xFFFF5252), NearfoRoutes.adminPanel),
            ],
            const SizedBox(height: 12),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, NearfoRoutes.login, (r) => false);
                    }
                  },
                  child: Text(context.l10n.profileSignOut, style: TextStyle(color: NearfoColors.danger, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
      ],
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, Color color, String route) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NearfoColors.border),
      ),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, route),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        trailing: Icon(Icons.arrow_forward_ios, color: NearfoColors.textDim, size: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
