import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:galaxy_truck/nav.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/services/driver_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/inspection_service.dart';
import 'package:galaxy_truck/services/damage_service.dart';
import 'package:galaxy_truck/services/maintenance_service.dart';
import 'package:galaxy_truck/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:galaxy_truck/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authService = AuthService();
  await authService.initialize();

  final truckService = TruckService();
  await truckService.loadTrucks();

  final driverService = DriverService();
  await driverService.loadDrivers();

  final rentalService = RentalService();
  await rentalService.loadRentals();

  final inspectionService = InspectionService();
  await inspectionService.loadInspections();

  final damageService = DamageService();
  await damageService.loadDamageReports();

  final maintenanceService = MaintenanceService();
  await maintenanceService.loadMaintenanceRequests();

  final notificationService = NotificationService();
  await notificationService.loadNotifications();
  
  runApp(MyApp(
    authService: authService,
    truckService: truckService,
    driverService: driverService,
    rentalService: rentalService,
    inspectionService: inspectionService,
    damageService: damageService,
    maintenanceService: maintenanceService,
    notificationService: notificationService,
  ));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final TruckService truckService;
  final DriverService driverService;
  final RentalService rentalService;
  final InspectionService inspectionService;
  final DamageService damageService;
  final MaintenanceService maintenanceService;
  final NotificationService notificationService;

  const MyApp({
    super.key,
    required this.authService,
    required this.truckService,
    required this.driverService,
    required this.rentalService,
    required this.inspectionService,
    required this.damageService,
    required this.maintenanceService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: truckService),
        ChangeNotifierProvider.value(value: driverService),
        ChangeNotifierProvider.value(value: rentalService),
        ChangeNotifierProvider.value(value: inspectionService),
        ChangeNotifierProvider.value(value: damageService),
        ChangeNotifierProvider.value(value: maintenanceService),
        ChangeNotifierProvider.value(value: notificationService),
      ],
      child: MaterialApp.router(
        title: 'Galaxy Truck Fleet Management',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
