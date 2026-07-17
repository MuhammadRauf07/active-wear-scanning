import 'package:active_wear_scanning/features/stitching_line_schedule/model/stitching_line_schedule_model.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';

class StitchingLineScheduleState {
  final bool isLoading;
  final String? errorMessage;
  final List<StitchingLineScheduleItem> stitchingLineSchedules;
  final bool isLoadingStitchingLineSchedules;
  final List<String> customers;
  final String? selectedCustomer;
  final List<String> customerPOs;
  final String? selectedCustomerPO;
  final List<String> articles;
  final String? selectedArticle;
  final List<CostCenterLine> costCenterLines;
  final CostCenterLine? selectedCostCenterLine;
  final bool isLoadingCostCenterLines;
  final Set<int> selectedStitchingLineScheduleIds;
  final String? allocationMode;

  const StitchingLineScheduleState({
    this.isLoading = false,
    this.errorMessage,
    this.stitchingLineSchedules = const [],
    this.isLoadingStitchingLineSchedules = false,
    this.customers = const [],
    this.selectedCustomer,
    this.customerPOs = const [],
    this.selectedCustomerPO,
    this.articles = const [],
    this.selectedArticle,
    this.costCenterLines = const [],
    this.selectedCostCenterLine,
    this.isLoadingCostCenterLines = false,
    this.selectedStitchingLineScheduleIds = const {},
    this.allocationMode,
  });

  StitchingLineScheduleState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<StitchingLineScheduleItem>? stitchingLineSchedules,
    bool? isLoadingStitchingLineSchedules,
    List<String>? customers,
    String? selectedCustomer,
    List<String>? customerPOs,
    String? selectedCustomerPO,
    List<String>? articles,
    String? selectedArticle,
    List<CostCenterLine>? costCenterLines,
    CostCenterLine? selectedCostCenterLine,
    bool? isLoadingCostCenterLines,
    Set<int>? selectedStitchingLineScheduleIds,
    String? allocationMode,
    bool clearSelectedCustomer = false,
    bool clearSelectedCustomerPO = false,
    bool clearSelectedArticle = false,
    bool clearSelectedCostCenterLine = false,
    bool clearAllocationMode = false,
    bool clearError = false,
  }) {
    return StitchingLineScheduleState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      stitchingLineSchedules: stitchingLineSchedules ?? this.stitchingLineSchedules,
      isLoadingStitchingLineSchedules: isLoadingStitchingLineSchedules ?? this.isLoadingStitchingLineSchedules,
      customers: customers ?? this.customers,
      selectedCustomer: clearSelectedCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      customerPOs: clearSelectedCustomerPO ? const [] : (customerPOs ?? this.customerPOs),
      selectedCustomerPO: (clearSelectedCustomer || clearSelectedCustomerPO) ? null : (selectedCustomerPO ?? this.selectedCustomerPO),
      articles: clearSelectedArticle ? const [] : (articles ?? this.articles),
      selectedArticle: (clearSelectedCustomer || clearSelectedCustomerPO || clearSelectedArticle) ? null : (selectedArticle ?? this.selectedArticle),
      costCenterLines: costCenterLines ?? this.costCenterLines,
      selectedCostCenterLine: (clearSelectedCustomer || clearSelectedCustomerPO || clearSelectedArticle || clearSelectedCostCenterLine) ? null : (selectedCostCenterLine ?? this.selectedCostCenterLine),
      isLoadingCostCenterLines: isLoadingCostCenterLines ?? this.isLoadingCostCenterLines,
      selectedStitchingLineScheduleIds: selectedStitchingLineScheduleIds ?? this.selectedStitchingLineScheduleIds,
      allocationMode: (clearSelectedCustomer || clearSelectedCustomerPO || clearSelectedArticle || clearSelectedCostCenterLine || clearAllocationMode) ? null : (allocationMode ?? this.allocationMode),
    );
  }
}
