import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'udst_buildings.dart';

/// Google Maps campus view, mirroring the original driver app
/// (theunieats/app_driver): real Google tiles centred on UDST with a live
/// driver-location marker. The UDST building markers are layered on top so an
/// on-foot courier can still locate drop buildings (tap a pin for name + code).
class CampusMap extends StatefulWidget {
  final bool isDark;

  const CampusMap({super.key, required this.isDark});

  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  static const _center = LatLng(udstCenterLat, udstCenterLng);

  GoogleMapController? _controller;
  StreamSubscription<Position>? _posSub;
  BitmapDescriptor? _driverIcon;
  LatLng? _driverPos;
  double _driverHeading = 0;

  final Map<MarkerId, Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadDriverIcon();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadDriverIcon() async {
    final icon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(38, 38)),
      'assets/icons/ic_bike.png',
    );
    if (mounted) setState(() => _driverIcon = icon);
    _refreshDriverMarker();
  }

  /// Requests location permission and streams the driver's position, updating
  /// the bike marker (and following it with the camera) — same flow as the
  /// original app's updateCurrentLocation().
  Future<void> _startLocationTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position p) {
    _driverPos = LatLng(p.latitude, p.longitude);
    _driverHeading = p.heading;
    _refreshDriverMarker();
    _controller?.animateCamera(CameraUpdate.newLatLng(_driverPos!));
  }

  void _refreshDriverMarker() {
    if (_driverPos == null || _driverIcon == null) return;
    const id = MarkerId('driver');
    setState(() {
      _markers[id] = Marker(
        markerId: id,
        position: _driverPos!,
        icon: _driverIcon!,
        rotation: _driverHeading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _center,
        zoom: udstDefaultZoom,
      ),
      style: widget.isDark ? _darkMapStyle : null,
      markers: Set<Marker>.of(_markers.values),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      padding: const EdgeInsets.only(top: 22),
      onMapCreated: (c) {
        _controller = c;
        _refreshDriverMarker();
      },
    );
  }
}

/// Compact dark map style so Google tiles match the app's dark theme.
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#383838"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
]
''';
