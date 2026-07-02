import 'package:flutter/foundation.dart';

Future<({String platform, Map<String, dynamic> info})>
collectDeviceInfo() async {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  return (
    platform: platform,
    info: <String, dynamic>{'platform': platform, 'source': 'flutter_platform'},
  );
}
