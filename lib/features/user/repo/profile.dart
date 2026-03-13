class Profile {
  Profile(
      {required this.userName,
        required this.email,
        required this.emailConfirmed,
        required this.name,
        required this.surname,
        required this.phoneNumber,
        required this.phoneNumberConfirmed,
        required this.isExternal,
        required this.hasPassword,
        required this.supportsMultipleTimezone,
        required this.timezone,
        required this.concurrencyStamp,
        required this.extraProperties});

  Profile.fromJson(dynamic json) {
    userName = json['userName'];
    email = json['email'];
    emailConfirmed = json['emailConfirmed'];
    name = json['name'] ?? '';
    surname = json['surname'];
    phoneNumber = json['phoneNumber'];
    phoneNumberConfirmed = json['phoneNumberConfirmed'];
    isExternal = json['isExternal'];
    hasPassword = json['hasPassword'];
    supportsMultipleTimezone = json['supportsMultipleTimezone'];
    timezone = json['timezone'];
    concurrencyStamp = json['concurrencyStamp'];
    extraProperties = json['extraProperties'];
  }

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
  late dynamic extraProperties;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
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
    map['extraProperties'] = extraProperties;
    return map;
  }
}
