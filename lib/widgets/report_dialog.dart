import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/l10n_helper.dart';

class ReportDialog extends StatefulWidget {
  final String contentType; // 'post', 'reel', 'story', 'comment', 'user'
  final String contentId;

  const ReportDialog({super.key, required this.contentType, required this.contentId});

  static Future<void> show(BuildContext context, {required String contentType, required String contentId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ReportDialog(contentType: contentType, contentId: contentId),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final _descController = TextEditingController();
  bool _submitting = false;

  final _reasons = [
    {'value': 'spam', 'label': 'Spam', 'icon': Icons.report_gmailerrorred},
    {'value': 'harassment', 'label': 'Harassment or Bullying', 'icon': Icons.person_off},
    {'value': 'hate_speech', 'label': 'Hate Speech', 'icon': Icons.speaker_notes_off},
    {'value': 'violence', 'label': 'Violence or Threats', 'icon': Icons.warning_amber},
    {'value': 'nudity', 'label': 'Nudity or Sexual Content', 'icon': Icons.no_adult_content},
    {'value': 'false_info', 'label': 'False Information', 'icon': Icons.info_outline},
    {'value': 'scam', 'label': 'Scam or Fraud', 'icon': Icons.money_off},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _submitting = true);
    final res = await ApiService.reportContent(
      contentType: widget.contentType,
      contentId: widget.contentId,
      reason: _selectedReason!,
      description: _descController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.isSuccess ? context.l10n.reportSubmitted : (res.errorMessage ?? context.l10n.reportFailed)),
      backgroundColor: res.isSuccess ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(context.l10n.reportTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(context.l10n.reportWhyReporting(widget.contentType), style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._reasons.map((r) => RadioListTile<String>(
                    value: r['value'] as String,
                    groupValue: _selectedReason,
                    onChanged: (v) => setState(() => _selectedReason = v),
                    title: Text(r['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    secondary: Icon(r['icon'] as IconData, color: Colors.grey[400], size: 20),
                    activeColor: Colors.deepPurpleAccent,
                    dense: true,
                  )),
                  if (_selectedReason != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _descController,
                        maxLines: 3,
                        maxLength: 500,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: context.l10n.reportAddDetails,
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[850],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          counterStyle: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedReason != null && !_submitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.grey[800],
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.l10n.reportSubmit, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }
}
