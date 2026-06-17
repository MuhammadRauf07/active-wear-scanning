import 'package:active_wear_scanning/features/common-models/common_models.dart';

class WipTransactionModel {
  final PrimaryTrayModel? primaryTrayModel;

  WipTransactionModel({this.primaryTrayModel});

  factory WipTransactionModel.fromJson(Map<String, dynamic> json) {
    return WipTransactionModel(
      primaryTrayModel: json['primaryTray'] != null
          ? PrimaryTrayModel.fromJson(json['primaryTray'])
          : null,
    );
  }
}
