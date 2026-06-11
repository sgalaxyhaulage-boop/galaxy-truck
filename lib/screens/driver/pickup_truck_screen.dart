import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import 'package:galaxy_truck/models/inspection.dart';
import 'package:galaxy_truck/models/truck.dart';
import 'package:galaxy_truck/services/auth_service.dart';
import 'package:galaxy_truck/services/inspection_service.dart';
import 'package:galaxy_truck/services/rental_service.dart';
import 'package:galaxy_truck/services/truck_service.dart';
import 'package:galaxy_truck/theme.dart';

class PickUpTruckScreen extends StatefulWidget {
  const PickUpTruckScreen({super.key});

  @override
  State<PickUpTruckScreen> createState() => _PickUpTruckScreenState();
}

String _normalizeRego(String input) => TruckService.normalizeRego(input);

class _PickUpTruckScreenState extends State<PickUpTruckScreen> {
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
  final _regoController = TextEditingController();
  final _regoFocusNode = FocusNode();

  late final SignatureController _signatureController;

  int _stepIndex = 0;
  Truck? _selectedTruck;
  double _fuelLevel = 0.75;
  final Map<String, String> _photoUriByLabel = {};
  final Map<String, Uint8List> _photoBytesByLabel = {};
  String? _signatureUri;
  Uint8List? _signatureBytes;

  bool get _hasSignature {
    final uri = _signatureUri;
    if (uri != null && uri.isNotEmpty) return true;
    final bytes = _signatureBytes;
    if (bytes != null && bytes.isNotEmpty) return true;
    // `SignatureController.isEmpty` has been unreliable on some web builds.
    // Using points is the most direct source of truth.
    return _signatureController.points.isNotEmpty;
  }

  bool _acknowledgeMissingPhotos = false;

  bool _submitting = false;
  bool _loadingTrucks = false;

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

    _odometerController.addListener(_handleDetailsChanged);
    _regoController.addListener(_handleDetailsChanged);

