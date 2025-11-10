// taskmanager_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;

class TaskManagerService {
  static const String _baseUrl = 'http://10.111.132.36:4000/api/task_manager';
  static const int _maxCacheEntries = 6;
  static const Duration _cacheTTL = Duration(seconds: 30);

  final Map<String, _CacheEntry> _cache = {};
  final List<String> _lruOrder = [];

  /* =====================================================
     🧠 Cache Utility
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

  /* =====================================================
     📥 Fetch all files for a user
  ====================================================== */
  Future<List<Map<String, dynamic>>> fetchUserTasks(String uid) async {
    final cacheKey = uid;

    if (_cache.containsKey(cacheKey) && !_isExpired(cacheKey)) {
      _touch(cacheKey);
      _silentRefresh(uid);
      return _cache[cacheKey]!.data;
    }

    final uri = Uri.parse('$_baseUrl/$uid');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List data = body['data'] as List;
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
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List data = body['data'] as List;
        final safeData = data.map((d) => Map<String, dynamic>.from(d)).toList();
        _cache[uid] = _CacheEntry(safeData);
      }
    } catch (_) {}
  }

  /* =====================================================
     📤 Upload file
  ====================================================== */
  Future<void> uploadTaskFile(File file, String uid, {String? category}) async {
    final uri = Uri.parse('$_baseUrl/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['uid'] = uid
      ..fields['category'] = category ?? '';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode == 201) {
      _invalidateCache(uid);
    } else {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     🗑️ Delete file
  ====================================================== */
  Future<void> deleteTaskFile(String fileId, String uid) async {
    final uri = Uri.parse('$_baseUrl/$uid/files/$fileId');
    final response = await http.delete(uri);

    if (response.statusCode == 200) {
      _invalidateCache(uid);
    } else {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }

  /* =====================================================
     📂 Download & open file
  ====================================================== */
  Future<void> openTaskFile(String fileId, String uid, {String? fileName}) async {
    final uri = Uri.parse('$_baseUrl/$uid/files/$fileId/download');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    // Try to get the original filename from the Content-Disposition header
    final disposition = response.headers['content-disposition'];
    String finalFileName = fileName ?? fileId; // Fallback to fileId
    if (disposition != null && disposition.contains('filename=')) {
      finalFileName = disposition.split('filename=')[1].replaceAll('"', '').trim();
    }

    final tempDir = Directory.systemTemp;
    final filePath = path.join(tempDir.path, finalFileName);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception('Error opening file: ${result.message}');
    }
  }
}

class _CacheEntry {
  final List<Map<String, dynamic>> data;
  DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();
}
