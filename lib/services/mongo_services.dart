// // mongodb_service.dart

// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart';
// import 'package:path_provider/path_provider.dart';

// // Data models for Document and Folder, using String ID for MongoDB ObjectId
// class Document {
//   final String id; // Represents MongoDB _id
//   final String name;
//   final String path;
//   final String? parentFolderId; // Matches the 'parent_folder_id' in MongoDB
//   final DateTime createdAt;

//   Document({
//     required this.id,
//     required this.name,
//     required this.path,
//     this.parentFolderId,
//     required this.createdAt,
//   });

//   factory Document.fromJson(Map<String, dynamic> json) {
//     final createdAtValue = json['created_at'];

//     return Document(
//       id: json['_id'] as String,
//       name: json['name'] as String,
//       path: json['path'] as String, // Path in your file storage
//       parentFolderId: json['parent_folder_id'] as String?, // Updated field name
//       createdAt: createdAtValue is DateTime ? createdAtValue : DateTime.parse(createdAtValue as String),
//     );
//   }

//   String get url => path; // For compatibility with UI
// }

// class Folder {
//   final String id; // Represents MongoDB _id
//   final String name;
//   final String? parentFolderId;
//   final DateTime createdAt;

//   Folder({
//     required this.id,
//     required this.name,
//     this.parentFolderId,
//     required this.createdAt,
//   });

//   factory Folder.fromJson(Map<String, dynamic> json) {
//     final createdAtValue = json['created_at'];

//     return Folder(
//       id: json['_id'] as String,
//       name: json['name'] as String,
//       parentFolderId: json['parent_folder_id'] as String?,
//       createdAt: createdAtValue is DateTime ? createdAtValue : DateTime.parse(createdAtValue as String),
//     );
//   }
// }

// class FolderNotEmptyException implements Exception {
//   const FolderNotEmptyException();
//   @override
//   String toString() => 'Folder is not empty.';
// }

// // ============ MONGODB SERVICE IMPLEMENTATION ============

// class MongoDBService {
//   static final MongoDBService _instance = MongoDBService._internal();
//   factory MongoDBService() => _instance;
//   MongoDBService._internal();

//   // API Client Setup
//   final Dio _dio = Dio(BaseOptions(
//     baseUrl: 'https://your-api-base-url.com/api', // <-- TODO: REPLACE WITH YOUR API URL
//     connectTimeout: const Duration(seconds: 5),
//     receiveTimeout: const Duration(seconds: 3),
//   ));

//   // Helper to add the auth token to requests
//   Future<Options> _getAuthOptions() async {
//     final token = await FirebaseAuth.instance.currentUser?.getIdToken();
//     return Options(headers: {'Authorization': 'Bearer $token'});
//   }

//   // Constants
//   static const int maxStorageFileSize = 10 * 1024 * 1024;

//   // Get current user ID from Firebase Auth
//   String get _currentUserId {
//     final userId = FirebaseAuth.instance.currentUser?.uid;
//     if (userId == null || userId.isEmpty) {
//       throw Exception('User is not authenticated.');
//     }
//     return userId;
//   }

//   // ----------------------------------------------------------------
//   // ============ DOCUMENT MANAGER METHODS ============
//   // ----------------------------------------------------------------

//   Future<List<dynamic>> getFilesAndFolders(String? parentFolderId) async {
//     try {
//       final response = await _dio.get(
//         '/documents',
//         queryParameters: {'parentFolderId': parentFolderId},
//         options: await _getAuthOptions(),
//       );

//       final List<dynamic> documents = response.data as List<dynamic>;
      
//       final List<Folder> folders = [];
//       final List<Document> files = [];

//       for (final item in documents) {
//         if (item['type'] == 'folder') {
//           folders.add(Folder.fromJson(item as Map<String, dynamic>));
//         } else if (item['type'] == 'document') {
//           files.add(Document.fromJson(item));
//         }
//       }
      
//       // Sort by name to ensure consistent ordering in the UI
//       final sortedItems = [...folders, ...files]..sort((a, b) => a.name.compareTo(b.name));
//       return sortedItems;
//     } catch (e) {
//       debugPrint('❌ Failed to load files and folders: $e');
//       throw Exception('Failed to load files and folders: $e');
//     }
//   }

