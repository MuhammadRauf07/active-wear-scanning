import 'package:active_wear_scanning/core/widgets/app_top_header.dart';
import 'package:active_wear_scanning/core/widgets/content_card.dart';
import 'package:active_wear_scanning/core/widgets/custom_outlined_button.dart';
import 'package:active_wear_scanning/features/batch/presentation/batch_scanning_screen.dart';
import 'package:active_wear_scanning/features/batch/repo/batch_repo.dart';

import 'package:active_wear_scanning/features/batch/model/batch_header_model.dart';
import 'package:flutter/material.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> with SingleTickerProviderStateMixin {
  final _batchRepo = BatchRepo();
  bool _isLoading = true;
  
  List<BatchHeaderResponseModel> _unlockedBatches = [];
  List<BatchHeaderResponseModel> _lockedBatches = [];
  
  // Maps batchHeaderId -> List of BatchLine raw maps from the batch-lines API
  Map<int, List<Map<String, dynamic>>> _batchLinesByHeader = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAndGroupBatches();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndGroupBatches() async {
    setState(() => _isLoading = true);
    
    final headerResult = await _batchRepo.fetchBatchHeaders();
    final batchLinesResult = await _batchRepo.fetchBatchLines();

    if (mounted && headerResult.success) {
      
      // 1. Map Headers
      final headerData = headerResult.data as List<Map<String, dynamic>>? ?? [];
      final headers = headerData.map((e) => BatchHeaderResponseModel.fromJson(e)).toList();

      // Separate Headers by Lock State
      _unlockedBatches = headers.where((h) => h.batchHeader.lockFlag == false).toList();
      _lockedBatches = headers.where((h) => h.batchHeader.lockFlag == true).toList();

      // 2. Group tray counts by batchHeaderId using the batch-lines API
      //    This is the proper relational source of truth.
      Map<int, List<Map<String, dynamic>>> grouped = {};
      if (batchLinesResult.success && batchLinesResult.data != null) {
        final rawLines = batchLinesResult.data as List<Map<String, dynamic>>;
        for (var line in rawLines) {
          final batchHeaderId = line['batchLines']?['batchHeaderId'];
          if (batchHeaderId != null) {
            final id = batchHeaderId as int;
            if (!grouped.containsKey(id)) grouped[id] = [];
            grouped[id]!.add(line);
          }
        }
      }

      setState(() {
        _batchLinesByHeader = grouped;
        _isLoading = false;
      });
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Failed to fetch batches')));
      }
    }
  }

  void _navigateToAddBatch() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const BatchScanningScreen())
    );
    if (result == true) {
      _fetchAndGroupBatches();
    }
  }

  void _navigateToEditBatch(BatchHeaderResponseModel batchHeaderModel) async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => BatchScanningScreen(
          existingBatch: batchHeaderModel,
          preloadedTrays: const [], // Edit screen loads its own trays from batch-lines
        )
      )
    );
    if (result == true) {
      _fetchAndGroupBatches();
    }
  }

  Future<void> _deleteBatch(BatchHeaderResponseModel header) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text('Are you sure you want to delete batch ${header.batchHeader.batchHeaderCode}?\nThis will permanently wipe it from the backend and unlink all trays.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final headerId = header.batchHeader.id!;

    // 1. Defensively Unlink mapped Trays - find them from batch-lines
    final batchLinesToUnlink = _batchLinesByHeader[headerId] ?? [];
    for (var line in batchLinesToUnlink) {
      final trayId = line['batchLines']?['trayId'] as int?;
      final progressId = line['batchLines']?['progressId'] as int?;
      final batchLineId = line['batchLines']?['id'] as int?;

      // a. Unlink tray-details
      if (trayId != null) {
        final getTrayRes = await _batchRepo.fetchTrayDetailById(trayId);
        if (getTrayRes.success && getTrayRes.data != null) {
          Map<String, dynamic> rawTrayPayload = getTrayRes.data.containsKey('trayDetail') ? getTrayRes.data['trayDetail'] : getTrayRes.data;
          rawTrayPayload["batchHeaderId"] = null;
          rawTrayPayload.remove("creatorId");
          rawTrayPayload.remove("creationTime");
          rawTrayPayload.remove("lastModifierId");
          rawTrayPayload.remove("lastModificationTime");
          await _batchRepo.updateTrayDetails(trayId, rawTrayPayload);
        }
      }

      // b. Unlink production-progress via progressId from batch-line
      if (progressId != null) {
        // We'll just delete the batch-line; the progress batchHeaderId cleanup
        // happens implicitly when the batch header is deleted.
      }

      // c. Delete the batch-line record itself
      if (batchLineId != null) {
        await _batchRepo.deleteBatchLine(batchLineId);
      }
    }

    // 2. Erase the Batch Header Object
    final res = await _batchRepo.deleteBatchHeader(headerId);
    
    setState(() => _isLoading = false);

    if (res.success) {
      _fetchAndGroupBatches(); // Rerender
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch permanently deleted!'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Failed: ${res.message}'), backgroundColor: Colors.red));
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
            
            // Tab Bar Rendering
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: "Unlocked"),
                Tab(text: "Locked"),
              ],
            ),
            
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBatchList(_unlockedBatches, isLocked: false),
                      _buildBatchList(_lockedBatches, isLocked: true),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchList(List<BatchHeaderResponseModel> batches, {required bool isLocked}) {
    if (batches.isEmpty) {
      return Center(
        child: Text(
          isLocked ? 'No batch is locked' : 'No unlocked batches found.', 
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)
        ),
      );
    }

    // Sort heavily newest first
    batches.sort((a, b) => (b.batchHeader.id ?? 0).compareTo((a.batchHeader.id ?? 0)));

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
                  Expanded(flex: 3, child: Text('BATCH ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 3, child: Text('MACHINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('COLOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('TRAYS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('WEIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                  if (!isLocked) Expanded(flex: 1, child: Text('DEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
                ],
              ),
            ),
            ...List.generate(batches.length, (index) {
              final header = batches[index];
              final batchId = header.batchHeader.batchHeaderCode ?? "Undef";
              final machineBrand = header.machine?.brand ?? 'Unknown';
              final colorDesc = header.batchHeader.colorDescription ?? '-';
              
              final rawDateStr = header.batchHeader.planDate;
              final DateTime? rawDate = rawDateStr != null ? DateTime.tryParse(rawDateStr) : null;
              final displayDate = rawDate != null ? "${rawDate.year}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.day.toString().padLeft(2, '0')}" : "-";
              
              // Load Trays logic securely
              final headerDatabaseId = header.batchHeader.id ?? 0;
              final traysLength = _batchLinesByHeader[headerDatabaseId]?.length ?? 0;

              return GestureDetector(
                onTap: () {
                  if(!isLocked) {
                     // Opens EDIT mode if unlocked
                     _navigateToEditBatch(header);
                  }
                },
                child: Container(
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
                        child: Text(batchId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(machineBrand, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(colorDesc, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("$traysLength", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("-", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)), // Native Weight Placeholder
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(displayDate, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ),
                      if (!isLocked)
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: () => _deleteBatch(header),
                            child: const Padding(
                               padding: EdgeInsets.all(4.0),
                               child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            )
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
