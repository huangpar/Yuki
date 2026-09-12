import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_booking.dart';
import '../models/my_profile.dart';
import '../models/nearby_provider_model.dart';
import '../models/provider_account.dart';

class ApiException implements Exception {
  final int statusCode;
  final String? code;
  final String message;

  ApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => message;
}

class SupabaseService {
  static const _apiBase = 'http://localhost:3000/api';

  static final SupabaseService _instance = SupabaseService._internal();
  late SupabaseClient _client;
  late String _supabaseUrl;
  late String _anonKey;

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  Future<void> initialize(String url, String anonKey) async {
    _supabaseUrl = url;
    _anonKey = anonKey;
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _client = Supabase.instance.client;
  }

  SupabaseClient get client => _client;

  // Where OAuth and email links send people back to (web only; mobile will use a deep link).
  String? get _returnUrl => kIsWeb ? '${Uri.base.origin}/' : null;

  // Auth Methods
  /// Emails or texts a one-time code. Creates the account if it's new.
  Future<void> sendSignInCode({String? email, String? phone}) async {
    await _client.auth.signInWithOtp(
      email: email,
      phone: phone,
      shouldCreateUser: true,
      emailRedirectTo: email != null ? _returnUrl : null,
    );
  }

  Future<void> verifySignInCode({String? email, String? phone, required String code}) async {
    await _client.auth.verifyOTP(
      email: email,
      phone: phone,
      token: code,
      type: email != null ? OtpType.email : OtpType.sms,
    );
  }

  /// Leaves the app for the provider's sign-in page; it returns here signed in.
  Future<void> signInWithProvider(OAuthProvider provider) async {
    await _client.auth.signInWithOAuth(provider, redirectTo: _returnUrl);
  }

  /// Sign-in methods switched on in the Supabase dashboard, e.g. {'email', 'google'}.
  Future<Set<String>> enabledSignInMethods() async {
    final response = await http.get(
      Uri.parse('$_supabaseUrl/auth/v1/settings'),
      headers: {'apikey': _anonKey},
    );
    final settings = jsonDecode(response.body) as Map<String, dynamic>;
    final external = settings['external'] as Map<String, dynamic>? ?? const {};
    return {
      for (final entry in external.entries)
        if (entry.value == true) entry.key,
    };
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<AuthChangeEvent> get authEvents =>
      _client.auth.onAuthStateChange.map((state) => state.event);

  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Which side of the app the user last used: 'customer' or 'provider'.
  String get preferredView =>
      _client.auth.currentUser?.userMetadata?['view'] == 'provider' ? 'provider' : 'customer';

  Future<void> setPreferredView(String view) async {
    if (_client.auth.currentUser == null) return;
    await _client.auth.updateUser(UserAttributes(data: {'view': view}));
  }

  // Real-time Provider Updates
  Stream<List<Map<String, dynamic>>> watchNearbyProviders(
    double longitude,
    double latitude,
  ) {
    return _client
        .rpc(
          'get_nearby_providers',
          params: {
            'client_long': longitude,
            'client_lat': latitude,
          },
        )
        .asStream()
        .map((data) => List<Map<String, dynamic>>.from(data ?? []));
  }

  // Get Provider Status
  Future<Map<String, dynamic>?> getProviderStatus(String providerId) async {
    final response = await _client
        .from('provider_statuses')
        .select()
        .eq('id', providerId)
        .single();
    return response;
  }

  // Get User Profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  // Real-time Subscription to Provider Status Changes
  RealtimeChannel subscribeToProviderStatus(String providerId) {
    return _client
        .channel('provider:$providerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'provider_statuses',
          callback: (payload) {
            // Payload contains the changed data
          },
        )
        .subscribe();
  }

  // Fetch nearby providers from backend API
  Future<NearbyProvidersResponse> fetchNearbyProviders({
    required double latitude,
    required double longitude,
    double? radius,
    String? category,
  }) async {
    try {
      // Build query parameters
      final queryParams = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        if (radius != null) 'radius': radius.toString(),
        if (category != null) 'category': category,
      };

      final uri = Uri.parse('$_apiBase/customers/nearby-providers')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return NearbyProvidersResponse.fromJson(json);
      } else {
        throw Exception('Failed to fetch nearby providers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching nearby providers: $e');
    }
  }

