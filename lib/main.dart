import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:speed_monitor/src/app.dart';
import 'package:speed_monitor/src/features/monitor/background_service.dart';
import 'package:speed_monitor/src/features/history/data/traffic_repository.dart';
import 'package:speed_monitor/src/features/overlay/overlay_widget.dart'; // Ensure entry point is linked

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWidget(),
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await TrafficRepository.init();
  await initializeService();
  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/langs',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}
