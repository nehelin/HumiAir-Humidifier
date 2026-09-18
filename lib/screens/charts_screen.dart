import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';

/// Time range options available in the chart screen.
enum ChartRange { h1, h6, h24, d7 }

extension _ChartRangeX on ChartRange {
  String get label {
    switch (this) {
      case ChartRange.h1:
        return '1h';
      case ChartRange.h6:
        return '6h';
      case ChartRange.h24:
        return '24h';
      case ChartRange.d7:
        return '7d';
    }
  }

  int get hours {
    switch (this) {
      case ChartRange.h1:
        return 1;
      case ChartRange.h6:
        return 6;
      case ChartRange.h24:
        return 24;
      case ChartRange.d7:
        return 168;
    }
  }
}

class ChartsScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const ChartsScreen(
      {super.key, required this.deviceId, required this.deviceName});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  late final FirestoreService _firestore;

  ChartRange _range = ChartRange.h24;
  bool _isLoading = true;
  bool _hasData = false;

  List<FlSpot> _humiditySpots = [];
  List<FlSpot> _temperatureSpots = [];
  List<FlSpot> _mistSpots = [];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _firestore = FirestoreService(userId: uid);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasData = false;
    });

    try {
      var snapshot = await _firestore
          .streamSensorDataSince(widget.deviceId, hours: _range.hours)
          .first;
      if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
            .streamSensorData(widget.deviceId, limit: 100)
            .first;
      }
      _processSnapshot(snapshot);
    } catch (e) {
      try {
        final fallback = await _firestore
            .streamSensorData(widget.deviceId, limit: 100)
            .first;
        _processSnapshot(fallback);
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  int get _mistActiveMinutes => _mistSpots.where((s) => s.y > 0.5).length;

  void _processSnapshot(QuerySnapshot snapshot) {
    final hum = <FlSpot>[];
    final temp = <FlSpot>[];
    final mist = <FlSpot>[];

    final docs = snapshot.docs;
    final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
    final cutoffMs = nowMs - (_range.hours * 3600 * 1000.0);

    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final data = doc.data() as Map<String, dynamic>;

      double? ts;
      final rawTs = data['timestamp'];
      if (rawTs is Timestamp) {
        ts = rawTs.millisecondsSinceEpoch.toDouble();
      } else if (rawTs is String) {
        final parsed = DateTime.tryParse(rawTs);
        if (parsed != null) ts = parsed.millisecondsSinceEpoch.toDouble();
      } else if (rawTs is num) {
        if (rawTs < 10000000000) {
          ts = rawTs * 1000.0;
        } else {
          ts = rawTs.toDouble();
        }
      }

      if (ts == null) {
        final idNum = double.tryParse(doc.id);
        if (idNum != null && idNum > 100000) {
          ts = idNum;
        } else {
          ts = nowMs - ((docs.length - 1 - i) * 60000.0);
        }
      }

      // Filter out readings that fall outside the selected time window
      if (ts < cutoffMs) {
        continue;
      }

      final h = (data['humidity'] as num?)?.toDouble();
      final t = (data['temperature'] as num?)?.toDouble();
      final m = data['mistOn'] == true;

      if (h != null) hum.add(FlSpot(ts, h));
      if (t != null) temp.add(FlSpot(ts, t));
      mist.add(FlSpot(ts, m ? 1.0 : 0.0));
    }

    // fl_chart requires spots to be strictly sorted by x
    hum.sort((a, b) => a.x.compareTo(b.x));
    temp.sort((a, b) => a.x.compareTo(b.x));
    mist.sort((a, b) => a.x.compareTo(b.x));

    if (mounted) {
      setState(() {
        _humiditySpots = hum;
        _temperatureSpots = temp;
        _mistSpots = mist;
        _isLoading = false;
        _hasData = hum.isNotEmpty || temp.isNotEmpty || mist.isNotEmpty;
      });
    }
  }

  void _setRange(ChartRange r) {
    if (_range == r) return;
    setState(() => _range = r);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F9FF),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.blue.shade700, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deviceName.isEmpty ? 'Charts' : widget.deviceName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
                Text(
                  Tr.sensorHistory,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade400,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh_rounded,
                    color: Colors.blue.shade500, size: 22),
                onPressed: _loadData,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildRangeSelector(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : _hasData
                        ? _buildCharts()
                        : _buildNoData(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: ChartRange.values.map((r) {
          final selected = r == _range;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => _setRange(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              Colors.blue.shade500,
                              Colors.cyan.shade400
                            ],
                          )
                        : null,
                    color: selected ? null : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : Colors.blue.shade100,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : Colors.blue.shade500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCharts() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildChartCard(
          title: Tr.humidity,
          icon: Icons.water_drop_rounded,
          spots: _humiditySpots,
          color: Colors.blue.shade500,
          minY: 0,
          maxY: 100,
          unit: '%',
          interval: 20,
        ),
        const SizedBox(height: 14),
        _buildChartCard(
          title: Tr.temperature,
          icon: Icons.thermostat_rounded,
          spots: _temperatureSpots,
          color: Colors.orange.shade500,
          minY: 0,
          maxY: 50,
          unit: '°C',
          interval: 10,
        ),
        const SizedBox(height: 14),
        _buildChartCard(
          title: Tr.mistUsage,
          icon: Icons.cloud_rounded,
          spots: _mistSpots,
          color: Colors.cyan.shade600,
          minY: -0.1,
          maxY: 1.1,
          unit: '',
          interval: 0.5,
          isBinary: true,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required List<FlSpot> spots,
    required Color color,
    required double minY,
    required double maxY,
    required String unit,
    required double interval,
    bool isBinary = false,
  }) {
    double? minVal, maxVal, avgVal;
    if (spots.isNotEmpty) {
      minVal = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      avgVal = spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                if (spots.isEmpty)
                  Text(
                    Tr.noChartData,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade300,
                    ),
                  ),
              ],
            ),
            if (spots.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (!isBinary)
                Row(
                  children: [
                    _statChip(Tr.min, '${minVal!.toStringAsFixed(1)}$unit', color),
                    const SizedBox(width: 8),
                    _statChip(Tr.avg, '${avgVal!.toStringAsFixed(1)}$unit', color),
                    const SizedBox(width: 8),
                    _statChip(Tr.max, '${maxVal!.toStringAsFixed(1)}$unit', color),
                  ],
                )
              else
                Row(
                  children: [
                    _statChip(Tr.totalMistRuntime, Tr.formatRuntime(_mistActiveMinutes), color),
                  ],
                ),
            ],
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 1.7,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          Colors.blue.shade900.withValues(alpha: 0.9),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(
                              spot.x.toInt());
                          final timeStr =
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          final dateStr = '${dt.day}/${dt.month}';
                          final valStr = isBinary
                              ? (spot.y > 0.5 ? 'Mist ON' : 'Mist OFF')
                              : '${spot.y.toStringAsFixed(1)}$unit';
                          return LineTooltipItem(
                            '$valStr\n$dateStr $timeStr',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: Colors.blue.shade50,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: interval,
                        reservedSize: 32,
                        getTitlesWidget: (v, m) => Text(
                          isBinary
                              ? (v == 1.0 ? 'ON' : v == 0.0 ? 'OFF' : '')
                              : v.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue.shade400,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: spots.length > 1,
                        reservedSize: 22,
                        interval: spots.length > 1
                            ? ((spots.last.x - spots.first.x) / 3).clamp(1.0, double.infinity)
                            : 1.0,
                        getTitlesWidget: (v, meta) {
                          if (v == meta.min || v == meta.max) {
                            return const SizedBox.shrink();
                          }
                          final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt());
                          String text;
                          if (_range == ChartRange.h1) {
                            text = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          } else if (_range == ChartRange.h6 || _range == ChartRange.h24) {
                            text = '${dt.hour.toString().padLeft(2, '0')}:00';
                          } else {
                            final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                            text = '${dt.day} ${months[dt.month - 1]}';
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.blue.shade400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.isEmpty
                          ? [FlSpot(0, (minY + maxY) / 2)]
                          : spots,
                      isCurved: !isBinary,
                      curveSmoothness: isBinary ? 0 : 0.3,
                      isStepLineChart: isBinary,
                      color: color,
                      barWidth: isBinary ? 2 : 2.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (spots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                Tr.readingsCount(spots.length, _range.label),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.cyan.shade100],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bar_chart_rounded,
                  size: 40, color: Colors.blue.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              Tr.noChartData,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Tr.noChartDataDesc,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}