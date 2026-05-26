import 'dart:async';

import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerAlwaysOpen extends StatefulWidget {
  final String title;
  final FutureOr<String?> Function(String code) onResult;

  /// Changed to allow async

  const ScannerAlwaysOpen({
    super.key,
    required this.title,
    required this.onResult,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required FutureOr<String?> Function(String) onResult,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 400,
              height: 600,
              child: ScannerAlwaysOpen(title: title, onResult: onResult),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<ScannerAlwaysOpen> createState() => _ScannerAlwaysOpenState();
}

class _ScannerAlwaysOpenState extends State<ScannerAlwaysOpen> {
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128],
  );
  final _manualController = TextEditingController();
  bool _showSubmit = false;
  Timer? _duplicateAlertTimer;
  bool _isProcessing = false;
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

    _isProcessing = true;
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
    if (mounted) _isProcessing = false;
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

      _isProcessing = true;
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
      if (mounted) _isProcessing = false;
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
        child: Column(
          children: [
            CustomInspectionHeader(
              heading: widget.title,
              subtitle: 'Scan or enter manually',
              isShowBackIcon: true,
              onBackPress: _close,
              topPadding: 0,
              horizontalPadding: 12,
              widget: CustomOutlinedButton(
                borderColor: Colors.blue,
                label: 'Done',
                fillColor: Colors.blue,
                textColor: Colors.white,
                buttonHeight: 36.0,
                onPressed: () {
                  _close();
                },
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
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
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _errorOverlayText != null
                              ? Colors.red
                              : Colors.blue.withValues(alpha: 0.5),
                          width: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
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
