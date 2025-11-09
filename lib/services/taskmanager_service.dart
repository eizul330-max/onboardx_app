// task_manager_services.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Internal cache entry (same idea as DocumentService)
class _CacheEntry {
  final List<Map<String, dynamic>> data;
  DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();
}

class TaskManagerService {
  static const String _baseUrl = 'http://10.111.132.36:4000/api/task_manager';
  static const int _maxCacheEntries = 6;
  static const Duration _cacheTTL = Duration(seconds: 30);

  final Map<String, _CacheEntry> _cache = {};
  final List<String> _lruOrder = [];

  /* =====================================================
     🧠 Utility Functions (cache mgmt)
  ====================================================== */
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

  void _invalidateCache(String uid) {
    _cache.remove(uid);
    _lruOrder.remove(uid);
  }

  void clearCache() {
    _cache.clear();
    _lruOrder.clear();
  }

  /* =====================================================
     📥 Fetch Task Manager Files
  ====================================================== */
  Future<List<Map<String, dynamic>>> fetchUserTasks(String uid) async {
    final cacheKey = uid;

    // ✅ Use cache if fresh
    if (_cache.containsKey(cacheKey) && !_isExpired(cacheKey)) {
      print('📦 Using cached task data for $uid');
      _touch(cacheKey);
      _silentRefresh(uid);
      return _cache[cacheKey]!.data;
    }

    // 🚀 Otherwise fetch from backend
    final uri = Uri.parse('$_baseUrl/$uid');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final safeData = data.map((d) => Map<String, dynamic>.from(d)).toList();
      _cache[cacheKey] = _CacheEntry(safeData);
      _touch(cacheKey);
      _evictIfNeeded();
      return safeData;
    } else {
      throw Exception('Failed to fetch tasks: ${response.statusCode}');
    }
  }

  void _silentRefresh(String uid) async {
    try {
      final uri = Uri.parse('$_baseUrl/$uid');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final safeData = data.map((d) => Map<String, dynamic>.from(d)).toList();
        _cache[uid] = _CacheEntry(safeData);
        print('🔄 Task cache refreshed for $uid');
      }
    } catch (_) {}
  }

  /* =====================================================
     📤 Upload Task File
  ====================================================== */
  Future<void> uploadTaskFile(File file, String uid, {String? category}) async {
    final uri = Uri.parse('$_baseUrl/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['uid'] = uid
      ..fields['category'] = category ?? ''; // optional grouping
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 201) {
      _invalidateCache(uid);
      print('✅ Task file uploaded successfully.');
    } else {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     📥 Download Task File
  ====================================================== */
  Future<Uint8List> downloadTaskFile(String fileId, String uid) async {
    final uri = Uri.parse('$_baseUrl/$uid/files/$fileId/download');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Download failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     🗑️ Delete Task File
  ====================================================== */
  Future<void> deleteTaskFile(String fileId, String uid) async {
    final uri = Uri.parse('$_baseUrl/$uid/files/$fileId');
    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      _invalidateCache(uid);
      print('🗑️ Task file deleted successfully.');
    } else {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     📄 Rename / Update Task Metadata (Optional)
  ====================================================== */
  Future<void> renameTaskFile(String fileId, String uid, String newName) async {
    final uri = Uri.parse('$_baseUrl/$uid/files/$fileId');
    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'new_name': newName}),
    );

    if (response.statusCode == 200) {
      _invalidateCache(uid);
    } else {
      throw Exception('Rename failed: ${response.statusCode}');
    }
  }
}
