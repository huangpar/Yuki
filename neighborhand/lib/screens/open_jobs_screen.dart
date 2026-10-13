import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/service_categories.dart';
import '../models/job_post.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_strip.dart';
import '../utils/formatters.dart';

/// Jobs customers posted nearby, where a provider can take the asking price or
/// counter with their own rate.
class OpenJobsScreen extends StatefulWidget {
  const OpenJobsScreen({super.key});

  @override
  State<OpenJobsScreen> createState() => _OpenJobsScreenState();
}

class _OpenJobsScreenState extends State<OpenJobsScreen> {
  List<JobPost>? _jobs;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    try {
      final position = await _currentPosition();
      if (position == null) {
        if (mounted) {
          setState(() => _error = 'Yuki needs your location to show jobs near you.');
        }
        return;
      }
      final jobs = await SupabaseService.instance.getOpenJobs(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load jobs. Check your connection and try again.');
      }
    }
  }

  Future<void> _makeOffer(JobPost job) async {
    final draft = await showDialog<_OfferDraft>(
      context: context,
      builder: (_) => _OfferDialog(job: job),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy.add(job.id));
    try {
      await SupabaseService.instance.sendJobOffer(
        job.id,
        rateType: draft.rateType,
        amount: draft.amount,
        message: draft.message,
      );
      _showMessage('Offer sent. The customer will see it on their job.');
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
      await _load();
    } catch (_) {
      _showMessage('Could not send your offer. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(job.id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jobs nearby', style: AppTypography.h3),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final jobs = _jobs;

    if (jobs == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (jobs == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: AppTypography.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.work_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.md),
              Text('No open jobs within 5 miles', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'New posts show up here when customers nearby need help.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => _OpenJobCard(
          job: jobs[i],
          busy: _busy.contains(jobs[i].id),
          onOffer: () => _makeOffer(jobs[i]),
        ),
      ),
    );
  }
}

class _OpenJobCard extends StatelessWidget {
  final JobPost job;
  final bool busy;
  final VoidCallback onOffer;

  const _OpenJobCard({required this.job, required this.busy, required this.onOffer});

  @override
  Widget build(BuildContext context) {
    final when = job.scheduledFor;
    final mine = job.myOffer;

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
                child: Text(categoryLabel(job.serviceCategory), style: AppTypography.h3),
              ),
              Text(
                '\$${job.offeredPrice.toStringAsFixed(2)}',
                style: AppTypography.h3.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              if (job.distanceMiles != null) '${job.distanceMiles!.toStringAsFixed(1)} mi away',
              if (when != null) job.asap ? 'ASAP' : formatWhen(context, when),
              formatDuration(job.durationMinutes),
            ].join(' · '),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(job.description, style: AppTypography.bodyMedium),
          if (job.photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            PhotoStrip(urls: job.photos),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(job.address, style: AppTypography.bodyMedium)),
            ],
          ),
          if (job.offerCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${job.offerCount} offer${job.offerCount == 1 ? '' : 's'} so far',
              style: AppTypography.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (mine != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Text(
                'You offered ${mine.matchesAsking ? 'their asking price' : mine.rateLabel}'
                ' — \$${mine.totalPrice.toStringAsFixed(2)} total',
                style: AppTypography.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onOffer,
                child: const Text('Change my offer'),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : onOffer,
                child: const Text('Make an offer'),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferDraft {
  final String rateType;
  final double? amount;
  final String? message;

  _OfferDraft(this.rateType, this.amount, this.message);
}

class _OfferDialog extends StatefulWidget {
  final JobPost job;

  const _OfferDialog({required this.job});

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  late String _rateType = widget.job.myOffer?.rateType ?? 'listed';
  late final _amountController = TextEditingController(
    text: widget.job.myOffer != null && widget.job.myOffer!.rateType != 'listed'
        ? widget.job.myOffer!.amount.toStringAsFixed(2)
        : '',
  );
  late final _messageController =
      TextEditingController(text: widget.job.myOffer?.message ?? '');
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  double? get _total {
    if (_rateType == 'listed') return widget.job.offeredPrice;
    final amount = _amount;
    if (amount == null) return null;
    if (_rateType == 'hourly') return amount * widget.job.durationMinutes / 60;
    return amount;
  }

  void _send() {
    if (_rateType != 'listed') {
      final amount = _amount;
      if (amount == null || amount <= 0 || amount > 10000) {
        setState(() => _error = 'Enter a rate up to \$10,000.');
        return;
      }
      if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(_amountController.text.trim())) {
        setState(() => _error = 'Use at most 2 decimal places.');
        return;
      }
    }
    Navigator.of(context).pop(
      _OfferDraft(
        _rateType,
        _rateType == 'listed' ? null : _amount,
        _messageController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return AlertDialog(
      title: Text('Your offer', style: AppTypography.h3),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _choice('Take \$${widget.job.offeredPrice.toStringAsFixed(0)}', 'listed'),
                _choice('Flat rate', 'flat'),
                _choice('Hourly rate', 'hourly'),
              ],
            ),
            if (_rateType != 'listed') ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: _rateType == 'hourly' ? 'Your hourly rate' : 'Your price for the job',
                  prefixText: '\$ ',
                  suffixText: _rateType == 'hourly' ? '/hr' : null,
                ),
              ),
            ],
            if (total != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Customer pays about \$${total.toStringAsFixed(2)} for '
                '${formatDuration(widget.job.durationMinutes)}.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _messageController,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'e.g. I can bring my own supplies',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Yuki doesn\'t handle payment: you and the customer settle directly.',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _send, child: const Text('Send offer')),
      ],
    );
  }

  Widget _choice(String label, String value) {
    final selected = _rateType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() {
        _rateType = value;
        _error = null;
      }),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.textInverse : AppColors.textPrimary,
      ),
    );
  }
}
