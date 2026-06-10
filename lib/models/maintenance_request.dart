enum MaintenanceCategory {
  generalService,
  tyreReplacement,
  windscreenReplacement,
  brakeIssue,
  engineIssue,
  transmissionIssue,
  tailLiftIssue,
  electricalIssue,
  airConditioning,
  bodyDamageRepair,
  other
}

enum UrgencyLevel { normal, urgent, unsafeToDrive }

enum MaintenanceStatus {
  requested,
  approved,
  scheduled,
  dropOffRequired,
  truckDroppedOff,
  inService,
  waitingForParts,
  qualityCheck,
  completed,
  readyForPickup,
  pickedUp,
  rejected
}

class MaintenanceRequest {
  final String id;
  final String truckId;
  final String driverId;
  final MaintenanceCategory category;
  final String issueDescription;
  final List<String> photoPaths;
  final List<String> videoPaths;
  final double odometer;
  final double latitude;
  final double longitude;
  final DateTime? preferredServiceDate;
  final UrgencyLevel urgencyLevel;
  final MaintenanceStatus status;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? scheduledDate;
  final String? workshopName;
  final String? adminNotes;
  final String? invoicePath;
  final double? repairCost;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceRequest({
    required this.id,
    required this.truckId,
    required this.driverId,
    required this.category,
    required this.issueDescription,
    this.photoPaths = const [],
    this.videoPaths = const [],
    required this.odometer,
    required this.latitude,
    required this.longitude,
    this.preferredServiceDate,
    this.urgencyLevel = UrgencyLevel.normal,
    this.status = MaintenanceStatus.requested,
    this.approvedAt,
    this.approvedBy,
    this.scheduledDate,
    this.workshopName,
    this.adminNotes,
    this.invoicePath,
    this.repairCost,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == MaintenanceStatus.requested;
  bool get isUrgent => urgencyLevel == UrgencyLevel.urgent || urgencyLevel == UrgencyLevel.unsafeToDrive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'truckId': truckId,
    'driverId': driverId,
    'category': category.name,
    'issueDescription': issueDescription,
    'photoPaths': photoPaths,
    'videoPaths': videoPaths,
    'odometer': odometer,
    'latitude': latitude,
    'longitude': longitude,
    'preferredServiceDate': preferredServiceDate?.toIso8601String(),
    'urgencyLevel': urgencyLevel.name,
    'status': status.name,
    'approvedAt': approvedAt?.toIso8601String(),
    'approvedBy': approvedBy,
    'scheduledDate': scheduledDate?.toIso8601String(),
    'workshopName': workshopName,
    'adminNotes': adminNotes,
    'invoicePath': invoicePath,
    'repairCost': repairCost,
    'rejectionReason': rejectionReason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) => MaintenanceRequest(
    id: json['id'],
    truckId: json['truckId'],
    driverId: json['driverId'],
    category: MaintenanceCategory.values.firstWhere((e) => e.name == json['category']),
    issueDescription: json['issueDescription'],
    photoPaths: List<String>.from(json['photoPaths'] ?? []),
    videoPaths: List<String>.from(json['videoPaths'] ?? []),
    odometer: json['odometer'].toDouble(),
    latitude: json['latitude'].toDouble(),
    longitude: json['longitude'].toDouble(),
    preferredServiceDate: json['preferredServiceDate'] != null ? DateTime.parse(json['preferredServiceDate']) : null,
    urgencyLevel: UrgencyLevel.values.firstWhere((e) => e.name == json['urgencyLevel']),
    status: MaintenanceStatus.values.firstWhere((e) => e.name == json['status']),
    approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
    approvedBy: json['approvedBy'],
    scheduledDate: json['scheduledDate'] != null ? DateTime.parse(json['scheduledDate']) : null,
    workshopName: json['workshopName'],
    adminNotes: json['adminNotes'],
    invoicePath: json['invoicePath'],
    repairCost: json['repairCost']?.toDouble(),
    rejectionReason: json['rejectionReason'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  MaintenanceRequest copyWith({
    String? id,
    String? truckId,
    String? driverId,
    MaintenanceCategory? category,
    String? issueDescription,
    List<String>? photoPaths,
    List<String>? videoPaths,
    double? odometer,
    double? latitude,
    double? longitude,
    DateTime? preferredServiceDate,
    UrgencyLevel? urgencyLevel,
    MaintenanceStatus? status,
    DateTime? approvedAt,
    String? approvedBy,
    DateTime? scheduledDate,
    String? workshopName,
    String? adminNotes,
    String? invoicePath,
    double? repairCost,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MaintenanceRequest(
    id: id ?? this.id,
    truckId: truckId ?? this.truckId,
    driverId: driverId ?? this.driverId,
    category: category ?? this.category,
    issueDescription: issueDescription ?? this.issueDescription,
    photoPaths: photoPaths ?? this.photoPaths,
    videoPaths: videoPaths ?? this.videoPaths,
    odometer: odometer ?? this.odometer,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    preferredServiceDate: preferredServiceDate ?? this.preferredServiceDate,
    urgencyLevel: urgencyLevel ?? this.urgencyLevel,
    status: status ?? this.status,
    approvedAt: approvedAt ?? this.approvedAt,
    approvedBy: approvedBy ?? this.approvedBy,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    workshopName: workshopName ?? this.workshopName,
    adminNotes: adminNotes ?? this.adminNotes,
    invoicePath: invoicePath ?? this.invoicePath,
    repairCost: repairCost ?? this.repairCost,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
