class WorkOrderSummary {
  final String id;
  final String description;
  final String componentDescription;
  final int trayCount;
  final double cumulativePieces;

  WorkOrderSummary({
    required this.id,
    required this.description,
    required this.componentDescription,
    required this.trayCount,
    required this.cumulativePieces,
  });
}
