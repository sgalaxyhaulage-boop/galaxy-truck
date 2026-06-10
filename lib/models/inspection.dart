class InspectionPhoto {
  final String label;
  final String path;

  InspectionPhoto({required this.label, required this.path});

  Map<String, dynamic> toJson() => {'label': label, 'path': path};

  factory InspectionPhoto.fromJson(Map<String, dynamic> json) =>
      InspectionPhoto(label: json['label'], path: json['path']);
}

class InspectionChecklist {
  final bool hasVisibleDamage;
  final bool hasWindscreenCrack;
  final bool hasTyreDamage;
  final bool hasWarningLights;
  final String? damageDescription;
  final String? damageLocation;
  final List<String> damagePhotoPaths;

  InspectionChecklist({
    required this.hasVisibleDamage,
    required this.hasWindscreenCrack,
    required this.hasTyreDamage,
    required this.hasWarningLights,
    this.damageDescription,
    this.damageLocation,
    this.damagePhotoPaths = const [],
  });

  bool get hasIssues => hasVisibleDamage || hasWindscreenCrack || hasTyreDamage || hasWarningLights;

  Map<String, dynamic> toJson() => {
    'hasVisibleDamage': hasVisibleDamage,
    'hasWindscreenCrack': hasWindscreenCrack,
    'hasTyreDamage': hasTyreDamage,
    'hasWarningLights': hasWarningLights,
    'damageDescription': damageDescription,
    'damageLocation': damageLocation,
    'damagePhotoPaths': damagePhotoPaths,
  };

  factory InspectionChecklist.fromJson(Map<String, dynamic> json) =>
      InspectionChecklist(
        hasVisibleDamage: json['hasVisibleDamage'],
        hasWindscreenCrack: json['hasWindscreenCrack'],
        hasTyreDamage: json['hasTyreDamage'],
        hasWarningLights: json['hasWarningLights'],
        damageDescription: json['damageDescription'],
        damageLocation: json['damageLocation'],
        damagePhotoPaths: List<String>.from(json['damagePhotoPaths'] ?? []),
      );
}

enum InspectionType { pickup, dropoff }

class Inspection {
  final String id;
  final String truckId;
  final String driverId;
  final InspectionType type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final List<InspectionPhoto> photos;
  final double odometer;
  final double fuelLevel;
  final InspectionChecklist checklist;
  final String? signaturePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Inspection({
    required this.id,
    required this.truckId,
    required this.driverId,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.photos,
    required this.odometer,
    required this.fuelLevel,
    required this.checklist,
    this.signaturePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'truckId': truckId,
    'driverId': driverId,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'photos': photos.map((p) => p.toJson()).toList(),
    'odometer': odometer,
    'fuelLevel': fuelLevel,
    'checklist': checklist.toJson(),
    'signaturePath': signaturePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Inspection.fromJson(Map<String, dynamic> json) => Inspection(
    id: json['id'],
    truckId: json['truckId'],
    driverId: json['driverId'],
    type: InspectionType.values.firstWhere((e) => e.name == json['type']),
    timestamp: DateTime.parse(json['timestamp']),
    latitude: json['latitude'].toDouble(),
    longitude: json['longitude'].toDouble(),
    photos: (json['photos'] as List).map((p) => InspectionPhoto.fromJson(p)).toList(),
    odometer: json['odometer'].toDouble(),
    fuelLevel: json['fuelLevel'].toDouble(),
    checklist: InspectionChecklist.fromJson(json['checklist']),
    signaturePath: json['signaturePath'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  Inspection copyWith({
    String? id,
    String? truckId,
    String? driverId,
    InspectionType? type,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    List<InspectionPhoto>? photos,
    double? odometer,
    double? fuelLevel,
    InspectionChecklist? checklist,
    String? signaturePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Inspection(
    id: id ?? this.id,
    truckId: truckId ?? this.truckId,
    driverId: driverId ?? this.driverId,
    type: type ?? this.type,
    timestamp: timestamp ?? this.timestamp,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    photos: photos ?? this.photos,
    odometer: odometer ?? this.odometer,
    fuelLevel: fuelLevel ?? this.fuelLevel,
    checklist: checklist ?? this.checklist,
    signaturePath: signaturePath ?? this.signaturePath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
