// taskmanager_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;

class TaskManagerService {
  // 🔥 Matches your backend root EXACTLY
  static const String _root = 'http://10.111.132.36:4000/api';

  // --------------------------
  // Caching system
  // --------------------------
  static const int _maxCacheEntries = 6;
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

  void _invalidateCache(String uid) {
    _cache.remove('files_$uid');
    _lruOrder.remove('files_$uid');
  }

  // ============================================================
  // FILES
  // Backend route: /api/task_manager/files/:uid
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchUserTasks(String uid,
      {bool forceRefresh = false}) async {
    final cacheKey = 'files_$uid';

    if (!forceRefresh && _cache.containsKey(cacheKey) && !_isExpired(cacheKey)) {
      _touch(cacheKey);
      _silentRefreshFiles(uid);
      return _cache[cacheKey]!.data;
    }

    final uri = Uri.parse('$_root/task_manager/files/$uid');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      final safe = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _cache[cacheKey] = _CacheEntry(safe);
      _touch(cacheKey);
      _evictIfNeeded();
      return safe;
    }

    throw Exception('Failed to fetch files: ${response.statusCode}');
  }

  void _silentRefreshFiles(String uid) async {
    try {
      final uri = Uri.parse('$_root/task_manager/files/$uid');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'];
        _cache['files_$uid'] =
            _CacheEntry(data.map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (_) {}
  }

  Future<void> uploadTaskFile(File file, String uid,
      {String? category, String? sectionId, String? documentId}) async {
    final uri = Uri.parse('$_root/task_manager/files/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['uid'] = uid
      ..fields['category'] = category ?? ''
      ..fields['section_id'] = sectionId ?? ''
      ..fields['document_id'] = documentId ?? '';

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode == 201) {
      _invalidateCache(uid);
      return;
    }

    throw Exception('Upload failed: ${response.statusCode}');
  }

  Future<void> deleteTaskFile(String fileId, String uid) async {
    final uri = Uri.parse('$_root/task_manager/files/$uid/files/$fileId');
    final response = await http.delete(uri);
    if (response.statusCode == 200) {
      _invalidateCache(uid);
      return;
    }
    throw Exception('Delete failed: ${response.statusCode}');
  }

  Future<void> openTaskFile(String fileId, String uid,
      {String? fileName}) async {
    final uri =
        Uri.parse('$_root/task_manager/files/$uid/files/$fileId/download');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final disposition = response.headers['content-disposition'];
    String finalFile = fileName ?? fileId;

    if (disposition != null && disposition.contains('filename=')) {
      finalFile =
          disposition.split('filename=')[1].replaceAll('"', '').trim();
    }

    final tempDir = Directory.systemTemp;
    final filePath = path.join(tempDir.path, finalFile);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    await OpenFile.open(file.path);
  }

  // ============================================================
  // SECTIONS
  // Backend route: /api/task_manager/sections/:uid
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchSections(String uid) async {
    final uri = Uri.parse('$_root/task_manager/sections/$uid');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body)['data'];
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    throw Exception('Failed to fetch sections: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> createSection(String uid, String name) async {
    final uri = Uri.parse('$_root/task_manager/sections/create');

    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'name': name}));

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body)['data']);
    }

    throw Exception('Create section failed: ${res.body}');
  }

  Future<Map<String, dynamic>> addDocumentToSection(
      String sectionId, String name) async {
    final uri = Uri.parse('$_root/task_manager/sections/$sectionId/documents');

    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}));

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body)['data']);
    }

    throw Exception('Add document failed: ${res.body}');
  }

  Future<void> deleteSection(String sectionId) async {
    final uri = Uri.parse('$_root/task_manager/sections/$sectionId');
    final res = await http.delete(uri);

    if (res.statusCode != 200) {
      throw Exception('Delete section failed: ${res.body}');
    }
  }

  Future<void> deleteDocumentFromSection(
      String sectionId, String docId) async {
    final uri =
        Uri.parse('$_root/task_manager/sections/$sectionId/documents/$docId');

    final res = await http.delete(uri);

    if (res.statusCode != 200) {
      throw Exception('Delete document failed: ${res.body}');
    }
  }

  // ============================================================
  // CATEGORIES
  // Backend route: /api/task_categories
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchCategories(String uid) async {
    final uri = Uri.parse('$_root/task_categories/$uid');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body)['data'];
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    throw Exception('Fetch categories failed: ${res.statusCode}');
  }

  Future<void> createCategory(String uid, String name) async {
    final uri = Uri.parse('$_root/task_categories/create');

    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'name': name}));

    if (res.statusCode != 201) {
      throw Exception('Create category failed: ${res.body}');
    }
  }

  // ============================================================
  // TEMPLATES
  // Backend route: /api/task_templates
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchTemplates() async {
    final uri = Uri.parse('$_root/task_templates');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body)['data'];
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    throw Exception('Failed to fetch templates: ${res.statusCode}');
  }
}

class _CacheEntry {
  final List<Map<String, dynamic>> data;
  DateTime timestamp;

  _CacheEntry(this.data) : timestamp = DateTime.now();
}
