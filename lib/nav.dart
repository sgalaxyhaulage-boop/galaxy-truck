import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:galaxy_truck/screens/auth/login_screen.dart';
import 'package:galaxy_truck/screens/auth/register_screen.dart';
import 'package:galaxy_truck/screens/driver/driver_dashboard.dart';
import 'package:galaxy_truck/screens/driver/pickup_truck_screen.dart';
import 'package:galaxy_truck/screens/driver/return_truck_screen.dart';
import 'package:galaxy_truck/screens/driver/report_damage_screen.dart';
import 'package:galaxy_truck/screens/driver/request_maintenance_screen.dart';
import 'package:galaxy_truck/screens/driver/driver_profile_screen.dart';
import 'package:galaxy_truck/screens/driver/rental_history_sreen.dart';
import 'package:galaxy_truck/screens/driver/driver_notifications_screen.dart';
import 'package:galaxy_truck/screens/admin/admin_dashboard.dart';
import 'package:galaxy_truck/screens/admin/trucks_screen.dart';
import 'package:galaxy_truck/screens/admin/manage_drivers_screen.dart';
import 'package:galaxy_truck/screens/admin/rental_approvals_screen.dart';
import 'package:galaxy_truck/screens/admin/damage_reports_screen.dart';
import 'package:galaxy_truck/screens/admin/maintenance_requests_screen.dart';
import 'package:galaxy_truck/screens/admin/gps_tracking_screen.dart';
import 'package:galaxy_truck/screens/admin/reports_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(child: const LoginScreen()),
      ),
      GoRoute(
        path: '/driver/dashboard',
        name: 'driver-dashboard',
        pageBuilder: (context, state) => NoTransitionPage(child: const DriverDashboard()),
      ),
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin-dashboard',
        pageBuilder: (context, state) => NoTransitionPage(child: const AdminDashboard()),
      ),
      GoRoute(
        path: '/driver/pickup-truck',
        name: 'pickup-truck',
        pageBuilder: (context, state) => const MaterialPage(child: PickUpTruckScreen()),
      ),
      GoRoute(
        path: '/driver/return-truck',
        name: 'return-truck',
        pageBuilder: (context, state) => const MaterialPage(child: ReturnTruckScreen()),
      ),
      GoRoute(
        path: '/driver/report-damage',
        name: 'report-damage',
        pageBuilder: (context, state) => const MaterialPage(child: ReportDamageScreen()),
      ),
      GoRoute(
        path: '/driver/request-maintenance',
        name: 'request-maintenance',
        pageBuilder: (context, state) => const MaterialPage(child: RequestMaintenanceScreen()),
      ),
            GoRoute(
                      path: '/driver/request-service',
                      name: 'request-service',
                      pageBuilder: (context, state) => const MaterialPage(child: RequestMaintenanceScreen()),
                    ),
      GoRoute(
        path: '/driver/profile',
        name: 'driver-profile',
        pageBuilder: (context, state) => const MaterialPage(child: DriverProfileScreen()),
      ),
      GoRoute(
        path: '/driver/rental-history',
        name: 'rental-history',
        pageBuilder: (context, state) => const MaterialPage(child: RentalHistoryScreen()),
      ),
      GoRoute(
        path: '/driver/notifications',
        name: 'notifications',
        pageBuilder: (context, state) => const MaterialPage(child: DriverNotificationsScreen()),
      ),
      GoRoute(
        path: '/admin/trucks',
        name: 'admin-trucks',
        pageBuilder: (context, state) => const MaterialPage(child: TrucksScreen()),
      ),
      GoRoute(
        path: '/admin/drivers',
        name: 'admin-drivers',
        pageBuilder: (context, state) => const MaterialPage(child: ManageDriversScreen()),
      ),
      GoRoute(
        path: '/admin/rentals',
        name: 'admin-rentals',
        pageBuilder: (context, state) => const MaterialPage(child: RentalApprovalsScreen()),
      ),
      GoRoute(
        path: '/admin/damage-reports',
        name: 'admin-damage',
        pageBuilder: (context, state) => const MaterialPage(child: DamageReportsScreen()),
      ),
      GoRoute(
        path: '/admin/maintenance',
        name: 'admin-maintenance',
        pageBuilder: (context, state) => const MaterialPage(child: MaintenanceRequestsScreen()),
      ),
      GoRoute(
        path: '/admin/gps-tracking',
        name: 'gps-tracking',
        pageBuilder: (context, state) => const MaterialPage(child: GpsTrackingScreen()),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'reports',
        pageBuilder: (context, state) => const MaterialPage(child: ReportsScreen()),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => const MaterialPage(child: RegisterScreen()),
      ),
    ],
  );
}

class AppRoutes {
  static const String login = '/login';
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text('$title Screen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Coming soon...', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
