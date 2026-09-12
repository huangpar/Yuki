import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../models/provider_model.dart';

class CustomerMapScreen extends StatefulWidget {
  const CustomerMapScreen({super.key});

  @override
  State<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class _CustomerMapScreenState extends State<CustomerMapScreen> {
  late MapController mapController;
  LatLng? userLocation;
  List<ProviderStatus> nearbyProviders = [];
  bool isLoading = true;
  ProviderStatus? selectedProvider;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          _showError('Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
      });

      _fetchNearbyProviders();
    } catch (e) {
      _showError('Error getting location: $e');
    }
  }

  void _fetchNearbyProviders() {
    if (userLocation == null) return;

    final supabaseService = SupabaseService();
    supabaseService
        .watchNearbyProviders(userLocation!.longitude, userLocation!.latitude)
        .listen((providers) {
      setState(() {
        nearbyProviders = providers
            .map((p) => ProviderStatus.fromJson(p))
            .toList();
        isLoading = false;
      });
    });
  }

  void _showProviderDetails(ProviderStatus provider) {
    setState(() => selectedProvider = provider);
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildProviderDetailsSheet(provider),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Widget _buildProviderDetailsSheet(ProviderStatus provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${provider.firstName} ${provider.lastName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.distanceMeters != null
                          ? '${(provider.distanceMeters! / 1000).toStringAsFixed(1)} km away'
                          : 'Distance unknown',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    '${provider.firstName[0]}${provider.lastName[0]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _requestService(provider);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Request Service',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _requestService(ProviderStatus provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Service request sent to ${provider.firstName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Service'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userLocation == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Unable to determine location'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeLocation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    center: userLocation,
                    zoom: 15,
                    minZoom: 5,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.neighborhand',
                    ),
                    MarkerLayer(
                      markers: [
                        // User location marker
                        Marker(
                          point: userLocation!,
                          builder: (ctx) => const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                        // Provider markers
                        ...nearbyProviders.map(
                          (provider) => Marker(
                            point: provider.location ??
                                const LatLng(0, 0),
                            builder: (ctx) => GestureDetector(
                              onTap: () =>
                                  _showProviderDetails(provider),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color:
                                          Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (userLocation != null) {
            mapController.move(userLocation!, 15);
          }
        },
        tooltip: 'Center on my location',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
