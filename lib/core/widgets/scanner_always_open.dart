import 'dart:async';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';

class ScannerAlwaysOpen extends StatefulWidget {
  final String title;
  final String? Function(String code) onResult; // Changed to return bool (true if added, false if duplicate)

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
  final _controller = MobileScannerController();
  String? _duplicateDetectedValue;
  Timer? _duplicateAlertTimer;
  bool _isProcessing = false;
  String? _errorOverlayText;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final code = raw.trim();
        _isProcessing = true;

        // Call the parent validation logic
        final String? errorMessage = widget.onResult(raw.trim());

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

  @override
  void dispose() {
    _controller.dispose();
    _duplicateAlertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          CustomInspectionHeader(
              heading: widget.title,
              subtitle: 'Scanning Trays...',
              isShowBackIcon: true,
              onBackPress: () => Navigator.pop(context),
              topPadding: 0,
              horizontalPadding: 12
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),

                // DYNAMIC ERROR OVERLAY
                if (_errorOverlayText != null)
                  Container(
                    color: Colors.red.withOpacity(0.4),
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
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold
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
                    width: 250, height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _errorOverlayText != null ? Colors.red : Colors.blue.withOpacity(0.5),
                          width: 4
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
    );
  }
}