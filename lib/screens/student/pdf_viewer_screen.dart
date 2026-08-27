import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../../app/theme.dart';
import '../../models/resource.dart';
import '../../services/pdf_service.dart';

typedef PdfDocumentViewerBuilder =
    Widget Function(
      BuildContext context,
      File file,
      VoidCallback onLoaded,
      VoidCallback onFailed,
    );

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.resource,
    this.pdfService,
    this.viewerBuilder,
  });

  final Resource resource;
  final PdfService? pdfService;
  final PdfDocumentViewerBuilder? viewerBuilder;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfService? _defaultPdfService;
  PdfViewSource? _source;
  String? _errorMessage;
  bool _isLoading = true;
  bool _viewerLoaded = false;

  PdfService get _pdfService =>
      widget.pdfService ?? (_defaultPdfService ??= PdfService());

  @override
  void initState() {
    super.initState();
    _preparePdf();
  }

  Future<void> _preparePdf() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _viewerLoaded = false;
        _errorMessage = null;
      });
    }

    await _releaseSource();

    try {
      final source = await _pdfService.preparePdf(widget.resource);
      if (!mounted) {
        await source.dispose();
        return;
      }

      setState(() {
        _source = source;
        _isLoading = false;
        _errorMessage = null;
      });
    } on PdfFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر عرض ملف PDF. حاول مرة أخرى.';
      });
    }
  }

  void _onViewerLoaded() {
    if (!mounted || _viewerLoaded) return;
    setState(() => _viewerLoaded = true);
  }

  void _onViewerFailed() {
    if (!mounted || _errorMessage != null) return;
    final source = _source;
    setState(() {
      _source = null;
      _viewerLoaded = false;
      _errorMessage = 'تعذر عرض ملف PDF. حاول مرة أخرى.';
    });
    if (source != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(source.dispose());
      });
    }
  }

  Future<void> _releaseSource() async {
    final source = _source;
    _source = null;
    _viewerLoaded = false;
    if (source != null) await source.dispose();
  }

  @override
  void dispose() {
    unawaited(_releaseSource());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      key: const Key('pdf-viewer-directionality'),
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            widget.resource.title,
            key: const Key('pdf-viewer-title'),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _PdfLoadingState(key: ValueKey('pdf-loading'));
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _PdfErrorState(
        key: const ValueKey('pdf-error'),
        message: errorMessage,
        onRetry: _preparePdf,
      );
    }

    final source = _source;
    if (source == null) {
      return _PdfErrorState(
        key: const ValueKey('pdf-error'),
        message: 'تعذر عرض ملف PDF. حاول مرة أخرى.',
        onRetry: _preparePdf,
      );
    }

    final viewerBuilder = widget.viewerBuilder ?? _buildNativePdfViewer;
    return Stack(
      key: const ValueKey('pdf-ready'),
      children: [
        Positioned.fill(
          child: viewerBuilder(
            context,
            source.file,
            _onViewerLoaded,
            _onViewerFailed,
          ),
        ),
        if (!_viewerLoaded)
          const Positioned.fill(
            child: ColoredBox(
              color: AppTheme.background,
              child: _PdfLoadingState(),
            ),
          ),
      ],
    );
  }

  Widget _buildNativePdfViewer(
    BuildContext context,
    File file,
    VoidCallback onLoaded,
    VoidCallback onFailed,
  ) {
    return PDFView(
      key: ValueKey(file.path),
      filePath: file.path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      preventLinkNavigation: true,
      backgroundColor: AppTheme.background,
      onRender: (_) => onLoaded(),
      onError: (_) => onFailed(),
      onPageError: (page, error) => onFailed(),
    );
  }
}

class _PdfLoadingState extends StatelessWidget {
  const _PdfLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        key: Key('pdf-loading-content'),
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 14),
          Text(
            'جارٍ تجهيز ملف PDF...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PdfErrorState extends StatelessWidget {
  const _PdfErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.error,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  key: const Key('pdf-error-message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('retry-pdf-button'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
