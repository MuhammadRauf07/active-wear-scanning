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
  Map<int, List<WIPEntry>> _locatorData = {};
  Map<int, bool> _loadingDetails = {};

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
    AppLoader.show(context, message: 'Loading Locators...');
    final result = await _wipRepo.fetchLocators();
    AppLoader.hide(context);

    if (result.success && result.data != null) {
      if (mounted) {
        final allLocs = result.data as List<LocatorResponse>;
        setState(() {
          // Condition: shows only those locators in dropdown whose logicalWH is FLOOR
          _locators = allLocs.where((l) {
            final wh = l.locator.logicalWH?.toUpperCase() ?? '';
            return wh.contains('FLOOR');
          }).toList().reversed.toList();
        });
      }
    } else {
      _showError(result.message);
    }
  }

  Future<void> _fetchWipData(int locatorId) async {
    // If we have data and it's not empty, skip unless user manually refreshes (could add later)
    if (_locatorData.containsKey(locatorId) && _locatorData[locatorId]!.isNotEmpty) return;

    setState(() => _loadingDetails[locatorId] = true);
    final result = await _wipRepo.fetchWipDetails(locatorId);

    if (mounted) {
      setState(() {
        _loadingDetails[locatorId] = false;
        if (result.success && result.data != null) {
          _locatorData[locatorId] = result.data as List<WIPEntry>;
        } else {
          _showError(result.message);
        }
      });
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CustomInspectionHeader(
              heading: 'WIP',
              subtitle: 'Work In Progress Monitoring',
              isShowBackIcon: true,
              topPadding: 0,
              horizontalPadding: 16,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SectionHeader(
                title: 'Stores & Locators',
                subtitle: 'Expand a locator to view physical inventory in that area',
              ),
            ),
            Expanded(
              child: _locators.isEmpty
                  ? _buildEmptyLocatorsState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _locators.length,
                      itemBuilder: (context, index) => _buildLocatorExpansionItem(_locators[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocatorExpansionItem(LocatorResponse loc) {
    final locatorId = loc.locator.id;
    final data = _locatorData[locatorId] ?? [];
    final isLoading = _loadingDetails[locatorId] ?? false;
    final deptCode = loc.department.code.toUpperCase();
    final isKnitting = deptCode == 'KNITTING';
    final isProcessing = deptCode == 'PROCESSING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            if (expanded) _fetchWipData(locatorId);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warehouse_outlined, size: 20, color: Colors.blue.shade700),
          ),
          title: Text(
            loc.locator.description,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
          ),
          subtitle: Text(
            'Dept: ${loc.department.name}',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade400, fontWeight: FontWeight.w500),
          ),
          trailing: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.keyboard_arrow_down, color: Colors.blue.shade200),
          children: [
            if (data.isEmpty && !isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: _buildEmptyState(),
              )
            else ...[
              const Divider(height: 1),
              _buildTableHeader(isKnitting, isProcessing),
              ...List.generate(data.length, (idx) {
                return _buildDataRow(idx, data[idx], isKnitting, isProcessing);
              }),
              const SizedBox(height: 12),
            ]
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

}
