import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/wip/model/wip_group.dart';
import 'package:active_wear_scanning/features/wip/presentation/widgets/locator_expansion_item.dart';
import 'package:active_wear_scanning/features/wip/repo/wip_repo.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:flutter/material.dart';

class WIPScreen extends StatefulWidget {
  const WIPScreen({super.key});

  @override
  State<WIPScreen> createState() => _WIPScreenState();
}

class _WIPScreenState extends State<WIPScreen> {
  final _wipRepo = WipRepo();
  final _batchRepo = BatchRepo();
  List<LocatorResponse> _locators = [];
  Map<int, List<ProductionProgressResponseModel>> _locatorTrays = {};
  Map<int, bool> _loadingDetails = {};

  static final _labelStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87);
  static final _tableHeaderStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchInitialData();
    });
  }

  Future<void> _fetchInitialData() async {
    AppLoader.show(context, message: 'Loading Locators...');
    final result = await _wipRepo.fetchLocators();
    AppLoader.hide(context);

    if (result.success && result.data != null) {
      if (mounted) {
        final allLocs = result.data as List<LocatorResponse>;
        setState(() {
          // Condition: shows only those locators in dropdown whose logicalWH is FLOOR
          _locators = allLocs.where((l) {
            final wh = l.locator.logicalWH?.toUpperCase() ?? '';
            return wh.contains('FLOOR');
          }).toList().reversed.toList();
        });
      }
    } else {
      _showError(result.message);
    }
  }

  Future<void> _fetchWipData(int locatorId) async {
    // If we have data, skip reload for now
    if (_locatorTrays.containsKey(locatorId) && _locatorTrays[locatorId]!.isNotEmpty) return;

    setState(() => _loadingDetails[locatorId] = true);
    final result = await _wipRepo.fetchWipDetails(locatorId);

    if (mounted) {
      if (result.success && result.data != null) {
        final rawList = result.data as List<ProductionProgressResponseModel>;

        // Enrich each tray with correct item details and user-selected machine (for batches)
        final enrichedList = <ProductionProgressResponseModel>[];
        for (final tray in rawList) {
          // 1. Enrich Item Details
          final mainItemId = tray.item.id;
          double perGarmentTube = tray.item.perGarmentTube ?? 0;
          String colorDesc = tray.item.colorDescription ?? '';
          String sizeDesc = tray.item.sizeDescription ?? '';

          if (mainItemId > 0) {
            final itemRes = await _batchRepo.fetchItemDef(mainItemId);
            if (itemRes.success && itemRes.data != null) {
              final d = itemRes.data is Map ? itemRes.data as Map<String, dynamic> : {};
              if (d['perGarmentTube'] != null) perGarmentTube = (d['perGarmentTube'] as num).toDouble();
              if (d['colorDescription'] != null) colorDesc = d['colorDescription'];
              if (d['sizeDescription'] != null) sizeDesc = d['sizeDescription'];
            }
          }

          final updatedItem = tray.item.copyWith(
            perGarmentTube: perGarmentTube,
            colorDescription: colorDesc,
            sizeDescription: sizeDesc,
          );

          // 2. Enrich Machine Details (Crucial for Processing & Knitting)
          MachineModel? finalMachine = tray.machineModel;
          final bhId = tray.productionProgress.batchHeaderId;
          final trayResourceId = tray.primaryTrayModel.resourceId;

          // Case A: Tray is in a Batch (Processing/Dyeing)
          if (bhId != null) {
            final bhRes = await _batchRepo.fetchBatchHeaderById(bhId);
            if (bhRes.success && bhRes.data != null) {
              final bhFull = BatchHeaderResponseModel.fromJson(bhRes.data);
              if (bhFull.machine != null) {
                finalMachine = bhFull.machine;
              } else if (bhFull.batchHeader.machineId != null) {
                final mRes = await _batchRepo.fetchMachineById(bhFull.batchHeader.machineId!);
                if (mRes.success && mRes.data != null) {
                  final mData = mRes.data as Map<String, dynamic>;
                  finalMachine = MachineModel.fromJson(mData['resource'] ?? mData);
                }
              }
            }
          } 
          // Case B: No Batch (Knitting) - Prefer resourceId from PrimaryTrayModel
          // This represents the 'Knitting basic machine' assigned during initial scanning
          else if (trayResourceId != null) {
            final mRes = await _batchRepo.fetchMachineById(trayResourceId);
            if (mRes.success && mRes.data != null) {
              final mData = mRes.data as Map<String, dynamic>;
              finalMachine = MachineModel.fromJson(mData['resource'] ?? mData);
            }
          }

          enrichedList.add(tray.copyWith(
            item: updatedItem,
            machineModel: finalMachine ?? tray.machineModel,
          ));
        }

        setState(() {
          _loadingDetails[locatorId] = false;
          _locatorTrays[locatorId] = enrichedList;
        });
      } else {
        setState(() => _loadingDetails[locatorId] = false);
        _showError(result.message);
      }
    }
  }

  List<WIPGroup> _groupTrays(List<ProductionProgressResponseModel> trays, bool isKnitting, bool isProcessing) {
    final Map<String, WIPGroup> groups = {};

    for (final t in trays) {
      String key;
      if (isKnitting) {
        // Group by WorkOrder + Machine + Item
        final wo = t.workOrderHeader.workOrderCode;
        final machine = t.machineModel.brand ?? t.machineModel.resourceCode ?? '-';
        final item = t.item.description;
        key = "${wo}_${machine}_$item";
        
        if (!groups.containsKey(key)) {
          groups[key] = WIPGroup(title1: wo, title2: machine, subtitle: item, trays: []);
        }
      } else if (isProcessing) {
        // Group by Batch No + Machine + Color (As requested)
        final batch = t.batchHeader?.batchHeaderCode ?? t.productionProgress.batchHeaderId?.toString() ?? '-';
        final machine = t.machineModel.brand ?? t.machineModel.resourceCode ?? '-';
        final color = t.batchHeader?.colorDescription ?? t.item.colorDescription ?? '-';
        key = "${batch}_${machine}_$color";
        
        if (!groups.containsKey(key)) {
          groups[key] = WIPGroup(title1: batch, title2: machine, title3: color, trays: []);
        }
      } else {
        // Default Group by Batch No + Color
        final batch = t.batchHeader?.batchHeaderCode ?? t.productionProgress.batchHeaderId?.toString() ?? '-';
        final color = t.batchHeader?.colorDescription ?? t.item.colorDescription ?? '-';
        key = "${batch}_$color";
        
        if (!groups.containsKey(key)) {
          groups[key] = WIPGroup(title1: batch, title2: color, trays: []);
        }
      }
      groups[key]!.trays.add(t);
    }
    return groups.values.toList();
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPremiumHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _locators.isEmpty
                    ? _buildEmptyLocatorsState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _locators.length,
                        itemBuilder: (context, index) {
                          final loc = _locators[index];
                          final locatorId = loc.locator.id;
                          final trays = _locatorTrays[locatorId] ?? [];
                          final isLoading = _loadingDetails[locatorId] ?? false;
                          final deptCode = loc.department.code.toUpperCase();
                          final isKnitting = deptCode == 'KNITTING';
                          final isProcessing = deptCode == 'PROCESSING';
                          final groupedData = _groupTrays(trays, isKnitting, isProcessing);

                          return LocatorExpansionItem(
                            locator: loc,
                            groupedData: groupedData,
                            isLoading: isLoading,
                            onExpansionChanged: (expanded) {
                              if (expanded) _fetchWipData(locatorId);
                            },
                            onViewDetails: (group) => _showTrayDetailsDialog(group),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
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
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0D47A1), size: 18),
              visualDensity: VisualDensity.compact,
            ),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work In Progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'PHYSICAL INVENTORY MONITORING',
                    style: TextStyle(fontSize: 9, color: Color(0xFF546E7A), fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF0D47A1), size: 20),
            ),
          ],
        ),
      ),
    );
  }


  // Removed _buildLocatorExpansionItem as it was extracted to LocatorExpansionItem.

  Widget _buildEmptyLocatorsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: Colors.blue.shade50),
          const SizedBox(height: 16),
          const Text('No stores or locators found with "FLOOR" logical warehouse.', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }


  // Removed _buildTableHeader and _buildGroupRow as they were extracted to widgets.

  void _showTrayDetailsDialog(WIPGroup group) async {
    bool showTrays = false;
    double? fetchedCapacity;
    
    if (group.trays.isNotEmpty) {
      final machineId = group.trays.first.productionProgress.machineId;
      if (machineId != null) {
        AppLoader.show(context, message: 'Loading Capacity...');
        final res = await _batchRepo.fetchMachineById(machineId);
        AppLoader.hide(context);
        if (res.success && res.data != null) {
          final mData = res.data as Map<String, dynamic>;
          final mJson = mData['resource'] ?? mData;
          fetchedCapacity = double.tryParse(mJson['capacity']?.toString() ?? '');
        }
      }
    }

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'WIP Details',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: anim1,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                double totalWeight = 0;
                double totalPcs = group.totalPcs;
                final Map<String, List<ProductionProgressResponseModel>> byWO = {};
                
                double? machineCapacity = fetchedCapacity;
                if (group.trays.isNotEmpty) {
                   machineCapacity ??= group.trays.first.machineModel.capacity;
                }

                for (final t in group.trays) {
                  final qty = t.productionProgress.primaryQuantity ?? 0;
                  final pw = t.item.pieceWeight ?? 0;
                  totalWeight += qty * pw;
                  final woCode = t.workOrderHeader.workOrderCode ?? 'Unknown WO';
                  byWO.putIfAbsent(woCode, () => []).add(t);
                }

                final remaining = machineCapacity != null ? (machineCapacity - totalWeight) : null;
                final isOverCapacity = remaining != null && remaining < 0;

                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── 1. Instrumentation Header ───────────────────────
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                          color: const Color(0xFF1E293B),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFF0D47A1).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.analytics_rounded, color: Color(0xFF60A5FA), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('BATCH SUMMARY CONSOLE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                                    Text(
                                      '${group.title1} • ${group.title2}${group.title3 != null ? ' • ${group.title3}' : ''}'.toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),

                        // ── 2. HUD Grid Summary ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 3.2,
                            children: [
                              _buildDialogHUD('TOTAL TRAYS', '${group.trayCount}', Icons.layers_rounded, const Color(0xFF0D47A1)),
                              _buildDialogHUD('TOTAL TUBES', totalPcs.toStringAsFixed(0), Icons.numbers_rounded, const Color(0xFF10B981)),
                              _buildDialogHUD('NET WEIGHT', '${totalWeight.toStringAsFixed(1)} g', Icons.scale_rounded, const Color(0xFFF59E0B)),
                              _buildDialogHUD(
                                isOverCapacity ? 'OVER CAPACITY' : 'CAPACITY REM.',
                                remaining != null ? '${remaining.abs().toStringAsFixed(1)} g' : 'N/A',
                                isOverCapacity ? Icons.warning_amber_rounded : Icons.hourglass_bottom_rounded,
                                isOverCapacity ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                              ),
                            ],
                          ),
                        ),

                        // ── 3. Breakdown List ───────────────────────────────
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('WORK ORDER BREAKDOWN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                  const SizedBox(height: 12),
                                  ...byWO.entries.map((woEntry) {
                                    final woTrays = woEntry.value;
                                    double woPcs = 0;
                                    double woWeight = 0;
                                    for (final t in woTrays) {
                                      woPcs += t.productionProgress.primaryQuantity ?? 0;
                                      woWeight += (t.productionProgress.primaryQuantity ?? 0) * (t.item.pieceWeight ?? 0);
                                    }
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                                        title: Text(woEntry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                                        subtitle: Text('${woTrays.length} TRAYS • ${woWeight.toStringAsFixed(1)} g', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                                        children: [
                                          _buildMiniHeader(),
                                          ...woTrays.map((t) => _buildMiniRow(t)),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => setDialogState(() => showTrays = !showTrays),
                                    icon: Icon(showTrays ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
                                    label: Text(showTrays ? 'HIDE DETAILED LOGS' : 'VIEW DETAILED LOGS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: showTrays ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  if (showTrays) ...[
                                    const SizedBox(height: 16),
                                    const Text('INDIVIDUAL TRAY RECORDS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                    const SizedBox(height: 8),
                                    _buildDetailedTrayTable(group.trays),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogHUD(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0), width: 1)),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFFF1F5F9),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('TRAY CODE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
          Expanded(flex: 4, child: Text('ITEM', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
          Expanded(flex: 2, child: Text('WEIGHT', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
        ],
      ),
    );
  }

  Widget _buildMiniRow(ProductionProgressResponseModel t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1)))),
          Expanded(flex: 4, child: Text(t.item.description, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(((t.productionProgress.primaryQuantity ?? 0) * (t.item.pieceWeight ?? 0)).toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _buildDetailedTrayTable(List<ProductionProgressResponseModel> trays) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildMiniHeader(),
          ...trays.map((t) => _buildMiniRow(t)),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, {Color? valueColor}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade600),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  // Removed _buildEmptyState and _WIPGroup as they were extracted.
}
