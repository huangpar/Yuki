class NearbyProvider {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final double hourlyRate;
  final String bio;
  final List<String> categories;
  final double latitude;
  final double longitude;
  final double distanceMiles;
  final bool availableNow;
  final double? rating;
  final int? reviewCount;

  NearbyProvider({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.hourlyRate,
    required this.bio,
    required this.categories,
    required this.latitude,
    required this.longitude,
    required this.distanceMiles,
    required this.availableNow,
    this.rating,
    this.reviewCount,
  });

  String get fullName => '$firstName $lastName';

  factory NearbyProvider.fromJson(Map<String, dynamic> json) {
    return NearbyProvider(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      hourlyRate: (json['hourly_rate'] as num).toDouble(),
      bio: json['bio'] as String? ?? '',
      categories: List<String>.from(json['categories'] as List? ?? []),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceMiles: (json['distance_miles'] as num).toDouble(),
      availableNow: json['available_now'] as bool? ?? true,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      reviewCount: json['review_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'hourly_rate': hourlyRate,
      'bio': bio,
      'categories': categories,
      'latitude': latitude,
      'longitude': longitude,
      'distance_miles': distanceMiles,
      'available_now': availableNow,
      'rating': rating,
      'review_count': reviewCount,
    };
  }
}

class NearbyProvidersResponse {
  final List<NearbyProvider> providers;
  final int count;
  final SearchCenter searchCenter;

  NearbyProvidersResponse({
    required this.providers,
    required this.count,
    required this.searchCenter,
  });

  factory NearbyProvidersResponse.fromJson(Map<String, dynamic> json) {
    return NearbyProvidersResponse(
      providers: (json['providers'] as List)
          .map((p) => NearbyProvider.fromJson(p as Map<String, dynamic>))
          .toList(),
      count: json['count'] as int,
      searchCenter: SearchCenter.fromJson(json['search_center'] as Map<String, dynamic>),
    );
  }
}

class SearchCenter {
  final double latitude;
  final double longitude;
  final int radiusMiles;

  SearchCenter({
    required this.latitude,
    required this.longitude,
    required this.radiusMiles,
  });

  factory SearchCenter.fromJson(Map<String, dynamic> json) {
    return SearchCenter(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMiles: json['radius_miles'] as int,
    );
  }
}
