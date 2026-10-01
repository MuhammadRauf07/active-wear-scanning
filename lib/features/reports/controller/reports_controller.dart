import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';
import 'package:active_wear_scanning/features/reports/repo/reports_repo.dart';

enum DateFilterPreset { today, yesterday, last7Days, last30Days, custom, all }

class ReportsController extends ChangeNotifier {
  final ReportsRepo _repo = ReportsRepo();

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Global Filter State
  DateFilterPreset _datePreset = DateFilterPreset.last7Days;
  DateFilterPreset get datePreset => _datePreset;

  DateTimeRange? _customDateRange;
  DateTimeRange? get customDateRange => _customDateRange;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int? _selectedShiftId;
  int? get selectedShiftId => _selectedShiftId;

  int? _selectedOperationId;
  int? get selectedOperationId => _selectedOperationId;

  String? _selectedStatusFilter;
  String? get selectedStatusFilter => _selectedStatusFilter;

  // Lookups
  List<MachineModel> _machines = [];
  List<MachineModel> get machines => _machines;

  List<Shift> _shifts = [];
  List<Shift> get shifts => _shifts;

  List<Operation> _operations = [];
  List<Operation> get operations => _operations;

  // Sub-Report Datasets
  List<KnittingReportItem> _knittingItems = [];
  List<KnittingReportItem> get knittingItems => _getFilteredKnittingItems();

  List<WorkOrderReportItem> _workOrderItems = [];
  List<WorkOrderReportItem> get workOrderItems => _getFilteredWorkOrderItems();

  List<BatchReportItem> _batchItems = [];
  List<BatchReportItem> get batchItems => _getFilteredBatchItems();

  List<InductionReportItem> _inductionItems = [];
  List<InductionReportItem> get inductionItems => _getFilteredInductionItems();

  List<TrayTrolleyReportItem> _trayTrolleyItems = [];
  List<TrayTrolleyReportItem> get trayTrolleyItems => _getFilteredTrayTrolleyItems();

  ReportsController() {
    _initLookups();
    fetchCurrentReportData();
  }

