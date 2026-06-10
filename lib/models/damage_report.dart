enum DamageType {
  general,
  windscreenCrack,
  tyreDamage,
  accident,
  bodyDamage,
  mechanicalIssue
}

enum DamageReportStatus {
  submitted,
  reviewed,
  approved,
  repairScheduled,
  repairCompleted,
  closed
}

class DamageReport {
  final String id;
  final String truckId;
  final String driverId;
  final DamageType damageType;
  final String description;
  final List<String> photoPaths;
  final double latitude;
  final double longitude;
  final DateTime reportedAt;
  final DamageReportStatus status;
  final String? adminNotes;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  DamageReport({
    required this.id,
    required this.truckId,
    required this.driverId,
    required this.damageType,
    required this.description,
    required this.photoPaths,
    required this.latitude,
    required this.longitude,
    required this.reportedAt,
    this.status = DamageReportStatus.submitted,
    this.adminNotes,
    this.reviewedAt,
    this.reviewedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == DamageReportStatus.submitted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'truckId': truckId,
    'driverId': driverId,
    'damageType': damageType.name,
    'description': description,
    'photoPaths': photoPaths,
    'latitude': latitude,
    'longitude': longitude,
    'reportedAt': reportedAt.toIso8601String(),
    'status': status.name,
    'adminNotes': adminNotes,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'reviewedBy': reviewedBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DamageReport.fromJson(Map<String, dynamic> json) => DamageReport(
    id: json['id'],
    truckId: json['truckId'],
    driverId: json['driverId'],
    damageType: DamageType.values.firstWhere((e) => e.name == json['damageType']),
    description: json['description'],
    photoPaths: List<String>.from(json['photoPaths']),
    latitude: json['latitude'].toDouble(),
    longitude: json['longitude'].toDouble(),
    reportedAt: DateTime.parse(json['reportedAt']),
    status: DamageReportStatus.values.firstWhere((e) => e.name == json['status']),
    adminNotes: json['adminNotes'],
    reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt']) : null,
    reviewedBy: json['reviewedBy'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  DamageReport copyWith({
    String? id,
    String? truckId,
    String? driverId,
    DamageType? damageType,
    String? description,
    List<String>? photoPaths,
    double? latitude,
    double? longitude,
    DateTime? reportedAt,
    DamageReportStatus? status,
    String? adminNotes,
    DateTime? reviewedAt,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DamageReport(
    id: id ?? this.id,
    truckId: truckId ?? this.truckId,
    driverId: driverId ?? this.driverId,
    damageType: damageType ?? this.damageType,
    description: description ?? this.description,
    photoPaths: photoPaths ?? this.photoPaths,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    reportedAt: reportedAt ?? this.reportedAt,
    status: status ?? this.status,
    adminNotes: adminNotes ?? this.adminNotes,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
