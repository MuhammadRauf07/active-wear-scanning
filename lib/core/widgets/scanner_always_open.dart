import 'dart:async';

import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerAlwaysOpen extends StatefulWidget {
  final String title;
  final String? Function(String code) onResult; /// Changed to return bool (true if added, false if duplicate)

  const ScannerAlwaysOpen({super.key, required this.title, required this.onResult});

  static Future<void> show(BuildContext context, {required String title, required String? Function(String) onResult}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24, offset: const Offset(0, 12))],
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
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128],
  );
  final _manualController = TextEditingController();
  bool _showSubmit = false;
  Timer? _duplicateAlertTimer;
  bool _isProcessing = false;
  String? _errorOverlayText;

  @override
  void initState() {
    super.initState();
    _manualController.addListener(_onManualChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {_controller.start();
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
      errorMessage = widget.onResult(text);
    } catch (e) {
      debugPrint("SCANNER ERROR: $e");
      errorMessage = 'An unexpected error occurred';
    }

    if (errorMessage == null) {
      HapticFeedback.lightImpact();
      if (mounted) setState(() => _errorOverlayText = null);
    } else {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _errorOverlayText = errorMessage);
      _duplicateAlertTimer?.cancel();
      _duplicateAlertTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _errorOverlayText = null);
      });
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) _isProcessing = false;
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _isProcessing = true;

        // Call the parent validation logic
        String? errorMessage;
        try {
          errorMessage = widget.onResult(raw.trim());
        } catch (e) {
          debugPrint("SCANNER ERROR: $e");
          errorMessage = 'An unexpected error occurred';
        }

        if (errorMessage == null) {
          // SUCCESS
          HapticFeedback.lightImpact();
          setState(() => _errorOverlayText = null);
        } else {
          // ERROR (Any of your 4 conditions)
          HapticFeedback.heavyImpact();
          setState(() => _errorOverlayText = errorMessage); // Set the specific message

          _duplicateAlertTimer?.cancel();
          _duplicateAlertTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) setState(() => _errorOverlayText = null);
          });
        }

        // Wait a bit before allowing the next scan to prevent rapid-fire triggers
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) _isProcessing = false;
      }
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
            CustomInspectionHeader(heading: widget.title, subtitle: 'Scan or enter manually', isShowBackIcon: true, onBackPress: _close, topPadding: 0, horizontalPadding: 12, widget: CustomOutlinedButton(borderColor: Colors.blue, label: 'Done',fillColor: Colors.blue,textColor: Colors.white,buttonHeight: 36.0,onPressed: () {
              _close();}
            ),),
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
                  if (_showSubmit) CustomOutlinedButton(label: 'Submit', borderColor: Colors.blue, fillColor: Colors.blue, textColor: Colors.white, onPressed: _submitManual),
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
                            const Icon(Icons.error_outline, color: Colors.white, size: 80),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _errorOverlayText!, // Shows specific validation message
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                        border: Border.all(color: _errorOverlayText != null ? Colors.red : Colors.blue.withOpacity(0.5), width: 4),
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
