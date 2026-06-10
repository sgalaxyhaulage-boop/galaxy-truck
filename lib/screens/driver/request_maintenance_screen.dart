import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/maintenance_request.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/maintenance_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class RequestMaintenanceScreen extends StatefulWidget {
  const RequestMaintenanceScreen({super.key});

  @override
  State<RequestMaintenanceScreen> createState() => _RequestMaintenanceScreenState();
}

class _RequestMaintenanceScreenState extends State<RequestMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  MaintenanceCategory _category = MaintenanceCategory.generalService;
  UrgencyLevel _urgency = UrgencyLevel.normal;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MaintenanceService>().loadMaintenanceRequests();
      context.read<RentalService>().loadRentals();
    });
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<Position?> _tryGetLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('Failed to get location for maintenance request: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final auth = context.read<AuthService>();
    final rentalService = context.read<RentalService>();
    final maintenanceService = context.read<MaintenanceService>();
    final user = auth.currentUser;
    if (user == null) return;

    final activeRental = rentalService.getActiveRentalByDriver(user.id);
    if (activeRental == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active truck rental found. Pick up a truck first.')),
      );
      return;
    }

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _isSubmitting = true);
    try {
      final pos = await _tryGetLocation();
      final now = DateTime.now();
      final odometer = double.tryParse(_odometerCtrl.text.trim()) ?? 0;

      final req = MaintenanceRequest(
        id: '',
        truckId: activeRental.truckId,
        driverId: user.id,
        category: _category,
        issueDescription: _descCtrl.text.trim(),
        odometer: odometer,
        latitude: pos?.latitude ?? 0,
        longitude: pos?.longitude ?? 0,
        urgencyLevel: _urgency,
        status: MaintenanceStatus.requested,
        createdAt: now,
        updatedAt: now,
      );

      await maintenanceService.createMaintenanceRequest(req);
      await maintenanceService.loadMaintenanceRequests();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance request submitted.')),
      );
      context.pop();
    } catch (e) {
      debugPrint('Failed to submit maintenance request: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Request Service', style: context.textStyles.titleLarge?.semiBold),
      ),
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
                    child: Icon(Icons.build_circle_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Submit a maintenance/service request for your currently assigned truck.',
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<MaintenanceCategory>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: MaintenanceCategory.values
                          .map((c) => DropdownMenuItem(value: c, child: Text(_labelForCategory(c))))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v ?? _category),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UrgencyLevel>(
                      value: _urgency,
                      decoration: const InputDecoration(labelText: 'Urgency'),
                      items: UrgencyLevel.values
                          .map((u) => DropdownMenuItem(value: u, child: Text(_labelForUrgency(u))))
                          .toList(),
                      onChanged: (v) => setState(() => _urgency = v ?? _urgency),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _odometerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Current odometer (km)', hintText: 'e.g. 123456'),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Enter a valid odometer.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: 'Describe the issue', hintText: 'What’s wrong? When did it start?'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Please describe the issue.' : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: Icon(Icons.send, color: cs.onPrimary),
                      label: Text(_isSubmitting ? 'Submitting…' : 'Submit request', style: TextStyle(color: cs.onPrimary)),
                      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _labelForCategory(MaintenanceCategory c) {
  switch (c) {
    case MaintenanceCategory.generalService:
      return 'General service';
    case MaintenanceCategory.tyreReplacement:
      return 'Tyre replacement';
    case MaintenanceCategory.windscreenReplacement:
      return 'Windscreen replacement';
    case MaintenanceCategory.brakeIssue:
      return 'Brake issue';
    case MaintenanceCategory.engineIssue:
      return 'Engine issue';
    case MaintenanceCategory.transmissionIssue:
      return 'Transmission issue';
    case MaintenanceCategory.tailLiftIssue:
      return 'Tail lift issue';
    case MaintenanceCategory.electricalIssue:
      return 'Electrical issue';
    case MaintenanceCategory.airConditioning:
      return 'Air conditioning';
    case MaintenanceCategory.bodyDamageRepair:
      return 'Body damage repair';
    case MaintenanceCategory.other:
      return 'Other';
  }
}

String _labelForUrgency(UrgencyLevel u) {
  switch (u) {
    case UrgencyLevel.normal:
      return 'Normal';
    case UrgencyLevel.urgent:
      return 'Urgent';
    case UrgencyLevel.unsafeToDrive:
      return 'Unsafe to drive';
  }
}
