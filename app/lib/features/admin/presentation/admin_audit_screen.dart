import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_time_format.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../orders/presentation/order_labels.dart';
import '../application/admin_providers.dart';
import '../domain/audit_entry.dart';
import 'admin_app_bar.dart';

/// What the staff did, newest first. For the `admin` role only (the database
/// refuses everybody else).
class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final log = ref.watch(auditLogProvider);
    return Scaffold(
      appBar: AdminAppBar(
        title: l10n.adminAuditTitle,
        leading: IconButton(
          tooltip: l10n.adminBackToOrders,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: log.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) =>
            ErrorView(onRetry: () => ref.invalidate(auditLogProvider)),
        data: (entries) => entries.isEmpty
            ? EmptyView(
                icon: Icons.history_rounded,
                title: l10n.adminAuditEmpty,
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _AuditTile(entries[index]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile(this.entry);

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final from = entry.fromStatus;
    final to = entry.toStatus;
    final text =
        entry.action == 'order.set_status' && from != null && to != null
        ? l10n.adminAuditSetStatus(from.title(l10n), to.title(l10n))
        : l10n.adminAuditOther(entry.action);
    return ListTile(
      title: Text(text),
      subtitle: Text(
        '${formatDate(entry.at)} ${formatClock(entry.at)}'
        '${entry.entityId == null ? '' : ' · ${entry.entity} ${entry.entityId}'}',
      ),
    );
  }
}
