import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:galaxy_truck/models/rental.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentalService extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Rental> _rentals = [];

  List<Rental> get rentals => _rentals;
  List<Rental> get pendingRentals => _rentals.where((r) => r.isPending).toList();
  List<Rental> get activeRentals => _rentals.where((r) => r.isActive).toList();

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('rentals');

  Future<void> _patchRental(String rentalId, Map<String, dynamic> fields) async {
    try {
      await _col.doc(rentalId).set(fields, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to patch rental $rentalId: $e');
      rethrow;
    }
  }

  Future<void> loadRentals() async {
    try {
      final snap = await _col.limit(500).get();
      _rentals = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return Rental.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Failed to load rentals: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<String> createRental(String truckId, String driverId) async {
    final now = DateTime.now();
    final rental = Rental(
      id: _uuid.v4(),
      truckId: truckId,
      driverId: driverId,
      requestedAt: now,
      status: RentalStatus.requested,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _col.doc(rental.id).set(rental.toJson());
      _rentals.add(rental);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to create rental: $e');
      rethrow;
    }
    return rental.id;
  }

  Future<void> updateRental(Rental rental) async {
    try {
      await _col.doc(rental.id).set(rental.toJson());
      final index = _rentals.indexWhere((r) => r.id == rental.id);
      if (index == -1) {
        // Keep local cache best-effort, but don't block Firestore update.
        _rentals.add(rental);
      } else {
        _rentals[index] = rental;
      }
    } catch (e) {
      debugPrint('Failed to update rental: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> approveRental(String rentalId) async {
    final rental = getRentalById(rentalId);
    if (rental != null) {
      final updated = rental.copyWith(
        status: RentalStatus.approved,
        approvedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await updateRental(updated);
    }
  }

  Future<void> rejectRental(String rentalId, String reason) async {
    final rental = getRentalById(rentalId);
    if (rental != null) {
      final updated = rental.copyWith(
        status: RentalStatus.rejected,
        rejectionReason: reason,
        updatedAt: DateTime.now(),
      );
      await updateRental(updated);
    }
  }

  Future<void> startRental(String rentalId, String inspectionId) async {
    final rental = getRentalById(rentalId);
    final now = DateTime.now();
    if (rental == null) {
      await _patchRental(rentalId, {
        'status': RentalStatus.active.name,
        'startedAt': now.toIso8601String(),
        'pickupInspectionId': inspectionId,
        'updatedAt': now.toIso8601String(),
      });
      return;
    }

    final updated = rental.copyWith(
      status: RentalStatus.active,
      startedAt: now,
      pickupInspectionId: inspectionId,
      updatedAt: now,
    );
    await updateRental(updated);
  }

  Future<void> completeRental(String rentalId, String inspectionId) async {
    final rental = getRentalById(rentalId);
    final now = DateTime.now();
    if (rental == null) {
      // Don't silently no-op: still attempt to mark the Firestore doc complete.
      await _patchRental(rentalId, {
        'status': RentalStatus.completed.name,
        'completedAt': now.toIso8601String(),
        'dropoffInspectionId': inspectionId,
        'updatedAt': now.toIso8601String(),
      });
      return;
    }

    final updated = rental.copyWith(
      status: RentalStatus.completed,
      completedAt: now,
      dropoffInspectionId: inspectionId,
      updatedAt: now,
    );
    await updateRental(updated);
  }

  Rental? getRentalById(String rentalId) {
    try {
      return _rentals.firstWhere((r) => r.id == rentalId);
    } catch (e) {
      return null;
    }
  }

  List<Rental> getRentalsByDriver(String driverId) => _rentals.where((r) => r.driverId == driverId).toList();
  List<Rental> getRentalsByTruck(String truckId) => _rentals.where((r) => r.truckId == truckId).toList();
  
  Rental? getActiveRentalByDriver(String driverId) {
    try {
      return _rentals.firstWhere((r) => r.driverId == driverId && r.isActive);
    } catch (e) {
      return null;
    }
  }
}
