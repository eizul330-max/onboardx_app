// lib/screens/task_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_app/services/taskmanager_service.dart';
import 'dart:io';

class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  final TaskManagerService _taskService = TaskManagerService();

  List<Map<String, dynamic>> _taskFiles = [];
  List<Map<String, dynamic>> _sections = [];
  bool _isLoading = true;
  String? _userUid;

  @override
  void initState() {
    super.initState();
    _initializeUserAndLoadAll();
  }

  Future<void> _initializeUserAndLoadAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _userUid = user.uid);
      await _loadAll();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User not authenticated.')));
    }
  }

  Future<void> _loadAll({bool forceRefresh = false}) async {
    if (_userUid == null) return;
    setState(() => _isLoading = true);

    try {
      final filesFuture = _taskService.fetchUserTasks(_userUid!, forceRefresh: forceRefresh);
      final sectionsFuture = _taskService.fetchSections(_userUid!);

      final results = await Future.wait([filesFuture, sectionsFuture]);

      if (!mounted) return;

      setState(() {
        _taskFiles = results[0] as List<Map<String, dynamic>>;
        _sections = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
  }

  Map<String, dynamic>? _getFileForDoc(String sectionId, String docId) {
    try {
      return _taskFiles.firstWhere((f) {
        return f['section_id']?.toString() == sectionId &&
            f['document_id']?.toString() == docId;
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAddSectionDialog() async {
    final TextEditingController c = TextEditingController();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Section'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Section name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (res == true) {
      final name = c.text.trim();
      if (name.isEmpty) {
        _showSnackbar('Name required');
        return;
      }
      try {
        final newSection = await _taskService.createSection(_userUid!, name);
        setState(() => _sections.insert(0, newSection));
        _showSnackbar('Section created');
      } catch (e) {
        _showSnackbar('Create failed: $e');
      }
    }
  }

  Future<void> _showAddDocumentDialog(String sectionId) async {
    final TextEditingController c = TextEditingController();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Document Type'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Document name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (res == true) {
      final name = c.text.trim();
      if (name.isEmpty) {
        _showSnackbar('Name required');
        return;
      }
      try {
        final added = await _taskService.addDocumentToSection(sectionId, name);

        final idx = _sections.indexWhere((s) => s['_id'] == sectionId);
        if (idx != -1) {
          setState(() {
            (_sections[idx]['documents'] as List).add(added);
          });
        } else {
          await _loadAll(forceRefresh: true);
        }

        _showSnackbar('Document type added');
      } catch (e) {
        _showSnackbar('Add failed: $e');
      }
    }
  }

  Future<void> _uploadFileForDoc(String sectionId, String docId, String docName) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final file = File(result.files.single.path!);

    try {
      await _taskService.uploadTaskFile(
        file,
        _userUid!,
        category: docName,
        sectionId: sectionId,
        documentId: docId,
      );

      _showSnackbar('File uploaded');
      await _loadAll(forceRefresh: true);
    } catch (e) {
      _showSnackbar('Upload failed: $e');
    }
  }

  Future<void> _downloadOpenFile(Map<String, dynamic> fileDoc) async {
    try {
      await _taskService.openTaskFile(fileDoc['_id'], _userUid!);
    } catch (e) {
      _showSnackbar('Open failed: $e');
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> fileDoc) async {
    try {
      await _taskService.deleteTaskFile(fileDoc['_id'], _userUid!);
      _showSnackbar('File deleted');
      await _loadAll(forceRefresh: true);
    } catch (e) {
      _showSnackbar('Delete failed: $e');
    }
  }

  // keep section delete as-is (uses section map for friendly dialog)
  Future<void> _deleteSection(Map<String, dynamic> section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete section "${section['name']}"?'),
        content: const Text('This will fail if files are attached. Delete files first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final String sectionId = section['_id'];

      await _taskService.deleteSection(sectionId);

      setState(() {
        _sections.removeWhere((s) => s['_id'] == sectionId);
      });

      _showSnackbar('Section removed');
    } catch (e) {
      _showSnackbar('Delete failed: $e');
    }
  }

  // UPDATED: accept explicit docId and optional docName for the confirmation
  Future<void> _deleteDocumentFromSection(String sectionId, String docId, [String? docName]) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete document "${docName ?? docId}"?'),
        content: const Text('This will fail if files are attached. Delete files first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _taskService.deleteDocumentFromSection(sectionId, docId);

      final sIdx = _sections.indexWhere((s) => s['_id'] == sectionId);
      if (sIdx != -1) {
        setState(() {
          (_sections[sIdx]['documents'] as List).removeWhere((d) => d['_id'] == docId);
        });
      } else {
        await _loadAll(forceRefresh: true);
      }

      _showSnackbar('Document removed');
    } catch (e) {
      _showSnackbar('Delete failed: $e');
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.taskmanager1,
            style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Add Section moved to the app bar
          IconButton(
            tooltip: 'Add Section',
            icon: const Icon(Icons.add),
            onPressed: _showAddSectionDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAll(forceRefresh: true),
          ),
        ],
      ),
      body: _userUid == null
          ? const Center(child: Text('User not signed in.'))
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _loadAll(forceRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header text only; Add button moved to appbar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sections', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 12),

                      for (final section in _sections)
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        section['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Add document type',
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => _showAddDocumentDialog(section['_id']),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete section',
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _deleteSection(section),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                if ((section['documents'] as List).isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('No document types. Add one.'),
                                  )
                                else
                                  Column(
                                    children: [
                                      for (final doc in (section['documents'] as List))
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(doc['name'] ?? ''),
                                          subtitle: Builder(builder: (ctx) {
                                            final f = _getFileForDoc(
                                                section['_id'].toString(), doc['_id'].toString());
                                            return f != null
                                                ? Text('Uploaded: ${f['name']}')
                                                : const Text('No file uploaded');
                                          }),
                                          trailing: PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (value) async {
                                              final f = _getFileForDoc(
                                                section['_id'].toString(),
                                                doc['_id'].toString(),
                                              );

                                              if (value == 'upload') {
                                                _uploadFileForDoc(
                                                  section['_id'].toString(),
                                                  doc['_id'].toString(),
                                                  doc['name'],
                                                );
                                              } else if (value == 'open' && f != null) {
                                                _downloadOpenFile(f);
                                              } else if (value == 'delete_file' && f != null) {
                                                _deleteFile(f);
                                              } else if (value == 'delete_doc' && f == null) {
                                                // IMPORTANT: pass the docId (string) + optional name
                                                _deleteDocumentFromSection(
                                                  section['_id'].toString(),
                                                  doc['_id'].toString(),
                                                  doc['name']?.toString(),
                                                );
                                              }
                                            },
                                            itemBuilder: (context) {
                                              final f = _getFileForDoc(
                                                section['_id'].toString(),
                                                doc['_id'].toString(),
                                              );

                                              return <PopupMenuEntry<String>>[
                                                const PopupMenuItem(
                                                  value: 'upload',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.file_upload_outlined),
                                                      SizedBox(width: 10),
                                                      Text('Upload File'),
                                                    ],
                                                  ),
                                                ),
                                                if (f != null)
                                                  const PopupMenuItem(
                                                    value: 'open',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.visibility),
                                                        SizedBox(width: 10),
                                                        Text('Open File'),
                                                      ],
                                                    ),
                                                  ),
                                                if (f != null)
                                                  const PopupMenuItem(
                                                    value: 'delete_file',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete, color: Colors.redAccent),
                                                        SizedBox(width: 10),
                                                        Text(
                                                          'Delete File',
                                                          style: TextStyle(color: Colors.redAccent),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (f == null)
                                                  const PopupMenuItem(
                                                    value: 'delete_doc',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete_outline, color: Colors.redAccent),
                                                        SizedBox(width: 10),
                                                        Text(
                                                          'Delete Document Type',
                                                          style: TextStyle(color: Colors.redAccent),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ];
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}
