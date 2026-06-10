import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/maintenance_request.dart';
import 'package:galaxy_truck/services/maintenance_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MaintenanceRequestsScreen extends StatefulWidget {
  const MaintenanceRequestsScreen({super.key});

  @override
  State<MaintenanceRequestsScreen> createState() => _MaintenanceRequestsScreenState();
}

class _MaintenanceRequestsScreenState extends State<MaintenanceRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MaintenanceService>().loadMaintenanceRequests();
      context.read<TruckService>().loadTrucks();
    });
  }

  Future<void> _approve(MaintenanceRequest r) async {
    try {
      await context.read<MaintenanceService>().approveMaintenanceRequest(r.id, 'admin');
      await context.read<MaintenanceService>().loadMaintenanceRequests();
    } catch (e) {
      debugPrint('Failed to approve maintenance request: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve.')));
    }
  }

  Future<void> _reject(MaintenanceRequest r) async {
    final cs = Theme.of(context).colorScheme;
    final reasonCtrl = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reject maintenance request', style: context.textStyles.titleLarge?.semiBold),
            const SizedBox(height: 8),
            TextField(controller: reasonCtrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Reason')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(reasonCtrl.text.trim()),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: Text('Reject', style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        ),
      ),
    );
    if (reason == null || reason.isEmpty) return;

    try {
      await context.read<MaintenanceService>().rejectMaintenanceRequest(r.id, reason);
      await context.read<MaintenanceService>().loadMaintenanceRequests();
    } catch (e) {
      debugPrint('Failed to reject maintenance request: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = context.watch<MaintenanceService>();
    final trucks = context.watch<TruckService>();
    final cs = Theme.of(context).colorScheme;
    final items = [...maintenance.maintenanceRequests]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: Text('Maintenance Requests', style: context.textStyles.titleLarge?.semiBold)),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_circle_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No maintenance requests', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
            )
          : ListView.builder(
              padding: AppSpacing.paddingMd,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                final truck = trucks.getTruckById(r.truckId);
                final urgent = r.urgencyLevel != UrgencyLevel.normal;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: urgent ? cs.errorContainer : cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                              child: Icon(Icons.build_circle_outlined, color: urgent ? cs.error : cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(truck?.displayName ?? 'Truck ${r.truckId}', style: context.textStyles.titleMedium?.semiBold),
                                  const SizedBox(height: 2),
                                  Text('Category: ${r.category.name}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  Text('Driver: ${r.driverId}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  Text('Created: ${DateFormat('dd MMM yyyy, h:mm a').format(r.createdAt)}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
                              child: Text(r.status.name.toUpperCase(), style: context.textStyles.labelSmall?.semiBold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(r.issueDescription, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: r.isPending ? () => _approve(r) : null,
                                icon: Icon(Icons.check, color: cs.onPrimary),
                                label: Text('Approve', style: TextStyle(color: cs.onPrimary)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: r.isPending ? () => _reject(r) : null,
                                icon: Icon(Icons.close, color: cs.error),
                                label: Text('Reject', style: TextStyle(color: cs.error)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
