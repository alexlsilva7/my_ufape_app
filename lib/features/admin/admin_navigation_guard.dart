/// The shell asks this guard before replacing the admin route with another tab.
class AdminNavigationGuard {
  static Future<bool> Function()? check;
  static Future<bool> allowLeave() async => await check?.call() ?? true;
}
