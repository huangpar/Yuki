class MyProfile {
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final bool isProvider;

  MyProfile({
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    required this.isProvider,
  });

  /// Google and Apple sign-ins arrive without a phone number, and Apple may omit the name.
  bool get isComplete => firstName.isNotEmpty && (phone?.isNotEmpty ?? false);

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isProvider: json['is_provider'] as bool? ?? false,
    );
  }
}
