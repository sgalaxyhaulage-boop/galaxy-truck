import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:galaxy_truck/models/damage_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class DamageService extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<DamageReport> _damageReports = [];

  List<DamageReport> get damageReports => _damageReports;
  List<DamageReport> get pendingReports => _damageReports.where((d) => d.isPending).toList();

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('damage_reports');

  /// Uploads a damage report photo to Firebase Storage and returns a download URL.
  ///
  /// Callers should catch permission errors (Storage rules) and provide fallbacks
  /// (e.g. store as base64 data uri in Firestore).
  Future<String> uploadDamageMediaBytes({required String reportId, required String fileName, required Uint8List bytes, required String contentType}) async {
    try {
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final ref = _storage.ref().child('damage_reports/$reportId/$safeFileName');
      final metadata = SettableMetadata(contentType: contentType, cacheControl: 'public,max-age=31536000');
      final task = await ref.putData(bytes, metadata);
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Failed to upload damage media: $e');
      rethrow;
    }
  }

  Future<void> loadDamageReports() async {
    try {
      final snap = await _col.limit(500).get();
      _damageReports = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return DamageReport.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Failed to load damage reports: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<String> createDamageReport(DamageReport report) async {
    try {
      final id = report.id.isEmpty ? _uuid.v4() : report.id;
      final toSave = report.id.isEmpty ? report.copyWith(id: id) : report;
      await _col.doc(id).set(toSave.toJson());
      _damageReports.add(toSave);
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Failed to create damage report: $e');
      rethrow;
    }
  }

  Future<void> updateDamageReport(DamageReport report) async {
    final index = _damageReports.indexWhere((d) => d.id == report.id);
    if (index == -1) return;
    try {
      await _col.doc(report.id).set(report.toJson());
      _damageReports[index] = report;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to update damage report: $e');
      rethrow;
    }
  }

  Future<void> reviewDamageReport(String reportId, DamageReportStatus status, String reviewedBy, {String? adminNotes}) async {
    final report = getDamageReportById(reportId);
    if (report != null) {
      final updated = report.copyWith(
        status: status,
        reviewedAt: DateTime.now(),
        reviewedBy: reviewedBy,
        adminNotes: adminNotes,
        updatedAt: DateTime.now(),
      );
      await updateDamageReport(updated);
    }
  }

  DamageReport? getDamageReportById(String reportId) {
    try {
      return _damageReports.firstWhere((d) => d.id == reportId);
    } catch (e) {
      return null;
    }
  }

  List<DamageReport> getDamageReportsByTruck(String truckId) => _damageReports.where((d) => d.truckId == truckId).toList();
}
