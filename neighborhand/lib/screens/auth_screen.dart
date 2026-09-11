import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, OAuthProvider;

import '../models/my_profile.dart';
import '../models/nearby_provider_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_banner.dart';
import 'booking_screen.dart';
import 'complete_profile_screen.dart';
import 'customer_bookings_screen.dart';
import 'home_screen.dart';
import 'provider_home_screen.dart';

/// Goes straight to booking when signed in, otherwise asks the customer to sign in first.
void openBookingFlow(BuildContext context, NearbyProvider provider) {
  final signedIn = SupabaseService.instance.getCurrentUser() != null;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          signedIn ? BookingScreen(provider: provider) : AuthScreen(provider: provider),
    ),
  );
}

void openProviderView(BuildContext context) {
  final service = SupabaseService.instance;
  if (service.preferredView != 'provider') {
    unawaited(service.setPreferredView('provider').catchError((_) {}));
  }
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const ProviderHomeScreen()),
    (_) => false,
  );
}

/// Sends a freshly signed-in user to the right place, first asking for any profile
/// details sign-in didn't provide.
Future<void> finishSignIn(
  BuildContext context, {
  NearbyProvider? bookingProvider,
  bool offerServices = false,
}) async {
  final navigator = Navigator.of(context);
  final service = SupabaseService.instance;

  MyProfile? profile;
  try {
    profile = await service.getMyProfile();
  } catch (_) {
    // Backend unreachable; let them in rather than block sign-in on the completeness check.
  }

  final incomplete = profile;
  if (incomplete != null && !incomplete.isComplete) {
    final finished = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => CompleteProfileScreen(profile: incomplete, offerServices: offerServices),
      ),
    );
    if (finished != true) return;
  }

  if (offerServices && service.preferredView != 'provider') {
    await service.setPreferredView('provider').catchError((_) {});
  }

  if (bookingProvider != null) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
    navigator.push(MaterialPageRoute(builder: (_) => BookingScreen(provider: bookingProvider)));
  } else if (service.preferredView == 'provider') {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ProviderHomeScreen()),
      (_) => false,
    );
  } else {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }
}

/// Customer app bar actions: sign-in buttons when signed out, view switch and account menu when signed in.
class AccountActions extends StatefulWidget {
  const AccountActions({super.key});

  @override
  State<AccountActions> createState() => _AccountActionsState();
}

