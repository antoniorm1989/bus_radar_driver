enum BusChatRole {
  user,
  driver,
  admin;

  String get value => name;

  bool get canPin => this == BusChatRole.driver || this == BusChatRole.admin;

  static BusChatRole fromDynamic(
    Object? rawRole, {
    BusChatRole fallback = BusChatRole.user,
  }) {
    final normalized = (rawRole as String? ?? '').trim().toLowerCase();

    switch (normalized) {
      case 'driver':
        return BusChatRole.driver;
      case 'admin':
        return BusChatRole.admin;
      case 'user':
        return BusChatRole.user;
      default:
        return fallback;
    }
  }
}
