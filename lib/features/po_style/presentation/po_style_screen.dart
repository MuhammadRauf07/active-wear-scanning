import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/api/plex-result/plex_api_result.dart';
import 'package:active_wear_scanning/core/theme/app_theme.dart';
import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_snackbar.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/custom_expanded_async_dropdown.dart';
import 'package:active_wear_scanning/features/common-models/common_models.dart';
import 'package:active_wear_scanning/features/po_style/model/po_style_model.dart';
import 'package:active_wear_scanning/features/po_style/repo/po_style_repo.dart';
import 'package:plex/plex_di/plex_dependency_injection.dart';

class PoStyleScreen extends StatefulWidget {
  const PoStyleScreen({super.key});

  @override
  State<PoStyleScreen> createState() => _PoStyleScreenState();
}

class _PoStyleScreenState extends State<PoStyleScreen> {
  final _poStyleRepo = fromPlex<PoStyleRepo>();

  List<PoStyleItem> _poStyles = [];
  bool _isLoadingPoStyles = false;

  List<String> _customers = [];
  String? _selectedCustomer;

  List<String> _customerPOs = [];
  String? _selectedCustomerPO;

  List<CostCenterLine> _costCenterLines = [];
  CostCenterLine? _selectedCostCenterLine;
  bool _isLoadingCostCenterLines = false;

  final Set<int> _selectedPoStyleIds = {};

  @override
  void initState() {
    super.initState();
    _fetchPoStyles();
  }

  Future<void> _fetchPoStyles() async {
    setState(() {
      _isLoadingPoStyles = true;
      _customers = [];
      _selectedCustomer = null;
      _customerPOs = [];
      _selectedCustomerPO = null;
      _selectedPoStyleIds.clear();
    });
    final res = await _poStyleRepo.fetchPoStyles();
    if (mounted) {
      if (res.success && res.data != null) {
        final allStyles = res.data as List<PoStyleItem>;
        final uniqueCustomers = allStyles
            .map((item) => item.poStyle.customer)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        uniqueCustomers.sort();
        setState(() {
          _poStyles = allStyles;
          _customers = uniqueCustomers;
          _isLoadingPoStyles = false;
        });
      } else {
        setState(() => _isLoadingPoStyles = false);
        AppSnackBar.showError(context, message: res.message);
      }
    }
  }

  Future<void> _fetchCostCenterLines() async {
    setState(() {
      _isLoadingCostCenterLines = true;
      _costCenterLines = [];
      _selectedCostCenterLine = null;
    });
    final res = await _poStyleRepo.fetchCostCenterLines();
    if (mounted) {
      if (res.success && res.data != null) {
        setState(() {
          _costCenterLines = res.data as List<CostCenterLine>;
          _isLoadingCostCenterLines = false;
        });
      } else {
        setState(() => _isLoadingCostCenterLines = false);
        AppSnackBar.showError(context, message: res.message);
      }
    }
  }

  void _onCustomerChanged(String? val) {
    HapticFeedbackHelper.buttonClick();
    setState(() {
      _selectedCustomer = val;
      _customerPOs = [];
      _selectedCustomerPO = null;
      _selectedPoStyleIds.clear();
      _costCenterLines = [];
      _selectedCostCenterLine = null;
    });
    if (val != null) {
      final uniquePOs = _poStyles
          .where((item) => item.poStyle.customer == val)
          .map((item) => item.poStyle.po)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      uniquePOs.sort();
      setState(() {
        _customerPOs = uniquePOs;
      });
    }
  }

  void _onCustomerPOChanged(String? val) {
    HapticFeedbackHelper.buttonClick();
    setState(() {
      _selectedCustomerPO = val;
      _selectedPoStyleIds.clear();
      _costCenterLines = [];
      _selectedCostCenterLine = null;
    });
    if (val != null) {
      _fetchCostCenterLines();
    }
  }

  List<PoStyleItem> get _filteredPoStyles {
    if (_selectedCustomer == null || _selectedCustomerPO == null) return [];
    return _poStyles
        .where((item) =>
            item.poStyle.customer == _selectedCustomer &&
            item.poStyle.po == _selectedCustomerPO)
        .toList();
  }

