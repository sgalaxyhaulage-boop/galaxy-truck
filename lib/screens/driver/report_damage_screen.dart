import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_truck/models/damage_report.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/damage_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ReportDamageScreen extends StatefulWidget {
  const ReportDamageScreen({super.key});

  @override
  State<ReportDamageScreen> createState() => _ReportDamageScreenState();
}

class _ReportDamageScreenState extends State<ReportDamageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final List<_PickedPhoto> _photos = [];

  DamageType _type = DamageType.general;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DamageService>().loadDamageReports();
      context.read<RentalService>().loadRentals();
    });
  }

  @override
  void dispose() {
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
      debugPrint('Failed to get location for damage report: $e');
      return null;
    }
  }

  Future<void> _addPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 82, maxWidth: 2400);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add(_PickedPhoto(fileName: picked.name, bytes: bytes)));
    } catch (e) {
      debugPrint('Failed to pick damage photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo. Please try again.')),
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final auth = context.read<AuthService>();
    final rentalService = context.read<RentalService>();
    final damageService = context.read<DamageService>();
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

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 photo.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final pos = await _tryGetLocation();
      final now = DateTime.now();

      // Create the report first to get an ID, then upload.
      final baseReport = DamageReport(
        id: '',
        truckId: activeRental.truckId,
        driverId: user.id,
        damageType: _type,
        description: _descCtrl.text.trim(),
        photoPaths: const [],
        latitude: pos?.latitude ?? 0,
        longitude: pos?.longitude ?? 0,
        reportedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final reportId = await damageService.createDamageReport(baseReport);

      final uploaded = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        final name = p.fileName.isNotEmpty ? p.fileName : 'photo_${i + 1}.jpg';
        try {
          final url = await damageService.uploadDamageMediaBytes(
            reportId: reportId,
            fileName: name,
            bytes: p.bytes,
            contentType: 'image/jpeg',
          );
          uploaded.add(url);
        } catch (e) {
          // Fallback: store as base64 data uri so the report still submits.
          debugPrint('Damage photo upload blocked; storing base64 fallback. Error: $e');
          final b64 = base64Encode(p.bytes);
          uploaded.add('data:image/jpeg;base64,$b64');
        }
      }

      final created = damageService.getDamageReportById(reportId);
      if (created != null) {
        await damageService.updateDamageReport(created.copyWith(photoPaths: uploaded, updatedAt: DateTime.now()));
      }
      await damageService.loadDamageReports();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Damage report submitted.')));
      context.pop();
    } catch (e) {
      debugPrint('Failed to submit damage report: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit. Please try again.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Report Damage', style: context.textStyles.titleLarge?.semiBold)),
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
                    decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(Icons.warning_amber_rounded, color: cs.error),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Report damage immediately. Photos help the admin team assess and action repairs faster.',
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
                    DropdownButtonFormField<DamageType>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Damage type'),
                      items: DamageType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(_labelForDamageType(t))))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v ?? _type),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'What happened? Where is the damage?'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter a description.' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Text('Photos', style: context.textStyles.titleMedium?.semiBold)),
                        Text('${_photos.length}/8', style: context.textStyles.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._photos.map((p) => _DamagePhotoChip(
                              bytes: p.bytes,
                              onRemove: () => setState(() => _photos.remove(p)),
                            )),
                        _AddPhotoChip(onTap: _photos.length >= 8 || _isSubmitting ? null : _addPhoto),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: Icon(Icons.send, color: cs.onPrimary),
                      label: Text(_isSubmitting ? 'Submitting…' : 'Submit report', style: TextStyle(color: cs.onPrimary)),
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

class _PickedPhoto {
  final String fileName;
  final Uint8List bytes;
  _PickedPhoto({required this.fileName, required this.bytes});
}

class _AddPhotoChip extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddPhotoChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 98,
        height: 98,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, color: onTap == null ? cs.onSurfaceVariant.withValues(alpha: 0.5) : cs.primary),
              const SizedBox(height: 6),
              Text('Add', style: context.textStyles.labelLarge?.semiBold.copyWith(color: onTap == null ? cs.onSurfaceVariant.withValues(alpha: 0.5) : cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DamagePhotoChip extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onRemove;
  const _DamagePhotoChip({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.memory(bytes, width: 98, height: 98, fit: BoxFit.cover),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: InkWell(
            onTap: onRemove,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(999)),
              child: Icon(Icons.close, size: 16, color: cs.error),
            ),
          ),
        ),
      ],
    );
  }
}

String _labelForDamageType(DamageType t) {
  switch (t) {
    case DamageType.general:
      return 'General';
    case DamageType.windscreenCrack:
      return 'Windscreen crack';
    case DamageType.tyreDamage:
      return 'Tyre damage';
    case DamageType.accident:
      return 'Accident';
    case DamageType.bodyDamage:
      return 'Body damage';
    case DamageType.mechanicalIssue:
      return 'Mechanical issue';
  }
}
