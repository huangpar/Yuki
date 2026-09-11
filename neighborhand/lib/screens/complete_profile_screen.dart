import 'package:flutter/material.dart';

import '../models/my_profile.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_banner.dart';
import 'home_screen.dart';

/// Asks new accounts for what sign-in didn't provide: name, phone number, and whether
/// they want to book services, offer them, or both. Pops `true` once saved.
class CompleteProfileScreen extends StatefulWidget {
  final MyProfile profile;
  final bool offerServices;

  const CompleteProfileScreen({
    super.key,
    required this.profile,
    this.offerServices = false,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  bool _bookServices = true;
  late bool _offerServices = widget.offerServices || widget.profile.isProvider;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Google and Apple share a name (Apple only on first sign-in), so prefill from it.
    final metadata = SupabaseService.instance.getCurrentUser()?.userMetadata ?? const {};
    final fullName = (metadata['full_name'] ?? metadata['name'])?.toString().trim() ?? '';
    final nameParts = fullName.isEmpty ? const <String>[] : fullName.split(RegExp(r'\s+'));

    _firstName = TextEditingController(
      text: widget.profile.firstName.isNotEmpty
          ? widget.profile.firstName
          : (metadata['given_name']?.toString() ?? (nameParts.isNotEmpty ? nameParts.first : '')),
    );
    _lastName = TextEditingController(
      text: widget.profile.lastName.isNotEmpty
          ? widget.profile.lastName
          : (metadata['family_name']?.toString() ?? nameParts.skip(1).join(' ')),
    );
    _phone = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_bookServices && !_offerServices) {
      setState(() => _error = 'Choose at least one: book services or offer your services.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final service = SupabaseService.instance;
      await service.completeProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: _phone.text.trim(),
        offerServices: _offerServices,
      );
      if (_offerServices) await service.setPreferredView('provider');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save your details. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Widget _roleOption({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: _saving
          ? null
          : (checked) => setState(() {
                onChanged(checked ?? false);
                _error = null;
              }),
      title: Text(title, style: AppTypography.bodyMedium),
      subtitle: Text(subtitle, style: AppTypography.bodySmall),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.primary,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Finish your profile', style: AppTypography.h3),
        actions: [
          TextButton(
            onPressed: _saving ? null : _signOut,
            child: const Text('Sign out'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Almost there', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We need your name and phone number so bookings can reach you.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstName,
                          enabled: !_saving,
                          decoration: const InputDecoration(labelText: 'First name'),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _lastName,
                          enabled: !_saving,
                          decoration: const InputDecoration(labelText: 'Last name'),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '(555) 123-4567',
                    ),
                    validator: (value) {
                      final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                      if (digits.isEmpty) return 'Phone is required';
                      final valid = digits.length == 10 ||
                          (digits.length == 11 && digits.startsWith('1'));
                      return valid ? null : 'Enter a 10-digit US phone number';
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'I want to',
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  _roleOption(
                    value: _bookServices,
                    onChanged: (v) => _bookServices = v,
                    title: 'Book services',
                    subtitle: 'Get help from neighbors nearby',
                  ),
                  _roleOption(
                    value: _offerServices,
                    onChanged: (v) => _offerServices = v,
                    title: 'Offer my services',
                    subtitle: 'Get paid to help neighbors nearby',
                  ),
                  Text('You can switch between the two anytime.', style: AppTypography.bodySmall),
                  const SizedBox(height: AppSpacing.xl),
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
                          : const Text('Continue'),
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
