import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/giphy_service.dart';
import '../utils/constants.dart';
import '../l10n/l10n_helper.dart';

/// Messenger-style GIF picker with search and trending grid
class GifPicker extends StatefulWidget {
  final Color themeColor;
  final void Function(GiphyGif gif) onGifSelected;

  const GifPicker({
    super.key,
    required this.themeColor,
    required this.onGifSelected,
  });

  @override
  State<GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<GifPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<GiphyGif> _gifs = [];
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    final gifs = await GiphyService.fetchTrending();
    if (mounted) setState(() { _gifs = gifs; _isLoading = false; });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isLoading = true);
      final gifs = query.isEmpty
          ? await GiphyService.fetchTrending()
          : await GiphyService.search(query);
      if (mounted) setState(() { _gifs = gifs; _isLoading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: NearfoColors.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NearfoColors.border.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(Icons.search_rounded, color: NearfoColors.textDim, size: 18),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: NearfoColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: context.l10n.gifSearchHint,
                      hintStyle: TextStyle(color: NearfoColors.textDim, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.close_rounded, color: NearfoColors.textDim, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Powered by Giphy
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(context.l10n.gifPoweredBy, style: TextStyle(color: NearfoColors.textDim, fontSize: 10)),
        ),
        // GIF Grid
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: widget.themeColor, strokeWidth: 2))
              : _gifs.isEmpty
                  ? Center(child: Text(context.l10n.gifNoResults, style: TextStyle(color: NearfoColors.textDim, fontSize: 14)))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _gifs.length,
                      itemBuilder: (context, index) {
                        final gif = _gifs[index];
                        return GestureDetector(
                          onTap: () => widget.onGifSelected(gif),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: gif.previewUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: NearfoColors.bg,
                                child: Center(child: CircularProgressIndicator(color: widget.themeColor, strokeWidth: 1.5)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: NearfoColors.bg,
                                child: Icon(Icons.gif_rounded, color: NearfoColors.textDim, size: 32),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
