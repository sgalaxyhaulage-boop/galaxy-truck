import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:galaxy_truck/models/driver_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverService extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DriverProfile> _drivers = [];

  List<DriverProfile> get drivers => _drivers;
  List<DriverProfile> get pendingDrivers => _drivers.where((d) => d.isPending).toList();
  List<DriverProfile> get approvedDrivers => _drivers.where((d) => d.isApproved).toList();

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('driver_profiles');

  Future<void> loadDrivers() async {
    try {
      final snap = await _col.limit(500).get();
      _drivers = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return DriverProfile.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Failed to load drivers: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> addDriver(DriverProfile driver) async {
    try {
      final id = driver.id.isEmpty ? _uuid.v4() : driver.id;
      final toSave = driver.id.isEmpty ? driver.copyWith(id: id) : driver;
      await _col.doc(id).set(toSave.toJson());
      _drivers.add(toSave);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add driver profile: $e');
      rethrow;
    }
  }

  Future<void> updateDriver(DriverProfile driver) async {
    final index = _drivers.indexWhere((d) => d.id == driver.id);
    if (index == -1) return;
    try {
      await _col.doc(driver.id).set(driver.toJson());
      _drivers[index] = driver;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update driver profile: $e');
      rethrow;
    }
  }

  Future<void> approveDriver(String driverId) async {
    final driver = getDriverById(driverId);
    if (driver != null) {
      final updated = driver.copyWith(
        approvalStatus: ApprovalStatus.approved,
        updatedAt: DateTime.now(),
      );
      await updateDriver(updated);
    }
  }

  Future<void> rejectDriver(String driverId, String reason) async {
    final driver = getDriverById(driverId);
    if (driver != null) {
      final updated = driver.copyWith(
        approvalStatus: ApprovalStatus.rejected,
        rejectionReason: reason,
        updatedAt: DateTime.now(),
      );
      await updateDriver(updated);
    }
  }

  DriverProfile? getDriverById(String driverId) {
    try {
      return _drivers.firstWhere((d) => d.id == driverId);
    } catch (e) {
      return null;
    }
  }

  DriverProfile? getDriverByUserId(String userId) {
    try {
      return _drivers.firstWhere((d) => d.userId == userId);
    } catch (e) {
      return null;
    }
  }
}
