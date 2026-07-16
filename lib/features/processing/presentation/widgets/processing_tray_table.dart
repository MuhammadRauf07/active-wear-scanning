import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays the internal tray table in [ProcessingBatchDetailsScreen].
///
/// Receives [trays] and rework state via constructor. Supports editing quantities
/// (tubes) inline when [isEditable] is true (e.g. in Heat Set & QA stages).
class ProcessingTrayTable extends StatefulWidget {
  final List<ProductionProgressResponseModel> trays;
  final bool isReworkMode;
  final Set<int> selectedReworkTrayIds;
  final void Function(int progressId, bool selected) onReworkToggle;
  final void Function(bool selected)? onSelectAllToggle;
  final bool isEditable;
  final String operationName;
  final Future<void> Function(int progressId, double newQty)? onQuantitySubmit;

  const ProcessingTrayTable({
    super.key,
    required this.trays,
    required this.isReworkMode,
    required this.selectedReworkTrayIds,
    required this.onReworkToggle,
    this.onSelectAllToggle,
    this.isEditable = false,
    required this.operationName,
    this.onQuantitySubmit,
  });

  @override
  State<ProcessingTrayTable> createState() => _ProcessingTrayTableState();
}

class _ProcessingTrayTableState extends State<ProcessingTrayTable> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, double> _initialQuantities = {};
  final Map<int, bool> _loadingRows = {};

  static final _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade700,
  );

  @override
  void initState() {
    super.initState();
    _initRowData();
  }

  @override
  void didUpdateWidget(covariant ProcessingTrayTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initRowData();
  }

  void _initRowData() {
    for (final t in widget.trays) {
      final id = t.productionProgress.id;
      if (id != null) {
        // Keep the original quantity as the upper limit
        _initialQuantities.putIfAbsent(id, () => t.productionProgress.primaryQuantity ?? 0);
        _controllers.putIfAbsent(
          id,
          () => TextEditingController(
            text: (t.productionProgress.primaryQuantity ?? 0).toStringAsFixed(0),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trays.isEmpty) {
      return const Center(child: Text('No trays found'));
    }

    final bool isAllSelected = widget.trays.isNotEmpty &&
        widget.trays.every((t) => widget.selectedReworkTrayIds.contains(t.productionProgress.id));
    final bool isAnySelected = widget.trays.isNotEmpty &&
        widget.trays.any((t) => widget.selectedReworkTrayIds.contains(t.productionProgress.id));

    return ContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Table header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('TRAY CODE', style: _headerStyle)),
                Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: _headerStyle)),
                Expanded(flex: 2, child: Text('COLOR', style: _headerStyle)),
                Expanded(flex: 2, child: Text('SIZE', style: _headerStyle)),
                Expanded(flex: 2, child: Text('PCS PER TUBE', style: _headerStyle)),
                Expanded(flex: 2, child: Text('TUBES', style: _headerStyle)),
                Expanded(flex: 2, child: Text('PCS', style: _headerStyle)),
                if (widget.isEditable)
                  Expanded(flex: 3, child: Text('EDIT QTY', style: _headerStyle)),
                if (widget.isReworkMode)
                  SizedBox(
                    width: 44,
                    child: Checkbox(
                      visualDensity: VisualDensity.compact,
                      value: isAllSelected ? true : (isAnySelected ? null : false),
                      tristate: true,
                      activeColor: Colors.orange,
                      onChanged: (v) {
                        if (widget.onSelectAllToggle != null) {
                          widget.onSelectAllToggle!(v == true);
                        }
                      },
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
          // ── Tray rows (Internally Scrollable) ─────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.trays.length,
              itemBuilder: (ctx, idx) {
                final t = widget.trays[idx];
                final id = t.productionProgress.id;
                final isSel = widget.selectedReworkTrayIds.contains(id);
                final tubes = t.productionProgress.primaryQuantity ?? 0;
                final pgt = t.item.perGarmentTube ?? 0;
                final garmentPcs = pgt > 0 ? tubes * pgt : 0;

                final initialQty = id != null ? (_initialQuantities[id] ?? 0) : 0.0;
                final isSaving = id != null && _loadingRows[id] == true;

                final bool hasWastage = (id != null && initialQty > 0 && tubes < initialQty) ||
                    widget.trays.any((item) =>
                        item.productionProgress.primaryTrayId == t.productionProgress.primaryTrayId &&
                        (item.productionProgress.waste ?? 0) > 0);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: hasWastage ? const Color(0xFFFFEBEE) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasWastage ? Colors.red.shade200 : const Color(0xFFF1F5F9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          t.primaryTrayModel.trayCode ?? '-',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          t.item.description ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          t.item.colorDescription?.isNotEmpty == true
                              ? t.item.colorDescription!
                              : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          t.item.sizeDescription?.isNotEmpty == true
                              ? t.item.sizeDescription!
                              : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          pgt > 0 ? pgt.toStringAsFixed(0) : '-',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          tubes.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      if (widget.isEditable)
                        Expanded(
                          flex: 3,
                          child: (id != null)
                              ? Center(
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF1B64A3),
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.edit_note_rounded,
                                            color: Color(0xFF1B64A3),
                                            size: 24,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showEditQtyDialog(
                                            context,
                                            id,
                                            t.primaryTrayModel.trayCode ?? '-',
                                            tubes,
                                            initialQty,
                                          ),
                                        ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      if (widget.isReworkMode)
                        SizedBox(
                          width: 44,
                          child: Checkbox(
                            visualDensity: VisualDensity.compact,
                            value: isSel,
                            activeColor: Colors.orange,
                            onChanged: (v) =>
                                widget.onReworkToggle(t.productionProgress.id!, v ?? false),
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditQtyDialog(BuildContext context, int progressId, String trayCode, double currentQty, double requiredQty) {
    showDialog(
      context: context,
      builder: (context) => _EditTrayQuantityDialog(
        trayCode: trayCode,
        operationName: widget.operationName,
        currentQty: currentQty,
        requiredQty: requiredQty,
        onSave: (finalQty) async {
          setState(() {
            _loadingRows[progressId] = true;
          });
          try {
            await widget.onQuantitySubmit?.call(progressId, finalQty);
          } finally {
            if (mounted) {
              setState(() {
                _loadingRows[progressId] = false;
              });
            }
          }
        },
      ),
    );
  }
}

class _EditTrayQuantityDialog extends StatefulWidget {
  final String trayCode;
  final String operationName;
  final double currentQty;
  final double requiredQty;
  final Future<void> Function(double finalQty) onSave;

  const _EditTrayQuantityDialog({
    required this.trayCode,
    required this.operationName,
    required this.currentQty,
    required this.requiredQty,
    required this.onSave,
  });

  @override
  State<_EditTrayQuantityDialog> createState() => _EditTrayQuantityDialogState();
}

class _EditTrayQuantityDialogState extends State<_EditTrayQuantityDialog> {
  int _selectedMode = 1; // 1 = Direct Quantity, 2 = Wastage
  late TextEditingController _qtyController;
  late TextEditingController _wastageController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.currentQty.toStringAsFixed(0));
    final initialWaste = widget.requiredQty - widget.currentQty;
    _wastageController = TextEditingController(
      text: initialWaste > 0 ? initialWaste.toStringAsFixed(0) : '0',
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _wastageController.dispose();
    super.dispose();
  }

  void _onChanged(String val, bool isQtyField) {
    if (val.isEmpty) {
      setState(() {});
      return;
    }

    // Strip leading zeroes
    if (val.startsWith('0') && val.length > 1) {
      final stripped = val.replaceFirst(RegExp(r'^0+'), '');
      if (isQtyField) {
        _qtyController.text = stripped;
        _qtyController.selection = TextSelection.fromPosition(
          TextPosition(offset: _qtyController.text.length),
        );
      } else {
        _wastageController.text = stripped;
        _wastageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _wastageController.text.length),
        );
      }
      _onChanged(stripped, isQtyField);
      return;
    }

    final parsed = int.tryParse(val) ?? 0;

    if (isQtyField) {
      if (parsed > widget.requiredQty) {
        _qtyController.text = widget.requiredQty.toStringAsFixed(0);
        _qtyController.selection = TextSelection.fromPosition(
          TextPosition(offset: _qtyController.text.length),
        );
        _wastageController.text = '0';
        setState(() {});
        return;
      }
      final calculatedWaste = widget.requiredQty - parsed;
      _wastageController.text = calculatedWaste >= 0 ? calculatedWaste.toStringAsFixed(0) : '0';
    } else {
      if (parsed >= widget.requiredQty) {
        final maxWaste = widget.requiredQty - 1;
        _wastageController.text = maxWaste > 0 ? maxWaste.toStringAsFixed(0) : '0';
        _wastageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _wastageController.text.length),
        );
        _qtyController.text = '1';
        setState(() {});
        return;
      }
      final calculatedQty = widget.requiredQty - parsed;
      _qtyController.text = calculatedQty.toStringAsFixed(0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = _qtyController.text;
    final parsedQty = double.tryParse(text) ?? 0;
    final isUnchanged = parsedQty == widget.currentQty;
    final isValid = parsedQty > 0 && parsedQty <= widget.requiredQty && !isUnchanged;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Tray Quantity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Tray Code: ${widget.trayCode}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Operation Info
            _buildInfoRow('Current Operation', widget.operationName),
            const SizedBox(height: 10),
            // Required Qty Info
            _buildInfoRow('Required Quantity', '${widget.requiredQty.toStringAsFixed(0)} tubes'),
            const Divider(height: 24, thickness: 1.5, color: Color(0xFFF1F5F9)),

            // Radio Options Mode Selection
            const Text(
              'Adjustment Mode',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: 1,
                    groupValue: _selectedMode,
                    title: const Text('Tubes Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onChanged: (v) {
                      setState(() {
                        _selectedMode = v!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: 2,
                    groupValue: _selectedMode,
                    title: const Text('Wastage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onChanged: (v) {
                      setState(() {
                        _selectedMode = v!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // TextFields
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tubes Qty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _qtyController,
                        enabled: _selectedMode == 1 && !_isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                          filled: _selectedMode != 1,
                          fillColor: const Color(0xFFF8FAFC),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF1B64A3), width: 1.5),
                          ),
                        ),
                        onChanged: (val) => _onChanged(val, true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wastage Qty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _wastageController,
                        enabled: _selectedMode == 2 && !_isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                          filled: _selectedMode != 2,
                          fillColor: const Color(0xFFF8FAFC),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF1B64A3), width: 1.5),
                          ),
                        ),
                        onChanged: (val) => _onChanged(val, false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B64A3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: isValid && !_isSaving
              ? () async {
                  setState(() {
                    _isSaving = true;
                  });
                  try {
                    await widget.onSave(parsedQty);
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                  }
                }
              : null,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }
}
