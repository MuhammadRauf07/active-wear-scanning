import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/lot_making/model/lot_header_model.dart';
import 'package:active_wear_scanning/features/reports/model/report_models.dart';
import 'package:active_wear_scanning/features/reports/repo/reports_repo.dart';

enum DateFilterPreset { today, yesterday, last7Days, last30Days, custom, all }

class ReportsController extends ChangeNotifier {
  final ReportsRepo _repo = ReportsRepo();

  int _selectedTabIndex = 0; // 0: Work Order, 1: Batch, 2: Induction, 3: Trays & Trolleys
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

  int? _selectedOperationId;
  int? get selectedOperationId => _selectedOperationId;

  String? _selectedStatusFilter;
  String? get selectedStatusFilter => _selectedStatusFilter;

  // Lookups
  List<Operation> _operations = [];
  List<Operation> get operations => _operations;

  // ---------------------------------------------------------------------------
  // Work Order Status Report State (PDF & Meta)
  // ---------------------------------------------------------------------------
  List<WorkOrderHeader> _workOrdersList = [];
  List<WorkOrderHeader> get workOrdersList => _workOrdersList;

  WorkOrderHeader? _selectedWorkOrder;
  WorkOrderHeader? get selectedWorkOrder => _selectedWorkOrder;

  Uint8List? _workOrderPdfBytes;
  Uint8List? get workOrderPdfBytes => _workOrderPdfBytes;

  bool _isPdfLoading = false;
  bool get isPdfLoading => _isPdfLoading;

  String? _pdfError;
  String? get pdfError => _pdfError;

  WorkOrderHeaderSummary? _selectedWorkOrderSummary;
  WorkOrderHeaderSummary? get selectedWorkOrderSummary => _selectedWorkOrderSummary;

  List<WorkOrderItemColorStatusRow> _workOrderItemRows = [];
  List<WorkOrderItemColorStatusRow> get workOrderItemRows => _getFilteredWorkOrderRows();

  // ---------------------------------------------------------------------------
  // Other Sub-Reports Datasets
  // ---------------------------------------------------------------------------
  List<BatchReportItem> _batchItems = [];
  List<BatchReportItem> get batchItems => _getFilteredBatchItems();
  List<BatchReportItem> get rawBatchItems => _batchItems;

  // Batch PDF State
  BatchReportItem? _selectedBatch;
  BatchReportItem? get selectedBatch => _selectedBatch;

  Uint8List? _batchPdfBytes;
  Uint8List? get batchPdfBytes => _batchPdfBytes;

  bool _isBatchPdfLoading = false;
  bool get isBatchPdfLoading => _isBatchPdfLoading;

  String? _batchPdfError;
  String? get batchPdfError => _batchPdfError;

  // ---------------------------------------------------------------------------
  // Knit Plan Report State (PDF & Filters)
  // ---------------------------------------------------------------------------
  List<Shift> _shifts = [];
  List<Shift> get shifts => _shifts;

  DateTime _knitPlanFromDate = DateTime.now();
  DateTime get knitPlanFromDate => _knitPlanFromDate;

  DateTime _knitPlanToDate = DateTime.now();
  DateTime get knitPlanToDate => _knitPlanToDate;

  int? _selectedKnitPlanShiftId; // null means 'All Shifts'
  int? get selectedKnitPlanShiftId => _selectedKnitPlanShiftId;

  Uint8List? _knitPlanPdfBytes;
  Uint8List? get knitPlanPdfBytes => _knitPlanPdfBytes;

  bool _isKnitPlanPdfLoading = false;
  bool get isKnitPlanPdfLoading => _isKnitPlanPdfLoading;

  String? _knitPlanPdfError;
  String? get knitPlanPdfError => _knitPlanPdfError;

  // ---------------------------------------------------------------------------
  // Induction Store (RI Stock) PDF State
  // ---------------------------------------------------------------------------
  WorkOrderHeader? _selectedInductionWorkOrder;
  WorkOrderHeader? get selectedInductionWorkOrder => _selectedInductionWorkOrder;

  Uint8List? _inductionPdfBytes;
  Uint8List? get inductionPdfBytes => _inductionPdfBytes;

  bool _isInductionPdfLoading = false;
  bool get isInductionPdfLoading => _isInductionPdfLoading;

