import 'package:flutter/material.dart';
import 'package:active_wear_scanning/features/tray/model/plan_header_model.dart';

class WorkOrderDropdown extends StatefulWidget {
  final List<PlanLineResponseModel>? planLines;
  final PlanLineResponseModel? selectedPlanLine;
  final ValueChanged<PlanLineResponseModel?> onChanged;
  final bool enabled;

  const WorkOrderDropdown({
    super.key,
    required this.planLines,
    required this.selectedPlanLine,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<WorkOrderDropdown> createState() => _WorkOrderDropdownState();
}

class _WorkOrderDropdownState extends State<WorkOrderDropdown> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
      _controller.forward();
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeDropdown,
              child: Container(),
            ),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                elevation: 0,
                color: Colors.transparent,
                child: _buildDropdownMenu(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.planLines == null || widget.planLines!.isEmpty) return const SizedBox.shrink();

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: widget.enabled ? const Color(0xFFF8F9FA) : Colors.grey.shade100, // Very subtle off-white or grey
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: !widget.enabled
                  ? Colors.grey.shade300
                  : (_isOpen ? const Color(0xFF1B64A3) : const Color(0xFFCFD8DC)),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: widget.selectedPlanLine == null
                    ? Text(
                        'Work Order Selection',
                        style: TextStyle(
                          color: widget.enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.selectedPlanLine!.workOrderHeader.workOrderCode,
                            style: TextStyle(
                              color: widget.enabled ? const Color(0xFF263238) : Colors.grey.shade500,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.selectedPlanLine!.item.description,
                            style: TextStyle(
                              color: widget.enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
              RotationTransition(
                turns: _rotateAnimation,
                child: Icon(
                  Icons.arrow_drop_down_rounded, 
                  color: !widget.enabled
                      ? Colors.grey.shade400
                      : (_isOpen ? const Color(0xFF1B64A3) : const Color(0xFF546E7A)),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownMenu() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFCFD8DC), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: widget.planLines!.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (context, index) {
          final plan = widget.planLines![index];
          final isSelected = plan == widget.selectedPlanLine;

          return InkWell(
            onTap: () {
              widget.onChanged(plan);
              _closeDropdown();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.workOrderHeader.workOrderCode,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF1B64A3) : const Color(0xFF263238),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          plan.item.description,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded, color: Color(0xFF1B64A3), size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
