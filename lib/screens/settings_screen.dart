import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import 'account_privacy_screen.dart';
import 'blocked_users_screen.dart';
import '../l10n/l10n_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRefreshingLocation = false;
  Future<void> _refreshLocation() async {
    setState(() => _isRefreshingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        await context.read<AuthProvider>().updateLocation(pos.latitude, pos.longitude);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.locationUpdated), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotGetLocation), backgroundColor: NearfoColors.danger, duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.locationError} $e'), backgroundColor: NearfoColors.danger),
        );
      }
    }
    if (mounted) setState(() => _isRefreshingLocation = false);
  }

  void _showFeedPreferencePicker() {
    final auth = context.read<AuthProvider>();
    String selected = auth.user?.feedPreference ?? 'mixed';

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
              ),
              Text(context.l10n.feedPreference, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 4),
              Text(context.l10n.chooseFeedOrganization, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              _feedOption(ctx, setSheetState, 'mixed', context.l10n.mixedFeed, context.l10n.mixedFeedDesc, selected, (val) {
                setSheetState(() => selected = val);
                auth.updateProfile({'feedPreference': val}).then((success) {
                  if (mounted && success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.feedSetMixed), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                    );
                  }
                });
              }),
              _feedOption(ctx, setSheetState, 'nearby', context.l10n.nearbyFirst, context.l10n.nearbyFirstDesc, selected, (val) {
                setSheetState(() => selected = val);
                auth.updateProfile({'feedPreference': val}).then((success) {
                  if (mounted && success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.feedSetNearby), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                    );
                  }
                });
              }),
              _feedOption(ctx, setSheetState, 'trending', context.l10n.trendingFeed, context.l10n.trendingFeedDesc, selected, (val) {
                setSheetState(() => selected = val);
                auth.updateProfile({'feedPreference': val}).then((success) {
                  if (mounted && success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.feedSetTrending), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                    );
                  }
                });
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedOption(BuildContext ctx, StateSetter setSheetState, String value, String label, String desc, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? NearfoColors.primary : NearfoColors.textDim,
      ),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
      subtitle: Text(desc, style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
      onTap: () => onSelect(value),
    );
  }

  void _showThemePicker(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final currentId = themeProvider.currentId;

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
            ),
            Text(context.l10n.settingsChooseTheme, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 4),
            Text(context.l10n.settingsPersonalizeExperience, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: NearfoThemes.all.length,
                itemBuilder: (context, index) {
                  final theme = NearfoThemes.all[index];
                  final isSelected = theme.id == currentId;
                  return GestureDetector(
                    onTap: () {
                      themeProvider.setTheme(theme.id);
                      Navigator.pop(ctx);
                      setState(() {});
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('${context.l10n.theme}: ${theme.name}'),
                          backgroundColor: theme.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: theme.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? theme.primary : NearfoColors.border,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 10)]
                            : null,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(theme.icon, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  theme.name,
                                  style: TextStyle(
                                    color: theme.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: theme.primary, size: 20),
                            ],
                          ),
                          // Color preview dots
                          Row(
                            children: [
                              _colorDot(theme.primary),
                              _colorDot(theme.accent),
                              _colorDot(theme.card),
                              _colorDot(theme.text),
                              _colorDot(theme.pink),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }

  void _showVisibilityPicker() {
    final auth = context.read<AuthProvider>();
    String selected = auth.user?.profileVisibility ?? 'public';

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
              ),
              Text(context.l10n.profileVisibility, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 4),
              Text(context.l10n.whoCanSeeProfile, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              _visibilityOption(ctx, setSheetState, 'public', context.l10n.publicLabel, context.l10n.publicVisDesc, Icons.public, selected, (val) {
                setSheetState(() => selected = val);
                auth.updateProfile({'profileVisibility': val}).then((success) {
                  if (mounted && success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.visibilitySetPublic), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                    );
                  }
                });
              }),
              _visibilityOption(ctx, setSheetState, 'followers', context.l10n.followersOnlyLabel, context.l10n.followersOnlyDesc, Icons.group, selected, (val) {
                setSheetState(() => selected = val);
                auth.updateProfile({'profileVisibility': val}).then((success) {
                  if (mounted && success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.visibilitySetFollowers), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                    );
                  }
                });
              }),
              _visibilityOption(ctx, setSheetState, 'private', context.l10n.privateLabel, context.l10n.privateVisDesc, Icons.lock, selected, (val) {
                setSheetState(() => selected = val);
                auth.updateProfile({'profileVisibility': val}).then((success) {
                  if (mounted && success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.visibilitySetPrivate), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                    );
                  }
                });
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visibilityOption(BuildContext ctx, StateSetter setSheetState, String value, String label, String desc, IconData icon, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? NearfoColors.primary : NearfoColors.textDim),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
      subtitle: Text(desc, style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
      trailing: isSelected ? Icon(Icons.check_circle, color: NearfoColors.primary) : null,
      onTap: () => onSelect(value),
    );
  }

  void _toggleNotifications() async {
    final auth = context.read<AuthProvider>();
    final current = auth.user?.notificationsEnabled ?? true;
    final success = await auth.updateProfile({'notificationsEnabled': !current});
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!current ? context.l10n.notificationsEnabled : context.l10n.notificationsDisabled),
          backgroundColor: NearfoColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAbout() {
    _openUrl('https://api.nearfo.com/about.html');
  }

  void _showEditEmail() {
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController(text: auth.user?.email ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
              ),
              Text(context.l10n.updateEmail, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 4),
              Text(context.l10n.enterNewEmail, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: context.l10n.emailPlaceholder,
                  hintStyle: TextStyle(color: NearfoColors.textDim),
                  prefixIcon: Icon(Icons.email_outlined, color: NearfoColors.textMuted),
                  filled: true,
                  fillColor: NearfoColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final email = controller.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.validEmailRequired), backgroundColor: NearfoColors.danger),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await auth.updateProfile({'email': email});
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.emailUpdated), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NearfoColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(context.l10n.saveEmail, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  void _showEditPhone() {
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController(text: auth.user?.phone ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
              ),
              Text(context.l10n.updatePhone, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 4),
              Text(context.l10n.enterPhoneNumber, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: context.l10n.phonePlaceholder,
                  hintStyle: TextStyle(color: NearfoColors.textDim),
                  prefixIcon: Icon(Icons.phone_outlined, color: NearfoColors.textMuted),
                  filled: true,
                  fillColor: NearfoColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final phone = controller.text.trim();
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.phoneRequired), backgroundColor: NearfoColors.danger),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await auth.updateProfile({'phone': phone});
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.phoneUpdated), backgroundColor: NearfoColors.success, duration: const Duration(seconds: 2)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NearfoColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(context.l10n.savePhone, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenLink), backgroundColor: NearfoColors.danger),
      );
    }
  }

  void _reportBug() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
              ),
              Text(context.l10n.reportBug, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 4),
              Text(context.l10n.helpImproveNearfo, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 5,
                maxLength: 500,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: context.l10n.bugDescription,
                  hintStyle: TextStyle(color: NearfoColors.textDim),
                  filled: true,
                  fillColor: NearfoColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    // TODO: Call ApiService.submitBugReport(controller.text.trim()) when available
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.bugReportSubmitted), backgroundColor: NearfoColors.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NearfoColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(context.l10n.submitReport, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  void _showStoryLocationSettings() {
    final auth = context.read<AuthProvider>();
    bool storyReplies = auth.user?.allowStoryReplies ?? true;
    bool showLocation = auth.user?.showLocationInStory ?? true;
    bool liveNotif = auth.user?.liveNotificationsEnabled ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
                  ),
                  Text(context.l10n.storyLiveLocation, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(context.l10n.controlStoryLocation, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  _toggleOption(
                    Icons.reply_rounded,
                    context.l10n.allowStoryReplies,
                    context.l10n.allowStoryRepliesDesc,
                    storyReplies,
                    (val) {
                      setSheetState(() => storyReplies = val);
                      auth.updateProfile({'allowStoryReplies': val}).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  _toggleOption(
                    Icons.location_on_outlined,
                    context.l10n.showLocationStories,
                    context.l10n.showLocationStoriesDesc,
                    showLocation,
                    (val) {
                      setSheetState(() => showLocation = val);
                      auth.updateProfile({'showLocationInStory': val}).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  _toggleOption(
                    Icons.live_tv_outlined,
                    context.l10n.liveNotifications,
                    context.l10n.liveNotificationsDesc,
                    liveNotif,
                    (val) {
                      setSheetState(() => liveNotif = val);
                      auth.updateProfile({'liveNotificationsEnabled': val}).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showActivitySettings() {
    final auth = context.read<AuthProvider>();
    bool likedPosts = auth.user?.showLikedPosts ?? true;
    bool showComments = auth.user?.showComments ?? true;
    bool newFollows = auth.user?.showNewFollows ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: NearfoColors.textDim, borderRadius: BorderRadius.circular(2)),
                  ),
                  Text(context.l10n.activityFriendsTab, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(context.l10n.controlActivityVisibility, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  _toggleOption(
                    Icons.favorite_border,
                    context.l10n.showLikedPosts,
                    context.l10n.showLikedPostsDesc,
                    likedPosts,
                    (val) {
                      setSheetState(() => likedPosts = val);
                      auth.updateProfile({'showLikedPosts': val}).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  _toggleOption(
                    Icons.comment_outlined,
                    context.l10n.showComments,
                    context.l10n.showCommentsDesc,
                    showComments,
                    (val) {
                      setSheetState(() => showComments = val);
                      auth.updateProfile({'showComments': val}).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  _toggleOption(
                    Icons.person_add_outlined,
                    context.l10n.showNewFollows,
                    context.l10n.showNewFollowsDesc,
                    newFollows,
                    (val) {
                      setSheetState(() => newFollows = val);
                      auth.updateProfile({'showNewFollows': val}).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _toggleOption(IconData icon, String label, String desc, bool value, Function(bool) onToggle) {
    return ListTile(
      leading: Icon(icon, color: NearfoColors.textMuted, size: 22),
      title: Text(label, style: TextStyle(fontSize: 15)),
      subtitle: Text(desc, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onToggle,
        activeColor: NearfoColors.primary,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.deleteAccount, style: TextStyle(fontWeight: FontWeight.w700, color: NearfoColors.danger)),
        content: Text(
          context.l10n.deleteAccountWarning,
          style: TextStyle(color: NearfoColors.text, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancelBtn, style: TextStyle(color: NearfoColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // TODO: Call ApiService.deleteAccount() when available
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.deletionRequestSent), backgroundColor: NearfoColors.danger),
              );
            },
            child: Text(context.l10n.deleteBtn, style: TextStyle(color: NearfoColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: NearfoColors.text),
        ),
        title: Text(context.l10n.settingsTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Account Section
            _sectionHeader(context.l10n.settingsAccount),
            _settingsTile(Icons.person_outline, context.l10n.settingsEditProfile, () => Navigator.pushNamed(context, NearfoRoutes.editProfile)),
            _settingsTile(Icons.phone_outlined, context.l10n.settingsPhone(phone: user?.phone ?? context.l10n.settingsNotSetValue), _showEditPhone),
            _settingsTile(Icons.email_outlined, context.l10n.settingsEmail(email: user?.email ?? context.l10n.settingsNotSetValue), _showEditEmail),

            // Who can see your content
            _sectionHeader(context.l10n.settingsWhoCanSee),
            _settingsTileWithTrailing(
              Icons.lock_outline_rounded,
              context.l10n.settingsAccountPrivacy,
              user?.profileVisibility == 'private' || user?.profileVisibility == 'followers' ? context.l10n.settingsPrivate : context.l10n.settingsPublic,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPrivacyScreen())),
            ),
            _settingsTile(Icons.block_rounded, context.l10n.settingsBlocked, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()))),
            _settingsTile(Icons.location_off_outlined, context.l10n.settingsStoryLiveLocation, _showStoryLocationSettings),
            _settingsTile(Icons.people_outline_rounded, context.l10n.settingsActivityFriends, _showActivitySettings),

            // Preferences
            _sectionHeader(context.l10n.settingsPreferences),
            _settingsTile(Icons.tune_rounded, context.l10n.settingsFeedPreferenceValue(value: user?.feedPreference ?? 'mixed'), _showFeedPreferencePicker),
            _settingsTile(Icons.visibility_outlined, context.l10n.settingsProfileVisibilityValue(value: user?.profileVisibility ?? 'public'), _showVisibilityPicker),
            _settingsTileWithSwitch(
              Icons.notifications_outlined,
              context.l10n.settingsNotifications,
              user?.notificationsEnabled ?? true,
              _toggleNotifications,
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return _settingsTile(
                  Icons.palette_outlined,
                  context.l10n.settingsThemeValue(name: themeProvider.current.name),
                  () => _showThemePicker(context),
                );
              },
            ),
            _settingsTileWithSwitch(
              Icons.cake_outlined,
              context.l10n.settingsShowBirthday,
              user?.showDobOnProfile ?? true,
              (val) async {
                final auth = context.read<AuthProvider>();
                await auth.updateProfile({'showDobOnProfile': val});
              },
            ),
            _settingsTileWithSwitch(
              Icons.people_outline,
              context.l10n.settingsHideFollowersList,
              user?.hideFollowersList ?? false,
              (bool val) async {
                final auth = context.read<AuthProvider>();
                final success = await auth.updateProfile({'hideFollowersList': val});
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? context.l10n.settingsFollowersHidden : context.l10n.settingsFollowersVisible),
                      backgroundColor: NearfoColors.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            _settingsTileWithSwitch(
              Icons.circle,
              context.l10n.settingsShowOnline,
              user?.showOnlineStatus ?? true,
              (bool val) async {
                final auth = context.read<AuthProvider>();
                final success = await auth.updateProfile({'showOnlineStatus': val});
                if (mounted && success) {
                  SocketService.instance.toggleOnlineVisibility(
                    userId: auth.user?.id ?? '',
                    visible: val,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val
                          ? context.l10n.settingsOnlineVisible
                          : context.l10n.settingsOnlineHidden),
                      backgroundColor: NearfoColors.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.settingsOnlineFailed),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            // Location
            _sectionHeader(context.l10n.settingsLocation),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: ListTile(
                leading: Icon(Icons.location_on_outlined, color: NearfoColors.textMuted, size: 22),
                title: Text(user?.displayLocation ?? 'Unknown', style: const TextStyle(fontSize: 15)),
                trailing: _isRefreshingLocation
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: NearfoColors.primary))
                    : Icon(Icons.refresh_rounded, size: 22, color: NearfoColors.primary),
                onTap: _isRefreshingLocation ? null : _refreshLocation,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            _settingsTile(Icons.radar_rounded, context.l10n.settingsRadius(radius: LocationService.nearfoRadiusKm.round().toString()), null, showArrow: false),

            // Owner-only section
            if (NearfoAdmin.isOwner(user?.handle, phone: user?.phone)) ...[
              _sectionHeader(context.l10n.settingsMonetization),
              _settingsTile(Icons.monetization_on_rounded, context.l10n.settingsEarningsDashboard, () => Navigator.pushNamed(context, NearfoRoutes.monetization)),
              _sectionHeader(context.l10n.settingsAdmin),
              _settingsTile(Icons.admin_panel_settings_rounded, context.l10n.settingsAdminPanel, () => Navigator.pushNamed(context, NearfoRoutes.adminPanel)),
              _settingsTile(Icons.gavel_rounded, context.l10n.settingsModeration, () => Navigator.pushNamed(context, '/moderation')),
            ],

            // App
            _sectionHeader(context.l10n.settingsApp),
            _settingsTile(Icons.language, context.l10n.settingsLanguage, () => Navigator.pushNamed(context, '/language')),
            _settingsTile(Icons.info_outline, context.l10n.settingsAbout, _showAbout),
            _settingsTile(Icons.policy_outlined, context.l10n.settingsPrivacyPolicy, () => _openUrl('https://api.nearfo.com/privacy.html')),
            _settingsTile(Icons.description_outlined, context.l10n.settingsTermsOfService, () => _openUrl('https://api.nearfo.com/terms.html')),
            _settingsTile(Icons.copyright_outlined, context.l10n.settingsCopyrightReport, () => Navigator.pushNamed(context, '/copyright-report')),
            _settingsTile(Icons.bug_report_outlined, context.l10n.settingsReportBug, _reportBug),

            const SizedBox(height: 20),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, NearfoRoutes.login, (r) => false);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: NearfoColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(context.l10n.settingsSignOut, style: TextStyle(color: NearfoColors.danger, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Delete Account
            Center(
              child: TextButton(
                onPressed: _showDeleteConfirmation,
                child: Text(context.l10n.settingsDeleteAccount, style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
              ),
            ),

            // Version
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.settingsVersion, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1)),
    );
  }

  Widget _settingsTile(IconData icon, String label, VoidCallback? onTap, {bool showArrow = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: NearfoColors.textMuted, size: 22),
        title: Text(label, style: TextStyle(fontSize: 15)),
        trailing: showArrow && onTap != null ? Icon(Icons.arrow_forward_ios, size: 14, color: NearfoColors.textDim) : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _settingsTileWithTrailing(IconData icon, String label, String trailing, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: NearfoColors.textMuted, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trailing, style: TextStyle(color: NearfoColors.textMuted, fontSize: 14)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 14, color: NearfoColors.textDim),
          ],
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _settingsTileWithSwitch(IconData icon, String label, bool value, Function onToggle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: NearfoColors.textMuted, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 15)),
        trailing: Switch(
          value: value,
          onChanged: (val) {
            if (onToggle is Function(bool)) {
              (onToggle as Function(bool))(val);
            } else {
              onToggle();
            }
          },
          activeColor: NearfoColors.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
