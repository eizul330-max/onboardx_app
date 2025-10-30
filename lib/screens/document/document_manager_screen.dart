import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:onboardx_app/services/document_services.dart';
import 'package:path_provider/path_provider.dart';
import 'document_preview_screen.dart';

class DocumentManagerScreen extends StatefulWidget {
  const DocumentManagerScreen({super.key});

  @override
  State<DocumentManagerScreen> createState() => _DocumentManagerScreenState();
}

class _DocumentManagerScreenState extends State<DocumentManagerScreen> {
  late final DocumentService _documentService;
  List<dynamic> _documents = [];
  bool _loading = true;
  bool _uploading = false;
  String? _uid;

  // Folder navigation
  String? _currentFolderId;
  String _currentFolderName = 'My Documents';
  final List<Map<String, String?>> _folderStack = [];

  @override
  void initState() {
    super.initState();
    _documentService =
        DocumentService(baseUrl: 'http://10.111.132.36:4000/api');
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _uid = user.uid);
      await _loadDocuments();
    } else {
      setState(() => _loading = false);
      _showError('User not signed in.');
    }
  }

  Future<void> _loadDocuments() async {
    if (_uid == null) return;
    try {
      final docs = await _documentService.fetchFolderContents(
        _uid!,
        parentId: _currentFolderId,
      );
      setState(() {
        _documents = docs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load documents: $e');
    }
  }

  Future<void> _createFolder() async {
    if (_uid == null) return;
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await _documentService.createFolder(
        name,
        _uid!,
        parentId: _currentFolderId,
      );
      await _loadDocuments();
      _showMessage('Folder created successfully');
    } catch (e) {
      _showError('Failed to create folder: $e');
    }
  }

  Future<void> _enterFolder(Map<String, dynamic> folder) async {
    _folderStack.add({
      'id': _currentFolderId,
      'name': _currentFolderName,
    });
    setState(() {
      _currentFolderId = folder['_id'];
      _currentFolderName = folder['name'] ?? 'Unnamed Folder';
      _loading = true;
    });
    await _loadDocuments();
  }

  Future<void> _goBack() async {
    if (_folderStack.isEmpty) return;
    final prev = _folderStack.removeLast();
    setState(() {
      _currentFolderId = prev['id'];
      _currentFolderName = prev['name'] ?? 'My Documents';
      _loading = true;
    });
    await _loadDocuments();
  }

  Future<void> _uploadDocument() async {
    if (_uid == null) return;
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      try {
        setState(() => _uploading = true);
        await _documentService.uploadDocument(
          file,
          _uid!,
          parentId: _currentFolderId,
        );
        await _loadDocuments();
        _showMessage('File uploaded successfully');
      } catch (e) {
        _showError('Upload failed: $e');
      } finally {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _deleteDocument(String id) async {
    if (_uid == null) return;
    try {
      await _documentService.deleteDocument(id, _uid!);
      setState(() {
        _documents.removeWhere((doc) => doc['_id'] == id);
      });
      _showMessage('File deleted successfully');
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Future<void> _downloadDocument(String id, String name) async {
    if (_uid == null) return;
    try {
      final bytes = await _documentService.downloadDocument(id, _uid!);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      _showMessage('Downloaded to ${file.path}');
    } catch (e) {
      _showError('Download failed: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = !_loading && _documents.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFolderName),
        leading: _folderStack.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _createFolder,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploading ? null : _uploadDocument,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? const Center(
                  child: Text(
                    'No items found.\nCreate a folder or upload a file to start!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDocuments,
                  child: ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      final name = doc['name'] ?? 'Unnamed';
                      final size = _formatFileSize(doc['file_size']);
                      final isFile = doc['type'] == 'file';

                      return ListTile(
                        leading: Icon(
                          isFile ? Icons.insert_drive_file : Icons.folder,
                          color: isFile ? Colors.blueAccent : Colors.amber,
                        ),
                        title: Text(name),
                        subtitle: isFile ? Text('Size: $size') : null,
                        onTap: () {
                          if (isFile) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DocumentPreviewScreen(
                                  document: doc,
                                  uid: _uid!,
                                  documentService: _documentService,
                                ),
                              ),
                            );
                          } else {
                            _enterFolder(doc);
                          }
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFile)
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () =>
                                    _downloadDocument(doc['_id'], name),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteDocument(doc['_id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
