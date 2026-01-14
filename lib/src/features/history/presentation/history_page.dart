import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:speed_monitor/src/features/history/data/traffic_repository.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 5 seconds to show live updates for "Today"
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = TrafficRepository.getTodayUsage();
    final history = TrafficRepository.getHistory();

    return Scaffold(
      appBar: AppBar(
        title: Text('history'.tr()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('today'.tr(), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            _buildTable([today], isToday: true),
            const SizedBox(height: 30),
            Text('previous_days'.tr(), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            history.isEmpty 
                ? Padding(
                    padding: const EdgeInsets.all(20), 
                    child: Text('No history yet', style: TextStyle(color: Colors.grey)))
                : _buildTable(history, isToday: false),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> data, {required bool isToday}) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade700),
      columnWidths: const {
        0: FlexColumnWidth(1.5), // Date
        1: FlexColumnWidth(1),   // DL
        2: FlexColumnWidth(1),   // UL
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade900),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('date'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('download'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('upload'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        ...data.map((row) {
          final dl = _formatBytes(row['dl']);
          final ul = _formatBytes(row['ul']);
          final date = isToday ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : row['date'];
          
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(date.toString()),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(dl),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(ul),
              ),
            ],
          );
        }),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    } else {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(2)} GB';
    }
  }
}
