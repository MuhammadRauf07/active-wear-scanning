import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:tasdeeq/screens/home/common/text_field.dart';

class CustomExpandedAsyncDropdown<T> extends StatefulWidget {
  final List<T>? items;
  final String? hint;
  final double width;
  final double height;
  final double? textSize;
  final bool? isReadOnly;
  final bool? isShowError;
  final bool? isShowSearch;
  final bool isMultiSelect;
  final Color? borderColor;
  final String? errorMessage;
  final Color? itemTextColor;
  final Color? backgroundColor;
  final List<T>? selectedValues;
  final T? selectedValue;
  final double? itemHeight;
  final bool showSelectAll;
  final EdgeInsets? selectAllPadding;
  final Function(T?)? onChanged;
  final Function(List<T>)? onMultiChanged;
  final String Function(T) itemAsString;
  final EdgeInsetsGeometry? contentPadding;
  final Future<List<T>> Function()? dropdownAsyncItems;
  final TextStyle Function(T)? itemTextStyleBuilder;
  final String? Function(T item)? itemTagBuilder;


  const CustomExpandedAsyncDropdown({
    super.key,
    this.selectedValue,
    this.selectedValues,
    this.borderColor,
    this.itemTextColor,
    this.backgroundColor,
    this.items,
    this.hint,
    this.isShowSearch,
    this.contentPadding,
    this.onChanged,
    this.onMultiChanged,
    this.dropdownAsyncItems,
    required this.itemAsString,
    this.width = 140,
    this.height = 52,
    this.textSize,
    this.isReadOnly,
    this.isShowError,
    this.errorMessage,
    this.itemTextStyleBuilder,
    this.isMultiSelect = false,
    this.itemHeight,
    this.showSelectAll = true,
    this.selectAllPadding = const EdgeInsets.only(bottom: 4),
    this.itemTagBuilder,
  });

  @override
  State<CustomExpandedAsyncDropdown<T>> createState() => _CustomExpandedAsyncDropdownState<T>();
}

class _CustomExpandedAsyncDropdownState<T> extends State<CustomExpandedAsyncDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _items = [];
  List<T> _filteredItems = [];
  bool isLoading = true;
  List<T> _selectedItems = [];
  final expansionKey = GlobalKey<DisclosureState<T>>();
  List<T> _pendingSelectedItems = [];

  @override
  void didUpdateWidget(covariant CustomExpandedAsyncDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final parentChanged = widget.key != oldWidget.key;

    if (parentChanged) {
      setState(() {
        isLoading = true;
        _items = [];
        _filteredItems = [];
      });

      if (widget.dropdownAsyncItems != null) {
        _initializeItems();
      }

      _selectedItems = widget.selectedValues ?? [];
      _pendingSelectedItems = List<T>.from(_selectedItems);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedItems = widget.selectedValues ?? [];
    _pendingSelectedItems = List<T>.from(_selectedItems);
    if (widget.dropdownAsyncItems != null) {
      _initializeItems();
    } else {
      _items = widget.items ?? [];
      final seen = <String>{};
      _items = _items.where((item) => seen.add(widget.itemAsString(item))).toList();
      _filteredItems = _items;
      isLoading = false;
    }
  }

  void _initializeItems() async {
    try {
      _items = await widget.dropdownAsyncItems!();
      final seen = <String>{};
      _items = _items.where((item) => seen.add(widget.itemAsString(item))).toList();
      _filteredItems = _items;
      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _filterItems(String enteredKeyword) {
    setState(() {
      _filteredItems = enteredKeyword.isEmpty ? _items : _items.where((item) => widget.itemAsString(item).toLowerCase().contains(enteredKeyword.toLowerCase())).toList();
    });
  }

  void _toggleSelection(T item) {
    setState(() {
      if (_pendingSelectedItems.contains(item)) {
        _pendingSelectedItems.remove(item);
      } else {
        _pendingSelectedItems.add(item);
      }
    });
  }

  void _applyMultiSelectionAndClose() {
    setState(() {
      _selectedItems = List<T>.from(_pendingSelectedItems);
    });
    widget.onMultiChanged?.call(_selectedItems);
    expansionKey.currentState?.handleTap();
  }

  void setSelectedItemAtTop() {
    if (!widget.isMultiSelect && widget.selectedValue != null && _filteredItems.contains(widget.selectedValue)) {
      _filteredItems
        ..remove(widget.selectedValue)
        ..insert(0, widget.selectedValue as T);
    }
  }

  @override
  Widget build(BuildContext context) {
    setSelectedItemAtTop();
    final displayText = widget.isMultiSelect
        ? (_selectedItems.isEmpty ? widget.hint ?? 'Select options' : _selectedItems.map(widget.itemAsString).join(', '))
        : (widget.selectedValue == null ? widget.hint ?? 'Select an option' : widget.itemAsString(widget.selectedValue as T));

    return Disclosure<T>(
      key: expansionKey,
      borderColor: widget.borderColor,
      padding: widget.selectAllPadding,
      trigger: Text(
        displayText,
        style: TextStyle(
          overflow: TextOverflow.ellipsis,
          fontSize: widget.textSize ?? 12,
          color: widget.borderColor ?? Colors.black87,
        ),
      ),
      config: DisclosureConfig(
        maxHeight: widget.height,
        expandDuration: const Duration(milliseconds: 200),
        collapseDuration: const Duration(milliseconds: 200),
        expandCurve: Curves.easeOut,
        collapseCurve: Curves.easeIn,
      ),
      onDoneTap: widget.isMultiSelect ? _applyMultiSelectionAndClose : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isShowSearch ?? true)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterItems,
                decoration: InputDecoration(
                  hintText: "Search",
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: widget.borderColor ?? Colors.grey),
                  ),
                ),
              ),
            ),

          /// Select All / Clear All toggle
          if (widget.isMultiSelect && widget.showSelectAll && _filteredItems.isNotEmpty)
            Padding(
              padding: widget.selectAllPadding!,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      final allSelected = _filteredItems.every(_pendingSelectedItems.contains);
                      if (allSelected) {
                        _pendingSelectedItems.removeWhere(_filteredItems.contains);
                      } else {
                        for (var item in _filteredItems) {
                          if (!_pendingSelectedItems.contains(item)) {
                            _pendingSelectedItems.add(item);
                          }
                        }
                      }
                    });
                  },
                  child: Text(
                    _filteredItems.every(_pendingSelectedItems.contains) ? 'Clear All' : 'Select All',
                    style: TextStyle(fontSize: 14, color: widget.borderColor),
                  ),
                ),
              ),
            ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_filteredItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text("No Data Found", style: TextStyle(fontSize: 14, color: Colors.grey)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = widget.isMultiSelect ? _pendingSelectedItems.contains(item) : item == widget.selectedValue;
                  final tagText = widget.itemTagBuilder?.call(item);

                  return Container(
                    height: widget.itemHeight,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor ?? Colors.transparent,
                      borderRadius: index != _filteredItems.length - 1
                          ? BorderRadius.zero
                          : const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.itemAsString(item),
                                  style: TextStyle(
                                    fontSize: widget.textSize ?? 13,
                                    color: widget.itemTextStyleBuilder?.call(item).color ?? widget.itemTextColor ?? Colors.black,
                                    fontWeight: widget.itemTextStyleBuilder?.call(item).fontWeight ?? (widget.textSize != null ? FontWeight.w600 : FontWeight.normal),
                                  ),
                                ),
                              ),
                              if (tagText != null)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tagText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: isSelected ? Icon(Icons.check, color: widget.itemTextColor ?? Colors.blue) : null,
                          onTap: () {
                            if (widget.isMultiSelect) {
                              _toggleSelection(item);
                            } else {
                              widget.onChanged?.call(item);
                              expansionKey.currentState?.handleTap();
                            }
                          },
                        ),
                        if (index != _filteredItems.length - 1) Divider(color: widget.borderColor, height: 0.1, thickness: 0.5),
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
}

