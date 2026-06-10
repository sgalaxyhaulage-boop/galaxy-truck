import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:galaxy_truck/models/truck.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TruckService extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Truck> _trucks = [];

  List<Truck> get trucks => _trucks;
  List<Truck> get availableTrucks => _trucks.where((t) => t.isAvailable).toList();
  List<Truck> get rentedTrucks => _trucks.where((t) => t.isRented).toList();

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('trucks');

  /// Normalizes a truck rego to match the Firestore document ID format.
  ///
  /// Requirement: uppercase + remove spaces. We also remove any non-alphanumeric
  /// characters defensively so formats like "ABC-123" still work.
  static String normalizeRego(String input) => input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

  Future<void> loadTrucks() async {
    try {
      final snap = await _col.limit(500).get();
      final loaded = <Truck>[];

      for (final d in snap.docs) {
        try {
          final data = d.data();
          // Ensure id is present even if document was created externally.
          data['id'] ??= d.id;
          final truck = Truck.fromJson(data);
          // Skip obviously invalid records.
          if (truck.registrationNumber.trim().isEmpty) {
            debugPrint('TruckService: skipping truck doc ${d.id} (missing registrationNumber/rego)');
            continue;
          }
          loaded.add(truck);
        } catch (e) {
          debugPrint('TruckService: failed to parse truck doc ${d.id}: $e');
        }
      }

      _trucks = loaded;
    } catch (e) {
      debugPrint('Failed to load trucks: $e');
      _trucks = [];
    } finally {
      notifyListeners();
    }
  }

  /// Fetches a truck directly by its Firestore document ID, which is the
  /// normalized rego (e.g. "ABC123"). Returns null if not found.
  Future<Truck?> getTruckByRegoDocId(String regoInput) async {
    final regoId = normalizeRego(regoInput);
    if (regoId.isEmpty) return null;
    try {
      final doc = await _col.doc(regoId).get();
      if (!doc.exists) return null;

      final data = doc.data() ?? <String, dynamic>{};
      data['id'] ??= doc.id;
      data['registrationNumber'] ??= doc.id;
      final truck = Truck.fromJson(data);

      // Keep local cache in sync for admin lists / dashboards.
      final index = _trucks.indexWhere((t) => t.id == truck.id);
      if (index >= 0) {
        _trucks[index] = truck;
      } else {
        _trucks.add(truck);
      }
      notifyListeners();
      return truck;
    } catch (e) {
      debugPrint('TruckService: failed to fetch truck by rego doc id: $e');
      return null;
    }
  }

  Future<void> addTruck(Truck truck) async {
    try {
      // New requirement: Firestore doc ID must equal normalized rego.
      // If a truck is created without an id, we derive it from rego.
      final normalizedRego = normalizeRego(truck.registrationNumber);
      final id = truck.id.isNotEmpty
          ? truck.id
          : (normalizedRego.isNotEmpty ? normalizedRego : _uuid.v4());

      final toSave = truck.copyWith(
        id: id,
        registrationNumber: normalizedRego.isNotEmpty ? normalizedRego : truck.registrationNumber,
        updatedAt: DateTime.now(),
      );

      await _col.doc(id).set(toSave.toJson());
      final existingIndex = _trucks.indexWhere((t) => t.id == toSave.id);
      if (existingIndex >= 0) {
        _trucks[existingIndex] = toSave;
      } else {
        _trucks.add(toSave);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add truck: $e');
      rethrow;
    }
  }

  Future<void> updateTruck(Truck truck) async {
    final index = _trucks.indexWhere((t) => t.id == truck.id);
    if (index == -1) return;
    try {
      await _col.doc(truck.id).set(truck.toJson());
      _trucks[index] = truck;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update truck: $e');
      rethrow;
    }
  }

  Future<void> deleteTruck(String truckId) async {
    try {
      await _col.doc(truckId).delete();
      _trucks.removeWhere((t) => t.id == truckId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete truck: $e');
      rethrow;
    }
  }

  Future<void> updateTruckStatus(String truckId, TruckStatus status, {String? driverId}) async {
    final truck = getTruckById(truckId);
    if (truck != null) {
      final updatedTruck = truck.copyWith(
        status: status,
        currentDriverId: driverId,
        updatedAt: DateTime.now(),
      );
      await updateTruck(updatedTruck);
    }
  }

  Future<void> updateTruckLocation(String truckId, double latitude, double longitude) async {
    final truck = getTruckById(truckId);
    if (truck != null) {
      final updatedTruck = truck.copyWith(
        currentLatitude: latitude,
        currentLongitude: longitude,
        lastLocationUpdate: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await updateTruck(updatedTruck);
    }
  }

  Truck? getTruckById(String truckId) {
    try {
      return _trucks.firstWhere((t) => t.id == truckId);
    } catch (e) {
      return null;
    }
  }

  List<Truck> getTrucksByDriver(String driverId) => _trucks.where((t) => t.currentDriverId == driverId).toList();

  List<Truck> searchTrucks(String query) {
    final lowerQuery = query.toLowerCase();
    return _trucks.where((t) =>
      t.registrationNumber.toLowerCase().contains(lowerQuery) ||
      t.fleetNumber.toLowerCase().contains(lowerQuery) ||
      t.make.toLowerCase().contains(lowerQuery) ||
      t.model.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}
