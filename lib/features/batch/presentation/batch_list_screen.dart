import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/batch/presentation/batch_scanning_screen.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:active_wear_scanning/features/tray/repo/tray_scanning_repo.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen>
    with SingleTickerProviderStateMixin {
  final _batchRepo = BatchRepo();
  final _trayRepo = TrayScanningRepo();
  bool _isLoading = true;

  List<BatchHeaderResponseModel> _unlockedBatches = [];
  List<BatchHeaderResponseModel> _lockedBatches = [];

  // Maps batchHeaderId → raw batch-line records linked to that batch
  Map<int, List<Map<String, dynamic>>> _groupedBatchLinesByHeader = {};

  // Trolley state: batchHeaderId → trolley trayDetail ID & tray code
  final Map<int, int> _trolleyDetailIdByBatch = {};
  final Map<int, String> _trolleyCodeByBatch = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndGroupBatches();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndGroupBatches() async {
    setState(() => _isLoading = true);
    AppLoader.show(context, message: 'Loading Batch History...');

    final headerResult = await _batchRepo.fetchBatchHeaders();
    final batchLinesResult = await _batchRepo.fetchBatchLines();

    if (mounted && headerResult.success) {
      final headerData = headerResult.data as List<Map<String, dynamic>>? ?? [];
      final headers = headerData
          .map((e) => BatchHeaderResponseModel.fromJson(e))
          .toList();
      _unlockedBatches = headers
          .where((h) => h.batchHeader.lockFlag == false)
          .toList();
      _lockedBatches = headers
          .where((h) => h.batchHeader.lockFlag == true)
          .toList();

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
      debugPrint(
        '📊 Grouped batch-lines: ${grouped.map((k, v) => MapEntry(k, v.length))}',
      );

      setState(() {
        _groupedBatchLinesByHeader = grouped;
        _isLoading = false;
      });
      AppLoader.hide(context);
    } else {
      if (mounted) {
        AppLoader.hide(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Failed to fetch batches')),
        );
      }
    }
  }

  void _navigateToAddBatch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BatchScanningScreen()),
    );
    if (result == true) {
      _fetchAndGroupBatches();
    }
  }

  void _navigateToEditBatch(BatchHeaderResponseModel batchHeaderModel) async {
    AppLoader.show(context, message: 'Loading Batch...');
    await Future.delayed(const Duration(milliseconds: 300)); // Allow loader to render
    AppLoader.hide(context);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BatchScanningScreen(
          existingBatch: batchHeaderModel,
          preloadedTrays:
              const [], // Edit screen loads its own trays from batch-lines
        ),
      ),
    );
    if (result == true) {
      _fetchAndGroupBatches();
    }
  }

  Future<void> _scanTrolleyForBatch(int batchHeaderId) async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trolly',
      onResult: (scannedCode) async {
        final code = scannedCode.trim().toLowerCase();
        if (code.isEmpty) return 'Invalid trolly code';

        AppLoader.show(context, message: 'Validating trolly...');
        final result = await _trayRepo.fetchAvailableTrayDetails();
        AppLoader.hide(context);

        if (!result.success || result.data == null) {
          return 'Failed to fetch tray details';
        }

        final allTrays = result.data as List<TrayDetailsModel>;
        final matched = allTrays.where((t) {
          return (t.trayDetails?.trayCode ?? '').trim().toLowerCase() == code;
        }).toList();

        if (matched.isEmpty) return 'Trolly not found';

        final trayDetail = matched.first.trayDetails;
        if (trayDetail?.active != true) return 'Trolly is not active';
        if ((trayDetail?.trayType ?? 0) != 4) {
          return 'Invalid tray type. Only Type 4 (Trolly) allowed.';
        }

        final trolleyId = trayDetail!.id!;
        final trolleyCode = trayDetail.trayCode ?? code;

        setState(() {
          _trolleyDetailIdByBatch[batchHeaderId] = trolleyId;
          _trolleyCodeByBatch[batchHeaderId] = trolleyCode;
        });

        Navigator.of(context).pop(); // close scanner after success
        return null;
      },
    );
  }

  Future<void> _deleteBatch(BatchHeaderResponseModel header) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text(
          'Are you sure you want to delete batch ${header.batchHeader.batchHeaderCode}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch permanently deleted!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete Failed: ${res.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _lockBatch(BatchHeaderResponseModel header) async {
    final headerId = header.batchHeader.id!;

    // ── Trolley guard: must scan trolley before locking ──────────────────────
    if (!_trolleyDetailIdByBatch.containsKey(headerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan a Trolly before issuing this batch.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Batch?'),
        content: Text(
          'Are you sure you want to issue batch ${header.batchHeader.batchHeaderCode}?\n\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Issue Batch',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
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
      'trayDetailId': _trolleyDetailIdByBatch[headerId] ?? bh.trayDetailId,
      'concurrencyStamp': bh.concurrencyStamp,
    });

    if (!lockRes.success) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Issue Failed: ${lockRes.message}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ── Step 1b: POST batch-header-routings (once per batch) ────────────────
    final lines = _groupedBatchLinesByHeader[headerId] ?? [];
    final firstLine = lines.isNotEmpty ? lines.first : null;
    final firstItemId =
        (firstLine?['batchLines'] as Map<String, dynamic>?)?['itemId'] as int?;

    if (firstItemId != null) {
      final routingRes = await _batchRepo.fetchItemRoutings(firstItemId);
      if (routingRes.success && routingRes.data != null) {
        final routingItems = routingRes.data as List;
        for (final r in routingItems) {
          final rMap = r as Map;
          final routingCode = rMap['itemRouting']?['routingCode']?.toString();
          final operationId = rMap['itemRouting']?['operationId'] as int?;
          final sequence = rMap['itemRouting']?['seq'] as int?;

          if (routingCode != null && operationId != null) {
            final res = await _batchRepo.postBatchHeaderRouting({
              'code': routingCode,
              'batchHeaderId': headerId,
              'operationId': operationId,
              'seq': sequence,
              'isActive': true,
            });
            debugPrint(
              res.success
                  ? '✅ BatchHeaderRouting posted: code=$routingCode opId=$operationId'
                  : '❌ BatchHeaderRouting failed: code=$routingCode → ${res.message}',
            );
          }
        }
      }
    }

    // ── Step 2: POST WIP transaction & production-progress for each batch-line ─
    int successCount = 0;

    for (final line in lines) {
      final bl = line['batchLines'] as Map<String, dynamic>?;
      final progress = line['progress'] as Map<String, dynamic>?;
      final item = line['item'] as Map<String, dynamic>?;

      if (bl == null) continue;

      // ── Compute min operationId from item routings ────────────────────────
      int? minOpId;
      final itemId = bl['itemId'] as int?;
      if (itemId != null) {
        final routingRes = await _batchRepo.fetchItemRoutings(itemId);
        if (routingRes.success && routingRes.data != null) {
          final routingItems = routingRes.data as List;
          final opIds = routingItems
              .map((r) => (r as Map)['itemRouting']?['operationId'])
              .whereType<int>()
              .toList();
          if (opIds.isNotEmpty) {
            minOpId = opIds.reduce((a, b) => a < b ? a : b);
          }
        }
        debugPrint('🔑 Lock: item=$itemId minOpId=$minOpId');
      }

      // ── Fetch processedItemId from work-order-line-details ────────────────
      int? processedItemId;
      final workOrderLineId = bl['workOrderLineId'] as int?;
      final colorDescription = bh.colorDescription;
      if (workOrderLineId != null && colorDescription != null) {
        final woRes = await _batchRepo.fetchWorkOrderLineDetails(
          workOrderLineId,
          colorDescription,
        );
        if (woRes.success && woRes.data != null) {
          final woItems = woRes.data as List;
          if (woItems.isNotEmpty) {
            final firstItem = woItems.first as Map;
            final raw = firstItem['processIItemd'];
            if (raw is Map) {
              processedItemId = raw['id'] as int?;
            } else if (raw is int) {
              processedItemId = raw;
            }
          }
        }
        debugPrint(
          '📦 Lock: workOrderLineId=$workOrderLineId processedItemId=$processedItemId',
        );
      }

      final primaryQty = (bl['primaryQuantity'] as num?)?.toDouble() ?? 0;
      final secondaryQty = (bl['secondaryQuantity'] as num?)?.toDouble() ?? 0;

      // ── Fetch dynamic locatorId based on operationId ─────────────────────
      int dynamicLocatorId = 10; // Default fallback
      final targetOpId = minOpId ?? progress?['operationId'];
      if (targetOpId != null) {
        final locRes = await _batchRepo.fetchLocators(operationId: targetOpId);
        if (locRes.success && locRes.data != null) {
          final locList = locRes.data as List;
          // Use .toString() comparison to avoid int vs String mismatch
          final matchingEntry = locList.cast<Map>().firstWhere(
            (entry) => (entry['operation']?['id'] ?? entry['locator']?['operationId'])?.toString() == targetOpId.toString(),
            orElse: () => {},
          );
          
          if (matchingEntry.isNotEmpty) {
            final locId = matchingEntry['locator']?['id'];
            if (locId != null) {
              dynamicLocatorId = locId as int;
              debugPrint('✅ Found Dynamic Locator: Op=$targetOpId -> Loc=$dynamicLocatorId');
            }
          } else {
            debugPrint('⚠️ No matching locator found in list for Op=$targetOpId. Using default 10.');
          }
        } else {
          debugPrint('❌ Fetch Locators Failed: ${locRes.message}. Using default 10.');
        }
      }

      final wipData = {
        'subOperation': 'Batch Issue',
        'transactionDate': DateTime.now().toIso8601String(),
        'transactionType': 2,
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
        'operationId': minOpId ?? progress?['operationId'],
        'workOrderHeaderId': bl['workOrderHeaderId'],
        'workOrderLineId': bl['workOrderLineId'],
        'itemId': bl['itemId'],
        'shiftId': progress?['shiftId'] ?? bh.shiftId,
        'primaryTrayId': bl['trayId'],
        'secondaryTrayId': _trolleyDetailIdByBatch[headerId],
        'machineId': progress?['machineId'] ?? bh.machineId,
        'planHeaderId': progress?['planHeaderId'],
        'locatorId': dynamicLocatorId,
        'batchHeaderId': headerId,
        'batchLinesId': bl['id'],
        'processedItemId': processedItemId,
      };

      final wipRes = await _batchRepo.postWipTransaction(wipData);
      if (wipRes.success) {
        successCount++;
        debugPrint('✅ WIP issued for tray ${bl["trayId"]}');
      } else {
        debugPrint(
          '❌ WIP issue failed for tray ${bl["trayId"]}: ${wipRes.message}',
        );
      }

      // ── Step 2b: POST new production-progress with min operationId ────────
      final progressData = {
        'subOperation': 'Batch Issue',
        'date': DateTime.now().toIso8601String(),
        'transactionType': 2,
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
        'operationId': minOpId ?? progress?['operationId'],
        'workOrderHeaderId': bl['workOrderHeaderId'],
        'workOrderLineId': bl['workOrderLineId'],
        'itemId': bl['itemId'],
        'shiftId': progress?['shiftId'] ?? bh.shiftId,
        'primaryTrayId': bl['trayId'],
        'secondaryTrayId': _trolleyDetailIdByBatch[headerId],
        'machineId': progress?['machineId'] ?? bh.machineId,
        'planHeaderId': progress?['planHeaderId'],
        'locatorId': dynamicLocatorId,
        'batchHeaderId': headerId,
        'batchLinesId': bl['id'],
        'processedItemId': processedItemId,
      };

      final progRes = await _batchRepo.postProductionProgress(progressData);
      if (progRes.success) {
        debugPrint('✅ ProductionProgress issued for tray ${bl["trayId"]}');

        // ── Step 2c: Update the BatchLine itself to reflect the new locator ──
        final blId = bl['id'] as int?;
        if (blId != null) {
          // Clean Business DTO: Include all business fields but exclude read-only system metadata.
          final Map<String, dynamic> cleanBlDto = {
            'planDate': bl['planDate'],
            'transactionDate': bl['transactionDate'],
            'primaryQuantity': bl['primaryQuantity'],
            'primaryUOM': bl['primaryUOM'],
            'secondaryQuantity': bl['secondaryQuantity'],
            'secondaryUOM': bl['secondaryUOM'],
            'batchLineCode': bl['batchLineCode'],
            'active': bl['active'] ?? true,
            'isReAssigned': bl['isReAssigned'] ?? false,
            'batchHeaderId': bl['batchHeaderId'],
            'progressId': bl['progressId'],
            'wipTransactionId': bl['wipTransactionId'],
            'workOrderHeaderId': bl['workOrderHeaderId'],
            'workOrderLineId': bl['workOrderLineId'],
            'itemId': bl['itemId'],
            'trayId': bl['trayId'],
            'locatorId': dynamicLocatorId, // Transition to dynamic locator based on op
            'processItemId':
                bl['processItemId'], // Send original value to keep it unchanged
            'concurrencyStamp': bl['concurrencyStamp'],
          };
          await _batchRepo.updateBatchLine(blId, cleanBlDto);
        }
      } else {
        debugPrint(
          '❌ ProductionProgress issue failed for tray ${bl["trayId"]}: ${progRes.message}',
        );
        if (context.mounted) {
          AppLoader.hide(context);
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Production Progress API Failed'),
              content: SingleChildScrollView(
                child: Text(
                  'Tray ${bl["trayId"]} failed to post progress: ${progRes.message}',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          AppLoader.show(context);
        }
      }

      // ── Step 2c: Update tray-details to empty it ─────────────────────────────
      final trayId = bl['trayId'] as int?;
      if (trayId != null) {
        final trayRes = await _batchRepo.fetchTrayDetailById(trayId);
        if (trayRes.success && trayRes.data != null) {
          final trayMap = Map<String, dynamic>.from(
            trayRes.data as Map<String, dynamic>,
          );

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
            debugPrint(
              '❌ TrayDetails empty failed for tray=$trayId: ${updateRes.message}',
            );
          }
        }
      }
    }

    setState(() => _isLoading = false);
    _fetchAndGroupBatches();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Batch issued! $successCount/${lines.length} WIP transactions posted.',
        ),
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

            // Segmented Control Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.blue,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tabs: const [
                    Tab(text: "Draft"),
                    Tab(text: "Issued"),
                  ],
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
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

  Widget _buildBatchList(
    List<BatchHeaderResponseModel> batches, {
    required bool isLocked,
  }) {
    if (batches.isEmpty) {
      return Center(
        child: Text(
          isLocked ? 'No batch is issued' : 'No draft batches found.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      );
    }

    // Sort heavily newest first
    batches.sort(
      (a, b) => (b.batchHeader.id ?? 0).compareTo((a.batchHeader.id ?? 0)),
    );

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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'BATCH ID',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'MACHINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'COLOR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'TRAYS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'WEIGHT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (!isLocked)
                    Expanded(
                      flex: 3,
                      child: Text(
                        'TROLLY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  if (!isLocked) const SizedBox(width: 120),
                ],
              ),
            ),
            ...List.generate(batches.length, (index) {
              final header = batches[index];
              final batchId = header.batchHeader.batchHeaderCode ?? "Undef";
              final machineBrand = header.machine?.brand ?? 'Unknown';
              final colorDesc = header.batchHeader.colorDescription ?? '-';

              final headerDatabaseId = header.batchHeader.id ?? 0;
              final traysLength =
                  _groupedBatchLinesByHeader[headerDatabaseId]?.length ?? 0;

              // Cumulative weight: sum(primaryQuantity × pieceWeight) for all lines in this batch
              double totalWeight = 0;
              for (final line
                  in (_groupedBatchLinesByHeader[headerDatabaseId] ?? [])) {
                final qty =
                    (line['batchLines']?['primaryQuantity'] as num?)
                        ?.toDouble() ??
                    0;
                final pw =
                    (line['item']?['pieceWeight'] as num?)?.toDouble() ?? 0;
                totalWeight += qty * pw;
              }
              final weightDisplay = totalWeight > 0
                  ? '${totalWeight.toStringAsFixed(2)} g'
                  : '-';

              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
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
                      child: Text(
                        batchId,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        machineBrand,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        colorDesc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "$traysLength",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        weightDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (!isLocked)
                      Expanded(
                        flex: 3,
                        child: Builder(builder: (_) {
                          final trolleyCode = _trolleyCodeByBatch[headerDatabaseId];
                          if (trolleyCode != null) {
                            return Text(
                              trolleyCode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return SizedBox(
                              width: 110,
                              child: CustomOutlinedButton(
                                label: 'Scan Trolly',
                                icon: Icons.qr_code_scanner,
                                iconSize: 14,
                                textSize: 11,
                                borderColor: Colors.orange,
                                fillColor: Colors.orange,
                                textColor: Colors.white,
                                buttonHeight: 34,
                                onPressed: () => _scanTrolleyForBatch(headerDatabaseId),
                              ),
                            );
                        }),
                      ),
                    if (!isLocked)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit button
                          GestureDetector(
                            onTap: () => _navigateToEditBatch(header),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.blue.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete button
                          GestureDetector(
                            onTap: () => _deleteBatch(header),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.cancel,
                                size: 18,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Lock / Issue Batch button (right)
                          GestureDetector(
                            onTap: () => _lockBatch(header),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
