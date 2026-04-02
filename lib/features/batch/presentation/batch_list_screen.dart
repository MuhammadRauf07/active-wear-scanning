import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/features/batch/presentation/batch_scanning_screen.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';
import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';
import 'package:flutter/material.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  final _batchRepo = BatchRepo();
  bool _isLoading = true;
  
  // This will store our logically grouped batches
  // The Key is the progressCode (Batch ID).
  // The Value is a list of all trays that share that progressCode.
  Map<String, List<ProductionProgressResponseModel>> _groupedBatches = {};

  @override
  void initState() {
    super.initState();
    _fetchAndGroupBatches();
  }

  Future<void> _fetchAndGroupBatches() async {
    setState(() => _isLoading = true);
    final result = await _batchRepo.fetchProductionProgress();

    if (mounted && result.success && result.data != null) {
      final allProgresses = result.data as List<ProductionProgressResponseModel>;
      
      // Filter strictly for records that HAVE a progressCode and are part of Batch (pbsFlag = true)
      final validBatches = allProgresses.where((p) => 
        p.productionProgress.pbsFlag == true && 
        p.productionProgress.progressCode != null &&
        p.productionProgress.progressCode!.trim().isNotEmpty
      ).toList();

      // Group them cleanly!
      Map<String, List<ProductionProgressResponseModel>> grouped = {};
      for (var tray in validBatches) {
        final code = tray.productionProgress.progressCode!;
        if (!grouped.containsKey(code)) {
          grouped[code] = [];
        }
        grouped[code]!.add(tray);
      }

      setState(() {
        _groupedBatches = grouped;
        _isLoading = false;
      });
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${result.message}')));
      }
    }
  }

  void _navigateToAddBatch() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const BatchScanningScreen())
    );
    // If we pop back with a true result (meaning a batch was saved), refresh the list!
    if (result == true) {
      _fetchAndGroupBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomInspectionHeader(
              heading: 'Batch History',
              subtitle: 'List of all created batches',
              isShowBackIcon: true,
              topPadding: 0,
              horizontalPadding: 12,
              widget: CustomOutlinedButton(
                label: 'Add Batch',
                borderColor: Colors.blue,
                textColor: Colors.blue,
                buttonHeight: 42,
                icon: Icons.add,
                onPressed: _navigateToAddBatch,
              ),
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : _buildBatchList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchList() {
    if (_groupedBatches.isEmpty) {
      return Center(
        child: Text(
          'No batches found. Build a batch to see it here.', 
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)
        ),
      );
    }

    // Convert map to a sorted list (newest first).
    // Assuming the progressCode (e.g. BCH-timestamp) allows string sorting or we sort by the first tray's date.
    final List<MapEntry<String, List<ProductionProgressResponseModel>>> batchList = _groupedBatches.entries.toList();
    batchList.sort((a, b) => b.key.compareTo(a.key)); // Basic string sort

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: ContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('BATCH ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 3, child: Text('MACHINE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('TRAYS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                ],
              ),
            ),
            ...List.generate(batchList.length, (index) {
              final batchId = batchList[index].key;
              final trays = batchList[index].value;
              
              // We infer machine brand and date from the very first grouped tray
              final firstTray = trays.first;
              final machineBrand = firstTray.machineModel.brand ?? 'Unknown';
              final rawDate = firstTray.productionProgress.date;
              final displayDate = rawDate != null ? "${rawDate.year}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.day.toString().padLeft(2, '0')}" : "-";
              
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                    right: BorderSide(color: Colors.grey.shade300),
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                  color: index.isEven ? Colors.white : Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(batchId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(machineBrand, style: const TextStyle(fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("${trays.length}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(displayDate, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
