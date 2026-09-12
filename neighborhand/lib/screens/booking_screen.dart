import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/service_categories.dart';
import '../models/nearby_provider_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_banner.dart';
import 'booking_status_screen.dart';

class BookingScreen extends StatefulWidget {
  final NearbyProvider provider;

  const BookingScreen({
    required this.provider,
    Key? key,
  }) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String? _category =
      widget.provider.categories.length == 1 ? widget.provider.categories.first : null;
  bool _asap = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Duration? _duration;
  bool _submitting = false;
  String? _error;

  bool get _hasTime => _asap || (_selectedDate != null && _selectedTime != null);

  bool get _canSubmit => !_submitting && _category != null && _duration != null && _hasTime;

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Book ${widget.provider.firstName}', style: AppTypography.h3),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Info Card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.provider.firstName[0],
                            style: TextStyle(
                              color: AppColors.textInverse,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.provider.fullName,
                              style: AppTypography.h3,
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              '\$${widget.provider.hourlyRate.toStringAsFixed(0)}/hour',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xl),

              Text('Service', style: AppTypography.h3),
              SizedBox(height: AppSpacing.md),
              _buildServiceSelector(),
              SizedBox(height: AppSpacing.xl),

              Text('Date & Time', style: AppTypography.h3),
              SizedBox(height: AppSpacing.md),
              _buildDateTimeSelector(context),
              SizedBox(height: AppSpacing.xl),

              Text('Duration', style: AppTypography.h3),
              SizedBox(height: AppSpacing.md),
              _buildDurationSelector(),
              SizedBox(height: AppSpacing.xl),

              Text('Where?', style: AppTypography.h3),
              SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _addressController,
                enabled: !_submitting,
                decoration: InputDecoration(
                  hintText: 'Street address, city',
                  prefixIcon: Icon(Icons.place_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                ),
                validator: (value) {
                  final address = value?.trim() ?? '';
                  if (address.isEmpty) return 'Enter the address for the job';
                  if (address.length < 5) return 'Enter a full street address';
                  return null;
                },
              ),
              SizedBox(height: AppSpacing.xl),

              Text('What do you need help with?', style: AppTypography.h3),
              SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                enabled: !_submitting,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Describe the work you need done...',
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
              SizedBox(height: AppSpacing.lg),

              // Estimated Cost
              if (_duration != null)
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated total',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${(_estimatedCost()).toStringAsFixed(2)}',
                        style: AppTypography.h3.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: AppSpacing.xl),

              if (_error != null) ...[
                ErrorBanner(_error!),
                SizedBox(height: AppSpacing.lg),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submitBooking : null,
                  child: _submitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textInverse,
                          ),
                        )
                      : Text('Request Booking'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSelector() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final category in widget.provider.categories)
          ChoiceChip(
            label: Text(categoryLabel(category)),
            selected: _category == category,
            showCheckmark: false,
            onSelected: _submitting ? null : (_) => setState(() => _category = category),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: _category == category ? AppColors.textInverse : AppColors.textPrimary,
            ),
          ),
      ],
    );
  }

  Widget _buildDateTimeSelector(BuildContext context) {
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
        if (_asap) ...[
          SizedBox(height: AppSpacing.sm),
          Text(
            'We\'ll ask ${widget.provider.firstName} to come as soon as they can.',
            style: AppTypography.bodySmall,
          ),
        ] else ...[
          SizedBox(height: AppSpacing.md),
          ListTile(
            leading: Icon(Icons.calendar_today, color: AppColors.primary),
            title: Text(
              _selectedDate == null
                  ? 'Select Date'
                  : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
            ),
            trailing: Icon(Icons.arrow_forward),
            onTap: () => _selectDate(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              side: BorderSide(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          ListTile(
            leading: Icon(Icons.access_time, color: AppColors.primary),
            title: Text(
              _selectedTime == null
                  ? 'Select Time'
                  : _selectedTime!.format(context),
            ),
            trailing: Icon(Icons.arrow_forward),
            onTap: () => _selectTime(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              side: BorderSide(color: AppColors.textSecondary),
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

  Widget _buildDurationSelector() {
    return Wrap(
      spacing: AppSpacing.md,
      children: [
        _durationChip('30 min', Duration(minutes: 30)),
        _durationChip('1 hr', Duration(hours: 1)),
        _durationChip('2 hr', Duration(hours: 2)),
        _durationChip('3 hr', Duration(hours: 3)),
        _durationChip('4 hr', Duration(hours: 4)),
      ],
    );
  }

  Widget _durationChip(String label, Duration duration) {
    return FilterChip(
      label: Text(label),
      selected: _duration == duration,
      onSelected: _submitting
          ? null
          : (selected) {
              setState(() => _duration = selected ? duration : null);
            },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: _duration == duration ? AppColors.textInverse : AppColors.textPrimary,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  double _estimatedCost() {
    if (_duration == null) return 0;
    return widget.provider.hourlyRate * _duration!.inMinutes / 60;
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

  Future<void> _submitBooking() async {
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
      final position = await _currentPosition();
      if (position == null) {
        setState(() {
          _error = 'Yuki needs your location to send the request. '
              'Allow location access and try again.';
        });
        return;
      }

      final booking = await SupabaseService.instance.createBooking(
        providerId: widget.provider.id,
        serviceCategory: _category!,
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        latitude: position.latitude,
        longitude: position.longitude,
        durationMinutes: _duration!.inMinutes,
        scheduledFor: scheduledFor,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingStatusScreen(
            providerName: widget.provider.firstName,
            booking: booking,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401 ? 'Your session expired. Sign in again.' : e.message;
      });
    } catch (_) {
      setState(() => _error = 'Could not send your request. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
