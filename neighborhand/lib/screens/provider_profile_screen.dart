import 'package:flutter/material.dart';

import '../constants/service_categories.dart';
import '../models/provider_account.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_banner.dart';
import 'home_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final ProviderAccount account;
  final bool isFirstSetup;

  const ProviderProfileScreen({
    super.key,
    required this.account,
    this.isFirstSetup = false,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rateController;
  late final TextEditingController _bioController;
  late final Set<String> _categories;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rate = widget.account.hourlyRate;
    _rateController = TextEditingController(
      text: rate == null
          ? ''
          : (rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2)),
    );
    _bioController = TextEditingController(text: widget.account.bio ?? '');
    _categories = {...widget.account.categories};
  }

  @override
  void dispose() {
    _rateController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();
    if (_categories.isEmpty) {
      setState(() => _error = 'Pick at least one service you offer.');
      return;
    }
    if (!formValid) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await SupabaseService.instance.updateProviderProfile(
        hourlyRate: double.parse(_rateController.text.trim()),
        categories: _categories.toList(),
        bio: _bioController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save your profile. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateRate(String? value) {
    final text = value?.trim() ?? '';
    final rate = double.tryParse(text);
    if (rate == null) return 'Enter your hourly rate';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return 'Use at most 2 decimal places';
    if (rate < 10 || rate > 500) return 'Rate must be between \$10 and \$500';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFirstSetup ? 'Set up your provider profile' : 'Your provider profile',
          style: AppTypography.h3,
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : () => openCustomerView(context),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Map'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isFirstSetup) ...[
                    Text('Tell customers what you do', style: AppTypography.h2),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This is what customers see on your card on the map.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  Text('Services you offer', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final entry in serviceCategories.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: _categories.contains(entry.key),
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                          onSelected: _saving
                              ? null
                              : (selected) => setState(() {
                                    if (selected) {
                                      _categories.add(entry.key);
                                    } else {
                                      _categories.remove(entry.key);
                                    }
                                    _error = null;
                                  }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _rateController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Hourly rate',
                      prefixText: '\$ ',
                      suffixText: '/hr',
                    ),
                    validator: _validateRate,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _bioController,
                    enabled: !_saving,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'About you (optional)',
                      hintText: 'e.g. 5 years of house cleaning experience. I bring my own supplies.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null) ...[
                    ErrorBanner(_error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textInverse,
                              ),
                            )
                          : Text(widget.isFirstSetup ? 'Continue' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
