import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/service_categories.dart';
import '../models/address_suggestion.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/address_field.dart';
import '../widgets/photo_picker.dart';
import '../widgets/error_banner.dart';

/// Lets a customer post a job with the price they're willing to pay, which
/// nearby providers can then offer on. Pops `true` once posted.
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  static const _openForOptions = <int, String>{
    1: '1 hour',
    4: '4 hours',
    12: '12 hours',
    24: '1 day',
    72: '3 days',
    168: '7 days',
  };

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String? _category;
  bool _asap = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Duration? _duration;
  int _openForHours = 24;
  AddressSuggestion? _selectedAddress;
  Position? _nearby;
  bool _submitting = false;
  List<String> _photos = const [];
  String? _error;

  bool get _hasTime => _asap || (_selectedDate != null && _selectedTime != null);

  bool get _canSubmit => !_submitting && _category != null && _duration != null && _hasTime;

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }

  /// Only used to bias address suggestions toward where they are.
  Future<void> _loadNearby() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _nearby = position);
    } catch (_) {
      // Suggestions still work without it.
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    DateTime? scheduledFor;
    if (!_asap) {
      final date = _selectedDate!;
      final time = _selectedTime!;
      scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (!scheduledFor.isAfter(DateTime.now())) {
        setState(() => _error = 'Pick a time in the future.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // A picked address carries its own coordinates; otherwise use where they are.
      var latitude = _selectedAddress?.latitude;
      var longitude = _selectedAddress?.longitude;
      if (latitude == null || longitude == null) {
        final position = await _currentPosition();
        if (position == null) {
          setState(() {
            _error = 'Pick an address from the suggestions, or allow location access '
                'so providers nearby can find your job.';
          });
          return;
        }
        latitude = position.latitude;
        longitude = position.longitude;
      }

      await SupabaseService.instance.postJob(
        serviceCategory: _category!,
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        durationMinutes: _duration!.inMinutes,
        offeredPrice: double.parse(_priceController.text.trim()),
        openForHours: _openForHours,
        scheduledFor: scheduledFor,
        photos: _photos,
      );

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not post your job. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Post a job', style: AppTypography.h3)),
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
                  Text('What do you need done?', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Providers nearby can take your price or offer their own.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text('Service', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final entry in serviceCategories.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _category == entry.key,
                          showCheckmark: false,
                          onSelected:
                              _submitting ? null : (_) => setState(() => _category = entry.key),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _category == entry.key
                                ? AppColors.textInverse
                                : AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text('When', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  _buildWhen(),
                  const SizedBox(height: AppSpacing.xl),

                  Text('How long', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    children: [
                      _durationChip('30 min', const Duration(minutes: 30)),
                      _durationChip('1 hr', const Duration(hours: 1)),
                      _durationChip('2 hr', const Duration(hours: 2)),
                      _durationChip('3 hr', const Duration(hours: 3)),
                      _durationChip('4 hr', const Duration(hours: 4)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text('Where', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  AddressField(
                    controller: _addressController,
                    enabled: !_submitting,
                    nearLatitude: _nearby?.latitude,
                    nearLongitude: _nearby?.longitude,
                    onSelected: (suggestion) => setState(() => _selectedAddress = suggestion),
                    validator: (value) {
                      final address = value?.trim() ?? '';
                      if (address.isEmpty) return 'Enter the address for the job';
                      if (address.length < 5) return 'Enter a full street address';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text('Details', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_submitting,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: 'Describe the work so providers can price it...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                    ),
                    validator: (value) {
                      if ((value?.trim().length ?? 0) < 10) {
                        return 'Add a few more details (at least 10 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text('Photos (optional)', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Show providers what the job involves. Only providers signed '
                    'in to Yuki can see these.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PhotoPicker(
                    kind: 'job',
                    paths: _photos,
                    max: 4,
                    enabled: !_submitting,
                    onChanged: (paths) => setState(() => _photos = paths),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Text('Your price', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _priceController,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'What you\'re willing to pay',
                      prefixText: '\$ ',
                      helperText: 'Providers can accept this or offer their own rate.',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      final price = double.tryParse(text);
                      if (price == null) return 'Enter the price you\'re offering';
                      if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
                        return 'Use at most 2 decimal places';
                      }
                      if (price <= 0 || price > 10000) return 'Enter an amount up to \$10,000';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text('Keep it open for', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final entry in _openForOptions.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _openForHours == entry.key,
                          showCheckmark: false,
                          onSelected: _submitting
                              ? null
                              : (_) => setState(() => _openForHours = entry.key),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _openForHours == entry.key
                                ? AppColors.textInverse
                                : AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'It closes as soon as you accept an offer. Yuki doesn\'t handle payment: '
                    'you and the provider settle directly.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (_error != null) ...[
                    ErrorBanner(_error!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textInverse,
                              ),
                            )
                          : const Text('Post job'),
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

  Widget _buildWhen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          children: [
            _whenChip('ASAP', asap: true),
            _whenChip('Pick a time', asap: false),
          ],
        ),
        if (!_asap) ...[
          const SizedBox(height: AppSpacing.md),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: AppColors.primary),
            title: Text(
              _selectedDate == null
                  ? 'Select date'
                  : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
            ),
            onTap: _submitting ? null : _selectDate,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              side: const BorderSide(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            leading: const Icon(Icons.access_time, color: AppColors.primary),
            title: Text(_selectedTime == null ? 'Select time' : _selectedTime!.format(context)),
            onTap: _submitting ? null : _selectTime,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              side: const BorderSide(color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _whenChip(String label, {required bool asap}) {
    final selected = _asap == asap;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: _submitting ? null : (_) => setState(() => _asap = asap),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.textInverse : AppColors.textPrimary,
      ),
    );
  }

  Widget _durationChip(String label, Duration duration) {
    return FilterChip(
      label: Text(label),
      selected: _duration == duration,
      onSelected: _submitting
          ? null
          : (selected) => setState(() => _duration = selected ? duration : null),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: _duration == duration ? AppColors.textInverse : AppColors.textPrimary,
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }
}
