import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/driver_profile.dart';
import 'package:galaxy_truck/models/user.dart' as app_user;
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/driver_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:provider/provider.dart';

class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  bool _loading = true;
  List<app_user.User> _users = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await context.read<AuthService>().getAllUsers();
      await context.read<DriverService>().loadDrivers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      debugPrint('Failed to load users/drivers: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRole(app_user.User user, app_user.UserRole role) async {
    try {
      await context.read<AuthService>().setUserRole(userId: user.id, role: role);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role updated: ${user.fullName} → ${role.name}')));
    } catch (e) {
      debugPrint('Failed to set role: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update role.')));
    }
  }

  Future<void> _approveProfile(DriverProfile p) async {
    try {
      await context.read<DriverService>().approveDriver(p.id);
      await context.read<DriverService>().loadDrivers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver profile approved.')));
    } catch (e) {
      debugPrint('Failed to approve driver: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve.')));
    }
  }

  Future<void> _rejectProfile(DriverProfile p) async {
    final cs = Theme.of(context).colorScheme;
    final reasonCtrl = TextEditingController();
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reject driver profile', style: context.textStyles.titleLarge?.semiBold),
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
    if (res == null || res.isEmpty) return;
    try {
      await context.read<DriverService>().rejectDriver(p.id, res);
      await context.read<DriverService>().loadDrivers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver profile rejected.')));
    } catch (e) {
      debugPrint('Failed to reject driver: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverService = context.watch<DriverService>();
    final cs = Theme.of(context).colorScheme;

    final filtered = _query.trim().isEmpty
        ? _users
        : _users.where((u) => u.fullName.toLowerCase().contains(_query.trim().toLowerCase()) || u.email.toLowerCase().contains(_query.trim().toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Drivers', style: context.textStyles.titleLarge?.semiBold),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.paddingMd,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Drivers must have role=driver in users/{uid}. Approve/reject driver profiles from driver_profiles.',
                            style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Users', style: context.textStyles.titleMedium?.semiBold),
                const SizedBox(height: 8),
                ...filtered.map((u) {
                  final role = u.role;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                            child: Icon(Icons.person_outline, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.fullName, style: context.textStyles.titleSmall?.semiBold),
                                const SizedBox(height: 2),
                                Text(u.email, style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
                            child: Text((role?.name ?? 'none').toUpperCase(), style: context.textStyles.labelSmall?.semiBold),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<app_user.UserRole>(
                            tooltip: 'Set role',
                            onSelected: (r) => _setRole(u, r),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: app_user.UserRole.driver, child: Text('Set as driver')),
                              PopupMenuItem(value: app_user.UserRole.admin, child: Text('Set as admin')),
                            ],
                            child: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Text('Driver profiles', style: context.textStyles.titleMedium?.semiBold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(999)),
                      child: Text('${driverService.pendingDrivers.length} pending', style: context.textStyles.labelLarge?.semiBold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (driverService.drivers.isEmpty)
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Text('No driver profiles found.', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  ...driverService.drivers.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: AppSpacing.paddingMd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(p.fullName, style: context.textStyles.titleSmall?.semiBold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
                                    child: Text(p.approvalStatus.name.toUpperCase(), style: context.textStyles.labelSmall?.semiBold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(p.email, style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: p.isApproved ? null : () => _approveProfile(p),
                                      icon: Icon(Icons.check, color: cs.onPrimary),
                                      label: Text('Approve', style: TextStyle(color: cs.onPrimary)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _rejectProfile(p),
                                      icon: Icon(Icons.close, color: cs.error),
                                      label: Text('Reject', style: TextStyle(color: cs.error)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
    );
  }
}
