import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/damage_service.dart';
import 'package:galaxy_truck/services/maintenance_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:galaxy_truck/models/truck.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final truckService = context.watch<TruckService>();
    final rentalService = context.watch<RentalService>();
    final damageService = context.watch<DamageService>();
    final maintenanceService = context.watch<MaintenanceService>();

    final totalTrucks = truckService.trucks.length;
    final availableTrucks = truckService.availableTrucks.length;
    final inUseTrucks = truckService.trucks.where((t) => t.status != TruckStatus.available).length;
    final rentedTrucks = truckService.rentedTrucks.length;
    final inServiceTrucks = truckService.trucks.where((t) => t.status == TruckStatus.inService).length;
    final pendingRentals = rentalService.pendingRentals.length;
    final pendingDamage = damageService.pendingReports.length;
    final pendingMaintenance = maintenanceService.pendingRequests.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF9260)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Galaxy Truck', style: context.textStyles.titleLarge?.semiBold),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await authService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMd,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Welcome banner ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2A4F7C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Dashboard', style: TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$totalTrucks trucks · $availableTrucks available · $pendingRentals pending',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              )),
            ]),
          ),

          const SizedBox(height: 20),
          _sectionLabel(context, 'Fleet Overview'),
          const SizedBox(height: 12),

          // ── Stat grid ─────────────────────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth >= 900 ? 3 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: cols == 3 ? 1.8 : 1.4,
              children: [
                _statCard(context, 'Total Trucks',  totalTrucks.toString(),     Icons.local_shipping_rounded, const Color(0xFFFF6B35)),
                _statCard(context, 'In Use',         inUseTrucks.toString(),     Icons.route_rounded,          const Color(0xFF4F8EF7)),
                _statCard(context, 'Available',      availableTrucks.toString(), Icons.check_circle_rounded,   const Color(0xFF28A745)),
                _statCard(context, 'On Rent',        rentedTrucks.toString(),    Icons.vpn_key_rounded,        const Color(0xFF9B59B6)),
                _statCard(context, 'In Service',     inServiceTrucks.toString(), Icons.build_rounded,          const Color(0xFFE74C3C)),
              ],
            );
          }),

          const SizedBox(height: 24),
          _sectionLabel(context, 'Recent Activity'),
          const SizedBox(height: 12),
          _DashboardSection(
            title: 'Recent Inspections',
            icon: Icons.fact_check_rounded,
            child: _RecentInspectionsList(
              query: _firestore.collection('inspections')
                .orderBy('createdAt', descending: true).limit(10)),
          ),
          const SizedBox(height: 12),
          _DashboardSection(
            title: 'Active Rentals',
            icon: Icons.assignment_rounded,
            child: _ActiveRentalsList(
              query: _firestore.collection('rentals')
                .orderBy('createdAt', descending: true).limit(10)),
          ),
          const SizedBox(height: 12),
          _DashboardSection(
            title: 'Maintenance Requests',
            icon: Icons.build_circle_rounded,
            child: _MaintenanceRequestsList(
              query: _firestore.collection('maintenance_requests')
                .orderBy('createdAt', descending: true).limit(10)),
          ),

          const SizedBox(height: 24),
          _sectionLabel(context, 'Pending Actions'),
          const SizedBox(height: 12),
          _actionCard(context, 'Rental Approvals',     pendingRentals.toString(),    Icons.approval_rounded,       () => context.push('/admin/rentals')),
          const SizedBox(height: 10),
          _actionCard(context, 'Damage Reports',       pendingDamage.toString(),     Icons.warning_amber_rounded,  () => context.push('/admin/damage-reports')),
          const SizedBox(height: 10),
          _actionCard(context, 'Maintenance Requests', pendingMaintenance.toString(),Icons.build_circle_rounded,   () => context.push('/admin/maintenance')),

          const SizedBox(height: 24),
          _sectionLabel(context, 'Fleet Management'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _serviceCard(context, 'Manage Trucks',  Icons.local_shipping_rounded, const Color(0xFFFF6B35), () => context.push('/admin/trucks')),
              _serviceCard(context, 'Manage Drivers', Icons.people_rounded,         const Color(0xFF4F8EF7), () => context.push('/admin/drivers')),
              _serviceCard(context, 'GPS Tracking',   Icons.map_rounded,            const Color(0xFF28A745), () => context.push('/admin/gps-tracking')),
              _serviceCard(context, 'Reports',        Icons.assessment_rounded,     const Color(0xFF9B59B6), () => context.push('/admin/reports')),
            ],
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF9260)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(2),
      )),
      const SizedBox(width: 10),
      Text(title, style: context.textStyles.titleMedium?.semiBold),
    ]);
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(
          color: color.withOpacity(0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: context.textStyles.headlineMedium?.semiBold.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: context.textStyles.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, String title, String count, IconData icon, VoidCallback onTap) {
    final n = int.tryParse(count) ?? 0;
    final badgeColor = n > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF9260)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: context.textStyles.titleMedium?.semiBold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(count, style: context.textStyles.labelLarge?.semiBold.copyWith(color: badgeColor)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  Widget _serviceCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: context.textStyles.titleSmall?.semiBold, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _DashboardSection({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title, style: context.textStyles.titleMedium?.semiBold),
          ]),
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream-based lists (logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentInspectionsList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  const _RecentInspectionsList({required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _InlineError(text: 'Failed to load inspections.');
        if (!snap.hasData) return const _InlineLoading();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const _InlineEmpty(text: 'No inspections yet.');
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final truckId  = (data['truckId']  ?? '').toString();
            final driverId = (data['driverId'] ?? '').toString();
            final fuel     = _asDouble(data['fuelLevel']);
            final createdAt = _asDateTime(data['createdAt'] ?? data['timestamp']);
            final type     = (data['type'] ?? '').toString();
            final fuelPct  = (fuel.isNaN ? null : (fuel.clamp(0, 1) * 100).round());
            final dateStr  = createdAt == null ? '—' : _formatDateTime(context, createdAt);
            final rawPhotos = data['photos'];
            final photos   = <Map<String, String>>[];
            if (rawPhotos is List) {
              for (final p in rawPhotos) {
                if (p is Map) {
                  final label = (p['label'] ?? '').toString();
                  final path  = (p['path']  ?? '').toString();
                  if (path.isNotEmpty) photos.add({'label': label, 'path': path});
                }
              }
            }
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.fact_check, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Truck: ${truckId.isEmpty ? "—" : truckId}', style: context.textStyles.bodyMedium?.semiBold),
                    const SizedBox(height: 4),
                    Text(
                      'Driver: ${driverId.isEmpty ? "—" : driverId}'
                      ' · Fuel: ${fuelPct == null ? "—" : "${fuelPct}%"}'
                      '${type.isEmpty ? "" : " · ${type.toUpperCase()}"}'
                      ' · $dateStr',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ])),
                  if (type.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: type.toLowerCase() == 'pickup'
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(type.toUpperCase(), style: context.textStyles.labelSmall?.semiBold),
                  ),
                ]),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final p = photos[idx];
                        return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _InspectionPhoto(uri: p['path']!),
                          ),
                          const SizedBox(height: 4),
                          Text(p['label'] ?? '',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]);
                      },
                    ),
                  ),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

