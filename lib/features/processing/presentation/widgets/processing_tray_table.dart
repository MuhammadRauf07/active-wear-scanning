import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:active_wear_scanning/features/processing/model/defect_list_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays the internal tray table in [ProcessingBatchDetailsScreen].
///
/// Styled matching the Knitting Production and GBS Receiving tray tables.
/// Supports viewing Wastage QTY and accessing a 3-dot action menu for
/// Add Waste and Delete Waste.
class ProcessingTrayTable extends StatefulWidget {
  final List<ProductionProgressResponseModel> trays;
  final List<DefectListItemModel> defectLists;
  final bool isReworkMode;
  final Set<int> selectedReworkTrayIds;
  final void Function(int progressId, bool selected) onReworkToggle;
  final void Function(bool selected)? onSelectAllToggle;
  final bool isEditable;
  final bool isBatchStarted;
  final String operationName;
  final Future<void> Function(
    int progressId,
    double newQty,
    int productGrade,
    List<int> defectListIds,
    String reason,
    String remarks,
  )? onQuantitySubmit;
  final Future<void> Function(int progressId)? onDeleteWastage;
  final Set<int> trayIdsWithWastage;
  final Map<int, ProductionProgressResponseModel> wastageByOriginalId;
  final Set<int> holdTrayIds;
  final void Function(int trayId)? onHoldToggle;
  final ValueChanged<bool>? onSelectAllHoldToggle;

  const ProcessingTrayTable({
    super.key,
    required this.trays,
    this.defectLists = const [],
    required this.isReworkMode,
    required this.selectedReworkTrayIds,
    required this.onReworkToggle,
    this.onSelectAllToggle,
    this.isEditable = false,
    this.isBatchStarted = false,
    required this.operationName,
    this.onQuantitySubmit,
    this.onDeleteWastage,
    this.trayIdsWithWastage = const {},
    this.wastageByOriginalId = const {},
    this.holdTrayIds = const {},
    this.onHoldToggle,
    this.onSelectAllHoldToggle,
  });

  @override
  State<ProcessingTrayTable> createState() => _ProcessingTrayTableState();
}

