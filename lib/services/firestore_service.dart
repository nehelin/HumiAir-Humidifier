import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ── DeviceModel ──────────────────────────────────────────────────────────────
class DeviceModel {
  final String id;       // Firestore document ID (same as deviceId)
  final String name;     // User-chosen friendly name
  final String deviceId; // e.g. "humiair_aabbccddeeff"
  final String room;     // e.g. "Bedroom"
  final DateTime createdAt;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.room,
    required this.createdAt,
  });

  factory DeviceModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return DeviceModel(
      id:        snapshot.id,
      name:      data['name']     as String? ?? 'Unnamed Device',
      deviceId:  data['deviceId'] as String? ?? snapshot.id,
      room:      data['room']     as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    'deviceId':  deviceId,
    'room':      room,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

/// ── FirestoreService ─────────────────────────────────────────────────────────
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  FirestoreService({required this.userId});

  // ── user-scoped device registry ──────────────────────────────────────────
  CollectionReference get _devicesCol =>
      _db.collection('users').doc(userId).collection('devices');

  // ── shared device data (written by ESP8266, readable by any linked user) ─
  DocumentReference _deviceDoc(String deviceId) =>
      _db.collection('devices').doc(deviceId);

  CollectionReference _sensorCol(String deviceId) =>
      _deviceDoc(deviceId).collection('sensorData');

  CollectionReference _settingsCol(String deviceId) =>
      _deviceDoc(deviceId).collection('settings');

  CollectionReference _statusCol(String deviceId) =>
      _deviceDoc(deviceId).collection('status');

  // ── Device CRUD ──────────────────────────────────────────────────────────

  /// Add a device.  Uses [device.deviceId] as the Firestore doc ID so that
  /// security rules can verify ownership via users/{uid}/devices/{deviceId}.
  Future<void> addDevice(DeviceModel device) async {
    if (device.deviceId.isEmpty) {
      throw ArgumentError('deviceId must not be empty.');
    }
    await _devicesCol.doc(device.deviceId).set(device.toMap());
  }

  Future<void> deleteDevice(String deviceId) async {
    await _devicesCol.doc(deviceId).delete();
  }

  Stream<List<DeviceModel>> streamDevices() {
    if (userId.isEmpty) return Stream.value([]);
    return _devicesCol.snapshots().map((s) {
      final list = s.docs.map(DeviceModel.fromSnapshot).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  // ── Live status (written by ESP8266 every 2 s) ────────────────────────────

  Stream<DocumentSnapshot> streamLiveStatus(String deviceId) {
    return _statusCol(deviceId).doc('current').snapshots();
  }

  // ── Thresholds ────────────────────────────────────────────────────────────

  Stream<DocumentSnapshot> streamThresholds(String deviceId) {
    return _settingsCol(deviceId).doc('thresholds').snapshots();
  }

  Future<void> setThresholds(
    String deviceId, {
    required double lower,
    required double upper,
  }) async {
    await _settingsCol(deviceId).doc('thresholds').set({
      'lowerThreshold': lower,
      'upperThreshold': upper,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Sensor history ────────────────────────────────────────────────────────

  /// Returns sensor readings up to [limit] documents.
  Stream<QuerySnapshot> streamSensorData(String deviceId, {int limit = 100}) {
    return _sensorCol(deviceId)
        .limit(limit)
        .snapshots();
  }

  /// Returns sensor readings within the last [hours] hours.
  Stream<QuerySnapshot> streamSensorDataSince(String deviceId,
      {required int hours}) {
    return _sensorCol(deviceId)
        .limit(200)
        .snapshots();
  }

  // ── Device existence check (used in Add Device flow) ──────────────────────

  /// Returns true if the device has ever sent data to Firestore.
  Future<bool> deviceExists(String deviceId) async {
    final doc = await _statusCol(deviceId).doc('current').get();
    return doc.exists;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String get currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';
}