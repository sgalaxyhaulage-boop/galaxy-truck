import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/services/notification_service.dart';
import 'package:galaxy_truck/theme.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final rentalService = context.watch<RentalService>();
    final truckService = context.watch<TruckService>();
    final notificationService = context.watch<NotificationService>();
    
    final currentUser = authService.currentUser;
    final activeRental = rentalService.getActiveRentalByDriver(currentUser?.id ?? '');
    final assignedTruck = activeRental != null ? truckService.getTruckById(activeRental.truckId) : null;
    final unreadCount = notificationService.getUnreadCount(currentUser?.id ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text('Galaxy Truck', style: context.textStyles.titleLarge?.semiBold),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/driver/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
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
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.fullName ?? '',
                    style: context.textStyles.headlineMedium?.semiBold.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (assignedTruck != null) ...[
              _buildSectionTitle(context, 'Current Truck'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              Icons.local_shipping,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignedTruck.displayName,
                                  style: context.textStyles.titleMedium?.semiBold,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rego: ${assignedTruck.registrationNumber}',
                                  style: context.textStyles.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/driver/return-truck'),
                        icon: const Icon(Icons.assignment_return, color: Colors.white),
                        label: const Text('Return Truck', style: TextStyle(color: Colors.white)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              _buildSectionTitle(context, 'Quick Actions'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/driver/pickup-truck'),
                    icon: const Icon(Icons.local_shipping, color: Colors.white),
                    label: const Text('Pick Up Truck', style: TextStyle(color: Colors.white)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle(context, 'Services'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildServiceCard(
                  context,
                  'Report Damage',
                  Icons.warning_amber_rounded,
                  () => context.push('/driver/report-damage'),
                ),
                _buildServiceCard(
                  context,
                  'Request Service',
                  Icons.build_circle_outlined,
                  () => context.push('/driver/request-maintenance'),
                ),
                _buildServiceCard(
                  context,
                  'My Profile',
                  Icons.person_outline,
                  () => context.push('/driver/profile'),
                ),
                _buildServiceCard(
                  context,
                  'Rental History',
                  Icons.history,
                  () => context.push('/driver/rental-history'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: context.textStyles.titleLarge?.semiBold,
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
              Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
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
