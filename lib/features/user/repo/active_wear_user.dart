import 'package:active_wear_scanning/features/user/model/active_wear_user.dart';
import 'package:active_wear_scanning/features/user/repo/profile.dart';
import 'package:plex/plex_user.dart';

class TasdeeqUser extends PlexUser {
  late String accessToken;
  late String tokenType;
  late int expiresIn;
  late String userName;
  late String email;
  late bool emailConfirmed;
  late String name;
  late String? surname;
  late String? phoneNumber;
  late bool phoneNumberConfirmed;
  late bool isExternal;
  late bool hasPassword;
  late bool supportsMultipleTimezone;
  late String timezone;
  late String concurrencyStamp;

  @override
  String getLoggedInEmail() => email;

  @override
  String getLoggedInFullName() => name;

  @override
  List<String>? getLoggedInRules() => null;

  @override
  String getLoggedInUsername() => userName;

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['access_token'] = accessToken;
    map['token_type'] = tokenType;
    map['expires_in'] = expiresIn;
    map['userName'] = userName;
    map['email'] = email;
    map['emailConfirmed'] = emailConfirmed;
    map['name'] = name;
    map['surname'] = surname;
    map['phoneNumber'] = phoneNumber;
    map['phoneNumberConfirmed'] = phoneNumberConfirmed;
    map['isExternal'] = isExternal;
    map['hasPassword'] = hasPassword;
    map['supportsMultipleTimezone'] = supportsMultipleTimezone;
    map['timezone'] = timezone;
    map['concurrencyStamp'] = concurrencyStamp;
    return map;
  }

  TasdeeqUser.fromJson(dynamic json) {
    accessToken = json['access_token'];
    tokenType = json['token_type'];
    expiresIn = json['expires_in'];
    userName = json['userName'];
    email = json['email'];
    emailConfirmed = json['emailConfirmed'];
    name = json['name'];
    surname = json['surname'];
    phoneNumber = json['phoneNumber'];
    phoneNumberConfirmed = json['phoneNumberConfirmed'];
    isExternal = json['isExternal'];
    hasPassword = json['hasPassword'];
    supportsMultipleTimezone = json['supportsMultipleTimezone'];
    timezone = json['timezone'];
    concurrencyStamp = json['concurrencyStamp'];
  }

  TasdeeqUser.fromToken(Token json, Profile profile) {
    accessToken = json.accessToken;
    tokenType = json.tokenType;
    expiresIn = json.expiresIn;
    userName = profile.userName;
    email = profile.email;
    emailConfirmed = profile.emailConfirmed;
    name = profile.name;
    surname = profile.surname;
    phoneNumber = profile.phoneNumber;
    phoneNumberConfirmed = profile.phoneNumberConfirmed;
    isExternal = profile.isExternal;
    hasPassword = profile.hasPassword;
    supportsMultipleTimezone = profile.supportsMultipleTimezone;
    timezone = profile.timezone;
    concurrencyStamp = profile.concurrencyStamp;
  }
}
