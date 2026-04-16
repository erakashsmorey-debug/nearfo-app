import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Giphy API service for fetching trending and search GIFs
class GiphyService {
  // Giphy API key (registered at developers.giphy.com for Nearfo)
  static const String _apiKey = 'JBkFNApFZesuJodBdOeKQlbPzPoXZzec';
  static const String _baseUrl = 'https://api.giphy.com/v1/gifs';
  static const int _limit = 30;

  /// Fetch trending GIFs
  static Future<List<GiphyGif>> fetchTrending({int offset = 0}) async {
    try {
      final url = Uri.parse('$_baseUrl/trending?api_key=$_apiKey&limit=$_limit&offset=$offset&rating=pg-13');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> gifs = data['data'] ?? [];
        return gifs.map((g) => GiphyGif.fromJson(g)).toList();
      }
    } catch (e) {
      debugPrint('[Giphy] Trending fetch error: $e');
    }
    return [];
  }

  /// Search GIFs by query
  static Future<List<GiphyGif>> search(String query, {int offset = 0}) async {
    if (query.trim().isEmpty) return fetchTrending(offset: offset);
    try {
      final url = Uri.parse('$_baseUrl/search?api_key=$_apiKey&q=${Uri.encodeComponent(query)}&limit=$_limit&offset=$offset&rating=pg-13');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> gifs = data['data'] ?? [];
        return gifs.map((g) => GiphyGif.fromJson(g)).toList();
      }
    } catch (e) {
      debugPrint('[Giphy] Search error: $e');
    }
    return [];
  }
}

/// Giphy GIF model
class GiphyGif {
  final String id;
  final String title;
  final String previewUrl;    // Small preview for grid
  final String originalUrl;   // Full size for sending
  final double aspectRatio;

  GiphyGif({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.originalUrl,
    required this.aspectRatio,
  });

  factory GiphyGif.fromJson(Map<String, dynamic> json) {
    final images = json['images'] ?? {};
    final preview = images['fixed_width_small'] ?? images['fixed_width'] ?? {};
    final original = images['original'] ?? images['fixed_width'] ?? {};

    final width = double.tryParse('${preview['width'] ?? '200'}') ?? 200;
    final height = double.tryParse('${preview['height'] ?? '200'}') ?? 200;

    return GiphyGif(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      previewUrl: preview['url']?.toString() ?? '',
      originalUrl: original['url']?.toString() ?? '',
      aspectRatio: height > 0 ? width / height : 1.0,
    );
  }
}
