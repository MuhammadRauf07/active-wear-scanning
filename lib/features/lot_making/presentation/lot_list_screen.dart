import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/lot_making/presentation/lot_making_screen.dart';
import 'package:active_wear_scanning/features/lot_making/presentation/widgets/locked_lot_tray_table.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';
import 'package:active_wear_scanning/features/knitting_production/repo/knitting_production_repo.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../gbs/model/production_progress.dart';

class LotListScreen extends StatefulWidget {
  const LotListScreen({super.key});

  @override
  State<LotListScreen> createState() => _LotListScreenState();
}

class _LotListScreenState extends State<LotListScreen>
    with SingleTickerProviderStateMixin {
  final _lotRepo = LotRepo();
  final _trayRepo = KnittingProductionRepo();
  bool _isLoading = true;

  List<LotHeaderResponseModel> _unlockedLots = [];
  List<LotHeaderResponseModel> _lockedLots = [];

  // Maps batchHeaderId → raw batch-line records linked to that lot
  Map<int, List<Map<String, dynamic>>> _groupedLotLinesByHeader = {};

  // Trolley state: batchHeaderId → trolley trayDetail ID & tray code
  final Map<int, int> _trolleyDetailIdByLot = {};
  final Map<int, String> _trolleyCodeByLot = {};

  // Expand/collapse state for locked batch tray details
  final Set<int> _expandedLockedLotIds = {};
  // trayDetailId → trayCode (all trays, used for sub-table tray code lookup)
  Map<int, String> _primaryTrayIdToCode = {};

  // State variables for global Bluetooth scanning and draft selection
  final FocusNode _keyboardFocusNode = FocusNode();
  final StringBuffer _scannerBuffer = StringBuffer();
  int? _selectedLotHeaderId;
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
      _fetchAndGroupLots();
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAndGroupLots() async {
    setState(() => _isLoading = true);
    AppLoader.show(context, message: 'Loading Lot History...');

    final headerResult = await _lotRepo.fetchLotHeaders();
    final batchLinesResult = await _lotRepo.fetchLotLines();
    // Startup pre-fetching of all tray details has been removed to load list instantly.
    _primaryTrayIdToCode = {};

    if (mounted && headerResult.success) {
      final headerData = headerResult.data as List<Map<String, dynamic>>? ?? [];
      final headers = headerData
          .map((e) => LotHeaderResponseModel.fromJson(e))
          .toList();
      _unlockedLots = headers
          .where((h) => h.batchHeader.lockFlag == false)
          .toList();
      _lockedLots = headers
          .where((h) => h.batchHeader.lockFlag == true)
          .toList();

      // Pre-populate trolley maps from persisted trayDetailId on all lots
      for (final lot in headers) {
        final batchId = lot.batchHeader.id;
        final trayDetailId = lot.batchHeader.trayDetailId;
        if (batchId != null && trayDetailId != null) {
          _trolleyDetailIdByLot[batchId] = trayDetailId;
          final trayCode = _primaryTrayIdToCode[trayDetailId];
          if (trayCode != null) {
            _trolleyCodeByLot[batchId] = trayCode;
          } else {
            _fetchTrolleyCodeDynamically(batchId, trayDetailId);
          }
        }
      }

      // Group batch-lines by batchHeaderId
      final Map<int, List<Map<String, dynamic>>> grouped = {};
      if (batchLinesResult.success && batchLinesResult.data != null) {
        final rawLines = batchLinesResult.data as List<Map<String, dynamic>>;
        debugPrint('📦 Total lot-lines fetched: ${rawLines.length}');
        for (var line in rawLines) {
          final id = line['batchLines']?['batchHeaderId'] as int?;
          if (id != null) grouped.putIfAbsent(id, () => []).add(line);
        }
      }
      debugPrint(
        '📊 Grouped lot-lines: ${grouped.map((k, v) => MapEntry(k, v.length))}',
      );

      setState(() {
        _groupedLotLinesByHeader = grouped;
        _isLoading = false;
      });
      AppLoader.hide(context);
    } else {
      if (mounted) {
        AppLoader.hide(context);
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, message: 'Failed to fetch lots');
      }
    }
  }

  void _navigateToAddLot() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LotMakingScreen()),
    );
    if (result == true) {
      _fetchAndGroupLots();
    }
  }

  void _navigateToEditLot(LotHeaderResponseModel lotHeaderModel) async {
    AppLoader.show(context, message: 'Loading Lot...');
    await Future.delayed(const Duration(milliseconds: 300)); // Allow loader to render
    AppLoader.hide(context);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LotMakingScreen(
          existingBatch: lotHeaderModel,
          preloadedTrays:
              const [], // Edit screen loads its own trays from lot-lines
        ),
      ),
    );
    if (result == true) {
      _fetchAndGroupLots();
    }
  }

  Future<String?> _validateAndAttachTrolley(int lotHeaderId, String code) async {
    final cleanCode = code.trim().toLowerCase();
    if (cleanCode.isEmpty) return 'Invalid trolley code';

    List<TrayDetailsModel> matched = [];
    try {
      final res = await _trayRepo.fetchTrayDetailByCode(code);
      if (res.success && res.data != null) {
        matched = [res.data as TrayDetailsModel];
      }
    } catch (e) {
      debugPrint('Error fetching trolley dynamically: $e');
    }

    if (matched.isEmpty) return 'Trolley not found';

    final trayDetail = matched.first.trayDetails;
    if (trayDetail?.active != true) return 'Trolley is not active';
    if ((trayDetail?.trayType ?? 0) != 4) {
      return 'Invalid type. Only Trolley is allowed.';
    }

    final trolleyId = trayDetail!.id!;
    final trolleyCode = trayDetail.trayCode ?? code;

    // ── Uniqueness check: trolley must not be assigned to any other lot ─
    final allLots = [..._unlockedLots, ..._lockedLots];
    for (final lot in allLots) {
      final existingId = lot.batchHeader.id;
      if (existingId == lotHeaderId) continue; // skip current lot
      final assignedTrolleyId = _trolleyDetailIdByLot[existingId] ?? lot.batchHeader.trayDetailId;
      if (assignedTrolleyId == trolleyId) {
        final batchCode = lot.batchHeader.batchHeaderCode ?? 'another lot';
        return 'Trolley already assigned to $batchCode';
      }
    }

    setState(() {
      _trolleyDetailIdByLot[lotHeaderId] = trolleyId;
      _trolleyCodeByLot[lotHeaderId] = trolleyCode;
    });

    return null;
  }

  Future<void> _scanTrolleyForLot(int lotHeaderId) async {
    _keyboardFocusNode.unfocus();
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trolley',
      onResult: (scannedCode) async {
        AppLoader.show(context, message: 'Validating trolley...');
        final errorMsg = await _validateAndAttachTrolley(lotHeaderId, scannedCode);
        AppLoader.hide(context);

        if (errorMsg == null) {
          Navigator.of(context).pop(); // close scanner after success
        }
        return errorMsg;
      },
    );
    if (mounted) _keyboardFocusNode.requestFocus();
  }

  Future<void> _handleExternalBluetoothScan(String code) async {
    if (code.isEmpty) return;

    // 1. Exception check: Ensure lot is selected first
    if (_selectedLotHeaderId == null) {
      HapticFeedback.heavyImpact();
      AppSnackBar.showError(
        context,
        title: 'Lot Required',
        message: 'Please select a draft lot first by checking its box on the left.',
      );
      return;
    }

    final activeId = _selectedLotHeaderId!;

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
      _selectedLotHeaderId = null;
    });
  }

  Future<void> _deleteLot(LotHeaderResponseModel header) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lot?'),
        content: Text(
          'Are you sure you want to delete lot ${header.batchHeader.batchHeaderCode}?',
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

    // 1. Delete all batch-lines linked to this lot
    final linkedLines = _groupedLotLinesByHeader[headerId] ?? [];
    for (var line in linkedLines) {
      final lineId = line['batchLines']?['id'] as int?;
      if (lineId != null) await _lotRepo.deleteLotLine(lineId);
    }

    // 2. Delete the Lot Header
    final res = await _lotRepo.deleteLotHeader(headerId);

    setState(() => _isLoading = false);

    if (res.success) {
      _fetchAndGroupLots();
      AppSnackBar.showSuccess(context, message: 'Lot permanently deleted!');
    } else {
      AppSnackBar.showError(context, title: 'Delete Failed', message: res.message ?? '');
    }
  }

  void _handleLockRequest(LotHeaderResponseModel lot, String? trolleyCode) {
    if (trolleyCode == null || trolleyCode.isEmpty) {
      AppSnackBar.showError(
        context,
        title: 'Trolley Required',
        message: 'Please scan trolley first.',
      );
      return;
    }
    _lockLot(lot);
  }

  Future<void> _lockLot(LotHeaderResponseModel header) async {
    final headerId = header.batchHeader.id!;

    // Double safety check
    if (!_trolleyDetailIdByLot.containsKey(headerId)) {
      _handleLockRequest(header, null);
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Lot?'),
        content: Text(
          'Are you sure you want to issue lot ${header.batchHeader.batchHeaderCode}?\n\n',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Issue Lot',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    AppLoader.show(context, message: 'Issuing Lot...');
    setState(() => _isLoading = true);
    final bh = header.batchHeader;

    // ── Step 1: Set lockFlag = true on lot header ──────────────────────────
    final lockRes = await _lotRepo.updateLotHeader(headerId, {
      'planDate': bh.planDate,
      'colorDescription': bh.colorDescription,
      'lockFlag': true,
      'batchHeaderCode': bh.batchHeaderCode,
      'machineId': bh.machineId,
      'colorCode': bh.colorCodeId,
      'shiftId': bh.shiftId,
      'trayDetailId': _trolleyDetailIdByLot[headerId] ?? bh.trayDetailId,
      'concurrencyStamp': bh.concurrencyStamp,
    });

    if (!lockRes.success) {
      AppLoader.hide(context);
      setState(() => _isLoading = false);
      AppSnackBar.showError(context, title: 'Issue Failed', message: lockRes.message ?? '');
      return;
    }

    // ── Step 1b: POST lot-header-routings (once per lot) ────────────────
    final lines = _groupedLotLinesByHeader[headerId] ?? [];
    final firstLine = lines.isNotEmpty ? lines.first : null;
    final firstItemId =
        (firstLine?['batchLines'] as Map<String, dynamic>?)?['itemId'] as int?;

    int? firstProcessedItemId;
    if (firstLine != null) {
      final bl = firstLine['batchLines'] as Map<String, dynamic>?;
      final workOrderLineId = bl?['workOrderLineId'] as int?;
      final colorDescription = bh.colorDescription;
      if (workOrderLineId != null && colorDescription != null) {
        final woRes = await _lotRepo.fetchWorkOrderLineDetails(
          workOrderLineId,
          colorDescription,
        );
        if (woRes.success && woRes.data != null) {
          final woItems = woRes.data as List;
          if (woItems.isNotEmpty) {
            final firstItem = woItems.first as Map;
            final raw = firstItem['processIItemd'];
            if (raw is Map) {
              firstProcessedItemId = raw['id'] as int?;
            } else if (raw is int) {
              firstProcessedItemId = raw;
            }
          }
        }
      }
    }

    final int? routingItemId = firstProcessedItemId ?? firstItemId;

    if (routingItemId != null) {
      final routingRes = await _lotRepo.fetchItemRoutings(routingItemId);
      if (routingRes.success && routingRes.data != null) {
        final routingItems = routingRes.data as List;
        for (final r in routingItems) {
          final rMap = r as Map;
          final routingCode = rMap['itemRouting']?['routingCode']?.toString();
          final operationId = rMap['itemRouting']?['operationId'] as int?;
          final sequence = rMap['itemRouting']?['seq'] as int?;

          if (routingCode != null && operationId != null) {
            final res = await _lotRepo.postLotHeaderRouting({
              'code': routingCode,
              'batchHeaderId': headerId,
              'operationId': operationId,
              'seq': sequence,
              'isActive': true,
            });
            debugPrint(
              res.success
                  ? '✅ LotHeaderRouting posted: code=$routingCode opId=$operationId'
                  : '❌ LotHeaderRouting failed: code=$routingCode → ${res.message}',
            );
          }
        }
      }
    }

    // ── Step 2: POST WIP transaction & production-progress for each lot-line ─
    int successCount = 0;

    for (final line in lines) {
      final bl = line['batchLines'] as Map<String, dynamic>?;
      final progress = line['progress'] as Map<String, dynamic>?;
      final item = line['item'] as Map<String, dynamic>?;

      if (bl == null) continue;

      // ── Fetch processedItemId from work-order-line-details ────────────────
      int? processedItemId;
      final workOrderLineId = bl['workOrderLineId'] as int?;
      final colorDescription = bh.colorDescription;
      if (workOrderLineId != null && colorDescription != null) {
        final woRes = await _lotRepo.fetchWorkOrderLineDetails(
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

      // ── Compute min operationId from item routings based on sequence ──────
      int? minOpId;
      final int? targetItemId = processedItemId ?? bl['itemId'] as int?;
      if (targetItemId != null) {
        final routingRes = await _lotRepo.fetchItemRoutings(targetItemId);
        if (routingRes.success && routingRes.data != null) {
          final routingItems = routingRes.data as List;
          int? minSeq;
          int? resolvedOpId;
          for (final r in routingItems) {
            final rMap = r as Map;
            final seq = rMap['itemRouting']?['seq'] as int?;
            final opId = rMap['itemRouting']?['operationId'] as int?;
            if (seq != null && opId != null) {
              if (minSeq == null || seq < minSeq) {
                minSeq = seq;
                resolvedOpId = opId;
              }
            }
          }
          minOpId = resolvedOpId;
        }
        debugPrint('🔑 Lock: item=$targetItemId minOpId=$minOpId');
      }

      final primaryQty = (bl['primaryQuantity'] as num?)?.toDouble() ?? 0;
      final secondaryQty = (bl['secondaryQuantity'] as num?)?.toDouble() ?? 0;

      // ── Fetch dynamic locatorId based on operationId ─────────────────────
      int dynamicLocatorId = 10; // Default fallback
      final targetOpId = minOpId ?? progress?['operationId'];
      if (targetOpId != null) {
        final locRes = await _lotRepo.fetchLocators(operationId: targetOpId);
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
        'secondaryTrayId': _trolleyDetailIdByLot[headerId],
        'machineId': progress?['machineId'] ?? bh.machineId,
        'planHeaderId': progress?['planHeaderId'],
        'locatorId': 3,
        'toLocatorId': 6,
        'batchHeaderId': headerId,
        'batchLinesId': bl['id'],
        'processedItemId': processedItemId,
      };

      final wipRes = await _lotRepo.postWipTransaction(wipData);
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
        'secondaryTrayId': _trolleyDetailIdByLot[headerId],
        'machineId': progress?['machineId'] ?? bh.machineId,
        'planHeaderId': progress?['planHeaderId'],
        'locatorId': 6,
        'batchHeaderId': headerId,
        'batchLineId': bl['id'],
        'batchLinesId': bl['id'],
        'processedItemId': processedItemId,
      };

      final progRes = await _lotRepo.postProductionProgress(progressData);
      if (progRes.success) {
        debugPrint('✅ ProductionProgress issued for tray ${bl["trayId"]}');

        // ── Step 2c: Update the LotLine itself to reflect the new locator ──
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
          await _lotRepo.updateLotLine(blId, cleanBlDto);
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

      // ── Step 2c: Update tray-details to empty it (only if not attached to other draft lots and has no remaining GBS checkout qty) ──
      final trayId = bl['trayId'] as int?;
      if (trayId != null) {
        bool hasUnissuedPortion = false;
        
        final ppRes = await _lotRepo.fetchProductionProgress(query: {
          'LocatorId': '3',
          'PrimaryTrayId': trayId.toString(),
        });

        if (ppRes.success && ppRes.data != null) {
          final ppList = ppRes.data as List<ProductionProgressResponseModel>;
          for (final ppItem in ppList) {
            final progressBatchHeaderId = ppItem.productionProgress.batchHeaderId;
            
            // If it is not associated with any batch, it is unassigned/remaining!
            if (progressBatchHeaderId == null) {
              hasUnissuedPortion = true;
              break;
            } else {
              // If it is associated with a batch, check if that batch is still draft (unlocked)
              // (unless it is the current batch being issued)
              if (progressBatchHeaderId.toString() == headerId.toString()) {
                continue;
              }
              
              final isDraft = _unlockedLots.any((lot) => lot.batchHeader.id?.toString() == progressBatchHeaderId.toString());
              if (isDraft) {
                hasUnissuedPortion = true;
                break;
              }
            }
          }
        }

        if (hasUnissuedPortion) {
          debugPrint('⚠️ Tray $trayId still has unissued portions (draft or remaining GBS quantity). Skipping reset of TrayDetails.');
        } else {
          final trayRes = await _lotRepo.fetchTrayDetailById(trayId);
          if (trayRes.success && trayRes.data != null) {
            final trayMap = Map<String, dynamic>.from(
              trayRes.data as Map<String, dynamic>,
            );

            // Free the tray!
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

            final updateRes = await _lotRepo.updateTrayDetails(trayId, trayMap);
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
    }

    AppLoader.hide(context);
    setState(() => _isLoading = false);
    _fetchAndGroupLots();
    AppSnackBar.showSuccess(context, message: 'Lot issued successfully');
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
                    heading: 'LOT HISTORY',
                    subtitle: 'Manage your scanning lots',
                    isShowBackIcon: true,
                    topPadding: 0,
                    horizontalPadding: 16,
                    widget: ElevatedButton.icon(
                      onPressed: _navigateToAddLot,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('NEW LOT',
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
                        _buildLotList(_unlockedLots, isLocked: false),
                        _buildLotList(_lockedLots, isLocked: true),
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

  Widget _buildLotList(List<LotHeaderResponseModel> lots,
      {required bool isLocked}) {
    if (lots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isLocked ? 'No issued lots found' : 'No draft lots found',
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

    lots.sort(
        (a, b) => (b.batchHeader.id ?? 0).compareTo((a.batchHeader.id ?? 0)));

    return Column(
      children: [
        _buildListHeader(isLocked),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: lots.length,
            itemBuilder: (context, index) =>
                _buildLotCard(lots[index], isLocked: isLocked),
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
          _buildHeaderCell('LOT #', 2, align: TextAlign.center),
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

  Widget _buildLotCard(LotHeaderResponseModel lot,
      {required bool isLocked}) {
    final headerId = lot.batchHeader.id ?? 0;
    final batchCode = lot.batchHeader.batchHeaderCode ?? "Undef";
    final machineName = lot.machine?.brand ?? 'Unknown';
    final colorDesc = lot.batchHeader.colorDescription ?? '-';
    final trays = _groupedLotLinesByHeader[headerId]?.length ?? 0;
    final trolleyCode = _trolleyCodeByLot[headerId];

    double totalWeight = 0;
    for (final line in (_groupedLotLinesByHeader[headerId] ?? [])) {
      final qty =
          (line['batchLines']?['primaryQuantity'] as num?)?.toDouble() ?? 0;
      final pw = (line['item']?['pieceWeight'] as num?)?.toDouble() ?? 0;
      totalWeight += qty * pw;
    }

    final isExpanded = _expandedLockedLotIds.contains(headerId);

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
                      value: _selectedLotHeaderId == headerId,
                      activeColor: const Color(0xFF1B64A3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedLotHeaderId = headerId;
                          } else {
                            if (_selectedLotHeaderId == headerId) {
                              _selectedLotHeaderId = null;
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
                      onTap: isLocked ? null : () => _scanTrolleyForLot(headerId),
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
                            () => _navigateToEditLot(lot)),
                        const SizedBox(width: 6),
                        _buildSmallIconButton(
                            Icons.lock_open_rounded,
                            trolleyCode == null 
                                ? Colors.grey.shade400 
                                : const Color(0xFFE67E22),
                            () => _handleLockRequest(lot, trolleyCode)),
                        const SizedBox(width: 6),
                        _buildSmallIconButton(
                            Icons.delete_outline_rounded,
                            Colors.red,
                            () => _deleteLot(lot)),
                      ],
                    ),
                  ),

                if (isLocked)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedLockedLotIds.remove(headerId);
                      } else {
                        _expandedLockedLotIds.add(headerId);
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
            LockedLotTrayTable(
              lines: _groupedLotLinesByHeader[headerId] ?? [],
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

  Future<void> _fetchTrolleyCodeDynamically(int batchId, int trayDetailId) async {
    try {
      final res = await _lotRepo.fetchTrayDetailById(trayDetailId);
      if (res.success && res.data != null) {
        final Map<String, dynamic> rawMap = res.data as Map<String, dynamic>;
        final tdMap = (rawMap['trayDetail'] is Map)
            ? Map<String, dynamic>.from(rawMap['trayDetail'] as Map)
            : rawMap;
        final code = tdMap['trayCode']?.toString();
        if (code != null && mounted) {
          setState(() {
            _trolleyCodeByLot[batchId] = code;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching trolley dynamically: $e');
    }
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

