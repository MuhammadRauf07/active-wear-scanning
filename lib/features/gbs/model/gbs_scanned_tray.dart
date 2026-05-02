class GBSScannedTray {
  final int? trayUpdateId;
  final String? trayConcurrencyStamp;
  final String trayCode;
  final String workOrderCode;
  final String sizeDescription;
  final String colorDescription;
  final String componentDescription;
  final String itemDescription;
  final String styleDescription;
  final String locatorCode;
  final String primaryQuantity;
  final double pieceWeight;

  GBSScannedTray({
    this.trayUpdateId,
    this.trayConcurrencyStamp,
    this.trayCode = '',
    this.workOrderCode = '',
    this.sizeDescription = '',
    this.colorDescription = '',
    this.componentDescription = '',
    this.itemDescription = '',
    this.styleDescription = '',
    this.locatorCode = '',
    this.primaryQuantity = '',
    this.pieceWeight = 0.0,
  });
}
