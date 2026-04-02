class GBSScannedTray {
  final int? trayUpdateId;
  final String? trayConcurrencyStamp;
  final String trayCode;
  final String workOrderCode;
  final String sizeDescription;
  final String componentDescription;
  final String itemDescription;
  final String styleDescription;
  final String locatorCode;
  final String primaryQuantity;

  GBSScannedTray({
    this.trayUpdateId,
    this.trayConcurrencyStamp,
    this.trayCode = '',
    this.workOrderCode = '',
    this.sizeDescription = '',
    this.componentDescription = '',
    this.itemDescription = '',
    this.styleDescription = '',
    this.locatorCode = '',
    this.primaryQuantity = '',
  });
}
