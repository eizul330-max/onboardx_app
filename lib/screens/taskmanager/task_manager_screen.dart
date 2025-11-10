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
  bool _isLoading = true;
  String? _userUid;

  @override
  void initState() {
    super.initState();
    _initializeUserAndLoadFiles();
  }

  Future<void> _initializeUserAndLoadFiles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (!mounted) return;
      setState(() => _userUid = user.uid);
      await _loadTaskFiles();
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
    }
  }

  Future<void> _loadTaskFiles() async {
    if (_userUid == null) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final files = await _taskService.fetchUserTasks(_userUid!);
      if (!mounted) return;
      setState(() {
        _taskFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tasks: $e')),
      );
    }
  }

  Map<String, dynamic>? _getFileForCategory(String category) {
    try {
      return _taskFiles.firstWhere((file) => file['category'] == category);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.taskmanager1, style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _userUid == null
          ? const Center(child: Text('User not signed in.'))
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTaskFiles,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(AppLocalizations.of(context)!.requiredDocuments,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),
                  DocumentCard(
                      uid: _userUid!,
                      title: 'Lampiran A',
                      subtitle: AppLocalizations.of(context)!.uploadtherequiredfiles,
                      subtitleColor: hintColor,
                      taskFile: _getFileForCategory('Lampiran A'),
                      onFileChanged: _loadTaskFiles),
                  DocumentCard(
                      uid: _userUid!,
                      title: 'Sijil Tanggung Rugi',
                      subtitle: AppLocalizations.of(context)!.uploadtherequiredfiles,
                      subtitleColor: hintColor,
                      taskFile: _getFileForCategory('Sijil Tanggung Rugi'),
                      onFileChanged: _loadTaskFiles),
                  DocumentCard(
                      uid: _userUid!,
                      title: 'Penyata Bank',
                      subtitle: AppLocalizations.of(context)!.uploadtherequiredfiles,
                      subtitleColor: hintColor,
                      taskFile: _getFileForCategory('Penyata Bank'),
                      onFileChanged: _loadTaskFiles),
                  const SizedBox(height: 32),
                  Text(AppLocalizations.of(context)!.privateDetailsandCerts,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),
                  DocumentCard(
                      uid: _userUid!,
                      title: AppLocalizations.of(context)!.identityCard,
                      subtitle: AppLocalizations.of(context)!.uploadRequired,
                      subtitleColor: hintColor,
                      taskFile: _getFileForCategory(AppLocalizations.of(context)!.identityCard),
                      onFileChanged: _loadTaskFiles),
                  DocumentCard(
                      uid: _userUid!,
                      title: AppLocalizations.of(context)!.drivingLicense,
                      subtitle: AppLocalizations.of(context)!.optional,
                      subtitleColor: hintColor,
                      taskFile: _getFileForCategory(AppLocalizations.of(context)!.drivingLicense),
                      onFileChanged: _loadTaskFiles),
                  DocumentCard(
                      uid: _userUid!,
                      title: AppLocalizations.of(context)!.certificate,
                      subtitle: AppLocalizations.of(context)!.optional,
                      subtitleColor: hintColor,
                      taskFile: _getFileForCategory(AppLocalizations.of(context)!.certificate),
                      onFileChanged: _loadTaskFiles),
                ],
              ),
            ),
    );
  }
}

class DocumentCard extends StatefulWidget {
  final String uid;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Map<String, dynamic>? taskFile;
  final VoidCallback onFileChanged;

  const DocumentCard({
    super.key,
    required this.uid,
    required this.title,
    required this.subtitle,
    required this.onFileChanged,
    this.subtitleColor,
    this.taskFile,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  final TaskManagerService _taskService = TaskManagerService();
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final file = File(result.files.single.path!);
    setState(() => _isUploading = true);

    try {
      await _taskService.uploadTaskFile(file, widget.uid, category: widget.title);
      widget.onFileChanged();
      _showSnackbar('✅ File uploaded successfully.');
    } catch (e) {
      _showSnackbar('❌ Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _openFile() async {
    final fileId = widget.taskFile?['_id'];
    if (fileId == null) {
      _showSnackbar('No file selected.');
      return;
    }
    try {
      await _taskService.openTaskFile(fileId, widget.uid);
    } catch (e) {
      _showSnackbar('❌ $e');
    }
  }

  Future<void> _removeFile() async {
    final fileId = widget.taskFile?['_id'];
    if (fileId == null) return;

    try {
      await _taskService.deleteTaskFile(fileId, widget.uid);
      widget.onFileChanged();
      _showSnackbar('🗑️ File deleted successfully.');
    } catch (e) {
      _showSnackbar('❌ Delete failed: $e');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    final hasFile = widget.taskFile != null;
    final fileName = widget.taskFile?['name'] as String?;
    final icon = _isUploading
        ? Icons.upload_file
        : hasFile
            ? Icons.check_circle
            : Icons.add_circle;
    final iconColor = _isUploading
        ? Colors.blue
        : hasFile
            ? Colors.green
            : hintColor;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                fileName ?? widget.title,
                style: TextStyle(fontSize: 16, color: iconColor),
              ),
            ),
            if (_isUploading)
              const CircularProgressIndicator(strokeWidth: 2)
            else if (hasFile)
              Row(
                children: [
                  IconButton(onPressed: _openFile, icon: const Icon(Icons.visibility)),
                  IconButton(onPressed: _removeFile, icon: const Icon(Icons.delete, color: Colors.red)),
                ],
              )
            else
              OutlinedButton(
                onPressed: _pickFile,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Upload'),
              ),
          ],
        ),
      ),
    );
  }
}
