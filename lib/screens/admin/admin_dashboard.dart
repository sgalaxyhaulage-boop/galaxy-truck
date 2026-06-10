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
      appBar: AppBar(
        title: Text('Admin Dashboard', style: context.textStyles.titleLarge?.semiBold),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fleet Overview',
              style: context.textStyles.titleLarge?.semiBold,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 900 ? 3 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: crossAxisCount == 3 ? 1.8 : 1.4,
                  children: [
                    _buildStatCard(context, 'Total Trucks', totalTrucks.toString(), Icons.local_shipping, Theme.of(context).colorScheme.primary),
                    _buildStatCard(context, 'Trucks In Use', inUseTrucks.toString(), Icons.route, Theme.of(context).colorScheme.secondary),
                    _buildStatCard(context, 'Available', availableTrucks.toString(), Icons.check_circle, Theme.of(context).colorScheme.tertiary),
                    _buildStatCard(context, 'On Rent', rentedTrucks.toString(), Icons.key, LightModeColors.lightSecondary),
                    _buildStatCard(context, 'In Service', inServiceTrucks.toString(), Icons.build, Theme.of(context).colorScheme.error),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            _DashboardSection(
              title: 'Recent Inspections',
              icon: Icons.fact_check,
              child: _RecentInspectionsList(query: _firestore.collection('inspections').orderBy('createdAt', descending: true).limit(10)),
            ),
            const SizedBox(height: 16),
            _DashboardSection(
              title: 'Active Rentals',
              icon: Icons.assignment,
              child: _ActiveRentalsList(query: _firestore.collection('rentals').orderBy('createdAt', descending: true).limit(10)),
            ),
            const SizedBox(height: 16),
            _DashboardSection(
              title: 'Maintenance Requests',
              icon: Icons.build_circle,
              child: _MaintenanceRequestsList(query: _firestore.collection('maintenance_requests').orderBy('createdAt', descending: true).limit(10)),
            ),

            const SizedBox(height: 32),
            Text(
              'Pending Actions',
              style: context.textStyles.titleLarge?.semiBold,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              'Rental Approvals',
              pendingRentals.toString(),
              Icons.approval,
              () => context.push('/admin/rentals'),
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              context,
              'Damage Reports',
              pendingDamage.toString(),
              Icons.warning_amber,
              () => context.push('/admin/damage-reports'),
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              context,
              'Maintenance Requests',
              pendingMaintenance.toString(),
              Icons.build_circle,
              () => context.push('/admin/maintenance'),
            ),
            const SizedBox(height: 32),
            Text(
              'Fleet Management',
              style: context.textStyles.titleLarge?.semiBold,
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildServiceCard(context, 'Manage Trucks', Icons.local_shipping, () => context.push('/admin/trucks')),
                _buildServiceCard(context, 'Manage Drivers', Icons.people, () => context.push('/admin/drivers')),
                _buildServiceCard(context, 'GPS Tracking', Icons.map, () => context.push('/admin/gps-tracking')),
                _buildServiceCard(context, 'Reports', Icons.assessment, () => context.push('/admin/reports')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: context.textStyles.headlineMedium?.semiBold.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String count, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: context.textStyles.titleMedium?.semiBold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  count,
                  style: context.textStyles.bodyMedium?.semiBold.copyWith(
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: context.textStyles.bodyMedium?.semiBold,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DashboardSection({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: context.textStyles.titleMedium?.semiBold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _RecentInspectionsList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  const _RecentInspectionsList({required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _InlineError(text: 'Failed to load inspections.');
        }
        if (!snap.hasData) {
          return const _InlineLoading();
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _InlineEmpty(text: 'No inspections yet.');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final truckId = (data['truckId'] ?? '').toString();
            final driverId = (data['driverId'] ?? '').toString();
            final fuel = _asDouble(data['fuelLevel']);
            final createdAt = _asDateTime(data['createdAt'] ?? data['timestamp']);
            final type = (data['type'] ?? '').toString();

            final fuelPct = (fuel.isNaN ? null : (fuel.clamp(0, 1) * 100).round());
            final dateStr = createdAt == null ? '—' : _formatDateTime(context, createdAt);

            return _CompactTile(
              leadingIcon: Icons.fact_check,
              title: 'Truck: ${truckId.isEmpty ? '—' : truckId}',
              subtitle: 'Driver: ${driverId.isEmpty ? '—' : driverId} • Fuel: ${fuelPct == null ? '—' : '$fuelPct%'} • ${type.isEmpty ? '' : '${type.toUpperCase()} • '}$dateStr',
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
        if (snap.hasError) {
          return _InlineError(text: 'Failed to load rentals.');
        }
        if (!snap.hasData) {
          return const _InlineLoading();
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _InlineEmpty(text: 'No rentals found.');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final driverId = (data['driverId'] ?? '').toString();
            final truckId = (data['truckId'] ?? '').toString();
            final status = (data['status'] ?? '').toString();
            final createdAt = _asDateTime(data['createdAt'] ?? data['requestedAt']);
            final dateStr = createdAt == null ? '—' : _formatDateTime(context, createdAt);

            final isActive = status.toLowerCase() == 'active';
            final statusColor = isActive ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurfaceVariant;

            return _CompactTile(
              leadingIcon: Icons.assignment,
              title: 'Driver: ${driverId.isEmpty ? '—' : driverId}',
              subtitle: 'Truck: ${truckId.isEmpty ? '—' : truckId} • ${status.isEmpty ? '—' : status.toUpperCase()} • $dateStr',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  status.isEmpty ? '—' : status.toUpperCase(),
                  style: context.textStyles.labelMedium?.semiBold.copyWith(color: statusColor),
                ),
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
        if (snap.hasError) {
          return _InlineError(text: 'Failed to load maintenance requests.');
        }
        if (!snap.hasData) {
          return const _InlineLoading();
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _InlineEmpty(text: 'No maintenance requests yet.');
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final truckId = (data['truckId'] ?? '').toString();
            final status = (data['status'] ?? '').toString();
            final desc = (data['issueDescription'] ?? data['description'] ?? '').toString();
            final createdAt = _asDateTime(data['createdAt']);
            final dateStr = createdAt == null ? '—' : _formatDateTime(context, createdAt);

            final statusColor = _maintenanceStatusColor(context, status);

            return _CompactTile(
              leadingIcon: Icons.build_circle,
              title: 'Truck: ${truckId.isEmpty ? '—' : truckId}',
              subtitle: '${desc.isEmpty ? '—' : desc} • ${status.isEmpty ? '—' : status.toUpperCase()} • $dateStr',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  status.isEmpty ? '—' : status.toUpperCase(),
                  style: context.textStyles.labelMedium?.semiBold.copyWith(color: statusColor),
                ),
              ),
            );
          },
        );
      },
    );
  }
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(leadingIcon, color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textStyles.bodyMedium?.semiBold),
                const SizedBox(height: 4),
                Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Text('Loading…', style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;
  const _InlineEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error));
  }
}

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
  final s = v.toString();
  return DateTime.tryParse(s);
}

String _formatDateTime(BuildContext context, DateTime dt) {
  final date = MaterialLocalizations.of(context).formatShortDate(dt);
  final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(dt), alwaysUse24HourFormat: false);
  return '$date $time';
}

Color _maintenanceStatusColor(BuildContext context, String statusRaw) {
  final s = statusRaw.toLowerCase();
  if (s.contains('rejected')) return Theme.of(context).colorScheme.error;
  if (s.contains('completed') || s.contains('pickedup') || s.contains('picked_up')) return Theme.of(context).colorScheme.tertiary;
  if (s.contains('urgent') || s.contains('unsafe')) return Theme.of(context).colorScheme.error;
  if (s.contains('approved') || s.contains('scheduled') || s.contains('service')) return Theme.of(context).colorScheme.secondary;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
