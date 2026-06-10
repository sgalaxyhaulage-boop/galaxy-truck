import 'package:flutter/material.dart';
import 'package:galaxy_truck/services/inspection_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GpsTrackingScreen extends StatefulWidget {
  const GpsTrackingScreen({super.key});

  @override
  State<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends State<GpsTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<RentalService>().loadRentals();
      await context.read<TruckService>().loadTrucks();
      await context.read<InspectionService>().loadInspections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rentals = context.watch<RentalService>();
    final trucks = context.watch<TruckService>();
    final inspections = context.watch<InspectionService>();
    final cs = Theme.of(context).colorScheme;

    final active = rentals.activeRentals..sort((a, b) => (b.startedAt ?? b.requestedAt).compareTo(a.startedAt ?? a.requestedAt));

    return Scaffold(
      appBar: AppBar(title: Text('GPS Tracking', style: context.textStyles.titleLarge?.semiBold)),
      body: active.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No active rentals', style: context.textStyles.titleMedium?.semiBold),
                  const SizedBox(height: 6),
                  Text('Tracking cards will appear when trucks are rented.', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: AppSpacing.paddingMd,
              itemCount: active.length,
              itemBuilder: (context, i) {
                final r = active[i];
                final truck = trucks.getTruckById(r.truckId);

                // Use pickup inspection location if available.
                final pickup = r.pickupInspectionId == null ? null : inspections.getInspectionById(r.pickupInspectionId!);
                final lat = pickup?.latitude;
                final lon = pickup?.longitude;

                final locationText = (lat == null || lon == null || (lat == 0 && lon == 0))
                    ? 'Location not captured yet'
                    : '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

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
                          child: Icon(Icons.location_on_outlined, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(truck?.displayName ?? 'Truck ${r.truckId}', style: context.textStyles.titleMedium?.semiBold),
                              const SizedBox(height: 2),
                              Text('Driver: ${r.driverId}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              Text('Started: ${r.startedAt == null ? '—' : DateFormat('dd MMM yyyy, h:mm a').format(r.startedAt!)}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              Text(locationText, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