class _AccountActionsState extends State<AccountActions> {
  StreamSubscription<Object?>? _authEvents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authEvents = SupabaseService.instance.authEvents.listen((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _authEvents?.cancel();
    super.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _signOut() async {
    await SupabaseService.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.getCurrentUser();

    if (user == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _open(const AuthScreen(offerServices: true)),
            child: const Text('Become a provider'),
          ),
          TextButton(
            onPressed: () => _open(const AuthScreen()),
            child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    final firstName = user.userMetadata?['first_name'] as String?;
    final email = user.email ?? '';
    final label = (firstName != null && firstName.isNotEmpty)
        ? firstName
        : (email.isNotEmpty ? email : 'Account');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'My bookings',
          onPressed: () => _open(const CustomerBookingsScreen()),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        TextButton.icon(
          onPressed: () => openProviderView(context),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Provider view'),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (value) {
            if (value == 'bookings') _open(const CustomerBookingsScreen());
            if (value == 'provider') openProviderView(context);
            if (value == 'sign_out') _signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(email.isNotEmpty ? email : label, style: AppTypography.bodySmall),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(value: 'bookings', child: Text('My bookings')),
            const PopupMenuItem<String>(
              value: 'provider',
              child: Text('Switch to provider view'),
            ),
            const PopupMenuItem<String>(value: 'sign_out', child: Text('Sign out')),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  label[0].toUpperCase(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textInverse,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: AppTypography.bodyMedium),
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

/// Passwordless sign-in: a one-time code by email (or text, once SMS is set up),
/// or Google / Apple. New emails get an account automatically.
class AuthScreen extends StatefulWidget {
  final NearbyProvider? provider; // Set when signing in to book this provider
  final bool offerServices;

  const AuthScreen({
    super.key,
    this.provider,
    this.offerServices = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _resendCooldown = Duration(seconds: 60);
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  // Set once a code has been sent; exactly one is non-null.
  String? _codeEmail;
  String? _codePhone;
  DateTime? _canResendAt;

  bool get _awaitingCode => _codeEmail != null || _codePhone != null;

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// US numbers as E.164 ("+12065550100"), or null if [input] isn't a phone number.
  static String? _asPhone(String input) {
    if (input.contains('@')) return null;
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    return null;
  }

  Future<void> _run(Future<void> Function() action, {bool verifying = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on _UserFacingError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _describeAuthError(e.message, verifying: verifying));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _describeAuthError(String message, {required bool verifying}) {
    final lower = message.toLowerCase();
    if (verifying && (lower.contains('expired') || lower.contains('invalid'))) {
      return 'That code is wrong or has expired. Check it, or send a new one.';
    }
    if (lower.contains('email rate limit')) {
      return 'We\'ve sent too many emails in the last hour. Try again later.';
    }
    return message;
  }

  Future<void> _sendCode() async {
    final input = _identifierController.text.trim();
    final phone = _asPhone(input);
    final email = phone == null && _emailPattern.hasMatch(input) ? input.toLowerCase() : null;
    if (phone == null && email == null) {
      setState(() => _error = 'Enter a valid email address or phone number.');
      return;
    }

    await _run(() async {
      final service = SupabaseService.instance;
      if (phone != null && !(await service.enabledSignInMethods()).contains('phone')) {
        throw const _UserFacingError(
          'Sign-in by text isn\'t available yet. Use your email for now.',
        );
      }
      await service.sendSignInCode(email: email, phone: phone);
      if (!mounted) return;
      setState(() {
        _codeEmail = email;
        _codePhone = phone;
        _canResendAt = DateTime.now().add(_resendCooldown);
        _codeController.clear();
      });
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      setState(() => _error = 'Enter the code from your ${_codePhone != null ? 'text' : 'email'}.');
      return;
    }

    await _run(() async {
      await SupabaseService.instance.verifySignInCode(
        email: _codeEmail,
        phone: _codePhone,
        code: code,
      );
      if (!mounted) return;
      await finishSignIn(
        context,
        bookingProvider: widget.provider,
        offerServices: widget.offerServices,
      );
    }, verifying: true);
  }

  Future<void> _resendCode() async {
    final wait = _canResendAt?.difference(DateTime.now());
    if (wait != null && wait > Duration.zero) {
      setState(() => _error = 'You can request a new code in ${wait.inSeconds + 1} seconds.');
      return;
    }

    await _run(() async {
      await SupabaseService.instance.sendSignInCode(email: _codeEmail, phone: _codePhone);
      _canResendAt = DateTime.now().add(_resendCooldown);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New code sent.')),
        );
      }
    });
  }

  void _useDifferentIdentifier() {
    setState(() {
      _codeEmail = null;
      _codePhone = null;
      _error = null;
    });
  }

  Future<void> _continueWith(OAuthProvider provider, {required String key, required String name}) {
    return _run(() async {
      final service = SupabaseService.instance;
      if (!(await service.enabledSignInMethods()).contains(key)) {
        throw _UserFacingError('$name sign-in isn\'t set up yet. Use your email for now.');
      }
      await service.signInWithProvider(provider);
    });
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _awaitingCode
              ? (_loading ? null : _useDifferentIdentifier)
              : () => Navigator.pop(context),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _awaitingCode ? _buildCodeStep() : _buildIdentifierStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentifierStep() {
    final String? subtitle;
    if (widget.offerServices) {
      subtitle = 'Offer your services to neighbors in Sumner and Auburn.';
    } else if (widget.provider != null) {
      subtitle = 'Sign in to book ${widget.provider!.firstName}.';
    } else {
      subtitle = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What\'s your phone number or email?', style: AppTypography.h2),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _identifierController,
          enabled: !_loading,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _sendCode(),
          decoration: _fieldDecoration('Enter phone number or email'),
        ),
        const SizedBox(height: AppSpacing.md),
        _primaryButton('Continue', _sendCode),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          ErrorBanner(_error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _OrDivider(),
        const SizedBox(height: AppSpacing.lg),
        _SocialButton(
          icon: FontAwesomeIcons.google,
          label: 'Continue with Google',
          onPressed: _loading
              ? null
              : () => _continueWith(OAuthProvider.google, key: 'google', name: 'Google'),
        ),
        const SizedBox(height: AppSpacing.md),
        _SocialButton(
          icon: FontAwesomeIcons.apple,
          label: 'Continue with Apple',
          onPressed: _loading
              ? null
              : () => _continueWith(OAuthProvider.apple, key: 'apple', name: 'Apple'),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'We\'ll send a one-time sign-in code by email, or by text if you use a phone number. '
          'Message and data rates may apply.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    final byText = _codePhone != null;
    final sentTo = _codePhone ?? _codeEmail!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter the code we sent you', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            text: 'It went to ',
            children: [
              TextSpan(text: sentTo, style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(
                text: byText ? '.' : '. Check your spam folder if you don\'t see it.',
              ),
            ],
          ),
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _codeController,
          enabled: !_loading,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verifyCode(),
          maxLength: 10,
          style: AppTypography.h3.copyWith(letterSpacing: 6),
          decoration: _fieldDecoration('123456').copyWith(counterText: ''),
        ),
        const SizedBox(height: AppSpacing.md),
        _primaryButton('Continue', _verifyCode),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          ErrorBanner(_error!),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.md,
          children: [
            TextButton(
              onPressed: _loading ? null : _resendCode,
              child: const Text('Send a new code'),
            ),
            TextButton(
              onPressed: _loading ? null : _useDifferentIdentifier,
              child: Text('Use a different ${byText ? 'number' : 'email'}'),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserFacingError implements Exception {
  final String message;

  const _UserFacingError(this.message);
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icon, size: 18, color: AppColors.textPrimary),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: AppColors.divider,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
        ),
      ),
    );
  }
}
