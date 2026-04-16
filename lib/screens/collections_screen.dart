import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';
import '../utils/json_helpers.dart';
import '../l10n/l10n_helper.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getCollections();
    if (res.isSuccess && res.data != null && mounted) {
      setState(() { _collections = res.data!; _loading = false; });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createCollection() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.collectionsNewCollection, style: TextStyle(color: NearfoColors.text)),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: NearfoColors.text),
          decoration: InputDecoration(
            hintText: context.l10n.collectionsNameHint,
            hintStyle: TextStyle(color: NearfoColors.textDim),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: NearfoColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: NearfoColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: Text(context.l10n.create, style: TextStyle(color: NearfoColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final res = await ApiService.createCollection(name: result);
      if (res.isSuccess) _load();
    }
  }

  void _deleteCollection(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NearfoColors.card,
        title: Text(context.l10n.collectionsDeleteCollection, style: TextStyle(color: NearfoColors.text)),
        content: Text(context.l10n.collectionsCantUndo, style: TextStyle(color: NearfoColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel, style: TextStyle(color: NearfoColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.delete, style: TextStyle(color: NearfoColors.danger))),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteCollection(id);
      _load();
    }
  }

  void _openCollection(String id, String name) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CollectionDetailScreen(collectionId: id, collectionName: name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        title: Text(context.l10n.collectionsTitle, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: NearfoColors.text), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: NearfoColors.primary),
            onPressed: _createCollection,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _collections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.collections_bookmark_outlined, size: 64, color: NearfoColors.textDim),
                      const SizedBox(height: 12),
                      Text(context.l10n.collectionsNoCollections, style: TextStyle(color: NearfoColors.textMuted, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(context.l10n.collectionsSavePostsHint, style: TextStyle(color: NearfoColors.textDim, fontSize: 13)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _createCollection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NearfoColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(context.l10n.collectionsCreateCollection, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _collections.length,
                    itemBuilder: (context, index) {
                      final c = _collections[index];
                      final name = (c['name'] as String?) ?? 'Untitled';
                      final coverUrl = (c['coverUrl'] as String?) ?? '';
                      final postCount = (c['postCount'] as num?) ?? 0;
                      final id = c['_id']?.toString() ?? '';

                      return GestureDetector(
                        onTap: () => _openCollection(id, name),
                        onLongPress: () => _deleteCollection(id),
                        child: Container(
                          decoration: BoxDecoration(
                            color: NearfoColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: NearfoColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: coverUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: NearfoConfig.resolveMediaUrl(coverUrl),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (_, __) => Container(color: NearfoColors.cardHover),
                                          errorWidget: (_, __, ___) => _emptyCollectionCover(),
                                        )
                                      : _emptyCollectionCover(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(context.l10n.collectionsPosts(postCount.toInt()), style: TextStyle(color: NearfoColors.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyCollectionCover() {
    return Container(
      color: NearfoColors.cardHover,
      child: Center(child: Icon(Icons.collections_bookmark, color: NearfoColors.textDim, size: 36)),
    );
  }
}

class _CollectionDetailScreen extends StatefulWidget {
  final String collectionId;
  final String collectionName;
  const _CollectionDetailScreen({required this.collectionId, required this.collectionName});
  @override
  State<_CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<_CollectionDetailScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final res = await ApiService.getCollectionPosts(widget.collectionId);
    if (mounted) {
      setState(() {
        _posts = res.data ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        elevation: 0,
        title: Text(widget.collectionName, style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: NearfoColors.text), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: NearfoColors.primary))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.collections_bookmark_outlined, size: 48, color: NearfoColors.textDim),
                      const SizedBox(height: 12),
                      Text(context.l10n.collectionsNoPostsInCollection, style: TextStyle(color: NearfoColors.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final images = (post is Map ? (post as Map<String, dynamic>)['images'] as List? : null) ?? [];
                      final imageUrl = images.isNotEmpty ? images[0].toString() : '';
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: NearfoConfig.resolveMediaUrl(imageUrl), fit: BoxFit.cover)
                            : Container(
                                color: NearfoColors.card,
                                child: Center(child: Icon(Icons.article, color: NearfoColors.textDim)),
                              ),
                      );
                    },
                  ),
                ),
    );
  }
}
