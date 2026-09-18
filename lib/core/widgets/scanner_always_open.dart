import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerAlwaysOpen extends StatefulWidget {
  final String title;
  final FutureOr<String?> Function(String code) onResult;
  final Widget Function(BuildContext context)? scannedItemsBuilder;
  final bool showDoneButton;

  const ScannerAlwaysOpen({
    super.key,
    required this.title,
    required this.onResult,
    this.scannedItemsBuilder,
    this.showDoneButton = true,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required FutureOr<String?> Function(String code) onResult,
    Widget Function(BuildContext context)? scannedItemsBuilder,
    bool showDoneButton = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ScannerAlwaysOpen(
            title: title,
            onResult: onResult,
            scannedItemsBuilder: scannedItemsBuilder,
            showDoneButton: showDoneButton,
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<ScannerAlwaysOpen> createState() => _ScannerAlwaysOpenState();
}

class _ScannerAlwaysOpenState extends State<ScannerAlwaysOpen> {
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 800,
    cameraResolution: const Size(1920, 1080),
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
  Timer? _duplicateAlertTimer;
  bool _isProcessing = false;
  bool _isValidating = false;
  String? _errorOverlayText;

  String? _lastProcessedCode;
  DateTime? _lastProcessedTime;
  bool _lastScanWasSuccess = false;

  @override
  void initState() {
    super.initState();
    _manualController.addListener(_onManualChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _controller.start();
          debugPrint("SCANNER: Camera Started Manually");
        }
      });
    });
  }

  void _onManualChange() {
    final hasText = _manualController.text.trim().isNotEmpty;
    if (hasText != _showSubmit) setState(() => _showSubmit = hasText);
  }

  void _submitManual() async {
    final text = _manualController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _isValidating = true;
      });
    }
    _manualController.clear();

    String? errorMessage;
    try {
      errorMessage = await widget.onResult(text);
    } catch (e) {
      debugPrint("SCANNER ERROR: $e");
      errorMessage = 'An unexpected error occurred';
    }

    if (errorMessage == null) {
      HapticFeedback.lightImpact();
      _lastScanWasSuccess = true;
      if (mounted) setState(() => _errorOverlayText = null);
    } else {
      HapticFeedback.heavyImpact();
      _lastScanWasSuccess = false;
      if (mounted) setState(() => _errorOverlayText = errorMessage);
      _duplicateAlertTimer?.cancel();
      _duplicateAlertTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _errorOverlayText = null);
      });
    }

    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isValidating = false;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      final now = DateTime.now();

      // Check if we are scanning the exact same code
      if (raw == _lastProcessedCode) {
        // Enforce a 2-second cooldown ONLY if the last scan of this code was a failure.
        // If the last scan was a success (e.g. just added), we allow it to scan again
        // immediately to show the "Already assigned" exception overlay.
        if (!_lastScanWasSuccess &&
            _lastProcessedTime != null &&
            now.difference(_lastProcessedTime!).inMilliseconds < 2000) {
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _isProcessing = true;
          _isValidating = true;
        });
      }
      _lastProcessedCode = raw;
      _lastProcessedTime = now;

      String? errorMessage;
      try {
        errorMessage = await widget.onResult(raw);
      } catch (e) {
        debugPrint("SCANNER ERROR: $e");
        errorMessage = 'An unexpected error occurred';
      }

      if (errorMessage == null) {
        HapticFeedback.lightImpact();
        _lastScanWasSuccess = true;
        _duplicateAlertTimer?.cancel();
        if (mounted) {
          setState(() {
            _errorOverlayText = null;
          });
        }
      } else {
        HapticFeedback.heavyImpact();
        _lastScanWasSuccess = false;
        _duplicateAlertTimer?.cancel();
        if (mounted) {
          setState(() {
            _errorOverlayText = errorMessage;
          });
        }
        _duplicateAlertTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _errorOverlayText = null;
            });
          }
        });
      }

      // Briefly wait to prevent double-triggering in the same instant frame
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isValidating = false;
        });
      }
      break; // Process one barcode per event
    }
  }

  void _close() => Navigator.pop(context);

  @override
  void dispose() {
    _manualController.removeListener(_onManualChange);
    _manualController.dispose();
    _controller.dispose();
    _duplicateAlertTimer?.cancel();
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
                  if (widget.showDoneButton) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _close,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('DONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ] else ...[
                    IconButton(
                      onPressed: _close,
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      splashRadius: 20,
                    ),
                  ],
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
            if (widget.scannedItemsBuilder == null)
              Expanded(
                child: Stack(
                  children: [
                    MobileScanner(controller: _controller, onDetect: _onDetect),

                    // DYNAMIC ERROR OVERLAY
                    if (_errorOverlayText != null)
                      Container(
                        color: Colors.red.withValues(alpha: 0.4),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 80,
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  _errorOverlayText!, // Shows specific validation message
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // SCANNER BORDER (Turns Red on any error)
                    Center(
                      child: Container(
                        width: 320,
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _errorOverlayText != null
                                ? Colors.red
                                : Colors.blue.withValues(alpha: 0.5),
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    // INLINE VALIDATION LOADER (MATCHING APPLOADER DESIGN)
                    if (_isValidating)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                              width: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.all(Radius.circular(16)),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF1B64A3).withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3.0,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                                      backgroundColor: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Please wait...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              // Scanner container with fixed height
              SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    MobileScanner(controller: _controller, onDetect: _onDetect),

                    // DYNAMIC ERROR OVERLAY (Smaller overlay for compact layout)
                    if (_errorOverlayText != null)
                      Container(
                        color: Colors.red.withValues(alpha: 0.4),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  _errorOverlayText!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // SCANNER BORDER (Smaller for the shorter height view)
                    Center(
                      child: Container(
                        width: 220,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _errorOverlayText != null
                                ? Colors.red
                                : Colors.blue.withValues(alpha: 0.5),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    // INLINE VALIDATION LOADER (MATCHING APPLOADER DESIGN)
                    if (_isValidating)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              width: 180,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.all(Radius.circular(14)),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.8,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                                      backgroundColor: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Please wait...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFCFD8DC)),
              // Scanned items view
              Expanded(
                child: Container(
                  color: const Color(0xFFF8FAFC), // Slate-grey background tint for list section
                  child: widget.scannedItemsBuilder!(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
