import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/service_categories.dart';
import '../theme/app_theme.dart';
import '../models/nearby_provider_model.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';
import 'dart:async';

/// Leaves the provider side for the customer map, and remembers that choice for next launch.
void openCustomerView(BuildContext context) {
  final service = SupabaseService.instance;
  if (service.preferredView != 'customer') {
    unawaited(service.setPreferredView('customer').catchError((_) {}));
  }
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (_) => false,
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late MapController _mapController;
  Position? _currentLocation;
  List<NearbyProvider> _providers = [];
  bool _loading = true;
  String? _error;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationDenied = true;
            _loading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationDenied = true;
          _loading = false;
        });
        return;
      }

      // Get current location
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = position;
      });

      // Fetch nearby providers
      await _fetchNearbyProviders();

      // Subscribe to real-time updates
      _subscribeToProviderUpdates();
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _fetchNearbyProviders() async {
    if (_currentLocation == null) return;

    try {
      setState(() => _loading = true);

      final response = await SupabaseService.instance.fetchNearbyProviders(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radius: 5,
      );

      setState(() {
        final myId = SupabaseService.instance.getCurrentUser()?.id;
        _providers = response.providers.where((p) => p.id != myId).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load providers: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _subscribeToProviderUpdates() {
    // Subscribe to real-time provider status changes
    SupabaseService.instance.subscribeToProviderUpdates(
      onUpdate: (updatedProviders) {
        setState(() {
          _providers = updatedProviders;
        });
      },
      onError: (error) {
        print('Real-time subscription error: $error');
      },
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _showProviderDetails(NearbyProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ProviderDetailsSheet(provider: provider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.lg),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('YUKI', style: AppTypography.h3),
            SizedBox(width: AppSpacing.sm),
            Text('🏠', style: TextStyle(fontSize: 20)),
          ],
        ),
        elevation: 0,
        actions: const [
          AccountActions(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_locationDenied) {
      return _buildLocationDeniedView();
    }

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_providers.isEmpty) {
      return _buildNoProvidersView();
    }

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(
              _currentLocation?.latitude ?? 0,
              _currentLocation?.longitude ?? 0,
            ),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            MarkerLayer(
              markers: [
                // Current location marker
                if (_currentLocation != null)
                  Marker(
                    width: 40,
                    height: 40,
                    point: LatLng(
                      _currentLocation!.latitude,
                      _currentLocation!.longitude,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textInverse,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.textInverse,
                        size: 20,
                      ),
                    ),
                  ),
                // Provider markers
                ..._providers.map(
                  (provider) => Marker(
                    width: 50,
                    height: 50,
                    point: LatLng(provider.latitude, provider.longitude),
                    child: GestureDetector(
                      onTap: () => _showProviderDetails(provider),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.textInverse,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowMedium,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            provider.firstName[0],
                            style: TextStyle(
                              color: AppColors.textInverse,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Providers list (bottom sheet preview)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.lg),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowMedium,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Nearby Providers (${_providers.length})',
                    style: AppTypography.h3,
                  ),
                ),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: _providers.length,
                    itemBuilder: (context, index) {
                      final provider = _providers[index];
                      return ProviderCard(
                        provider: provider,
                        onTap: () => _showProviderDetails(provider),
                      );
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDeniedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: AppColors.textSecondary),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Location Permission Denied',
            style: AppTypography.h2,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'We need your location to show nearby providers.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Error',
            style: AppTypography.h2,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              _error ?? 'Something went wrong',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () {
              setState(() => _loading = true);
              _initializeLocation();
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProvidersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_city, size: 64, color: AppColors.textSecondary),
          SizedBox(height: AppSpacing.lg),
          Text(
            'No Providers Yet',
            style: AppTypography.h2,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Yuki is coming to your neighborhood soon. Request access to be notified.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _showRequestNeighborhoodDialog(),
            icon: Icon(Icons.notifications_active),
            label: Text('Request This Neighborhood'),
          ),
        ],
      ),
    );
  }

  void _showRequestNeighborhoodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request This Neighborhood'),
        content: Text(
          'We\'ll notify you when providers become available in your area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement neighborhood request
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Thank you! We\'ll be in touch.')),
              );
            },
            child: Text('Request'),
          ),
        ],
      ),
    );
  }
}

class ProviderCard extends StatelessWidget {
  final NearbyProvider provider;
  final VoidCallback onTap;

  const ProviderCard({
    required this.provider,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.only(right: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: SizedBox(
          width: 140,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.fullName,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '${provider.distanceMiles.toStringAsFixed(1)} mi away',
                  style: AppTypography.caption,
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  provider.categories.map(categoryLabel).join(', '),
                  style: AppTypography.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  '\$${provider.hourlyRate.toStringAsFixed(0)}/hr',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProviderDetailsSheet extends StatelessWidget {
  final NearbyProvider provider;

  const ProviderDetailsSheet({
    required this.provider,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    provider.firstName[0],
                    style: TextStyle(
                      color: AppColors.textInverse,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.fullName,
                      style: AppTypography.h3,
                    ),
                    Text(
                      '${provider.distanceMiles.toStringAsFixed(1)} mi away',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          // Rate
          Row(
            children: [
              Icon(Icons.attach_money, color: AppColors.primary, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text(
                '\$${provider.hourlyRate.toStringAsFixed(2)}/hour',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),

          // Categories
          Wrap(
            spacing: AppSpacing.sm,
            children: provider.categories
                .map((cat) => Chip(
                      label: Text(
                        categoryLabel(cat),
                        style: AppTypography.caption,
                      ),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                    ))
                .toList(),
          ),
          SizedBox(height: AppSpacing.md),

          // Bio
          if (provider.bio.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: AppSpacing.sm),
                Text(provider.bio, style: AppTypography.bodySmall),
                SizedBox(height: AppSpacing.md),
              ],
            ),

          // CTA Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openBookingFlow(context, provider);
                  },
                  child: Text('Book Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
