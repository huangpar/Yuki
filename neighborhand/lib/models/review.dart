/// One review someone wrote about a provider or a customer.
class Review {
  final String id;
  final String bookingId;
  final String reviewerName;
  final String reviewerRole;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.reviewerName,
    required this.reviewerRole,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  bool get fromCustomer => reviewerRole == 'customer';

  factory Review.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;
    return Review(
      id: json['review_id'] as String,
      bookingId: json['booking_id'] as String,
      reviewerName: json['reviewer_name'] as String? ?? 'Someone',
      reviewerRole: json['reviewer_role'] as String? ?? 'customer',
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: createdAt == null ? null : DateTime.parse(createdAt).toLocal(),
    );
  }
}

/// Everything shown on someone's reviews page: the in-app reviews plus,
/// if they listed one, a link to their reviews elsewhere.
class ReviewSummary {
  final List<Review> reviews;
  final double? rating;
  final int reviewCount;
  final String? externalReviewsUrl;

  ReviewSummary({
    required this.reviews,
    this.rating,
    required this.reviewCount,
    this.externalReviewsUrl,
  });

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    return ReviewSummary(
      reviews: (json['reviews'] as List? ?? const [])
          .map((r) => Review.fromJson(r as Map<String, dynamic>))
          .toList(),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      externalReviewsUrl: json['external_reviews_url'] as String?,
    );
  }
}
