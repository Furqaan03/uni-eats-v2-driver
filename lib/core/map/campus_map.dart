import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'udst_building_footprints.dart';
import 'udst_buildings.dart';

/// Google Maps campus view, mirroring the original driver app
/// (theunieats/app_driver): real Google tiles centred on UDST with a live
/// driver-location marker. The UDST building markers are layered on top so an
/// on-foot courier can still locate drop buildings (tap a pin for name + code).
class CampusMap extends StatefulWidget {
  final bool isDark;

  /// Whether the camera follows the live driver location. Production keeps this
  /// on; set false to keep the view pinned on the UDST campus.
  final bool followDriver;

  const CampusMap({
    super.key,
    required this.isDark,
    this.followDriver = true,
  });

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
    if (widget.followDriver) {
      _controller?.animateCamera(CameraUpdate.newLatLng(_driverPos!));
    }
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
      // Force a full re-init when the theme flips. GoogleMap applies `style` and
      // `buildingsEnabled` reliably only at initialization, not on live option
      // updates — and theme loads async (after first build), so without this key
      // the map stays stuck in its initial light config. Re-keying recreates the
      // map cleanly in the correct mode.
      key: ValueKey(widget.isDark),
      initialCameraPosition: const CameraPosition(
        target: _center,
        zoom: udstDefaultZoom,
      ),
      style: widget.isDark ? _darkMapStyle : null,
      // Dark mode: Google's building layer is invisible (unstyleable, dark on
      // dark), so turn it off and draw our own footprint polygons instead. Light
      // mode keeps Google's native 3D buildings — already correct.
      buildingsEnabled: !widget.isDark,
      polygons: udstDarkBuildingPolygons(isDark: widget.isDark),
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

/// Building footprints drawn as explicit polygons in dark mode. Google's own
/// building layer is unstyleable and renders invisibly on a dark map at high
/// zoom, so we paint the real OSM outlines ourselves — a light slate fill that
/// clearly reads against the Night base. Light mode uses Google's native
/// buildings (already correct), so this returns an empty set there.
///
/// Pure function (no widget state) so it can be unit-tested headlessly.
Set<Polygon> udstDarkBuildingPolygons({required bool isDark}) {
  if (!isDark) return const {};
  final polys = <Polygon>{};
  for (var i = 0; i < udstBuildingFootprints.length; i++) {
    final pts = udstBuildingFootprints[i]
        .map((p) => LatLng(p[0], p[1]))
        .toList(growable: false);
    if (pts.length < 3) continue;
    polys.add(Polygon(
      polygonId: PolygonId('udst_building_$i'),
      points: pts,
      fillColor: const Color(0xCC44566B), // ~80% so labels still show through
      strokeColor: const Color(0xFF7488A0),
      strokeWidth: 1,
      geodesic: false,
    ));
  }
  return polys;
}

/// Google's official "Night" map theme (the canonical dark style from Google's
/// own documentation/sample), applied directly — warm tan roads/labels on the
/// #242f3e navy base. The only additions are explicit building fills
/// (landscape.man_made / poi), since the stock Night style leaves footprints the
/// same colour as the ground; paired with `buildingsEnabled: false` in dark mode
/// these flat footprints stay visible at every zoom.
const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"on"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#3a4a5e"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.stroke","stylers":[{"color":"#516379"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#3a4a5e"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
]
''';