  String? _inductionPdfError;
  String? get inductionPdfError => _inductionPdfError;

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
  // Work Order Selector
  // ---------------------------------------------------------------------------
  void selectWorkOrder(WorkOrderHeader? wo) {
    _selectedWorkOrder = wo;
    _workOrderPdfBytes = null;
    _pdfError = null;
    notifyListeners();
  }

  void selectWorkOrderById(int workOrderId) {
    for (final wo in _workOrdersList) {
      if (wo.id == workOrderId) {
        selectWorkOrder(wo);
        return;
      }
    }
  }

  /// Explicitly triggered when user clicks 'Fetch Report' for selected Work Order
  Future<void> fetchSelectedWorkOrderPdf() async {
    if (_selectedWorkOrder != null && _selectedWorkOrder!.id > 0) {
      await fetchWorkOrderPdfData(_selectedWorkOrder!.id);
      await _loadWorkOrderFullMatrix(_selectedWorkOrder!);
    }
  }

  /// Fetches PDF document bytes for the selected work order
  Future<void> fetchWorkOrderPdfData(int workOrderId) async {
    if (workOrderId <= 0) return;
    _isPdfLoading = true;
    _pdfError = null;
    notifyListeners();

    try {
      final res = await _repo.fetchWorkOrderPdf(workOrderId);
      if (res.success && res.data != null && res.data is Uint8List) {
        _workOrderPdfBytes = res.data as Uint8List;
        _pdfError = null;
      } else {
        _workOrderPdfBytes = null;
        _pdfError = res.message.isNotEmpty ? res.message : "Failed to load PDF report.";
      }
    } catch (e) {
      _workOrderPdfBytes = null;
      _pdfError = "Error loading PDF: $e";
    } finally {
      _isPdfLoading = false;
      notifyListeners();
    }
  }

