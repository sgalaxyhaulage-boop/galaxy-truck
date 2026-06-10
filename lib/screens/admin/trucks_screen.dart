import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:galaxy_truck/models/truck.dart';
import 'package:intl/intl.dart';

class TrucksScreen extends StatefulWidget {
  const TrucksScreen({super.key});

  @override
  State<TrucksScreen> createState() => _TrucksScreenState();
}

class _TrucksScreenState extends State<TrucksScreen> {
  String _searchQuery = '';
  TruckStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    // Ensure trucks list is populated for admins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TruckService>().loadTrucks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final truckService = context.watch<TruckService>();
    var trucks = _searchQuery.isEmpty
        ? truckService.trucks
        : truckService.searchTrucks(_searchQuery);

    if (_filterStatus != null) {
      trucks = trucks.where((t) => t.status == _filterStatus).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Trucks', style: context.textStyles.titleLarge?.semiBold),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const _AddTruckSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add truck'),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search trucks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(context, 'All', null),
                      const SizedBox(width: 8),
                      _buildFilterChip(context, 'Available', TruckStatus.available),
                      const SizedBox(width: 8),
                      _buildFilterChip(context, 'Rented', TruckStatus.rented),
                      const SizedBox(width: 8),
                      _buildFilterChip(context, 'In Service', TruckStatus.inService),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: trucks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No trucks found', style: context.textStyles.titleMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: AppSpacing.paddingMd,
                    itemCount: trucks.length,
                    itemBuilder: (context, index) {
                      final truck = trucks[index];
                      return _buildTruckCard(context, truck);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, TruckStatus? status) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filterStatus = selected ? status : null),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildTruckCard(BuildContext context, Truck truck) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: _getStatusColor(truck.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: _getStatusColor(truck.status),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(truck.displayName, style: context.textStyles.titleMedium?.semiBold),
                      const SizedBox(height: 4),
                      Text('Fleet: ${truck.fleetNumber}', style: context.textStyles.bodySmall),
                    ],
                  ),
                ),
                _buildStatusChip(context, truck.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(context, 'Rego', truck.registrationNumber),
                ),
                Expanded(
                  child: _buildInfoItem(context, 'Type', truck.truckType.name.toUpperCase()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(context, 'Odometer', '${truck.currentOdometer.toStringAsFixed(0)} km'),
                ),
                Expanded(
                  child: _buildInfoItem(context, 'Service Due', DateFormat('dd MMM yyyy').format(truck.serviceDueDate)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textStyles.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: context.textStyles.bodyMedium?.semiBold),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, TruckStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Text(
        _getStatusLabel(status),
        style: context.textStyles.bodySmall?.semiBold.copyWith(color: _getStatusColor(status)),
      ),
    );
  }

  Color _getStatusColor(TruckStatus status) {
    switch (status) {
      case TruckStatus.available:
        return Colors.green;
      case TruckStatus.rented:
        return Colors.blue;
      case TruckStatus.inService:
        return Colors.orange;
      case TruckStatus.damaged:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(TruckStatus status) {
    switch (status) {
      case TruckStatus.available:
        return 'Available';
      case TruckStatus.rented:
        return 'Rented';
      case TruckStatus.inService:
        return 'In Service';
      case TruckStatus.damaged:
        return 'Damaged';
      case TruckStatus.underRepair:
        return 'Under Repair';
      case TruckStatus.awaitingPickup:
        return 'Awaiting Pickup';
      case TruckStatus.outOfService:
        return 'Out of Service';
      default:
        return 'Reserved';
    }
  }
}

class _AddTruckSheet extends StatefulWidget {
  const _AddTruckSheet();

  @override
  State<_AddTruckSheet> createState() => _AddTruckSheetState();
}

class _AddTruckSheetState extends State<_AddTruckSheet> {
  final _formKey = GlobalKey<FormState>();
  final _regoController = TextEditingController();
  final _fleetController = TextEditingController();
  final _makeController = TextEditingController(text: 'Isuzu');
  final _modelController = TextEditingController();
  final _yearController = TextEditingController(text: DateTime.now().year.toString());

  TruckType _truckType = TruckType.box;
  FuelType _fuelType = FuelType.diesel;

  bool _saving = false;

  @override
  void dispose() {
    _regoController.dispose();
    _fleetController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add truck', style: context.textStyles.titleLarge?.semiBold),
          const SizedBox(height: 6),
          Text(
            'Important: the Firestore document ID will be the normalized rego (uppercase, no spaces).',
            style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _regoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Truck rego',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final rego = TruckService.normalizeRego(v ?? '');
                    if (rego.isEmpty) return 'Enter the truck rego';
                    return null;
                  },
                  onChanged: (v) {
                    final normalized = TruckService.normalizeRego(v);
                    if (v != normalized) {
                      _regoController.value = TextEditingValue(
                        text: normalized,
                        selection: TextSelection.collapsed(offset: normalized.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fleetController,
                  decoration: const InputDecoration(
                    labelText: 'Fleet number (optional)',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _makeController,
                        decoration: const InputDecoration(
                          labelText: 'Make',
                          prefixIcon: Icon(Icons.factory_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter make' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter model' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final year = int.tryParse((v ?? '').trim());
                          if (year == null || year < 1980 || year > DateTime.now().year + 1) return 'Enter a valid year';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<TruckType>(
                        value: _truckType,
                        decoration: const InputDecoration(
                          labelText: 'Truck type',
                          border: OutlineInputBorder(),
                        ),
                        items: TruckType.values
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase())))
                            .toList(),
                        onChanged: (v) => setState(() => _truckType = v ?? TruckType.box),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FuelType>(
                  value: _fuelType,
                  decoration: const InputDecoration(
                    labelText: 'Fuel type',
                    border: OutlineInputBorder(),
                  ),
                  items: FuelType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _fuelType = v ?? FuelType.diesel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                : Icon(Icons.save_outlined, color: cs.onPrimary),
            label: Text('Save truck', style: TextStyle(color: cs.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final truckService = context.read<TruckService>();
      final now = DateTime.now();

      final rego = TruckService.normalizeRego(_regoController.text);
      final year = int.parse(_yearController.text.trim());

      final truck = Truck(
        id: rego,
        registrationNumber: rego,
        vin: '',
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: year,
        fleetNumber: _fleetController.text.trim(),
        truckType: _truckType,
        palletCapacity: 0,
        fuelType: _fuelType,
        currentOdometer: 0,
        serviceDueDate: now.add(const Duration(days: 180)),
        registrationExpiry: now.add(const Duration(days: 365)),
        insuranceExpiry: now.add(const Duration(days: 365)),
        status: TruckStatus.available,
        createdAt: now,
        updatedAt: now,
      );

      await truckService.addTruck(truck);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Truck added.')));
      context.pop();
    } catch (e) {
      debugPrint('Admin add truck failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add truck. Please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