//   Future<void> createFolder(String name, String? parentFolderId) async {
//     try {
//       await _dio.post(
//         '/folders',
//         data: {
//           'name': name,
//           'parentFolderId': parentFolderId,
//         },
//         options: await _getAuthOptions(),
//       });
//     } catch (e) {
//       debugPrint('❌ Failed to create folder: $e');
//       throw Exception('Failed to create folder: $e');
//     }
//   }

//   Future<void> uploadFile(PlatformFile platformFile, String? folderId) async {
//     try {
//       if (platformFile.path == null) {
//         throw Exception('File path is not available.');
//       }

//       final formData = FormData.fromMap({
//         'file': await MultipartFile.fromFile(platformFile.path!, filename: platformFile.name),
//         if (folderId != null) 'parentFolderId': folderId,
//       });

//       await _dio.post(
//         '/documents/upload',
//         data: formData,
//         options: await _getAuthOptions(),
//         // onSendProgress: (sent, total) => ...
//       });
//     } catch (e) {
//       debugPrint('❌ Failed to upload file: $e');
//       throw Exception('Failed to upload file: $e');
//     }
//   }

//   Future<String?> downloadFile(String fileUrl, String fileName) async {
//     try {
//       // 1. Download file bytes from the public URL
//       final response = await _dio.get<List<int>>(
//         fileUrl,
//         options: Options(responseType: ResponseType.bytes), // Important for binary data
//       );
//       final fileBytes = response.data;

//       // 2. Get local directory
//       final directory = await getApplicationDocumentsDirectory();
//       final localFile = File('${directory.path}/$fileName');
      
//       // 3. Write file locally
//       await localFile.writeAsBytes(fileBytes);
      
//       if (fileBytes == null) {
//         throw Exception('Downloaded file data is null.');
//       }

//       return localFile.path;
//     } catch (e) {
//       debugPrint('❌ Failed to download file: $e');
//       throw Exception('Failed to download file: $e');
//     }
//   }

//   Future<void> deleteFile(String documentId) async {
//     try {
//       await _dio.delete('/documents/$documentId', options: await _getAuthOptions());
//     } catch (e) {
//       debugPrint('❌ Failed to delete file: $e');
//     }
//   }

//   Future<void> deleteFolder(String folderId, {bool recursive = false}) async {
//     try {
//       await _dio.delete(
//         '/folders/$folderId',
//         queryParameters: {'recursive': recursive},
//         options: await _getAuthOptions(),
//       );
//     } on DioException catch (e) {
//       // Check for a specific status code from the API that indicates the folder is not empty
//       if (e.response?.statusCode == 409) { // 409 Conflict is a good choice
//         if (recursive) {
//           // This case shouldn't happen if the API handles recursive deletion
//         } else {
//           throw const FolderNotEmptyException();
//         }
//       }
//     } on FolderNotEmptyException {
//       rethrow;
//     } catch (e) {
//       debugPrint('❌ Failed to delete folder: $e');
//       throw Exception('Failed to delete folder: $e');
//     }
//   }

//   // ----------------------------------------------------------------
//   // ============ TASK DOCUMENT METHODS ============
//   // ----------------------------------------------------------------
  
//   Future<String> uploadTaskDocument(String taskName, File file) async {
//     final userId = _currentUserId;

//     try {
//       final formData = FormData.fromMap({
//         'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
//         'taskName': taskName,
//       });

//       final response = await _dio.post(
//         '/tasks/document',
//         data: formData,
//         options: await _getAuthOptions(),
//       );

//       final publicUrl = response.data['url'] as String;

//       debugPrint('✅ Task document "$taskName" uploaded and record updated.');

//       return publicUrl;
//     } catch (e) {
//       debugPrint('❌ Failed to upload task document: $e');
//       throw Exception('Failed to upload task document: $e');
//     }
//   }

