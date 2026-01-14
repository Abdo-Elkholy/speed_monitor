import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speed_monitor/src/features/history/presentation/history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String text = "Stop Service";
  bool isRunning = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.notification.request();
    // Battery optimizations should be ignored for background service reliability
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
    }
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('title'.tr()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              if (context.locale.languageCode == 'en') {
                context.setLocale(const Locale('ar'));
              } else {
                context.setLocale(const Locale('en'));
              }
            },
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildMonitor() : const HistoryPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.speed),
            label: 'title'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: 'history'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitor() {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.speed,
              size: 100,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 20),
            StreamBuilder<Map<String, dynamic>?>(
              stream: FlutterBackgroundService().on('update'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text(
                    'service_status'.tr(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  );
                }
                final data = snapshot.data!;
                String? device = data["device"];
                DateTime? date = DateTime.tryParse(data["date"]);
                return Column(
                  children: [
                    Text(device ?? 'unknown_device'.tr()),
                    Text(date.toString()),
                  ],
                );
              },
            ),
             const SizedBox(height: 20),
             // We can check service status using isRunning
            StreamBuilder<bool>(
                stream: _isRunningStream(),
                initialData: false,
                builder: (context, snapshot) {
                    final running = snapshot.data ?? false;
                    return Column(
                        children: [
                            Text(
                              running ? "monitoring_active".tr() : "monitoring_stopped".tr(),
                              style: TextStyle(
                                fontSize: 24, 
                                color: running ? Colors.greenAccent : Colors.grey
                              ),
                            ),
                            const SizedBox(height: 40),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                backgroundColor: running ? Colors.redAccent : Colors.greenAccent,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () async {
                                final service = FlutterBackgroundService();
                                var isRunning = await service.isRunning();
                                if (isRunning) {
                                  service.invoke("stopService");
                                } else {
                                  service.startService();
                                }
                                setState(() {});
                              },
                              child: Text(
                                running ? 'stop_service'.tr() : 'start_service'.tr(),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Overlay Control
                            FutureBuilder<bool>(
                              future: FlutterOverlayWindow.isActive(),
                              builder: (context, snapshot) {
                                final isOverlayActive = snapshot.data ?? false;
                                return TextButton(
                                  onPressed: () async {
                                    if (isOverlayActive) {
                                      await FlutterOverlayWindow.closeOverlay();
                                    } else {
                                      bool granted = await FlutterOverlayWindow.isPermissionGranted();
                                      if (!granted) {
                                        granted = (await FlutterOverlayWindow.requestPermission()) ?? false;
                                      }
                                      if (granted) {
                                        await FlutterOverlayWindow.showOverlay(
                                          enableDrag: true,
                                          overlayTitle: "Speed Monitor",
                                          overlayContent: "Running...",
                                          flag: OverlayFlag.defaultFlag,
                                          visibility: NotificationVisibility.visibilitySecret,
                                          positionGravity: PositionGravity.auto,
                                        );
                                      }
                                    }
                                    setState(() {});
                                  },
                                  child: Text(
                                    isOverlayActive ? "Disable Overlay" : "Enable Overlay",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              },
                            ),
                        ],
                    );
                }
            )
          ],
        ),
      );
  }
  
  Stream<bool> _isRunningStream() {
      // Create a stream that checks status periodically or uses the service stream
      // A simple poll for UI update
      return Stream.periodic(const Duration(seconds: 1), (_) async {
          return await FlutterBackgroundService().isRunning();
      }).asyncMap((event) async => await event);
  }
}