  // Subscribe to real-time provider updates
  void subscribeToProviderUpdates({
    required Function(List<NearbyProvider>) onUpdate,
    required Function(dynamic) onError,
  }) {
    _client
        .channel('provider_locations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'provider_statuses',
          callback: (payload) {
            // Fetch updated provider list on any change
            // In production, we'd handle this more efficiently
            onUpdate([]);
          },
        )
        .subscribe();
  }

  // Backend API
  Map<String, String> get _headers {
    final token = _client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _request(String method, String path, [Map<String, dynamic>? body]) async {
    final request = http.Request(method, Uri.parse('$_apiBase$path'))..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    final response = await http.Response.fromStream(await request.send());
    final data = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode >= 400) {
      final error = data is Map<String, dynamic> ? data : const <String, dynamic>{};
      throw ApiException(
        response.statusCode,
        error['error'] as String?,
        error['message'] as String? ?? 'Something went wrong. Please try again.',
      );
    }
    return data;
  }

  // The API's date validator rejects fractional seconds.
  static String _isoSeconds(DateTime time) =>
      '${time.toUtc().toIso8601String().substring(0, 19)}Z';

  // Account API
  Future<MyProfile> getMyProfile() async {
    final data = await _request('GET', '/me');
    return MyProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<MyProfile> completeProfile({
    required String firstName,
    required String lastName,
    required String phone,
    required bool offerServices,
  }) async {
    final data = await _request('PUT', '/me', {
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'offer_services': offerServices,
    });
    return MyProfile.fromJson(data as Map<String, dynamic>);
  }

  // Customer API
  /// Pass no [scheduledFor] for an ASAP request.
  Future<CustomerBooking> createBooking({
    required String providerId,
    required String serviceCategory,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required int durationMinutes,
    DateTime? scheduledFor,
  }) async {
    final data = await _request('POST', '/bookings', {
      'provider_id': providerId,
      'service_category': serviceCategory,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'estimated_duration_minutes': durationMinutes,
      if (scheduledFor == null) 'asap': true else 'scheduled_for': _isoSeconds(scheduledFor),
    }) as Map<String, dynamic>;
    return CustomerBooking.fromJson(data);
  }

  Future<CustomerBooking> getBooking(String bookingId) async {
    final data = await _request('GET', '/bookings/$bookingId') as Map<String, dynamic>;
    return CustomerBooking.fromJson(data);
  }

  Future<List<CustomerBooking>> getMyBookings() async {
    final data = await _request('GET', '/bookings/customers/bookings') as Map<String, dynamic>;
    return (data['bookings'] as List)
        .map((b) => CustomerBooking.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  // Provider API
  Future<void> enableProviderProfile() async {
    await _request('POST', '/providers/enable', {});
  }

  Future<ProviderAccount> getProviderAccount() async {
    final data = await _request('GET', '/providers/me');
    return ProviderAccount.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateProviderProfile({
    required double hourlyRate,
    required List<String> categories,
    required String bio,
  }) async {
    await _request('PUT', '/providers/profile', {
      'hourly_rate': hourlyRate,
      'categories': categories,
      'bio': bio,
    });
  }

  /// Returns when the availability window ends, or null when going offline.
  Future<DateTime?> setProviderAvailability({
    required bool available,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _request('POST', '/providers/availability/toggle', {
      'available': available,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    }) as Map<String, dynamic>;
    final expiresAt = data['expires_at'] as String?;
    return expiresAt == null ? null : DateTime.parse(expiresAt).toLocal();
  }

  Future<void> sendProviderLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _request('POST', '/providers/availability/update-location', {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<List<ProviderBooking>> getProviderBookings(String status) async {
    final data = await _request('GET', '/bookings/providers/bookings?status=$status')
        as Map<String, dynamic>;
    return (data['bookings'] as List)
        .map((b) => ProviderBooking.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptBooking(String bookingId, {required DateTime arrivingAt}) async {
    await _request('POST', '/bookings/$bookingId/accept', {
      'estimated_arrival_at': _isoSeconds(arrivingAt),
    });
  }

  Future<void> declineBooking(String bookingId) async {
    await _request('POST', '/bookings/$bookingId/decline', {});
  }

  static SupabaseService get instance => _instance;
}
