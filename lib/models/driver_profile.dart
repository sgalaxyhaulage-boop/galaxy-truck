enum ApprovalStatus { pending, approved, rejected }

enum LicenceClass { classA, classB, classC, classD, classE }

class DriverProfile {
  final String id;
  final String userId;
  final String fullName;
  final DateTime dateOfBirth;
  final String address;
  final String mobileNumber;
  final String email;
  final String? companyName;
  final String licenceNumber;
  final LicenceClass licenceClass;
  final DateTime licenceExpiry;
  final String? licenceFrontPath;
  final String? licenceBackPath;
  final String? proofOfAddressPath;
  final String? driverPhotoPath;
  final ApprovalStatus approvalStatus;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.dateOfBirth,
    required this.address,
    required this.mobileNumber,
    required this.email,
    this.companyName,
    required this.licenceNumber,
    required this.licenceClass,
    required this.licenceExpiry,
    this.licenceFrontPath,
    this.licenceBackPath,
    this.proofOfAddressPath,
    this.driverPhotoPath,
    this.approvalStatus = ApprovalStatus.pending,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => approvalStatus == ApprovalStatus.approved;
  bool get isPending => approvalStatus == ApprovalStatus.pending;
  bool get isDocumentsComplete => licenceFrontPath != null && licenceBackPath != null && proofOfAddressPath != null && driverPhotoPath != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'fullName': fullName,
    'dateOfBirth': dateOfBirth.toIso8601String(),
    'address': address,
    'mobileNumber': mobileNumber,
    'email': email,
    'companyName': companyName,
    'licenceNumber': licenceNumber,
    'licenceClass': licenceClass.name,
    'licenceExpiry': licenceExpiry.toIso8601String(),
    'licenceFrontPath': licenceFrontPath,
    'licenceBackPath': licenceBackPath,
    'proofOfAddressPath': proofOfAddressPath,
    'driverPhotoPath': driverPhotoPath,
    'approvalStatus': approvalStatus.name,
    'rejectionReason': rejectionReason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
    id: json['id'],
    userId: json['userId'],
    fullName: json['fullName'],
    dateOfBirth: DateTime.parse(json['dateOfBirth']),
    address: json['address'],
    mobileNumber: json['mobileNumber'],
    email: json['email'],
    companyName: json['companyName'],
    licenceNumber: json['licenceNumber'],
    licenceClass: LicenceClass.values.firstWhere((e) => e.name == json['licenceClass']),
    licenceExpiry: DateTime.parse(json['licenceExpiry']),
    licenceFrontPath: json['licenceFrontPath'],
    licenceBackPath: json['licenceBackPath'],
    proofOfAddressPath: json['proofOfAddressPath'],
    driverPhotoPath: json['driverPhotoPath'],
    approvalStatus: ApprovalStatus.values.firstWhere((e) => e.name == json['approvalStatus']),
    rejectionReason: json['rejectionReason'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  DriverProfile copyWith({
    String? id,
    String? userId,
    String? fullName,
    DateTime? dateOfBirth,
    String? address,
    String? mobileNumber,
    String? email,
    String? companyName,
    String? licenceNumber,
    LicenceClass? licenceClass,
    DateTime? licenceExpiry,
    String? licenceFrontPath,
    String? licenceBackPath,
    String? proofOfAddressPath,
    String? driverPhotoPath,
    ApprovalStatus? approvalStatus,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DriverProfile(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    fullName: fullName ?? this.fullName,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    address: address ?? this.address,
    mobileNumber: mobileNumber ?? this.mobileNumber,
    email: email ?? this.email,
    companyName: companyName ?? this.companyName,
    licenceNumber: licenceNumber ?? this.licenceNumber,
    licenceClass: licenceClass ?? this.licenceClass,
    licenceExpiry: licenceExpiry ?? this.licenceExpiry,
    licenceFrontPath: licenceFrontPath ?? this.licenceFrontPath,
    licenceBackPath: licenceBackPath ?? this.licenceBackPath,
    proofOfAddressPath: proofOfAddressPath ?? this.proofOfAddressPath,
    driverPhotoPath: driverPhotoPath ?? this.driverPhotoPath,
    approvalStatus: approvalStatus ?? this.approvalStatus,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
