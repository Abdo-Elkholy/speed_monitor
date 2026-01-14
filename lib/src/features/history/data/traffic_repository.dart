import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class TrafficRepository {
  static const String boxName = 'traffic_history';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  static Box get _box => Hive.box(boxName);

  static String _getTodayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  static Future<void> updateToday(int downloadDelta, int uploadDelta) async {
    final key = _getTodayKey();
    final current = _box.get(key, defaultValue: {'dl': 0, 'ul': 0}) as Map;
    
    final newDl = (current['dl'] ?? 0) + downloadDelta;
    final newUl = (current['ul'] ?? 0) + uploadDelta;

    await _box.put(key, {'dl': newDl, 'ul': newUl});
  }

  static Map<String, dynamic> getTodayUsage() {
    final key = _getTodayKey();
    final data = _box.get(key, defaultValue: {'dl': 0, 'ul': 0});
    return Map<String, dynamic>.from(data);
  }

  static List<Map<String, dynamic>> getHistory() {
    final today = _getTodayKey();
    final allKeys = _box.keys.cast<String>().where((k) => k != today).toList();
    // Sort descending
    allKeys.sort((a, b) => b.compareTo(a));

    return allKeys.map((key) {
      final data = _box.get(key) as Map;
      return {
        'date': key,
        'dl': data['dl'] ?? 0,
        'ul': data['ul'] ?? 0,
      };
    }).toList();
  }
}
