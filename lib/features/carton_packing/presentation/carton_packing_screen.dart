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
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/carton_packing/model/carton_packing_scanned_item.dart';
import 'package:active_wear_scanning/features/carton_packing/presentation/widgets/carton_packing_row.dart';
import 'package:active_wear_scanning/features/carton_packing/repo/carton_packing_repo.dart';

class CartonPackingScreen extends StatefulWidget {
  const CartonPackingScreen({super.key});

  @override
  State<CartonPackingScreen> createState() => _CartonPackingScreenState();
}

class _CartonPackingScreenState extends State<CartonPackingScreen> {
  // Scanned cartons flat list
  final List<PackingInstructionResponseModel> _scannedCartons = [];

  // Active scanned groups and details cache
  final List<PackingInstructionHeader> _activeCartonGroups = [];
  final Map<int, List<PackingInstructionLineResponse>> _groupLinesCache = {};
  int? _expandedGroupId;

  final Set<int> _packedCartonDetailIds = {};
  final Map<int, List<int>> _groupDetailIdsCache = {};

  final _cartonPackingRepo = fromPlex<CartonPackingRepo>();

  // Active Sale Order constraints
  int? _activeSaleOrderId;
  SaleOrderModel? _activeSaleOrder;
  String? _activeCustomerName;

