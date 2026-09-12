class ProviderAccount {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final double? hourlyRate;
  final String? bio;
  final List<String> categories;
  final bool isVerified;
  final DateTime? availableUntil;

  ProviderAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.hourlyRate,
    this.bio,
    required this.categories,
    required this.isVerified,
    this.availableUntil,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get needsProfileSetup => hourlyRate == null || categories.isEmpty;

  factory ProviderAccount.fromJson(Map<String, dynamic> json) {
    return ProviderAccount(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      categories: List<String>.from(json['categories'] as List? ?? const []),
      isVerified: json['is_verified_for_work'] as bool? ?? false,
      availableUntil: _parseDate(json['available_until']),
    );
  }
}

class ProviderBooking {
  final String id;
  final String customerName;
  final String? serviceCategory;
  final String? description;
  final String? address;
  final DateTime? scheduledFor;
  final int? durationMinutes;
  final double? price;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// The arrival time the provider gave the customer when accepting.
  final DateTime? estimatedArrivalAt;

  ProviderBooking({
    required this.id,
    required this.customerName,
    this.serviceCategory,
    this.description,
    this.address,
    this.scheduledFor,
    this.durationMinutes,
    this.price,
    this.createdAt,
    this.expiresAt,
    this.estimatedArrivalAt,
  });

  /// ASAP requests are scheduled for the moment they were sent.
  bool get isAsap =>
      scheduledFor != null &&
      createdAt != null &&
      scheduledFor!.difference(createdAt!).inMinutes.abs() < 2;

  factory ProviderBooking.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    final firstName = customer['first_name'] as String? ?? '';
    final lastName = customer['last_name'] as String? ?? '';
    final name = [
      if (firstName.isNotEmpty) firstName,
      if (lastName.isNotEmpty) '${lastName[0]}.',
    ].join(' ');

    return ProviderBooking(
      id: json['booking_id'] as String,
      customerName: name.isEmpty ? 'Customer' : name,
      serviceCategory: json['service_category'] as String?,
      description: json['description'] as String?,
      address: json['address'] as String?,
      scheduledFor: _parseDate(json['scheduled_for']),
      durationMinutes: (json['estimated_duration_minutes'] as num?)?.toInt(),
      price: (json['price'] as num?)?.toDouble(),
      createdAt: _parseDate(json['created_at']),
      expiresAt: _parseDate(json['expires_at']),
      estimatedArrivalAt: _parseDate(json['estimated_arrival_at']),
    );
  }

  /// When this job should be done: from the promised arrival (or requested time) plus its length.
  DateTime endsAt() {
    final start = estimatedArrivalAt ?? scheduledFor ?? DateTime.now();
    return start.add(Duration(minutes: durationMinutes ?? 60));
  }
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
