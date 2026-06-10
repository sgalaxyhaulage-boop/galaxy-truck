import 'package:flutter/material.dart';
import 'package:galaxy_truck/services/damage_service.dart';
import 'package:galaxy_truck/services/maintenance_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rentals = context.watch<RentalService>();
    final trucks = context.watch<TruckService>();
    final maintenance = context.watch<MaintenanceService>();
    final damage = context.watch<DamageService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Reports', style: context.textStyles.titleLarge?.semiBold)),
      body: ListView(
        padding: AppSpacing.paddingMd,
        children: [
          Card(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(Icons.assessment_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This section summarizes fleet activity from Firestore. PDF exports can be added next.',
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(label: 'Total trucks', value: '${trucks.trucks.length}', icon: Icons.local_shipping_outlined),
          const SizedBox(height: 12),
          _MetricCard(label: 'Active rentals', value: '${rentals.activeRentals.length}', icon: Icons.key_outlined),
          const SizedBox(height: 12),
          _MetricCard(label: 'Pending rentals', value: '${rentals.pendingRentals.length}', icon: Icons.approval_outlined),
          const SizedBox(height: 12),
          _MetricCard(label: 'Pending maintenance', value: '${maintenance.pendingRequests.length}', icon: Icons.build_circle_outlined),
          const SizedBox(height: 12),
          _MetricCard(label: 'Pending damage', value: '${damage.pendingReports.length}', icon: Icons.warning_amber_rounded),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: context.textStyles.titleMedium?.semiBold)),
            Text(value, style: context.textStyles.headlineSmall?.semiBold.copyWith(color: cs.primary)),
          ],
        ),
      ),
    );
  }
}
