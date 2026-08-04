class ScannedTray {
  final int? trayUpdateId;
  final String? trayConcurrencyStamp;
  final String trayCode;
  final String? quantity;
  final String colorDescription;
  final String sizeDescription;
  final double perGarmentTube;
  final bool isHold;

  ScannedTray({
    this.trayCode = '',
    this.trayUpdateId,
    this.quantity,
    this.trayConcurrencyStamp,
    this.colorDescription = '',
    this.sizeDescription = '',
    this.perGarmentTube = 0,
    this.isHold = false,
  });

  ScannedTray copyWith({
    int? trayUpdateId,
    String? trayConcurrencyStamp,
    String? trayCode,
    String? quantity,
    String? colorDescription,
    String? sizeDescription,
    double? perGarmentTube,
    bool? isHold,
  }) {
    return ScannedTray(
      trayUpdateId: trayUpdateId ?? this.trayUpdateId,
      trayConcurrencyStamp: trayConcurrencyStamp ?? this.trayConcurrencyStamp,
      trayCode: trayCode ?? this.trayCode,
      quantity: quantity ?? this.quantity,
      colorDescription: colorDescription ?? this.colorDescription,
      sizeDescription: sizeDescription ?? this.sizeDescription,
      perGarmentTube: perGarmentTube ?? this.perGarmentTube,
      isHold: isHold ?? this.isHold,
    );
  }
}
