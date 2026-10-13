/// Someone's report that a job or booking went wrong.
class SupportTicket {
  final String id;
  final String subjectType;
  final String? bookingId;
  final String? jobId;
  final String category;
  final String message;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  /// Who raised it. Only the admin view gets this.
  final String? reporterName;
  final String? reporterEmail;

  SupportTicket({
    required this.id,
    required this.subjectType,
    this.bookingId,
    this.jobId,
    required this.category,
    required this.message,
    required this.status,
    this.adminNote,
    this.createdAt,
    this.resolvedAt,
    this.reporterName,
    this.reporterEmail,
  });

  bool get isOpen => status == 'open' || status == 'in_progress';

  String get statusLabel => switch (status) {
        'open' => 'Open',
        'in_progress' => 'In progress',
        'resolved' => 'Resolved',
        'closed' => 'Closed',
        _ => status,
      };

  String get categoryLabel => switch (category) {
        'no_show' => 'No show',
        'quality' => 'Quality of work',
        'payment' => 'Payment',
        'safety' => 'Safety',
        'account' => 'Account',
        _ => 'Something else',
      };

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] as Map<String, dynamic>?;
    return SupportTicket(
      id: json['ticket_id'] as String,
      subjectType: json['subject_type'] as String? ?? 'other',
      bookingId: json['booking_id'] as String?,
      jobId: json['job_id'] as String?,
      category: json['category'] as String? ?? 'other',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      adminNote: json['admin_note'] as String?,
      createdAt: _parseDate(json['created_at']),
      resolvedAt: _parseDate(json['resolved_at']),
      reporterName: reporter?['name'] as String?,
      reporterEmail: reporter?['email'] as String?,
    );
  }
}

/// A note someone sent about Yuki itself, as the admin inbox sees it.
class FeedbackItem {
  final String id;
  final String category;
  final String message;
  final String? context;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;
  final String? fromName;
  final String? fromEmail;

  FeedbackItem({
    required this.id,
    required this.category,
    required this.message,
    this.context,
    required this.status,
    this.adminNote,
    this.createdAt,
    this.fromName,
    this.fromEmail,
  });

  String get categoryLabel => switch (category) {
        'idea' => 'Idea',
        'problem' => 'Problem',
        'praise' => 'Praise',
        _ => 'Other',
      };

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    final from = json['from'] as Map<String, dynamic>?;
    return FeedbackItem(
      id: json['feedback_id'] as String,
      category: json['category'] as String? ?? 'other',
      message: json['message'] as String? ?? '',
      context: json['context'] as String?,
      status: json['status'] as String? ?? 'new',
      adminNote: json['admin_note'] as String?,
      createdAt: _parseDate(json['created_at']),
      fromName: from?['name'] as String?,
      fromEmail: from?['email'] as String?,
    );
  }
}

/// A provider waiting on, or holding, approval to take work.
class AdminProvider {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final double? hourlyRate;
  final List<String> categories;
  final String? bio;
  final double? rating;
  final int reviewCount;
  final bool isVerified;

  AdminProvider({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.hourlyRate,
    required this.categories,
    this.bio,
    this.rating,
    required this.reviewCount,
    required this.isVerified,
  });

  factory AdminProvider.fromJson(Map<String, dynamic> json) {
    final first = json['first_name'] as String? ?? '';
    final last = json['last_name'] as String? ?? '';
    return AdminProvider(
      id: json['id'] as String,
      name: '$first $last'.trim().isEmpty ? 'No name yet' : '$first $last'.trim(),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      categories: List<String>.from(json['categories'] as List? ?? const []),
      bio: json['bio'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified_for_work'] as bool? ?? false,
    );
  }
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