    // Defensive: ensure trucks are loaded even if this screen is opened via deep link
    // or the app resumes after being backgrounded.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTrucksLoaded());
  }

  Future<void> _ensureTrucksLoaded() async {
    if (!mounted || _loadingTrucks) return;
    final truckService = context.read<TruckService>();
    if (truckService.trucks.isNotEmpty) return;
    setState(() => _loadingTrucks = true);
    try {
      await truckService.loadTrucks();
    } catch (e) {
      debugPrint('Pickup: failed to load trucks: $e');
    } finally {
      if (mounted) setState(() => _loadingTrucks = false);
    }
  }

  Truck? _tryResolveTruckFromRego() {
    final q = _normalizeRego(_regoController.text.trim());
    if (q.isEmpty) return null;
    // IMPORTANT: resolve against *all* trucks, not only `availableTrucks`.
    // In real data, status parsing/values can be inconsistent; using only
    // `availableTrucks` can cause the Continue button to stay disabled even
    // when the rego exists.
    final trucks = context.read<TruckService>().trucks;
    for (final t in trucks) {
      if (_normalizeRego(t.registrationNumber) == q) return t;
    }
    return null;
  }

  void _handleDetailsChanged() {
    if (!mounted) return;

    // Keep the input normalized (uppercase + no spaces) without fighting the caret.
    final normalized = _normalizeRego(_regoController.text);
    if (_regoController.text != normalized) {
      _regoController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
        composing: TextRange.empty,
      );
      return;
    }

    final resolved = _tryResolveTruckFromRego();
    // Keep selection in sync when driver types an exact rego.
    // This prevents the Continue button staying disabled when the match exists.
    if (resolved != null && _selectedTruck?.id != resolved.id) {
      setState(() => _selectedTruck = resolved);
      return;
    }
    if (_regoController.text.trim().isEmpty && _selectedTruck != null) {
      setState(() => _selectedTruck = null);
      return;
    }

    // Rebuild bottom bar state when form fields change.
    setState(() {});
  }

  @override
  void dispose() {
    _odometerController.removeListener(_handleDetailsChanged);
    _regoController.removeListener(_handleDetailsChanged);
    _odometerController.dispose();
    _regoController.dispose();
    _regoFocusNode.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final truckService = context.watch<TruckService>();
    final trucks = truckService.availableTrucks;

    return Scaffold(
      appBar: AppBar(
        title: Text('Truck pickup', style: context.textStyles.titleLarge?.semiBold),
      ),
      body: SafeArea(
        child: Column(
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
                child: _buildStep(context, trucks),
              ),
            ),
            _BottomBar(
              stepIndex: _stepIndex,
              canGoBack: _stepIndex > 0 && !_submitting,
              primaryLabel: _stepIndex == 2 ? 'Confirm pickup' : 'Continue',
              primaryEnabled: _primaryEnabled,
              submitting: _submitting,
              onBack: () => setState(() => _stepIndex -= 1),
              onPrimary: _handlePrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, List<Truck> availableTrucks) {
    return Padding(
      key: ValueKey(_stepIndex),
      padding: AppSpacing.paddingMd,
      child: switch (_stepIndex) {
        0 => _PickupDetailsStep(
          formKey: _formKey,
          trucks: availableTrucks,
          selectedTruck: _selectedTruck,
          loadingTrucks: _loadingTrucks,
          regoController: _regoController,
          regoFocusNode: _regoFocusNode,
          odometerController: _odometerController,
          fuelLevel: _fuelLevel,
          onTruckChanged: (t) => setState(() {
            _selectedTruck = t;
            _regoController.text = t?.registrationNumber ?? '';
          }),
          onTruckSelectedFromRego: (t) => setState(() => _selectedTruck = t),
          onFuelChanged: (v) => setState(() => _fuelLevel = v),
        ),
        1 => _PhotoStep(
          photosByLabel: _photoUriByLabel,
          requiredLabels: _requiredPhotoLabels,
          acknowledgedMissing: _acknowledgeMissingPhotos,
          onAcknowledgeMissingChanged: (v) => setState(() => _acknowledgeMissingPhotos = v),
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
            setState(() => _signatureUri = null);
          },
          onSave: _saveSignature,
        ),
      },
    );
  }

  bool get _primaryEnabled {
    if (_submitting) return false;
    if (_stepIndex == 0) {
      // Enable based on *user input*, and resolve the truck on press.
      // This prevents the UI from getting stuck when truck data isn't loaded
      // yet or is filtered out by status.
      final normalizedRego = _normalizeRego(_regoController.text.trim());
      final odometer = double.tryParse(_odometerController.text.trim());
      return normalizedRego.isNotEmpty && odometer != null && odometer >= 0;
    }
    if (_stepIndex == 1) {
      // Don't block the whole pickup flow on photos.
      // Minimum: at least one photo OR the driver explicitly acknowledges skipping.
      final doneCount = _requiredPhotoLabels.where(_photoUriByLabel.containsKey).length;
      final hasAny = _photoUriByLabel.isNotEmpty;
      return hasAny && (doneCount == _requiredPhotoLabels.length || _acknowledgeMissingPhotos);
    }
    // Allow confirm if the driver has either saved the signature OR drawn one.
    // On web, exporting PNG bytes can occasionally fail/return null; we then
    // export on-confirm.
    return _hasSignature;
  }

  Future<void> _handlePrimary() async {
    if (_stepIndex == 0) {
      if (!_formKey.currentState!.validate()) return;

      final regoId = _normalizeRego(_regoController.text.trim());
      if (regoId.isEmpty) return;

      // Source of truth: Firestore doc id equals rego.
      final truckService = context.read<TruckService>();
      final resolved = await truckService.getTruckByRegoDocId(regoId);
      if (resolved == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Truck rego not found. Please check the rego or contact admin.')),
        );
        return;
      }

      if (resolved.isRented) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This truck is currently marked as rented and cannot be picked up.')),
        );
        return;
      }

      setState(() {
        _selectedTruck = resolved;
        _stepIndex = 1;
      });
      return;
    }
    if (_stepIndex == 1) {
      setState(() => _stepIndex = 2);
      return;
    }
    // If user drew but didn't hit “Save signature”, auto-save before submitting.
    if ((_signatureUri == null || _signatureUri!.isEmpty) && _signatureController.points.isNotEmpty) {
      await _saveSignature();
    }
    await _submitPickup();
  }

  Future<void> _capturePhoto(String label) async {
    try {
      final isOdometer = label.toLowerCase() == 'odometer';
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: isOdometer ? 1920 : 1280,
        maxHeight: isOdometer ? 1920 : 1280,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final uri = await _persistBytesAsImage(bytes, suggestedName: 'pickup_${label.toLowerCase().replaceAll(' ', '_')}');
      setState(() {
        _photoBytesByLabel[label] = bytes;
        _photoUriByLabel[label] = uri;
      });
    } catch (e) {
      debugPrint('Failed to capture photo ($label): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open camera for "$label".')),
      );
    }
  }

  Future<void> _saveSignature() async {
    try {
      if (_signatureController.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign before saving.')),
        );
        return;
      }

      final bytes = await _signatureController.toPngBytes();
      if (bytes == null || bytes.isEmpty) {
        debugPrint('Signature export returned empty bytes');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export signature. Please try again.')),
        );
        return;
      }

      final uri = await _persistBytesAsPng(bytes, suggestedName: 'pickup_signature');
      setState(() {
        _signatureBytes = bytes;
        _signatureUri = uri;
      });
    } catch (e) {
      debugPrint('Failed to save signature: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save signature. Please try again.')),
      );
    }
  }

  Future<String> _persistBytesAsImage(Uint8List bytes, {required String suggestedName}) async {
    // Store as data URI so it works on web + mobile consistently without filesystem access.
    // (If you later connect Firebase/Supabase, you can upload these bytes and store URLs instead.)
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<String> _persistBytesAsPng(Uint8List bytes, {required String suggestedName}) async {
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  Future<({double lat, double lng})> _tryGetLocation() async {
    try {
      // Never let location capture block submission indefinitely.
      // (Web permission prompts can stall.)
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return (lat: 0.0, lng: 0.0);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return (lat: 0.0, lng: 0.0);
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low)
          .timeout(const Duration(seconds: 6));
      return (lat: position.latitude, lng: position.longitude);
    } catch (e) {
      debugPrint('Location capture failed: $e');
      return (lat: 0.0, lng: 0.0);
    }
  }

  Future<void> _submitPickup() async {
    if (_selectedTruck == null) return;

    // IMPORTANT: at step 2, the details form is not mounted in the widget tree,
    // so `_formKey.currentState` can be null. Validate using controllers.
    final regoId = _normalizeRego(_regoController.text.trim());
    final parsedOdometer = double.tryParse(_odometerController.text.trim());
    if (regoId.isEmpty || parsedOdometer == null || parsedOdometer < 0) {
      setState(() => _stepIndex = 0);
      return;
    }

    // Photos are optional, but at least one photo is required for evidence.
    if (_photoUriByLabel.isEmpty) {
      setState(() => _stepIndex = 1);
      return;
    }

    // Signature is required. If the driver drew but export failed earlier, try again here.
    if (_signatureUri == null || _signatureUri!.isEmpty) {
      if (_signatureController.points.isNotEmpty) {
        await _saveSignature();
      }
      if (_signatureUri == null || _signatureUri!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please save your signature before confirming.')),
          );
          setState(() => _stepIndex = 2);
        }
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      debugPrint('Pickup submit: start');
      final authService = context.read<AuthService>();
      final rentalService = context.read<RentalService>();
      final inspectionService = context.read<InspectionService>();
      final truckService = context.read<TruckService>();

      final user = authService.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Re-validate in case anything changed.
      if (parsedOdometer.isNaN || parsedOdometer < 0) throw Exception('Invalid odometer');

      final loc = await _tryGetLocation();
      final now = DateTime.now();
      final inspectionId = _uuid.v4();

      // Upload photos + signature to Firebase Storage when possible.
      // Fallback to data URIs (still stored in Firestore) if upload is blocked by rules.
      final uploadedPhotoEntries = <InspectionPhoto>[];
      for (final entry in _photoUriByLabel.entries) {
        final label = entry.key;
        final existingUri = entry.value;
        final bytes = _photoBytesByLabel[label];
        if (bytes == null) {
          uploadedPhotoEntries.add(InspectionPhoto(label: label, path: existingUri));
          continue;
        }
        try {
          final url = await inspectionService
              .uploadInspectionMediaBytes(
                inspectionId: inspectionId,
                fileName: 'pickup_${label.toLowerCase().replaceAll(' ', '_')}.jpg',
                bytes: bytes,
                contentType: 'image/jpeg',
              )
              .timeout(const Duration(seconds: 15));
          uploadedPhotoEntries.add(InspectionPhoto(label: label, path: url));
        } catch (e) {
          debugPrint('Pickup: photo upload failed ($label), using local data URI fallback: $e');
          uploadedPhotoEntries.add(InspectionPhoto(label: label, path: existingUri));
        }
      }

      String? signaturePath = _signatureUri;
      final sigBytes = _signatureBytes;
      if (sigBytes != null) {
        try {
          signaturePath = await inspectionService
              .uploadInspectionMediaBytes(
                inspectionId: inspectionId,
                fileName: 'pickup_signature.png',
                bytes: sigBytes,
                contentType: 'image/png',
              )
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          debugPrint('Pickup: signature upload failed, using local data URI fallback: $e');
        }
      }

      final inspection = Inspection(
        id: inspectionId,
        truckId: _selectedTruck!.id,
        driverId: user.id,
        type: InspectionType.pickup,
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

      debugPrint('Pickup submit: writing inspection=${inspection.id}');
      await inspectionService.createInspection(inspection).timeout(const Duration(seconds: 12));

      debugPrint('Pickup submit: creating rental');
      final rentalId = await rentalService.createRental(_selectedTruck!.id, user.id).timeout(const Duration(seconds: 12));

      debugPrint('Pickup submit: starting rental=$rentalId');
      await rentalService.startRental(rentalId, inspectionId).timeout(const Duration(seconds: 12));

      debugPrint('Pickup submit: updating truck status');
      await truckService.updateTruckStatus(_selectedTruck!.id, TruckStatus.rented, driverId: user.id)
          .timeout(const Duration(seconds: 12));

      debugPrint('Pickup submit: complete');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup complete. Truck assigned to you.')),
      );
      context.go('/driver/dashboard');
    } on FirebaseException catch (e) {
      debugPrint('Pickup submit failed (Firebase): ${e.code} ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'Permission denied. Your Firestore security rules are blocking this action. Please contact admin to update access.'
                : (e.message ?? 'Could not complete pickup. Please try again.'),
          ),
        ),
      );
    } on TimeoutException {
      debugPrint('Pickup submit timed out');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup is taking too long. Please check your connection and try again.')),
      );
    } catch (e) {
      debugPrint('Pickup submit failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete pickup: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final int stepIndex;
  const _HeaderCard({required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = const [
      ('Details', Icons.local_shipping_outlined),
      ('Photos', Icons.photo_camera_outlined),
      ('Signature', Icons.draw_outlined),
    ];

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.primaryContainer.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == stepIndex;
          final done = i < stepIndex;
          final iconColor = active || done ? cs.primary : cs.onPrimaryContainer.withValues(alpha: 0.55);
          final textColor = active || done ? cs.onPrimaryContainer : cs.onPrimaryContainer.withValues(alpha: 0.65);
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
                    child: Icon(Icons.chevron_right, color: cs.onPrimaryContainer.withValues(alpha: 0.5), size: 18),
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
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      ),
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
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                    )
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

class _PickupDetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Truck> trucks;
  final Truck? selectedTruck;
  final bool loadingTrucks;
  final TextEditingController regoController;
  final FocusNode regoFocusNode;
  final TextEditingController odometerController;
  final double fuelLevel;
  final ValueChanged<Truck?> onTruckChanged;
  final ValueChanged<Truck?> onTruckSelectedFromRego;
  final ValueChanged<double> onFuelChanged;

  const _PickupDetailsStep({
    required this.formKey,
    required this.trucks,
    required this.selectedTruck,
    required this.loadingTrucks,
    required this.regoController,
    required this.regoFocusNode,
    required this.odometerController,
    required this.fuelLevel,
    required this.onTruckChanged,
    required this.onTruckSelectedFromRego,
    required this.onFuelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: ListView(
        children: [
          Text('Pickup details', style: context.textStyles.headlineSmall?.semiBold),
          const SizedBox(height: 6),
          Text(
            'Select the truck you’re collecting, then record odometer and fuel level.',
            style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TruckRegoAutocompleteField(
                    trucks: trucks,
                    selectedTruck: selectedTruck,
                    loading: loadingTrucks,
                    controller: regoController,
                    focusNode: regoFocusNode,
                    onTruckSelected: (truck) {
                      if (truck == null) {
                        onTruckSelectedFromRego(null);
                      } else {
                        onTruckChanged(truck);
                      }
                    },
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
                      Icon(Icons.local_gas_station_outlined, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Fuel level', style: context.textStyles.titleMedium?.semiBold),
                      ),
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
                  Slider(
                    value: fuelLevel,
                    onChanged: onFuelChanged,
                    divisions: 20,
                    label: '${(fuelLevel * 100).round()}%',
                  ),
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
                  Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Stand back and keep the whole truck in frame for exterior photos.',
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckRegoAutocompleteField extends StatelessWidget {
  final List<Truck> trucks;
  final Truck? selectedTruck;
  final bool loading;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<Truck?> onTruckSelected;

  const _TruckRegoAutocompleteField({
    required this.trucks,
    required this.selectedTruck,
    required this.loading,
    required this.controller,
    required this.focusNode,
    required this.onTruckSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RawAutocomplete<Truck>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (t) => t.registrationNumber,
      optionsBuilder: (value) {
        final q = _normalizeRego(value.text.trim());
        if (q.isEmpty) return const Iterable<Truck>.empty();
        return trucks.where((t) => _normalizeRego(t.registrationNumber).contains(q));
      },
      onSelected: (t) {
        controller.text = t.registrationNumber;
        onTruckSelected(t);
      },
      fieldViewBuilder: (context, textController, node, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: node,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Truck rego number',
            helperText: loading ? 'Loading trucks… please wait' : 'Type the rego (e.g. ABC123)',
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: textController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      textController.clear();
                      onTruckSelected(null);
                    },
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    tooltip: 'Clear',
                  ),
          ),
          onChanged: (v) {
            final trimmed = _normalizeRego(v.trim());
            if (trimmed.isEmpty) {
              onTruckSelected(null);
              return;
            }

            final match = trucks.where((t) => _normalizeRego(t.registrationNumber) == trimmed).toList();
            if (match.isNotEmpty) onTruckSelected(match.first);
          },
          validator: (_) {
            if (loading) return 'Loading trucks…';
            final normalized = _normalizeRego(textController.text.trim());
            if (normalized.isEmpty) return 'Enter the truck rego';
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 0,
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final t = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(t),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStatePropertyAll(Colors.transparent),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.local_shipping_outlined, color: cs.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.displayName,
                              style: context.textStyles.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.12)),
                itemCount: options.length,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoStep extends StatelessWidget {
  final Map<String, String> photosByLabel;
  final List<String> requiredLabels;
  final bool acknowledgedMissing;
  final ValueChanged<bool> onAcknowledgeMissingChanged;
  final ValueChanged<String> onCapture;
  final ValueChanged<String> onRemove;

  const _PhotoStep({
    required this.photosByLabel,
    required this.requiredLabels,
    required this.acknowledgedMissing,
    required this.onAcknowledgeMissingChanged,
    required this.onCapture,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final doneCount = requiredLabels.where(photosByLabel.containsKey).length;
    final missingCount = requiredLabels.length - doneCount;
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Required photos', style: context.textStyles.headlineSmall?.semiBold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$doneCount/${requiredLabels.length}', style: context.textStyles.labelLarge?.semiBold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Capture clear photos — these will be attached to the pickup inspection record.',
          style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ...requiredLabels.map((label) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PhotoCaptureCard(
                label: label,
                uri: photosByLabel[label],
                onCapture: () => onCapture(label),
                onRemove: () => onRemove(label),
              ),
            )),
        if (missingCount > 0) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Missing $missingCount photo(s). You can continue, but it’s recommended to capture all angles.',
                          style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: acknowledgedMissing,
                    onChanged: (v) => onAcknowledgeMissingChanged(v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('I understand I am continuing without all photos', style: context.textStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Photos and signatures upload to secure cloud storage when permitted by your Firebase rules. If upload is blocked, they’re saved as a local fallback in Firestore for now.',
                    style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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

/// A reusable card for capturing and previewing a single required photo.
class PhotoCaptureCard extends StatelessWidget {
  final String label;
  final String? uri;
  final VoidCallback onCapture;
  final VoidCallback onRemove;

  const PhotoCaptureCard({
    super.key,
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
                Expanded(
                  child: Text(label, style: context.textStyles.titleMedium?.semiBold),
                ),
                if (hasImage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
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
                    ? InspectionImage(uri: uri!)
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
                  IconButton(
                    onPressed: onRemove,
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    tooltip: 'Remove',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays either a `data:image/...;base64,` image or a local file path.
class InspectionImage extends StatelessWidget {
  final String uri;
  const InspectionImage({super.key, required this.uri});

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

  const _SignatureStep({
    required this.controller,
    required this.signatureUri,
    required this.onClear,
    required this.onSave,
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
          'Sign to confirm you’ve collected the vehicle in the condition shown in photos.',
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
                  child: Signature(
                    controller: controller,
                    backgroundColor: Colors.white,
                  ),
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
                Icon(Icons.description_outlined, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'By confirming, a pickup inspection record is created and the truck is set to “Rented”.',
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
