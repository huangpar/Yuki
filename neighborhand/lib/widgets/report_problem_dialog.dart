import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'error_banner.dart';

const _categories = {
  'no_show': 'Nobody showed up',
  'quality': 'Quality of the work',
  'payment': 'Payment',
  'safety': 'Safety',
  'other': 'Something else',
};

/// Opens a support ticket about one booking or job. Pops true once it's in.
class ReportProblemDialog extends StatefulWidget {
  final String subjectType;
  final String? bookingId;
  final String? jobId;

  /// What the report is about, e.g. "your booking with Maya".
  final String about;

  const ReportProblemDialog({
    super.key,
    required this.subjectType,
    required this.about,
    this.bookingId,
    this.jobId,
  });

  @override
  State<ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<ReportProblemDialog> {
  final _message = TextEditingController();
  String _category = 'no_show';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _message.text.trim();
    if (message.length < 5) {
      setState(() => _error = 'Tell us what happened.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await SupabaseService.instance.reportProblem(
        subjectType: widget.subjectType,
        category: _category,
        message: message,
        bookingId: widget.bookingId,
        jobId: widget.jobId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not send that. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report a problem', style: AppTypography.h3),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'About ${widget.about}.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final entry in _categories.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _category == entry.key,
                      selectedColor: AppColors.primary.withOpacity(0.15),
                      onSelected: _sending
                          ? null
                          : (_) => setState(() {
                                _category = entry.key;
                                _error = null;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _message,
                enabled: !_sending,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
                )
              : const Text('Send report'),
        ),
      ],
    );
  }
}

/// Opens [ReportProblemDialog] and says whether a ticket was raised.
Future<bool> reportProblem(
  BuildContext context, {
  required String subjectType,
  required String about,
  String? bookingId,
  String? jobId,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => ReportProblemDialog(
      subjectType: subjectType,
      about: about,
      bookingId: bookingId,
      jobId: jobId,
    ),
  );
  return sent ?? false;
}
