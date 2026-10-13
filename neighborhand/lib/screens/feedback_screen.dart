import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_banner.dart';
import 'my_tickets_screen.dart';

const _categories = {
  'idea': 'An idea',
  'problem': 'Something broken',
  'praise': 'Something good',
  'other': 'Something else',
};

/// Tell us about Yuki itself. Problems with a particular job go through
/// "Report a problem" on that booking instead, which opens a ticket we work.
class FeedbackScreen extends StatefulWidget {
  /// Where the person was when they opened this, sent along so a short note
  /// is still actionable.
  final String? context;

  const FeedbackScreen({super.key, this.context});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  String _category = 'idea';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.length < 5) {
      setState(() => _error = 'Tell us a little more.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await SupabaseService.instance.sendFeedback(
        category: _category,
        message: message,
        context: widget.context,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your feedback is with us.')),
      );
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
    return Scaffold(
      appBar: AppBar(title: Text('Send feedback', style: AppTypography.h3)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How is Yuki working for you?', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This goes straight to the people building it.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
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
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _message,
                  enabled: !_sending,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'What would you like us to know?',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ErrorBanner(_error!),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textInverse,
                            ),
                          )
                        : const Text('Send feedback'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                Text('Something went wrong with a job?', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Use "Report a problem" on that booking so we can look into it, '
                  'and follow where it got to here.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _sending
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                          ),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('My reports'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