  // ---------------------------------------------------------------------------
  // Tab Management
  // ---------------------------------------------------------------------------
  void setTabIndex(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      _searchQuery = '';
      _selectedStatusFilter = null;
      notifyListeners();
      fetchCurrentReportData();
    }
  }

  // ---------------------------------------------------------------------------
  // Filter Updaters
  // ---------------------------------------------------------------------------
  void setDatePreset(DateFilterPreset preset, {DateTimeRange? customRange}) {
    _datePreset = preset;
    _customDateRange = customRange;
    notifyListeners();
    fetchCurrentReportData();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void setShiftFilter(int? shiftId) {
    _selectedShiftId = shiftId;
    notifyListeners();
    fetchCurrentReportData();
  }

  void setOperationFilter(int? operationId) {
    _selectedOperationId = operationId;
    notifyListeners();
    fetchCurrentReportData();
  }

  void setStatusFilter(String? status) {
    _selectedStatusFilter = status;
    notifyListeners();
  }

  void resetFilters() {
    _datePreset = DateFilterPreset.last7Days;
    _customDateRange = null;
    _searchQuery = '';
    _selectedShiftId = null;
    _selectedOperationId = null;
    _selectedStatusFilter = null;
    notifyListeners();
    fetchCurrentReportData();
  }

  // ---------------------------------------------------------------------------
  // Init & Data Fetching
  // ---------------------------------------------------------------------------
  Future<void> _initLookups() async {
    final results = await Future.wait([
      _repo.fetchMachines(),
      _repo.fetchShifts(),
      _repo.fetchOperations(),
    ]);

    if (results[0].success && results[0].data is List<MachineModel>) {
      _machines = results[0].data as List<MachineModel>;
    }
    if (results[1].success && results[1].data is List<Shift>) {
      _shifts = results[1].data as List<Shift>;
    }
    if (results[2].success && results[2].data is List<Operation>) {
      _operations = results[2].data as List<Operation>;
    }
    notifyListeners();
  }

  Future<void> fetchCurrentReportData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      switch (_selectedTabIndex) {
        case 0:
          await _fetchKnittingReport();
          break;
        case 1:
          await _fetchWorkOrderReport();
          break;
        case 2:
          await _fetchBatchReport();
          break;
        case 3:
          await _fetchInductionReport();
          break;
        case 4:
          await _fetchTrayTrolleyReport();
          break;
      }
    } catch (e) {
      _errorMessage = "Failed to load report data: $e";
      dev.log("ReportsController error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 1. Knitting Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> _fetchKnittingReport() async {
    final dateParam = _getDateStringForQuery();
    final planResult = await _repo.fetchKnittingPlanLines(
      planDate: dateParam,
      shiftId: _selectedShiftId,
    );

    if (planResult.success && planResult.data is List<PlanLine>) {
      final List<PlanLine> planLines = planResult.data as List<PlanLine>;

      _knittingItems = planLines.map((line) {
        final machine = _machines.cast<MachineModel?>().firstWhere(
          (m) => m?.id == line.resourceId,
          orElse: () => null,
        );
        final shift = _shifts.cast<Shift?>().firstWhere(
          (s) => s?.id == line.shiftId,
          orElse: () => null,
        );

        final double planTubes = line.secondaryPlanQuantity > 0 ? line.secondaryPlanQuantity : line.primaryPlanQuantity;
        final double actualTubes = line.secondaryQuantity > 0 ? line.secondaryQuantity : line.primaryQuantity;
        final double compPct = planTubes > 0 ? (actualTubes / planTubes) * 100 : 0.0;

        return KnittingReportItem(
          planLine: line,
          machine: machine,
          shift: shift,
          planWeight: line.primaryPlanQuantity,
          planTubes: planTubes,
          actualWeight: line.primaryQuantity,
          actualTubes: actualTubes,
          sampleQty: line.sampleQty,
          cGradeQty: line.cGradeQty,
          cycleTime: line.cycleTime,
          completionPercentage: compPct.clamp(0.0, 100.0),
        );
      }).toList();
    } else {
      _knittingItems = [];
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Work Order Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> _fetchWorkOrderReport() async {
    final batchLinesRes = await _repo.fetchWorkOrderLines();
    final progressRes = await _repo.fetchProductionProgressGeneric({});

    if (batchLinesRes.success && batchLinesRes.data is List<BatchLine>) {
      final List<BatchLine> batchLines = batchLinesRes.data as List<BatchLine>;
      final List<ProductionProgressResponseModel> progressList = 
          progressRes.success && progressRes.data is List<ProductionProgressResponseModel>
              ? progressRes.data as List<ProductionProgressResponseModel>
              : [];

      // Group batch lines by workOrderHeaderId
      final Map<int, List<BatchLine>> woMap = {};
      for (final bl in batchLines) {
        final woId = bl.workOrderHeaderId ?? 0;
        if (woId > 0) {
          woMap.putIfAbsent(woId, () => []).add(bl);
        }
      }

      _workOrderItems = woMap.entries.map((entry) {
        final lines = entry.value;
        final first = lines.first;
        final woId = entry.key;

        final double requiredTubes = lines.fold(0.0, (sum, l) => sum + (l.garmentTube?.toDouble() ?? 0.0));
        final double planTubes = lines.fold(0.0, (sum, l) => sum + (l.planQuantity?.toDouble() ?? 0.0));

        // Aggregate knitted vs packed from progress list
        final woProgress = progressList.where((p) => p.workOrderHeader.id == woId).toList();
        final double knittedTubes = woProgress
            .where((p) => p.productionProgress.transactionType == 1)
            .fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0));

        final double packedTubes = woProgress
            .where((p) => p.productionProgress.isLastProcess == true)
            .fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0));

        final totalBatches = lines.map((l) => l.batchHeaderId).toSet().length;
        final completedBatches = woProgress
            .where((p) => p.productionProgress.isLastProcess == true)
            .map((p) => p.productionProgress.batchHeaderId)
            .toSet()
            .length;

        final double progressPercent = requiredTubes > 0 ? ((packedTubes > 0 ? packedTubes : knittedTubes) / requiredTubes) * 100 : 0.0;

        return WorkOrderReportItem(
          workOrderHeaderId: woId,
          workOrderCode: first.workOrderHeaderId?.toString() ?? 'WO-$woId',
          customerPo: null,
          workOrderDate: null,
          status: completedBatches >= totalBatches && totalBatches > 0 ? 'Completed' : 'In Progress',
          requiredTubes: requiredTubes,
          planTubes: planTubes,
          knittedTubes: knittedTubes,
          packedTubes: packedTubes,
          totalBatches: totalBatches,
          completedBatches: completedBatches,
          knittingMargin: lines.first.knittingMargin?.toDouble() ?? 0.0,
          dyeingMargin: lines.first.dyeingMargin?.toDouble() ?? 0.0,
          stitchingMargin: lines.first.stitchingMargin?.toDouble() ?? 0.0,
          progressPercent: progressPercent.clamp(0.0, 100.0),
        );
      }).toList();
    } else {
      _workOrderItems = [];
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Batch Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> _fetchBatchReport() async {
    final batchHeadersRes = await _repo.fetchBatchHeaders(planDate: _getDateStringForQuery());
    final progressRes = await _repo.fetchProductionProgressGeneric({});

    if (batchHeadersRes.success && batchHeadersRes.data is List<LotHeaderModel>) {
      final List<LotHeaderModel> batchHeaders = batchHeadersRes.data as List<LotHeaderModel>;
      final List<ProductionProgressResponseModel> allProgress = 
          progressRes.success && progressRes.data is List<ProductionProgressResponseModel>
              ? progressRes.data as List<ProductionProgressResponseModel>
              : [];

      _batchItems = batchHeaders.map((batch) {
        final batchProgress = allProgress.where((p) => p.productionProgress.batchHeaderId == batch.id).toList();

        final double totalWeight = batchProgress.fold(0.0, (sum, p) => sum + (p.productionProgress.primaryQuantity ?? 0.0));
        final double totalTubes = batchProgress.fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0));
        final int totalTrays = batchProgress.map((p) => p.productionProgress.primaryTrayId).toSet().length;

        final int reworkCount = batchProgress.where((p) => p.productionProgress.reworkFlag == true).length;
        final int holdCount = batchProgress.where((p) => p.productionProgress.holdFlag == true).length;

        String currentOp = 'Lot Created';
        if (batchProgress.isNotEmpty) {
          final lastP = batchProgress.last;
          currentOp = lastP.operation.name;
        }

        String statusBadge = 'Normal';
        if (batch.lockFlag == true) {
          statusBadge = 'Locked';
        } else if (holdCount > 0) {
          statusBadge = 'On Hold';
        } else if (reworkCount > 0) {
          statusBadge = 'Rework';
        } else if (batchProgress.any((p) => p.productionProgress.isLastProcess == true)) {
          statusBadge = 'Completed';
        }

        return BatchReportItem(
          batchHeader: batch,
          batchCode: batch.batchHeaderCode ?? 'BATCH-${batch.id}',
          planDate: batch.planDate ?? '',
          colorDescription: batch.colorDescription ?? 'N/A',
          isLocked: batch.lockFlag ?? false,
          trayDetailId: batch.trayDetailId,
          trolleyCode: batch.trayDetailId != null ? 'TRL-${batch.trayDetailId}' : null,
          isTrolleyFreed: batch.trayDetailId == null, // If null, trolley was freed or not assigned
          totalWeight: totalWeight,
          totalTubes: totalTubes,
          totalTrays: totalTrays,
          reworkCount: reworkCount,
          holdCount: holdCount,
          defectCount: 0,
          currentOperation: currentOp,
          statusBadge: statusBadge,
        );
      }).toList();
    } else {
      _batchItems = [];
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Induction Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> _fetchInductionReport() async {
    final progressRes = await _repo.fetchInductionProductionProgress(
      operationId: _selectedOperationId,
    );

    if (progressRes.success && progressRes.data is List<ProductionProgressResponseModel>) {
      final List<ProductionProgressResponseModel> progressList = progressRes.data as List<ProductionProgressResponseModel>;

      _inductionItems = progressList.map((p) {
        final prog = p.productionProgress;
        final tray = p.primaryTrayModel;
        final wo = p.workOrderHeader;
        final item = p.item;

        return InductionReportItem(
          progress: prog,
          trayCode: tray.trayCode ?? 'TRAY-${prog.primaryTrayId ?? 0}',
          locatorName: p.operation.locator?.description ?? 'Induction Staging',
          workOrderCode: wo.workOrderCode ?? 'WO-${wo.id}',
          itemDescription: item.description ?? 'Fabric Tube Item',
          colorDescription: item.colorDescription ?? 'Standard',
          sizeDescription: item.sizeDescription ?? 'M',
          weight: prog.primaryQuantity ?? 0.0,
          tubes: prog.secondaryQuantity ?? 0.0,
          productGrade: tray.productGrade ?? 1,
          inductionDate: prog.startDate,
          isBatched: prog.batchHeaderId != null && prog.batchHeaderId! > 0,
          batchHeaderId: prog.batchHeaderId,
        );
      }).toList();
    } else {
      _inductionItems = [];
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Tray & Trolley Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> _fetchTrayTrolleyReport() async {
    final trayRes = await _repo.fetchTrayDetails();

    if (trayRes.success && trayRes.data is List<TrayDetail>) {
      final List<TrayDetail> trays = trayRes.data as List<TrayDetail>;

      _trayTrolleyItems = trays.map((t) {
        final bool isTrolley = t.trayType == 2 || (t.trayCode != null && t.trayCode!.toUpperCase().contains('TRL'));
        final String assetType = isTrolley ? 'Trolley' : 'Tray';
        final bool isFree = t.isReAssigned == true || t.batchHeaderId == null || t.batchHeaderId == 0;

        String status = 'Available / Free';
        if (t.active == false) {
          status = 'Inactive';
        } else if (!isFree) {
          status = 'In Use';
        }

        return TrayTrolleyReportItem(
          trayDetail: t,
          assetCode: t.trayCode ?? 'ASSET-${t.id}',
          assetType: assetType,
          isActive: t.active ?? true,
          isReAssigned: t.isReAssigned ?? false,
          status: status,
          currentBatchCode: t.batchHeaderId != null && t.batchHeaderId! > 0 ? 'BATCH-${t.batchHeaderId}' : null,
          currentWorkOrderCode: t.workOrderHeaderId != null && t.workOrderHeaderId! > 0 ? 'WO-${t.workOrderHeaderId}' : null,
          locatorName: t.locatorId != null ? 'Locator #${t.locatorId}' : 'Floor',
          quantity: t.trayQuantity?.toDouble() ?? 0.0,
          lastActiveTime: t.lastModificationTime ?? t.creationTime,
        );
      }).toList();
    } else {
      _trayTrolleyItems = [];
    }
  }

  // ---------------------------------------------------------------------------
  // Filtering Helpers
  // ---------------------------------------------------------------------------
  List<KnittingReportItem> _getFilteredKnittingItems() {
    return _knittingItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        final matchWO = item.planLine.orderNo?.toLowerCase().contains(_searchQuery) ?? false;
        final matchCode = item.planLine.planLineCode?.toLowerCase().contains(_searchQuery) ?? false;
        final matchMachine = item.machine?.serialNumber?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchWO && !matchCode && !matchMachine) return false;
      }
      if (_selectedShiftId != null && item.planLine.shiftId != _selectedShiftId) {
        return false;
      }
      return true;
    }).toList();
  }

  List<WorkOrderReportItem> _getFilteredWorkOrderItems() {
    return _workOrderItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        final matchCode = item.workOrderCode.toLowerCase().contains(_searchQuery);
        final matchPo = item.customerPo?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchCode && !matchPo) return false;
      }
      if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
        if (item.status?.toLowerCase() != _selectedStatusFilter!.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  List<BatchReportItem> _getFilteredBatchItems() {
    return _batchItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        final matchCode = item.batchCode.toLowerCase().contains(_searchQuery);
        final matchColor = item.colorDescription.toLowerCase().contains(_searchQuery);
        final matchTrolley = item.trolleyCode?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchCode && !matchColor && !matchTrolley) return false;
      }
      if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
        if (item.statusBadge.toLowerCase() != _selectedStatusFilter!.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  List<InductionReportItem> _getFilteredInductionItems() {
    return _inductionItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        final matchTray = item.trayCode.toLowerCase().contains(_searchQuery);
        final matchWO = item.workOrderCode.toLowerCase().contains(_searchQuery);
        final matchItem = item.itemDescription.toLowerCase().contains(_searchQuery);
        if (!matchTray && !matchWO && !matchItem) return false;
      }
      if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
        if (_selectedStatusFilter == 'Batched' && !item.isBatched) return false;
        if (_selectedStatusFilter == 'Unbatched' && item.isBatched) return false;
      }
      return true;
    }).toList();
  }

  List<TrayTrolleyReportItem> _getFilteredTrayTrolleyItems() {
    return _trayTrolleyItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        final matchCode = item.assetCode.toLowerCase().contains(_searchQuery);
        final matchBatch = item.currentBatchCode?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchCode && !matchBatch) return false;
      }
      if (_selectedStatusFilter != null && _selectedStatusFilter!.isNotEmpty) {
        if (item.status.toLowerCase() != _selectedStatusFilter!.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  String? _getDateStringForQuery() {
    final now = DateTime.now();
    switch (_datePreset) {
      case DateFilterPreset.today:
        return DateFormat('yyyy-MM-dd').format(now);
      case DateFilterPreset.yesterday:
        return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      case DateFilterPreset.last7Days:
      case DateFilterPreset.last30Days:
      case DateFilterPreset.custom:
      case DateFilterPreset.all:
        return null; // Let client-side range or default API handle
    }
  }
}