class _ProcessingTrayTableState extends State<ProcessingTrayTable> {
  final Map<int, bool> _loadingRows = {};

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF455A64), // Slate Grey
    letterSpacing: 0.2,
  );

  static const _cellStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: Color(0xFF263238),
  );

  static const _blueCellStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1B64A3),
  );

  double _computeWasteQuantity(ProductionProgressResponseModel t) {
    final progressId = t.productionProgress.id;
    final tubes = (t.productionProgress.secondaryQuantity ?? t.productionProgress.primaryQuantity ?? 0).toDouble();
    final reqQty = t.productionProgress.requiredQty?.toDouble();
    final wastageRecord = (progressId != null) ? widget.wastageByOriginalId[progressId] : null;

    if (reqQty != null && reqQty > tubes) {
      return reqQty - tubes;
    }
    if ((t.productionProgress.waste ?? 0) > 0) {
      return t.productionProgress.waste!.toDouble();
    }
    if (wastageRecord != null) {
      return (wastageRecord.productionProgress.secondaryQuantity ??
              wastageRecord.productionProgress.primaryQuantity ??
              0)
          .toDouble();
    }
    return 0.0;
  }

  bool _hasWaste(ProductionProgressResponseModel t) {
    final progressId = t.productionProgress.id;
    final wasteQty = _computeWasteQuantity(t);
    return wasteQty > 0 ||
        (progressId != null &&
            (widget.trayIdsWithWastage.contains(t.productionProgress.primaryTrayId) ||
                widget.wastageByOriginalId.containsKey(progressId)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trays.isEmpty) {
      return const Center(
        child: Text(
          'No trays found',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
        ),
      );
    }

    final bool isAllSelected = widget.trays.isNotEmpty &&
        widget.trays.every((t) => widget.selectedReworkTrayIds.contains(t.productionProgress.id));
    final bool isAnySelected = widget.trays.isNotEmpty &&
        widget.trays.any((t) => widget.selectedReworkTrayIds.contains(t.productionProgress.id));

    final nonBackendHeldTrays = widget.trays.where((t) => t.productionProgress.holdFlag != true).toList();
    final bool isAllHoldSelected = nonBackendHeldTrays.isNotEmpty &&
        nonBackendHeldTrays.every((t) {
          final trayId = t.primaryTrayModel.id ?? t.productionProgress.id;
          return widget.holdTrayIds.contains(trayId);
        });
    final bool isAnyHoldSelected = widget.trays.any((t) {
      final trayId = t.primaryTrayModel.id ?? t.productionProgress.id;
      return t.productionProgress.holdFlag == true || widget.holdTrayIds.contains(trayId);
    });

    return Column(
      children: [
        // ── Table header (Knitting / GBS Style) ─────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9), // Light Slate
            border: Border(
              bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              const Expanded(flex: 5, child: Text('TRAY CODE', textAlign: TextAlign.center, style: _headerStyle)),
              const Expanded(flex: 8, child: Text('ITEM DESCRIPTION', textAlign: TextAlign.center, style: _headerStyle)),
              const Expanded(flex: 4, child: Text('COLOR', textAlign: TextAlign.center, style: _headerStyle)),
              const Expanded(flex: 3, child: Text('SIZE', textAlign: TextAlign.center, style: _headerStyle)),
              const Expanded(flex: 3, child: Text('PCS/TUBE', textAlign: TextAlign.center, style: _headerStyle)),
              const Expanded(flex: 3, child: Text('TUBES', textAlign: TextAlign.center, style: _headerStyle)),
              const Expanded(flex: 3, child: Text('PCS', textAlign: TextAlign.center, style: _headerStyle)),
              const Expanded(flex: 4, child: Text('WASTAGE QTY', textAlign: TextAlign.center, style: _headerStyle)),
              if (widget.onHoldToggle != null)
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          visualDensity: VisualDensity.compact,
                          value: isAllHoldSelected ? true : (isAnyHoldSelected ? null : false),
                          tristate: true,
                          activeColor: Colors.red.shade700,
                          onChanged: (val) {
                            final shouldSelect = val == true;
                            if (widget.onSelectAllHoldToggle != null) {
                              widget.onSelectAllHoldToggle!(shouldSelect);
                            } else {
                              for (final t in nonBackendHeldTrays) {
                                final trayId = t.primaryTrayModel.id ?? t.productionProgress.id;
                                if (trayId != null) {
                                  final isCur = widget.holdTrayIds.contains(trayId);
                                  if ((shouldSelect && !isCur) || (!shouldSelect && isCur)) {
                                    widget.onHoldToggle!(trayId);
                                  }
                                }
                              }
                            }
                          },
                        ),
                        const Text(
                          'HOLD',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
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
                ),
              const SizedBox(
                width: 44,
                child: Text('ACTION', textAlign: TextAlign.center, style: _headerStyle),
              ),
            ],
          ),
        ),

        // ── Tray rows ───────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.trays.length,
            itemBuilder: (ctx, idx) {
              final t = widget.trays[idx];
              final id = t.productionProgress.id;
              final isSel = widget.selectedReworkTrayIds.contains(id);
              final tubes = (t.productionProgress.secondaryQuantity ?? t.productionProgress.primaryQuantity ?? 0).toDouble();
              final pgt = t.item.perGarmentTube;
              final garmentPcs = pgt > 0 ? tubes * pgt : 0;

              final bool isAlreadyHeld = t.productionProgress.holdFlag == true;
              final bool isToggledHold = widget.holdTrayIds.contains(t.primaryTrayModel.id) || widget.holdTrayIds.contains(t.productionProgress.id);
              final bool isHeld = isAlreadyHeld || isToggledHold;

              final double wasteQty = _computeWasteQuantity(t);
              final bool hasWaste = _hasWaste(t);
              final isSaving = id != null && _loadingRows[id] == true;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isHeld
                      ? const Color(0xFFFFF1F2)
                      : (idx.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Tray Code
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            t.primaryTrayModel.trayCode ?? '-',
                            textAlign: TextAlign.center,
                            style: _blueCellStyle.copyWith(
                              color: isHeld ? const Color(0xFFDC2626) : const Color(0xFF1B64A3),
                            ),
                          ),
                          if (isAlreadyHeld)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ON HOLD',
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Item Description
                    Expanded(
                      flex: 8,
                      child: Text(
                        t.item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Color
                    Expanded(
                      flex: 4,
                      child: Text(
                        t.item.colorDescription?.isNotEmpty == true ? t.item.colorDescription! : '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Size
                    Expanded(
                      flex: 3,
                      child: Text(
                        t.item.sizeDescription?.isNotEmpty == true ? t.item.sizeDescription! : '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Pcs / Tube
                    Expanded(
                      flex: 3,
                      child: Text(
                        pgt > 0 ? pgt.toStringAsFixed(0) : '-',
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Tubes
                    Expanded(
                      flex: 3,
                      child: Text(
                        tubes.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: _cellStyle.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),

                    // Pcs
                    Expanded(
                      flex: 3,
                      child: Text(
                        garmentPcs > 0 ? garmentPcs.toStringAsFixed(0) : '-',
                        textAlign: TextAlign.center,
                        style: _cellStyle,
                      ),
                    ),

                    // Wastage QTY
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: hasWaste && wasteQty > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFECACA), width: 1),
                                ),
                                child: Text(
                                  wasteQty.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              )
                            : const Text(
                                '0',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                      ),
                    ),

                    // Hold Checkbox
                    if (widget.onHoldToggle != null)
                      Expanded(
                        flex: 3,
                        child: Checkbox(
                          visualDensity: VisualDensity.compact,
                          value: isHeld,
                          activeColor: Colors.red.shade700,
                          onChanged: isAlreadyHeld
                              ? null
                              : (val) {
                                  final trayId = t.primaryTrayModel.id ?? t.productionProgress.id;
                                  if (trayId != null) {
                                    widget.onHoldToggle!(trayId);
                                  }
                                },
                        ),
                      ),

                    // Rework Checkbox
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
                      ),

                    // 3-Dot Action Button
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1B64A3),
                                ),
                              )
                            : (id != null)
                                ? Theme(
                                    data: Theme.of(context).copyWith(
                                      popupMenuTheme: PopupMenuThemeData(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        color: Colors.white,
                                        elevation: 6,
                                      ),
                                    ),
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        size: 20,
                                        color: Color(0xFF546E7A),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Tray Actions',
                                      onSelected: (value) async {
                                        if (value == 'add_waste') {
                                          if (!widget.isBatchStarted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Cannot add waste. The batch has not been started yet.'),
                                                backgroundColor: Color(0xFFDC2626),
                                              ),
                                            );
                                            return;
                                          }
                                          final double requiredTubes = t.productionProgress.requiredQty?.toDouble() ??
                                              (hasWaste ? tubes + wasteQty : tubes);
                                          final wastageRecord = widget.wastageByOriginalId[id];
                                          final int initialProductGrade = wastageRecord?.productionProgress.productGrade ?? t.productionProgress.productGrade ?? 1;
                                          final int? initialDefectListId = wastageRecord?.productionProgress.defectListId;
                                          final List<int> initialDefectListIds = initialDefectListId != null ? [initialDefectListId] : const [];
                                          final String? initialRemarks = wastageRecord?.productionProgress.remarks;
                                          _showAddWasteDialog(
                                            context,
                                            id,
                                            t.primaryTrayModel.trayCode ?? '-',
                                            tubes,
                                            requiredTubes,
                                            hasCurrentWaste: hasWaste,
                                            initialProductGrade: initialProductGrade,
                                            initialDefectListIds: initialDefectListIds,
                                            initialRemarks: initialRemarks,
                                          );
                                        } else if (value == 'delete_waste') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              title: const Row(
                                                children: [
                                                  Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Delete Waste',
                                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                                  ),
                                                ],
                                              ),
                                              content: Text(
                                                'Are you sure you want to delete waste for Tray ${t.primaryTrayModel.trayCode ?? '-'} and restore quantity?',
                                                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFDC2626),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Delete Waste', style: TextStyle(fontWeight: FontWeight.w800)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            _handleDeleteWastage(id);
                                          }
                                        }
                                      },
                                      itemBuilder: (context) {
                                        final bool canAddWaste = widget.isBatchStarted;
                                        final bool canDeleteWaste = hasWaste && widget.onDeleteWastage != null;

                                        return [
                                          PopupMenuItem<String>(
                                            value: 'add_waste',
                                            enabled: canAddWaste,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.playlist_add_rounded,
                                                  size: 18,
                                                  color: canAddWaste ? const Color(0xFF1B64A3) : const Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Add Waste',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: canAddWaste ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                                if (!canAddWaste) ...[
                                                  const SizedBox(width: 6),
                                                  const Text('(Batch Not Started)', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                                                ],
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'delete_waste',
                                            enabled: canDeleteWaste,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: canDeleteWaste ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Delete Waste',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: canDeleteWaste ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ];
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleDeleteWastage(int progressId) async {
    setState(() {
      _loadingRows[progressId] = true;
    });
    try {
      await widget.onDeleteWastage?.call(progressId);
    } finally {
      if (mounted) {
        setState(() {
          _loadingRows[progressId] = false;
        });
      }
    }
  }

  void _showAddWasteDialog(
    BuildContext context,
    int progressId,
    String trayCode,
    double currentQty,
    double requiredQty, {
    bool hasCurrentWaste = false,
    int initialProductGrade = 1,
    List<int> initialDefectListIds = const [],
    String? initialRemarks,
    String? initialReason,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PremiumAddWasteDialog(
        trayCode: trayCode,
        operationName: widget.operationName,
        currentQty: currentQty,
        requiredQty: requiredQty,
        initialProductGrade: initialProductGrade,
        initialDefectListIds: initialDefectListIds,
        initialRemarks: initialRemarks,
        initialReason: initialReason,
        defectLists: widget.defectLists,
        onSave: (finalQty, productGrade, defectListIds, reason, remarks) async {
          setState(() {
            _loadingRows[progressId] = true;
          });
          try {
            await widget.onQuantitySubmit?.call(progressId, finalQty, productGrade, defectListIds, reason, remarks);
          } finally {
            if (mounted) {
              setState(() {
                _loadingRows[progressId] = false;
              });
            }
          }
        },
        onDelete: (hasCurrentWaste && widget.onDeleteWastage != null)
            ? () async {
                setState(() {
                  _loadingRows[progressId] = true;
                });
                try {
                  await widget.onDeleteWastage?.call(progressId);
                } finally {
                  if (mounted) {
                    setState(() {
                      _loadingRows[progressId] = false;
                    });
                  }
                }
              }
            : null,
      ),
    );
  }
}

/// A modern, premium designed dialog for adding tray waste / adjusting quantities.
class _PremiumAddWasteDialog extends StatefulWidget {
  final String trayCode;
  final String operationName;
  final double currentQty;
  final double requiredQty;
  final int initialProductGrade;
  final List<int> initialDefectListIds;
  final String? initialRemarks;
  final String? initialReason;
  final List<DefectListItemModel> defectLists;
  final Future<void> Function(
    double finalQty,
    int productGrade,
    List<int> defectListIds,
    String reason,
    String remarks,
  ) onSave;
  final Future<void> Function()? onDelete;

  const _PremiumAddWasteDialog({
    required this.trayCode,
    required this.operationName,
    required this.currentQty,
    required this.requiredQty,
    this.initialProductGrade = 1,
    this.initialDefectListIds = const [],
    this.initialRemarks,
    this.initialReason,
    this.defectLists = const [],
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_PremiumAddWasteDialog> createState() => _PremiumAddWasteDialogState();
}

class _PremiumAddWasteDialogState extends State<_PremiumAddWasteDialog> {
  int _selectedMode = 2; // Default to Wastage Qty (2)
  int _selectedProductGrade = 1; // 1 = Grade B, 2 = Grade C
  List<int> _selectedDefectListIds = [];
  late TextEditingController _qtyController;
  late TextEditingController _wastageController;
  late TextEditingController _reasonController;
  late TextEditingController _remarksController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedProductGrade = (widget.initialProductGrade == 2) ? 2 : 1;
    _selectedDefectListIds = List<int>.from(widget.initialDefectListIds);
    _qtyController = TextEditingController(text: widget.currentQty.toStringAsFixed(0));
    final initialWaste = widget.requiredQty - widget.currentQty;
    _wastageController = TextEditingController(
      text: initialWaste > 0 ? initialWaste.toStringAsFixed(0) : '0',
    );
    _reasonController = TextEditingController(text: widget.initialReason ?? '');
    _remarksController = TextEditingController(text: widget.initialRemarks ?? '');

    _reasonController.addListener(() {
      if (mounted) setState(() {});
    });
    _remarksController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _wastageController.dispose();
    _reasonController.dispose();
    _remarksController.dispose();
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

  void _increment(bool isQtyField) {
    if (isQtyField) {
      final current = int.tryParse(_qtyController.text) ?? 0;
      if (current < widget.requiredQty) {
        _qtyController.text = (current + 1).toString();
        _onChanged(_qtyController.text, true);
      }
    } else {
      final current = int.tryParse(_wastageController.text) ?? 0;
      if (current < widget.requiredQty - 1) {
        _wastageController.text = (current + 1).toString();
        _onChanged(_wastageController.text, false);
      }
    }
  }

  void _decrement(bool isQtyField) {
    if (isQtyField) {
      final current = int.tryParse(_qtyController.text) ?? 0;
      if (current > 1) {
        _qtyController.text = (current - 1).toString();
        _onChanged(_qtyController.text, true);
      }
    } else {
      final current = int.tryParse(_wastageController.text) ?? 0;
      if (current > 0) {
        _wastageController.text = (current - 1).toString();
        _onChanged(_wastageController.text, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _qtyController.text;
    final parsedQty = double.tryParse(text) ?? 0;
    final isReasonValid = _reasonController.text.trim().isNotEmpty;
    final isRemarksValid = _remarksController.text.trim().isNotEmpty;
    final currentWaste = (widget.requiredQty - parsedQty).clamp(0, widget.requiredQty).toInt();
    final isValid = currentWaste > 0 && parsedQty > 0 && parsedQty < widget.requiredQty && isReasonValid && isRemarksValid;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF0D47A1), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Tray Wastage',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B64A3).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'TRAY: ${widget.trayCode}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B64A3),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ── Body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Context Information HUD
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMetricItem('OPERATION', widget.operationName.toUpperCase(), Icons.settings_suggest_outlined),
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                          Expanded(
                            child: _buildMetricItem('REQ TUBES', '${widget.requiredQty.toStringAsFixed(0)} Units', Icons.inventory_2_outlined),
                          ),
                          Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                          Expanded(
                            child: _buildMetricItem('CURR TUBES', '${widget.currentQty.toStringAsFixed(0)} Units', Icons.scale_outlined),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Mode Selection Tabs
                    const Text(
                      'ADJUSTMENT MODE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeTab(
                              title: 'Wastage Qty',
                              subtitle: 'Enter rejected tubes',
                              icon: Icons.delete_sweep_outlined,
                              modeIndex: 2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildModeTab(
                              title: 'Good Tubes',
                              subtitle: 'Enter remaining tubes',
                              icon: Icons.check_circle_outline_rounded,
                              modeIndex: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Input Stepper Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedMode == 2 ? 'WASTAGE TUBES COUNT' : 'REMAINING GOOD TUBES',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _selectedMode == 2 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedMode == 2 ? 'Max: ${(widget.requiredQty - 1).toInt()}' : 'Max: ${widget.requiredQty.toInt()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedMode == 2 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStepButton(
                                icon: Icons.remove_rounded,
                                onPressed: _isSaving ? null : () => _decrement(_selectedMode == 1),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _selectedMode == 1 ? _qtyController : _wastageController,
                                  enabled: !_isSaving,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF1B64A3), width: 2),
                                    ),
                                  ),
                                  onChanged: (val) => _onChanged(val, _selectedMode == 1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildStepButton(
                                icon: Icons.add_rounded,
                                onPressed: _isSaving ? null : () => _increment(_selectedMode == 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Live Calculation Summary Chips
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Good: ${parsedQty.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Wastage: $currentWaste',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Product Grade Selection
                    const Text(
                      'PRODUCT GRADE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGradeCard(
                            gradeValue: 1,
                            title: 'Grade B',
                            subtitle: 'Secondary / Minor Defect',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildGradeCard(
                            gradeValue: 2,
                            title: 'Grade C',
                            subtitle: 'Scrap / Major Damage',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Defects Selection Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DEFECT REASONS (${_selectedDefectListIds.length} SELECTED)',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        InkWell(
                          onTap: _isSaving ? null : () => _showMultiDefectPicker(context),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 13, color: Color(0xFF1D4ED8)),
                                SizedBox(width: 3),
                                Text('Select Defects', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Selected Defects Chip Container
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                      ),
                      child: _selectedDefectListIds.isEmpty
                          ? InkWell(
                              onTap: _isSaving ? null : () => _showMultiDefectPicker(context),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF94A3B8)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Tap to select defect reasons...',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ..._selectedDefectListIds.map((id) {
                                  final matches = widget.defectLists.where((d) => d.defectList.id == id).toList();
                                  final d = matches.isNotEmpty ? matches.first.defectList : null;
                                  final label = (d?.description != null && d!.description!.isNotEmpty)
                                      ? d.description!
                                      : (d?.code ?? 'Defect #$id');
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF93C5FD)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (d?.code != null && d!.code!.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDBEAFE),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              d.code!,
                                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                        ],
                                        Flexible(
                                          child: Text(
                                            label,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: _isSaving
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _selectedDefectListIds.remove(id);
                                                  });
                                                },
                                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),

                    const SizedBox(height: 18),

                    // Reason Text Field (Required)
                    Row(
                      children: [
                        const Text(
                          'REASON',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const Spacer(),
                        if (_reasonController.text.trim().isEmpty)
                          const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reasonController,
                      enabled: !_isSaving,
                      maxLines: 2,
                      minLines: 1,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Enter reason for wastage...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _reasonController.text.trim().isEmpty
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF93C5FD),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Remarks Text Field (Required)
                    Row(
                      children: [
                        const Text(
                          'REMARKS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const Spacer(),
                        if (_remarksController.text.trim().isEmpty)
                          const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _remarksController,
                      enabled: !_isSaving,
                      maxLines: 2,
                      minLines: 1,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Enter additional remarks...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: _remarksController.text.trim().isEmpty
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF93C5FD),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer Actions ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Row(
                  children: [
                    if (widget.currentQty < widget.requiredQty && widget.onDelete != null) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        label: const Text('Delete Waste', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() {
                                  _isSaving = true;
                                });
                                try {
                                  await widget.onDelete!();
                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isSaving = false;
                                    });
                                  }
                                }
                              },
                      ),
                      const Spacer(),
                    ] else ...[
                      const Spacer(),
                    ],
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Apply Waste',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      onPressed: isValid && !_isSaving
                          ? () async {
                              setState(() {
                                _isSaving = true;
                              });
                              try {
                                await widget.onSave(
                                  parsedQty,
                                  _selectedProductGrade,
                                  _selectedDefectListIds,
                                  _reasonController.text.trim(),
                                  _remarksController.text.trim(),
                                );
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.4),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required int modeIndex,
  }) {
    final isSelected = _selectedMode == modeIndex;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isSaving
          ? null
          : () {
              setState(() {
                _selectedMode = modeIndex;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 8.5,
                      color: isSelected ? const Color(0xFF546E7A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton({required IconData icon, required VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: onPressed != null ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildGradeCard({
    required int gradeValue,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedProductGrade == gradeValue;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _isSaving
          ? null
          : () {
              setState(() {
                _selectedProductGrade = gradeValue;
              });
            },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMultiDefectPicker(BuildContext context) {
    final tempSelected = List<int>.from(_selectedDefectListIds);
    String filterText = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = widget.defectLists.where((item) {
              final d = item.defectList;
              final desc = (d.description ?? '').toLowerCase();
              final code = (d.code ?? '').toLowerCase();
              final query = filterText.toLowerCase();
              return desc.contains(query) || code.contains(query);
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Defect Reasons',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              '${tempSelected.length} defect(s) selected',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (tempSelected.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    tempSelected.clear();
                                  });
                                },
                                child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                              ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedDefectListIds = tempSelected;
                                });
                              },
                              child: const Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search defect code or description...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          filterText = val;
                        });
                      },
                    ),
                  ),
                  // Defect List
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching defects found',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, idx) {
                              final item = filteredList[idx];
                              final d = item.defectList;
                              final isSelected = tempSelected.contains(d.id);
                              final desc = d.description ?? 'Defect #${d.id}';
                              final code = d.code;

                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      tempSelected.remove(d.id);
                                    } else {
                                      tempSelected.add(d.id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: const Color(0xFF0D47A1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (checked) {
                                          setModalState(() {
                                            if (checked == true) {
                                              if (!tempSelected.contains(d.id)) tempSelected.add(d.id);
                                            } else {
                                              tempSelected.remove(d.id);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (code != null && code.isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                                ),
                                                child: Text(
                                                  code,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                            Text(
                                              desc,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
