import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../l10n/l10n_helper.dart';

class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({super.key});
  @override
  State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  bool _isSaving = false;

  Future<void> _togglePrivacy(bool makePrivate) async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final newValue = makePrivate ? 'private' : 'public';
    final success = await auth.updateProfile({'profileVisibility': newValue});
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(makePrivate ? context.l10n.accountSetPrivate : context.l10n.accountSetPublic),
            backgroundColor: NearfoColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPrivate = auth.user?.profileVisibility == 'private' || auth.user?.profileVisibility == 'followers';

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.l10n.accountPrivacyTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Privacy toggle card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NearfoColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NearfoColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: NearfoColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.privateAccountLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          isPrivate ? context.l10n.privateAccountDesc : context.l10n.publicAccountDesc,
                          style: TextStyle(color: NearfoColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _isSaving
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: NearfoColors.primary))
                      : Switch(
                          value: isPrivate,
                          onChanged: (val) => _togglePrivacy(val),
                          activeColor: NearfoColors.primary,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info section
            _infoCard(
              Icons.visibility_outlined,
              context.l10n.publicAccountTitle,
              context.l10n.publicAccountInfo,
            ),
            const SizedBox(height: 12),
            _infoCard(
              Icons.visibility_off_outlined,
              context.l10n.privateAccountTitle,
              context.l10n.privateAccountInfo,
            ),
            const SizedBox(height: 12),
            _infoCard(
              Icons.info_outline,
              context.l10n.noteLabel,
              context.l10n.privateAccountNote,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NearfoColors.border.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NearfoColors.textDim, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
