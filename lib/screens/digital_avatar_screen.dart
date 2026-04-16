import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../utils/json_helpers.dart';

class DigitalAvatarScreen extends StatefulWidget {
  const DigitalAvatarScreen({super.key});
  @override
  State<DigitalAvatarScreen> createState() => _DigitalAvatarScreenState();
}

class _DigitalAvatarScreenState extends State<DigitalAvatarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ===== Style Avatar State =====
  final List<Map<String, String>> _styles = [
    {'id': 'adventurer', 'name': 'Adventurer', 'icon': '🎭'},
    {'id': 'adventurer-neutral', 'name': 'Neutral', 'icon': '😊'},
    {'id': 'avataaars', 'name': 'Avataaars', 'icon': '🧑'},
    {'id': 'big-ears', 'name': 'Big Ears', 'icon': '🐰'},
    {'id': 'big-ears-neutral', 'name': 'Big Ears Alt', 'icon': '🐻'},
    {'id': 'lorelei', 'name': 'Lorelei', 'icon': '✨'},
    {'id': 'lorelei-neutral', 'name': 'Elegant', 'icon': '💎'},
    {'id': 'notionists', 'name': 'Notionists', 'icon': '✏️'},
    {'id': 'notionists-neutral', 'name': 'Sketch', 'icon': '📝'},
    {'id': 'open-peeps', 'name': 'Open Peeps', 'icon': '🎨'},
    {'id': 'personas', 'name': 'Personas', 'icon': '👤'},
    {'id': 'pixel-art', 'name': 'Pixel Art', 'icon': '👾'},
  ];

  String _selectedStyle = 'adventurer';
  String _selectedSeed = '';
  List<Map<String, String>> _variations = [];
  int _selectedVariationIndex = 0;
  bool _loadingVariations = false;
  bool _settingProfile = false;

  // ===== Photo Avatar State =====
  File? _selectedPhoto;
  String _photoSeed = '';
  List<Map<String, dynamic>> _photoAvatars = [];
  int _selectedPhotoAvatarIndex = -1;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateVariations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===== Style Avatar Methods =====
  Future<void> _generateVariations() async {
    setState(() {
      _loadingVariations = true;
      _selectedVariationIndex = 0;
    });

    final res = await ApiService.generateAvatarVariations(
      style: _selectedStyle,
      count: 12,
    );

    if (res.isSuccess && res.data != null) {
      setState(() {
        _variations = ((res.data!['variations'] as List?) ?? [])
            .where((v) => v is Map && v['seed'] != null && v['previewUrl'] != null)
            .map((v) => {
                  'seed': v['seed'].toString(),
                  'previewUrl': v['previewUrl'].toString(),
                })
            .toList();
        if (_variations.isNotEmpty) {
          _selectedSeed = _variations[0]['seed']!;
        }
        _loadingVariations = false;
      });
    } else {
      // Fallback: generate local variations
      final seeds = List.generate(12, (i) => 'avatar_${_selectedStyle}_$i');
      setState(() {
        _variations = seeds
            .map((s) => {
                  'seed': s,
                  'previewUrl':
                      'https://api.dicebear.com/9.x/$_selectedStyle/png?seed=${Uri.encodeComponent(s)}&size=256',
                })
            .toList();
        if (_variations.isNotEmpty) {
          _selectedSeed = _variations[0]['seed']!;
        }
        _loadingVariations = false;
      });
    }
  }

  void _shuffleVariations() {
    final seeds = List.generate(
        12, (i) => '${DateTime.now().millisecondsSinceEpoch}_$i');
    setState(() {
      _variations = seeds
          .map((s) => {
                'seed': s,
                'previewUrl':
                    'https://api.dicebear.com/9.x/$_selectedStyle/png?seed=${Uri.encodeComponent(s)}&size=256',
              })
          .toList();
      _selectedVariationIndex = 0;
      if (_variations.isNotEmpty) {
        _selectedSeed = _variations[0]['seed']!;
      }
    });
  }

  Future<void> _setAsProfile() async {
    if (_selectedSeed.isEmpty) return;

    setState(() => _settingProfile = true);

    final res = await ApiService.setAvatarAsProfile(
      style: _selectedStyle,
      seed: _selectedSeed,
    );

    setState(() => _settingProfile = false);

    if (!mounted) return;

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avatar set as profile picture!'),
          backgroundColor: NearfoColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Failed to set avatar'),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  String get _selectedPreviewUrl {
    if (_variations.isEmpty) return '';
    return 'https://api.dicebear.com/9.x/$_selectedStyle/png?seed=${Uri.encodeComponent(_selectedSeed)}&size=512';
  }

  // ===== Photo Avatar Methods =====
  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _selectedPhoto = File(picked.path);
      _selectedPhotoAvatarIndex = -1;
    });

    _generatePhotoAvatars();
  }

  void _generatePhotoAvatars() {
    // Use the photo filename + timestamp as a unique seed base
    final baseSeed = _selectedPhoto?.path.split('/').last.split('.').first ??
        'photo_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _photoSeed = baseSeed;
      _photoAvatars = [];
    });

    // Generate avatars in different styles using the same seed (based on photo)
    final avatarStyles = [
      {'style': 'adventurer', 'name': 'Adventurer'},
      {'style': 'adventurer-neutral', 'name': 'Neutral'},
      {'style': 'avataaars', 'name': 'Classic'},
      {'style': 'big-ears', 'name': 'Big Ears'},
      {'style': 'big-ears-neutral', 'name': 'Cute'},
      {'style': 'lorelei', 'name': 'Elegant'},
      {'style': 'lorelei-neutral', 'name': 'Minimal'},
      {'style': 'notionists', 'name': 'Artsy'},
      {'style': 'notionists-neutral', 'name': 'Sketch'},
      {'style': 'open-peeps', 'name': 'Peeps'},
      {'style': 'personas', 'name': 'Persona'},
      {'style': 'pixel-art', 'name': 'Pixel'},
    ];

    setState(() {
      _photoAvatars = avatarStyles.map((s) {
        return {
          'style': s['style']!,
          'name': s['name']!,
          'seed': '${baseSeed}_${s['style']}',
          'previewUrl':
              'https://api.dicebear.com/9.x/${s['style']}/png?seed=${Uri.encodeComponent('${baseSeed}_${s['style']}')}&size=256',
        };
      }).toList();
    });
  }

  Future<void> _setPhotoAvatarAsProfile() async {
    if (_selectedPhotoAvatarIndex < 0 || _selectedPhotoAvatarIndex >= _photoAvatars.length) return;

    setState(() => _uploadingPhoto = true);

    final avatar = _photoAvatars[_selectedPhotoAvatarIndex];
    final res = await ApiService.setAvatarAsProfile(
      style: avatar['style'] as String,
      seed: avatar['seed'] as String,
    );

    setState(() => _uploadingPhoto = false);

    if (!mounted) return;

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avatar set as profile picture!'),
          backgroundColor: NearfoColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Failed to set avatar'),
          backgroundColor: NearfoColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: NearfoColors.text),
        ),
        title: const Text('Digital Avatar',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NearfoColors.primary,
          labelColor: NearfoColors.primary,
          unselectedLabelColor: NearfoColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt_rounded, size: 20), text: 'From Photo'),
            Tab(icon: Icon(Icons.palette_rounded, size: 20), text: 'Style Avatars'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotoTab(),
          _buildStyleTab(),
        ],
      ),
    );
  }

  // ===== PHOTO TAB =====
  Widget _buildPhotoTab() {
    return Column(
      children: [
        // Photo preview + upload area
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NearfoColors.accent.withOpacity(0.1),
                NearfoColors.primary.withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              if (_selectedPhoto == null) ...[
                Icon(Icons.add_a_photo_rounded,
                    size: 60, color: NearfoColors.textDim),
                const SizedBox(height: 12),
                Text(
                  'Upload your photo to create avatar',
                  style: TextStyle(
                    color: NearfoColors.textDim,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _photoButton(
                      Icons.camera_alt_rounded,
                      'Camera',
                      () => _pickPhoto(ImageSource.camera),
                    ),
                    const SizedBox(width: 16),
                    _photoButton(
                      Icons.photo_library_rounded,
                      'Gallery',
                      () => _pickPhoto(ImageSource.gallery),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Original photo
                    Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: NearfoColors.border, width: 2),
                          ),
                          child: ClipOval(
                            child: Image.file(_selectedPhoto!,
                                fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Your Photo',
                            style: TextStyle(
                                color: NearfoColors.textDim, fontSize: 11)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: NearfoColors.accent, size: 28),
                    ),
                    // Selected avatar
                    Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: NearfoColors.primary, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: NearfoColors.primary.withOpacity(0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _selectedPhotoAvatarIndex >= 0 && _selectedPhotoAvatarIndex < _photoAvatars.length
                                ? CachedNetworkImage(
                                    imageUrl: NearfoConfig.resolveMediaUrl(((_photoAvatars[_selectedPhotoAvatarIndex]
                                            ['previewUrl'] as String?) ?? '').toString()),
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: NearfoColors.card,
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: NearfoColors.primary)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: NearfoColors.card,
                                      child: Icon(Icons.face,
                                          size: 40,
                                          color: NearfoColors.textDim),
                                    ),
                                  )
                                : Container(
                                    color: NearfoColors.card,
                                    child: Icon(Icons.face,
                                        size: 40,
                                        color: NearfoColors.textDim),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Your Avatar',
                            style: TextStyle(
                                color: NearfoColors.textDim, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _pickPhoto(ImageSource.gallery),
                  child: Text(
                    'Change Photo',
                    style: TextStyle(
                      color: NearfoColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (_selectedPhoto != null && _photoAvatars.isNotEmpty) ...[
          // Section label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 18, color: NearfoColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Choose Your Style',
                  style: TextStyle(
                    color: NearfoColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _generatePhotoAvatars,
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 16, color: NearfoColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          color: NearfoColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Avatar grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: _photoAvatars.length,
              itemBuilder: (context, index) {
                final avatar = _photoAvatars[index];
                final isSelected = index == _selectedPhotoAvatarIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedPhotoAvatarIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: NearfoColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? NearfoColors.primary
                            : NearfoColors.border,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    NearfoColors.primary.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14)),
                            child: CachedNetworkImage(
                              imageUrl: NearfoConfig.resolveMediaUrl(avatar['previewUrl'] as String),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) => Container(
                                color: NearfoColors.card,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: NearfoColors.primaryLight,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: NearfoColors.card,
                                child: Icon(Icons.broken_image,
                                    color: NearfoColors.textDim),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            avatar['name'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? NearfoColors.primary
                                  : NearfoColors.textMuted,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else if (_selectedPhoto == null) ...[
          // Empty state
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.face_retouching_natural,
                      size: 64, color: NearfoColors.textDim.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Upload a photo to see avatar styles',
                    style: TextStyle(color: NearfoColors.textDim, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Set as profile button
        if (_selectedPhotoAvatarIndex >= 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ElevatedButton(
              onPressed: _uploadingPhoto ? null : _setPhotoAvatarAsProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: NearfoColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _uploadingPhoto
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Use as Profile Picture',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  Widget _photoButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: NearfoColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NearfoColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: NearfoColors.accent, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: NearfoColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ===== STYLE TAB =====
  Widget _buildStyleTab() {
    return Column(
      children: [
        // Preview Area
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NearfoColors.primary.withOpacity(0.1),
                NearfoColors.accent.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Large avatar preview
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: NearfoColors.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: NearfoColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _selectedPreviewUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: NearfoConfig.resolveMediaUrl(_selectedPreviewUrl),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: NearfoColors.card,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: NearfoColors.primary,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: NearfoColors.card,
                            child: Icon(Icons.face,
                                size: 60, color: NearfoColors.textDim),
                          ),
                        )
                      : Container(
                          color: NearfoColors.card,
                          child: Icon(Icons.face,
                              size: 60, color: NearfoColors.textDim),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (_styles
                    .firstWhere((s) => s['id'] == _selectedStyle, orElse: () => _styles.first)['name']) ?? 'Style',
                style: TextStyle(
                  color: NearfoColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a style or variation below to customize',
                style: TextStyle(
                  color: NearfoColors.textDim,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Style Selector
        Container(
          height: 48,
          margin: const EdgeInsets.only(top: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _styles.length,
            itemBuilder: (context, index) {
              final style = _styles[index];
              final isSelected = style['id'] == _selectedStyle;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStyle = style['id']!);
                  _generateVariations();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NearfoColors.primary
                        : NearfoColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? NearfoColors.primary
                          : NearfoColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(style['icon']!,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        style['name']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : NearfoColors.textMuted,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Section label with Shuffle button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.grid_view_rounded,
                  size: 18, color: NearfoColors.accent),
              const SizedBox(width: 8),
              Text(
                'Variations',
                style: TextStyle(
                  color: NearfoColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _shuffleVariations,
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 16, color: NearfoColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Shuffle',
                      style: TextStyle(
                        color: NearfoColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Random Seed Input Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NearfoColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NearfoColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.tag_rounded, size: 18, color: NearfoColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          _selectedSeed = value.trim();
                        });
                      }
                    },
                    style: TextStyle(color: NearfoColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter a name or custom seed...',
                      hintStyle: TextStyle(color: NearfoColors.textDim, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Variations Grid
        Expanded(
          child: _loadingVariations
              ? Center(
                  child: CircularProgressIndicator(
                      color: NearfoColors.primary))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _variations.length,
                  itemBuilder: (context, index) {
                    final variation = _variations[index];
                    final isSelected = index == _selectedVariationIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedVariationIndex = index;
                          _selectedSeed = variation['seed']!;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? NearfoColors.primary
                                : NearfoColors.border,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: NearfoColors.primary
                                        .withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              isSelected ? 13 : 15),
                          child: CachedNetworkImage(
                            imageUrl: NearfoConfig.resolveMediaUrl(variation['previewUrl']!),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: NearfoColors.card,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        NearfoColors.primaryLight,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: NearfoColors.card,
                              child: Icon(Icons.broken_image,
                                  color: NearfoColors.textDim),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Set as Profile Button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ElevatedButton(
            onPressed: _settingProfile ? null : _setAsProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: NearfoColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _settingProfile
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Use as Profile Picture',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
