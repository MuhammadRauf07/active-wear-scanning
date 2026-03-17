class ScannedTray {
  final int? trayUpdateId;
  final String? trayConcurrencyStamp;
  final String trayCode;

  ScannedTray({this.trayCode = '', this.trayUpdateId, this.trayConcurrencyStamp});
}
