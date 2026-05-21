import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:active_wear_scanning/features/batch/presentation/batch_scanning_screen.dart';
import 'package:active_wear_scanning/features/batch/presentation/widgets/locked_batch_tray_table.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/tray/repo/tray_scanning_repo.dart';
import 'package:active_wear_scanning/features/tray/model/tray_details_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // Expand/collapse state for locked batch tray details
  final Set<int> _expandedLockedBatchIds = {};
  // trayDetailId → trayCode (all trays, used for sub-table tray code lookup)
  Map<int, String> _primaryTrayIdToCode = {};

  // State variables for global Bluetooth scanning and draft selection
  final FocusNode _keyboardFocusNode = FocusNode();
  final StringBuffer _scannerBuffer = StringBuffer();
  int? _selectedBatchHeaderId;
  DateTime? _lastKeyPress;

  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final now = DateTime.now();
      if (_lastKeyPress != null &&
          now.difference(_lastKeyPress!).inMilliseconds > 100) {
        _scannerBuffer.clear();
      }
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final code = _scannerBuffer.toString().trim();
        _scannerBuffer.clear();
        if (code.isNotEmpty) {
          _handleExternalBluetoothScan(code);
        }
      } else if (event.character != null) {
        _scannerBuffer.write(event.character!);
      }
    }
  }

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndGroupBatches();
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAndGroupBatches() async {
    setState(() => _isLoading = true);
    AppLoader.show(context, message: 'Loading Batch History...');

    final headerResult = await _batchRepo.fetchBatchHeaders();
    final batchLinesResult = await _batchRepo.fetchBatchLines();
    final trayDetailsResult = await _trayRepo.fetchAvailableTrayDetails();

    // Build trayDetailId → trayCode lookup map (reused for trolleys + sub-table)
    final Map<int, String> trayIdToCode = {};
    if (trayDetailsResult.success && trayDetailsResult.data != null) {
      for (final t in trayDetailsResult.data as List<TrayDetailsModel>) {
        final id = t.trayDetails?.id;
        final code = t.trayDetails?.trayCode;
        if (id != null && code != null) trayIdToCode[id] = code;
      }
    }
    _primaryTrayIdToCode = trayIdToCode;

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

      // Pre-populate trolley maps from persisted trayDetailId on all batches
      for (final batch in headers) {
        final batchId = batch.batchHeader.id;
        final trayDetailId = batch.batchHeader.trayDetailId;
        if (batchId != null && trayDetailId != null) {
          _trolleyDetailIdByBatch[batchId] = trayDetailId;
          final trayCode = trayIdToCode[trayDetailId];
          if (trayCode != null) _trolleyCodeByBatch[batchId] = trayCode;
        }
      }

      // Group batch-lines by batchHeaderId
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
        AppSnackBar.showError(context, message: 'Failed to fetch batches');
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

  Future<String?> _validateAndAttachTrolley(int batchHeaderId, String code) async {
    final cleanCode = code.trim().toLowerCase();
    if (cleanCode.isEmpty) return 'Invalid trolly code';

    final result = await _trayRepo.fetchAvailableTrayDetails();
    if (!result.success || result.data == null) {
      return 'Failed to fetch tray details';
    }

    final allTrays = result.data as List<TrayDetailsModel>;
    final matched = allTrays.where((t) {
      return (t.trayDetails?.trayCode ?? '').trim().toLowerCase() == cleanCode;
    }).toList();

    if (matched.isEmpty) return 'Trolly not found';

    final trayDetail = matched.first.trayDetails;
    if (trayDetail?.active != true) return 'Trolly is not active';
    if ((trayDetail?.trayType ?? 0) != 4) {
      return 'Invalid tray type. Only Type 4 (Trolly) allowed.';
    }

    final trolleyId = trayDetail!.id!;
    final trolleyCode = trayDetail.trayCode ?? code;

    // ── Uniqueness check: trolley must not be assigned to any other batch ─
    final allBatches = [..._unlockedBatches, ..._lockedBatches];
    for (final batch in allBatches) {
      final existingId = batch.batchHeader.id;
      if (existingId == batchHeaderId) continue; // skip current batch
      final assignedTrolleyId = _trolleyDetailIdByBatch[existingId] ?? batch.batchHeader.trayDetailId;
      if (assignedTrolleyId == trolleyId) {
        final batchCode = batch.batchHeader.batchHeaderCode ?? 'another batch';
        return 'Trolly already assigned to $batchCode';
      }
    }

    setState(() {
      _trolleyDetailIdByBatch[batchHeaderId] = trolleyId;
      _trolleyCodeByBatch[batchHeaderId] = trolleyCode;
    });

    return null;
  }

  Future<void> _scanTrolleyForBatch(int batchHeaderId) async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trolly',
      onResult: (scannedCode) async {
        AppLoader.show(context, message: 'Validating trolly...');
        final errorMsg = await _validateAndAttachTrolley(batchHeaderId, scannedCode);
        AppLoader.hide(context);

        if (errorMsg == null) {
          Navigator.of(context).pop(); // close scanner after success
        }
        return errorMsg;
      },
    );
  }

  Future<void> _handleExternalBluetoothScan(String code) async {
    if (code.isEmpty) return;

    // 1. Exception check: Ensure batch is selected first
    if (_selectedBatchHeaderId == null) {
      HapticFeedback.heavyImpact();
      AppSnackBar.showError(
        context,
        title: 'Batch Required',
        message: 'Please select a draft batch first by checking its box on the left.',
      );
      return;
    }

    final activeId = _selectedBatchHeaderId!;

    // 2. Validate and attach trolley
    AppLoader.show(context, message: 'Validating trolley scanned...');
    final errorMsg = await _validateAndAttachTrolley(activeId, code);
    AppLoader.hide(context);

    if (errorMsg != null) {
      HapticFeedback.heavyImpact();
      AppSnackBar.showError(
        context,
        title: 'Trolley Scan Error',
        message: errorMsg,
      );
      return;
    }

    // 3. Success haptic
    HapticFeedback.lightImpact();

    // 4. Show success snackbar
    AppSnackBar.showSuccess(
      context,
      message: 'Trolley attached successfully! Press the issue button to post.',
    );

    // Clear selection state
    setState(() {
      _selectedBatchHeaderId = null;
    });
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
      AppSnackBar.showSuccess(context, message: 'Batch permanently deleted!');
    } else {
      AppSnackBar.showError(context, title: 'Delete Failed', message: res.message ?? '');
    }
  }

  void _handleLockRequest(BatchHeaderResponseModel batch, String? trolleyCode) {
    if (trolleyCode == null || trolleyCode.isEmpty) {
      AppSnackBar.showError(
        context,
        title: 'Trolley Required',
        message: 'Please scan trolley first.',
      );
      return;
    }
    _lockBatch(batch);
  }

  Future<void> _lockBatch(BatchHeaderResponseModel header) async {
    final headerId = header.batchHeader.id!;

    // Double safety check
    if (!_trolleyDetailIdByBatch.containsKey(headerId)) {
      _handleLockRequest(header, null);
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
      AppSnackBar.showError(context, title: 'Issue Failed', message: lockRes.message ?? '');
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
    AppSnackBar.showSuccess(context, message: 'Batch issued successfully');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _keyboardFocusNode.requestFocus();
          },
          child: RawKeyboardListener(
            focusNode: _keyboardFocusNode,
            autofocus: true,
            onKey: _onKey,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomInspectionHeader(
                    heading: 'BATCH HISTORY',
                    subtitle: 'Manage your scanning batches',
                    isShowBackIcon: true,
                    topPadding: 0,
                    horizontalPadding: 16,
                    widget: ElevatedButton.icon(
                      onPressed: _navigateToAddBatch,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('NEW BATCH',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B64A3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  _buildPremiumTabBar(),
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
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: const Color(0xFF1B64A3),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: 'DRAFT'),
          Tab(text: 'ISSUED'),
        ],
      ),
    );
  }

  Widget _buildBatchList(List<BatchHeaderResponseModel> batches,
      {required bool isLocked}) {
    if (batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isLocked ? 'No issued batches found' : 'No draft batches found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    batches.sort(
        (a, b) => (b.batchHeader.id ?? 0).compareTo((a.batchHeader.id ?? 0)));

    return Column(
      children: [
        _buildListHeader(isLocked),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: batches.length,
            itemBuilder: (context, index) =>
                _buildBatchCard(batches[index], isLocked: isLocked),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(bool isLocked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (!isLocked) const SizedBox(width: 40),
          _buildHeaderCell('BATCH #', 2, align: TextAlign.center),
          _buildHeaderCell('MACHINE', 3, align: TextAlign.center),
          _buildHeaderCell('COLOR', 2, align: TextAlign.center),
          _buildHeaderCell('TRAYS', 1, align: TextAlign.center),
          _buildHeaderCell('WEIGHT', 2, align: TextAlign.center),
          _buildHeaderCell('TROLLEY', 2, align: TextAlign.center),
          if (!isLocked)
            const SizedBox(
                width: 110,
                child: Text('ACTIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF94A3B8)))),
          if (isLocked) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, int flex,
      {TextAlign align = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBatchCard(BatchHeaderResponseModel batch,
      {required bool isLocked}) {
    final headerId = batch.batchHeader.id ?? 0;
    final batchCode = batch.batchHeader.batchHeaderCode ?? "Undef";
    final machineName = batch.machine?.brand ?? 'Unknown';
    final colorDesc = batch.batchHeader.colorDescription ?? '-';
    final trays = _groupedBatchLinesByHeader[headerId]?.length ?? 0;
    final trolleyCode = _trolleyCodeByBatch[headerId];

    double totalWeight = 0;
    for (final line in (_groupedBatchLinesByHeader[headerId] ?? [])) {
      final qty =
          (line['batchLines']?['primaryQuantity'] as num?)?.toDouble() ?? 0;
      final pw = (line['item']?['pieceWeight'] as num?)?.toDouble() ?? 0;
      totalWeight += qty * pw;
    }

    final isExpanded = _expandedLockedBatchIds.contains(headerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCFD8DC), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (!isLocked)
                  SizedBox(
                    width: 32,
                    child: Checkbox(
                      value: _selectedBatchHeaderId == headerId,
                      activeColor: const Color(0xFF1B64A3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedBatchHeaderId = headerId;
                          } else {
                            if (_selectedBatchHeaderId == headerId) {
                              _selectedBatchHeaderId = null;
                            }
                          }
                        });
                      },
                    ),
                  ),
                if (!isLocked) const SizedBox(width: 8),
                // Data Columns
                _buildDataCell(batchCode, 2, isBold: true, align: TextAlign.center),
                _buildDataCell(machineName, 3, align: TextAlign.center),
                _buildDataCell(colorDesc, 2, align: TextAlign.center),
                _buildDataCell('$trays', 1, align: TextAlign.center),
                _buildDataCell('${totalWeight.toStringAsFixed(0)}g', 2,
                    align: TextAlign.center),

                // Interactive Trolley Column
                Expanded(
                  flex: 2,
                  child: Center(
                    child: GestureDetector(
                      onTap: isLocked ? null : () => _scanTrolleyForBatch(headerId),
                      child: trolleyCode != null
                          ? Text(
                              trolleyCode,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B64A3),
                                  decoration: TextDecoration.underline),
                            )
                          : Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: const Icon(Icons.local_shipping_outlined,
                                  size: 14, color: Colors.orange),
                            ),
                    ),
                  ),
                ),

                // Actions
                if (!isLocked)
                  SizedBox(
                    width: 110,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSmallIconButton(
                            Icons.edit_rounded,
                            const Color(0xFF1B64A3),
                            () => _navigateToEditBatch(batch)),
                        const SizedBox(width: 6),
                        _buildSmallIconButton(
                            Icons.lock_open_rounded,
                            trolleyCode == null 
                                ? Colors.grey.shade400 
                                : const Color(0xFFE67E22),
                            () => _handleLockRequest(batch, trolleyCode)),
                        const SizedBox(width: 6),
                        _buildSmallIconButton(
                            Icons.delete_outline_rounded,
                            Colors.red,
                            () => _deleteBatch(batch)),
                      ],
                    ),
                  ),

                if (isLocked)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedLockedBatchIds.remove(headerId);
                      } else {
                        _expandedLockedBatchIds.add(headerId);
                      }
                    }),
                    child: SizedBox(
                      width: 40,
                      child: Center(
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFFB0BEC5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isLocked && isExpanded)
            LockedBatchTrayTable(
              lines: _groupedBatchLinesByHeader[headerId] ?? [],
              trayIdToCode: _primaryTrayIdToCode,
            ),
        ],
      ),
    );
  }

  Widget _buildDataCell(String value, int flex, {bool isBold = false, TextAlign align = TextAlign.start}) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          color: const Color(0xFF263238),
        ),
      ),
    );
  }

  Widget _buildSmallIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

