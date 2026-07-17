import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/wip/model/wip_group.dart';
import 'package:active_wear_scanning/features/wip/presentation/widgets/locator_expansion_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/features/wip/controller/wip_controller.dart';

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

class _WIPScreenView extends StatefulWidget {
  const _WIPScreenView();

  @override
  State<_WIPScreenView> createState() => _WIPScreenViewState();
}

class _WIPScreenViewState extends State<_WIPScreenView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchInitialData();
    });
  }

  Future<void> _fetchInitialData() async {
    final controller = context.read<WipController>();
    AppLoader.show(context, message: 'Loading Locators...');
    await controller.fetchInitialData();
    if (mounted) {
      AppLoader.hide(context);
      final state = controller.state;
      if (state.errorMessage != null) {
        _showError(state.errorMessage!);
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      AppSnackBar.showError(context, message: msg);
    }
  }

  Future<void> _onExpandLocator(WipController controller, int locatorId, bool expanded) async {
    if (expanded) {
      await controller.fetchWipData(locatorId);
      if (mounted && controller.state.errorMessage != null) {
        _showError(controller.state.errorMessage!);
      }
    }
  }

  void _showTrayDetailsDialog(WipController controller, WIPGroup group) async {
    double? fetchedCapacity;
    
    if (group.trays.isNotEmpty) {
      final machineId = group.trays.first.productionProgress.machineId;
      if (machineId != null) {
        AppLoader.show(context, message: 'Loading Capacity...');
        fetchedCapacity = await controller.fetchMachineCapacity(machineId);
        if (!mounted) return;
        AppLoader.hide(context);
      }
    }

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'WIP Details',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: anim1,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                double totalWeight = 0;
                double totalPcs = group.totalPcs;
                final Map<String, List<ProductionProgressResponseModel>> byWO = {};
                
                double? machineCapacity = fetchedCapacity;
                if (group.trays.isNotEmpty) {
                   machineCapacity ??= group.trays.first.machineModel.capacity;
                }

                for (final t in group.trays) {
                  final qty = t.productionProgress.primaryQuantity ?? 0;
                  final pw = t.item.pieceWeight ?? 0;
                  totalWeight += qty * pw;
                  final woCode = t.workOrderHeader.workOrderCode;
                  byWO.putIfAbsent(woCode, () => []).add(t);
                }

                final remaining = machineCapacity != null ? (machineCapacity - totalWeight) : null;
                final isOverCapacity = remaining != null && remaining < 0;

                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                          color: const Color(0xFF1E293B),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFF0D47A1).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.analytics_rounded, color: Color(0xFF60A5FA), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LOT SUMMARY CONSOLE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                                    Text(
                                      '${group.title1} • ${group.title2}${group.title3 != null ? ' • ${group.title3}' : ''}'.toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 3.2,
                            children: [
                              _buildDialogHUD('TOTAL TRAYS', '${group.trayCount}', Icons.layers_rounded, const Color(0xFF0D47A1)),
                              _buildDialogHUD('TOTAL TUBES', totalPcs.toStringAsFixed(0), Icons.numbers_rounded, const Color(0xFF10B981)),
                              _buildDialogHUD('NET WEIGHT', '${totalWeight.toStringAsFixed(1)} g', Icons.scale_rounded, const Color(0xFFF59E0B)),
                              _buildDialogHUD(
                                isOverCapacity ? 'OVER CAPACITY' : 'CAPACITY REM.',
                                remaining != null ? '${remaining.abs().toStringAsFixed(1)} g' : 'N/A',
                                isOverCapacity ? Icons.warning_amber_rounded : Icons.hourglass_bottom_rounded,
                                isOverCapacity ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: byWO.entries.map((entry) {
                                  final woCode = entry.key;
                                  final trays = entry.value;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                                        child: Text(
                                          'WORK ORDER: $woCode',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...trays.map((t) {
                                        final code = t.primaryTrayModel.trayCode ?? 'N/A';
                                        final qty = t.productionProgress.primaryQuantity ?? 0;
                                        final per = t.item.perGarmentTube;
                                        final itemDesc = t.item.description;
                                        final sizeDesc = t.item.sizeDescription ?? 'N/A';
                                        final colorDesc = t.item.colorDescription ?? 'N/A';

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.crop_free_rounded, size: 10, color: Color(0xFF64748B)),
                                                        const SizedBox(width: 4),
                                                        Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1B64A3))),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '$itemDesc • SIZE $sizeDesc • COLOR $colorDesc',
                                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${qty.toStringAsFixed(0)} Tubes',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                                  ),
                                                  Text(
                                                    '${(qty * per).toStringAsFixed(0)} Pcs',
                                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogHUD(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WipController>();
    final state = controller.state;

    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: state.locators.isEmpty
                      ? _buildEmptyLocatorsState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: state.locators.length,
                          itemBuilder: (context, index) {
                            final loc = state.locators[index];
                            final locatorId = loc.locator.id;
                            final trays = state.locatorTrays[locatorId] ?? [];
                            final isLoading = state.loadingDetails[locatorId] ?? false;
                            final deptCode = loc.department.code.toUpperCase();
                            final isKnitting = deptCode == 'KNITTING';
                            final isProcessing = deptCode == 'PROCESSING';
                            final groupedData = controller.groupTrays(trays, isKnitting, isProcessing);
  
                            return LocatorExpansionItem(
                              locator: loc,
                              groupedData: groupedData,
                              isLoading: isLoading,
                              onExpansionChanged: (expanded) => _onExpandLocator(controller, locatorId, expanded),
                              onViewDetails: (group) => _showTrayDetailsDialog(controller, group),
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

  Widget _buildPremiumHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Work In Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238))),
                  Text('PHYSICAL INVENTORY MONITORING', style: TextStyle(fontSize: 9, color: Color(0xFF546E7A), fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF0D47A1), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLocatorsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: Colors.blue.shade50),
          const SizedBox(height: 16),
          const Text('No stores or locators found with "FLOOR" logical warehouse.', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
