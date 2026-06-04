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

  List<String> _articles = [];
  String? _selectedArticle;

  List<CostCenterLine> _costCenterLines = [];
  CostCenterLine? _selectedCostCenterLine;
  bool _isLoadingCostCenterLines = false;

  final Set<int> _selectedPoStyleIds = {};
  String? _allocationMode;

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
      _articles = [];
      _selectedArticle = null;
      _selectedPoStyleIds.clear();
      _allocationMode = null;
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
      _allocationMode = null;
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
      _articles = [];
      _selectedArticle = null;
      _selectedPoStyleIds.clear();
      _costCenterLines = [];
      _selectedCostCenterLine = null;
      _allocationMode = null;
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
      _articles = [];
      _selectedArticle = null;
      _selectedPoStyleIds.clear();
      _costCenterLines = [];
      _selectedCostCenterLine = null;
      _allocationMode = null;
    });
    if (val != null && _selectedCustomer != null) {
      final uniqueArticles = _poStyles
          .where((item) => item.poStyle.customer == _selectedCustomer && item.poStyle.po == val)
          .map((item) => item.poStyle.articleNo)
          .whereType<String>()
          .where((a) => a.isNotEmpty)
          .toSet()
          .toList();
      uniqueArticles.sort();
      setState(() {
        _articles = uniqueArticles;
      });
    }
  }

  void _onArticleChanged(String? val) {
    HapticFeedbackHelper.buttonClick();
    setState(() {
      _selectedArticle = val;
      _selectedPoStyleIds.clear();
      _costCenterLines = [];
      _selectedCostCenterLine = null;
      _allocationMode = null;
    });
    if (val != null) {
      _fetchCostCenterLines();
    }
  }

  List<PoStyleItem> get _filteredPoStyles {
    if (_selectedCustomer == null || _selectedCustomerPO == null || _selectedArticle == null) return [];
    return _poStyles
        .where((item) =>
            item.poStyle.customer == _selectedCustomer &&
            item.poStyle.po == _selectedCustomerPO &&
            item.poStyle.articleNo == _selectedArticle)
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
              'SELECT ARTICLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF546E7A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            CustomExpandedAsyncDropdown<String>(
              selectedValue: _selectedArticle,
              items: _articles,
              hint: "Select Article...",
              isShowSearch: true,
              itemAsString: (art) => art,
              borderColor: const Color(0xFFCFD8DC),
              backgroundColor: Colors.white,
              height: 48,
              textSize: 13,
              onChanged: _onArticleChanged,
            ),
          ],
          if (_selectedArticle != null) ...[
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
                        _allocationMode = null;
                        _selectedPoStyleIds.clear();
                      });
                    },
                  ),
          ],
          if (_selectedCostCenterLine != null) ...[
            _buildAllocationModeButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    final filtered = _filteredPoStyles;
    final showTable = _selectedCostCenterLine != null && _allocationMode != null && filtered.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectionCard(),
          const SizedBox(height: 16),
          if (showTable)
            Expanded(
              child: _buildPoStylesTable(filtered),
            ),
        ],
      ),
    );
  }

  Widget _buildPoStylesTable(List<PoStyleItem> items) {
    final selectableItems = items.where(_isRowSelectable).toList();
    final allSelected = selectableItems.isNotEmpty && selectableItems.every((i) => _selectedPoStyleIds.contains(i.poStyle.id));
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
                    onChanged: selectableItems.isEmpty ? null : (val) {
                      HapticFeedbackHelper.buttonClick();
                      setState(() {
                        if (val == true) {
                          _selectedPoStyleIds.addAll(selectableItems.map((i) => i.poStyle.id));
                        } else {
                          for (final i in selectableItems) {
                            _selectedPoStyleIds.remove(i.poStyle.id);
                          }
                        }
                      });
                    },
                  ),
                ),
                const Expanded(flex: 3, child: Text('Bundle', style: headerStyle)),
                const Expanded(flex: 3, child: Text('Lot', style: headerStyle)),
                const Expanded(flex: 3, child: Text('Color', style: headerStyle)),
                const Expanded(flex: 2, child: Text('Size', style: headerStyle)),
                const Expanded(flex: 2, child: Text('Qty', style: headerStyle)),
                const Expanded(flex: 4, child: Text('Line', style: headerStyle)),
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
                final isSelectable = _isRowSelectable(item);
                final currentCellStyle = isSelectable
                    ? cellStyle
                    : cellStyle.copyWith(color: const Color(0xFF94A3B8));
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
                          onChanged: isSelectable
                              ? (val) {
                                  HapticFeedbackHelper.buttonClick();
                                  setState(() {
                                    if (val == true) {
                                      _selectedPoStyleIds.add(item.poStyle.id);
                                    } else {
                                      _selectedPoStyleIds.remove(item.poStyle.id);
                                    }
                                  });
                                }
                              : null,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(item.poStyle.bundleNo ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(item.poStyle.lot ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(item.poStyle.colorCode ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(item.poStyle.size ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(item.poStyle.quantity?.toString() ?? '-', style: currentCellStyle, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 4,
                        child: _buildCurrentLineCellText(item, isChecked, isSelectable),
                      ),
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

  Widget _buildCurrentLineCellText(PoStyleItem item, bool isChecked, bool isSelectable) {
    final currentLine = item.poStyle.line ?? '-';
    if (isChecked && _selectedCostCenterLine != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLine,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF78909C),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _selectedCostCenterLine!.description ?? '-',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Text(
      currentLine,
      style: TextStyle(
        fontSize: 11,
        color: isSelectable ? const Color(0xFF263238) : const Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  bool _isRowSelectable(PoStyleItem item) {
    if (_allocationMode == 'allocate') {
      return item.poStyle.line == null || item.poStyle.line!.isEmpty;
    } else if (_allocationMode == 're-allocate') {
      return item.poStyle.line != null && item.poStyle.line!.isNotEmpty;
    }
    return false;
  }

  Widget _buildAllocationModeButtons() {
    if (_selectedCostCenterLine == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'ALLOCATION OPTIONS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF546E7A),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildModeButton(
                label: 'Allocate',
                mode: 'allocate',
                icon: Icons.playlist_add_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeButton(
                label: 'Re-Allocate',
                mode: 're-allocate',
                icon: Icons.playlist_play_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeButton({required String label, required String mode, required IconData icon}) {
    final isActive = _allocationMode == mode;
    return OutlinedButton.icon(
      onPressed: () {
        HapticFeedbackHelper.buttonClick();
        setState(() {
          _allocationMode = mode;
          _selectedPoStyleIds.clear(); // Clear selections when mode changes
        });
      },
      icon: Icon(
        icon,
        size: 16,
        color: isActive ? Colors.white : const Color(0xFF0D47A1),
      ),
      label: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isActive ? Colors.white : const Color(0xFF0D47A1),
          letterSpacing: 0.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF0D47A1) : Colors.white,
        side: BorderSide(
          color: const Color(0xFF0D47A1),
          width: isActive ? 0 : 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
