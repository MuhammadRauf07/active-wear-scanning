import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/knitting_production/model/plan_header_model.dart';
import 'package:active_wear_scanning/features/knitting_production/model/scanned_tray.dart';
import 'package:active_wear_scanning/features/knitting_production/model/tray_details_model.dart';

class KnittingProductionState {
  final bool isLoading;
  final String? errorMessage;
  final String machineBarcode;
  final List<ScannedTray> scannedTrays;
  final String productionType; // 'good', 'sample', 'c_grade'
  final bool usePreviousShift;
  final List<PlanLineResponseModel>? planLines;
  final List<PlanLineResponseModel> allRawPlanLines;
  final List<TrayDetailsModel> availableTraysDetail;
  final List<ProductionProgressResponseModel> existingProductionProgresses;
  final List<Map<String, dynamic>> allLotHeaders;
  final List<Map<String, dynamic>> allLotLines;
  final PlanLineResponseModel? selectedPlanLine;
  final List<Shift> shifts;
  final Map<int, List<PlanLineResponseModel>> allPlanLinesForWorkOrderLines;

  const KnittingProductionState({
    this.isLoading = false,
    this.errorMessage,
    this.machineBarcode = '',
    this.scannedTrays = const [],
    this.productionType = 'good',
    this.usePreviousShift = false,
    this.planLines,
    this.allRawPlanLines = const [],
    this.availableTraysDetail = const [],
    this.existingProductionProgresses = const [],
    this.allLotHeaders = const [],
    this.allLotLines = const [],
    this.selectedPlanLine,
    this.shifts = const [],
    this.allPlanLinesForWorkOrderLines = const {},
  });

  KnittingProductionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? machineBarcode,
    List<ScannedTray>? scannedTrays,
    String? productionType,
    bool? usePreviousShift,
    List<PlanLineResponseModel>? planLines,
    List<PlanLineResponseModel>? allRawPlanLines,
    List<TrayDetailsModel>? availableTraysDetail,
    List<ProductionProgressResponseModel>? existingProductionProgresses,
    List<Map<String, dynamic>>? allLotHeaders,
    List<Map<String, dynamic>>? allLotLines,
    PlanLineResponseModel? selectedPlanLine,
    List<Shift>? shifts,
    Map<int, List<PlanLineResponseModel>>? allPlanLinesForWorkOrderLines,
    bool clearPlanLines = false,
    bool clearSelectedPlanLine = false,
    bool clearError = false,
  }) {
    return KnittingProductionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      machineBarcode: machineBarcode ?? this.machineBarcode,
      scannedTrays: scannedTrays ?? this.scannedTrays,
      productionType: productionType ?? this.productionType,
      usePreviousShift: usePreviousShift ?? this.usePreviousShift,
      planLines: clearPlanLines ? null : (planLines ?? this.planLines),
      allRawPlanLines: allRawPlanLines ?? this.allRawPlanLines,
      availableTraysDetail: availableTraysDetail ?? this.availableTraysDetail,
      existingProductionProgresses: existingProductionProgresses ?? this.existingProductionProgresses,
      allLotHeaders: allLotHeaders ?? this.allLotHeaders,
      allLotLines: allLotLines ?? this.allLotLines,
      selectedPlanLine: clearSelectedPlanLine ? null : (selectedPlanLine ?? this.selectedPlanLine),
      shifts: shifts ?? this.shifts,
      allPlanLinesForWorkOrderLines: allPlanLinesForWorkOrderLines ?? this.allPlanLinesForWorkOrderLines,
    );
  }
}
