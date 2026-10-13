/// The numbers on the admin overview: who's here, and how far work gets.
class AdminOverview {
  final String window;
  final int accounts;
  final int providers;
  final int verifiedProviders;
  final int availableNow;

  final int jobsPosted;
  final int offersMade;
  final int jobsAssigned;
  final int? matchRate;

  final int bookingsRequested;
  final int bookingsAccepted;
  final int bookingsCompleted;
  final int bookingsDeclined;
  final int? acceptanceRate;
  final int? completionRate;

  final int reviewsWritten;
  final int openTickets;
  final int newFeedback;

  AdminOverview({
    required this.window,
    required this.accounts,
    required this.providers,
    required this.verifiedProviders,
    required this.availableNow,
    required this.jobsPosted,
    required this.offersMade,
    required this.jobsAssigned,
    this.matchRate,
    required this.bookingsRequested,
    required this.bookingsAccepted,
    required this.bookingsCompleted,
    required this.bookingsDeclined,
    this.acceptanceRate,
    this.completionRate,
    required this.reviewsWritten,
    required this.openTickets,
    required this.newFeedback,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    final people = json['people'] as Map<String, dynamic>? ?? const {};
    final jobs = json['jobs'] as Map<String, dynamic>? ?? const {};
    final bookings = json['bookings'] as Map<String, dynamic>? ?? const {};
    final reviews = json['reviews'] as Map<String, dynamic>? ?? const {};
    final queue = json['queue'] as Map<String, dynamic>? ?? const {};
    int count(Map<String, dynamic> from, String key) => (from[key] as num?)?.toInt() ?? 0;

    return AdminOverview(
      window: json['window'] as String? ?? '30d',
      accounts: count(people, 'accounts'),
      providers: count(people, 'providers'),
      verifiedProviders: count(people, 'verified_providers'),
      availableNow: count(people, 'available_now'),
      jobsPosted: count(jobs, 'posted'),
      offersMade: count(jobs, 'offers_made'),
      jobsAssigned: count(jobs, 'assigned'),
      matchRate: (jobs['match_rate'] as num?)?.toInt(),
      bookingsRequested: count(bookings, 'requested'),
      bookingsAccepted: count(bookings, 'accepted'),
      bookingsCompleted: count(bookings, 'completed'),
      bookingsDeclined: count(bookings, 'declined'),
      acceptanceRate: (bookings['acceptance_rate'] as num?)?.toInt(),
      completionRate: (bookings['completion_rate'] as num?)?.toInt(),
      reviewsWritten: count(reviews, 'written'),
      openTickets: count(queue, 'open_tickets'),
      newFeedback: count(queue, 'new_feedback'),
    );
  }
}
