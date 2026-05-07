import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/widgets/custom_expanded_async_dropdown.dart';
import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';

class WorkOrderDropdown extends StatelessWidget {
  final List<PlanLineResponseModel>? planLines;
  final PlanLineResponseModel? selectedPlanLine;
  final ValueChanged<PlanLineResponseModel?> onChanged;

  const WorkOrderDropdown({
    super.key,
    required this.planLines,
    required this.selectedPlanLine,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (planLines == null || planLines!.isEmpty) return const SizedBox.shrink();
    
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Work Order & Item Description', style: labelStyle),
          const SizedBox(height: 8),
          CustomExpandedAsyncDropdown<PlanLineResponseModel>(
            hint: "Select from list",
            width: double.infinity,
            height: 48,
            borderColor: Colors.blue,
            items: planLines,
            selectedValue: selectedPlanLine,
            itemAsString: (plan) => "${plan.workOrderHeader.workOrderCode} - ${plan.item.description}",
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
