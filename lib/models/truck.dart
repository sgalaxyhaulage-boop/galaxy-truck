enum TruckStatus {
  available,
  reserved,
  rented,
  inService,
  underRepair,
  damaged,
  awaitingPickup,
  outOfService
}

enum TruckType { box, flatbed, refrigerated, tanker, dump }

enum FuelType { diesel, petrol, electric, hybrid }

class Truck {
  final String id;
  final String registrationNumber;
  final String vin;
  final String make;
  final String model;
  final int year;
  final String fleetNumber;
  final TruckType truckType;
  final int palletCapacity;
  final FuelType fuelType;
  final double currentOdometer;
  final DateTime serviceDueDate;
  final DateTime registrationExpiry;
  final DateTime insuranceExpiry;
  final TruckStatus status;
  final String? currentDriverId;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? lastLocationUpdate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Truck({
    required this.id,
    required this.registrationNumber,
    required this.vin,
    required this.make,
    required this.model,
    required this.year,
    required this.fleetNumber,
    required this.truckType,
    required this.palletCapacity,
    required this.fuelType,
    required this.currentOdometer,
    required this.serviceDueDate,
    required this.registrationExpiry,
    required this.insuranceExpiry,
    this.status = TruckStatus.available,
    this.currentDriverId,
    this.currentLatitude,
    this.currentLongitude,
    this.lastLocationUpdate,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAvailable => status == TruckStatus.available;
  bool get isRented => status == TruckStatus.rented;
  String get displayName => '$make $model ($registrationNumber)';

  Map<String, dynamic> toJson() => {
    'id': id,
    'registrationNumber': registrationNumber,
    'vin': vin,
    'make': make,
    'model': model,
    'year': year,
    'fleetNumber': fleetNumber,
    'truckType': truckType.name,
    'palletCapacity': palletCapacity,
    'fuelType': fuelType.name,
    'currentOdometer': currentOdometer,
    'serviceDueDate': serviceDueDate.toIso8601String(),
    'registrationExpiry': registrationExpiry.toIso8601String(),
    'insuranceExpiry': insuranceExpiry.toIso8601String(),
    'status': status.name,
    'currentDriverId': currentDriverId,
    'currentLatitude': currentLatitude,
    'currentLongitude': currentLongitude,
    'lastLocationUpdate': lastLocationUpdate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static String _asString(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static DateTime _asDateTime(dynamic v, {DateTime? fallback}) {
    final fb = fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (v == null) return fb;
    if (v is DateTime) return v;
    // Firestore Timestamp support (without importing cloud_firestore in model)
    try {
      final dynamic maybeTimestamp = v;
      final dynamic dateTime = maybeTimestamp.toDate?.call();
      if (dateTime is DateTime) return dateTime;
    } catch (_) {}
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final s = v.toString();
    return DateTime.tryParse(s) ?? fb;
  }

  static T _parseEnum<T extends Enum>(
    List<T> values,
    dynamic raw, {
    required T fallback,
    List<String> aliases = const [],
  }) {
    if (raw == null) return fallback;
    final s = raw.toString();
    for (final v in values) {
      if (v.name == s) return v;
    }
    // Some older data may store enums in different casing
    final sl = s.toLowerCase();
    for (final v in values) {
      if (v.name.toLowerCase() == sl) return v;
    }
    // Support custom aliases if needed.
    for (var i = 0; i < aliases.length; i += 2) {
      final from = aliases[i];
      final to = aliases[i + 1];
      if (sl == from.toLowerCase()) {
        for (final v in values) {
          if (v.name.toLowerCase() == to.toLowerCase()) return v;
        }
      }
    }
    return fallback;
  }

  /// Firestore documents can be created/edited externally, so this parser is
  /// intentionally tolerant. It supports legacy field names and missing values
  /// so the app doesn't fail to load all trucks.
  factory Truck.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    final rego = _asString(
      json['registrationNumber'] ?? json['rego'] ?? json['registration'] ?? json['plate'],
      fallback: '',
    );
    final make = _asString(json['make'], fallback: 'Truck');
    final model = _asString(json['model'], fallback: '');
    final fleetNumber = _asString(json['fleetNumber'] ?? json['fleet_no'] ?? json['fleet'], fallback: '');
    final vin = _asString(json['vin'] ?? json['VIN'], fallback: '');

    final createdAt = _asDateTime(json['createdAt'] ?? json['created_at'], fallback: now);
    final updatedAt = _asDateTime(json['updatedAt'] ?? json['updated_at'], fallback: createdAt);

    // Expiry/service dates: if missing, default to one year ahead to avoid
    // breaking UI.
    final serviceDueDate = _asDateTime(json['serviceDueDate'] ?? json['service_due_date'], fallback: now.add(const Duration(days: 365)));
    final registrationExpiry = _asDateTime(json['registrationExpiry'] ?? json['registration_expiry'], fallback: now.add(const Duration(days: 365)));
    final insuranceExpiry = _asDateTime(json['insuranceExpiry'] ?? json['insurance_expiry'], fallback: now.add(const Duration(days: 365)));

    final status = _parseEnum(
      TruckStatus.values,
      json['status'],
      fallback: TruckStatus.available,
      aliases: const [
        'in_service', 'inService',
        'under_repair', 'underRepair',
        'out_of_service', 'outOfService',
        'awaiting_pickup', 'awaitingPickup',
      ],
    );

    return Truck(
      id: _asString(json['id']),
      registrationNumber: rego,
      vin: vin,
      make: make,
      model: model,
      year: _asInt(json['year'], fallback: now.year),
      fleetNumber: fleetNumber,
      truckType: _parseEnum(TruckType.values, json['truckType'] ?? json['type'], fallback: TruckType.box),
      palletCapacity: _asInt(json['palletCapacity'] ?? json['pallet_capacity'], fallback: 0),
      fuelType: _parseEnum(FuelType.values, json['fuelType'], fallback: FuelType.diesel),
      currentOdometer: _asDouble(json['currentOdometer'] ?? json['odometer'], fallback: 0),
      serviceDueDate: serviceDueDate,
      registrationExpiry: registrationExpiry,
      insuranceExpiry: insuranceExpiry,
      status: status,
      currentDriverId: () {
        final v = json['currentDriverId'] ?? json['driverId'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      currentLatitude: json['currentLatitude'] == null ? null : _asDouble(json['currentLatitude']),
      currentLongitude: json['currentLongitude'] == null ? null : _asDouble(json['currentLongitude']),
      lastLocationUpdate: json['lastLocationUpdate'] == null ? null : _asDateTime(json['lastLocationUpdate']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Truck copyWith({
    String? id,
    String? registrationNumber,
    String? vin,
    String? make,
    String? model,
    int? year,
    String? fleetNumber,
    TruckType? truckType,
    int? palletCapacity,
    FuelType? fuelType,
    double? currentOdometer,
    DateTime? serviceDueDate,
    DateTime? registrationExpiry,
    DateTime? insuranceExpiry,
    TruckStatus? status,
    String? currentDriverId,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? lastLocationUpdate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Truck(
    id: id ?? this.id,
    registrationNumber: registrationNumber ?? this.registrationNumber,
    vin: vin ?? this.vin,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    fleetNumber: fleetNumber ?? this.fleetNumber,
    truckType: truckType ?? this.truckType,
    palletCapacity: palletCapacity ?? this.palletCapacity,
    fuelType: fuelType ?? this.fuelType,
    currentOdometer: currentOdometer ?? this.currentOdometer,
    serviceDueDate: serviceDueDate ?? this.serviceDueDate,
    registrationExpiry: registrationExpiry ?? this.registrationExpiry,
    insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
    status: status ?? this.status,
    currentDriverId: currentDriverId ?? this.currentDriverId,
    currentLatitude: currentLatitude ?? this.currentLatitude,
    currentLongitude: currentLongitude ?? this.currentLongitude,
    lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
