import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/scanner_always_open.dart';
import 'package:active_wear_scanning/features/lapping/presentation/lapping_detail_screen.dart';
import 'package:active_wear_scanning/features/processing/presentation/widgets/processing_tray_table.dart';
import 'package:active_wear_scanning/features/processing/controller/processing_batch_controller.dart';
import 'package:active_wear_scanning/features/processing/model/processing_batch_state.dart';
import 'package:active_wear_scanning/features/lot_making/repo/lot_repo.dart';

class ProcessingBatchDetailsScreen extends StatelessWidget {
  final int batchHeaderId;
  final int currentOperationId;
  final String batchCode;
  final int? machineId;
  final String machine;
  final String color;
  final int trayCount;
  final double totalWeight;
  final String operationName;
  final String nextOperationName;
  final int? nextOperationId;
  final bool hasPreviousProcess;

  const ProcessingBatchDetailsScreen({
    super.key,
    required this.batchHeaderId,
    required this.currentOperationId,
    required this.batchCode,
    this.machineId,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalWeight,
    required this.operationName,
    required this.nextOperationName,
    this.nextOperationId,
    required this.hasPreviousProcess,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProcessingBatchController>(
      create: (_) => ProcessingBatchController(
        batchHeaderId: batchHeaderId,
        currentOperationId: currentOperationId,
        batchCode: batchCode,
        machineId: machineId,
        machine: machine,
        color: color,
        trayCount: trayCount,
        totalWeight: totalWeight,
        operationName: operationName,
        nextOperationName: nextOperationName,
        nextOperationId: nextOperationId,
        hasPreviousProcess: hasPreviousProcess,
      )..loadInitialData(),
      child: const _ProcessingBatchDetailsView(),
    );
  }
}

class _ProcessingBatchDetailsView extends StatefulWidget {
  const _ProcessingBatchDetailsView();

  @override
  State<_ProcessingBatchDetailsView> createState() => _ProcessingBatchDetailsViewState();
}

class _ProcessingBatchDetailsViewState extends State<_ProcessingBatchDetailsView> {
  final _lotRepo = LotRepo();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProcessingBatchController>();
    final state = controller.state;

