/// One address the geocoder offered while someone was typing.
class AddressSuggestion {
  final String label;
  final double latitude;
  final double longitude;

  AddressSuggestion({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      label: json['label'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
