import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../constants/service_categories.dart';
import '../models/customer_booking.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class BookingStatusScreen extends StatefulWidget {
  final String providerName;
  final CustomerBooking booking;

  const BookingStatusScreen({
    super.key,
    required this.providerName,
    required this.booking,
  });

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  static const _pollInterval = Duration(seconds: 5);

  late CustomerBooking _booking = widget.booking;
  Timer? _poll;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    if (!_booking.isWaiting) return;
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_booking.isWaiting) {
        _poll?.cancel();
        _clock?.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!_booking.isWaiting) return;
    try {
      final booking = await SupabaseService.instance.getBooking(_booking.id);
      if (mounted) setState(() => _booking = booking);
    } catch (_) {
      // Transient; the next poll retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.providerName;

    IconData icon;
    Color color;
    String title;
    String message;
    if (_booking.isWaiting) {
      final expiresAt = _booking.expiresAt;
      icon = Icons.hourglass_top;
      color = AppColors.accent;
      title = 'Waiting for $name';
      message = expiresAt == null
          ? 'We sent your request. This screen updates on its own.'
          : '$name has ${formatCountdown(expiresAt.difference(DateTime.now()))} to respond. '
              'This screen updates on its own.';
    } else if (_booking.status == 'accepted') {
      icon = Icons.check_circle;
      color = AppColors.success;
      title = '$name accepted!';
      message = '$name accepted your request.';
    } else if (_booking.status == 'declined') {
      icon = Icons.event_busy;
      color = AppColors.textSecondary;
      title = '$name can\'t make it';
      message = 'Try another provider nearby.';
    } else if (_booking.isExpired) {
      icon = Icons.timer_off_outlined;
      color = AppColors.textSecondary;
      title = 'No response from $name';
      message = 'The 10 minutes ran out. Try another provider nearby.';
    } else {
      icon = Icons.info_outline;
      color = AppColors.textSecondary;
      title = _booking.statusLabel;
      message = '';
    }

    final noLuck = _booking.status == 'declined' || _booking.isExpired;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your request', style: AppTypography.h3),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.lg),
              Icon(icon, size: 56, color: color),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
              if (message.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _Summary(booking: _booking),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: noLuck
                    ? ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((route) => route.isFirst),
                        child: const Text('Find another provider'),
                      )
                    : OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final CustomerBooking booking;

  const _Summary({required this.booking});

  @override
  Widget build(BuildContext context) {
    final when = booking.scheduledFor;
    final duration = booking.durationMinutes;
    final price = booking.price;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Service', value: categoryLabel(booking.serviceCategory)),
          if (when != null)
            _SummaryRow(
              label: 'When',
              value: booking.isAsap ? 'ASAP' : formatWhen(context, when),
            ),
          if (duration != null) _SummaryRow(label: 'Duration', value: formatDuration(duration)),
          if (booking.address != null) _SummaryRow(label: 'Where', value: booking.address!),
          if (price != null)
            _SummaryRow(label: 'Estimated total', value: '\$${price.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}
