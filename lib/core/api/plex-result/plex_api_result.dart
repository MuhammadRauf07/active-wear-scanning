class PlexApiResult {
  final bool success;
  final int code;
  final String message;
  final dynamic data;

  PlexApiResult(this.success, this.code, this.message, this.data);
}
