import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/wip/repo/wip_repo.dart';
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

        // Enrich each tray with perGarmentTube from item-defs
        final enrichedList = <ProductionProgressResponseModel>[];
        for (final tray in rawList) {
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
          enrichedList.add(tray.copyWith(item: updatedItem));
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

  List<_WIPGroup> _groupTrays(List<ProductionProgressResponseModel> trays, bool isKnitting) {
    final Map<String, _WIPGroup> groups = {};

    for (final t in trays) {
      String key;
      if (isKnitting) {
        // Group by WorkOrder + Machine + Item
        final wo = t.workOrderHeader.workOrderCode;
        final machine = t.machineModel.brand ?? t.machineModel.resourceCode ?? '-';
        final item = t.item.description;
        key = "${wo}_${machine}_$item";
        
        if (!groups.containsKey(key)) {
          groups[key] = _WIPGroup(title1: wo, title2: machine, subtitle: item, trays: []);
        }
      } else {
        // Group by Batch No + Color
        final batch = t.batchHeader?.batchHeaderCode ?? t.productionProgress.batchHeaderId?.toString() ?? '-';
        final color = t.batchHeader?.colorDescription ?? '-';
        key = "${batch}_$color";
        
        if (!groups.containsKey(key)) {
          groups[key] = _WIPGroup(title1: batch, title2: color, trays: []);
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CustomInspectionHeader(
              heading: 'WIP',
              subtitle: 'Work In Progress Monitoring',
              isShowBackIcon: true,
              topPadding: 0,
              horizontalPadding: 16,
            ),
            const SizedBox(height: 12),
            // const Padding(
            //   padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            //   child: SectionHeader(
            //     title: 'Stores & Locators',
            //     subtitle: 'Expand a locator to view physical inventory in that area',
            //   ),
            // ),
            Expanded(
              child: _locators.isEmpty
                  ? _buildEmptyLocatorsState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _locators.length,
                      itemBuilder: (context, index) => _buildLocatorExpansionItem(_locators[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocatorExpansionItem(LocatorResponse loc) {
    final locatorId = loc.locator.id;
    final trays = _locatorTrays[locatorId] ?? [];
    final isLoading = _loadingDetails[locatorId] ?? false;
    final deptCode = loc.department.code.toUpperCase();
    final isKnitting = deptCode == 'KNITTING';
    final isProcessing = deptCode == 'PROCESSING';
    
    final groupedData = _groupTrays(trays, isKnitting);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            if (expanded) _fetchWipData(locatorId);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warehouse_outlined, size: 20, color: Colors.blue.shade700),
          ),
          title: Text(
            loc.locator.description,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
          ),
          subtitle: Text(
            'Dept: ${loc.department.name}',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade400, fontWeight: FontWeight.w500),
          ),
          trailing: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade200),
          children: [
            if (groupedData.isEmpty && !isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: _buildEmptyState(),
              )
            else ...[
              const Divider(height: 1),
              _buildTableHeader(isKnitting, isProcessing),
              ...List.generate(groupedData.length, (idx) {
                return _buildGroupRow(idx, groupedData[idx], isKnitting, isProcessing);
              }),
              const SizedBox(height: 12),
            ]
          ],
        ),
      ),
    );
  }

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


  Widget _buildTableHeader(bool isKnitting, bool isProcessing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text('WORK ORDER', style: _tableHeaderStyle)),
            Expanded(flex: 3, child: Text('MACHINE', style: _tableHeaderStyle)),
            Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle)),
          ] else ...[
            Expanded(flex: 4, child: Text('BATCH NO', style: _tableHeaderStyle)),
            Expanded(flex: 4, child: Text('COLOR', style: _tableHeaderStyle)),
          ],
          Expanded(flex: 2, child: Text('TRAYS', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle)),
          const SizedBox(width: 40), // Space for action button
        ],
      ),
    );
  }

  Widget _buildGroupRow(int index, _WIPGroup group, bool isKnitting, bool isProcessing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        color: index.isEven ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text(group.title1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            Expanded(flex: 3, child: Text(group.title2, style: const TextStyle(fontSize: 11))),
            Expanded(flex: 4, child: Text(group.subtitle ?? '-', style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ] else ...[
            Expanded(flex: 4, child: Text(group.title1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            Expanded(flex: 4, child: Text(group.title2, style: const TextStyle(fontSize: 11))),
          ],
          Expanded(flex: 2, child: Text(group.trayCount.toString(), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(group.totalPcs.toInt().toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, size: 20, color: Colors.blue),
            onPressed: () => _showTrayDetailsDialog(group),
            tooltip: 'View Tray Details',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  void _showTrayDetailsDialog(_WIPGroup group) async {
    bool showTrays = false;
    double? fetchedCapacity;
    
    // ── Fetch Machine Capacity ──────────────────────────────────────────────
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
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                // ── Compute Aggregates ───────────────────────────────────────
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── 1. Premium Header (STAY VISIBLE) ────────────────
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade700, Colors.blue.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Batch Summary',
                                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                    Text(
                                      '${group.title1} • ${group.title2}',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
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

                        // ── 2. Sticky Stat Cards (STAY VISIBLE) ──────────────
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                _statTile('No. of Trays', '${group.trayCount}', Icons.layers_outlined),
                                _verticalDivider(),
                                _statTile('Total Tubes', totalPcs.toStringAsFixed(0), Icons.format_list_numbered),
                                _verticalDivider(),
                                _statTile('Weight', totalWeight.toStringAsFixed(1), Icons.scale_outlined),
                                if (machineCapacity != null && machineCapacity > 0) ...[
                                  _verticalDivider(),
                                  _statTile(
                                    isOverCapacity ? 'Over By' : 'Remaining',
                                    remaining!.abs().toStringAsFixed(1),
                                    isOverCapacity ? Icons.warning_amber_rounded : Icons.hourglass_empty,
                                    valueColor: isOverCapacity ? Colors.red.shade700 : Colors.blue.shade700,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // ── 3. Scrollable Body (Expansion Tiles + Tray Table) ─
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Work Order Breakdown ─────────────────────────
                                Text(
                                  'Work Order Breakdown',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                ),
                                const SizedBox(height: 12),
                                ...byWO.entries.map((woEntry) {
                                  final woCode = woEntry.key;
                                  final woTrays = woEntry.value;

                                  final Map<String, List<ProductionProgressResponseModel>> byItem = {};
                                  double woPcs = 0;
                                  double woWeight = 0;
                                  for (final t in woTrays) {
                                    final qty = t.productionProgress.primaryQuantity ?? 0;
                                    final pw = t.item.pieceWeight ?? 0;
                                    woPcs += qty;
                                    woWeight += qty * pw;
                                    final itemDesc = t.item.description;
                                    byItem.putIfAbsent(itemDesc, () => []).add(t);
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade50),
                                      boxShadow: [
                                        BoxShadow(color: Colors.blue.shade100.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Theme(
                                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                      child: ExpansionTile(
                                        backgroundColor: Colors.blue.shade50.withValues(alpha: 0.2),
                                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        title: Text(woCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        subtitle: Text(
                                          '${woTrays.length} Trays • ${woPcs.toStringAsFixed(0)} Tubes • ${woWeight.toStringAsFixed(1)} g',
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                                        ),
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            color: Colors.grey.shade50,
                                            child: Row(
                                              children: [
                                                Expanded(flex: 5, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle)),
                                                Expanded(flex: 2, child: Text('TRAYS', style: _tableHeaderStyle)),
                                                Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle)),
                                                Expanded(flex: 3, child: Text('WEIGHT', style: _tableHeaderStyle)),
                                              ],
                                            ),
                                          ),
                                          ...byItem.entries.map((itemEntry) {
                                            final itemDesc = itemEntry.key;
                                            final itemTrays = itemEntry.value;
                                            double iPcs = 0;
                                            double iWeight = 0;
                                            for (final it in itemTrays) {
                                              final qty = it.productionProgress.primaryQuantity ?? 0;
                                              iPcs += qty;
                                              iWeight += qty * (it.item.pieceWeight ?? 0);
                                            }
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 5, child: Text(itemDesc, style: const TextStyle(fontSize: 11, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                                  Expanded(flex: 2, child: Text('${itemTrays.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                                  Expanded(flex: 2, child: Text(iPcs.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
                                                  Expanded(flex: 3, child: Text('${iWeight.toStringAsFixed(1)} g', style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                const SizedBox(height: 10),
                                
                                // ── Enhanced Toggle Button ───────────────────────
                                InkWell(
                                  onTap: () => setDialogState(() => showTrays = !showTrays),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: showTrays ? Colors.grey.shade100 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: showTrays ? Colors.grey.shade200 : Colors.blue.shade100),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(showTrays ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: showTrays ? Colors.grey.shade700 : Colors.blue.shade700),
                                        const SizedBox(width: 10),
                                        Text(
                                          showTrays ? 'Hide Detailed Tray List' : 'Show Detailed Tray List',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: showTrays ? Colors.grey.shade700 : Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (showTrays) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Individual Tray Records',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                         Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          color: Colors.grey.shade50,
                                          child: Row(
                                            children: [
                                              Expanded(flex: 3, child: Text('TRAY CODE', style: _tableHeaderStyle)),
                                              Expanded(flex: 3, child: Text('ITEM DESCRIPTION', style: _tableHeaderStyle)),
                                              Expanded(flex: 2, child: Text('PCS/TUBE', style: _tableHeaderStyle)),
                                              Expanded(flex: 2, child: Text('TUBES', style: _tableHeaderStyle)),
                                              Expanded(flex: 2, child: Text('PCS', style: _tableHeaderStyle)),
                                              Expanded(flex: 2, child: Text('WEIGHT', style: _tableHeaderStyle)),
                                            ],
                                          ),
                                        ),
                                        ...group.trays.map((t) {
                                          final qty = t.productionProgress.primaryQuantity ?? 0;
                                          final wt = qty * (t.item.pieceWeight ?? 0);
                                          final pgt = t.item.perGarmentTube ?? 0;
                                          final garmentPcs = pgt > 0 ? qty * pgt : 0;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                                            child: Row(
                                              children: [
                                                Expanded(flex: 3, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                                                Expanded(flex: 3, child: Text(t.item.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                Expanded(flex: 2, child: Text(pgt > 0 ? pgt.toStringAsFixed(0) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo.shade700))),
                                                Expanded(flex: 2, child: Text(qty.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 2, child: Text(garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700))),
                                                Expanded(flex: 2, child: Text('${wt.toStringAsFixed(1)} g', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        
                        // ── Bottom Safe Space ────────────────────────────────
                        const SizedBox(height: 16),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No WIP entries found in this locator', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _WIPGroup {
  final String title1;
  final String title2;
  final String? subtitle;
  final List<ProductionProgressResponseModel> trays;

  _WIPGroup({required this.title1, required this.title2, this.subtitle, required this.trays});

  int get trayCount => trays.length;
  double get totalPcs => trays.fold(0.0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0));
}
