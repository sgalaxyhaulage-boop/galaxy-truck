import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/driver_profile.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/driver_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _addressCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _licenceCtrl = TextEditingController();

  DateTime? _dob;
  DateTime? _licenceExpiry;
  LicenceClass _licenceClass = LicenceClass.classC;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DriverService>().loadDrivers();
      _hydrateFromExisting();
    });
  }

  void _hydrateFromExisting() {
    final auth = context.read<AuthService>();
    final driverService = context.read<DriverService>();
    final user = auth.currentUser;
    if (user == null) return;

    final existing = driverService.getDriverByUserId(user.id);
    if (existing == null) return;

    _addressCtrl.text = existing.address;
    _mobileCtrl.text = existing.mobileNumber;
    _companyCtrl.text = existing.companyName ?? '';
    _licenceCtrl.text = existing.licenceNumber;
    _dob = existing.dateOfBirth;
    _licenceExpiry = existing.licenceExpiry;
    _licenceClass = existing.licenceClass;
    setState(() {});
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _mobileCtrl.dispose();
    _companyCtrl.dispose();
    _licenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required DateTime? current, required ValueChanged<DateTime> onPicked}) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (result != null) onPicked(result);
  }

  Future<void> _save() async {
    if (_saving) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final auth = context.read<AuthService>();
    final driverService = context.read<DriverService>();
    final user = auth.currentUser;
    if (user == null) return;

    if (_dob == null || _licenceExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select all dates.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final existing = driverService.getDriverByUserId(user.id);
      final profile = DriverProfile(
        id: existing?.id ?? '',
        userId: user.id,
        fullName: user.fullName,
        dateOfBirth: _dob!,
        address: _addressCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim(),
        email: user.email,
        companyName: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        licenceNumber: _licenceCtrl.text.trim(),
        licenceClass: _licenceClass,
        licenceExpiry: _licenceExpiry!,
        licenceFrontPath: existing?.licenceFrontPath,
        licenceBackPath: existing?.licenceBackPath,
        proofOfAddressPath: existing?.proofOfAddressPath,
        driverPhotoPath: existing?.driverPhotoPath,
        approvalStatus: existing?.approvalStatus ?? ApprovalStatus.pending,
        rejectionReason: existing?.rejectionReason,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (existing == null) {
        await driverService.addDriver(profile);
      } else {
        await driverService.updateDriver(profile);
      }
      await driverService.loadDrivers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      debugPrint('Failed to save driver profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save. Please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final driverService = context.watch<DriverService>();
    final user = auth.currentUser;
    final cs = Theme.of(context).colorScheme;

    final profile = user == null ? null : driverService.getDriverByUserId(user.id);
    final statusText = profile == null
        ? 'Not created'
        : profile.isApproved
            ? 'Approved'
            : profile.isPending
                ? 'Pending approval'
                : 'Rejected';

    return Scaffold(
      appBar: AppBar(title: Text('My Profile', style: context.textStyles.titleLarge?.semiBold)),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Card(
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.lg)),
                          child: Icon(Icons.person_outline, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.fullName, style: context.textStyles.titleMedium?.semiBold),
                              const SizedBox(height: 2),
                              Text(user.email, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: profile?.isApproved == true ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                          ),
                          child: Text(statusText, style: context.textStyles.labelLarge?.semiBold),
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
                        children: [
                          TextFormField(
                            controller: _mobileCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Mobile number'),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a mobile number.' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressCtrl,
                            decoration: const InputDecoration(labelText: 'Address'),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter an address.' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _companyCtrl,
                            decoration: const InputDecoration(labelText: 'Company name (optional)'),
                          ),
                          const SizedBox(height: 12),
                          _DateField(
                            label: 'Date of birth',
                            value: _dob,
                            onTap: () => _pickDate(current: _dob, onPicked: (d) => setState(() => _dob = d)),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _licenceCtrl,
                            decoration: const InputDecoration(labelText: 'Licence number'),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a licence number.' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<LicenceClass>(
                            value: _licenceClass,
                            decoration: const InputDecoration(labelText: 'Licence class'),
                            items: LicenceClass.values
                                .map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase())))
                                .toList(),
                            onChanged: (v) => setState(() => _licenceClass = v ?? _licenceClass),
                          ),
                          const SizedBox(height: 12),
                          _DateField(
                            label: 'Licence expiry',
                            value: _licenceExpiry,
                            onTap: () => _pickDate(current: _licenceExpiry, onPicked: (d) => setState(() => _licenceExpiry = d)),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: Icon(Icons.save_outlined, color: cs.onPrimary),
                            label: Text(_saving ? 'Saving…' : 'Save profile', style: TextStyle(color: cs.onPrimary)),
                            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                          ),
                          if (profile?.approvalStatus == ApprovalStatus.rejected && (profile?.rejectionReason ?? '').isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline, color: cs.error),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      profile!.rejectionReason!,
                                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onErrorContainer, height: 1.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = value == null ? 'Select' : DateFormat('dd MMM yyyy').format(value!);
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
        child: Row(
          children: [
            Expanded(child: Text(text, style: context.textStyles.bodyMedium?.copyWith(color: value == null ? cs.onSurfaceVariant : cs.onSurface))),
            Icon(Icons.calendar_month_outlined, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
