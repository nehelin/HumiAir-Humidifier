import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';
import 'devices_screen.dart';
import 'charts_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FirestoreService _firestoreService;

  List<DeviceModel> _devices = [];
  int _selectedIndex = 0;

  // Per-selected-device live data
  Map<String, dynamic>? _liveData;
  DateTime? _lastSnapshotReceived;
  Timer? _offlineCheckTimer;
  StreamSubscription<DocumentSnapshot>? _statusSub;

  // Threshold editing
  final _lowerCtrl = TextEditingController();
  final _upperCtrl = TextEditingController();
  bool _thresholdLoaded = false;
  bool _isSaving = false;
  bool _waterBannerDismissed = false;
  StreamSubscription<DocumentSnapshot>? _thresholdSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _firestoreService = FirestoreService(userId: uid);

    // Periodically re-evaluate online/offline status so UI switches promptly
    // when physical power is cut on the humidifier
    _offlineCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _liveData != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _offlineCheckTimer?.cancel();
    _statusSub?.cancel();
    _thresholdSub?.cancel();
    _lowerCtrl.dispose();
    _upperCtrl.dispose();
    super.dispose();
  }

  String? _subscribedDeviceId;

  bool _devicesListEqual(List<DeviceModel> a, List<DeviceModel> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].deviceId != b[i].deviceId || a[i].name != b[i].name) return false;
    }
    return true;
  }

  void _onDevicesChanged(List<DeviceModel> devices) {
    _devices = devices;

    if (devices.isEmpty) {
      _statusSub?.cancel();
      _thresholdSub?.cancel();
      _subscribedDeviceId = null;
      if (mounted) setState(() => _liveData = null);
      return;
    }

    if (_selectedIndex >= devices.length) {
      _selectedIndex = devices.length - 1;
    }

    final targetId = devices[_selectedIndex].deviceId;
    if (_subscribedDeviceId != targetId) {
      _subscribeToDevice(targetId);
    }
  }

  void _selectDevice(int index) {
    if (index == _selectedIndex || index >= _devices.length) return;
    setState(() {
      _selectedIndex = index;
      _liveData = null;
      _thresholdLoaded = false;
      _waterBannerDismissed = false;
    });
    _subscribeToDevice(_devices[index].deviceId);
  }

  void _subscribeToDevice(String deviceId) {
    _statusSub?.cancel();
    _thresholdSub?.cancel();
    _subscribedDeviceId = deviceId;
    _thresholdLoaded = false;
    _lastSnapshotReceived = null;

    _statusSub = _firestoreService.streamLiveStatus(deviceId).listen((snap) {
      if (!mounted) return;
      final data = snap.data() as Map<String, dynamic>?;
      final isWaterEmpty = (data != null && (data['waterEmpty'] ?? false) == true);

      setState(() {
        _liveData = data;
        _lastSnapshotReceived = DateTime.now();
        // When water is refilled, reset dismissal so future alerts can show
        if (!isWaterEmpty) {
          _waterBannerDismissed = false;
        }
      });
    });

    _thresholdSub =
        _firestoreService.streamThresholds(deviceId).listen((snap) {
      if (!mounted || _thresholdLoaded) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _lowerCtrl.text =
              (data['lowerThreshold'] ?? 60.0).toStringAsFixed(1);
          _upperCtrl.text =
              (data['upperThreshold'] ?? 70.0).toStringAsFixed(1);
          _thresholdLoaded = true;
        });
      }
    });
  }

  bool _isDeviceOnline(Map<String, dynamic>? data) {
    if (data == null) return false;

    // 1. Check updatedAt or lastSeen timestamp from ESP8266
    DateTime? deviceTime;
    final rawUpdated = data['updatedAt'];
    if (rawUpdated is Timestamp) {
      deviceTime = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      deviceTime = DateTime.tryParse(rawUpdated);
    } else if (data['lastSeen'] is num) {
      deviceTime = DateTime.fromMillisecondsSinceEpoch(
          (data['lastSeen'] as num).toInt());
    }

    if (deviceTime != null) {
      final diff =
          DateTime.now().toUtc().difference(deviceTime.toUtc()).inSeconds.abs();
      return diff <= 15;
    }

    // 2. Fallback: if data has no timestamp yet (legacy), rely on recent stream reception
    if (_lastSnapshotReceived != null) {
      final elapsed =
          DateTime.now().difference(_lastSnapshotReceived!).inSeconds;
      return elapsed <= 15;
    }

    return false;
  }

  Future<void> _saveThresholds() async {
    FocusScope.of(context).unfocus();

    final lowerStr = _lowerCtrl.text.trim().replaceAll(',', '.');
    final upperStr = _upperCtrl.text.trim().replaceAll(',', '.');
    final lower = double.tryParse(lowerStr);
    final upper = double.tryParse(upperStr);

    if (lower == null || upper == null) {
      _showSnack(Tr.invalidNumber, isError: true);
      return;
    }
    if (lower >= upper) {
      _showSnack(Tr.lowerMustBeLessThanUpper, isError: true);
      return;
    }
    if (_devices.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _firestoreService.setThresholds(
        _devices[_selectedIndex].deviceId,
        lower: lower,
        upper: upper,
      );
      if (!mounted) return;
      _thresholdLoaded = true;
      _lowerCtrl.text = lower.toStringAsFixed(1);
      _upperCtrl.text = upper.toStringAsFixed(1);
      _showSnack(Tr.thresholdsSaved);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F9FF),
          appBar: _buildAppBar(),
          body: StreamBuilder<List<DeviceModel>>(
            stream: _firestoreService.streamDevices(),
            builder: (context, snapshot) {
              // Smooth optimistic handling: avoid full-screen spinner flashing
              final devices = snapshot.data ?? _devices;

              if (snapshot.hasData && !_devicesListEqual(snapshot.data!, _devices)) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _onDevicesChanged(snapshot.data!),
                );
              }

              if (devices.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _devices.isEmpty) {
                  // Subtle calm placeholder while first fetching
                  return _buildLoadingPlaceholder();
                }
                return _buildNoDevicePlaceholder();
              }

              return Column(
                children: [
                  if (devices.length > 1) _buildDeviceSelector(devices),
                  Expanded(child: _buildDashboard(devices)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.cyan.shade400],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.water_drop_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            Tr.appName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: Tr.myDevices,
          icon: Icon(Icons.devices_rounded,
              color: Colors.blue.shade500, size: 22),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DevicesScreen()),
          ),
        ),
        IconButton(
          tooltip: Tr.sensorHistory,
          icon: Icon(Icons.bar_chart_rounded,
              color: Colors.blue.shade500, size: 22),
          onPressed: () {
            if (_devices.isEmpty) {
              _showSnack(Tr.noDeviceTitle, isError: true);
              return;
            }
            final d = _devices[_selectedIndex];
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChartsScreen(deviceId: d.deviceId, deviceName: d.name),
              ),
            );
          },
        ),
        IconButton(
          tooltip: Tr.profileAndSettings,
          icon: Icon(Icons.account_circle_outlined,
              color: Colors.blue.shade600, size: 24),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildDeviceSelector(List<DeviceModel> devices) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: devices.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = i == _selectedIndex;
            return GestureDetector(
              onTap: () => _selectDevice(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.cyan.shade400
                          ],
                        )
                      : null,
                  color: selected ? null : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.blue.shade100,
                  ),
                ),
                child: Text(
                  devices[i].name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.blue.shade600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(List<DeviceModel> devices) {
    final device = _selectedIndex < devices.length
        ? devices[_selectedIndex]
        : devices.first;
    final isDeviceOnline = _isDeviceOnline(_liveData);
    final isWaterEmpty = isDeviceOnline && _liveData?['waterEmpty'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isWaterEmpty && !_waterBannerDismissed) ...[
          _buildWaterEmptyBanner(device),
          const SizedBox(height: 12),
        ],
        _buildLiveCard(device),
        const SizedBox(height: 14),
        _buildThresholdCard(device),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWaterEmptyBanner(DeviceModel device) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop_rounded, color: Color(0xFFEA580C), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${device.name} — ${Tr.waterTankLowNotice}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              setState(() => _waterBannerDismissed = true);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                Tr.ok,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(DeviceModel device) {
    final data = _liveData;
    final isOnline = _isDeviceOnline(data);
    final humidity = (data?['humidity'] as num?)?.toDouble();
    final temp = (data?['temperature'] as num?)?.toDouble();
    final mistOn = isOnline && data?['mistOn'] == true;
    final waterEmpty = isOnline && data?['waterEmpty'] == true;
    final hasData = data != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.cyan.shade500],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.sensors_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  device.room.isEmpty ? Tr.liveStatus : device.room,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.white.withValues(alpha: 0.2)
                        : (hasData
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(20),
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
                              ? const Color(0xFF4ADE80)
                              : (hasData
                                  ? const Color(0xFFF87171)
                                  : Colors.white38),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline
                            ? Tr.online
                            : (hasData ? Tr.offline : Tr.waiting),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main humidity & temperature section
            if (hasData) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    humidity != null
                        ? humidity.toStringAsFixed(1)
                        : '--',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('%',
                        style: TextStyle(
                            fontSize: 22,
                            color: Colors.white70,
                            fontWeight: FontWeight.w300)),
                  ),
                  const Spacer(),
                  // Temperature pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.thermostat_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          temp != null
                              ? '${temp.toStringAsFixed(1)}°C'
                              : '--',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(Tr.humidity,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 16),
              // Status row (Wrap prevents pixel overflow on smaller screens)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStatusBadge(
                    icon: mistOn
                        ? Icons.cloud_rounded
                        : Icons.cloud_off_rounded,
                    label: mistOn ? Tr.mistOn : Tr.mistOff,
                    active: mistOn,
                  ),
                  if (waterEmpty)
                    _buildStatusBadge(
                      icon: Icons.warning_amber_rounded,
                      label: Tr.waterTankLow,
                      active: false,
                      isWarning: true,
                    ),
                  if (!isOnline && hasData)
                    _buildStatusBadge(
                      icon: Icons.power_off_rounded,
                      label: Tr.deviceOfflineNotice,
                      active: false,
                      isWarning: false,
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_sync_outlined,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Tr.waitingForDeviceData,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required bool active,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xFFFFA500).withValues(alpha: 0.25)
            : active
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWarning
              ? Colors.orange.shade300.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildThresholdCard(DeviceModel device) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tune_rounded,
                      color: Colors.blue.shade500, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Tr.humidityThresholds,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900)),
                    Text(Tr.thresholdRangeSubtitle,
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade400)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildThresholdField(
                    controller: _lowerCtrl,
                    label: Tr.lowerThreshold,
                    icon: Icons.arrow_downward_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildThresholdField(
                    controller: _upperCtrl,
                    label: Tr.upperThreshold,
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.cyan.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade500, Colors.cyan.shade500],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveThresholds,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          Tr.saveThresholds,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          onTap: () {
            if (controller.text.isNotEmpty) {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            }
          },
          onChanged: (_) => setState(() {}),
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade900),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.blue.shade50.withValues(alpha: 0.6),
            prefixIcon: Icon(icon, size: 16, color: color),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.cancel_rounded,
                        size: 18, color: Colors.blue.shade300),
                    splashRadius: 16,
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.water_drop_outlined,
                size: 34, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            Tr.waitingForDeviceData,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDevicePlaceholder() {
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
                  colors: [
                    Colors.blue.shade100,
                    Colors.cyan.shade100
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.water_drop_outlined,
                  size: 44, color: Colors.blue.shade400),
            ),
            const SizedBox(height: 22),
            Text(
              Tr.noDeviceTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Tr.noDeviceDesc,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.cyan.shade500],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevicesScreen()),
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  Tr.addDeviceBtn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
