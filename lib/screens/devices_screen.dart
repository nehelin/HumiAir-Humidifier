import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';
import 'add_device_screen.dart';
import 'charts_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return Scaffold(
        body: Center(child: Text(Tr.noDeviceTitle)),
      );
    }

    final service = FirestoreService(userId: uid);

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
            title: Text(
              Tr.myDevices,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          body: StreamBuilder<List<DeviceModel>>(
            stream: service.streamDevices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              }

              final devices = snapshot.data ?? [];

              if (devices.isEmpty) {
                return _buildEmpty(context, uid);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: devices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _DeviceCard(device: devices[i], service: service),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddDeviceScreen(userId: uid)),
            ),
            backgroundColor: Colors.blue.shade600,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              Tr.addDeviceBtn,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            elevation: 4,
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, String uid) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.cyan.shade100],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.devices_other_rounded,
                  size: 44, color: Colors.blue.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              Tr.noDevicesYet,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Tr.tapPlusToAdd,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Individual Device Card ────────────────────────────────────────────────

class _DeviceCard extends StatefulWidget {
  final DeviceModel device;
  final FirestoreService service;

  const _DeviceCard({required this.device, required this.service});

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _sub;
  DateTime? _lastLiveServerTime; // last time a real server push arrived
  Map<String, dynamic>? _liveData;
  bool _hasSnapshot = false;
  bool _docExists = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.streamLiveStatus(widget.device.deviceId).listen((snap) {
      if (!mounted) return;
      final isLiveFromServer = !snap.metadata.isFromCache;
      final data = snap.data() as Map<String, dynamic>?;
      setState(() {
        _hasSnapshot = true;
        _docExists = snap.exists;
        _liveData = data;
        if (isLiveFromServer && data != null) {
          _lastLiveServerTime = DateTime.now();
        }
      });
    });

    // Periodically re-evaluate online status so UI updates when device goes offline
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _liveData != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  bool _isOnline(Map<String, dynamic>? data) {
    if (data == null) return false;

    // 1. New firmware: use updatedAt / lastSeen timestamp
    DateTime? deviceTime;
    final rawUpdated = data['updatedAt'];
    if (rawUpdated is Timestamp) {
      deviceTime = rawUpdated.toDate();
    } else if (rawUpdated is String && rawUpdated.isNotEmpty) {
      deviceTime = DateTime.tryParse(rawUpdated);
    } else if (data['lastSeen'] is num) {
      deviceTime = DateTime.fromMillisecondsSinceEpoch(
          (data['lastSeen'] as num).toInt());
    }

    if (deviceTime != null) {
      return DateTime.now().toUtc().difference(deviceTime.toUtc()).inSeconds.abs() <= 20;
    }

    // 2. Legacy firmware fallback: rely on last live server push time
    if (_lastLiveServerTime != null) {
      return DateTime.now().difference(_lastLiveServerTime!).inSeconds <= 20;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final displayData = _liveData;
    final isOnline = _hasSnapshot && _docExists && _isOnline(displayData);

    final humidity = (displayData?['humidity'] as num?)?.toDouble();
    final temp = (displayData?['temperature'] as num?)?.toDouble();
    final mistOn = isOnline && displayData?['mistOn'] == true;
    final waterEmpty = isOnline && displayData?['waterEmpty'] == true;


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
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChartsScreen(
                  deviceId: widget.device.deviceId,
                  deviceName: widget.device.name,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.cyan.shade400
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.water_drop_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.device.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.device.room.isEmpty
                                  ? (LanguageService.instance.isBengali
                                      ? 'লোকেশন নেই'
                                      : 'No location')
                                  : widget.device.room,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Online / Offline badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOnline
                                ? Colors.green.shade200
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline
                                    ? Colors.green.shade500
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOnline ? Tr.online : Tr.offline,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isOnline
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Live data row (show whenever data exists, mist is OFF if offline)
                  if (displayData != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _miniStat(
                          icon: Icons.water_drop_rounded,
                          value: humidity != null
                              ? '${humidity.toStringAsFixed(1)}%'
                              : '--',
                          label: Tr.humidity,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 14),
                        _miniStat(
                          icon: Icons.thermostat_rounded,
                          value: temp != null
                              ? '${temp.toStringAsFixed(1)}°C'
                              : '--',
                          label: Tr.temperature,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 14),
                        _miniStat(
                          icon: mistOn
                              ? Icons.cloud_rounded
                              : Icons.cloud_off_rounded,
                          value: mistOn ? 'ON' : 'OFF',
                          label: Tr.mistStatus,
                          color: Colors.cyan.shade700,
                        ),
                        if (waterEmpty) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange.shade600,
                                    size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  Tr.waterTankLow,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Device ID row with copy button
                  Row(
                    children: [
                      Icon(Icons.fingerprint_rounded,
                          size: 13, color: Colors.blue.shade300),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.device.deviceId,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade400,
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.device.deviceId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(Tr.copied),
                              backgroundColor: Colors.blue.shade600,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.copy_rounded,
                              size: 15, color: Colors.blue.shade500),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Delete button
                      GestureDetector(
                        onTap: () =>
                            _confirmDelete(context, widget.device, widget.service),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 17, color: Colors.red.shade400),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _miniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Colors.blue.shade400)),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DeviceModel device,
    FirestoreService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(Tr.deleteDeviceTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          Tr.deleteDeviceDesc(device.name),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Tr.cancel,
                style: TextStyle(color: Colors.blue.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(Tr.remove),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await service.deleteDevice(device.deviceId);
    }
  }
}
