import 'package:flutter/material.dart';

import '../constants/service_categories.dart';
import '../models/job_post.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'post_job_screen.dart';

/// The customer's posted jobs and the offers providers have made on them.
class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  List<JobPost>? _jobs;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await SupabaseService.instance.getMyJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your jobs. Check your connection and try again.');
      }
    }
  }

  Future<void> _postJob() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostJobScreen()),
    );
    if (posted == true) {
      _showMessage('Job posted. Providers nearby can offer now.');
      _load();
    }
  }

  Future<void> _acceptOffer(JobPost job, JobOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Accept this offer?', style: AppTypography.h3),
        content: Text(
          '${offer.providerName} for \$${offer.totalPrice.toStringAsFixed(2)}. '
          'This books them and closes the job. Yuki doesn\'t handle payment, so you\'ll '
          'settle the amount directly.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(offer.id, () async {
      await SupabaseService.instance.acceptJobOffer(offer.id);
      _showMessage('Booked with ${offer.providerName}. Find it under My bookings.');
    });
  }

  Future<void> _declineOffer(JobOffer offer) =>
      _run(offer.id, () => SupabaseService.instance.declineJobOffer(offer.id));

  Future<void> _cancelJob(JobPost job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel this job?', style: AppTypography.h3),
        content: Text(
          'It comes off the board and any offers are turned down.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel job'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(job.id, () => SupabaseService.instance.cancelJob(job.id));
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    setState(() => _busy.add(id));
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      _showMessage(e.message);
      await _load();
    } catch (_) {
      _showMessage('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
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
        title: Text('My jobs', style: AppTypography.h3),
        actions: [
          TextButton.icon(
            onPressed: _postJob,
            icon: const Icon(Icons.add),
            label: const Text('Post a job'),
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
      return _Message(
        icon: Icons.cloud_off,
        title: _error!,
        buttonLabel: 'Try again',
        onPressed: _load,
      );
    }

    if (jobs.isEmpty) {
      return _Message(
        icon: Icons.work_outline,
        title: 'No jobs posted yet',
        body: 'Post what you need done and set your price. Providers nearby can offer on it.',
        buttonLabel: 'Post a job',
        onPressed: _postJob,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => _JobCard(
          job: jobs[i],
          busy: _busy,
          onAccept: (offer) => _acceptOffer(jobs[i], offer),
          onDecline: _declineOffer,
          onCancel: () => _cancelJob(jobs[i]),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobPost job;
  final Set<String> busy;
  final void Function(JobOffer) onAccept;
  final void Function(JobOffer) onDecline;
  final VoidCallback onCancel;

  const _JobCard({
    required this.job,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final offers = job.isOpen ? job.pendingOffers : job.offers;
    final when = job.scheduledFor;
    final created = job.createdAt;

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
              _StatusChip(label: job.statusLabel, open: job.isOpen),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              'Asking \$${job.offeredPrice.toStringAsFixed(2)}',
              if (when != null) job.asap ? 'ASAP' : formatWhen(context, when),
              formatDuration(job.durationMinutes),
            ].join(' · '),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          if (created != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Posted ${formatWhen(context, created)}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (job.isOpen && job.expiresAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Open until ${formatWhen(context, job.expiresAt!)}',
              style: AppTypography.bodySmall,
            ),
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
          const SizedBox(height: AppSpacing.sm),
          Text(job.description, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.md),

          if (offers.isEmpty)
            Text(
              job.isOpen ? 'No offers yet.' : 'No offers were accepted.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            )
          else ...[
            Text(
              job.isOpen ? '${offers.length} offer${offers.length == 1 ? '' : 's'}' : 'Offers',
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final offer in offers)
              _OfferRow(
                offer: offer,
                canAnswer: job.isOpen && offer.status == 'pending',
                busy: busy.contains(offer.id),
                onAccept: () => onAccept(offer),
                onDecline: () => onDecline(offer),
              ),
          ],

          if (job.isOpen) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy.contains(job.id) ? null : onCancel,
                child: const Text('Cancel job'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  final JobOffer offer;
  final bool canAnswer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OfferRow({
    required this.offer,
    required this.canAnswer,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.providerName,
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '\$${offer.totalPrice.toStringAsFixed(2)}',
                  style: AppTypography.h3.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              offer.matchesAsking ? 'Takes your asking price' : offer.rateLabel,
              style: AppTypography.bodySmall,
            ),
            if (offer.message != null && offer.message!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('"${offer.message}"',
                  style: AppTypography.bodyMedium.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (offer.status != 'pending') ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                offer.status == 'accepted' ? 'Accepted' : 'Declined',
                style: AppTypography.bodySmall.copyWith(
                  color: offer.status == 'accepted' ? AppColors.success : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (canAnswer) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onDecline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool open;

  const _StatusChip({required this.label, required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600),
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