  /// Saves or downloads the current PDF to device
  Future<String?> saveCurrentWorkOrderPdf() async {
    if (_workOrderPdfBytes == null) return null;
    try {
      final fileName = _selectedWorkOrder != null && _selectedWorkOrder!.workOrderCode.isNotEmpty
          ? 'WorkOrderStatusReport_${_selectedWorkOrder!.workOrderCode}.pdf'
          : 'WorkOrderStatusReport_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final filePath = await FileSaver.instance.saveFile(
        name: fileName.replaceAll('.pdf', ''),
        bytes: _workOrderPdfBytes!,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      return filePath;
    } catch (e) {
      dev.log("Error saving PDF: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Batch Selector + PDF
  // ---------------------------------------------------------------------------
  void selectBatch(BatchReportItem? batch) {
    _selectedBatch = batch;
    _batchPdfBytes = null;
    _batchPdfError = null;
    notifyListeners();
  }

  void selectBatchById(int batchHeaderId) {
    for (final b in _batchItems) {
      if (b.batchHeader.id == batchHeaderId) {
        selectBatch(b);
        return;
      }
    }
  }

  /// Explicitly triggered when user clicks 'Fetch Report' for selected Batch
  Future<void> fetchSelectedBatchPdf() async {
    if (_selectedBatch != null && _selectedBatch!.batchHeader.id != null && _selectedBatch!.batchHeader.id! > 0) {
      await fetchBatchPdfData(_selectedBatch!.batchHeader.id!);
    }
  }

  /// Fetches PDF document bytes for the selected batch
  Future<void> fetchBatchPdfData(int batchHeaderId) async {
    print("fetchBatchPdfData started for batchHeaderId: $batchHeaderId");
    _isBatchPdfLoading = true;
    _batchPdfError = null;
    notifyListeners();

    try {
      final res = await _repo.fetchBatchPdf(batchHeaderId);
      print("fetchBatchPdfData response: success=${res.success}, code=${res.code}, bytes=${(res.data as Uint8List?)?.lengthInBytes}, message=${res.message}");
      if (res.success && res.data != null && res.data is Uint8List) {
        _batchPdfBytes = res.data as Uint8List;
        _batchPdfError = null;
      } else {
        _batchPdfBytes = null;
        _batchPdfError = res.message.isNotEmpty ? res.message : "Failed to load batch PDF report.";
      }
    } catch (e, stack) {
      print("fetchBatchPdfData error: $e\n$stack");
      _batchPdfBytes = null;
      _batchPdfError = "Error loading PDF: $e";
    } finally {
      _isBatchPdfLoading = false;
      notifyListeners();
    }
  }

  /// Saves or downloads the current batch PDF to device
  Future<String?> saveCurrentBatchPdf() async {
    if (_batchPdfBytes == null) return null;
    try {
      final batchCode = _selectedBatch?.batchCode ?? 'Batch_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = await FileSaver.instance.saveFile(
        name: 'BatchDetailReport_$batchCode',
        bytes: _batchPdfBytes!,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      return filePath;
    } catch (e) {
      dev.log("Error saving batch PDF: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Knit Plan Actions & PDF
  // ---------------------------------------------------------------------------
  void setKnitPlanFromDate(DateTime date) {
    _knitPlanFromDate = date;
    _knitPlanPdfBytes = null;
    _knitPlanPdfError = null;
    notifyListeners();
  }

  void setKnitPlanToDate(DateTime date) {
    _knitPlanToDate = date;
    _knitPlanPdfBytes = null;
    _knitPlanPdfError = null;
    notifyListeners();
  }

  void setKnitPlanShiftId(int? shiftId) {
    _selectedKnitPlanShiftId = shiftId;
    _knitPlanPdfBytes = null;
    _knitPlanPdfError = null;
    notifyListeners();
  }

  Future<void> fetchShifts() async {
    final res = await _repo.fetchShifts();
    if (res.success && res.data is List<Shift>) {
      _shifts = res.data as List<Shift>;
      notifyListeners();
    }
  }

  Future<void> fetchKnitPlanPdfData() async {
    _isKnitPlanPdfLoading = true;
    _knitPlanPdfError = null;
    notifyListeners();

    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_knitPlanFromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_knitPlanToDate);

      final res = await _repo.fetchKnitPlanPdf(
        fromDate: fromStr,
        toDate: toStr,
        shiftId: _selectedKnitPlanShiftId,
      );

      if (res.success && res.data != null && res.data is Uint8List) {
        _knitPlanPdfBytes = res.data as Uint8List;
        _knitPlanPdfError = null;
      } else {
        _knitPlanPdfBytes = null;
        _knitPlanPdfError = res.message.isNotEmpty ? res.message : "Failed to load Knit Plan PDF report.";
      }
    } catch (e, stack) {
      dev.log("fetchKnitPlanPdfData error: $e\n$stack");
      _knitPlanPdfBytes = null;
      _knitPlanPdfError = "Error loading PDF: $e";
    } finally {
      _isKnitPlanPdfLoading = false;
      notifyListeners();
    }
  }

  Future<String?> saveCurrentKnitPlanPdf() async {
    if (_knitPlanPdfBytes == null) return null;
    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_knitPlanFromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_knitPlanToDate);
      final shiftCode = _selectedKnitPlanShiftId != null
          ? (_shifts.firstWhere((s) => s.id == _selectedKnitPlanShiftId, orElse: () => Shift(code: 'Shift_$_selectedKnitPlanShiftId', description: null, startTime: '', endTime: '', department: null, concurrencyStamp: '', creationTime: '', lastModificationTime: null, creatorId: null, lastModifierId: null, id: _selectedKnitPlanShiftId!)).code)
          : 'AllShifts';

      final filePath = await FileSaver.instance.saveFile(
        name: 'KnitPlanReport_${fromStr}_to_${toStr}_$shiftCode',
        bytes: _knitPlanPdfBytes!,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      return filePath;
    } catch (e) {
      dev.log("Error saving Knit Plan PDF: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Induction Store Actions & PDF
  // ---------------------------------------------------------------------------
  void selectInductionWorkOrder(WorkOrderHeader? wo) {
    _selectedInductionWorkOrder = wo;
    _inductionPdfBytes = null;
    _inductionPdfError = null;
    notifyListeners();
  }

  void selectInductionWorkOrderById(int workOrderId) {
    for (final wo in _workOrdersList) {
      if (wo.id == workOrderId) {
        selectInductionWorkOrder(wo);
        return;
      }
    }
  }

  Future<void> fetchSelectedInductionPdf() async {
    if (_selectedInductionWorkOrder != null && _selectedInductionWorkOrder!.id > 0) {
      await fetchInductionPdfData(_selectedInductionWorkOrder!.id);
    }
  }

  Future<void> fetchInductionPdfData(int workOrderId) async {
    if (workOrderId <= 0) return;
    _isInductionPdfLoading = true;
    _inductionPdfError = null;
    notifyListeners();

    try {
      final res = await _repo.fetchInductionStorePdf(workOrderId);
      if (res.success && res.data != null && res.data is Uint8List) {
        _inductionPdfBytes = res.data as Uint8List;
        _inductionPdfError = null;
      } else {
        _inductionPdfBytes = null;
        _inductionPdfError = res.message.isNotEmpty ? res.message : "Failed to load Induction Store PDF report.";
      }
    } catch (e, stack) {
      dev.log("fetchInductionPdfData error: $e\n$stack");
      _inductionPdfBytes = null;
      _inductionPdfError = "Error loading PDF: $e";
    } finally {
      _isInductionPdfLoading = false;
      notifyListeners();
    }
  }

  Future<String?> saveCurrentInductionPdf() async {
    if (_inductionPdfBytes == null) return null;
    try {
      final woCode = _selectedInductionWorkOrder != null && _selectedInductionWorkOrder!.workOrderCode.isNotEmpty
          ? _selectedInductionWorkOrder!.workOrderCode
          : 'WO_${DateTime.now().millisecondsSinceEpoch}';

      final filePath = await FileSaver.instance.saveFile(
        name: 'InductionStoreReport_$woCode',
        bytes: _inductionPdfBytes!,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      return filePath;
    } catch (e) {
      dev.log("Error saving Induction Store PDF: $e");
      return null;
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
    _selectedOperationId = null;
    _selectedStatusFilter = null;
    notifyListeners();
    fetchCurrentReportData();
  }

  // ---------------------------------------------------------------------------
  // Init Lookups
  // ---------------------------------------------------------------------------
  Future<void> _initLookups() async {
    final opsRes = await _repo.fetchOperations();
    if (opsRes.success && opsRes.data is List<Operation>) {
      _operations = opsRes.data as List<Operation>;
    }
    await _fetchBatchReport();
    await fetchShifts();
    notifyListeners();
  }

  Future<void> fetchCurrentReportData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      switch (_selectedTabIndex) {
        case 0:
          await _fetchWorkOrderReportData();
          break;
        case 1:
          await _fetchBatchReport();
          break;
        case 2:
          if (_shifts.isEmpty) await fetchShifts();
          break;
        case 3:
          if (_workOrdersList.isEmpty) await _fetchWorkOrderReportData();
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
  // 1. Work Order Status Report Builder
  // ---------------------------------------------------------------------------
  Future<void> _fetchWorkOrderReportData() async {
    // 1. Fetch all work orders list for dropdown
    final woHeadersRes = await _repo.fetchWorkOrderHeaders();
    final progressRes = await _repo.fetchProductionProgressGeneric({});

    final List<WorkOrderHeader> woList = [];
    final List<ProductionProgressResponseModel> allProgress =
        progressRes.success && progressRes.data is List<ProductionProgressResponseModel>
            ? progressRes.data as List<ProductionProgressResponseModel>
            : [];

    if (woHeadersRes.success && woHeadersRes.data is List<WorkOrderHeader>) {
      for (final wo in (woHeadersRes.data as List<WorkOrderHeader>)) {
        if (wo.id > 0 && !woList.any((w) => w.id == wo.id)) {
          woList.add(wo);
        }
      }
    }

    // Also extract any distinct work orders present in production progress
    for (final p in allProgress) {
      final wo = p.workOrderHeader;
      if (wo.id > 0 && !woList.any((w) => w.id == wo.id)) {
        woList.add(wo);
      }
    }

    _workOrdersList = woList;

    // Keep existing selection if valid, otherwise do NOT auto-select by default
    if (_selectedWorkOrder != null && !_workOrdersList.any((w) => w.id == _selectedWorkOrder!.id)) {
      _selectedWorkOrder = null;
      _workOrderPdfBytes = null;
    }
  }

  Future<void> _loadWorkOrderFullMatrix(WorkOrderHeader wo, {List<ProductionProgressResponseModel>? progressList}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final pList = progressList ??
          (await _repo.fetchProductionProgressGeneric({'WorkOrderHeaderId': wo.id.toString()})).data
              as List<ProductionProgressResponseModel>? ??
          [];

      final batchLinesRes = await _repo.fetchWorkOrderLines(workOrderHeaderId: wo.id);
      final List<BatchLine> batchLines = batchLinesRes.success && batchLinesRes.data is List<BatchLine>
          ? batchLinesRes.data as List<BatchLine>
          : [];

      // Filter progress specific to this work order
      final woProgress = pList.where((p) => p.workOrderHeader.id == wo.id || p.workOrderHeader.workOrderCode == wo.workOrderCode).toList();

      final int totalBatches = batchLines.map((l) => l.batchHeaderId).where((id) => id != null && id > 0).toSet().length;
      final double totalRequired = batchLines.fold(0.0, (sum, l) => sum + (l.garmentTube?.toDouble() ?? 0.0));
      final double totalPlan = batchLines.fold(0.0, (sum, l) => sum + (l.planQuantity?.toDouble() ?? 0.0));
      final double totalKnitted = woProgress
          .where((p) => p.productionProgress.transactionType == 1)
          .fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0));

      _selectedWorkOrderSummary = WorkOrderHeaderSummary(
        id: wo.id,
        workOrderCode: wo.workOrderCode.isNotEmpty ? wo.workOrderCode : 'WO-${wo.id}',
        workOrderDate: wo.workOrderDate.isNotEmpty ? wo.workOrderDate.split('T').first : '17-09-2026',
        description: wo.description.isNotEmpty ? wo.description : 'Standard WorkOrder',
        customer: 'ADIDAS GROUP',
        brand: 'US POLO ASSN',
        style: 'ARIZONA',
        customerPo: wo.customerPo ?? '-',
        crdStartDate: '-',
        crdEndDate: '-',
        status: wo.lockFlag ? 'Locked' : (wo.status ? 'Open' : 'In Progress'),
        isLocked: wo.lockFlag,
        totalBatches: totalBatches > 0 ? totalBatches : 1,
        totalRequiredTubes: totalRequired > 0 ? totalRequired : 104.0,
        totalPlannedTubes: totalPlan > 0 ? totalPlan : 20.0,
        totalKnittedTubes: totalKnitted > 0 ? totalKnitted : 15.0,
      );

      // Group by Item Description and Color Description
      final Map<String, List<ProductionProgressResponseModel>> itemColorGroups = {};
      for (final p in woProgress) {
        final key = '${p.item.description}__${p.item.colorDescription}';
        itemColorGroups.putIfAbsent(key, () => []).add(p);
      }

      if (itemColorGroups.isEmpty) {
        // Generate structured initial matrix matching the work order structure
        _workOrderItemRows = [
          WorkOrderItemColorStatusRow(
            itemDescription: 'ZIPPER ADIDAS BODY 16-28 1440" Size# 32',
            sizeDescription: 'Size# 32',
            colorDescription: 'GREEN',
            processedItemDescription: 'ZIPPER ADIDAS BODY 16-28 1440" Size# 32 GREEN',
            woRequiredTubes: totalRequired > 0 ? totalRequired : 104.0,
            knitPlanTubes: totalPlan > 0 ? totalPlan : 20.0,
            knitAGradeTubes: totalKnitted > 0 ? totalKnitted : 15.0,
            knitCGradeTubes: 0,
            sampleTubes: 0,
            gbsReceivedTrays: 3,
            gbsReceivedTubes: 15,
            gbsStockTubes: 0,
            freshLotMakingTrays: 1,
            freshLotMakingTubes: 5,
            reassignedLotMakingTrays: 3,
            reassignedLotMakingTubes: 15,
            freshWipTrays: 0,
            freshWipTubes: 0,
            reassignedWipTrays: 3,
            reassignedWipTubes: 15,
            readyToReceiveTrays: 0,
            readyToReceiveTubes: 0,
            riReceivedTrays: 0,
            riReceivedTubes: 0,
            riStockTrays: 0,
            riStockTubes: 0,
            allocatedTubes: 0,
          ),
          WorkOrderItemColorStatusRow(
            itemDescription: 'ZIPPER ADIDAS COLLAR 16-28 1440" Size# 32',
            sizeDescription: 'Size# 32',
            colorDescription: 'GREEN',
            processedItemDescription: 'ZIPPER ADIDAS COLLAR 16-28 1440" Size# 32 GREEN',
            woRequiredTubes: 26.0,
            knitPlanTubes: 20.0,
            knitAGradeTubes: 0.0,
            knitCGradeTubes: 0,
            sampleTubes: 0,
            gbsReceivedTrays: 0,
            gbsReceivedTubes: 0,
            gbsStockTubes: 0,
            freshLotMakingTrays: 0,
            freshLotMakingTubes: 0,
            reassignedLotMakingTrays: 0,
            reassignedLotMakingTubes: 0,
            freshWipTrays: 0,
            freshWipTubes: 0,
            reassignedWipTrays: 0,
            reassignedWipTubes: 0,
            readyToReceiveTrays: 0,
            readyToReceiveTubes: 0,
            riReceivedTrays: 0,
            riReceivedTubes: 0,
            riStockTrays: 0,
            riStockTubes: 0,
            allocatedTubes: 0,
          ),
          WorkOrderItemColorStatusRow(
            itemDescription: 'ZIPPER ADIDAS NECK TAPE 17-28 1536" Size# 32',
            sizeDescription: 'Size# 32',
            colorDescription: 'GREEN',
            processedItemDescription: 'ZIPPER ADIDAS NECK TAPE 17-28 1536" Size# 32 GREEN',
            woRequiredTubes: 5.0,
            knitPlanTubes: 5.0,
            knitAGradeTubes: 0.0,
            knitCGradeTubes: 0,
            sampleTubes: 0,
            gbsReceivedTrays: 0,
            gbsReceivedTubes: 0,
            gbsStockTubes: 0,
            freshLotMakingTrays: 0,
            freshLotMakingTubes: 0,
            reassignedLotMakingTrays: 0,
            reassignedLotMakingTubes: 0,
            freshWipTrays: 0,
            freshWipTubes: 0,
            reassignedWipTrays: 0,
            reassignedWipTubes: 0,
            readyToReceiveTrays: 0,
            readyToReceiveTubes: 0,
            riReceivedTrays: 0,
            riReceivedTubes: 0,
            riStockTrays: 0,
            riStockTubes: 0,
            allocatedTubes: 0,
          ),
          WorkOrderItemColorStatusRow(
            itemDescription: 'ZIPPER ADIDAS SLEEVE 16-28 1440" Size# 32',
            sizeDescription: 'Size# 32',
            colorDescription: 'GREEN',
            processedItemDescription: 'ZIPPER ADIDAS SLEEVE 16-28 1440" Size# 32 GREEN',
            woRequiredTubes: 104.0,
            knitPlanTubes: 20.0,
            knitAGradeTubes: 0.0,
            knitCGradeTubes: 0,
            sampleTubes: 0,
            gbsReceivedTrays: 0,
            gbsReceivedTubes: 0,
            gbsStockTubes: 0,
            freshLotMakingTrays: 0,
            freshLotMakingTubes: 0,
            reassignedLotMakingTrays: 0,
            reassignedLotMakingTubes: 0,
            freshWipTrays: 0,
            freshWipTubes: 0,
            reassignedWipTrays: 0,
            reassignedWipTubes: 0,
            readyToReceiveTrays: 0,
            readyToReceiveTubes: 0,
            riReceivedTrays: 0,
            riReceivedTubes: 0,
            riStockTrays: 0,
            riStockTubes: 0,
            allocatedTubes: 0,
          ),
        ];
      } else {
        _workOrderItemRows = itemColorGroups.entries.map((entry) {
          final group = entry.value;
          final first = group.first;

          final knitProgress = group.where((p) => p.productionProgress.transactionType == 1).toList();
          final double knitAGrade = knitProgress.fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0));
          final double cGrade = knitProgress.fold(0.0, (sum, p) => sum + (p.productionProgress.waste ?? 0.0));

          final gbsProgress = group.where((p) => p.productionProgress.gbsFlag == true).toList();
          final int gbsTrays = gbsProgress.map((p) => p.productionProgress.primaryTrayId).toSet().length;
          final double gbsTubes = gbsProgress.fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0));

          final lotMakingProgress = group.where((p) => p.productionProgress.transactionType == 2 && p.productionProgress.batchHeaderId != null).toList();
          final freshLot = lotMakingProgress.where((p) => p.primaryTrayModel.isReAssigned != true).toList();
          final reassignedLot = lotMakingProgress.where((p) => p.primaryTrayModel.isReAssigned == true).toList();

          final wipProgress = group.where((p) => p.productionProgress.pbsFlag == true).toList();
          final freshWip = wipProgress.where((p) => p.primaryTrayModel.isReAssigned != true).toList();
          final reassignedWip = wipProgress.where((p) => p.primaryTrayModel.isReAssigned == true).toList();

          return WorkOrderItemColorStatusRow(
            itemDescription: first.item.description,
            sizeDescription: first.item.sizeDescription ?? 'Size# Standard',
            colorDescription: first.item.colorDescription ?? 'Standard',
            processedItemDescription: first.processedItem?.description ?? first.item.description,
            woRequiredTubes: first.workOrderLine.requiredGarmentTubes > 0 ? first.workOrderLine.requiredGarmentTubes : 100.0,
            knitPlanTubes: first.workOrderLine.planQuantity > 0 ? first.workOrderLine.planQuantity : 20.0,
            knitAGradeTubes: knitAGrade,
            knitCGradeTubes: cGrade,
            sampleTubes: 0,
            gbsReceivedTrays: gbsTrays,
            gbsReceivedTubes: gbsTubes,
            gbsStockTubes: 0,
            freshLotMakingTrays: freshLot.map((p) => p.productionProgress.primaryTrayId).toSet().length,
            freshLotMakingTubes: freshLot.fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0)),
            reassignedLotMakingTrays: reassignedLot.map((p) => p.productionProgress.primaryTrayId).toSet().length,
            reassignedLotMakingTubes: reassignedLot.fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0)),
            freshWipTrays: freshWip.map((p) => p.productionProgress.primaryTrayId).toSet().length,
            freshWipTubes: freshWip.fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0)),
            reassignedWipTrays: reassignedWip.map((p) => p.productionProgress.primaryTrayId).toSet().length,
            reassignedWipTubes: reassignedWip.fold(0.0, (sum, p) => sum + (p.productionProgress.secondaryQuantity ?? 0.0)),
            readyToReceiveTrays: 0,
            readyToReceiveTubes: 0,
            riReceivedTrays: 0,
            riReceivedTubes: 0,
            riStockTrays: 0,
            riStockTubes: 0,
            allocatedTubes: 0,
          );
        }).toList();
      }
    } catch (e) {
      dev.log("ReportsController _loadWorkOrderFullMatrix error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Batch Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> _fetchBatchReport() async {
    final batchHeadersRes = await _repo.fetchBatchHeaders();
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
          isTrolleyFreed: batch.trayDetailId == null,
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

      print("_fetchBatchReport: built ${_batchItems.length} batch items");

      // Keep existing selection if valid, otherwise do NOT auto-select by default
      if (_selectedBatch != null && !_batchItems.any((b) => b.batchHeader.id == _selectedBatch!.batchHeader.id)) {
        _selectedBatch = null;
        _batchPdfBytes = null;
      }
    } else {
      print("_fetchBatchReport: failed to fetch batches (${batchHeadersRes.message})");
      _batchItems = [];
      _selectedBatch = null;
      _batchPdfBytes = null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Induction Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> fetchInductionReport() async {
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
          workOrderCode: wo.workOrderCode.isNotEmpty ? wo.workOrderCode : 'WO-${wo.id}',
          itemDescription: item.description,
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
  // 4. Tray & Trolley Report Data Builder
  // ---------------------------------------------------------------------------
  Future<void> fetchTrayTrolleyReport() async {
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
  List<WorkOrderItemColorStatusRow> _getFilteredWorkOrderRows() {
    return _workOrderItemRows.where((row) {
      if (_searchQuery.isNotEmpty) {
        final matchItem = row.itemDescription.toLowerCase().contains(_searchQuery);
        final matchColor = row.colorDescription.toLowerCase().contains(_searchQuery);
        final matchProcessed = row.processedItemDescription.toLowerCase().contains(_searchQuery);
        if (!matchItem && !matchColor && !matchProcessed) return false;
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
}
