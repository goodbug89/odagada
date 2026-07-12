import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const OdagadaApp());
}
