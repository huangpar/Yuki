/// A job a customer posted, with the price they're willing to pay.
class JobPost {
  final String id;
  final String? serviceCategory;
  final String description;
  final String address;
  final bool asap;
  final DateTime? scheduledFor;
  final int durationMinutes;
  final double offeredPrice;
  final String status; // open, assigned, cancelled, expired
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// Signed URLs, good for an hour from when the list was loaded.
  final List<String> photos;
  final double? distanceMiles;
  final int offerCount;
  final JobOffer? myOffer;
  final List<JobOffer> offers;

  JobPost({
    required this.id,
    this.serviceCategory,
    required this.description,
    required this.address,
    required this.asap,
    this.scheduledFor,
    required this.durationMinutes,
    required this.offeredPrice,
    required this.status,
    this.createdAt,
    this.expiresAt,
    this.photos = const [],
    this.distanceMiles,
    this.offerCount = 0,
    this.myOffer,
    this.offers = const [],
  });

  bool get isOpen => status == 'open';

  List<JobOffer> get pendingOffers =>
      offers.where((o) => o.status == 'pending').toList();

  JobOffer? get acceptedOffer {
    for (final offer in offers) {
      if (offer.status == 'accepted') return offer;
    }
    return null;
  }

  String get statusLabel => switch (status) {
        'open' => 'Open',
        'assigned' => 'Booked',
        'cancelled' => 'Cancelled',
        'expired' => 'Closed',
        _ => status,
      };

  factory JobPost.fromJson(Map<String, dynamic> json) {
    return JobPost(
      id: json['job_id'] as String,
      serviceCategory: json['service_category'] as String?,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      asap: json['asap'] as bool? ?? false,
      scheduledFor: _parseDate(json['scheduled_for']),
      durationMinutes: (json['estimated_duration_minutes'] as num?)?.toInt() ?? 60,
      offeredPrice: (json['offered_price'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'open',
      createdAt: _parseDate(json['created_at']),
      expiresAt: _parseDate(json['expires_at']),
      photos: List<String>.from(json['photos'] as List? ?? const []),
      distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
      offerCount: (json['offer_count'] as num?)?.toInt() ?? 0,
      myOffer: json['my_offer'] == null
          ? null
          : JobOffer.fromJson(json['my_offer'] as Map<String, dynamic>),
      offers: ((json['offers'] as List?) ?? const [])
          .map((o) => JobOffer.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// What a provider offered on a job: the customer's price, a flat rate, or an hourly rate.
class JobOffer {
  final String id;
  final String providerName;
  final String? providerBio;
  final double? providerHourlyRate;
  final String rateType; // listed, flat, hourly
  final double amount;
  final double totalPrice;
  final String? message;
  final String status; // pending, accepted, declined, withdrawn
  final DateTime? createdAt;

  JobOffer({
    required this.id,
    required this.providerName,
    this.providerBio,
    this.providerHourlyRate,
    required this.rateType,
    required this.amount,
    required this.totalPrice,
    this.message,
    required this.status,
    this.createdAt,
  });

  bool get isHourly => rateType == 'hourly';

  bool get matchesAsking => rateType == 'listed';

  /// "Your price", "$120 for the job", or "$40/hr".
  String get rateLabel => switch (rateType) {
        'listed' => 'Your asking price',
        'hourly' => '\$${_money(amount)}/hr',
        _ => '\$${_money(amount)} for the job',
      };

  factory JobOffer.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] as Map<String, dynamic>? ?? const {};
    final first = provider['first_name'] as String? ?? '';
    final last = provider['last_name'] as String? ?? '';
    final name = [
      if (first.isNotEmpty) first,
      if (last.isNotEmpty) '${last[0]}.',
    ].join(' ');

    return JobOffer(
      id: json['offer_id'] as String,
      providerName: name.isEmpty ? 'Provider' : name,
      providerBio: provider['bio'] as String?,
      providerHourlyRate: (provider['hourly_rate'] as num?)?.toDouble(),
      rateType: json['rate_type'] as String? ?? 'listed',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: _parseDate(json['created_at']),
    );
  }
}

String _money(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