  Future<void> _saveChanges() async {
    if (_selectedCostCenterLine == null || _selectedPoStyleIds.isEmpty) return;

    HapticFeedbackHelper.buttonClick();
    AppLoader.show(context, message: 'Updating ${_selectedPoStyleIds.length} PO Styles...');

    final selectedItems = _poStyles
        .where((item) => _selectedPoStyleIds.contains(item.poStyle.id))
        .toList();
    final List<Future<PlexApiResult>> updateFutures = [];

    for (final item in selectedItems) {
      final updatedModel = item.poStyle.copyWith(
        lineCode: _selectedCostCenterLine!.name,
        line: _selectedCostCenterLine!.description,
      );
      updateFutures.add(_poStyleRepo.updatePoStyle(item.poStyle.id, updatedModel.toJson()));
    }

    try {
      final results = await Future.wait(updateFutures);
      if (mounted) AppLoader.hide(context);

      int successCount = 0;
      final List<String> errors = [];

      for (var i = 0; i < results.length; i++) {
        final res = results[i];
        if (res.success) {
          successCount++;
        } else {
          errors.add(res.message);
        }
      }

      if (mounted) {
        if (successCount == results.length) {
          HapticFeedbackHelper.scanSuccess();
          AppSnackBar.showSuccess(context, message: 'Successfully updated $successCount PO Styles.');
          Navigator.of(context).pop();
        } else {
          HapticFeedbackHelper.scanError();
          AppSnackBar.showError(
            context,
            message: 'Updated $successCount/${results.length} styles. Errors: ${errors.join(", ")}',
          );
          _fetchPoStyles();
        }
      }
    } catch (e) {
      if (mounted) AppLoader.hide(context);
      if (mounted) {
        HapticFeedbackHelper.scanError();
        AppSnackBar.showError(context, message: 'An unexpected error occurred: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !AppLoader.isVisible,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Standard slate-grey background
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildPlaceholderContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    final hasSelection = _selectedCostCenterLine != null && _selectedPoStyleIds.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
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
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PO Style',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263238),
                    ),
                  ),
                  Text(
                    'PO / DESIGN SPECIFICATION CONSOLE',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF546E7A),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: hasSelection ? _saveChanges : null,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('SAVE CHANGES'),
              style: AppTheme.saveButtonStyle(isEnabled: hasSelection),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT CUSTOMER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF546E7A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingPoStyles
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : CustomExpandedAsyncDropdown<String>(
                  selectedValue: _selectedCustomer,
                  items: _customers,
                  hint: "Select Customer...",
                  isShowSearch: true,
                  itemAsString: (c) => c,
                  borderColor: const Color(0xFFCFD8DC),
                  backgroundColor: Colors.white,
                  height: 48,
                  textSize: 13,
                  onChanged: _onCustomerChanged,
                ),
          if (_selectedCustomer != null) ...[
            const SizedBox(height: 16),
            const Text(
              'SELECT CUSTOMER PO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF546E7A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            CustomExpandedAsyncDropdown<String>(
              selectedValue: _selectedCustomerPO,
              items: _customerPOs,
              hint: "Select Customer PO...",
              isShowSearch: true,
              itemAsString: (po) => po,
              borderColor: const Color(0xFFCFD8DC),
              backgroundColor: Colors.white,
              height: 48,
              textSize: 13,
              onChanged: _onCustomerPOChanged,
            ),
          ],
          if (_selectedCustomerPO != null) ...[
            const SizedBox(height: 16),
            const Text(
              'SELECT COST CENTER LINE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF546E7A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _isLoadingCostCenterLines
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : CustomExpandedAsyncDropdown<CostCenterLine>(
                    selectedValue: _selectedCostCenterLine,
                    items: _costCenterLines,
                    hint: "Select Cost Center Line...",
                    isShowSearch: true,
                    itemAsString: (c) => c.name,
                    borderColor: const Color(0xFFCFD8DC),
                    backgroundColor: Colors.white,
                    height: 48,
                    textSize: 13,
                    onChanged: (val) {
                      HapticFeedbackHelper.buttonClick();
                      setState(() {
                        _selectedCostCenterLine = val;
                      });
                    },
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    final filtered = _filteredPoStyles;
    final showTable = _selectedCostCenterLine != null && filtered.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectionCard(),
          const SizedBox(height: 16),
          if (!showTable)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF90CAF9), width: 2),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 36,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'PO Style Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoadingPoStyles
                            ? 'Loading PO Style records from server...'
                            : _selectedCustomer == null
                                ? 'Please select a customer from the dropdown above to view styles.'
                                : _selectedCustomerPO == null
                                    ? 'Active Customer: $_selectedCustomer\n\nPlease select a Customer PO to view styles.'
                                    : _selectedCostCenterLine == null
                                        ? 'Active Customer: $_selectedCustomer\nActive PO: $_selectedCustomerPO\n\nPlease select a Cost Center Line to view styles.'
                                        : 'Active Customer: $_selectedCustomer\nActive PO: $_selectedCustomerPO\nActive Line: ${_selectedCostCenterLine!.name}\n\nNo records found for this combination.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF78909C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _buildPoStylesTable(filtered),
            ),
        ],
      ),
    );
  }

  Widget _buildPoStylesTable(List<PoStyleItem> items) {
    final allSelected = items.isNotEmpty && items.every((i) => _selectedPoStyleIds.contains(i.poStyle.id));
    const headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: Color(0xFF37474F),
      letterSpacing: 0.3,
    );
    const cellStyle = TextStyle(
      fontSize: 11,
      color: Color(0xFF263238),
      fontWeight: FontWeight.w500,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB0BEC5),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1020,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFB0BEC5), width: 1.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Checkbox(
                            value: allSelected,
                            activeColor: const Color(0xFF0D47A1),
                            onChanged: (val) {
                              HapticFeedbackHelper.buttonClick();
                              setState(() {
                                if (val == true) {
                                  _selectedPoStyleIds.addAll(items.map((i) => i.poStyle.id));
                                } else {
                                  _selectedPoStyleIds.clear();
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 90, child: Text('Customer', style: headerStyle)),
                        const SizedBox(width: 110, child: Text('PO', style: headerStyle)),
                        const SizedBox(width: 110, child: Text('Article No', style: headerStyle)),
                        const SizedBox(width: 50, child: Text('Size', style: headerStyle)),
                        const SizedBox(width: 110, child: Text('Color Code', style: headerStyle)),
                        const SizedBox(width: 110, child: Text('Batch', style: headerStyle)),
                        const SizedBox(width: 110, child: Text('Bundle No', style: headerStyle)),
                        const SizedBox(width: 120, child: Text('Line', style: headerStyle)),
                        const SizedBox(width: 120, child: Text('Line Desc', style: headerStyle)),
                      ],
                    ),
                  ),
                  // List of rows
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: Color(0xFFE2E8F0),
                        thickness: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isChecked = _selectedPoStyleIds.contains(item.poStyle.id);
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          color: isChecked ? const Color(0xFFE3F2FD).withValues(alpha: 0.4) : null,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 48,
                                child: Checkbox(
                                  value: isChecked,
                                  activeColor: const Color(0xFF0D47A1),
                                  onChanged: (val) {
                                    HapticFeedbackHelper.buttonClick();
                                    setState(() {
                                      if (val == true) {
                                        _selectedPoStyleIds.add(item.poStyle.id);
                                      } else {
                                        _selectedPoStyleIds.remove(item.poStyle.id);
                                      }
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(item.poStyle.customer ?? '-', style: cellStyle, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(item.poStyle.po ?? '-', style: cellStyle, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(item.poStyle.articleNo ?? '-', style: cellStyle, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text(item.poStyle.size ?? '-', style: cellStyle, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(item.poStyle.colorCode ?? '-', style: cellStyle, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(item.poStyle.lot ?? '-', style: cellStyle, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(item.poStyle.bundleNo ?? '-', style: cellStyle, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 120,
                                child: _buildLineCellText(item, isChecked),
                              ),
                              SizedBox(
                                width: 120,
                                child: _buildLineDescCellText(item, isChecked),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLineCellText(PoStyleItem item, bool isChecked) {
    final currentLine = item.poStyle.lineCode ?? '-';
    if (isChecked && _selectedCostCenterLine != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLine,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF78909C),
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF0D47A1)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _selectedCostCenterLine!.name,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Text(
      currentLine,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF263238),
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLineDescCellText(PoStyleItem item, bool isChecked) {
    final currentLineDesc = item.poStyle.line ?? '-';
    if (isChecked && _selectedCostCenterLine != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLineDesc,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF78909C),
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF0D47A1)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _selectedCostCenterLine!.description ?? '',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Text(
      currentLineDesc,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF263238),
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
