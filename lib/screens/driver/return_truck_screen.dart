import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import 'package:galaxy_truck/models/inspection.dart';
import 'package:galaxy_truck/models/rental.dart';
import 'package:galaxy_truck/models/truck.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/inspection_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';

class ReturnTruckScreen extends StatefulWidget {
  const ReturnTruckScreen({super.key});

  @override
  State<ReturnTruckScreen> createState() => _ReturnTruckScreenState();
}

class _ReturnTruckScreenState extends State<ReturnTruckScreen> {
  static const _requiredPhotoLabels = <String>[
    'Front',
    'Back',
    'Left side',
    'Right side',
    'Interior',
    'Odometer',
  ];

  final _picker = ImagePicker();
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  final _odometerController = TextEditingController();

  late final SignatureController _signatureController;

  int _stepIndex = 0;
  double _fuelLevel = 0.5;
  final Map<String, String> _photoUriByLabel = {};
  final Map<String, Uint8List> _photoBytesByLabel = {};
  String? _signatureUri;
  Uint8List? _signatureBytes;
  bool _submitting = false;

  bool get _hasSignature {
    final uri = _signatureUri;
    if (uri != null && uri.isNotEmpty) return true;
    final bytes = _signatureBytes;
    if (bytes != null && bytes.isNotEmpty) return true;
    // `SignatureController.isEmpty` has been unreliable on some web builds.
    return _signatureController.points.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 2.6,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    // Ensure the bottom bar enables/disables immediately as the user draws.
    _signatureController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final rentals = context.watch<RentalService>();
    final trucks = context.watch<TruckService>();

    final user = auth.currentUser;
    final activeRental = rentals.getActiveRentalByDriver(user?.id ?? '');
    final truck = activeRental == null ? null : trucks.getTruckById(activeRental.truckId);

    return Scaffold(
      appBar: AppBar(title: Text('Truck drop-off', style: context.textStyles.titleLarge?.semiBold)),
      body: SafeArea(
        child: truck == null || activeRental == null
            ? _NoActiveRentalState(onBack: () => context.go('/driver/dashboard'))
            : Column(
                children: [
                  Padding(
                    padding: AppSpacing.horizontalMd.add(const EdgeInsets.only(top: 12)),
                    child: _HeaderCard(stepIndex: _stepIndex),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildStep(context, truck, activeRental),
                    ),
                  ),
                  _BottomBar(
                    stepIndex: _stepIndex,
                    canGoBack: _stepIndex > 0 && !_submitting,
                    primaryLabel: _stepIndex == 2 ? 'Confirm drop-off' : 'Continue',
                    primaryEnabled: _primaryEnabled,
                    submitting: _submitting,
                    onBack: () => setState(() => _stepIndex -= 1),
                    onPrimary: () => _handlePrimary(truck, activeRental),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, Truck truck, Rental activeRental) {
    return Padding(
      key: ValueKey(_stepIndex),
      padding: AppSpacing.paddingMd,
      child: switch (_stepIndex) {
        0 => _ReturnDetailsStep(
            formKey: _formKey,
            truck: truck,
            odometerController: _odometerController,
            fuelLevel: _fuelLevel,
            onFuelChanged: (v) => setState(() => _fuelLevel = v),
          ),
        1 => _PhotoStep(
            photosByLabel: _photoUriByLabel,
            requiredLabels: _requiredPhotoLabels,
            onCapture: _capturePhoto,
            onRemove: (label) => setState(() {
              _photoUriByLabel.remove(label);
              _photoBytesByLabel.remove(label);
            }),
          ),
        _ => _SignatureStep(
            controller: _signatureController,
            signatureUri: _signatureUri,
            onClear: () {
              _signatureController.clear();
              setState(() {
                _signatureUri = null;
                _signatureBytes = null;
              });
            },
            onSave: _saveSignature,
            confirmHint: 'By confirming, a drop-off inspection is created and the rental is completed.',
          ),
      },
    );
  }

  bool get _primaryEnabled {
    if (_submitting) return false;
    if (_stepIndex == 0) {
      final odometer = double.tryParse(_odometerController.text.trim());
      return odometer != null && odometer >= 0;
    }
    if (_stepIndex == 1) return _requiredPhotoLabels.every(_photoUriByLabel.containsKey);
    return _hasSignature;
  }

  Future<void> _handlePrimary(Truck truck, Rental activeRental) async {
    if (_stepIndex == 0) {
      final ok = _formKey.currentState?.validate() ?? false;
      if (!ok) {
        debugPrint('Drop-off submit: validation failed on details step');
        return;
      }
      setState(() => _stepIndex = 1);
      return;
    }
    if (_stepIndex == 1) {
      setState(() => _stepIndex = 2);
      return;
    }

    debugPrint(
      'Drop-off submit: confirm pressed (hasUri=${_signatureUri != null && _signatureUri!.isNotEmpty}, hasBytes=${_signatureBytes != null && _signatureBytes!.isNotEmpty}, points=${_signatureController.points.length})',
    );

    // If the driver drew but didn't hit “Save signature”, auto-export before submitting.
    if (!_hasSignature) {
      debugPrint('Drop-off submit: no signature detected; blocking submit');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign before confirming.')),
        );
      }
      return;
    }

    if ((_signatureUri == null || _signatureUri!.isEmpty) && _signatureController.points.isNotEmpty) {
      debugPrint('Drop-off submit: signature drawn but not exported; attempting auto-export');
      await _saveSignature();
      if (!_hasSignature || _signatureBytes == null || _signatureBytes!.isEmpty) {
        debugPrint('Drop-off submit: signature auto-export failed; blocking submit');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signature export failed. Please tap Save signature and try again.')),
          );
          setState(() => _stepIndex = 2);
        }
        return;
      }
    }

    await _submitDropoff(truck, activeRental);
  }

