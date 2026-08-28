import 'dart:async';
import 'dart:io';

import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:flutter/foundation.dart';
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
            CustomInspectionHeader(
              heading: widget.title,
              subtitle: 'Scan or enter manually',
              isShowBackIcon: true,
              onBackPress: _close,
              topPadding: 0,
              horizontalPadding: 12,
              widget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!kIsWeb && !Platform.isWindows)
                    IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.blue),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                  if (widget.showDoneButton)
                    CustomOutlinedButton(
                      borderColor: Colors.blue,
                      label: 'Done',
                      fillColor: Colors.blue,
                      textColor: Colors.white,
                      buttonHeight: 36.0,
                      onPressed: _close,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: InputDecoration(
                        hintText: 'Enter code manually',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_showSubmit)
                    CustomOutlinedButton(
                      label: 'Submit',
                      borderColor: Colors.blue,
                      fillColor: Colors.blue,
                      textColor: Colors.white,
                      onPressed: _submitManual,
                    ),
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

                    // INLINE VALIDATION LOADER
                    if (_isValidating)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                                      backgroundColor: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Validating code...',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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

                    // INLINE VALIDATION LOADER (COMPACT)
                    if (_isValidating)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B64A3)),
                                      backgroundColor: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Validating code...',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
