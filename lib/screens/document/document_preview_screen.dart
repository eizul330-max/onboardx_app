// document_preview_screen.dart
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
  int _totalPages = 0;
  int _currentPage = 1;
  String? _localPath;

  // 🆕 Added for overlay controls
  bool _showOverlay = true;
  int _pagesCount = 0;

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

  Future<void> _loadFile() async {
    final name = widget.document['name'] ?? 'file';
    final cacheDir = await getTemporaryDirectory();
    final cachedPath = '${cacheDir.path}/$name';

    // ✅ Use cached file first
    if (await File(cachedPath).exists()) {
      final bytes = await File(cachedPath).readAsBytes();
      setState(() {
        _fileBytes = bytes;
        _localPath = cachedPath;
        _loading = false;
      });
      await _initPdfIfNeeded(bytes);
      return;
    }

    // 🌐 Otherwise, fetch from backend
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

      await _initPdfIfNeeded(bytes);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _initPdfIfNeeded(Uint8List bytes) async {
    final mime = _getMimeType();
    if (mime == 'application/pdf') {
      final doc = await PdfDocument.openData(bytes);
      setState(() {
        _pdfController = PdfController(document: Future.value(doc));
        _pagesCount = doc.pagesCount;
        _totalPages = doc.pagesCount;
      });
    }
  }

  String _getMimeType() {
    final name = widget.document['name'] ?? '';
    final mime = widget.document['mime_type'] ?? '';

    if (mime.isNotEmpty) return mime;

    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.txt')) return 'text/plain';
    if (name.endsWith('.md')) return 'text/markdown';
    if (name.endsWith('.dart')) return 'text/x-dart';
    if (name.endsWith('.js')) return 'application/javascript';

    return 'application/octet-stream';
  }

  Future<void> _openExternally() async {
    if (_localPath == null) return;
    final result = await OpenFile.open(_localPath!);
    if (result.type != ResultType.done) {
      _showError('Failed to open file: ${result.message}');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _jumpToPage(int page) {
    if (_pdfController == null || page < 1 || page > _totalPages) return;
    _pdfController!.jumpToPage(page);
    setState(() => _currentPage = page);
  }

  // 🆕 Dialog to jump to a specific page
  Future<int?> _showGotoDialog(BuildContext context, int currentPage) async {
    final controller = TextEditingController(text: currentPage.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Go to Page"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Page number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              Navigator.pop(ctx, page);
            },
            child: const Text("Go"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.document['name'] ?? 'Unnamed';
    final mime = _getMimeType();

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text('Error: $_error'));
    } else if (_fileBytes == null) {
      body = const Center(child: Text('No file content available'));
    } else if (mime.startsWith('image/')) {
      body = InteractiveViewer(child: Image.memory(_fileBytes!));
    } else if (mime == 'application/pdf') {
      body = Stack(
        children: [
          PdfView(
            controller: _pdfController!,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
            },
          ),

          // 🆕 Overlay controls for PDF navigation
          if (_showOverlay)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                  top: 8,
                  left: 12,
                  right: 12,
                ),
                color: Colors.black38,
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_left),
                      onPressed:
                          _currentPage > 1 ? () => _jumpToPage(_currentPage - 1) : null,
                    ),
                    Text('$_currentPage / $_pagesCount',
                        style: const TextStyle(color: Colors.white)),
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < _pagesCount
                          ? () => _jumpToPage(_currentPage + 1)
                          : null,
                    ),
                    const Spacer(),
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.keyboard_double_arrow_up),
                      onPressed: () async {
                        final input = await _showGotoDialog(context, _currentPage);
                        if (input != null) _jumpToPage(input);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (mime.startsWith('text/')) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(String.fromCharCodes(_fileBytes!)),
      );
    } else if (name.endsWith('.md')) {
      body = Markdown(data: String.fromCharCodes(_fileBytes!));
    } else if (name.endsWith('.dart') || name.endsWith('.js')) {
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
        ],
      ),
      body: body,
    );
  }
}
