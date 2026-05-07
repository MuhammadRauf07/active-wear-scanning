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

class _TrayTrackingScreenState extends State<TrayTrackingScreen> {
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

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _trayCodeController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RawKeyboardListener(
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
              horizontalPadding: 12,
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: SectionHeader(
                                title: 'Scanning Section',
                                subtitle: 'Scan a tray QR to track its current state',
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 110,
                              child: CustomOutlinedButton(
                                label: 'Scan Tray',
                                borderColor: Colors.blue,
                                fillColor: Colors.blue,
                                textColor: Colors.white,
                                buttonHeight: 44,
                                onPressed: _openScanner,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_trayDetail != null) ...[
                          const SectionHeader(
                            title: 'Tracking Details',
                            subtitle: 'Information for the identified tray',
                          ),
                          const SizedBox(height: 12),
                          TrayDetailCard(
                            trayDetail: _trayDetail,
                            locatorName: _locatorName,
                          ),
                          const SizedBox(height: 24),
                          const SectionHeader(
                            title: 'Tracking Path',
                            subtitle: 'Real-time production flow visualization',
                          ),
                          const SizedBox(height: 16),
                          ContentCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                PathNode(
                                  icon: Icons.description_outlined,
                                  title: 'Item Description',
                                  value: _itemDescription ?? '-',
                                  color: Colors.blue,
                                  isLast: false,
                                ),
                                PathNode(
                                  icon: Icons.assignment_outlined,
                                  title: 'Work Order',
                                  value: _workOrderDescription ?? 'Not assigned',
                                  color: Colors.indigo,
                                  isLast: false,
                                ),
                                PathNode(
                                  icon: Icons.badge_outlined,
                                  title: 'Batch Code',
                                  value: _batchCode ?? "-",
                                  color: Colors.purple,
                                  isLast: false,
                                ),
                                PathNode(
                                  icon: Icons.palette_outlined,
                                  title: 'Color',
                                  value: _color ?? "-",
                                  color: Colors.pink,
                                  isLast: false,
                                ),
                                PathNode(
                                  icon: Icons.precision_manufacturing_outlined,
                                  title: 'Active Machine',
                                  value: _machineName ?? 'Idle',
                                  color: Colors.teal,
                                  isLast: false,
                                ),
                                PathNode(
                                  icon: Icons.assignment_turned_in_outlined,
                                  title: 'Is Reassigned',
                                  value: _trayDetail?.isReAssigned == true ? 'YES' : 'NO',
                                  color: _trayDetail?.isReAssigned == true ? Colors.green : Colors.grey,
                                  isLast: true,
                                  isHighlight: _trayDetail?.isReAssigned == true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ] else if (_errorMessage != null) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Column(
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 60),
                              child: Column(
                                children: [
                                  Icon(Icons.qr_code_scanner, size: 64, color: Colors.blue.shade100),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Scan a tray QR to view details',
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
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
    );
  }
}