class _ActiveRentalsList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  const _ActiveRentalsList({required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _InlineError(text: 'Failed to load rentals.');
        if (!snap.hasData) return const _InlineLoading();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const _InlineEmpty(text: 'No rentals found.');
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data     = docs[i].data();
            final driverId = (data['driverId'] ?? '').toString();
            final truckId  = (data['truckId']  ?? '').toString();
            final status   = (data['status']   ?? '').toString();
            final createdAt = _asDateTime(data['createdAt'] ?? data['requestedAt']);
            final dateStr  = createdAt == null ? '—' : _formatDateTime(context, createdAt);
            final statusColor = status.toLowerCase() == 'active'
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.onSurfaceVariant;
            return _CompactTile(
              leadingIcon: Icons.assignment,
              title: 'Driver: ${driverId.isEmpty ? "—" : driverId}',
              subtitle: 'Truck: ${truckId.isEmpty ? "—" : truckId} · ${status.isEmpty ? "—" : status.toUpperCase()} · $dateStr',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(status.isEmpty ? '—' : status.toUpperCase(),
                  style: context.textStyles.labelMedium?.semiBold.copyWith(color: statusColor)),
              ),
            );
          },
        );
      },
    );
  }
}

class _MaintenanceRequestsList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  const _MaintenanceRequestsList({required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _InlineError(text: 'Failed to load maintenance requests.');
        if (!snap.hasData) return const _InlineLoading();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const _InlineEmpty(text: 'No maintenance requests yet.');
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data    = docs[i].data();
            final truckId = (data['truckId'] ?? '').toString();
            final status  = (data['status']  ?? '').toString();
            final desc    = (data['issueDescription'] ?? data['description'] ?? '').toString();
            final createdAt = _asDateTime(data['createdAt']);
            final dateStr = createdAt == null ? '—' : _formatDateTime(context, createdAt);
            final statusColor = _maintenanceStatusColor(context, status);
            return _CompactTile(
              leadingIcon: Icons.build_circle,
              title: 'Truck: ${truckId.isEmpty ? "—" : truckId}',
              subtitle: '${desc.isEmpty ? "—" : desc} · ${status.isEmpty ? "—" : status.toUpperCase()} · $dateStr',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(status.isEmpty ? '—' : status.toUpperCase(),
                  style: context.textStyles.labelMedium?.semiBold.copyWith(color: statusColor)),
              ),
            );
          },
        );
      },
    );
  }
}

