// lib/screens/task_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';
import 'package:onboardx_app/services/taskmanager_service.dart';
import 'dart:io';

class TaskManagerScreen extends StatelessWidget {
  const TaskManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    const String userUid = 'USER123';

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.taskmanager1, style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppLocalizations.of(context)!.requiredDocuments,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          DocumentCard(uid: userUid, title: 'Lampiran A', subtitle: AppLocalizations.of(context)!.uploadtherequiredfiles, subtitleColor: hintColor),
          DocumentCard(uid: userUid, title: 'Sijil Tanggung Rugi', subtitle: AppLocalizations.of(context)!.uploadtherequiredfiles, subtitleColor: hintColor),
          DocumentCard(uid: userUid, title: 'Penyata Bank', subtitle: AppLocalizations.of(context)!.uploadtherequiredfiles, subtitleColor: hintColor),
          const SizedBox(height: 32),
          Text(AppLocalizations.of(context)!.privateDetailsandCerts,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          DocumentCard(uid: userUid, title: AppLocalizations.of(context)!.identityCard, subtitle: AppLocalizations.of(context)!.uploadRequired, subtitleColor: hintColor),
          DocumentCard(uid: userUid, title: AppLocalizations.of(context)!.drivingLicense, subtitle: AppLocalizations.of(context)!.optional, subtitleColor: hintColor),
          DocumentCard(uid: userUid, title: AppLocalizations.of(context)!.certificate, subtitle: AppLocalizations.of(context)!.optional, subtitleColor: hintColor),
        ],
      ),
    );
  }
}

class DocumentCard extends StatefulWidget {
  final String uid;
  final String title;
  final String subtitle;
  final Color? subtitleColor;

  const DocumentCard({
    super.key,
    required this.uid,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  final TaskManagerService _taskService = TaskManagerService();
  String? _selectedFileName;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final file = File(result.files.single.path!);
    setState(() => _isUploading = true);

    try {
      await _taskService.uploadTaskFile(file, widget.uid, category: widget.title);
      setState(() => _selectedFileName = file.path.split('/').last);
      _showSnackbar('✅ File uploaded successfully.');
    } catch (e) {
      _showSnackbar('❌ Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _openFile() async {
    if (_selectedFileName == null) {
      _showSnackbar('No file selected.');
      return;
    }
    try {
      await _taskService.openTaskFile(_selectedFileName!, widget.uid);
    } catch (e) {
      _showSnackbar('❌ $e');
    }
  }

  Future<void> _removeFile() async {
    if (_selectedFileName == null) return;

    try {
      await _taskService.deleteTaskFile(_selectedFileName!, widget.uid);
      setState(() => _selectedFileName = null);
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

    final hasFile = _selectedFileName != null;
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
                _selectedFileName ?? widget.title,
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
