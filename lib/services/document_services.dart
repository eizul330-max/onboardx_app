//document_services.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DocumentService {
  final String baseUrl;

  DocumentService({required this.baseUrl});

  /// Fetch all items (files & folders) in the specified parent folder.
  Future<List<dynamic>> fetchFolderContents(String uid, {String? parentId}) async {
    final uri = Uri.parse('$baseUrl/files_and_folders').replace(queryParameters: {
      'uid': uid,
      if (parentId != null) 'parent_folder_id': parentId,
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch folder contents: ${response.statusCode}');
    }
  }

  /// Upload a new document. Supports optional parent folder.
  Future<void> uploadDocument(File file, String uid, {String? parentId}) async {
    final uri = Uri.parse('$baseUrl/files_and_folders/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['uid'] = uid;

    if (parentId != null) {
      request.fields['parent_folder_id'] = parentId;
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode != 201) {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }

  /// Create a new folder under the current parent folder.
  Future<void> createFolder(String name, String uid, {String? parentId}) async {
    final uri = Uri.parse('$baseUrl/files_and_folders');
    final body = {
      'name': name,
      'uid': uid,
      if (parentId != null) 'parent_folder_id': parentId,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create folder: ${response.statusCode}');
    }
  }

  /// Download a document by its ID.
  Future<Uint8List> downloadDocument(String id, String uid) async {
    final uri = Uri.parse('$baseUrl/files_and_folders/$id/download?uid=$uid');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Download failed: ${response.statusCode}');
    }
  }

  /// Delete a document or folder.
  Future<void> deleteDocument(String id, String uid) async {
    final uri = Uri.parse('$baseUrl/files_and_folders/$id?uid=$uid');

    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }
}
