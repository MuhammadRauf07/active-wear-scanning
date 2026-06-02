import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/utils/barcode_buffer_parser.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/empty_scan_state.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/md_receiving/repo/md_receiving_repo.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';

class MdReceivingScreen extends StatefulWidget {
  const MdReceivingScreen({super.key});

  @override
  State<MdReceivingScreen> createState() => _MdReceivingScreenState();
}

class _MdReceivingScreenState extends State<MdReceivingScreen> {
  final List<PackingInstructionResponseModel> _scannedCartons = [];
  final Map<int, Map<String, dynamic>> _productionProgressMap = {};
  final _mdReceivingRepo = fromPlex<MdReceivingRepo>();

  // Bluetooth Scanner Support
  final _barcodeParser = BarcodeBufferParser();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    return _barcodeParser.handleKey(event, _processBluetoothScan);
  }

  Future<void> _processBluetoothScan(String scannedCode) async {
    final error = await _validateScanCode(scannedCode);
    if (error != null && mounted) {
      _showError(error);
    }
  }

  Future<String?> _validateScanCode(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid scanned code';

    // Verify if already scanned in current session
    final isAlreadyScanned = _scannedCartons.any(
      (item) => item.packingInstructionLineDetail.uniqueId.trim().toLowerCase() == code.toLowerCase(),
    );
    if (isAlreadyScanned) return 'Item already scanned in current session';

    AppLoader.show(context, message: 'Validating Carton unique ID...');
    try {
      // Step 1: Fetch Carton packing instruction details by unique ID
      final result = await _mdReceivingRepo.fetchPackingInstructionByUniqueId(code);
      if (!result.success || result.data == null) {
        return result.message ?? 'Unique ID not found in Packing Instructions';
      }

      final model = PackingInstructionResponseModel.fromJson(
        Map<String, dynamic>.from(result.data),
      );
      final lineDetailId = model.packingInstructionLineDetail.id;

      // Step 2: Query production progresses to verify Carton Packing has been saved
      AppLoader.show(context, message: 'Verifying Carton Packing record...');
      final progressResult = await _mdReceivingRepo.fetchProductionProgress({
        'PackingInstructionLineDetailId': lineDetailId.toString(),
        'SubOperation': 'Packing',
      });

      if (!progressResult.success || progressResult.data == null) {
        return 'Carton Verification Error: ${progressResult.message}';
      }

      final List rawList = progressResult.data is Map ? (progressResult.data['items'] ?? []) : progressResult.data;
      if (rawList.isEmpty) {
        return 'This carton must be scanned and saved in Carton Packing first!';
      }

      // Extract raw productionProgress JSON map to preserve backend audit fields
      final firstItem = rawList.first;
      if (firstItem is! Map) {
        return 'Invalid progress data returned from backend';
      }

      final rawProgress = firstItem.containsKey('productionProgress') 
          ? Map<String, dynamic>.from(firstItem['productionProgress'] as Map) 
          : Map<String, dynamic>.from(firstItem);

      setState(() {
        _scannedCartons.add(model);
        _productionProgressMap[lineDetailId] = rawProgress;
      });
      HapticFeedbackHelper.scanSuccess();
      return null;
    } catch (e) {
      debugPrint("❌ MD Receiving Validation Error: $e");
      return 'Server error validating Carton ID';
    } finally {
      AppLoader.hide(context);
    }
  }

  Future<void> _onScanItem() async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'MD Receiving Scan',
      onResult: (scannedCode) {
        return _validateScanCode(scannedCode);
      },
      scannedItemsBuilder: (context) {
        if (_scannedCartons.isEmpty) {
          return const Center(
            child: Text(
              'No cartons scanned yet',
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: _scannedCartons.length,
          itemBuilder: (context, index) {
            final carton = _scannedCartons[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.orange, size: 20),
                ),
                title: Text(
                  carton.packingInstructionLineDetail.uniqueId.isNotEmpty
                      ? carton.packingInstructionLineDetail.uniqueId
                      : '-',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF263238)),
                ),
                subtitle: Text(
                  'Group: ${carton.packingInstructionHeader.cartonGroup} • Size: ${carton.packingInstructionHeader.sizeDescription} • Packs: ${carton.packingInstructionHeader.packsPerCarton}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                ),
                trailing: Text(
                  '#${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.grey, fontSize: 11),
                ),
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  Future<void> saveMdReceivingData() async {
    if (_scannedCartons.isEmpty) return;

    AppLoader.show(context, message: 'Saving MD receiving logs & WIP transactions...');
    int successCount = 0;
    final List<String> failedItems = [];

    try {
      for (final model in _scannedCartons) {
        final lineDetailId = model.packingInstructionLineDetail.id;
        final rawProgress = _productionProgressMap[lineDetailId];
        if (rawProgress == null) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Missing-cache)');
          continue;
        }

        final int progressId = rawProgress['id'] as int? ?? 0;
        if (progressId == 0) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Invalid-progress-id)');
          continue;
        }

        // ── 1. Update original Production Progress toLocatorId to 14 ──
        final Map<String, dynamic> updatePayload = Map<String, dynamic>.from(rawProgress);
        updatePayload['toLocatorId'] = 14;

        final updateRes = await _mdReceivingRepo.updateProductionProgress(progressId, updatePayload);
        if (!updateRes.success) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Progress-update-fail)');
          continue;
        }

        // ── 2. Create Negative WIP Transaction (locator 13 -> 14) ──
        final negativeWipPayload = {
          'subOperation': 'Locator Transfer',
          'transactionDate': DateTime.now().toIso8601String(),
          'transactionType': 1,
          'operatorDescription': 'system',
          'primaryQuantity': -1.0,
          'secondaryQuantity': -1.0,
          'operationId': 4, // Carton Packing operationId
          'shiftId': 1,
          'locatorId': 13,
          'toLocatorId': 14,
          'packingInstructionLineDetailId': lineDetailId,
          'progressId': progressId,
        };

        final negWipRes = await _mdReceivingRepo.createWipTransaction(negativeWipPayload);
        if (!negWipRes.success) {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Negative-WIP-fail)');
          continue;
        }

        // ── 3. Create Positive WIP Transaction (locator 14 -> null) ──
        final positiveWipPayload = {
          'subOperation': 'MD Receiving',
          'transactionDate': DateTime.now().toIso8601String(),
          'transactionType': 0,
          'operatorDescription': 'system',
          'primaryQuantity': 1.0,
          'secondaryQuantity': 1.0,
          'operationId': 4, // Mapped to 4 per request
          'shiftId': 1,
          'locatorId': 14,
          'toLocatorId': null,
          'packingInstructionLineDetailId': lineDetailId,
          'progressId': progressId,
        };

        final posWipRes = await _mdReceivingRepo.createWipTransaction(positiveWipPayload);
        if (posWipRes.success) {
          successCount++;
        } else {
          failedItems.add('${model.packingInstructionLineDetail.uniqueId} (Positive-WIP-fail)');
        }
      }
    } catch (e) {
      debugPrint("❌ MD Receiving Save Error: $e");
    } finally {
      AppLoader.hide(context);
      if (mounted) {
        if (failedItems.isEmpty && successCount == _scannedCartons.length) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Saved successfully ($successCount carton(s))');
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else if (successCount > 0) {
          _showError(
            "Saved $successCount carton(s) successfully.\n"
            "Failed: ${failedItems.join(', ')}",
          );
        } else {
          _showError("Failed to save MD receiving data.");
        }
      }
    }
  }

  void _showError(String message) {
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }

  bool get _hasScannedItems => _scannedCartons.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Light slate grey
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildMainContentSection(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () {
                HapticFeedbackHelper.buttonClick();
                Navigator.of(context).pop();
              },
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF546E7A),
                backgroundColor: const Color(0xFFECEFF1),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MD Receiving',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'Log incoming MD material items',
                    style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _hasScannedItems
                  ? () {
                      HapticFeedbackHelper.buttonClick();
                      saveMdReceivingData();
                    }
                  : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: _hasScannedItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContentSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SCANNED MD ITEMS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
                    ),
                    Text(
                      '${_scannedCartons.length} Total Items',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF78909C)),
                    ),
                  ],
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedbackHelper.buttonClick();
                      _onScanItem();
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('SCAN ITEM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFCFD8DC), thickness: 1),

          if (_scannedCartons.isEmpty)
            const Expanded(child: EmptyScanState(hasBorder: false))
          else ...[
            _buildTableHeader(),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _scannedCartons.length,
                itemBuilder: (context, index) {
                  final reversedIndex = _scannedCartons.length - 1 - index;
                  final model = _scannedCartons[reversedIndex];
                  final code = model.packingInstructionLineDetail.uniqueId;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      color: reversedIndex.isEven ? Colors.white : const Color(0xFFF8FAFC),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '#${reversedIndex + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey, fontSize: 12),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            code,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              final lineDetailId = model.packingInstructionLineDetail.id;
                              _scannedCartons.removeAt(reversedIndex);
                              _productionProgressMap.remove(lineDetailId);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
        ),
      ),
      child: const Row(
        children: [
          Text('No.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
          SizedBox(width: 16),
          Expanded(child: Text('MD Item Code / Barcode', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF455A64)))),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}
