import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../l10n/l10n_helper.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});
  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isGettingLocation = false;
  String _city = '';
  String _state = '';
  double _lat = 0;
  double _lng = 0;
  bool _locationDone = false;
  DateTime? _dateOfBirth;
  bool _showDobOnProfile = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      _lat = pos.latitude;
      _lng = pos.longitude;
      // Reverse geocode with Nominatim
      try {
        final geoRes = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&accept-language=en',
        ), headers: {'User-Agent': 'Nearfo/1.0'});
        if (geoRes.statusCode == 200) {
          final geoData = (jsonDecode(geoRes.body) as Map<String, dynamic>);
          final address = ((geoData['address'] as Map<String, dynamic>?) ?? {});
          _city = (((address['city'] as String?) ?? (address['town'] as String?)) ?? ((address['village'] as String?) ?? (address['suburb'] as String?))) ?? '';
          _state = (((address['state'] as String?) ?? (address['region'] as String?)) ?? '');
        }
      } catch (_) {
        // Fallback: leave city/state empty, user can fill in later
      }
      _locationDone = true;
    }
    setState(() => _isGettingLocation = false);
  }

  void _submit() async {
    final name = _nameController.text.trim();
    final handle = _handleController.text.trim().toLowerCase();

    if (name.isEmpty) {
      _showError(context.l10n.setupErrorNameRequired);
      return;
    }
    if (handle.isEmpty || handle.length < 3) {
      _showError(context.l10n.setupErrorHandleLength);
      return;
    }
    if (!_locationDone) {
      _showError(context.l10n.setupErrorLocationAccess);
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.setupProfile(
      name: name,
      handle: handle,
      bio: _bioController.text.trim(),
      latitude: _lat,
      longitude: _lng,
      city: _city,
      state: _state,
      dateOfBirth: _dateOfBirth,
      showDobOnProfile: _showDobOnProfile,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, NearfoRoutes.home, (r) => false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: NearfoColors.danger),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (bounds) => NearfoColors.primaryGradient.createShader(bounds),
                child: Text(context.l10n.setupTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text(context.l10n.setupSubtitle,
                style: TextStyle(color: NearfoColors.textMuted, fontSize: 15, height: 1.5)),
              SizedBox(height: 32),

              // Avatar placeholder
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: NearfoColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 48, color: Colors.white),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
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
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Name
              _buildLabel(context.l10n.setupLabelFullName),
              _buildInput(_nameController, context.l10n.setupHintName, maxLength: 50),
              const SizedBox(height: 20),

              // Handle
              _buildLabel(context.l10n.setupLabelUsername),
              _buildInput(_handleController, context.l10n.setupHintUsername, maxLength: 30, prefix: '@'),
              const SizedBox(height: 20),

              // Bio
              _buildLabel(context.l10n.setupLabelBio),
              _buildInput(_bioController, context.l10n.setupHintBio, maxLength: 150, maxLines: 3),
              const SizedBox(height: 20),

              // Date of Birth
              _buildLabel(context.l10n.setupLabelDOB),
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NearfoColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _dateOfBirth != null ? NearfoColors.primary : NearfoColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, color: _dateOfBirth != null ? NearfoColors.primary : NearfoColors.textDim, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        _dateOfBirth != null
                            ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                            : context.l10n.setupHintDOB,
                        style: TextStyle(
                          color: _dateOfBirth != null ? NearfoColors.text : NearfoColors.textDim,
                          fontSize: 16,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.calendar_today, size: 18, color: NearfoColors.textDim),
                    ],
                  ),
                ),
              ),
              if (_dateOfBirth != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 44, height: 26,
                      child: Switch(
                        value: _showDobOnProfile,
                        onChanged: (v) => setState(() => _showDobOnProfile = v),
                        activeColor: NearfoColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(context.l10n.setupShowDOB, style: TextStyle(color: NearfoColors.textMuted, fontSize: 13)),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Location
              _buildLabel(context.l10n.setupLabelLocation),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NearfoColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _locationDone ? NearfoColors.success.withOpacity(0.5) : NearfoColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _locationDone ? Icons.check_circle : Icons.location_on,
                      color: _locationDone ? NearfoColors.success : NearfoColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _isGettingLocation
                          ? Text(context.l10n.setupGettingLocation, style: TextStyle(color: NearfoColors.textMuted))
                          : Text(
                              _locationDone ? '$_city, $_state' : context.l10n.setupLocationPlaceholder,
                              style: TextStyle(color: _locationDone ? NearfoColors.text : NearfoColors.textMuted),
                            ),
                    ),
                    if (!_locationDone && !_isGettingLocation)
                      GestureDetector(
                        onTap: _getLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: NearfoColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(context.l10n.setupLocationEnable, style: TextStyle(color: NearfoColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (_isGettingLocation)
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.setupLocationHint,
                style: TextStyle(color: NearfoColors.textDim, fontSize: 12),
              ),
              const SizedBox(height: 32),

              // Error
              if (auth.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: NearfoColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(auth.error!, style: TextStyle(color: NearfoColors.danger, fontSize: 13)),
                ),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: NearfoColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: auth.isLoading
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(context.l10n.setupSubmit, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: NearfoColors.textMuted)),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {int maxLength = 100, int maxLines = 1, String? prefix}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: NearfoColors.textDim),
        prefixText: prefix,
        prefixStyle: TextStyle(color: NearfoColors.textMuted, fontSize: 16),
        counterText: '',
        filled: true,
        fillColor: NearfoColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: NearfoColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