//   Future<Map<String, String>> getTaskDocuments() async {
//     final userId = _currentUserId;
//     try {
//       final response = await _dio.get('/tasks/documents', options: await _getAuthOptions());
//       final documents = response.data as List<dynamic>;
      
//       final Map<String, String> result = {};
//       for (var doc in documents) {
//         final docMap = doc as Map<String, dynamic>;
//         // Task name is the key, file name is the value
//         result[docMap['task_name'] as String] = docMap['file_name'] as String;
//       }
//       return result;
//     } catch (e) {
//       debugPrint('❌ Failed to get task documents: $e');
//       throw Exception('Failed to get task documents: $e');
//     }
//   }

//   Future<void> deleteTaskDocument(String taskName) async {
//     final userId = _currentUserId;

//     try {
//       await _dio.delete('/tasks/document/$taskName', options: await _getAuthOptions());

//       debugPrint('✅ Task document record for "$taskName" deleted.');
//     } catch (e) {
//       debugPrint('❌ Failed to delete task document: $e');
//       throw Exception('Failed to delete task document: $e');
//     }
//   }

//   // Download a task-specific document (uses existing downloadFile helper)
//   Future<String?> downloadTaskDocument(String taskName) async {
//     final userId = _currentUserId;

//     try {
//       final response = await _dio.get('/tasks/document/$taskName', options: await _getAuthOptions());

//       if (response.statusCode != 200 || response.data == null) {
//         throw Exception('Document for task "$taskName" not found.');
//       }

//       final docData = response.data as Map<String, dynamic>;
//       final fileUrl = docData['file_url'] as String;
//       final fileName = docData['file_name'] as String;

//       // 2. Download and save the file locally
//       // Assuming downloadFile now takes a URL
//       return await downloadFile(fileUrl, fileName);
//     } catch (e) {
//       debugPrint('❌ Failed to download task document: $e');
//       throw Exception('Failed to download task document: $e');
//     }
//   }

//   // ----------------------------------------------------------------
//   // ============ USER MANAGEMENT/PROFILE METHODS ============
//   // ----------------------------------------------------------------

//   Future<Map<String, dynamic>?> getUser(String uid) async {
//     try {
//       final response = await _dio.get('/users/$uid', options: await _getAuthOptions());
//       return response.data as Map<String, dynamic>?;
//     } catch (e) {
//       debugPrint('❌ Failed to get user: $e');
//       throw Exception('Failed to get user: $e');
//     }
//   }

//   Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
//     try {
//       final response = await _dio.post(
//         '/users',
//         data: userData,
//         options: await _getAuthOptions(),
//       );

//       return response.data as Map<String, dynamic>;
//     } catch (e) {
//       debugPrint('❌ Failed to create user: $e');
//       throw Exception('Failed to create user: $e');
//     }
//   }

//   Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
//     try {
//       await _dio.patch('/users/$uid', data: updates, options: await _getAuthOptions());
//     } catch (e) {
//       debugPrint('❌ Failed to update user: $e');
//       throw Exception('Failed to update user: $e');
//     }
//   }

//   Future<bool> isUsernameExists(String username) async {
//     try {
//       final response = await _dio.get(
//         '/users/username-exists',
//         queryParameters: {'username': username},
//         // No auth needed for this public check
//       );
//       return response.data['exists'] as bool;
//     } catch (e) {
//       debugPrint('❌ Failed to check username: $e');
//       throw Exception('Failed to check username: $e');
//     }
//   }

//   Future<Map<String, dynamic>?> getTeamByNoTeam(String noTeam) async {
//     try {
//       final response = await _dio.get('/teams/$noTeam', options: await _getAuthOptions());
//       return response.data as Map<String, dynamic>?;
//     } catch (e) {
//       debugPrint('❌ Failed to get team by no_team: $e');
//       throw Exception('Failed to get team by no_team: $e');
//     }
//   }

//   // The rest of the profile and utility methods (like image upload/download) 
//   // rely on the updated getUser, updateUser, and the new storageClient, so they remain largely the same.
//   // ... (The rest of the class methods, including profile, image, and utility functions, are omitted for brevity
//   // as they primarily use the new dbClient/storageClient methods shown above.)
//   // ...
// }