  Future<void> _capturePhoto(String label) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final uri = _persistBytesAsImage(bytes);
      setState(() {
        _photoBytesByLabel[label] = bytes;
        _photoUriByLabel[label] = uri;
      });
    } catch (e) {
      debugPrint('Drop-off: failed to capture photo ($label): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open camera for "$label".')),
      );
    }
  }

  Future<void> _saveSignature() async {
    try {
      if (_signatureController.points.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign before saving.')),
        );
        return;
      }
      final bytes = await _signatureController.toPngBytes();
      if (bytes == null || bytes.isEmpty) {
        debugPrint('Drop-off: signature export returned empty bytes');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export signature. Please try again.')),
        );
        return;
      }
      setState(() {
        _signatureBytes = bytes;
        _signatureUri = _persistBytesAsPng(bytes);
      });
    } catch (e) {
      debugPrint('Drop-off: failed to save signature: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save signature. Please try again.')),
      );
    }
  }

  String _persistBytesAsImage(Uint8List bytes) => 'data:image/jpeg;base64,${base64Encode(bytes)}';
  String _persistBytesAsPng(Uint8List bytes) => 'data:image/png;base64,${base64Encode(bytes)}';

  Future<({double lat, double lng})> _tryGetLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return (lat: 0.0, lng: 0.0);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return (lat: 0.0, lng: 0.0);
      }

      // Never let location capture block submission indefinitely.
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low)
          .timeout(const Duration(seconds: 6));
      return (lat: position.latitude, lng: position.longitude);
    } catch (e) {
      debugPrint('Drop-off: location capture failed: $e');
      return (lat: 0.0, lng: 0.0);
    }
  }

  Future<void> _submitDropoff(Truck truck, Rental activeRental) async {
    debugPrint('Drop-off submit: start validation for rental=${activeRental.id}');
    // IMPORTANT: at step 2, the details form is not mounted in the widget tree,
    // so `_formKey.currentState` can be null. Validate using controllers.
    final parsedOdometer = double.tryParse(_odometerController.text.trim());
    if (parsedOdometer == null || parsedOdometer < 0) {
      debugPrint('Drop-off submit: validation failed (odometer="${_odometerController.text}")');
      setState(() => _stepIndex = 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid odometer reading.')),
        );
      }
      return;
    }
    if (_requiredPhotoLabels.any((l) => !_photoUriByLabel.containsKey(l))) {
      debugPrint('Drop-off submit: validation failed (missing required photos)');
      setState(() => _stepIndex = 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture all required photos before confirming.')),
        );
      }
      return;
    }

    // Signature is required. If the driver drew but export failed earlier, try again here.
    if (!_hasSignature) {
      debugPrint('Drop-off submit: validation failed (no signature detected)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign before confirming.')),
        );
        setState(() => _stepIndex = 2);
      }
      return;
    }

    if ((_signatureBytes == null || _signatureBytes!.isEmpty) && _signatureController.points.isNotEmpty) {
      debugPrint('Drop-off submit: signature present but bytes missing; attempting export');
      await _saveSignature();
    }

    if ((_signatureBytes == null || _signatureBytes!.isEmpty) && (_signatureUri == null || _signatureUri!.isEmpty)) {
      debugPrint('Drop-off submit: signature export still missing after attempt; blocking submit');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature export failed. Please tap Save signature and try again.')),
        );
        setState(() => _stepIndex = 2);
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      debugPrint('Drop-off submit: start rental=${activeRental.id} truck=${truck.id}');
      final authService = context.read<AuthService>();
      final rentalService = context.read<RentalService>();
      final inspectionService = context.read<InspectionService>();
      final truckService = context.read<TruckService>();

      final user = authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      final loc = await _tryGetLocation();
      final now = DateTime.now();
      final inspectionId = _uuid.v4();

      // Upload photos + signature to Firebase Storage when possible.
      // Fallback to data URIs (still stored in Firestore) if upload is blocked by rules.
      final uploadedPhotoEntries = <InspectionPhoto>[];
      for (final label in _requiredPhotoLabels) {
        final existingUri = _photoUriByLabel[label];
        if (existingUri == null) continue;
        final bytes = _photoBytesByLabel[label];
        if (bytes == null) {
          uploadedPhotoEntries.add(InspectionPhoto(label: label, path: existingUri));
          continue;
        }
        try {
          final url = await inspectionService
              .uploadInspectionMediaBytes(
                inspectionId: inspectionId,
                fileName: 'dropoff_${label.toLowerCase().replaceAll(' ', '_')}.jpg',
                bytes: bytes,
                contentType: 'image/jpeg',
              )
              .timeout(const Duration(seconds: 15));
          uploadedPhotoEntries.add(InspectionPhoto(label: label, path: url));
        } catch (e) {
          debugPrint('Drop-off: photo upload failed ($label), using local data URI fallback: $e');
          uploadedPhotoEntries.add(InspectionPhoto(label: label, path: existingUri));
        }
      }

      String? signaturePath = _signatureUri;
      final sigBytes = _signatureBytes;
      if ((signaturePath == null || signaturePath.isEmpty) && sigBytes != null && sigBytes.isNotEmpty) {
        // Ensure we always have a non-empty fallback when Storage upload is blocked.
        signaturePath = _persistBytesAsPng(sigBytes);
      }

      if (sigBytes != null && sigBytes.isNotEmpty) {
        try {
          signaturePath = await inspectionService
              .uploadInspectionMediaBytes(
                inspectionId: inspectionId,
                fileName: 'dropoff_signature.png',
                bytes: sigBytes,
                contentType: 'image/png',
              )
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          debugPrint('Drop-off: signature upload failed, using local data URI fallback: $e');
        }
      }

      final inspection = Inspection(
        id: inspectionId,
        truckId: truck.id,
        driverId: user.id,
        type: InspectionType.dropoff,
        timestamp: now,
        latitude: loc.lat,
        longitude: loc.lng,
        photos: uploadedPhotoEntries,
        odometer: parsedOdometer,
        fuelLevel: _fuelLevel,
        checklist: InspectionChecklist(
          hasVisibleDamage: false,
          hasWindscreenCrack: false,
          hasTyreDamage: false,
          hasWarningLights: false,
        ),
        signaturePath: signaturePath,
        createdAt: now,
        updatedAt: now,
      );

      debugPrint('Drop-off submit: writing inspection=${inspection.id}');
      await inspectionService.createInspection(inspection).timeout(const Duration(seconds: 12));

      debugPrint('Drop-off submit: completing rental=${activeRental.id}');
      await rentalService.completeRental(activeRental.id, inspectionId).timeout(const Duration(seconds: 12));

      // Verify rental updated (prevents silent no-op if local cache is stale).
      try {
        final snap = await FirebaseFirestore.instance
            .collection('rentals')
            .doc(activeRental.id)
            .get()
            .timeout(const Duration(seconds: 8));
        final status = snap.data()?['status']?.toString();
        final completedAt = snap.data()?['completedAt'];
        final dropoffInspectionId = snap.data()?['dropoffInspectionId']?.toString();
        debugPrint(
          'Drop-off submit: verify rental status=$status completedAt=$completedAt dropoffInspectionId=$dropoffInspectionId',
        );
        if (status != RentalStatus.completed.name || dropoffInspectionId != inspectionId || completedAt == null) {
          throw Exception(
            'Rental did not update to completed. status=$status completedAt=$completedAt dropoffInspectionId=$dropoffInspectionId',
          );
        }
      } on FirebaseException catch (e) {
        // Some security rules may allow updates but disallow reads; don't hard-block completion.
        debugPrint('Drop-off submit: rental verification skipped (Firebase): ${e.code} ${e.message}');
        if (e.code != 'permission-denied') rethrow;
      } catch (e) {
        debugPrint('Drop-off submit: rental verification failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Drop-off could not be completed. Your rental did not update. Please retry or contact admin.',
            ),
          ),
        );
        return;
      }

      debugPrint('Drop-off submit: updating truck status');
      await truckService.updateTruckStatus(truck.id, TruckStatus.available, driverId: null)
          .timeout(const Duration(seconds: 12));

      debugPrint('Drop-off submit: complete');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drop-off complete. Thank you!')),
      );
      context.go('/driver/dashboard');
    } on FirebaseException catch (e) {
      debugPrint('Drop-off submit failed (Firebase): ${e.code} ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'Permission denied. Your Firestore/Storage security rules are blocking this action. Please contact admin to update access.'
                : (e.message ?? 'Could not complete drop-off. Please try again.'),
          ),
        ),
      );
    } on TimeoutException {
      debugPrint('Drop-off submit timed out');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drop-off is taking too long. Please check your connection and try again.')),
      );
    } catch (e) {
      debugPrint('Drop-off submit failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete drop-off: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _NoActiveRentalState extends StatelessWidget {
  final VoidCallback onBack;
  const _NoActiveRentalState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.local_shipping_outlined, size: 38, color: cs.primary),
            ),
            const SizedBox(height: 14),
            Text('No active rental', style: context.textStyles.headlineSmall?.semiBold, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'You don\'t currently have a truck assigned.\nPick up a truck first, then return here to drop it off.',
              style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onBack,
              icon: Icon(Icons.chevron_left, color: cs.onPrimary),
              label: Text('Back to dashboard', style: TextStyle(color: cs.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int stepIndex;
  const _HeaderCard({required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = const [
      ('Details', Icons.assignment_outlined),
      ('Photos', Icons.photo_camera_outlined),
      ('Signature', Icons.draw_outlined),
    ];
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.secondaryContainer, cs.secondaryContainer.withValues(alpha: 0.55)]),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == stepIndex;
          final done = i < stepIndex;
          final iconColor = active || done ? cs.secondary : cs.onSecondaryContainer.withValues(alpha: 0.55);
          final textColor = active || done ? cs.onSecondaryContainer : cs.onSecondaryContainer.withValues(alpha: 0.65);
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: active ? 0.9 : 0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                  ),
                  child: Icon(done ? Icons.check : items[i].$2, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i].$1,
                    style: context.textStyles.bodyMedium?.semiBold.copyWith(color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i != items.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.chevron_right, color: cs.onSecondaryContainer.withValues(alpha: 0.5), size: 18),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int stepIndex;
  final bool canGoBack;
  final String primaryLabel;
  final bool primaryEnabled;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onPrimary;

  const _BottomBar({
    required this.stepIndex,
    required this.canGoBack,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.submitting,
    required this.onBack,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.12)))),
      child: Row(
        children: [
          if (canGoBack)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBack,
                icon: Icon(Icons.chevron_left, color: cs.onSurface),
                label: Text('Back', style: TextStyle(color: cs.onSurface)),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: primaryEnabled ? onPrimary : null,
              icon: submitting
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : Icon(stepIndex == 2 ? Icons.check_circle_outline : Icons.chevron_right, color: cs.onPrimary),
              label: Text(primaryLabel, style: TextStyle(color: cs.onPrimary)),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnDetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Truck truck;
  final TextEditingController odometerController;
  final double fuelLevel;
  final ValueChanged<double> onFuelChanged;

  const _ReturnDetailsStep({
    required this.formKey,
    required this.truck,
    required this.odometerController,
    required this.fuelLevel,
    required this.onFuelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: ListView(
        children: [
          Text('Drop-off details', style: context.textStyles.headlineSmall?.semiBold),
          const SizedBox(height: 6),
          Text(
            'Confirm the odometer and fuel level for this return.',
            style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, color: cs.secondary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(truck.displayName, style: context.textStyles.titleMedium?.semiBold, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: odometerController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Odometer (km)',
                      prefixIcon: Icon(Icons.speed_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return 'Enter the current odometer';
                      final parsed = double.tryParse(text);
                      if (parsed == null || parsed < 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.local_gas_station_outlined, color: cs.secondary),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Fuel level', style: context.textStyles.titleMedium?.semiBold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
                        ),
                        child: Text('${(fuelLevel * 100).round()}%', style: context.textStyles.labelLarge?.semiBold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Slider(value: fuelLevel, onChanged: onFuelChanged, divisions: 20, label: '${(fuelLevel * 100).round()}%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStep extends StatelessWidget {
  final Map<String, String> photosByLabel;
  final List<String> requiredLabels;
  final ValueChanged<String> onCapture;
  final ValueChanged<String> onRemove;

  const _PhotoStep({
    required this.photosByLabel,
    required this.requiredLabels,
    required this.onCapture,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final doneCount = requiredLabels.where(photosByLabel.containsKey).length;
    return ListView(
      children: [
        Row(
          children: [
            Expanded(child: Text('Required photos', style: context.textStyles.headlineSmall?.semiBold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(999)),
              child: Text('$doneCount/${requiredLabels.length}', style: context.textStyles.labelLarge?.semiBold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Capture clear photos of the truck at drop-off.', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        ...requiredLabels.map((label) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PhotoCaptureCard(
                label: label,
                uri: photosByLabel[label],
                onCapture: () => onCapture(label),
                onRemove: () => onRemove(label),
              ),
            )),
      ],
    );
  }
}

class _PhotoCaptureCard extends StatelessWidget {
  final String label;
  final String? uri;
  final VoidCallback onCapture;
  final VoidCallback onRemove;

  const _PhotoCaptureCard({
    required this.label,
    required this.uri,
    required this.onCapture,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = uri != null && uri!.isNotEmpty;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: context.textStyles.titleMedium?.semiBold)),
                if (hasImage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: cs.tertiaryContainer.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: cs.tertiary),
                        const SizedBox(width: 6),
                        Text('Captured', style: context.textStyles.labelLarge?.semiBold),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? _InspectionImage(uri: uri!)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_outlined, color: cs.onSurfaceVariant, size: 28),
                            const SizedBox(height: 8),
                            Text('No photo yet', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCapture,
                    icon: Icon(hasImage ? Icons.refresh : Icons.photo_camera, color: cs.onPrimary),
                    label: Text(hasImage ? 'Retake' : 'Capture', style: TextStyle(color: cs.onPrimary)),
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(width: 12),
                  IconButton(onPressed: onRemove, icon: Icon(Icons.delete_outline, color: cs.error), tooltip: 'Remove'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectionImage extends StatelessWidget {
  final String uri;
  const _InspectionImage({required this.uri});

  @override
  Widget build(BuildContext context) {
    final comma = uri.indexOf(',');
    final b64 = comma == -1 ? '' : uri.substring(comma + 1);
    final bytes = base64Decode(b64);
    return Image.memory(bytes, fit: BoxFit.cover);
  }
}

class _SignatureStep extends StatelessWidget {
  final SignatureController controller;
  final String? signatureUri;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final String confirmHint;

  const _SignatureStep({
    required this.controller,
    required this.signatureUri,
    required this.onClear,
    required this.onSave,
    required this.confirmHint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSaved = signatureUri != null && signatureUri!.isNotEmpty;
    return ListView(
      children: [
        Text('Driver signature', style: context.textStyles.headlineSmall?.semiBold),
        const SizedBox(height: 6),
        Text(
          'Sign to confirm the vehicle is returned in the condition shown in photos.',
          style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Signature(controller: controller, backgroundColor: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onClear,
                        icon: Icon(Icons.clear, color: cs.onSurface),
                        label: Text('Clear', style: TextStyle(color: cs.onSurface)),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onSave,
                        icon: Icon(Icons.save_outlined, color: cs.onPrimary),
                        label: Text('Save signature', style: TextStyle(color: cs.onPrimary)),
                        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
                      ),
                    ),
                  ],
                ),
                if (hasSaved) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, color: cs.tertiary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Signature saved — you can still change it before confirming.',
                          style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined, color: cs.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    confirmHint,
                    style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
