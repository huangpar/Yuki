import 'package:flutter/material.dart';

import '../models/support_ticket.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Problems you reported, and where each one got to.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<SupportTicket>? _tickets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tickets = await SupabaseService.instance.getMyTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your reports. Check your connection.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _tickets;

    return Scaffold(
      appBar: AppBar(title: Text('My reports', style: AppTypography.h3)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: tickets == null && _error == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : tickets == null
                  ? _Empty(
                      icon: Icons.cloud_off,
                      title: _error!,
                      action: ElevatedButton(onPressed: _load, child: const Text('Try again')),
                    )
                  : tickets.isEmpty
                      ? const _Empty(
                          icon: Icons.flag_outlined,
                          title: 'Nothing reported',
                          body: 'If a job goes wrong, use "Report a problem" on that booking.',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: tickets.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                            itemBuilder: (_, i) => TicketCard(ticket: tickets[i]),
                          ),
                        ),
        ),
      ),
    );
  }
}

/// One ticket, as the person who raised it sees it. The admin view adds to this.
class TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final Widget? footer;

  const TicketCard({super.key, required this.ticket, this.footer});

  @override
  Widget build(BuildContext context) {
    final created = ticket.createdAt;
    final note = ticket.adminNote;

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
              Expanded(child: Text(ticket.categoryLabel, style: AppTypography.h3)),
              StatusPill(
                label: ticket.statusLabel,
                color: ticket.isOpen ? AppColors.accentDark : AppColors.success,
              ),
            ],
          ),
          if (ticket.reporterName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              [ticket.reporterName, ticket.reporterEmail].whereType<String>().join(' · '),
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (created != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reported ${formatWhen(context, created)}',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(ticket.message, style: AppTypography.bodyMedium),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From Yuki',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(note, style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  const _Empty({required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                body!,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
