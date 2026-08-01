final class AppVersion {
  const AppVersion({required this.name, required this.buildNumber});

  // Updated together with pubspec.yaml by tool/set_version.ps1.
  static const current = AppVersion(name: '0.1.0', buildNumber: 1);

  final String name;
  final int buildNumber;

  String get display => '$name ($buildNumber)';
}
