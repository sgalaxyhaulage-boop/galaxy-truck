import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/damage_report.dart';
import 'package:galaxy_truck/services/damage_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DamageReportsScreen extends StatefulWidget {
  const DamageReportsScreen({super.key});

  @override
  State<DamageReportsScreen> createState() => _DamageReportsScreenState();
}

class _DamageReportsScreenState extends State<DamageReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DamageService>().loadDamageReports();
      context.read<TruckService>().loadTrucks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final damage = context.watch<DamageService>();
    final trucks = context.watch<TruckService>();
    final cs = Theme.of(context).colorScheme;
    final items = [...damage.damageReports]..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

    return Scaffold(
      appBar: AppBar(title: Text('Damage Reports', style: context.textStyles.titleLarge?.semiBold)),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No damage reports', style: context.textStyles.titleMedium?.semiBold),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                              child: Icon(Icons.warning_amber_rounded, color: cs.error),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(truck?.displayName ?? 'Truck ${r.truckId}', style: context.textStyles.titleMedium?.semiBold),
                                  const SizedBox(height: 2),
                                  Text('Type: ${r.damageType.name}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  Text('Driver: ${r.driverId}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  Text('Reported: ${DateFormat('dd MMM yyyy, h:mm a').format(r.reportedAt)}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
                        Text(r.description, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45)),
                        const SizedBox(height: 10),
                        if (r.photoPaths.isNotEmpty)
                          SizedBox(
                            height: 86,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: r.photoPaths.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, idx) {
                                final uri = r.photoPaths[idx];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: _AnyImage(uri: uri),
                                );
                              },
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

class _AnyImage extends StatelessWidget {
  final String uri;
  const _AnyImage({required this.uri});

  @override
  Widget build(BuildContext context) {
    if (uri.startsWith('http')) {
      return Image.network(uri, width: 120, height: 86, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _broken());
    }
    if (uri.startsWith('data:image')) {
      final comma = uri.indexOf(',');
      final b64 = comma == -1 ? '' : uri.substring(comma + 1);
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, width: 120, height: 86, fit: BoxFit.cover);
      } catch (_) {
        return _broken();
      }
    }
    return _broken();
  }

  Widget _broken() => Container(color: Colors.black12, width: 120, height: 86, child: const Center(child: Icon(Icons.broken_image_outlined)));
}
