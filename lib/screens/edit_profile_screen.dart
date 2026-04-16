import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import '../utils/image_compressor.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'digital_avatar_screen.dart';
import '../l10n/l10n_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _bioController;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  DateTime? _dateOfBirth;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _handleController = TextEditingController(text: user?.handle ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _dateOfBirth = user?.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: NearfoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.editProfileChangePhoto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.camera_alt, color: NearfoColors.primary),
                title: Text(context.l10n.editProfileTakePhoto),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: NearfoColors.accent),
                title: Text(context.l10n.editProfileChooseGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.face_retouching_natural, color: NearfoColors.pink),
                title: Text(context.l10n.editProfileCreateDigitalAvatar),
                subtitle: Text(context.l10n.editProfileAvatarSubtitle, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDigitalAvatar();
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      // Compress avatar before upload (512px, quality 85)
      final compressedPath = await ImageCompressor.compress(image.path, type: ImageType.avatar);
      final result = await ApiService.uploadAvatar(compressedPath);
      if (result.isSuccess && result.data != null) {
        setState(() {
          _avatarUrl = result.data;
          _isUploadingAvatar = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.editProfilePhotoUpdated), backgroundColor: NearfoColors.success),
          );
        }
      } else {
        setState(() => _isUploadingAvatar = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? context.l10n.editProfileUploadFailed), backgroundColor: NearfoColors.danger),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.editProfileError(error: e.toString())), backgroundColor: NearfoColors.danger),
        );
      }
    }
  }

  Future<void> _openDigitalAvatar() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DigitalAvatarScreen()),
    );
    if (result == true && mounted) {
      // Avatar was set, refresh profile
      final auth = context.read<AuthProvider>();
      await auth.init();
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    final success = await auth.setupProfile(
      name: _nameController.text.trim(),
      handle: _handleController.text.trim(),
      bio: _bioController.text.trim(),
      latitude: user.latitude,
      longitude: user.longitude,
      city: user.city,
      state: user.state,
      dateOfBirth: _dateOfBirth,
      showDobOnProfile: user.showDobOnProfile,
      avatarUrl: _avatarUrl ?? user.avatarUrl,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.editProfileUpdated),
          backgroundColor: NearfoColors.success,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? context.l10n.editProfileUpdateFailed),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: NearfoColors.text),
        ),
        title: Text(context.l10n.editProfileTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(context.l10n.save, style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      gradient: NearfoColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: NearfoColors.primary.withOpacity(0.3), blurRadius: 20)],
                    ),
                    child: (_avatarUrl ?? user?.avatarUrl ?? '').isNotEmpty
                        ? ClipOval(child: CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(_avatarUrl ?? user?.avatarUrl ?? ''), fit: BoxFit.cover, width: 100, height: 100,
                            errorWidget: (_, __, ___) => Center(child: Text(user?.initials ?? '?', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)))))
                        : Center(
                            child: Text(
                              user?.initials ?? '?',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                  ),
                  if (_isUploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NearfoColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: NearfoColors.bg, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Digital Avatar button
              TextButton.icon(
                onPressed: _openDigitalAvatar,
                icon: Icon(Icons.face_retouching_natural, size: 18, color: NearfoColors.pink),
                label: Text(
                  context.l10n.editProfileCreateDigitalAvatar,
                  style: TextStyle(color: NearfoColors.pink, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: NearfoColors.pink.withOpacity(0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Name
              _buildTextField(
                controller: _nameController,
                label: context.l10n.editProfileDisplayName,
                icon: Icons.person_outline,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return context.l10n.editProfileNameRequired;
                  if (v.trim().length < 2) return context.l10n.editProfileNameMin;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Handle
              _buildTextField(
                controller: _handleController,
                label: context.l10n.editProfileUsername,
                icon: Icons.alternate_email,
                prefix: '@',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return context.l10n.editProfileUsernameRequired;
                  if (v.trim().length < 3) return context.l10n.editProfileUsernameMin;
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) return context.l10n.editProfileUsernameInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date of Birth
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: NearfoColors.primary,
                          surface: NearfoColors.card,
                          onSurface: NearfoColors.text,
                        ),
                        dialogBackgroundColor: NearfoColors.bg,
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _dateOfBirth = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NearfoColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _dateOfBirth != null ? NearfoColors.primary : NearfoColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, color: _dateOfBirth != null ? NearfoColors.primary : NearfoColors.textDim, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.editProfileDateOfBirth, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              _dateOfBirth != null
                                  ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                  : context.l10n.editProfileTapToSelect,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: _dateOfBirth != null ? NearfoColors.text : NearfoColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.calendar_today, size: 16, color: NearfoColors.textDim),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bio
              _buildTextField(
                controller: _bioController,
                label: context.l10n.editProfileBio,
                icon: Icons.info_outline,
                maxLines: 3,
                maxLength: NearfoConfig.maxBioLength,
                hint: context.l10n.editProfileBioHint,
              ),
              const SizedBox(height: 24),

              // Location info (read-only)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NearfoColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NearfoColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: NearfoColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.location_on, color: NearfoColors.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.editProfileLocation, style: TextStyle(color: NearfoColors.textDim, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            user?.displayLocation ?? context.l10n.editProfileNotSet,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.lock_outline, color: NearfoColors.textDim, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.editProfileLocationAuto,
                style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? prefix,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: NearfoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NearfoColors.border),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        style: TextStyle(color: NearfoColors.text, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: NearfoColors.textDim),
          hintStyle: TextStyle(color: NearfoColors.textDim),
          prefixIcon: Icon(icon, color: NearfoColors.textMuted, size: 22),
          prefixText: prefix,
          prefixStyle: TextStyle(color: NearfoColors.textMuted, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          counterStyle: TextStyle(color: NearfoColors.textDim),
        ),
      ),
    );
  }
}
