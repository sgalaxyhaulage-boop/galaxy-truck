enum NotificationType {
  rentalApproved,
  rentalRejected,
  serviceApproved,
  serviceScheduled,
  truckDroppedOff,
  truckInService,
  waitingForParts,
  serviceCompleted,
  truckReadyForPickup,
  damageReportUpdate,
  licenceExpiry,
  registrationExpiry,
  insuranceExpiry,
  serviceDue,
  general
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime timestamp;
  final String? relatedEntityId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.timestamp,
    this.relatedEntityId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'title': title,
    'message': message,
    'isRead': isRead,
    'timestamp': timestamp.toIso8601String(),
    'relatedEntityId': relatedEntityId,
    'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'],
    userId: json['userId'],
    type: NotificationType.values.firstWhere((e) => e.name == json['type']),
    title: json['title'],
    message: json['message'],
    isRead: json['isRead'] ?? false,
    timestamp: DateTime.parse(json['timestamp']),
    relatedEntityId: json['relatedEntityId'],
    metadata: json['metadata'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    bool? isRead,
    DateTime? timestamp,
    String? relatedEntityId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AppNotification(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    title: title ?? this.title,
    message: message ?? this.message,
    isRead: isRead ?? this.isRead,
    timestamp: timestamp ?? this.timestamp,
    relatedEntityId: relatedEntityId ?? this.relatedEntityId,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
