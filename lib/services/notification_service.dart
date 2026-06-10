import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:galaxy_truck/models/notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications => _notifications.where((n) => !n.isRead).toList();

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('notifications');

  Future<void> loadNotifications() async {
    try {
      final snap = await _col.limit(500).get();
      _notifications = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return AppNotification.fromJson(data);
      }).toList();
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? relatedEntityId,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    final notification = AppNotification(
      id: _uuid.v4(),
      userId: userId,
      type: type,
      title: title,
      message: message,
      timestamp: now,
      relatedEntityId: relatedEntityId,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _col.doc(notification.id).set(notification.toJson());
      _notifications.insert(0, notification);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to send notification: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final notification = _notifications.firstWhere((n) => n.id == notificationId);
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final updated = notification.copyWith(isRead: true, updatedAt: DateTime.now());
      try {
        await _col.doc(notificationId).set(updated.toJson());
        _notifications[index] = updated;
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to mark notification as read: $e');
        rethrow;
      }
    }
  }

  Future<void> markAllAsRead(String userId) async {
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true, updatedAt: DateTime.now());
      }
    }
    try {
      final batch = _firestore.batch();
      for (final n in _notifications.where((n) => n.userId == userId)) {
        batch.set(_col.doc(n.id), n.toJson());
      }
      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
      rethrow;
    }
  }

  List<AppNotification> getNotificationsByUser(String userId) => _notifications.where((n) => n.userId == userId).toList();
  
  int getUnreadCount(String userId) => _notifications.where((n) => n.userId == userId && !n.isRead).length;
}
