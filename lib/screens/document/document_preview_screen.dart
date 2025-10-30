import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:intl/intl.dart';
import 'package:onboardx_app/services/document_services.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  final String uid;
  final DocumentService documentService;

  const DocumentPreviewScreen({
    super.key,
    required this.document,
    required this.uid,
    required this.documentService,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  Uint8List? _fileBytes;
  bool _loading = true;
  String? _error;
  PdfController? _pdfController;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  /// Load file from cache or backend
  Future<void> _loadFile() async {
    final name = widget.document['name'] ?? 'file';
    final cacheDir = await getTemporaryDirectory();
    final cachedPath = '${cacheDir.path}/$name';

    // ✅ Check local cache first
    if (await File(cachedPath).exists()) {
      final bytes = await File(cachedPath).readAsBytes();
      setState(() {
        _fileBytes = bytes;
        _localPath = cachedPath;
        _loading = false;
      });
      _initPdfIfNeeded(bytes);
      return;
    }

    try {
      final bytes = await widget.documentService.downloadDocument(
        widget.document['_id'],
        widget.uid,
      );

      final file = File(cachedPath);
      await file.writeAsBytes(bytes, flush: true);

      setState(() {
        _fileBytes = bytes;
        _localPath = cachedPath;
        _loading = false;
      });

      _initPdfIfNeeded(bytes);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _initPdfIfNeeded(Uint8List bytes) {
    final mime = widget.document['mime_type'] ?? '';
    if (mime == 'application/pdf') {
      _pdfController = PdfController(document: PdfDocument.openData(bytes));
    }
  }

  Future<void> _openExternally() async {
    if (_localPath == null) return;
    final result = await OpenFile.open(_localPath!);
    if (result.type != ResultType.done) {
      _showError('Failed to open file: ${result.message}');
    }
  }

  Future<void> _shareFile() async {
    if (_localPath == null) return;
    // In a real app, use the "share_plus" package
    _showMessage('Sharing not implemented — install share_plus to enable.');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green));
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
    final doc = widget.document;
    final name = doc['name'] ?? 'Unnamed';
    final mime = doc['mime_type'] ?? '';
    final uploaded =
        doc['created_at'] != null ? DateTime.tryParse(doc['created_at']) : null;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text('Error: $_error'));
    } else if (mime.startsWith('image/')) {
      body = Center(child: InteractiveViewer(child: Image.memory(_fileBytes!)));
    } else if (mime == 'application/pdf') {
      body = PdfView(controller: _pdfController!);
    } else if (mime.startsWith('text/')) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(String.fromCharCodes(_fileBytes!)),
      );
    } else if (name.endsWith('.md')) {
      body = Markdown(data: String.fromCharCodes(_fileBytes!));
    } else if (name.endsWith('.dart') || name.endsWith('.js')) {
      final lang = name.endsWith('.dart') ? dart : javascript;
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HighlightView(
          String.fromCharCodes(_fileBytes!),
          language: name.endsWith('.dart') ? 'dart' : 'javascript',
          theme: githubTheme,
          padding: const EdgeInsets.all(8),
          textStyle: const TextStyle(fontFamily: 'monospace'),
        ),
      );
    } else {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 80, color: Colors.grey),
            const SizedBox(height: 12),
            const Text("Preview not supported"),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in external app'),
              onPressed: _openExternally,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _localPath != null ? _openExternally : null,
            tooltip: 'Open externally',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
            tooltip: 'Share file',
          ),
        ],
      ),
      body: Column(
        children: [
          // 📄 File metadata
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Type: $mime'),
                      if (uploaded != null)
                        Text('Uploaded: ${DateFormat.yMMMd().format(uploaded)}'),
                      Text(
                        'Size: ${_formatFileSize(doc['file_size'])}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
