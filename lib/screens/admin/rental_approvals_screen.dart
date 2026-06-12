import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/rental.dart';
import 'package:galaxy_truck/services/driver_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RentalApprovalsScreen extends StatefulWidget {
  const RentalApprovalsScreen({super.key});

  @override
  State<RentalApprovalsScreen> createState() => _RentalApprovalsScreenState();
}

class _RentalApprovalsScreenState extends State<RentalApprovalsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<RentalService>().loadRentals();
      await context.read<TruckService>().loadTrucks();
      await context.read<DriverService>().loadDrivers();
    });
  }

  Future<void> _approve(String rentalId) async {
    setState(() => _loading = true);
    try {
      await context.read<RentalService>().approveRental(rentalId);
      await context.read<RentalService>().loadRentals();
    } catch (e) {
      debugPrint('Failed to approve rental: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject(String rentalId) async {
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
            Text('Reject rental request', style: context.textStyles.titleLarge?.semiBold),
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

    setState(() => _loading = true);
    try {
      await context.read<RentalService>().rejectRental(rentalId, reason);
      await context.read<RentalService>().loadRentals();
    } catch (e) {
      debugPrint('Failed to reject rental: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rentals = context.watch<RentalService>();
    final trucks = context.watch<TruckService>();
    final driverSvc = context.watch<DriverService>();
    final cs = Theme.of(context).colorScheme;
    final pending = rentals.pendingRentals..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    return Scaffold(
      appBar: AppBar(title: Text('Rental Approvals', style: context.textStyles.titleLarge?.semiBold)),
      body: pending.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.approval_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No pending rentals', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
            )
          : ListView.builder(
              padding: AppSpacing.paddingMd,
              itemCount: pending.length,
              itemBuilder: (context, i) {
                final r = pending[i];
                final truck = trucks.getTruckById(r.truckId);
                final driverName = driverSvc.getDriverByUserId(r.driverId)?.fullName ?? r.driverId;
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
                              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                              child: Icon(Icons.local_shipping_outlined, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(truck?.displayName ?? 'Truck ${r.truckId}', style: context.textStyles.titleMedium?.semiBold),
                                  const SizedBox(height: 2),
                                  Text('Driver: $driverName', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  Text('Requested: ${DateFormat('dd MMM yyyy, h:mm a').format(r.requestedAt)}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _loading ? null : () => _approve(r.id),
                                icon: Icon(Icons.check, color: cs.onPrimary),
                                label: Text('Approve', style: TextStyle(color: cs.onPrimary)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : () => _reject(r.id),
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
