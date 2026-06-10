import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:galaxy_truck/models/maintenance_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceService extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<MaintenanceRequest> _maintenanceRequests = [];

  List<MaintenanceRequest> get maintenanceRequests => _maintenanceRequests;
  List<MaintenanceRequest> get pendingRequests => _maintenanceRequests.where((m) => m.isPending).toList();
  List<MaintenanceRequest> get urgentRequests => _maintenanceRequests.where((m) => m.isUrgent).toList();

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('maintenance_requests');

  Future<void> loadMaintenanceRequests() async {
    try {
      final snap = await _col.limit(500).get();
      _maintenanceRequests = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return MaintenanceRequest.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Failed to load maintenance requests: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<String> createMaintenanceRequest(MaintenanceRequest request) async {
    try {
      final id = request.id.isEmpty ? _uuid.v4() : request.id;
      final toSave = request.id.isEmpty ? request.copyWith(id: id) : request;
      await _col.doc(id).set(toSave.toJson());
      _maintenanceRequests.add(toSave);
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Failed to create maintenance request: $e');
      rethrow;
    }
  }

  Future<void> updateMaintenanceRequest(MaintenanceRequest request) async {
    final index = _maintenanceRequests.indexWhere((m) => m.id == request.id);
    if (index == -1) return;
    try {
      await _col.doc(request.id).set(request.toJson());
      _maintenanceRequests[index] = request;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update maintenance request: $e');
      rethrow;
    }
  }

  Future<void> approveMaintenanceRequest(String requestId, String approvedBy, {DateTime? scheduledDate, String? workshopName}) async {
    final request = getMaintenanceRequestById(requestId);
    if (request != null) {
      final updated = request.copyWith(
        status: MaintenanceStatus.approved,
        approvedAt: DateTime.now(),
        approvedBy: approvedBy,
        scheduledDate: scheduledDate,
        workshopName: workshopName,
        updatedAt: DateTime.now(),
      );
      await updateMaintenanceRequest(updated);
    }
  }

  Future<void> rejectMaintenanceRequest(String requestId, String reason) async {
    final request = getMaintenanceRequestById(requestId);
    if (request != null) {
      final updated = request.copyWith(
        status: MaintenanceStatus.rejected,
        rejectionReason: reason,
        updatedAt: DateTime.now(),
      );
      await updateMaintenanceRequest(updated);
    }
  }

  MaintenanceRequest? getMaintenanceRequestById(String requestId) {
    try {
      return _maintenanceRequests.firstWhere((m) => m.id == requestId);
    } catch (e) {
      return null;
    }
  }

  List<MaintenanceRequest> getMaintenanceRequestsByTruck(String truckId) => _maintenanceRequests.where((m) => m.truckId == truckId).toList();
  List<MaintenanceRequest> getMaintenanceRequestsByDriver(String driverId) => _maintenanceRequests.where((m) => m.driverId == driverId).toList();
}