class _InspectionPhoto extends StatelessWidget {
  final String uri;
  const _InspectionPhoto({required this.uri});
  @override
  Widget build(BuildContext context) {
    if (uri.startsWith('http')) {
      return Image.network(uri, width: 110, height: 80, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _broken());
    }
    if (uri.startsWith('data:image')) {
      final comma = uri.indexOf(',');
      final b64 = comma == -1 ? '' : uri.substring(comma + 1);
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, width: 110, height: 80, fit: BoxFit.cover);
      } catch (_) { return _broken(); }
    }
    return _broken();
  }
  Widget _broken() => Container(
    color: Colors.black12, width: 110, height: 80,
    child: const Center(child: Icon(Icons.broken_image_outlined)));
}

class _CompactTile extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _CompactTile({required this.leadingIcon, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(leadingIcon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: context.textStyles.bodyMedium?.semiBold),
          const SizedBox(height: 4),
          Text(subtitle, style: context.textStyles.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ]),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 10),
        Text('Loading…', style: context.textStyles.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;
  const _InlineEmpty({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
    style: context.textStyles.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant));
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
    style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error));
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

double _asDouble(dynamic v, {double fallback = double.nan}) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.tryParse(v.toString());
}

String _formatDateTime(BuildContext context, DateTime dt) {
  final date = MaterialLocalizations.of(context).formatShortDate(dt);
  final time = MaterialLocalizations.of(context)
    .formatTimeOfDay(TimeOfDay.fromDateTime(dt), alwaysUse24HourFormat: false);
  return '$date $time';
}

Color _maintenanceStatusColor(BuildContext context, String statusRaw) {
  final s = statusRaw.toLowerCase();
  if (s.contains('rejected')) return Theme.of(context).colorScheme.error;
  if (s.contains('completed') || s.contains('pickedup') || s.contains('picked_up'))
    return Theme.of(context).colorScheme.tertiary;
  if (s.contains('urgent') || s.contains('unsafe'))
    return Theme.of(context).colorScheme.error;
  if (s.contains('approved') || s.contains('scheduled') || s.contains('service'))
    return Theme.of(context).colorScheme.secondary;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
