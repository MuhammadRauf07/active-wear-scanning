class ScannedTray {
  final int? trayUpdateId;
  final String? trayConcurrencyStamp;
  final String trayCode;
  final String? quantity;

  ScannedTray({this.trayCode = '', this.trayUpdateId, this.quantity, this.trayConcurrencyStamp});
}
