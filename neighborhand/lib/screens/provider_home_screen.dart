import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/service_categories.dart';
import '../models/provider_account.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'provider_profile_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  static const _locationInterval = Duration(seconds: 60);
  static const _bookingsInterval = Duration(seconds: 15);

  final _api = SupabaseService.instance;

  ProviderAccount? _account;
  DateTime? _availableUntil;
  List<ProviderBooking> _requests = [];
  List<ProviderBooking> _upcoming = [];
  String? _loadError;
  bool _needsProviderProfile = false;
  bool _enablingProvider = false;
  bool _changingAvailability = false;
  final Set<String> _responding = {};

  Timer? _clock;
  Timer? _bookingsTimer;
  Timer? _locationTimer;

  bool get _isAvailable => _availableUntil?.isAfter(DateTime.now()) ?? false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _bookingsTimer = Timer.periodic(_bookingsInterval, (_) => _loadBookings());
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _bookingsTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadError != null || _needsProviderProfile) {
      setState(() {
        _loadError = null;
        _needsProviderProfile = false;
      });
    }
    try {
      var account = await _api.getProviderAccount();
      if (account.needsProfileSetup) {
        if (!mounted) return;
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ProviderProfileScreen(account: account, isFirstSetup: true),
          ),
        );
        if (saved != true) {
          if (mounted) setState(() => _loadError = 'Finish setting up your profile to continue.');
          return;
        }
        account = await _api.getProviderAccount();
      }
      if (!mounted) return;
      setState(() {
        _account = account;
        _availableUntil = account.availableUntil;
      });
      _syncLocationUpdates();
      await _loadBookings();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'not_a_provider') {
          _needsProviderProfile = true;
        } else {
          _loadError = e.message;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Could not reach Yuki. Check your connection and try again.');
      }
    }
  }

  Future<void> _enableProviderProfile() async {
    setState(() => _enablingProvider = true);
    try {
      await _api.enableProviderProfile();
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not set up your provider profile. Try again.');
    } finally {
      if (mounted) setState(() => _enablingProvider = false);
    }
  }

  Future<void> _loadBookings() async {
    if (_account == null) return;
    try {
      final results = await Future.wait([
        _api.getProviderBookings('pending_acceptance'),
        _api.getProviderBookings('accepted'),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0];
        _upcoming = results[1];
      });
    } catch (_) {
      // Transient; the next poll retries.
    }
  }

  void _onTick() {
    if (!mounted) return;
    final until = _availableUntil;
    if (until != null && !until.isAfter(DateTime.now())) {
      _setAvailableUntil(null);
      _showMessage('Your 30 minutes are up. Go available again to keep getting requests.');
    } else if (until != null || _requests.isNotEmpty) {
      setState(() {});
    }
  }

  void _setAvailableUntil(DateTime? until) {
    setState(() => _availableUntil = until);
    _syncLocationUpdates();
  }

  void _syncLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer =
        _isAvailable ? Timer.periodic(_locationInterval, (_) => _sendLocation()) : null;
  }

  Future<void> _sendLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      await _api.sendProviderLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on ApiException catch (e) {
      if ((e.code == 'availability_expired' || e.code == 'not_online') && mounted) {
        _setAvailableUntil(null);
      }
    } catch (_) {
      // GPS hiccup; the next heartbeat retries.
    }
  }

  Future<Position?> _currentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition();
  }

  Future<void> _changeAvailability({required bool available}) async {
    setState(() => _changingAvailability = true);
    try {
      double? latitude;
      double? longitude;
      if (available) {
        final position = await _currentPosition();
        if (position == null) {
          _showMessage(
            'Yuki needs your location to show you on the map. Allow location access and try again.',
          );
          return;
        }
        latitude = position.latitude;
        longitude = position.longitude;
      }
      final until = await _api.setProviderAvailability(
        available: available,
        latitude: latitude,
        longitude: longitude,
      );
      if (mounted) _setAvailableUntil(until);
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not update your availability. Try again.');
    } finally {
      if (mounted) setState(() => _changingAvailability = false);
    }
  }

  Future<void> _respond(ProviderBooking request, {required bool accept}) async {
    setState(() => _responding.add(request.id));
    try {
      if (accept) {
        await _api.acceptBooking(request.id);
      } else {
        await _api.declineBooking(request.id);
      }
      if (!mounted) return;
      setState(() => _requests.removeWhere((r) => r.id == request.id));
      _showMessage(accept ? 'Request accepted.' : 'Request declined.');
      if (accept) _loadBookings();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        setState(() => _requests.removeWhere((r) => r.id == request.id));
        _showMessage('That request is no longer available.');
      } else {
        _showMessage(e.message);
      }
    } catch (_) {
      _showMessage('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _responding.remove(request.id));
    }
  }

  Future<void> _editProfile() async {
    final account = _account;
    if (account == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProviderProfileScreen(account: account)),
    );
    if (saved == true) _load();
  }

  void _switchToCustomerView() {
    unawaited(_api.setPreferredView('customer').catchError((_) {}));
    if (_isAvailable) {
      _showMessage('You stay on the map until your availability timer runs out.');
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _signOut() async {
    if (_isAvailable) {
      try {
        await _api.setProviderAvailability(available: false);
      } catch (_) {
        // Signing out anyway; the 30-minute window still takes them off the map.
      }
    }
    await _api.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final email = _api.getCurrentUser()?.email;

    return Scaffold(
      appBar: AppBar(
        title: Text('YUKI', style: AppTypography.h3),
        actions: [
          TextButton.icon(
            onPressed: _switchToCustomerView,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Map'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _editProfile();
                case 'customer':
                  _switchToCustomerView();
                case 'sign_out':
                  _signOut();
              }
            },
            itemBuilder: (_) => [
              if (email != null) ...[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(email, style: AppTypography.bodySmall),
                ),
                const PopupMenuDivider(),
              ],
              if (account != null)
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('Edit provider profile'),
                ),
              const PopupMenuItem<String>(
                value: 'customer',
                child: Text('Switch to customer view'),
              ),
              const PopupMenuItem<String>(value: 'sign_out', child: Text('Sign out')),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: account != null
          ? RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _ProfileHeader(account: account),
                      const SizedBox(height: AppSpacing.lg),
                      _buildStatusCard(account),
                      const SizedBox(height: AppSpacing.xl),
                      ..._buildRequests(account),
                      if (_upcoming.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text('Upcoming jobs', style: AppTypography.h3),
                        const SizedBox(height: AppSpacing.md),
                        for (final booking in _upcoming)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _BookingCard(booking: booking),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : _needsProviderProfile
              ? _buildProviderOnboarding()
              : _buildLoadingOrError(),
    );
  }

  Widget _buildProviderOnboarding() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.work_outline, size: 56, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Offer your services on Yuki',
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Set your rate and the services you offer. Once your background check '
                'clears, you can go available and get requests from neighbors nearby.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enablingProvider ? null : _enableProviderProfile,
                  child: _enablingProvider ? const _ButtonSpinner() : const Text('Get started'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _enablingProvider ? null : _switchToCustomerView,
                child: const Text('Not now, back to customer view'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrError() {
    if (_loadError == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(_loadError!, textAlign: TextAlign.center, style: AppTypography.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ProviderAccount account) {
    if (!account.isVerified) {
      return const _StatusCard(
        dotColor: AppColors.warning,
        title: 'Verification in progress',
        body: 'You can go available once your background check clears.',
      );
    }

    if (!_isAvailable) {
      return _StatusCard(
        dotColor: AppColors.textHint,
        title: 'Offline',
        body: 'Customers within 5 miles will see you on the map for 30 minutes.',
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _changingAvailability ? null : () => _changeAvailability(available: true),
              child: _changingAvailability ? const _ButtonSpinner() : const Text('Go available now'),
            ),
          ),
        ],
      );
    }

    final remaining = _availableUntil!.difference(DateTime.now());
    return _StatusCard(
      dotColor: AppColors.success,
      title: 'Available now',
      trailing: Text(
        '${_formatCountdown(remaining)} left',
        style: AppTypography.bodyLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      body: 'Customers nearby can see you on the map. Your location updates every minute.',
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _changingAvailability ? null : () => _changeAvailability(available: false),
                child: const Text('Go offline'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    _changingAvailability ? null : () => _changeAvailability(available: true),
                child: _changingAvailability
                    ? const _ButtonSpinner()
                    : const Text('Extend to 30 min'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildRequests(ProviderAccount account) {
    final now = DateTime.now();
    final pending =
        _requests.where((r) => r.expiresAt == null || r.expiresAt!.isAfter(now)).toList();

    final String emptyText;
    if (!account.isVerified) {
      emptyText = 'Requests will show up here once you\'re verified.';
    } else if (_isAvailable) {
      emptyText = 'No requests yet. New ones show up here automatically.';
    } else {
      emptyText = 'No requests right now. Go available to start getting them.';
    }

    return [
      Text('Incoming requests', style: AppTypography.h3),
      const SizedBox(height: AppSpacing.md),
      if (pending.isEmpty)
        Text(
          emptyText,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        )
      else
        for (final request in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _BookingCard(
              booking: request,
              footer: _buildRequestActions(request, now),
            ),
          ),
    ];
  }

  Widget _buildRequestActions(ProviderBooking request, DateTime now) {
    final busy = _responding.contains(request.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (request.expiresAt != null) ...[
          Text(
            'Expires in ${_formatCountdown(request.expiresAt!.difference(now))}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.accentDark,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => _respond(request, accept: false),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: busy ? null : () => _respond(request, accept: true),
                child: const Text('Accept'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProviderAccount account;

  const _ProfileHeader({required this.account});

  @override
  Widget build(BuildContext context) {
    final rate = account.hourlyRate;
    final summary = [
      if (rate != null)
        '\$${rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2)}/hr',
      if (account.categories.isNotEmpty) account.categories.map(categoryLabel).join(', '),
    ].join(' · ');

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.secondary,
          child: Text(
            account.firstName.isNotEmpty ? account.firstName[0].toUpperCase() : '?',
            style: AppTypography.h3.copyWith(color: AppColors.textInverse),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.fullName.isEmpty ? 'Welcome' : account.fullName,
                style: AppTypography.h3,
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  summary,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Color dotColor;
  final String title;
  final String body;
  final Widget? trailing;
  final List<Widget> actions;

  const _StatusCard({
    required this.dotColor,
    required this.title,
    required this.body,
    this.trailing,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.h3)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ...actions,
          ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final ProviderBooking booking;
  final Widget? footer;

  const _BookingCard({required this.booking, this.footer});

  @override
  Widget build(BuildContext context) {
    final price = booking.price;
    final when = booking.scheduledFor;
    final duration = booking.durationMinutes;
    final schedule = [
      if (when != null) booking.isAsap ? 'ASAP' : _formatWhen(context, when),
      if (duration != null) _formatDuration(duration),
    ].join(' · ');
    final description = booking.description;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(categoryLabel(booking.serviceCategory), style: AppTypography.h3),
              ),
              if (price != null)
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: AppTypography.h3.copyWith(color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(booking.customerName, style: AppTypography.bodyMedium),
          if (schedule.isNotEmpty) _BookingDetail(icon: Icons.schedule, text: schedule),
          if (booking.address != null)
            _BookingDetail(icon: Icons.place_outlined, text: booking.address!),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '"$description"',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _BookingDetail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BookingDetail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatCountdown(Duration remaining) {
  final seconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _formatWhen(BuildContext context, DateTime when) {
  final time = TimeOfDay.fromDateTime(when).format(context);
  final now = DateTime.now();
  final days = DateTime(when.year, when.month, when.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Tomorrow, $time';
  return '${_months[when.month - 1]} ${when.day}, $time';
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  if (rest == 0) return hours == 1 ? '1 hr' : '$hours hrs';
  return '$hours hr $rest min';
}
