class BatchSummaryItem {
  final int batchHeaderId;
  final int? machineId;
  final String batchCode;
  final String machine;
  final String color;
  final int trayCount;
  final double totalTubes;
  final double totalWeight;
  final String? trolleyCode;
  final bool isStarted;
  final bool reworkFlag;
  final bool isReassigned;

  BatchSummaryItem({
    required this.batchHeaderId,
    this.machineId,
    required this.batchCode,
    required this.machine,
    required this.color,
    required this.trayCount,
    required this.totalTubes,
    required this.totalWeight,
    this.trolleyCode,
    required this.isStarted,
    required this.reworkFlag,
    required this.isReassigned,
  });
}