  // Bluetooth Scanner Support
  final _barcodeParser = BarcodeBufferParser();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _fetchPackedCartonIds();
  }

  Future<void> _fetchPackedCartonIds() async {
    try {
      final res = await _cartonPackingRepo.fetchProductionProgress({
        'SubOperation': 'Packing',
      });
      if (res.success && res.data != null) {
        final List rawList = res.data is Map ? (res.data['items'] ?? []) : res.data;
        final Set<int> packedIds = {};
        for (final item in rawList) {
          if (item is Map) {
            final pp = item['productionProgress'] ?? item;
            final id = pp['packingInstructionLineDetailId'] as int?;
            if (id != null) {
              packedIds.add(id);
            }
          }
        }
        setState(() {
          _packedCartonDetailIds.clear();
          _packedCartonDetailIds.addAll(packedIds);
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching packed carton IDs: $e");
    }
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
    final error = await _validateCartonForScan(scannedCode);
    if (error != null && mounted) {
      _showError(error);
    }
  }

  Future<void> _onScanCarton() async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'Carton Packing Scan',
      onResult: (scannedCode) {
        return _validateCartonForScan(scannedCode);
      },
      scannedItemsBuilder: (context) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            if (_scannedCartons.isEmpty) {
              return const Center(
                child: Text(
                  'No cartons scanned yet',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.all(12),
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
                children: [
                  _buildCartonTableHeader(),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _scannedCartons.length,
                      itemBuilder: (context, index) {
                        final reversedIndex = _scannedCartons.length - 1 - index;
                        final model = _scannedCartons[reversedIndex];
                        return CartonPackingRow(
                          index: reversedIndex,
                          item: model,
                          onRemove: () {
                            setState(() {
                              _scannedCartons.removeAt(reversedIndex);

                              // Reset constraint if no cartons are left in checklist
                              if (_scannedCartons.isEmpty) {
                                _activeSaleOrderId = null;
                                _activeSaleOrder = null;
                                _activeCustomerName = null;
                                _activeCartonGroups.clear();
                                _groupLinesCache.clear();
                                _expandedGroupId = null;
                              } else {
                                // Clean up groups if no scanned cartons left for that group
                                final headerId = model.packingInstructionHeader.id;
                                final remains = _scannedCartons.any((c) => c.packingInstructionHeader.id == headerId);
                                if (!remains) {
                                  _activeCartonGroups.removeWhere((g) => g.id == headerId);
                                  _groupLinesCache.remove(headerId);
                                  if (_expandedGroupId == headerId) {
                                    _expandedGroupId = null;
                                  }
                                }
                              }
                            });
                            setSubState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  Future<String?> _validateCartonForScan(String scannedCode) async {
    final code = scannedCode.trim();
    if (code.isEmpty) return 'Invalid carton code';

    // Verify if already scanned
    final isAlreadyScanned = _scannedCartons.any(
      (item) => item.packingInstructionLineDetail.uniqueId.trim().toLowerCase() == code.toLowerCase(),
    );
    if (isAlreadyScanned) return 'Already assigned';

    AppLoader.show(context, message: 'Validating Carton unique ID...');
    try {
      final result = await _cartonPackingRepo.fetchPackingInstructionByUniqueId(code);
      if (result.success && result.data != null) {
        final model = result.data as PackingInstructionResponseModel;
        final header = model.packingInstructionHeader;
        final headerId = header.id;
        final saleOrderId = header.saleOrderMstId;
        final lineDetailId = model.packingInstructionLineDetail.id;

        // Check if already packed/saved in database
        if (_packedCartonDetailIds.contains(lineDetailId)) {
          return 'This carton is already packed and saved!';
        }

        // Restriction Check: Enforce that scanned cartons must belong to the first scanned Sale Order
        if (_activeSaleOrderId != null && saleOrderId != _activeSaleOrderId) {
          return 'Carton belongs to a different Sale Order (Expected: $_activeSaleOrderId, scanned: $saleOrderId)!';
        }

        // If this is the first scanned carton, fetch the Sale Order Master Data & Customer details
        if (_activeSaleOrderId == null) {
          AppLoader.show(context, message: 'Fetching Sale Order Master details...');
          final saleOrderResult = await _cartonPackingRepo.fetchSaleOrderById(saleOrderId);

          if (saleOrderResult.success && saleOrderResult.data != null) {
            final saleOrder = saleOrderResult.data as SaleOrderModel;
            final customerId = saleOrder.customerId;

            AppLoader.show(context, message: 'Fetching Customer details...');
            final customerResult = await _cartonPackingRepo.fetchCustomerById(customerId);

            String customerName = 'Unknown';
            if (customerResult.success && customerResult.data != null) {
              customerName = (customerResult.data as CustomerModel).name;
              if (customerName.isEmpty) {
                customerName = (customerResult.data as CustomerModel).description;
              }
            }

            setState(() {
              _activeSaleOrderId = saleOrderId;
              _activeSaleOrder = saleOrder;
              _activeCustomerName = customerName;
            });
          } else {
            // Graceful fallback
            setState(() {
              _activeSaleOrderId = saleOrderId;
              _activeSaleOrder = SaleOrderModel(
                id: saleOrderId,
                orderNo: header.cartonGroup,
                customerPO: 'PO-$headerId',
              );
              _activeCustomerName = 'Fallback Customer';
            });
          }
        }

        // Fetch lines for this Carton Group if not cached yet
        if (!_groupLinesCache.containsKey(headerId)) {
          AppLoader.show(context, message: 'Loading Carton Group items...');
          final linesResult = await _cartonPackingRepo.fetchPackingInstructionLines(headerId);
          if (linesResult.success && linesResult.data != null) {
            final lines = linesResult.data as List<PackingInstructionLineResponse>;
            setState(() {
              _groupLinesCache[headerId] = lines;
              if (!_activeCartonGroups.any((g) => g.id == headerId)) {
                _activeCartonGroups.add(header);
              }
            });
          }
        }

        // Fetch all details for this Carton Group if not cached yet to compute packed count
        if (!_groupDetailIdsCache.containsKey(headerId)) {
          AppLoader.show(context, message: 'Caching Carton Group details...');
          final detailsResult = await _cartonPackingRepo.fetchPackingInstructionDetailsByHeaderId(headerId);
          if (detailsResult.success && detailsResult.data != null) {
            final details = detailsResult.data as List<PackingInstructionResponseModel>;
            final ids = details.map((d) => d.packingInstructionLineDetail.id).toList();
            setState(() {
              _groupDetailIdsCache[headerId] = ids;
            });
          }
        }

        setState(() {
          _expandedGroupId = headerId;
          _scannedCartons.add(model);
        });
        HapticFeedbackHelper.scanSuccess();
        return null;
      } else {
        return result.message ?? 'Unique ID not found in Packing Instructions';
      }
    } catch (e) {
      debugPrint("❌ Validation Error: $e");
      return 'Server error validating Carton ID';
    } finally {
      AppLoader.hide(context);
    }
  }

  Future<void> saveCartonPackingData() async {
    if (_scannedCartons.isEmpty) return;

    AppLoader.show(context, message: 'Saving carton packing logs & WIP transactions...');
    int successCount = 0;
    final List<String> failedCartons = [];

    try {
      for (final model in _scannedCartons) {
        // ── 1. Create Production Progress ──
        final progressPayload = {
          'subOperation': 'Packing',
          'date': DateTime.now().toIso8601String(),
          'transactionType': 0,
          'operatorDescription': 'system',
          'primaryQuantity': 1.0,
          'secondaryQuantity': 1.0,
          'operationId': 4,
          'shiftId': 1,
          'locatorId': 13,
          'packingInstructionLineDetailId': model.packingInstructionLineDetail.id,
        };

        final res = await _cartonPackingRepo.createProductionProgress(progressPayload);
        if (res.success) {
          // ── 2. Extract Resolved Progress ID ──
          int? progressId;
          final dynamic data = res.data;
          if (data is Map) {
            progressId = data['id'] ?? data['productionProgress']?['id'];
          } else if (data is int) {
            progressId = data;
          }

          // Refetch fallback if progressId is null or 0
          if (progressId == null || progressId == 0) {
            debugPrint("⚠️ ProductionProgress ID is null/0 in immediate response. Fetching via PackingInstructionLineDetailId...");
            final refetchRes = await _cartonPackingRepo.fetchProductionProgress({
              'PackingInstructionLineDetailId': model.packingInstructionLineDetail.id.toString(),
            });
            if (refetchRes.success && refetchRes.data != null) {
              final List rawList = refetchRes.data is Map ? (refetchRes.data['items'] ?? []) : refetchRes.data;
              if (rawList.isNotEmpty && rawList.first is Map) {
                final firstItem = rawList.first;
                if (firstItem.containsKey('productionProgress')) {
                  progressId = firstItem['productionProgress']?['id'] as int?;
                } else {
                  progressId = firstItem['id'] as int?;
                }
                debugPrint("✅ Re-fetched ProductionProgress ID: $progressId");
              }
            }
          }

          // ── 3. Create WIP Transaction ──
          final wipPayload = {
            'subOperation': 'Packing',
            'transactionDate': DateTime.now().toIso8601String(),
            'transactionType': 0,
            'operatorDescription': 'system',
            'primaryQuantity': 1.0,
            'secondaryQuantity': 1.0,
            'operationId': 4,
            'shiftId': 1,
            'locatorId': 13,
            'packingInstructionLineDetailId': model.packingInstructionLineDetail.id,
            if (progressId != null && progressId > 0) 'progressId': progressId,
          };

          final wipRes = await _cartonPackingRepo.createWipTransaction(wipPayload);
          if (wipRes.success) {
            successCount++;
          } else {
            failedCartons.add('${model.packingInstructionLineDetail.uniqueId} (WIP-fail)');
          }
        } else {
          failedCartons.add('${model.packingInstructionLineDetail.uniqueId} (PP-fail)');
        }
      }
    } catch (e) {
      debugPrint("❌ Carton Packing Save Error: $e");
    } finally {
      AppLoader.hide(context);
      if (mounted) {
        if (failedCartons.isEmpty && successCount == _scannedCartons.length) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Saved successfully ($successCount carton(s))');
          await _fetchPackedCartonIds();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        } else if (successCount > 0) {
          _showError(
            "Saved $successCount carton(s) successfully.\n"
            "Failed cartons: ${failedCartons.join(', ')}",
          );
        } else {
          _showError("Failed to save carton packing data.");
        }
      }
    }
  }

  void _showError(String message) {
    HapticFeedbackHelper.scanError();
    AppSnackBar.showError(context, message: message);
  }

  bool get _hasScannedCartons => _scannedCartons.isNotEmpty;

  // UOM Helper mapping from the C# Enum
  String _getUomString(int uomValue) {
    switch (uomValue) {
      case 0:
        return 'Pack';
      case 1:
        return 'Pc';
      case 2:
        return 'Kg';
      case 3:
        return 'No';
      case 4:
        return 'Tube';
      case 5:
        return 'CM';
      case 6:
        return 'M';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Light slate grey background
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
            const CustomBackButton(),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carton Packing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'Modular Carton Packing HUD',
                    style: TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _hasScannedCartons
                  ? () {
                      HapticFeedbackHelper.buttonClick();
                      saveCartonPackingData();
                    }
                  : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: _hasScannedCartons),
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
                      'SCANNED CARTONS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
                    ),
                    Text(
                      '${_scannedCartons.length} Total Cartons',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF78909C)),
                    ),
                  ],
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedbackHelper.buttonClick();
                      _onScanCarton();
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('SCAN CARTON', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
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
            // Sale Order Master Specs Card
            _buildSaleOrderMasterCard(),
            
            const Divider(height: 1, color: Color(0xFFCFD8DC), thickness: 1.5),

            // Top Section: Carton Group Specifications with items pack ratio breakdown
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'CARTON GROUP SPECIFICATIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
              ),
            ),
            Expanded(
              flex: 4,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _activeCartonGroups.length,
                itemBuilder: (context, index) {
                  final group = _activeCartonGroups[index];
                  final isExpanded = _expandedGroupId == group.id;
                  final lines = _groupLinesCache[group.id] ?? [];

                  return _buildCartonGroupSpecsPanel(group, lines, isExpanded);
                },
              ),
            ),

            const Divider(height: 1, color: Color(0xFFCFD8DC), thickness: 1.5),

            // Bottom Section: Scanned Carton checklist history table
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'CARTON SCAN CHECKLIST',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5),
              ),
            ),
            _buildCartonTableHeader(),
            Expanded(
              flex: 3,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _scannedCartons.length,
                itemBuilder: (context, index) {
                  final reversedIndex = _scannedCartons.length - 1 - index;
                  final model = _scannedCartons[reversedIndex];

                  return CartonPackingRow(
                    index: reversedIndex,
                    item: model,
                    onRemove: () {
                      setState(() {
                        _scannedCartons.removeAt(reversedIndex);

                        // Reset constraint if no cartons are left in checklist
                        if (_scannedCartons.isEmpty) {
                          _activeSaleOrderId = null;
                          _activeSaleOrder = null;
                          _activeCustomerName = null;
                          _activeCartonGroups.clear();
                          _groupLinesCache.clear();
                          _expandedGroupId = null;
                        } else {
                          // Clean up groups if no scanned cartons left for that group
                          final headerId = model.packingInstructionHeader.id;
                          final remains = _scannedCartons.any((c) => c.packingInstructionHeader.id == headerId);
                          if (!remains) {
                            _activeCartonGroups.removeWhere((g) => g.id == headerId);
                            _groupLinesCache.remove(headerId);
                            if (_expandedGroupId == headerId) {
                              _expandedGroupId = null;
                            }
                          }
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaleOrderMasterCard() {
    if (_activeSaleOrder == null) return const SizedBox();

    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return '-';
      return dateStr.split('T')[0].split(' ')[0];
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_rounded, color: Color(0xFF0D47A1), size: 16),
              SizedBox(width: 8),
              Text(
                'SALE ORDER MASTER DATA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D47A1),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSpecsCard('ORDER NO', _activeSaleOrder!.orderNo, Icons.qr_code_rounded),
              const SizedBox(width: 8),
              _buildSpecsCard('CUSTOMER PO', _activeSaleOrder!.customerPO, Icons.receipt_long_rounded),
              const SizedBox(width: 8),
              _buildSpecsCard('CUSTOMER NAME', _activeCustomerName ?? '-', Icons.person_rounded),
              const SizedBox(width: 8),
              _buildSpecsCard('SHIPMENT DATE', formatDate(_activeSaleOrder!.shipmentDate), Icons.local_shipping_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartonGroupSpecsPanel(PackingInstructionHeader header, List<PackingInstructionLineResponse> lines, bool isExpanded) {
    final headerId = header.id;
    
    // Count scanned cartons (database packed + session scanned) belonging to this group
    final detailIds = _groupDetailIdsCache[headerId] ?? [];
    final dbPackedCount = detailIds.where((id) => _packedCartonDetailIds.contains(id)).length;
    final sessionScannedCount = _scannedCartons.where((c) => c.packingInstructionHeader.id == headerId).length;
    final totalScannedCount = dbPackedCount + sessionScannedCount;
    
    final weightUom = _getUomString(header.weight.toInt());
    final dimsUom = _getUomString(header.measurementUom);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFD8DC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accordion Header Panel
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedGroupId == headerId) {
                  _expandedGroupId = null;
                } else {
                  _expandedGroupId = headerId;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Color(0xFF1B64A3), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header.cartonGroup,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalScannedCount / ${header.noCartons} Cartons Scanned',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C)),
                        ),
                      ],
                    ),
                  ),
                  if (lines.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF90CAF9), width: 1),
                      ),
                      child: Text(
                        '${lines.length} ${lines.length == 1 ? 'Item' : 'Items'}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF1B64A3),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Collapsible Expanded Panel Content
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFCFD8DC)),
            // ── Spec Grid Cards ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _buildSpecsCard('NET WEIGHT', '${header.netWeight.toStringAsFixed(1)} $weightUom', Icons.scale_rounded),
                      const SizedBox(width: 8),
                      _buildSpecsCard('GROSS WEIGHT', '${header.grossWeight.toStringAsFixed(1)} $weightUom', Icons.scale_rounded),
                      const SizedBox(width: 8),
                      _buildSpecsCard('DIMENSIONS', '${header.length.toStringAsFixed(0)}x${header.width.toStringAsFixed(0)}x${header.height.toStringAsFixed(0)} $dimsUom', Icons.aspect_ratio_rounded),
                      const SizedBox(width: 8),
                      _buildSpecsCard('TOTAL ITEMS', '${lines.length}', Icons.layers_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // ── Pack Ratio & Items Breakdown Table Title ──
                  const Text(
                    'PACK RATIO & ITEMS BREAKDOWN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF546E7A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Table Container
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Sub-table Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: const Color(0xFFF1F5F9),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('COLOR', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('SIZE', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('PACK RATIO', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              ),
                            ],
                          ),
                        ),
                        // Sub-table Items
                        if (lines.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: const Text('No items defined.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          )
                        else
                          ...lines.map((line) {
                            final idx = lines.indexOf(line);
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                border: Border(
                                  top: BorderSide(color: const Color(0xFFE2E8F0), width: idx == 0 ? 0 : 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      line.itemDef.description,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF263238)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECEFF1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          line.itemDef.colorDescription,
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF455A64)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F4C3),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          line.itemDef.sizeDescription,
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF827717)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '1 : ${line.packingInstructionLine.packRatio}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecsCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: const Color(0xFF1B64A3)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartonTableHeader() {
    const headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Color(0xFF455A64), // Slate Grey
      letterSpacing: 0.2,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Very light slate blue/grey
        border: Border(
          bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('Carton ID', style: headerStyle),
          ),
          Expanded(
            flex: 4,
            child: Text('Carton Group', textAlign: TextAlign.center, style: headerStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('Packs/Carton', textAlign: TextAlign.center, style: headerStyle),
          ),
          SizedBox(width: 44), // space for delete action icon
        ],
      ),
    );
  }
}
