import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/features/wip/controller/wip_controller.dart';
import 'package:active_wear_scanning/features/wip/presentation/widgets/wip_operation_card.dart';

class WIPScreen extends StatelessWidget {
  const WIPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WipController>(
      create: (_) => WipController(),
      child: const _WIPScreenView(),
    );
  }
}

class _WIPScreenView extends StatelessWidget {
  const _WIPScreenView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WipController>();
    final state = controller.state;

    // Show error snackbar if any
    if (state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppSnackBar.showError(context, message: state.errorMessage!);
      });
    }

    final int totalBatches = state.operations.fold(0, (sum, op) => sum + op.batchCount);
    final double totalTubes = state.operations.fold(0.0, (sum, op) => sum + op.totalTubes);
    final double totalWeightKg = state.operations.fold(0.0, (sum, op) => sum + (op.totalWeight / 1000.0));

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Standard Slate 100
        body: SafeArea(
          child: Column(
            children: [
              // 1. Technical Header (Standard layout & padding)
              CustomInspectionHeader(
                heading: 'WIP MONITORING',
                subtitle: 'Manufacturing Status & Tracking',
                isShowBackIcon: true,
                topPadding: 12,
                horizontalPadding: 16,
                onBackPress: () => Navigator.of(context).pop(),
              ),

              // 2. Overview Metrics Ribbon
              if (state.operations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricTile(
                          icon: Icons.alt_route_rounded,
                          label: 'OPERATIONS',
                          value: '${state.operations.length}',
                          color: const Color(0xFF1B64A3),
                        ),
                        Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                        _buildMetricTile(
                          icon: Icons.layers_rounded,
                          label: 'ACTIVE BATCHES',
                          value: '$totalBatches',
                          color: const Color(0xFF2E7D32),
                        ),
                        Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                        _buildMetricTile(
                          icon: Icons.view_week_rounded,
                          label: 'TOTAL TUBES',
                          value: totalTubes.toStringAsFixed(0),
                          color: const Color(0xFFD97706),
                        ),
                        Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                        _buildMetricTile(
                          icon: Icons.scale_rounded,
                          label: 'TOTAL WEIGHT',
                          value: '${totalWeightKg.toStringAsFixed(1)} kg',
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. Operations List Hierarchy
              Expanded(
                child: state.isLoading && state.operations.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF1B64A3))),
                      )
                    : state.operations.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            color: const Color(0xFF1B64A3),
                            onRefresh: controller.fetchInitialData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                              itemCount: state.operations.length,
                              itemBuilder: (context, index) {
                                final opModel = state.operations[index];
                                final opId = opModel.operation.id;
                                final isExpanded = state.expandedOperationIds.contains(opId);
                                final batches = state.operationBatches[opId];
                                final isLoadingBatches = state.loadingDetails[opId] ?? false;

                                return WipOperationCard(
                                  operationModel: opModel,
                                  batches: batches,
                                  isLoading: isLoadingBatches,
                                  isExpanded: isExpanded,
                                  expandedBatchIds: state.expandedBatchIds,
                                  onToggleOperation: () => controller.toggleOperationExpanded(opId),
                                  onToggleBatch: (bhId) => controller.toggleBatchExpanded(bhId),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF64748B),
                letterSpacing: 0.4,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.blueGrey.shade200),
          const SizedBox(height: 12),
          const Text(
            'No processing operations found.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check manufacturing parameters and process setup.',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
