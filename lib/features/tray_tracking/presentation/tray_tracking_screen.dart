import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/barcode_scanner_dialog.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/features/tray_tracking/controller/tray_tracking_controller.dart';
import 'package:active_wear_scanning/features/tray_tracking/model/tray_tracking_state.dart';

class TrayTrackingScreen extends StatelessWidget {
  const TrayTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrayTrackingController>(
      create: (_) => TrayTrackingController(),
      child: const _TrayTrackingScreenView(),
    );
  }
}

class _TrayTrackingScreenView extends StatefulWidget {
  const _TrayTrackingScreenView();

  @override
  State<_TrayTrackingScreenView> createState() => _TrayTrackingScreenViewState();
}

class _TrayTrackingScreenViewState extends State<_TrayTrackingScreenView> with SingleTickerProviderStateMixin {
  final _barcodeParser = BarcodeBufferParser();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _pulseController.dispose();
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    return _barcodeParser.handleKey(event, (code) {
      _onTrayScanned(code);
    });
  }

  Future<void> _onTrayScanned(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    final controller = context.read<TrayTrackingController>();
    AppLoader.show(context, message: 'Please wait...');

    final error = await controller.onTrayScanned(cleanCode);
    if (!mounted) return;
    AppLoader.hide(context);

    if (error == null) {
      HapticFeedbackHelper.scanSuccess();
    } else {
      HapticFeedbackHelper.scanError();
    }
  }

  void _openScanner() async {
    final code = await BarcodeScannerDialog.show(
      context,
      title: 'Track Tray',
    );
    
    if (code != null && code.isNotEmpty) {
      _onTrayScanned(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrayTrackingController>();
    final state = controller.state;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            CustomInspectionHeader(
              heading: 'Tray Tracking',
              subtitle: 'Track and monitor tray locations',
              isShowBackIcon: true,
              topPadding: 12,
              horizontalPadding: 16,
            ),
            Expanded(
              child: state.isLoading 
                ? const Center(child: _TacticalLoader())
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildScanningConsole(state),
                        const SizedBox(height: 12),
                        Expanded(
                          child: state.trayDetail != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: _buildTrackingDetailsHUD(state),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      flex: 6,
                                      child: _buildTrackingPathPipeline(state),
                                    ),
                                  ],
                                )
                              : state.errorMessage != null
                                  ? Center(
                                      child: _buildEmptyState(
                                        icon: Icons.error_outline_rounded,
                                        title: 'TRAY NOT FOUND',
                                        message: state.errorMessage!,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    )
                                  : Center(
                                      child: _buildEmptyState(
                                        icon: Icons.qr_code_scanner_rounded,
                                        title: 'NO TRAY SCANNED',
                                        message: 'Tap "SCAN TRAY" or use scanner to track tray history',
                                        color: const Color(0xFF0D47A1),
                                        isScanning: true,
                                      ),
                                    ),
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningConsole(TrayTrackingState state) {
    final hasTray = state.trayDetail != null;
    final trayCode = state.trayDetail?.trayCode ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.12), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasTray ? 'CURRENTLY TRACKING' : 'TRAY TRACKING CONSOLE',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasTray ? trayCode : 'Ready to track tray',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: hasTray ? const Color(0xFF0D47A1) : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(
                hasTray ? 'SCAN ANOTHER TRAY' : 'SCAN TRAY',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingDetailsHUD(TrayTrackingState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.12), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          (state.trayDetail?.trayCode ?? '').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildProminentLocator(state.locatorName ?? 'FLOOR'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCompactMetric('QUANTITY', '${state.trayDetail?.trayQuantity?.toInt() ?? 0} PCS', Icons.inventory_2_rounded, const Color(0xFF3B82F6), false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMetric('TYPE', state.trayDetail?.isReAssigned == true ? 'REASSIGN' : 'PRIMARY', Icons.account_tree_rounded, const Color(0xFF8B5CF6), false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProminentLocator(String locator) {
    const baseColor = Color(0xFFF59E0B);
    final bgColor = baseColor.withValues(alpha: 0.06);
    final borderColor = baseColor.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: baseColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: baseColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.location_on_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('CURRENT LOCATOR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFD97706), letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(
                  locator.toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(String label, String value, IconData icon, Color color, bool pulse) {
    final baseColor = color;
    final bgColor = baseColor.withValues(alpha: 0.05);
    final borderColor = baseColor.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pulse)
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                  child: Icon(icon, size: 13, color: baseColor),
                )
              else
                Icon(icon, size: 13, color: baseColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: baseColor.withValues(alpha: 0.8), letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: baseColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingPathPipeline(TrayTrackingState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.12), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Expanded(child: _buildPipelineStep(Icons.description_rounded, 'ITEM DESCRIPTION', state.itemDescription ?? '-', const Color(0xFF3B82F6), true, false)),
          Expanded(child: _buildPipelineStep(Icons.assignment_rounded, 'WORK ORDER', state.workOrderDescription ?? 'NOT ASSIGNED', const Color(0xFF6366F1), false, false)),
          Expanded(child: _buildPipelineStep(Icons.qr_code_rounded, 'BATCH#', state.batchCode ?? "PENDING", const Color(0xFF8B5CF6), false, false)),
          Expanded(child: _buildPipelineStep(Icons.palette_rounded, 'COLOR', state.color ?? "PENDING", const Color(0xFFEC4899), false, false)),
          Expanded(child: _buildPipelineStep(Icons.precision_manufacturing_rounded, 'MACHINE', state.machineName ?? 'IDLE', const Color(0xFF06B6D4), false, true)),
        ],
      ),
    );
  }

  Widget _buildPipelineStep(IconData icon, String label, String value, Color color, bool isFirst, bool isLast) {
    final bgColor = color.withValues(alpha: 0.04);
    final borderColor = color.withValues(alpha: 0.12);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isFirst ? Colors.transparent : color.withValues(alpha: 0.25),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : color.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Icon(icon, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(
                  value.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message, required Color color, bool isScanning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.12), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isScanning)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.04),
                    border: Border.all(color: color.withValues(alpha: 1.0 - _pulseController.value), width: 2),
                  ),
                  child: Icon(icon, size: 36, color: color),
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.05),
              ),
              child: Icon(icon, size: 36, color: color),
            ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TacticalLoader extends StatelessWidget {
  const _TacticalLoader();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
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
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
