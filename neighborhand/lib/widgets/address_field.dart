import 'dart:async';

import 'package:flutter/material.dart';

import '../models/address_suggestion.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// An address box that suggests real addresses as someone types. Picking one
/// also hands back its coordinates, so the job lands where the address is
/// rather than wherever the phone happens to be.
class AddressField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<AddressSuggestion?> onSelected;
  final double? nearLatitude;
  final double? nearLongitude;
  final bool enabled;
  final String hintText;
  final String? Function(String?)? validator;

  const AddressField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.nearLatitude,
    this.nearLongitude,
    this.enabled = true,
    this.hintText = 'Start typing an address',
    this.validator,
  });

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  static const _debounce = Duration(milliseconds: 350);
  static const _minCharacters = 4;

  Timer? _timer;
  List<AddressSuggestion> _suggestions = [];
  bool _loading = false;
  int _request = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    // Typing after picking means they're changing it, so drop the old coordinates.
    widget.onSelected(null);
    _timer?.cancel();

    if (value.trim().length < _minCharacters) {
      setState(() {
        _suggestions = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _timer = Timer(_debounce, () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    try {
      final results = await SupabaseService.instance.suggestAddresses(
        query,
        latitude: widget.nearLatitude,
        longitude: widget.nearLongitude,
      );
      // A slower earlier search must not overwrite a newer one.
      if (!mounted || request != _request) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    } catch (_) {
      // Lookup is a convenience; they can still type the address themselves.
      if (mounted && request == _request) {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
      }
    }
  }

  void _choose(AddressSuggestion suggestion) {
    widget.controller.text = suggestion.label;
    widget.onSelected(suggestion);
    setState(() {
      _suggestions = [];
      _loading = false;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.place_outlined, color: AppColors.primary),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
          ),
          validator: widget.validator,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final suggestion in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined,
                        size: 20, color: AppColors.textSecondary),
                    title: Text(suggestion.label, style: AppTypography.bodyMedium),
                    onTap: () => _choose(suggestion),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
