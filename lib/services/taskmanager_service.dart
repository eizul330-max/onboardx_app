// lib/services/taskmanager_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;

class TaskManagerService {
  static const String _root = 'http://10.111.132.36:4000/api';

  // Caching
  static const int _maxCacheEntries = 6;
  static const Duration _cacheTTL = Duration(seconds: 30);

  final Map<String, _CacheEntry> _cache = {};
  final List<String> _lruOrder = [];

  bool _isExpired(String key) {
    final entry = _cache[key];
    return entry == null || DateTime.now().difference(entry.timestamp) > _cacheTTL;
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
      final decoded = jsonDecode(response.body);
      // body might be { ok:true, count:..., data: [...] } or directly data, adjust accordingly
      final List data = decoded is Map && decoded['data'] != null ? decoded['data'] as List : decoded as List;
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
        final decoded = jsonDecode(response.body);
        final List data = decoded is Map && decoded['data'] != null ? decoded['data'] as List : decoded as List;
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

    final respStr = await response.stream.bytesToString();
    throw Exception('Upload failed: ${response.statusCode} - $respStr');
  }

  Future<void> deleteTaskFile(String fileId, String uid) async {
    final uri = Uri.parse('$_root/task_manager/files/$uid/files/$fileId');
    final response = await http.delete(uri);
    if (response.statusCode == 200) {
      _invalidateCache(uid);
      return;
    }
    throw Exception('Delete failed: ${response.statusCode} - ${response.body}');
  }

  Future<void> openTaskFile(String fileId, String uid, {String? fileName}) async {
    final uri = Uri.parse('$_root/task_manager/files/$uid/files/$fileId/download');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final disposition = response.headers['content-disposition'];
    String finalFile = fileName ?? fileId;

    if (disposition != null && disposition.contains('filename=')) {
      finalFile = disposition.split('filename=')[1].replaceAll('"', '').trim();
    }

    final tempDir = Directory.systemTemp;
    final filePath = path.join(tempDir.path, finalFile);
    final file = File(filePath);

    await file.writeAsBytes(response.bodyBytes);
    await OpenFile.open(file.path);
  }

  // ============================================================
  // SECTIONS
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchSections(String uid) async {
    final uri = Uri.parse('$_root/task_manager/sections/$uid');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final List data = decoded is Map && decoded['data'] != null ? decoded['data'] as List : decoded as List;
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

  Future<Map<String, dynamic>> addDocumentToSection(String sectionId, String name) async {
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

  Future<void> deleteDocumentFromSection(String sectionId, String docId) async {
    final uri = Uri.parse('$_root/task_manager/sections/$sectionId/documents/$docId');

    final res = await http.delete(uri);

    if (res.statusCode != 200) {
      throw Exception('Delete document failed: ${res.body}');
    }
  }

  // ============================================================
  // TEMPLATES
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchTemplates() async {
    final uri = Uri.parse('$_root/task_templates');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final List data = decoded is Map && decoded['data'] != null ? decoded['data'] as List : decoded as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    throw Exception('Failed to fetch templates: ${res.statusCode}');
  }

  // Download / open template
  Future<void> openTaskTemplate(String templateId) async {
    final uri = Uri.parse('$_root/task_templates/$templateId/download');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Template download failed: ${res.statusCode}');
    }

    final disposition = res.headers['content-disposition'];
    String finalFile = 'template_$templateId';

    if (disposition != null && disposition.contains('filename=')) {
      finalFile = disposition.split('filename=')[1].replaceAll('"', '').trim();
    }

    final tempDir = Directory.systemTemp;
    final filePath = path.join(tempDir.path, finalFile);
    final file = File(filePath);

    await file.writeAsBytes(res.bodyBytes);
    await OpenFile.open(file.path);
  }

  // Upload template (admin)
  Future<void> uploadTemplate(File file, String uid, {String? category, String? description}) async {
    final uri = Uri.parse('$_root/task_templates/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['uid'] = uid
      ..fields['category'] = category ?? ''
      ..fields['description'] = description ?? '';

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode == 201) {
      return;
    }

    final respStr = await response.stream.bytesToString();
    throw Exception('Template upload failed: ${response.statusCode} - $respStr');
  }

  // NOTE: Backend delete template endpoint is not implemented in your merged backend
  // If you add DELETE /api/task_templates/:id, implement deleteTemplate calling that endpoint.
}

class _CacheEntry {
  final List<Map<String, dynamic>> data;
  DateTime timestamp;

  _CacheEntry(this.data) : timestamp = DateTime.now();
}
