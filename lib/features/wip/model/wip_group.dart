import 'package:active_wear_scanning/features/gbs/model/production_progress.dart';

class WIPGroup {
  final String title1;
  final String title2;
  final String? title3;
  final String? subtitle;
  final List<ProductionProgressResponseModel> trays;

  WIPGroup({
    required this.title1,
    required this.title2,
    this.title3,
    this.subtitle,
    required this.trays,
  });

  int get trayCount => trays.length;
  double get totalPcs => trays.fold(0.0, (sum, t) => sum + (t.productionProgress.primaryQuantity ?? 0));
}
