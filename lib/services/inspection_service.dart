import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:galaxy_truck/models/inspection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class InspectionService extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<Inspection> _inspections = [];

  List<Inspection> get inspections => _inspections;

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('inspections');

  Future<void> loadInspections() async {
    try {
      final snap = await _col.limit(500).get();
      _inspections = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return Inspection.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Failed to load inspections: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<String> createInspection(Inspection inspection) async {
    try {
      final id = inspection.id.isEmpty ? _uuid.v4() : inspection.id;
      final toSave = inspection.id.isEmpty ? inspection.copyWith(id: id) : inspection;
      await _col.doc(id).set(toSave.toJson());
      _inspections.add(toSave);
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Failed to create inspection: $e');
      rethrow;
    }
  }

  /// Uploads raw bytes to Firebase Storage and returns the download URL.
  ///
  /// This is used for inspection photos/signatures. Callers should handle
  /// Firebase Storage rules (permission-denied) and provide fallbacks.
  Future<String> uploadInspectionMediaBytes({required String inspectionId, required String fileName, required Uint8List bytes, required String contentType}) async {
    try {
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final ref = _storage.ref().child('inspections/$inspectionId/$safeFileName');
      final metadata = SettableMetadata(contentType: contentType, cacheControl: 'public,max-age=31536000');
      final task = await ref.putData(bytes, metadata);
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Failed to upload inspection media: $e');
      rethrow;
    }
  }

  Inspection? getInspectionById(String inspectionId) {
    try {
      return _inspections.firstWhere((i) => i.id == inspectionId);
    } catch (e) {
      return null;
    }
  }

  List<Inspection> getInspectionsByTruck(String truckId) => _inspections.where((i) => i.truckId == truckId).toList();
  List<Inspection> getInspectionsByDriver(String driverId) => _inspections.where((i) => i.driverId == driverId).toList();
}
