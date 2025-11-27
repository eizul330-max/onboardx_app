// task_manager_screen.dart
// NOTE (testing): This file contains a local Admin/User toggle used for
// testing. Change/remove this behavior on deployment.
// Purpose: Templates are shared (top virtual section). Normal sections are per-user.
// Admin toggle only controls template edit/upload UI for testing.

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

  /// LOCAL TEST MODE: Admin/User switch (testing only; change for deploy)
  bool _isAdmin = false;

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
      final filesFuture =
          _taskService.fetchUserTasks(_userUid!, forceRefresh: forceRefresh);
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
      _showSnackbar('Failed to load: $e');
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
      if (name.isEmpty) return _showSnackbar('Name required');

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
      if (name.isEmpty) return _showSnackbar('Name required');

      try {
        final added = await _taskService.addDocumentToSection(sectionId, name);

        final idx = _sections.indexWhere((s) => s['_id'] == sectionId);
        if (idx != -1) {
          setState(() => (_sections[idx]['documents'] as List).add(added));
        } else {
          await _loadAll(forceRefresh: true);
        }

        _showSnackbar('Document type added');
      } catch (e) {
        _showSnackbar('Add failed: $e');
      }
    }
  }

  Future<void> _uploadFileForDoc(
      String sectionId, String docId, String docName) async {
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

  /// FIXED: replaces broken method
  Future<void> _openFile(Map<String, dynamic> f) async {
    try {
      await _taskService.openTaskFile(f['_id'], _userUid!);
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

  Future<void> _deleteDocumentFromSection(
      String sectionId, String docId, [String? docName]) async {
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

  // ---------------- Template upload (admin) ----------------
  Future<void> _uploadTemplate() async {
    if (!_isAdmin) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final file = File(result.files.single.path!);

    try {
      // 'uid' is required by the backend to identify uploader (admin)
      if (_userUid == null) return _showSnackbar('Missing user id for upload');

      await _taskService.uploadTemplate(file, _userUid!, category: '', description: '');
      _showSnackbar('Template uploaded');
      await _loadAll(forceRefresh: true);
    } catch (e) {
      _showSnackbar('Template upload failed: $e');
    }
  }

  // ---------------- Template delete placeholder ----------------
  Future<void> _deleteTemplatePlaceholder(String templateId) async {
    // The backend currently does not expose a delete endpoint for templates
    // (there's a GET and POST upload/download). Wire this to backend DELETE
    // later. For now show a clear message.
    _showSnackbar('Delete not available on server yet — implement backend delete later.');
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
          /// ADMIN/USER TOGGLE (testing only)
          Row(
            children: [
              Text(_isAdmin ? "Admin" : "User", style: const TextStyle(fontSize: 12)),
              Switch(
                value: _isAdmin,
                onChanged: (v) => setState(() => _isAdmin = v),
              ),
            ],
          ),

          // Add Section ALWAYS visible — users should be able to create sections.
          IconButton(
            tooltip: 'Add Section',
            icon: const Icon(Icons.add),
            onPressed: _showAddSectionDialog,
          ),

          // Admin-only: upload template (uploads to /api/task_templates/upload)
          if (_isAdmin)
            IconButton(
              tooltip: 'Upload Template',
              icon: const Icon(Icons.upload_file),
              onPressed: _uploadTemplate,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sections', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                      const SizedBox(height: 12),

                      for (final section in _sections) _buildSectionCard(section),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final bool isTemplateSection = section['isTemplateSection'] == true;

    // Templates are handled as an ExpansionTile for collapse/expand UX
    if (isTemplateSection) {
      final List templates = section['templates'] ?? [];
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ExpansionTile(
          key: ValueKey('templates_expansion'),
          leading: const Icon(Icons.folder_shared),
          title: Text(section['name'] ?? 'Templates',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          // admin can upload (AppBar) and optionally do more
          children: templates.map<Widget>((tmpl) {
            return ListTile(
              title: Text(tmpl['name'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Download template',
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      _taskService.openTaskTemplate(tmpl['_id']);
                    },
                  ),
                  if (_isAdmin)
                    IconButton(
                      tooltip: 'Delete template (backend required)',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteTemplatePlaceholder(tmpl['_id']),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    // NORMAL SECTION card
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    section['name'] ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                // Add document type — allowed for all users (per-user sections)
                IconButton(
                  tooltip: 'Add document type',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showAddDocumentDialog(section['_id']),
                ),

                // Delete section — allowed for owner/admin (backend enforces)
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
                    _buildDocumentTile(section, doc),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile(Map<String, dynamic> section, Map<String, dynamic> doc) {
    final f = _getFileForDoc(section['_id'].toString(), doc['_id'].toString());

    final isTemplateSection = section['isTemplateSection'] == true;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(doc['name'] ?? ''),
      subtitle: f != null ? Text('Uploaded: ${f['name']}') : const Text('No file uploaded'),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          // Open always allowed when file exists
          if (value == 'open' && f != null) {
            _openFile(f);
            return;
          }

          // If this is a template section, users are not allowed to modify templates.
          if (isTemplateSection && !_isAdmin) return;

          // Normal (per-user) sections: allow users to upload/delete their files (and delete doc if empty)
          if (value == 'upload' && !isTemplateSection) {
            _uploadFileForDoc(section['_id'].toString(), doc['_id'].toString(), doc['name']);
          } else if (value == 'delete_file' && f != null) {
            _deleteFile(f);
          } else if (value == 'delete_doc' && f == null) {
            _deleteDocumentFromSection(section['_id'].toString(), doc['_id'].toString(), doc['name']?.toString());
          }
        },
        itemBuilder: (context) {
          List<PopupMenuEntry<String>> items = [];

          // Always allow OPEN if file exists
          if (f != null) {
            items.add(const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 10),
                  Text('Open File'),
                ],
              ),
            ));
          }

          // For templates: only allow open/download for users; admin gets editing options (upload at appbar)
          if (isTemplateSection) {
            if (_isAdmin) {
              // admin could have extra options; leave upload in appbar for clarity
              // Add delete option only as a placeholder (backend delete implementation required)
              items.add(const PopupMenuItem(
                value: 'delete_doc',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Delete (backend required)', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ));
            }
          } else {
            // Normal section: allow upload and delete for owner (and admin)
            items.add(const PopupMenuItem(
              value: 'upload',
              child: Row(
                children: [
                  Icon(Icons.file_upload_outlined),
                  SizedBox(width: 10),
                  Text('Upload File'),
                ],
              ),
            ));

            if (f != null) {
              items.add(const PopupMenuItem(
                value: 'delete_file',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Delete File', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ));
            }

            if (f == null) {
              items.add(const PopupMenuItem(
                value: 'delete_doc',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Delete Document Type', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ));
            }
          }

          return items;
        },
      ),
    );
  }
}
