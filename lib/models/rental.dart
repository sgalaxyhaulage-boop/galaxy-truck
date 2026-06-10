enum RentalStatus {
  requested,
  approved,
  rejected,
  active,
  completed,
  cancelled
}

class Rental {
  final String id;
  final String truckId;
  final String driverId;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? pickupInspectionId;
  final String? dropoffInspectionId;
  final RentalStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  Rental({
    required this.id,
    required this.truckId,
    required this.driverId,
    required this.requestedAt,
    this.approvedAt,
    this.startedAt,
    this.completedAt,
    this.pickupInspectionId,
    this.dropoffInspectionId,
    this.status = RentalStatus.requested,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == RentalStatus.active;
  bool get isPending => status == RentalStatus.requested;

  Map<String, dynamic> toJson() => {
    'id': id,
    'truckId': truckId,
    'driverId': driverId,
    'requestedAt': requestedAt.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'pickupInspectionId': pickupInspectionId,
    'dropoffInspectionId': dropoffInspectionId,
    'status': status.name,
    'rejectionReason': rejectionReason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Rental.fromJson(Map<String, dynamic> json) => Rental(
    id: json['id'],
    truckId: json['truckId'],
    driverId: json['driverId'],
    requestedAt: DateTime.parse(json['requestedAt']),
    approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
    startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    pickupInspectionId: json['pickupInspectionId'],
    dropoffInspectionId: json['dropoffInspectionId'],
    status: RentalStatus.values.firstWhere((e) => e.name == json['status']),
    rejectionReason: json['rejectionReason'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  Rental copyWith({
    String? id,
    String? truckId,
    String? driverId,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? pickupInspectionId,
    String? dropoffInspectionId,
    RentalStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Rental(
    id: id ?? this.id,
    truckId: truckId ?? this.truckId,
    driverId: driverId ?? this.driverId,
    requestedAt: requestedAt ?? this.requestedAt,
    approvedAt: approvedAt ?? this.approvedAt,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    pickupInspectionId: pickupInspectionId ?? this.pickupInspectionId,
    dropoffInspectionId: dropoffInspectionId ?? this.dropoffInspectionId,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
