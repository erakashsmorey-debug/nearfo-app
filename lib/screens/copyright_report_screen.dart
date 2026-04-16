import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../l10n/l10n_helper.dart';

/// DMCA Copyright Infringement Report Screen
/// Allows any user to submit a copyright takedown request.
class CopyrightReportScreen extends StatefulWidget {
  const CopyrightReportScreen({super.key});

  @override
  State<CopyrightReportScreen> createState() => _CopyrightReportScreenState();
}

class _CopyrightReportScreenState extends State<CopyrightReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contentIdController = TextEditingController();
  final _originalUrlController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _contentType = 'post';
  bool _swornStatement = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contentIdController.dispose();
    _originalUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_swornStatement) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.mustConfirmStatement), backgroundColor: NearfoColors.danger),
      );
      return;
    }

    setState(() => _submitting = true);
    final res = await ApiService.submitTakedown(
      complainantName: _nameController.text.trim(),
      complainantEmail: _emailController.text.trim(),
      contentType: _contentType,
      contentId: _contentIdController.text.trim(),
      description: _descriptionController.text.trim(),
      originalWorkUrl: _originalUrlController.text.trim(),
      swornStatement: _swornStatement,
    );
    setState(() => _submitting = false);

    if (res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dmcaSubmitted), backgroundColor: NearfoColors.success),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Failed to submit'), backgroundColor: NearfoColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        title: Text(context.l10n.copyrightTitle, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: NearfoColors.text), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.copyrightDesc,
                style: TextStyle(color: NearfoColors.textMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),

              _buildField(context.l10n.yourNameLabel, _nameController, context.l10n.nameHint),
              _buildField(context.l10n.yourEmailLabel, _emailController, context.l10n.emailHint, type: TextInputType.emailAddress),

              // Content Type dropdown
              Text(context.l10n.contentTypeLabel, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: NearfoColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NearfoColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _contentType,
                    isExpanded: true,
                    dropdownColor: NearfoColors.card,
                    style: TextStyle(color: NearfoColors.text),
                    items: ['post', 'reel', 'story', 'comment', 'avatar']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase(), style: TextStyle(color: NearfoColors.text))))
                        .toList(),
                    onChanged: (v) => setState(() => _contentType = v ?? 'post'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildField(context.l10n.contentIdLabel, _contentIdController, context.l10n.contentIdHint),
              _buildField(context.l10n.originalUrlLabel, _originalUrlController, context.l10n.originalUrlHint, required: false),
              _buildField(context.l10n.descriptionLabel, _descriptionController, context.l10n.descriptionHint, maxLines: 4),

              const SizedBox(height: 16),
              // Sworn statement checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _swornStatement,
                    onChanged: (v) => setState(() => _swornStatement = v ?? false),
                    activeColor: NearfoColors.primary,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _swornStatement = !_swornStatement),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          context.l10n.swornStatement,
                          style: TextStyle(color: NearfoColors.textMuted, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NearfoColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit DMCA Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {int maxLines = 1, bool required = true, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: type,
            style: TextStyle(color: NearfoColors.text),
            validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: NearfoColors.textDim),
              filled: true,
              fillColor: NearfoColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NearfoColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
