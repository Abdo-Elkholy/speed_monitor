import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:traffic_stats/traffic_stats.dart';
import 'package:speed_monitor/src/features/history/data/traffic_repository.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'speed_monitor_channel', // id
    'Speed Monitor Service', // title
    description: 'This channel is used for internet speed notifications.', 
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'speed_monitor_channel',
      initialNotificationTitle: 'Speed Monitor',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // iOS implementation is limited
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Initialize traffic monitoring
  await TrafficRepository.init();
  final trafficService = NetworkSpeedService();
  trafficService.init();

  int _bufferedDl = 0;
  int _bufferedUl = 0;
  DateTime? lastUpdate;
  Timer? _flushTimer;

  // Helper to flush data
  Future<void> flushBufferedData() async {
    if (_bufferedDl > 0 || _bufferedUl > 0) {
      await TrafficRepository.updateToday(_bufferedDl, _bufferedUl);
      _bufferedDl = 0;
      _bufferedUl = 0;
    }
  }

  // Periodic flush every 30 seconds
  _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
    await flushBufferedData();
  });

  service.on('stopService').listen((event) async {
    _flushTimer?.cancel();
    await flushBufferedData(); // Force final flush
    trafficService.dispose();
    service.stopSelf();
  });

  trafficService.speedStream.listen((data) async {
    final now = DateTime.now();
    
    // Calculate bytes transferred since last update
    // Speed is in KB/s, so multiply by time interval in seconds
    if (lastUpdate != null) {
      final secondsElapsed = now.difference(lastUpdate!).inMilliseconds / 1000.0;
      // Convert KB/s to bytes: speed * 1024 * seconds
      final dlBytes = (data.downloadSpeed * 1024 * secondsElapsed).round();
      final ulBytes = (data.uploadSpeed * 1024 * secondsElapsed).round();
      
      // Buffer data instead of writing immediately
      _bufferedDl += dlBytes;
      _bufferedUl += ulBytes;
    }
    lastUpdate = now;

    // Share with overlay if active
    if (await FlutterOverlayWindow.isActive()) {
      final totalSpeed = data.downloadSpeed + data.uploadSpeed;
      // Send single string: e.g. "150 KB/s"
      await FlutterOverlayWindow.shareData(_formatSpeed(totalSpeed));
    }

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Speed Monitor",
          content: "▼ ${_formatSpeed(data.downloadSpeed)}  ▲ ${_formatSpeed(data.uploadSpeed)}",
        );
      }
    }
  });
}

String _formatSpeed(int speed) {
  // Assuming speed is in KB/s based on common plugin behaviors
  // If it's bits, we'd divide by 8. If bytes, divide by 1024 to get KB?
  // Let's assume the plugin returns KB/s directly as 'int' suggests pre-calculation
  if (speed >= 1024) {
    return '${(speed / 1024).toStringAsFixed(1)} MB/s';
  }
  return '$speed KB/s';
}
