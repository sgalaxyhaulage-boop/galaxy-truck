import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/rental.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RentalHistoryScreen extends StatefulWidget {
  const RentalHistoryScreen({super.key});

  @override
  State<RentalHistoryScreen> createState() => _RentalHistoryScreenState();
}

class _RentalHistoryScreenState extends State<RentalHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RentalService>().loadRentals();
      context.read<TruckService>().loadTrucks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final rentals = context.watch<RentalService>();
    final trucks = context.watch<TruckService>();
    final user = auth.currentUser;
    final cs = Theme.of(context).colorScheme;

    final items = user == null
        ? const <Rental>[]
        : rentals.getRentalsByDriver(user.id)
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    return Scaffold(
      appBar: AppBar(title: Text('Rental History', style: context.textStyles.titleLarge?.semiBold)),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No rentals yet', style: context.textStyles.titleMedium?.semiBold),
                  const SizedBox(height: 6),
                  Text('Your completed and active rentals will appear here.', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: AppSpacing.paddingMd,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                final truck = trucks.getTruckById(r.truckId);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                          child: Icon(Icons.local_shipping_outlined, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(truck?.displayName ?? 'Truck', style: context.textStyles.titleMedium?.semiBold),
                              const SizedBox(height: 2),
                              Text(
                                'Requested: ${DateFormat('dd MMM yyyy, h:mm a').format(r.requestedAt)}',
                                style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              if (r.startedAt != null)
                                Text(
                                  'Started: ${DateFormat('dd MMM yyyy, h:mm a').format(r.startedAt!)}',
                                  style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              if (r.completedAt != null)
                                Text(
                                  'Completed: ${DateFormat('dd MMM yyyy, h:mm a').format(r.completedAt!)}',
                                  style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        _RentalStatusPill(status: r.status),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _RentalStatusPill extends StatelessWidget {
  final RentalStatus status;
  const _RentalStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      RentalStatus.active => (cs.tertiaryContainer, cs.onTertiaryContainer),
      RentalStatus.approved => (cs.secondaryContainer, cs.onSecondaryContainer),
      RentalStatus.completed => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      RentalStatus.rejected => (cs.errorContainer, cs.onErrorContainer),
      RentalStatus.cancelled => (cs.errorContainer, cs.onErrorContainer),
      RentalStatus.requested => (cs.primaryContainer, cs.onPrimaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.name.toUpperCase(), style: context.textStyles.labelSmall?.semiBold.copyWith(color: fg)),
    );
  }
}
