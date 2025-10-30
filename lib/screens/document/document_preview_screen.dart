//document_preview_screen.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
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
    try {
      final bytes = await widget.documentService.downloadDocument(
        widget.document['_id'],
        widget.uid,
      );

      if (!mounted) return;

      setState(() {
        _fileBytes = bytes;
        _loading = false;
      });

      final mime = widget.document['mime_type'] ?? '';
      if (mime == 'application/pdf') {
        _pdfController = PdfController(
          document: PdfDocument.openData(bytes),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openExternally() async {
    try {
      final dir = await getTemporaryDirectory();
      final name = widget.document['name'] ?? 'file';
      final path = '${dir.path}/$name';
      final file = File(path);
      await file.writeAsBytes(_fileBytes!, flush: true);

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        _showError('Failed to open file: ${result.message}');
      }
    } catch (e) {
      _showError('Error opening externally: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.document['name'] ?? 'Unnamed';
    final mime = widget.document['mime_type'] ?? '';

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text('Error: $_error'));
    } else if (mime.startsWith('image/')) {
      body = Center(child: Image.memory(_fileBytes!));
    } else if (mime == 'application/pdf') {
      body = PdfView(controller: _pdfController!);
    } else if (mime.startsWith('text/')) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(String.fromCharCodes(_fileBytes!)),
      );
    } else {
      // Unsupported file type → open externally
      body = Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open in external app'),
          onPressed: _openExternally,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: body,
    );
  }
}
