import 'package:latlong2/latlong.dart';

class ProviderStatus {
  final String id;
  final bool isAvailable;
  final LatLng? location;
  final String? stripeAccountId;
  final bool stripeOnboardingComplete;
  final String? checkrCandidateId;
  final String backgroundCheckStatus;
  final bool isVerifiedForWork;
  final DateTime lastHeartbeat;
  final String firstName;
  final String lastName;
  final double? distanceMeters;

  ProviderStatus({
    required this.id,
    required this.isAvailable,
    this.location,
    this.stripeAccountId,
    required this.stripeOnboardingComplete,
    this.checkrCandidateId,
    required this.backgroundCheckStatus,
    required this.isVerifiedForWork,
    required this.lastHeartbeat,
    required this.firstName,
    required this.lastName,
    this.distanceMeters,
  });

  factory ProviderStatus.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['location'] != null) {
      // Parse PostGIS point format: "POINT(lon lat)"
      final locationStr = json['location'].toString();
      final coords = locationStr
          .replaceAll('POINT(', '')
          .replaceAll(')', '')
          .trim()
          .split(' ');
      if (coords.length == 2) {
        location = LatLng(
          double.parse(coords[1]),
          double.parse(coords[0]),
        );
      }
    }

    return ProviderStatus(
      id: json['id'] as String,
      isAvailable: json['is_available'] as bool? ?? false,
      location: location,
      stripeAccountId: json['stripe_account_id'] as String?,
      stripeOnboardingComplete:
          json['stripe_onboarding_complete'] as bool? ?? false,
      checkrCandidateId: json['checkr_candidate_id'] as String?,
      backgroundCheckStatus:
          json['background_check_status'] as String? ?? 'not_started',
      isVerifiedForWork: json['is_verified_for_work'] as bool? ?? false,
      lastHeartbeat:
          DateTime.parse(json['last_heartbeat'] as String? ?? DateTime.now().toIso8601String()),
      firstName: json['first_name'] as String? ?? 'Unknown',
      lastName: json['last_name'] as String? ?? 'Unknown',
      distanceMeters: json['distance_meters'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_available': isAvailable,
      'location': location != null
          ? 'POINT(${location!.longitude} ${location!.latitude})'
          : null,
      'stripe_account_id': stripeAccountId,
      'stripe_onboarding_complete': stripeOnboardingComplete,
      'checkr_candidate_id': checkrCandidateId,
      'background_check_status': backgroundCheckStatus,
      'is_verified_for_work': isVerifiedForWork,
      'last_heartbeat': lastHeartbeat.toIso8601String(),
    };
  }
}
