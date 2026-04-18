import 'package:active_wear_scanning/core/widgets/app_loader.dart';
import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/section_header.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
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
  Map<int, List<ProductionProgressResponseModel>> _locatorTrays = {};
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
    // If we have data, skip reload for now
    if (_locatorTrays.containsKey(locatorId) && _locatorTrays[locatorId]!.isNotEmpty) return;

    setState(() => _loadingDetails[locatorId] = true);
    final result = await _wipRepo.fetchWipDetails(locatorId);

    if (mounted) {
      setState(() {
        _loadingDetails[locatorId] = false;
        if (result.success && result.data != null) {
          _locatorTrays[locatorId] = result.data as List<ProductionProgressResponseModel>;
        } else {
          _showError(result.message);
        }
      });
    }
  }

  List<_WIPGroup> _groupTrays(List<ProductionProgressResponseModel> trays, bool isKnitting) {
    final Map<String, _WIPGroup> groups = {};

    for (final t in trays) {
      String key;
      if (isKnitting) {
        // Group by WorkOrder + Machine + Item
        final wo = t.workOrderHeader.workOrderCode;
        final machine = t.machineModel.brand ?? t.machineModel.resourceCode ?? '-';
        final item = t.item.description;
        key = "${wo}_${machine}_$item";
        
        if (!groups.containsKey(key)) {
          groups[key] = _WIPGroup(title1: wo, title2: machine, subtitle: item, trays: []);
        }
      } else {
        // Group by Batch No + Color
        final batch = t.productionProgress.progressCode ?? '-';
        final color = t.batchHeader?.colorDescription ?? '-';
        key = "${batch}_$color";
        
        if (!groups.containsKey(key)) {
          groups[key] = _WIPGroup(title1: batch, title2: color, trays: []);
        }
      }
      groups[key]!.trays.add(t);
    }
    return groups.values.toList();
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
    final trays = _locatorTrays[locatorId] ?? [];
    final isLoading = _loadingDetails[locatorId] ?? false;
    final deptCode = loc.department.code.toUpperCase();
    final isKnitting = deptCode == 'KNITTING';
    final isProcessing = deptCode == 'PROCESSING';
    
    final groupedData = _groupTrays(trays, isKnitting);

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
            if (groupedData.isEmpty && !isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: _buildEmptyState(),
              )
            else ...[
              const Divider(height: 1),
              _buildTableHeader(isKnitting, isProcessing),
              ...List.generate(groupedData.length, (idx) {
                return _buildGroupRow(idx, groupedData[idx], isKnitting, isProcessing);
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
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text('WORK ORDER', style: _tableHeaderStyle)),
            Expanded(flex: 3, child: Text('MACHINE', style: _tableHeaderStyle)),
            Expanded(flex: 4, child: Text('ITEM DESC', style: _tableHeaderStyle)),
          ] else ...[
            Expanded(flex: 4, child: Text('BATCH NO', style: _tableHeaderStyle)),
            Expanded(flex: 4, child: Text('COLOR', style: _tableHeaderStyle)),
          ],
          Expanded(flex: 2, child: Text('TRAYS', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('PCS', style: _tableHeaderStyle)),
          const SizedBox(width: 40), // Space for action button
        ],
      ),
    );
  }

  Widget _buildGroupRow(int index, _WIPGroup group, bool isKnitting, bool isProcessing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        color: index.isEven ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          if (isKnitting) ...[
            Expanded(flex: 3, child: Text(group.title1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            Expanded(flex: 3, child: Text(group.title2, style: const TextStyle(fontSize: 11))),
            Expanded(flex: 4, child: Text(group.subtitle ?? '-', style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ] else ...[
            Expanded(flex: 4, child: Text(group.title1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            Expanded(flex: 4, child: Text(group.title2, style: const TextStyle(fontSize: 11))),
          ],
          Expanded(flex: 2, child: Text(group.trayCount.toString(), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(group.totalPcs.toInt().toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, size: 20, color: Colors.blue),
            onPressed: () => _showTrayDetailsDialog(group),
            tooltip: 'View Tray Details',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  void _showTrayDetailsDialog(_WIPGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.layers, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tray Details', style: TextStyle(color: Colors.white, fontSize: 18)),
                    Text('${group.title1} | ${group.title2}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
            ],
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('TRAY CODE', style: _tableHeaderStyle)),
                    Expanded(flex: 3, child: Text('WORK ORDER', style: _tableHeaderStyle)),
                    Expanded(flex: 4, child: Text('ITEM', style: _tableHeaderStyle)),
                    Expanded(flex: 2, child: Text('QTY', style: _tableHeaderStyle)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(group.trays.length, (index) {
                      final t = group.trays[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(t.primaryTrayModel.trayCode ?? '-', style: const TextStyle(fontSize: 12))),
                            Expanded(flex: 3, child: Text(t.workOrderHeader.workOrderCode ?? '-', style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 4, child: Text(t.item.description, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 2, child: Text((t.productionProgress.primaryQuantity ?? 0).toInt().toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        contentPadding: EdgeInsets.zero,
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

class _WIPGroup {
  final String title1;
  final String title2;
  final String? subtitle;
  final List<ProductionProgressResponseModel> trays;

  _WIPGroup({required this.title1, required this.title2, this.subtitle, required this.trays});

  int get trayCount => trays.length;
  double get totalPcs => trays.fold(0.0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0));
}
