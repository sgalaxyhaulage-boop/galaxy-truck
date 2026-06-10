enum PaymentType { bond, damage, fuel, lateReturn, other }

enum PaymentStatus { pending, authorized, captured, failed, refunded }

class Payment {
  final String id;
  final String rentalId;
  final String driverId;
  final PaymentType paymentType;
  final double amount;
  final String cardLast4;
  final String cardholderName;
  final PaymentStatus status;
  final String? stripePaymentIntentId;
  final DateTime? authorizedAt;
  final DateTime? capturedAt;
  final DateTime? refundedAt;
  final String? failureReason;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.rentalId,
    required this.driverId,
    required this.paymentType,
    required this.amount,
    required this.cardLast4,
    required this.cardholderName,
    this.status = PaymentStatus.pending,
    this.stripePaymentIntentId,
    this.authorizedAt,
    this.capturedAt,
    this.refundedAt,
    this.failureReason,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'rentalId': rentalId,
    'driverId': driverId,
    'paymentType': paymentType.name,
    'amount': amount,
    'cardLast4': cardLast4,
    'cardholderName': cardholderName,
    'status': status.name,
    'stripePaymentIntentId': stripePaymentIntentId,
    'authorizedAt': authorizedAt?.toIso8601String(),
    'capturedAt': capturedAt?.toIso8601String(),
    'refundedAt': refundedAt?.toIso8601String(),
    'failureReason': failureReason,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'],
    rentalId: json['rentalId'],
    driverId: json['driverId'],
    paymentType: PaymentType.values.firstWhere((e) => e.name == json['paymentType']),
    amount: json['amount'].toDouble(),
    cardLast4: json['cardLast4'],
    cardholderName: json['cardholderName'],
    status: PaymentStatus.values.firstWhere((e) => e.name == json['status']),
    stripePaymentIntentId: json['stripePaymentIntentId'],
    authorizedAt: json['authorizedAt'] != null ? DateTime.parse(json['authorizedAt']) : null,
    capturedAt: json['capturedAt'] != null ? DateTime.parse(json['capturedAt']) : null,
    refundedAt: json['refundedAt'] != null ? DateTime.parse(json['refundedAt']) : null,
    failureReason: json['failureReason'],
    description: json['description'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  Payment copyWith({
    String? id,
    String? rentalId,
    String? driverId,
    PaymentType? paymentType,
    double? amount,
    String? cardLast4,
    String? cardholderName,
    PaymentStatus? status,
    String? stripePaymentIntentId,
    DateTime? authorizedAt,
    DateTime? capturedAt,
    DateTime? refundedAt,
    String? failureReason,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Payment(
    id: id ?? this.id,
    rentalId: rentalId ?? this.rentalId,
    driverId: driverId ?? this.driverId,
    paymentType: paymentType ?? this.paymentType,
    amount: amount ?? this.amount,
    cardLast4: cardLast4 ?? this.cardLast4,
    cardholderName: cardholderName ?? this.cardholderName,
    status: status ?? this.status,
    stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
    authorizedAt: authorizedAt ?? this.authorizedAt,
    capturedAt: capturedAt ?? this.capturedAt,
    refundedAt: refundedAt ?? this.refundedAt,
    failureReason: failureReason ?? this.failureReason,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
