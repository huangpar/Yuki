import 'package:flutter/material.dart';

import '../constants/service_categories.dart';
import '../models/admin_overview.dart';
import '../models/support_ticket.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/error_banner.dart';
import 'my_tickets_screen.dart' show TicketCard, StatusPill;

/// Everything only the people running Yuki can see: how it's being used, what
/// people are telling us, problems to work, and who's waiting to be approved.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin', style: AppTypography.h3),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Feedback'),
              Tab(text: 'Tickets'),
              Tab(text: 'Providers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _FeedbackTab(),
            _TicketsTab(),
            _ProvidersTab(),
          ],
        ),
      ),
    );
  }
}

/// Shared scaffolding: load, show a spinner, show an error with a retry, or
/// hand the loaded value to a builder.
class _Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T value, VoidCallback reload) builder;

  const _Loader({super.key, required this.load, required this.builder});

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  T? _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.load();
      if (!mounted) return;
      setState(() {
        _value = value;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load that. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;

    if (value == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (value == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(_error!),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: widget.builder(context, value, _load),
    );
  }
}

// ---------------------------------------------------------------- Overview

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  String _window = '30d';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '7d', label: Text('7 days')),
              ButtonSegment(value: '30d', label: Text('30 days')),
              ButtonSegment(value: 'all', label: Text('All time')),
            ],
            selected: {_window},
            onSelectionChanged: (values) => setState(() => _window = values.first),
          ),
        ),
        Expanded(
          child: _Loader<AdminOverview>(
            // A new key so switching the window reloads rather than keeps the old numbers.
            key: ValueKey(_window),
            load: () => SupabaseService.instance.getAdminOverview(_window),
            builder: (context, overview, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (overview.openTickets > 0 || overview.newFeedback > 0) ...[
                  _NeedsAttention(overview: overview),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _Section(
                  title: 'People',
                  subtitle: overview.window == 'all'
                      ? 'Everyone, all time'
                      : 'Accounts created in this window; provider counts are current',
                  tiles: [
                    _Stat(label: 'Accounts', value: '${overview.accounts}'),
                    _Stat(label: 'Providers', value: '${overview.providers}'),
                    _Stat(label: 'Verified', value: '${overview.verifiedProviders}'),
                    _Stat(label: 'Available now', value: '${overview.availableNow}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Jobs posted',
                  subtitle: 'How far a posted job gets',
                  tiles: [
                    _Stat(label: 'Posted', value: '${overview.jobsPosted}'),
                    _Stat(label: 'Offers made', value: '${overview.offersMade}'),
                    _Stat(label: 'Matched', value: '${overview.jobsAssigned}'),
                    _Stat(label: 'Match rate', value: _percent(overview.matchRate)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Bookings',
                  subtitle: 'Requests sent straight to a provider from the map',
                  tiles: [
                    _Stat(label: 'Requested', value: '${overview.bookingsRequested}'),
                    _Stat(label: 'Accepted', value: '${overview.bookingsAccepted}'),
                    _Stat(label: 'Completed', value: '${overview.bookingsCompleted}'),
                    _Stat(label: 'Declined', value: '${overview.bookingsDeclined}'),
                    _Stat(label: 'Accepted', value: _percent(overview.acceptanceRate)),
                    _Stat(label: 'Completed', value: _percent(overview.completionRate)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Reviews',
                  subtitle: 'Written in this window, both directions',
                  tiles: [_Stat(label: 'Reviews', value: '${overview.reviewsWritten}')],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _percent(int? value) => value == null ? '—' : '$value%';
}

class _NeedsAttention extends StatelessWidget {
  final AdminOverview overview;

  const _NeedsAttention({required this.overview});

  @override
  Widget build(BuildContext context) {
    final waiting = [
      if (overview.openTickets > 0)
        '${overview.openTickets} open ${overview.openTickets == 1 ? 'ticket' : 'tickets'}',
      if (overview.newFeedback > 0) '${overview.newFeedback} unread feedback',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentDark.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.accentDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Waiting on you: $waiting',
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_Stat> tiles;

  const _Section({required this.title, required this.subtitle, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: tiles),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTypography.h2.copyWith(color: AppColors.primary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Feedback

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  String _status = 'new';
  final Set<String> _busy = {};

  Future<void> _setStatus(FeedbackItem item, String status, VoidCallback reload) async {
    setState(() => _busy.add(item.id));
    try {
      await SupabaseService.instance.updateFeedback(item.id, status: status);
      reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Filter(
          options: const {'new': 'New', 'read': 'Read', 'resolved': 'Resolved', 'all': 'All'},
          selected: _status,
          onChanged: (value) => setState(() => _status = value),
        ),
        Expanded(
          child: _Loader<List<FeedbackItem>>(
            key: ValueKey(_status),
            load: () => SupabaseService.instance.getAdminFeedback(_status),
            builder: (context, items, reload) {
              if (items.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Nothing here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final busy = _busy.contains(item.id);
                  return _FeedbackCard(
                    item: item,
                    busy: busy,
                    onRead: busy ? null : () => _setStatus(item, 'read', reload),
                    onResolve: busy ? null : () => _setStatus(item, 'resolved', reload),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackItem item;
  final bool busy;
  final VoidCallback? onRead;
  final VoidCallback? onResolve;

  const _FeedbackCard({
    required this.item,
    required this.busy,
    this.onRead,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final created = item.createdAt;

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
              Expanded(child: Text(item.categoryLabel, style: AppTypography.h3)),
              StatusPill(
                label: item.status == 'new' ? 'New' : (item.status == 'read' ? 'Read' : 'Resolved'),
                color: item.status == 'new' ? AppColors.accentDark : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              item.fromName?.isNotEmpty == true ? item.fromName : null,
              item.fromEmail,
              if (created != null) formatWhen(context, created),
            ].whereType<String>().join(' · '),
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (item.context != null && item.context!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sent from ${item.context}',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(item.message, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (item.status == 'new')
                OutlinedButton(onPressed: onRead, child: const Text('Mark read')),
              if (item.status != 'resolved') ...[
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton(onPressed: onResolve, child: const Text('Resolve')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Tickets

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  String _status = 'open';
  final Set<String> _busy = {};

  Future<void> _update(
    SupportTicket ticket,
    VoidCallback reload, {
    String? status,
    String? note,
  }) async {
    setState(() => _busy.add(ticket.id));
    try {
      await SupabaseService.instance.updateTicket(ticket.id, status: status, adminNote: note);
      reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(ticket.id));
    }
  }

  Future<void> _addNote(SupportTicket ticket, VoidCallback reload) async {
    final controller = TextEditingController(text: ticket.adminNote ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reply to the reporter', style: AppTypography.h3),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'They see this on their report',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null) await _update(ticket, reload, note: note);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Filter(
          options: const {
            'open': 'Open',
            'in_progress': 'In progress',
            'resolved': 'Resolved',
            'all': 'All',
          },
          selected: _status,
          onChanged: (value) => setState(() => _status = value),
        ),
        Expanded(
          child: _Loader<List<SupportTicket>>(
            key: ValueKey(_status),
            load: () => SupabaseService.instance.getAdminTickets(_status),
            builder: (context, tickets, reload) {
              if (tickets.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Nothing here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: tickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, i) {
                  final ticket = tickets[i];
                  final busy = _busy.contains(ticket.id);
                  return TicketCard(
                    ticket: ticket,
                    footer: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _addNote(ticket, reload),
                          icon: const Icon(Icons.reply, size: 16),
                          label: Text(ticket.adminNote == null ? 'Reply' : 'Edit reply'),
                        ),
                        if (ticket.status == 'open')
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _update(ticket, reload, status: 'in_progress'),
                            child: const Text('Start'),
                          ),
                        if (ticket.isOpen)
                          ElevatedButton(
                            onPressed:
                                busy ? null : () => _update(ticket, reload, status: 'resolved'),
                            child: const Text('Resolve'),
                          ),
                        if (ticket.status != 'closed')
                          TextButton(
                            onPressed:
                                busy ? null : () => _update(ticket, reload, status: 'closed'),
                            child: const Text('Close'),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Providers

class _ProvidersTab extends StatefulWidget {
  const _ProvidersTab();

  @override
  State<_ProvidersTab> createState() => _ProvidersTabState();
}

class _ProvidersTabState extends State<_ProvidersTab> {
  String _verified = 'false';
  final Set<String> _busy = {};

  Future<void> _setVerified(AdminProvider provider, bool verified, VoidCallback reload) async {
    if (!verified) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Remove approval?', style: AppTypography.h3),
          content: Text(
            '${provider.name} will stop appearing on the map and cannot take new work.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove approval'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy.add(provider.id));
    try {
      await SupabaseService.instance.setProviderVerification(provider.id, verified);
      reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              verified
                  ? '${provider.name} can now take work.'
                  : '${provider.name} is no longer approved.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(provider.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Filter(
          options: const {'false': 'Waiting', 'true': 'Approved', 'all': 'All'},
          selected: _verified,
          onChanged: (value) => setState(() => _verified = value),
        ),
        Expanded(
          child: _Loader<List<AdminProvider>>(
            key: ValueKey(_verified),
            load: () => SupabaseService.instance.getAdminProviders(_verified),
            builder: (context, providers, reload) {
              if (providers.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        _verified == 'false' ? 'Nobody is waiting.' : 'Nothing here.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: providers.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, i) {
                  final provider = providers[i];
                  final busy = _busy.contains(provider.id);
                  return _ProviderCard(
                    provider: provider,
                    busy: busy,
                    onChanged: (verified) => _setVerified(provider, verified, reload),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final AdminProvider provider;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _ProviderCard({
    required this.provider,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rate = provider.hourlyRate;
    final details = [
      if (rate != null) '\$${rate.toStringAsFixed(0)}/hr',
      if (provider.categories.isNotEmpty) provider.categories.map(categoryLabel).join(', '),
      if (provider.reviewCount > 0)
        '${provider.rating!.toStringAsFixed(1)}★ (${provider.reviewCount})',
    ].join(' · ');
    final bio = provider.bio;

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
              Expanded(child: Text(provider.name, style: AppTypography.h3)),
              StatusPill(
                label: provider.isVerified ? 'Approved' : 'Waiting',
                color: provider.isVerified ? AppColors.success : AppColors.accentDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [provider.email, provider.phone].whereType<String>().join(' · '),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(details, style: AppTypography.bodyMedium),
          ],
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(bio, style: AppTypography.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          provider.isVerified
              ? OutlinedButton(
                  onPressed: busy ? null : () => onChanged(false),
                  child: const Text('Remove approval'),
                )
              : ElevatedButton.icon(
                  onPressed: busy ? null : () => onChanged(true),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Approve for work'),
                ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _Filter({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          for (final entry in options.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              selectedColor: AppColors.primary.withOpacity(0.15),
              onSelected: (_) => onChanged(entry.key),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
