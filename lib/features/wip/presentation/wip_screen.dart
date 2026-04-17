import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/wip/model/wip_model.dart';
import 'package:active_wear_scanning/features/wip/repo/wip_repo.dart';
import 'package:flutter/material.dart';

class WIPScreen extends StatefulWidget {
  const WIPScreen({super.key});

  @override
  State<WIPScreen> createState() => _WIPScreenState();
}

class _WIPScreenState extends State<WIPScreen> {
  final _wipRepo = WipRepo();
  List<LocatorResponse> _locators = [];
  LocatorResponse? _selectedLocator;
  List<WIPEntry> _wipEntries = [];
  bool _isLoading = false;

  static final _labelStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87);
  static final _tableHeaderStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchInitialData();
    });
  }

  Future<void> _fetchInitialData() async {
    AppLoader.show(message: 'Loading Locators...');
    final result = await _wipRepo.fetchLocators();
    AppLoader.hide();

    if (result.success && result.data != null) {
      if (mounted) {
        final allLocs = result.data as List<LocatorResponse>;
        setState(() {
          // Condition: shows only those locators in dropdown whose logicalWH is FLOOR
          _locators = allLocs.where((l) {
            final wh = l.locator.logicalWH?.toUpperCase() ?? '';
            return wh.contains('FLOOR');
          }).toList();
        });
      }
    } else {
      _showError(result.message);
    }
  }

  Future<void> _fetchWipData(int locatorId) async {
    setState(() => _isLoading = true);
    final result = await _wipRepo.fetchWipDetails(locatorId);
    setState(() => _isLoading = false);

    if (result.success && result.data != null) {
      setState(() {
        _wipEntries = result.data as List<WIPEntry>;
      });
    } else {
      _showError(result.message);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptCode = _selectedLocator?.department.code.toUpperCase() ?? '';
    final isKnitting = deptCode == 'KNITTING';
    final isProcessing = deptCode == 'PROCESSING';

    return Scaffold(
      backgroundColor: Colors.white,
      body: AppLoaderContextAttach(
        child: SafeArea(
          child: Column(
            children: [
              CustomInspectionHeader(
                heading: 'WIP',
                subtitle: 'Work In Progress Monitoring',
                isShowBackIcon: true,
                topPadding: 0,
                horizontalPadding: 16,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSelectorSection(),
                      const SizedBox(height: 20),
                      if (_selectedLocator != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SectionHeader(
                              title: 'WIP Details',
                              subtitle: '${_selectedLocator?.locator.description} Inventory',
                            ),
                            if (_isLoading)
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ContentCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _buildTableHeader(isKnitting, isProcessing),
                                Expanded(
                                  child: _wipEntries.isEmpty
                                      ? _buildEmptyState()
                                      : ListView.builder(
                                          itemCount: _wipEntries.length,
                                          itemBuilder: (context, index) => _buildDataRow(index, _wipEntries[index], isKnitting, isProcessing),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else
                        Expanded(child: _buildWelcomeState()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorSection() {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Locator', style: _labelStyle),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade100),
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue.shade50.withValues(alpha: 0.3),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LocatorResponse>(
                isExpanded: true,
                hint: const Text('Choose a store/locator'),
                value: _selectedLocator,
                items: _locators.map((loc) {
                  return DropdownMenuItem(
                    value: loc,
                    child: Text('${loc.locator.description} (${loc.department.name})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedLocator = val);
                  if (val != null) _fetchWipData(val.locator.id);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isKnitting, bool isProcessing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('WORK ORDER', style: _tableHeaderStyle)),
          if (isKnitting) Expanded(flex: 3, child: Text('MACHINE', style: _tableHeaderStyle)),
          if (isProcessing) Expanded(flex: 3, child: Text('BATCH NO', style: _tableHeaderStyle)),
          Expanded(flex: 4, child: Text('ITEM', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('TRAYS', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('PCS', style: _tableHeaderStyle)),
        ],
      ),
    );
  }

  Widget _buildDataRow(int index, WIPEntry entry, bool isKnitting, bool isProcessing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        color: index.isEven ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(entry.workOrder, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          if (isKnitting) Expanded(flex: 3, child: Text(entry.machine ?? '-', style: const TextStyle(fontSize: 11))),
          if (isProcessing) Expanded(flex: 3, child: Text(entry.batchNo ?? '-', style: const TextStyle(fontSize: 11))),
          Expanded(flex: 4, child: Text(entry.item, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(entry.traysCount.toString(), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(entry.pcsCount.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No WIP entries found in this locator', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 64, color: Colors.blue.shade100),
          const SizedBox(height: 16),
          const Text('Select a locator to view WIP details', style: TextStyle(fontSize: 16, color: Colors.black54)),
        ],
      ),
    );
  }
}
