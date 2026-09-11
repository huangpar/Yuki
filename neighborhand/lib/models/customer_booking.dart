class CustomerBooking {
  final String id;
  final String status;
  final String? providerName;
  final String? serviceCategory;
  final String? address;
  final DateTime? scheduledFor;
  final int? durationMinutes;
  final double? price;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  CustomerBooking({
    required this.id,
    required this.status,
    this.providerName,
    this.serviceCategory,
    this.address,
    this.scheduledFor,
    this.durationMinutes,
    this.price,
    this.createdAt,
    this.expiresAt,
  });

  bool get isPending => status == 'pending_acceptance';

  bool get isExpired =>
      isPending && expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  /// Still inside the provider's 10-minute window to respond.
  bool get isWaiting => isPending && !isExpired;

  /// ASAP requests are scheduled for the moment they were sent.
  bool get isAsap =>
      scheduledFor != null &&
      createdAt != null &&
      scheduledFor!.difference(createdAt!).inMinutes.abs() < 2;

  String get statusLabel {
    if (isExpired) return 'No response';
    return switch (status) {
      'pending_acceptance' => 'Waiting',
      'accepted' => 'Accepted',
      'declined' => 'Declined',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };
  }

  factory CustomerBooking.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>?;
    return CustomerBooking(
      id: json['booking_id'] as String,
      status: json['status'] as String,
      providerName: provider?['first_name'] as String?,
      serviceCategory: json['service_category'] as String?,
      address: json['address'] as String?,
      scheduledFor: _parseDate(json['scheduled_for']),
      durationMinutes: (json['estimated_duration_minutes'] as num?)?.toInt(),
      price: (json['price'] as num?)?.toDouble(),
      createdAt: _parseDate(json['created_at']),
      expiresAt: _parseDate(json['expires_at']),
    );
  }
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
