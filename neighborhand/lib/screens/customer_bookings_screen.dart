import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../constants/service_categories.dart';
import '../models/customer_booking.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/rating_stars.dart';
import '../widgets/review_dialog.dart';
import 'booking_status_screen.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  static const _pollInterval = Duration(seconds: 10);

  List<CustomerBooking>? _bookings;
  String? _error;
  Timer? _clock;
  Timer? _poll;
  final Set<String> _completing = {};

  bool get _anyWaiting => _bookings?.any((b) => b.isWaiting) ?? false;

  @override
  void initState() {
    super.initState();
    _load();
    // Keeps countdowns ticking and flips expired requests to "No response".
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _anyWaiting) setState(() {});
    });
    _poll = Timer.periodic(_pollInterval, (_) {
      if (_anyWaiting) _load();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bookings = await SupabaseService.instance.getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your bookings. Check your connection and try again.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Either side can close out a job; whoever gets there first opens up reviews.
  Future<void> _markDone(CustomerBooking booking) async {
    setState(() => _completing.add(booking.id));
    try {
      await SupabaseService.instance.completeBooking(booking.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final rating = await askForReview(
        context,
        bookingId: booking.id,
        subjectName: booking.providerName ?? 'your provider',
      );
      if (rating != null) _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not update that booking. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _completing.remove(booking.id));
    }
  }

  Future<void> _review(CustomerBooking booking) async {
    final rating = await askForReview(
      context,
      bookingId: booking.id,
      subjectName: booking.providerName ?? 'your provider',
      existingRating: booking.myRating,
    );
    if (rating != null) _load();
  }

  Future<void> _open(CustomerBooking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingStatusScreen(
          providerName: booking.providerName ?? 'Your provider',
          booking: booking,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My bookings', style: AppTypography.h3)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final bookings = _bookings;

    if (bookings == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (bookings == null) {
      return _Message(
        icon: Icons.cloud_off,
        title: _error!,
        buttonLabel: 'Try again',
        onPressed: _load,
      );
    }

    if (bookings.isEmpty) {
      return _Message(
        icon: Icons.event_note_outlined,
        title: 'No bookings yet',
        body: 'Find a provider on the map and send your first request.',
        buttonLabel: 'Browse the map',
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => _BookingTile(
          booking: bookings[i],
          onTap: () => _open(bookings[i]),
          onReview: () => _review(bookings[i]),
          onMarkDone: () => _markDone(bookings[i]),
          markingDone: _completing.contains(bookings[i].id),
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final CustomerBooking booking;
  final VoidCallback onTap;
  final VoidCallback onReview;
  final VoidCallback onMarkDone;
  final bool markingDone;

  const _BookingTile({
    required this.booking,
    required this.onTap,
    required this.onReview,
    required this.onMarkDone,
    required this.markingDone,
  });

  @override
  Widget build(BuildContext context) {
    final when = booking.scheduledFor;
    final price = booking.price;
    final arrival = booking.isAccepted ? booking.estimatedArrivalAt : null;
    final created = booking.createdAt;
    final details = [
      categoryLabel(booking.serviceCategory),
      if (when != null) booking.isAsap ? 'ASAP' : formatWhen(context, when),
      if (booking.durationMinutes != null) formatDuration(booking.durationMinutes!),
    ].join(' \u00b7 ');

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.providerName ?? 'Provider', style: AppTypography.h3),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          details,
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        if (created != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Requested ${formatWhen(context, created)}',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                        if (arrival != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Arriving around ${formatArrival(context, arrival)}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (price != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _StatusChip(booking: booking),
                ],
              ),
              if (booking.isAccepted) ...[
                const Divider(height: AppSpacing.lg, color: AppColors.border),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Finished? Marking it done lets you both leave a review.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: markingDone ? null : onMarkDone,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(markingDone ? 'Saving\u2026' : 'Mark this done'),
                    ),
                  ],
                ),
              ],
              if (booking.isComplete) ...[
                const Divider(height: AppSpacing.lg, color: AppColors.border),
                booking.canReview
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: onReview,
                          icon: const Icon(Icons.star_border, size: 18),
                          label: Text('Rate ${booking.providerName ?? 'your provider'}'),
                        ),
                      )
                    : Row(
                        children: [
                          Text(
                            'You rated',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          RatingStars(
                            rating: booking.myRating!.toDouble(),
                            reviewCount: 1,
                            size: 14,
                            showCount: false,
                          ),
                          const Spacer(),
                          TextButton(onPressed: onReview, child: const Text('Edit')),
                        ],
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CustomerBooking booking;

  const _StatusChip({required this.booking});

  @override
  Widget build(BuildContext context) {
    final color = switch (booking.statusLabel) {
      'Waiting' => AppColors.accentDark,
      'Accepted' => AppColors.success,
      'Completed' => AppColors.primary,
      _ => AppColors.textSecondary,
    };
    final expiresAt = booking.expiresAt;
    final label = booking.isWaiting && expiresAt != null
        ? 'Waiting · ${formatCountdown(expiresAt.difference(DateTime.now()))}'
        : booking.statusLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _Message({
    required this.icon,
    required this.title,
    this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                body!,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
