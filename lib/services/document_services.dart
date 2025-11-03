// document_services.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DocumentService {
  /// Backend base URL — centralized here
  static const String _baseUrl = 'http://10.111.132.36:4000/api';

  /// Simple in-memory cache for folder contents
  final Map<String, List<dynamic>> _cache = {};

  /* =====================================================
     📁 Fetch Folder Contents
  ====================================================== */
  Future<List<dynamic>> fetchFolderContents(String uid, {String? parentId}) async {
    // If no parent folder ID — get user's root folder
    final effectiveParentId = parentId ?? await _getRootFolderId(uid);

    final cacheKey = '${uid}_${effectiveParentId ?? "root"}';
    if (_cache.containsKey(cacheKey)) {
      print('📦 Using cached data for $cacheKey');
      return _cache[cacheKey]!;
    }

    final queryParams = {
      'uid': uid,
      if (effectiveParentId != null) 'parent_folder_id': effectiveParentId,
    };

    final foldersUri = Uri.parse('$_baseUrl/folders').replace(queryParameters: queryParams);
    final filesUri = Uri.parse('$_baseUrl/files').replace(queryParameters: queryParams);

    try {
      final responses = await Future.wait([
        http.get(foldersUri),
        http.get(filesUri),
      ]);

      final foldersResponse = responses[0];
      final filesResponse = responses[1];

      if (foldersResponse.statusCode != 200) {
        throw Exception('Failed to fetch folders: ${foldersResponse.statusCode}');
      }

      final folders = jsonDecode(foldersResponse.body) as List;
      final List files;
      if (filesResponse.statusCode == 200) {
        files = jsonDecode(filesResponse.body) as List;
      } else if (filesResponse.statusCode == 404) {
        files = [];
      } else {
        throw Exception('Failed to fetch files: ${filesResponse.statusCode}');
      }

      final combined = [
        ...folders.map((f) => {...f, 'type': 'folder'}),
        ...files.map((f) => {...f, 'type': 'file'}),
      ];

      _cache[cacheKey] = combined;
      return combined;
    } catch (e) {
      throw Exception('Failed to fetch folder contents: $e');
    }
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
     🗑️ Delete File or Folder
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
     🌱 Root Folder
  ====================================================== */
  Future<String?> _getRootFolderId(String uid) async {
    try {
      final uri = Uri.parse('$_baseUrl/folders/root/$uid');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['_id'];
      } else if (response.statusCode == 404) {
        // Auto-create root folder
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
      final data = jsonDecode(response.body);
      return data['_id'];
    } else {
      throw Exception('Failed to create root folder: ${response.statusCode}');
    }
  }

  /* =====================================================
     🧠 Cache Helpers
  ====================================================== */
  void _invalidateCache(String uid, String? parentId) {
    final cacheKey = '${uid}_${parentId ?? "root"}';
    _cache.remove(cacheKey);
  }

  void clearCache() => _cache.clear();
}
