import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:agrimotion/main_web.dart';
import 'package:agrimotion/main_mobile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    runWebPlatform();
  } else {
    runMobileApp();
  }
}