    return PopScope(
      canPop: !state.isLoading && !AppLoader.isVisible,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: state.isLoading && state.trays.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildPremiumHeader(context, controller, state),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: state.isLoading,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBatchIntelligenceGrid(controller, state),
                              const SizedBox(height: 12),
                              _buildActionConsole(controller, state),
                              if (state.showTrays) ...[
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _buildTrayTableContainer(controller, state),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, ProcessingBatchController controller, ProcessingBatchState state) {
    final isLapping = controller.operationName.toLowerCase().contains('lapping');
    final submitBlocked = !state.isBatchStarted || (isLapping && !state.isReassignedBatch && !state.isReworkMode);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFB0BEC5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const CustomBackButton(),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch Processing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                  ),
                  Text(
                    'BATCH: ${controller.batchCode}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A), fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: submitBlocked ? null : () => _confirmSubmit(controller, state),
              icon: Icon(
                state.failedTrayIds.isNotEmpty ? Icons.replay_rounded : Icons.check_circle_rounded,
                size: 16,
              ),
              label: Text(
                state.failedTrayIds.isNotEmpty
                    ? 'RETRY SUBMISSION (${state.failedTrayIds.length})'
                    : 'SUBMIT BATCH',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: state.failedTrayIds.isNotEmpty
                    ? const Color(0xFFE65100)
                    : const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchIntelligenceGrid(ProcessingBatchController controller, ProcessingBatchState state) {
    return Column(
      children: [
        _buildProcessFlowRibbon(controller),
        const SizedBox(height: 16),
        _buildAeroIntelligenceGrid(controller, state),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProcessFlowRibbon(ProcessingBatchController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B64A3), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B64A3).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildProcessNode('CURRENT', controller.operationName, Icons.settings_suggest_rounded, true),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Divider(color: Colors.white38, thickness: 1.5),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
          _buildProcessNode('NEXT', controller.nextOperationName, Icons.arrow_forward_rounded, false),
        ],
      ),
    );
  }

  Widget _buildProcessNode(String label, String value, IconData icon, bool isActive) {
    return Column(
      crossAxisAlignment: isActive ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) Icon(icon, color: Colors.white, size: 16),
            if (isActive) const SizedBox(width: 8),
            Text(
              value.toUpperCase(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            if (!isActive) const SizedBox(width: 8),
            if (!isActive) Icon(icon, color: Colors.white60, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildAeroIntelligenceGrid(ProcessingBatchController controller, ProcessingBatchState state) {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.2,
          children: [
            _buildHUDCard('BATCH #', controller.batchCode, Icons.tag_rounded),
            _buildHUDCard('MACHINE', controller.machine, Icons.precision_manufacturing_rounded),
            _buildHUDCard('COLOR', controller.color, Icons.palette_rounded),
            _buildHUDCard('TROLLEY', state.trolleyCode ?? 'N/A', Icons.local_shipping_rounded, valueColor: state.trolleyCode != null ? const Color(0xFF1B64A3) : const Color(0xFF94A3B8)),
            _buildHUDCard('TRAYS', '${controller.trayCount} UNITS', Icons.inventory_2_rounded),
            _buildHUDCard('WEIGHT', '${controller.totalWeight.toStringAsFixed(1)} g', Icons.scale_rounded),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModernTime('ISSUED', state.issueTime),
              _buildModernTime('STARTED', state.startTime),
              _buildModernStatus('RE-ASSIGN', state.isReassignedBatch ? 'YES' : 'NO', state.isReassignedBatch ? const Color(0xFF60A5FA) : Colors.white24),
              _buildModernStatus('REWORK', state.isReworkBatch ? 'YES' : 'NO', state.isReworkBatch ? const Color(0xFFFB923C) : Colors.white24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHUDCard(String label, String value, IconData icon, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTime(String label, DateTime? time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          time != null ? _formatTimeOnly(time) : '--:--',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: time != null ? Colors.white : Colors.white24,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatus(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: valueColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _formatTimeOnly(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTrayTableContainer(ProcessingBatchController controller, ProcessingBatchState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BATCHED TRAYS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
                    Text('Units within current production batch', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF78909C))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFECEFF1), borderRadius: BorderRadius.circular(6)),
                  child: Text('${state.trays.length} Units', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF455A64))),
                ),
              ],
            ),
          ),
          Expanded(
            child: ProcessingTrayTable(
              trays: state.trays,
              isReworkMode: state.isReworkMode,
              selectedReworkTrayIds: state.selectedReworkTrayIds,
              trayIdsWithWastage: state.trayIdsWithWastage,
              isEditable: (controller.operationName.toLowerCase().contains('heat set') || controller.operationName.toLowerCase().contains('qa')) && state.isBatchStarted,
              operationName: controller.operationName,
              onQuantitySubmit: (progressId, newQty, productGrade) async {
                try {
                  await controller.updateQuantity(progressId, newQty, productGrade);
                  if (mounted) AppSnackBar.showSuccess(context, message: 'Quantity updated successfully.');
                } catch (e) {
                  if (mounted) AppSnackBar.showError(context, message: 'Failed to update quantity: $e');
                }
              },
              onDeleteWastage: (progressId) async {
                try {
                  await controller.deleteWastage(progressId);
                  if (mounted) AppSnackBar.showSuccess(context, message: 'Wastage deleted successfully.');
                } catch (e) {
                  if (mounted) AppSnackBar.showError(context, message: 'Failed to delete wastage: $e');
                }
              },
              onReworkToggle: (progressId, selected) {
                controller.toggleReworkTray(progressId, selected);
              },
              onSelectAllToggle: (selected) {
                controller.selectAllReworkTrays(selected);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmFreeTrolley(ProcessingBatchController controller, ProcessingBatchState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Free Trolley'),
        content: Text(
          'Remove trolley "${state.trolleyCode}" from batch ${controller.batchCode}?\n\n'
          'You will need to re-attach a trolley before submitting.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _freeTrolley(controller);
            },
            child: const Text('Free Trolley'),
          ),
        ],
      ),
    );
  }

  Future<void> _freeTrolley(ProcessingBatchController controller) async {
    AppLoader.show(context, message: 'Freeing trolley...');
    await controller.freeTrolley();
    AppLoader.hide(context);
    if (!mounted) return;
    if (controller.state.errorMessage != null) {
      AppSnackBar.showError(context, message: controller.state.errorMessage!);
    } else {
      AppSnackBar.showWarning(context, message: 'Trolley free. Scan a new trolley before submitting.');
    }
  }

  Future<void> _showScanTrolleyDialog(ProcessingBatchController controller) async {
    await ScannerAlwaysOpen.show(
      context,
      title: 'Scan Trolley',
      onResult: (scannedCode) async {
        final code = scannedCode.trim();
        if (code.isEmpty) return 'Invalid trolley code';
        final err = await controller.attachTrolley(code);
        if (err != null) return err;
        if (mounted) Navigator.of(context).pop();
        return null;
      },
    );
  }

  void _confirmStart(ProcessingBatchController controller, ProcessingBatchState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Batch'),
        content: Text(
          'Are you sure you want to start batch ${controller.batchCode}?\n'
          '${state.trays.length} tray${state.trays.length != 1 ? 's' : ''} will be marked as started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startBatch(controller);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBatch(ProcessingBatchController controller) async {
    AppLoader.show(context, message: 'Starting batch...');
    try {
      await controller.startBatch();
      if (mounted) AppSnackBar.showSuccess(context, message: 'Batch started successfully.');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: 'Failed to start batch: $e');
    } finally {
      AppLoader.hide(context);
    }
  }

  void _showReworkDialog(ProcessingBatchController controller, ProcessingBatchState state) async {
    final firstTray = state.trays.isNotEmpty ? state.trays.first : null;
    final int? routingItemId = firstTray?.productionProgress.processedItemId ?? firstTray?.item.id;

    if (routingItemId == null) {
      AppSnackBar.showError(context, message: 'Could not resolve batch item ID.');
      return;
    }

    AppLoader.show(context, message: 'Fetching routing operations...');
    final routingRes = await _lotRepo.fetchItemRoutings(routingItemId);
    AppLoader.hide(context);

    if (!routingRes.success || routingRes.data == null) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Failed to fetch batch routing: ${routingRes.message}');
      }
      return;
    }

    final routingItems = routingRes.data as List;
    final List<Map<String, dynamic>> parsedRoutings = [];
    for (final r in routingItems) {
      final rMap = r is Map ? r as Map<String, dynamic> : {};
      final itemRouting = rMap['itemRouting'] as Map?;
      final op = rMap['operation'] as Map?;
      if (itemRouting != null && op != null) {
        final opId = itemRouting['operationId'] as int?;
        final seq = itemRouting['seq'] as int?;
        final opName = op['name'] as String?;
        if (opId != null && seq != null && opName != null) {
          parsedRoutings.add({
            'operationId': opId,
            'seq': seq,
            'name': opName,
          });
        }
      }
    }

    parsedRoutings.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
    final currentIdx = parsedRoutings.indexWhere((r) => r['operationId'] == controller.currentOperationId);

    final List<Map<String, dynamic>> prevOps = [];
    if (currentIdx != -1) {
      prevOps.addAll(parsedRoutings.sublist(0, currentIdx));
    } else {
      prevOps.addAll(parsedRoutings);
    }

    if (prevOps.isEmpty) {
      if (mounted) {
        AppSnackBar.showWarning(context, message: 'No previous operations in this batch routing.');
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rework Target'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: prevOps.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final op = prevOps[i];
              return ListTile(
                title: Text(op['name']),
                onTap: () {
                  Navigator.pop(context);
                  controller.toggleReworkMode(
                    enabled: true,
                    targetOpId: op['operationId'] as int,
                    targetOpName: op['name'] as String,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmSubmit(ProcessingBatchController controller, ProcessingBatchState state) {
    if (state.trolleyDetailId == null) {
      AppSnackBar.showError(context, message: 'Please scan a trolley before submitting.');
      return;
    }
    String msg = 'Proceed with batch submission?';
    if (state.isReworkMode) {
      msg = '${state.selectedReworkTrayIds.length} trays will return to ${state.reworkTargetOpName}.\nOthers will proceed to standard flow.';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitBatch(controller);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBatch(ProcessingBatchController controller) async {
    AppLoader.show(context, message: 'Submitting...');
    try {
      await controller.submitBatch((result) {
        if (mounted) {
          AppLoader.hide(context);
          Navigator.pop(context, result);
        }
      });
    } catch (e) {
      AppLoader.hide(context);
      if (mounted) {
        AppSnackBar.showError(context, message: e.toString());
      }
    }
  }

  Widget _buildActionConsole(ProcessingBatchController controller, ProcessingBatchState state) {
    final isLapping = controller.operationName.toLowerCase().contains('lapping');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTROL CONSOLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF263238), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildConsoleButton(
                  label: state.showTrays
                      ? 'HIDE'
                      : ((controller.operationName.toLowerCase().contains('heat set') || controller.operationName.toLowerCase().contains('qa'))
                          ? 'EDIT TRAYS'
                          : 'SHOW'),
                  icon: state.showTrays
                      ? Icons.visibility_off_rounded
                      : ((controller.operationName.toLowerCase().contains('heat set') || controller.operationName.toLowerCase().contains('qa'))
                          ? Icons.edit_note_rounded
                          : Icons.visibility_rounded),
                  color: const Color(0xFF1B64A3),
                  onPressed: controller.toggleShowTrays,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildConsoleButton(
                  label: state.isBatchStarted ? 'STARTED' : 'START',
                  icon: state.isBatchStarted ? Icons.check_circle_outline_rounded : Icons.play_arrow_rounded,
                  color: state.isBatchStarted ? const Color(0xFF94A3B8) : const Color(0xFF2E7D32),
                  onPressed: (state.isBatchStarted || state.trays.isEmpty) ? null : () => _confirmStart(controller, state),
                ),
              ),
              const SizedBox(width: 6),
              if (controller.hasPreviousProcess && !isLapping) ...[
                Expanded(
                  child: _buildConsoleButton(
                    label: state.isReworkMode ? 'CANCEL' : 'REWORK',
                    icon: Icons.sync_problem_rounded,
                    color: state.isReworkMode ? Colors.red : Colors.orange.shade800,
                    onPressed: !state.isBatchStarted
                        ? null
                        : () {
                            if (state.isReworkMode) {
                              controller.toggleReworkMode(enabled: false);
                            } else {
                              _showReworkDialog(controller, state);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (isLapping && !state.isReassignedBatch) ...[
                Expanded(
                  child: _buildConsoleButton(
                    label: 'RE-ASSIGN',
                    icon: Icons.assignment_turned_in_rounded,
                    color: Colors.teal,
                    onPressed: !state.isBatchStarted
                        ? null
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LappingDetailScreen(
                                  batchHeaderId: controller.batchHeaderId,
                                  batchCode: controller.batchCode,
                                  machineId: controller.machineId,
                                  machine: controller.machine,
                                  color: controller.color,
                                  trayCount: controller.trayCount,
                                  totalWeight: controller.totalWeight,
                                  currentOperationId: controller.currentOperationId,
                                  nextOperationId: controller.nextOperationId,
                                  nextOperationName: controller.nextOperationName,
                                ),
                              ),
                            );
                            if (mounted && result == true) {
                              Navigator.pop(context, {
                                'submitted': true,
                                'targetOps': [if (controller.nextOperationId != null) controller.nextOperationId!],
                                'isReassigned': true,
                                'isRework': false,
                              });
                            }
                          },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: _buildConsoleButton(
                  label: state.trolleyCode != null ? 'FREE TROLLEY' : 'SCAN TROLLEY',
                  icon: state.trolleyCode != null ? Icons.link_off_rounded : Icons.qr_code_scanner_rounded,
                  color: state.trolleyCode != null ? Colors.red.shade700 : Colors.teal.shade700,
                  onPressed: !state.isBatchStarted
                      ? null
                      : (state.isUpdatingTrolley
                          ? null
                          : (state.trolleyCode != null
                              ? () => _confirmFreeTrolley(controller, state)
                              : () => _showScanTrolleyDialog(controller))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleButton({required String label, required IconData icon, required Color color, required VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        disabledBackgroundColor: const Color(0xFFF1F5F9),
        disabledForegroundColor: const Color(0xFF94A3B8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 8)),
        ],
      ),
    );
  }
}
