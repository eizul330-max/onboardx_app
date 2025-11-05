// document_services.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Internal cache entry class for folder/file caching
class _CacheEntry {
  final List<Map<String, dynamic>> data;
  DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();
}

class DocumentService {
  static const String _baseUrl = 'http://10.111.132.36:4000/api';

  static const int _maxCacheEntries = 8;
  static const Duration _cacheTTL = Duration(seconds: 30);

  final Map<String, _CacheEntry> _cache = {};
  final List<String> _lruOrder = [];

  bool _isExpired(String key) {
    final entry = _cache[key];
    if (entry == null) return true;
    return DateTime.now().difference(entry.timestamp) > _cacheTTL;
  }

  void _touch(String key) {
    _lruOrder.remove(key);
    _lruOrder.insert(0, key);
  }

  void _evictIfNeeded() {
    while (_lruOrder.length > _maxCacheEntries) {
      final oldestKey = _lruOrder.removeLast();
      _cache.remove(oldestKey);
    }
  }

  void _invalidateCache(String uid, String? parentId) {
    final cacheKey = '${uid}_${parentId ?? "root"}';
    _cache.remove(cacheKey);
    _lruOrder.remove(cacheKey);
  }

  void clearCache() {
    _cache.clear();
    _lruOrder.clear();
  }

  /* =====================================================
     📁 Fetch Folder Contents
  ====================================================== */
  Future<List<Map<String, dynamic>>> fetchFolderContents(String uid, {String? parentId}) async {
    final effectiveParentId = parentId ?? await _getRootFolderId(uid);
    final cacheKey = '${uid}_${effectiveParentId ?? "root"}';

    // Use cache if valid
    if (_cache.containsKey(cacheKey) && !_isExpired(cacheKey)) {
      print('📦 Using cached data for $cacheKey');
      _touch(cacheKey);
      _silentRefresh(uid, effectiveParentId, cacheKey);
      return _cache[cacheKey]!.data;
    }

    // Otherwise fetch fresh
    final combined = await _fetchAndCombine(uid, effectiveParentId);
    _cache[cacheKey] = _CacheEntry(combined);
    _touch(cacheKey);
    _evictIfNeeded();
    return combined;
  }

  void _silentRefresh(String uid, String? parentId, String cacheKey) async {
    try {
      final combined = await _fetchAndCombine(uid, parentId);
      _cache[cacheKey] = _CacheEntry(combined);
      print('🔄 Cache silently refreshed for $cacheKey');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchAndCombine(String uid, String? parentId) async {
    final queryParams = {
      'uid': uid,
      if (parentId != null) 'parent_folder_id': parentId,
    };

    final foldersUri = Uri.parse('$_baseUrl/folders').replace(queryParameters: queryParams);
    final filesUri = Uri.parse('$_baseUrl/files').replace(queryParameters: queryParams);

    final responses = await Future.wait([
      http.get(foldersUri),
      http.get(filesUri),
    ]);

    if (responses[0].statusCode != 200) {
      throw Exception('Failed to fetch folders: ${responses[0].statusCode}');
    }

    final List folders = jsonDecode(responses[0].body);
    final List files;
    if (responses[1].statusCode == 200) {
      files = jsonDecode(responses[1].body);
    } else if (responses[1].statusCode == 404) {
      files = [];
    } else {
      throw Exception('Failed to fetch files: ${responses[1].statusCode}');
    }

    List<Map<String, dynamic>> safeFolders = folders
        .map((f) => Map<String, dynamic>.from(f))
        .map((f) => {...f, 'type': 'folder'})
        .toList();

    List<Map<String, dynamic>> safeFiles = files
        .map((f) => Map<String, dynamic>.from(f))
        .map((f) => {...f, 'type': 'file'})
        .toList();

    return [...safeFolders, ...safeFiles];
  }

  /* =====================================================
     📤 Upload File
  ====================================================== */
  Future<void> uploadDocument(File file, String uid, {String? folderId}) async {
    final targetFolderId = folderId ?? await _getRootFolderId(uid);
    final uri = Uri.parse('$_baseUrl/files/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['uid'] = uid
      ..fields['folder_id'] = targetFolderId ?? '';

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 201) {
      _invalidateCache(uid, targetFolderId);
    } else {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     📁 Create Folder
  ====================================================== */
  Future<void> createFolder(String name, String uid, {String? parentId}) async {
    final targetParentId = parentId ?? await _getRootFolderId(uid);
    final uri = Uri.parse('$_baseUrl/folders');
    final body = {
      'name': name,
      'uid': uid,
      if (targetParentId != null) 'parent_folder_id': targetParentId,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      _invalidateCache(uid, targetParentId);
    } else {
      throw Exception('Failed to create folder: ${response.statusCode}');
    }
  }

  /* =====================================================
     📥 Download File
  ====================================================== */
  Future<Uint8List> downloadDocument(String fileId, String uid) async {
    final uri = Uri.parse('$_baseUrl/files/$fileId/download?uid=$uid');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Download failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     🗑️ Delete Item
  ====================================================== */
  Future<void> deleteItem(String id, String uid, String type, {String? parentId}) async {
    if (type != 'file' && type != 'folder') {
      throw ArgumentError('Invalid item type: $type');
    }

    final endpoint = type == 'file' ? 'files' : 'folders';
    final uri = Uri.parse('$_baseUrl/$endpoint/$id?uid=$uid');
    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      _invalidateCache(uid, parentId);
    } else {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     🌱 Root Folder Handling
  ====================================================== */
  Future<String?> _getRootFolderId(String uid) async {
    try {
      final uri = Uri.parse('$_baseUrl/folders/root/$uid');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        return data['_id'];
      } else if (response.statusCode == 404) {
        print('🪴 No root folder found, creating new one for UID: $uid');
        return await _createRootFolder(uid);
      } else {
        throw Exception('Failed to get root folder ID: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error fetching root folder ID: $e');
      return null;
    }
  }

  Future<String?> _createRootFolder(String uid) async {
    final uri = Uri.parse('$_baseUrl/folders/root');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': uid}),
    );

    if (response.statusCode == 201) {
      final data = Map<String, dynamic>.from(jsonDecode(response.body));
      return data['_id'];
    } else {
      throw Exception('Failed to create root folder: ${response.statusCode}');
    }
  }
}
