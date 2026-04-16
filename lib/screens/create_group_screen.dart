import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/json_helpers.dart';
import 'chat_detail_screen.dart';
import '../l10n/l10n_helper.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _selectedIds = {};
  final Map<String, Map<String, dynamic>> _selectedUsers = {};
  bool _searching = false;
  bool _creating = false;

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final res = await ApiService.searchUsers(query);
    if (mounted) {
      setState(() {
        _searching = false;
        _searchResults = res.isSuccess ? (res.data ?? []) : [];
      });
    }
  }

  void _toggleUser(Map<String, dynamic> user) {
    final id = user.asString('_id', '');
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedUsers.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedUsers[id] = user;
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.createGroupNameRequired), backgroundColor: Colors.red));
      return;
    }
    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.createGroupMinMembers), backgroundColor: Colors.red));
      return;
    }
    setState(() => _creating = true);
    final res = await ApiService.createGroupChat(
      participantIds: _selectedIds.toList(),
      groupName: name,
      groupDescription: _descController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (res.isSuccess && res.data != null) {
      final chat = res.data!;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          recipientName: chat.asString('groupName', name),
          recipientId: '',
          existingChatId: chat.asString('_id', ''),
          isGroup: true,
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.errorMessage ?? context.l10n.createGroupFailed), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(context.l10n.createGroupTitle, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _creating ? null : _createGroup,
            child: _creating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent))
                : Text(context.l10n.createGroupCreateButton, style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group name & desc
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n.createGroupNameHint,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.group, color: Colors.deepPurpleAccent),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n.createGroupDescriptionHint,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.info_outline, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          // Selected members chips
          if (_selectedUsers.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _selectedUsers.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundImage: e.value.asStringOrNull('avatarUrl') != null ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(e.value.asStringOrNull('avatarUrl')!)) : null,
                      child: e.value.asStringOrNull('avatarUrl') == null ? const Icon(Icons.person, size: 14) : null,
                    ),
                    label: Text(e.value.asString('name', ''), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: Colors.grey[800],
                    deleteIconColor: Colors.grey[400],
                    onDeleted: () => _toggleUser(e.value),
                  ),
                )).toList(),
              ),
            ),
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: context.l10n.createGroupSearchPeople,
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
            ),
          ),
          // Search results
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final id = user.asString('_id', '');
                final isSelected = _selectedIds.contains(id);
                final avatarUrl = user.asStringOrNull('avatarUrl');
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (avatarUrl ?? '').isNotEmpty ? CachedNetworkImageProvider(NearfoConfig.resolveMediaUrl(avatarUrl!)) : null,
                    backgroundColor: Colors.grey[800],
                    child: (avatarUrl ?? '').isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  title: Text(user.asString('name', ''), style: const TextStyle(color: Colors.white)),
                  subtitle: Text('@${user.asString('handle', '')}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  trailing: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? Colors.deepPurpleAccent : Colors.grey[600]),
                  onTap: () => _toggleUser(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
