import 'package:flutter/services.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/barcode_scanner_dialog.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/tray_tracking/model/tray_tracking_model.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/features/tray_tracking/repo/tray_tracking_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/tray_tracking/presentation/widgets/path_node.dart';
import 'package:active_wear_scanning/features/tray_tracking/presentation/widgets/status_badge.dart';
import 'package:active_wear_scanning/features/tray_tracking/presentation/widgets/tray_detail_card.dart';
import 'package:flutter/material.dart';

class TrayTrackingScreen extends StatefulWidget {
  const TrayTrackingScreen({super.key});

  @override
  State<TrayTrackingScreen> createState() => _TrayTrackingScreenState();
}

class _TrayTrackingScreenState extends State<TrayTrackingScreen> with SingleTickerProviderStateMixin {
  final _trayTrackingRepo = TrayTrackingRepo();
  final _trayCodeController = TextEditingController();
  bool _isLoading = false;
  TrayDetail? _trayDetail;
  String? _batchCode;
  String? _color;
  String? _locatorName;
  String? _machineName;
  String? _itemDescription;
  String? _workOrderDescription;
  String? _errorMessage;

  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;


  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final now = DateTime.now();
      if (_lastKeyPress != null && now.difference(_lastKeyPress!).inMilliseconds > 200) {
        _barcodeBuffer = '';
      }
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          final code = _barcodeBuffer;
          _barcodeBuffer = '';
          _onTrayScanned(code);
        }
      } else if (event.character != null) {
        _barcodeBuffer += event.character!;
      }
    }
  }

  Future<String?> _onTrayScanned(String code) async {
    if (code.trim().isEmpty) return "Please enter tray code";
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _trayCodeController.text = code;
    });

    final res = await _trayTrackingRepo.fetchTrayDetailByCode(code.trim());
    
    setState(() => _isLoading = false);

    if (res.success && res.data != null) {
      setState(() {
      final data = res.data is Map ? res.data as Map : {};
      final trayMap = data['trayDetail'] ?? data;
      _trayDetail = TrayTrackingDetailModel.fromJson(Map<String, dynamic>.from(trayMap));
      
      final batchMap = data['batchHeader'];
        if (batchMap is Map) {
          _batchCode = batchMap['batchHeaderCode'];
          _color = batchMap['colorDescription'];
        } else {
          _batchCode = null;
          _color = null;
        }

        _locatorName = data['locator']?['description'];
        _machineName = data['resource']?['resourceCode'] ?? data['resource']?['brand'] ?? data['resource']?['description'];
        _itemDescription = data['knitItem']?['description'] ?? trayMap['description'];
        _workOrderDescription = data['workOrderHeader']?['description'];
      });
      return null;
    } else {
      setState(() {
        _trayDetail = null;
        _batchCode = null;
        _color = null;
        _locatorName = null;
        _machineName = null;
        _itemDescription = null;
        _workOrderDescription = null;
        _errorMessage = res.message;
      });
      return res.message ?? "Tray not found";
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

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _focusNode.dispose();
    _trayCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100 Background
      body: Stack(
        children: [
          // ── Background Layer: Technical Grid ─────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _TechnicalGridPainter()),
          ),

          RawKeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKey: _onKey,
            child: SafeArea(
              child: Column(
                children: [
                  CustomInspectionHeader(
                    heading: 'Tray Tracking',
                    subtitle: 'Track and monitor tray locations',
                    isShowBackIcon: true,
                    topPadding: 10,
                    horizontalPadding: 16,
                  ),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: _TacticalLoader())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SectionHeader(
                                title: 'Scanning Section',
                                subtitle: 'Scan a tray QR to track its current state',
                              ),
                              const SizedBox(height: 12),
                              _buildScanningConsole(),
                              
                              const SizedBox(height: 24),

                              if (_trayDetail != null) ...[
                                const SectionHeader(
                                  title: 'Tracking Details',
                                  subtitle: 'Information for the identified tray',
                                ),
                                const SizedBox(height: 12),
                                _buildTrackingDetailsHUD(),
                                
                                const SizedBox(height: 24),

                                const SectionHeader(
                                  title: 'Tracking Path',
                                  subtitle: 'Real-time production flow visualization',
                                ),
                                const SizedBox(height: 16),
                                _buildTrackingPathPipeline(),
                              ] else if (_errorMessage != null) ...[
                                _buildEmptyState(
                                  icon: Icons.error_outline_rounded,
                                  title: 'TRAY NOT FOUND',
                                  message: _errorMessage!,
                                  color: const Color(0xFFEF4444),
                                ),
                              ] else ...[
                                _buildEmptyState(
                                  icon: Icons.qr_code_scanner_rounded,
                                  title: 'AWAITING SCAN',
                                  message: 'Scan a tray QR to view details',
                                  color: const Color(0xFF3B82F6),
                                  isScanning: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningConsole() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Center(
                child: TextField(
                  controller: _trayCodeController,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  decoration: const InputDecoration(
                    hintText: 'ENTER TRAY CODE...',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) => _onTrayScanned(val),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('SCAN TRAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingDetailsHUD() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Color(0xFF3B82F6), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    _trayCodeController.text.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                ),
                child: const Text('ACTIVE LOGISTICS SIGNAL', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildDetailTile('CURRENT STATUS', 'ONLINE', Icons.radar_rounded, const Color(0xFF10B981), true),
            _buildDetailTile('TRAY QUANTITY', '${_trayDetail?.trayQuantity?.toInt() ?? 0} UNITS', Icons.inventory_2_rounded, const Color(0xFF3B82F6), false),
            _buildDetailTile('LOCATOR NAME', _locatorName ?? 'FLOOR', Icons.location_on_rounded, const Color(0xFFF59E0B), false),
            _buildDetailTile('PROCESS TYPE', _trayDetail?.isReAssigned == true ? 'REASSIGNED' : 'PRIMARY', Icons.account_tree_rounded, const Color(0xFF8B5CF6), false),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailTile(String label, String value, IconData icon, Color color, bool pulse) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          if (pulse)
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
              child: Icon(icon, size: 20, color: color),
            )
          else
            Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingPathPipeline() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          _buildPipelineStep(Icons.description_rounded, 'ITEM DESCRIPTION', _itemDescription ?? '-', const Color(0xFF3B82F6), false),
          _buildPipelineStep(Icons.assignment_rounded, 'WORK ORDER', _workOrderDescription ?? 'NOT ASSIGNED', const Color(0xFF6366F1), false),
          _buildPipelineStep(Icons.qr_code_rounded, 'BATCH CODE', _batchCode ?? "PENDING", const Color(0xFF8B5CF6), false),
          _buildPipelineStep(Icons.palette_rounded, 'COLOR', _color ?? "PENDING", const Color(0xFFEC4899), false),
          _buildPipelineStep(Icons.precision_manufacturing_rounded, 'ACTIVE MACHINE', _machineName ?? 'IDLE', const Color(0xFF06B6D4), true),
        ],
      ),
    );
  }

  Widget _buildPipelineStep(IconData icon, String label, String value, Color color, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withValues(alpha: 0.3), Colors.transparent],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(value.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message, required Color color, bool isScanning = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          if (isScanning)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 1.0 - _pulseController.value), width: 2),
                  ),
                  child: Icon(icon, size: 48, color: color.withValues(alpha: 0.5)),
                );
              },
            )
          else
            Icon(icon, size: 64, color: color.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color.withValues(alpha: 0.8), letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B), height: 1.6)),
        ],
      ),
    );
  }
}

class _TechnicalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.02)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    paint.color = const Color(0xFF1E293B).withValues(alpha: 0.01);
    for (double i = 0; i < size.width; i += 10) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 10) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TacticalLoader extends StatelessWidget {
  const _TacticalLoader();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D47A1)),
        ),
        const SizedBox(height: 24),
        Text(
          'ESTABLISHING TELEMETRY LINK...',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0D47A1).withValues(alpha: 0.7), letterSpacing: 1.5),
        ),
      ],
    );
  }
}

