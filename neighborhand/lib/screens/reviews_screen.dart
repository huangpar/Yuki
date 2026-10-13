import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/review.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/photo_strip.dart';
import '../widgets/rating_stars.dart';

/// Everyone's reviews of one person, plus a link to their listing elsewhere.
class ReviewsScreen extends StatefulWidget {
  final String profileId;
  final String name;

  const ReviewsScreen({super.key, required this.profileId, required this.name});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  ReviewSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await SupabaseService.instance.getReviewsFor(widget.profileId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load reviews. Check your connection and try again.');
      }
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reviews of ${widget.name}', style: AppTypography.h3)),
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
    final summary = _summary;

    if (summary == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: AppTypography.h3, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final external = summary.externalReviewsUrl;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              RatingStars(rating: summary.rating, reviewCount: summary.reviewCount, size: 22),
              const Spacer(),
              Text(
                summary.reviewCount == 1 ? '1 review' : '${summary.reviewCount} reviews',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (external != null && external.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openExternal(external),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('See ${widget.name}\'s reviews elsewhere'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (summary.reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.md),
                  Text('No reviews here yet', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Reviews show up after a job is marked complete.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (final review in summary.reviews)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ReviewCard(review: review),
              ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final comment = review.comment;
    final created = review.createdAt;

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
              Expanded(child: Text(review.reviewerName, style: AppTypography.bodyMedium)),
              RatingStars(
                rating: review.rating.toDouble(),
                reviewCount: 1,
                size: 14,
                showCount: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              review.fromCustomer ? 'As a customer' : 'As a provider',
              if (created != null) formatWhen(context, created),
            ].join(' · '),
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(comment, style: AppTypography.bodyMedium),
          ],
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            PhotoStrip(urls: review.photos),
          ],
        ],
      ),
    );
  }
}