class DisclosureConfig {
  final Duration expandDuration;
  final Duration collapseDuration;
  final Curve expandCurve;
  final Curve collapseCurve;
  final double maxHeight;

  const DisclosureConfig({
    this.expandDuration = const Duration(milliseconds: 200),
    this.collapseDuration = const Duration(milliseconds: 200),
    this.expandCurve = Curves.easeOut,
    this.collapseCurve = Curves.easeIn,
    this.maxHeight = 52,
  });
}

class Disclosure<T> extends StatefulWidget {
  final Widget? trigger;
  final Widget content;
  final Color? borderColor;
  final bool initiallyExpanded;
  final DisclosureConfig? config;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onDoneTap;

  const Disclosure({
    super.key,
    this.trigger,
    this.borderColor,
    required this.content,
    this.initiallyExpanded = false,
    this.config,
    this.decoration,
    this.padding = const EdgeInsets.all(12),
    this.onDoneTap,
  });

  @override
  State<Disclosure<T>> createState() => DisclosureState<T>();
}

class DisclosureState<T> extends State<Disclosure<T>> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightFactor;
  late bool _isExpanded;

  bool get isExpanded => _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: widget.config?.expandDuration ?? const Duration(milliseconds: 200),
      reverseDuration: widget.config?.collapseDuration ?? const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(
      curve: _isExpanded ? (widget.config?.expandCurve ?? Curves.easeOut) : (widget.config?.collapseCurve ?? Curves.easeIn),
    ));

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  void handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.decoration ??
          BoxDecoration(
            border: Border.all(color: widget.borderColor ?? Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.trigger != null)
            InkWell(
              onTap: handleTap,
              child: SizedBox(
                height: widget.config?.maxHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(padding: EdgeInsets.only(left: 10)),
                    Expanded(
                      child: Padding(padding: widget.padding ?? EdgeInsets.zero, child: widget.trigger!),
                    ),
                    Builder(
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: isExpanded && widget.onDoneTap != null
                              ? GestureDetector(
                            onTap: widget.onDoneTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: widget.borderColor ?? Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(6), // rounded look
                              ),
                              child: Text(
                                "Done",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.borderColor,
                                ),
                              ),
                            ),
                          )
                              : Icon(isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: widget.borderColor ?? Colors.grey.shade400),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (_isExpanded) Divider(thickness: 0.5, color: Colors.grey.shade400, height: 1),
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller.view,
              builder: (context, child) {
                return Align(heightFactor: _heightFactor.value, child: child);
              },
              child: widget.content,
            ),
          ),
        ],
      ),
    );
  }
}
