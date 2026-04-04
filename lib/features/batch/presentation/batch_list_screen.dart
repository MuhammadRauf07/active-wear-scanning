import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/features/batch/presentation/batch_scanning_screen.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';

import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:flutter/material.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> with SingleTickerProviderStateMixin {
  final _batchRepo = BatchRepo();
  bool _isLoading = true;
  
  List<BatchHeaderResponseModel> _unlockedBatches = [];
  List<BatchHeaderResponseModel> _lockedBatches = [];
  
  // Maps batchHeaderId → raw batch-line records linked to that batch
  Map<int, List<Map<String, dynamic>>> _groupedBatchLinesByHeader = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAndGroupBatches();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndGroupBatches() async {
    setState(() => _isLoading = true);

    final headerResult = await _batchRepo.fetchBatchHeaders();
    final batchLinesResult = await _batchRepo.fetchBatchLines();

    if (mounted && headerResult.success) {
      final headerData = headerResult.data as List<Map<String, dynamic>>? ?? [];
      final headers = headerData.map((e) => BatchHeaderResponseModel.fromJson(e)).toList();
      _unlockedBatches = headers.where((h) => h.batchHeader.lockFlag == false).toList();
      _lockedBatches = headers.where((h) => h.batchHeader.lockFlag == true).toList();

      // Group batch-lines by batchHeaderId — this IS populated correctly
      final Map<int, List<Map<String, dynamic>>> grouped = {};
      if (batchLinesResult.success && batchLinesResult.data != null) {
        final rawLines = batchLinesResult.data as List<Map<String, dynamic>>;
        debugPrint('📦 Total batch-lines fetched: ${rawLines.length}');
        for (var line in rawLines) {
          final id = line['batchLines']?['batchHeaderId'] as int?;
          if (id != null) grouped.putIfAbsent(id, () => []).add(line);
        }
      }
      debugPrint('📊 Grouped batch-lines: ${grouped.map((k, v) => MapEntry(k, v.length))}');

      setState(() {
        _groupedBatchLinesByHeader = grouped;
        _isLoading = false;
      });
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Failed to fetch batches')));
      }
    }
  }


  void _navigateToAddBatch() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const BatchScanningScreen())
    );
    if (result == true) {
      _fetchAndGroupBatches();
    }
  }

  void _navigateToEditBatch(BatchHeaderResponseModel batchHeaderModel) async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => BatchScanningScreen(
          existingBatch: batchHeaderModel,
          preloadedTrays: const [], // Edit screen loads its own trays from batch-lines
        )
      )
    );
    if (result == true) {
      _fetchAndGroupBatches();
    }
  }

  Future<void> _deleteBatch(BatchHeaderResponseModel header) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text('Are you sure you want to delete batch ${header.batchHeader.batchHeaderCode}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final headerId = header.batchHeader.id!;

    // 1. Delete all batch-lines linked to this batch
    final linkedLines = _groupedBatchLinesByHeader[headerId] ?? [];
    for (var line in linkedLines) {
      final lineId = line['batchLines']?['id'] as int?;
      if (lineId != null) await _batchRepo.deleteBatchLine(lineId);
    }

    // 2. Delete the Batch Header
    final res = await _batchRepo.deleteBatchHeader(headerId);
    
    setState(() => _isLoading = false);

    if (res.success) {
      _fetchAndGroupBatches();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch permanently deleted!'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Failed: ${res.message}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _lockBatch(BatchHeaderResponseModel header) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock / Issue Batch?'),
        content: Text(
          'Are you sure you want to issue batch ${header.batchHeader.batchHeaderCode}?\n\n'
          ,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lock & Issue', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final headerId = header.batchHeader.id!;
    final bh = header.batchHeader;

    // ── Step 1: Set lockFlag = true on batch header ──────────────────────────
    final lockRes = await _batchRepo.updateBatchHeader(headerId, {
      'planDate': bh.planDate,
      'colorDescription': bh.colorDescription,
      'lockFlag': true,
      'batchHeaderCode': bh.batchHeaderCode,
      'machineId': bh.machineId,
      'colorCode': bh.colorCodeId,
      'shiftId': bh.shiftId,
      'concurrencyStamp': bh.concurrencyStamp,
    });

    if (!lockRes.success) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lock Failed: ${lockRes.message}'), backgroundColor: Colors.red),
      );
      return;
    }

    // ── Step 2: POST negative WIP transaction (type=3) for each batch-line ───
    final lines = _groupedBatchLinesByHeader[headerId] ?? [];
    int successCount = 0;

    for (final line in lines) {
      final bl = line['batchLines'] as Map<String, dynamic>?;
      final progress = line['progress'] as Map<String, dynamic>?;
      final item = line['item'] as Map<String, dynamic>?;

      if (bl == null) continue;

      final primaryQty = (bl['primaryQuantity'] as num?)?.toDouble() ?? 0;
      final secondaryQty = (bl['secondaryQuantity'] as num?)?.toDouble() ?? 0;

      final wipData = {
        'subOperation': 'Batch Issue',
        'transactionDate': DateTime.now().toIso8601String(),
        'transactionType': 3,
        'uom': line['workOrderLine']?['uom'],
        'operatorDescription': 'system',
        'primaryQuantity': -primaryQty,
        'secondaryQuantity': -secondaryQty,
        'primaryUOM': bl['primaryUOM'] ?? 0,
        'secondaryUOM': bl['secondaryUOM'] ?? 0,
        'code': item?['code'],
        'productGrade': progress?['productGrade'],
        'productNature': progress?['productNature'],
        'progressId': bl['progressId'],
        'operationId': progress?['operationId'],
        'workOrderHeaderId': bl['workOrderHeaderId'],
        'workOrderLineId': bl['workOrderLineId'],
        'itemId': bl['itemId'],
        'shiftId': progress?['shiftId'] ?? bh.shiftId,
        'primaryTrayId': bl['trayId'],
        'machineId': progress?['machineId'] ?? bh.machineId,
        'planHeaderId': progress?['planHeaderId'],
        'locatorId': bl['locatorId'],
      };

      final wipRes = await _batchRepo.postWipTransaction(wipData);
      if (wipRes.success) {
        successCount++;
        debugPrint('✅ WIP issued for tray ${bl["trayId"]}');
      } else {
        debugPrint('❌ WIP issue failed for tray ${bl["trayId"]}: ${wipRes.message}');
      }

      // ── Step 2b: POST new production-progress (operationId=10, type=1, +qty) ─
      final progressData = {
        'subOperation': 'Batch Issue',
        'date': DateTime.now().toIso8601String(),
        'transactionType': 1,
        'operatorDescription': progress?['operatorDescription'] ?? 'system',
        'primaryQuantity': primaryQty,
        'primaryUOM': bl['primaryUOM'] ?? 0,
        'secondaryQuantity': secondaryQty,
        'secondaryUOM': bl['secondaryUOM'] ?? 0,
        'wipStatus': progress?['wipStatus'] ?? 0,
        'gbsFlag': progress?['gbsFlag'] ?? false,
        'pbsFlag': progress?['pbsFlag'] ?? false,
        'progressCode': progress?['progressCode'],
        'productGrade': progress?['productGrade'],
        'productNature': progress?['productNature'],
        'operationId': 10,
        'workOrderHeaderId': bl['workOrderHeaderId'],
        'workOrderLineId': bl['workOrderLineId'],
        'itemId': bl['itemId'],
        'shiftId': progress?['shiftId'] ?? bh.shiftId,
        'primaryTrayId': bl['trayId'],
        'machineId': progress?['machineId'] ?? bh.machineId,
        'planHeaderId': progress?['planHeaderId'],
        'locatorId': bl['locatorId'],
        'batchHeaderId': headerId,
      };

      final progRes = await _batchRepo.postProductionProgress(progressData);
      if (progRes.success) {
        debugPrint('✅ ProductionProgress issued for tray ${bl["trayId"]}');
      } else {
        debugPrint('❌ ProductionProgress issue failed for tray ${bl["trayId"]}: ${progRes.message}');
      }

      // ── Step 2c: Update tray-details to empty it ─────────────────────────────
      final trayId = bl['trayId'] as int?;
      if (trayId != null) {
        final trayRes = await _batchRepo.fetchTrayDetailById(trayId);
        if (trayRes.success && trayRes.data != null) {
          final trayMap = Map<String, dynamic>.from(trayRes.data as Map<String, dynamic>);
          
          trayMap['shiftId'] = null;
          trayMap['planLineId'] = null;
          trayMap['resourceId'] = null;
          trayMap['workOrderHeaderId'] = null;
          trayMap['workOrderLineId'] = null;
          trayMap['knitItemId'] = null;
          trayMap['batchHeaderId'] = null;
          trayMap['batchLineId'] = null;
          trayMap['batchLinesId'] = null; // Adding both just to be safe
          trayMap['locatorId'] = null;
          trayMap['trayQuantity'] = "0";

          final updateRes = await _batchRepo.updateTrayDetails(trayId, trayMap);
          if (updateRes.success) {
            debugPrint('✅ TrayDetails emptied for reusable tray=$trayId');
          } else {
            debugPrint('❌ TrayDetails empty failed for tray=$trayId: ${updateRes.message}');
          }
        }
      }
    }

    setState(() => _isLoading = false);
    _fetchAndGroupBatches();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Batch locked! $successCount/${lines.length} WIP transactions posted.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomInspectionHeader(
              heading: 'Batch History',
              subtitle: 'List of all created batches',
              isShowBackIcon: true,
              topPadding: 0,
              horizontalPadding: 12,
              widget: CustomOutlinedButton(
                label: 'Add Batch',
                borderColor: Colors.blue,
                textColor: Colors.blue,
                buttonHeight: 42,
                icon: Icons.add,
                onPressed: _navigateToAddBatch,
              ),
            ),
            
            // Tab Bar Rendering
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: "Unlocked"),
                Tab(text: "Locked"),
              ],
            ),
            
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBatchList(_unlockedBatches, isLocked: false),
                      _buildBatchList(_lockedBatches, isLocked: true),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchList(List<BatchHeaderResponseModel> batches, {required bool isLocked}) {
    if (batches.isEmpty) {
      return Center(
        child: Text(
          isLocked ? 'No batch is locked' : 'No unlocked batches found.', 
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)
        ),
      );
    }

    // Sort heavily newest first
    batches.sort((a, b) => (b.batchHeader.id ?? 0).compareTo((a.batchHeader.id ?? 0)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('BATCH ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 3, child: Text('MACHINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('COLOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('TRAYS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('WEIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  if (!isLocked) const SizedBox(width: 80),
                ],
              ),
            ),
            ...List.generate(batches.length, (index) {
              final header = batches[index];
              final batchId = header.batchHeader.batchHeaderCode ?? "Undef";
              final machineBrand = header.machine?.brand ?? 'Unknown';
              final colorDesc = header.batchHeader.colorDescription ?? '-';
              
              final headerDatabaseId = header.batchHeader.id ?? 0;
              final traysLength = _groupedBatchLinesByHeader[headerDatabaseId]?.length ?? 0;

              // Cumulative weight: sum(primaryQuantity × pieceWeight) for all lines in this batch
              double totalWeight = 0;
              for (final line in (_groupedBatchLinesByHeader[headerDatabaseId] ?? [])) {
                final qty = (line['batchLines']?['primaryQuantity'] as num?)?.toDouble() ?? 0;
                final pw = (line['item']?['pieceWeight'] as num?)?.toDouble() ?? 0;
                totalWeight += qty * pw;
              }
              final weightDisplay = totalWeight > 0 ? '${totalWeight.toStringAsFixed(2)} kg' : '-';

              return GestureDetector(
                onTap: () {
                  if(!isLocked) {
                     _navigateToEditBatch(header);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                      right: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                    color: index.isEven ? Colors.white : Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(batchId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(machineBrand, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(colorDesc, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("$traysLength", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(weightDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                      ),
                      if (!isLocked)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Delete button (left)
                            GestureDetector(
                              onTap: () => _deleteBatch(header),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.cancel, size: 18, color: Colors.red.shade400),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Lock / Issue Batch button (right)
                            GestureDetector(
                              onTap: () => _lockBatch(header),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.orange.shade200),
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.lock_outline, size: 18, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
