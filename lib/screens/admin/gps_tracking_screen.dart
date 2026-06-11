import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TruckLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double speed;
  final int timestamp;

  TruckLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.timestamp,
  });

  factory TruckLocation.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TruckLocation(
      id: doc.id,
      name: d['name'] ?? doc.id,
      lat: (d['lat'] ?? 0.0).toDouble(),
      lng: (d['lng'] ?? 0.0).toDouble(),
      speed: (d['speed'] ?? 0.0).toDouble(),
      timestamp: (d['timestamp'] ?? 0) as int,
    );
  }

  bool get isMoving => speed > 2.0;

  String get lastSeenText {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp;
    if (diff < 60) return 'Just now';
    if (diff < 3600) return '${diff ~/ 60}m ago';
    if (diff < 86400) return '${diff ~/ 3600}h ago';
    return '${diff ~/ 86400}d ago';
  }
}

class GpsTrackingScreen extends StatefulWidget {
  const GpsTrackingScreen({super.key});

  @override
  State<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends State<GpsTrackingScreen> {
  final MapController _mapController = MapController();
  List<TruckLocation> _trucks = [];
  TruckLocation? _selected;
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  static const LatLng _defaultCentre = LatLng(-27.0, 133.0);
  static const double _defaultZoom = 5.0;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('truck_locations')
        .snapshots()
        .listen(
      (snap) {
        final trucks = snap.docs
            .map((d) => TruckLocation.fromDoc(d))
            .where((t) => t.lat != 0.0 && t.lng != 0.0)
            .toList();
        setState(() {
          _trucks = trucks;
          _loading = false;
        });
      },
      onError: (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _fitBounds() {
    if (_trucks.isEmpty) return;
    final lats = _trucks.map((t) => t.lat);
    final lngs = _trucks.map((t) => t.lng);
    final sw = LatLng(lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b));
    final ne = LatLng(lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b));
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(sw, ne),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moving = _trucks.where((t) => t.isMoving).length;
    final stopped = _trucks.length - moving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live GPS Tracking'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          if (_trucks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.fit_screen),
              tooltip: 'Fit all trucks',
              onPressed: _fitBounds,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Failed to load GPS data',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(_error!,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _statChip(Icons.local_shipping, '${_trucks.length} trucks', Colors.white70),
                          const SizedBox(width: 12),
                          _statChip(Icons.play_circle, '$moving moving', Colors.greenAccent),
                          const SizedBox(width: 12),
                          _statChip(Icons.pause_circle, '$stopped stopped', Colors.orangeAccent),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _defaultCentre,
                              initialZoom: _defaultZoom,
                              onTap: (_, __) => setState(() => _selected = null),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.galaxytruckrentals.app',
                              ),
                              MarkerLayer(
                                markers: _trucks.map((truck) {
                                  return Marker(
                                    point: LatLng(truck.lat, truck.lng),
                                    width: 36,
                                    height: 36,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selected = truck),
                                      child: _TruckMarker(
                                        isMoving: truck.isMoving,
                                        isSelected: _selected?.id == truck.id,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          if (_selected != null)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: _TruckInfoCard(
                                truck: _selected!,
                                onClose: () => setState(() => _selected = null),
                              ),
                            ),
                          if (_trucks.isEmpty)
                            const Center(
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No GPS data yet.\nThe sync function runs every minute.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _TruckMarker extends StatelessWidget {
  final bool isMoving;
  final bool isSelected;
  const _TruckMarker({required this.isMoving, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isMoving ? Colors.green : Colors.orange,
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: Colors.blue, width: 3)
            : Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Icon(Icons.local_shipping, color: Colors.white, size: isSelected ? 20 : 16),
    );
  }
}

class _TruckInfoCard extends StatelessWidget {
  final TruckLocation truck;
  final VoidCallback onClose;
  const _TruckInfoCard({required this.truck, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: truck.isMoving ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(truck.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    truck.isMoving
                        ? '${truck.speed.toStringAsFixed(0)} km/h  •  ${truck.lastSeenText}'
                        : 'Stopped  •  ${truck.lastSeenText}',
                    style: TextStyle(
                      color: truck.isMoving ? Colors.green : Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${truck.lat.toStringAsFixed(5)}, ${truck.lng.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: onClose),
          ],
        ),
      ),
    );
  }
}
