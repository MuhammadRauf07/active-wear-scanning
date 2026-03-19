import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.all, BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.qrCode],
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
      _controller.stop();
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomInspectionHeader(heading: widget.title, subtitle: 'Scan or enter manually', isShowBackIcon: true, onBackPress: _close, topPadding: 0, horizontalPadding: 12, widget: CustomOutlinedButton(borderColor: Colors.blue, label: 'Done',fillColor: Colors.blue,textColor: Colors.white,buttonHeight: 36.0,onPressed: () {_close();}
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
              child: MobileScanner(controller: _controller, onDetect: _onDetect),
            ),
          ],
        ),
      ),
    );
  }
}
