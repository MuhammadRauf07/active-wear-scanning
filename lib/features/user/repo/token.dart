class Token {
  Token({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  Token.fromJson(dynamic json) {
    accessToken = json['access_token'];
    tokenType = json['token_type'];
    expiresIn = json['expires_in'];
  }

  late String accessToken;
  late String tokenType;
  late int expiresIn;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['access_token'] = accessToken;
    map['token_type'] = tokenType;
    map['expires_in'] = expiresIn;
    return map;
  }
}
