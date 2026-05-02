class ScannedTray {
  final int? trayUpdateId;
  final String? trayConcurrencyStamp;
  final String trayCode;
  final String? quantity;
  final String colorDescription;
  final String sizeDescription;

  ScannedTray({
    this.trayCode = '',
    this.trayUpdateId,
    this.quantity,
    this.trayConcurrencyStamp,
    this.colorDescription = '',
    this.sizeDescription = '',
  });
}
