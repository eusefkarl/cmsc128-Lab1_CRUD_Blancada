extension EnumLabel on Enum {
  /// The enum value's name with its first letter capitalized, e.g. `High`.
  String get label => name[0].toUpperCase() + name.substring(1);
}
