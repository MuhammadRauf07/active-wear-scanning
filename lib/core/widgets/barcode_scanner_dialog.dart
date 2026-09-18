import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io' show Platform;

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key, this.title = 'Scan Barcode'});

  final String title;

  static Future<String?> show(BuildContext context, {String title = 'Scan Barcode'}) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 12), spreadRadius: 0)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(width: 400, height: 600, child: BarcodeScannerDialog(title: title)),
          ),
        ),
      ),
    );
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 800,
    cameraResolution: const Size(1920, 1080),
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.itf,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.codabar,
      BarcodeFormat.dataMatrix,
    ],
  );

  final _manualController = TextEditingController();
  bool _showSubmit = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _manualController.addListener(_onManualChange);
  }

  void _onManualChange() {
    final show = _manualController.text.trim().isNotEmpty;
    if (show != _showSubmit) setState(() => _showSubmit = show);
  }

  void _submitManual() {
    final text = _manualController.text.trim();
    if (text.isNotEmpty) {
      if (!kIsWeb && !Platform.isWindows) {
        _controller.stop();
      }
      Navigator.pop(context, text);
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '').trim();
        if (cleaned.isNotEmpty) {
          _hasScanned = true;
          await _controller.stop();
          if (mounted) Navigator.pop(context, cleaned);
          break;
        }
      }
    }
  }

  void _close() => Navigator.pop(context);

  @override
  void dispose() {
    _manualController.removeListener(_onManualChange);
    _manualController.dispose();
    if (!kIsWeb && !Platform.isWindows) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Seamless Integrated Dialog Header ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Dark Slate Navy
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF60A5FA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Scan barcode or enter manually',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // ── Compact Manual Input Bar ─────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _manualController,
                        onSubmitted: (_) => _submitManual(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          hintText: 'Enter code manually...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 18, color: Color(0xFF64748B)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_showSubmit) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: _submitManual,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('SUBMIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: (!kIsWeb && Platform.isWindows)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.computer, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('Camera scanner not supported on Windows', style: TextStyle(color: Colors.grey)),
                          const Text('Please enter the code manually above', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        MobileScanner(controller: _controller, onDetect: _onDetect),
                        Center(
                          child: Container(
                            width: 320,
                            height: 160,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.6), width: 3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
