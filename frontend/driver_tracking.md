# Frontend Development Plan: Driver Delivery Tracking

## Overview

Implement Flutter-based driver location tracking with background location services, real-time map visualization with HTTP polling for live updates.

---

## Phase 1: Dependencies and Configuration (Day 1)

### Step 1.1: Update Dependencies

**File:** `frontend/pubspec.yaml`

Add the following dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Existing dependencies...
  http: ^1.1.0
  provider: ^6.1.1

  # Location tracking (NEW)
  geolocator: ^10.1.0
  permission_handler: ^11.1.0

  # Mapbox for map display (NEW)
  mapbox_gl: ^0.16.0

  # Background execution (NEW)
  workmanager: ^0.5.1

  # Battery monitoring (NEW)
  battery_plus: ^4.0.2

  # UUID generation (NEW)
  uuid: ^4.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

**Install Dependencies:**
```bash
cd frontend
flutter pub get
```

### Step 1.2: Platform-Specific Configuration

#### iOS Configuration

**File:** `frontend/ios/Runner/Info.plist`

Add location permissions:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track deliveries in real-time</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to track deliveries even when the app is in the background</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to track deliveries even when the app is in the background</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
</array>
```

#### Android Configuration

**File:** `frontend/android/app/src/main/AndroidManifest.xml`

Add location permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Location permissions -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application>
        <!-- Existing configuration... -->
    </application>
</manifest>
```

### Step 1.3: Mapbox Token Configuration

**File:** `frontend/lib/config/mapbox_config.dart`

```dart
class MapboxConfig {
  // TODO: Replace with your Mapbox access token
  static const String accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN_HERE';

  // Default map style
  static const String mapStyle = 'mapbox://styles/mapbox/streets-v12';

  // San Francisco coordinates (default)
  static const double defaultLatitude = 37.7749;
  static const double defaultLongitude = -122.4194;
  static const double defaultZoom = 12.0;
}
```

**Testing:**
```bash
# Verify dependencies installed
flutter pub get
flutter pub outdated

# Check platform configuration
flutter doctor -v
```

---

## Phase 2: Models and Data Structures (Day 2)

### Step 2.1: Create Tracking Models

**File:** `frontend/lib/models/driver_location.dart`

```dart
import 'package:flutter/foundation.dart';

enum DriverLocationStatus {
  offline,
  online,
  onDelivery,
  paused;

  String get displayName {
    switch (this) {
      case DriverLocationStatus.offline:
        return 'Offline';
      case DriverLocationStatus.online:
        return 'Available';
      case DriverLocationStatus.onDelivery:
        return 'On Delivery';
      case DriverLocationStatus.paused:
        return 'Paused';
    }
  }

  static DriverLocationStatus fromString(String status) {
    return DriverLocationStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => DriverLocationStatus.offline,
    );
  }
}

class DriverLocation {
  final int driverId;
  final String driverName;
  final double latitude;
  final double longitude;
  final int? headingDegrees;
  final double? speedMps;
  final DriverLocationStatus status;
  final int? orderId;
  final DestinationInfo? destination;
  final DateTime updatedAt;

  DriverLocation({
    required this.driverId,
    required this.driverName,
    required this.latitude,
    required this.longitude,
    this.headingDegrees,
    this.speedMps,
    required this.status,
    this.orderId,
    this.destination,
    required this.updatedAt,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      driverId: json['driver_id'],
      driverName: json['driver_name'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      headingDegrees: json['heading_degrees'],
      speedMps: json['speed_mps'] != null
          ? (json['speed_mps'] as num).toDouble()
          : null,
      status: DriverLocationStatus.fromString(json['status']),
      orderId: json['order_id'],
      destination: json['destination'] != null
          ? DestinationInfo.fromJson(json['destination'])
          : null,
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'driver_name': driverName,
      'latitude': latitude,
      'longitude': longitude,
      'heading_degrees': headingDegrees,
      'speed_mps': speedMps,
      'status': status.name,
      'order_id': orderId,
      'destination': destination?.toJson(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class DestinationInfo {
  final String type; // 'restaurant' or 'customer'
  final String name;
  final double latitude;
  final double longitude;
  final int? etaMinutes;

  DestinationInfo({
    required this.type,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.etaMinutes,
  });

  factory DestinationInfo.fromJson(Map<String, dynamic> json) {
    return DestinationInfo(
      type: json['type'],
      name: json['name'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      etaMinutes: json['eta_minutes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'eta_minutes': etaMinutes,
    };
  }
}

class LocationHistoryPoint {
  final double latitude;
  final double longitude;
  final double? speedMps;
  final int? headingDegrees;
  final DateTime recordedAt;
  final String? eventType;

  LocationHistoryPoint({
    required this.latitude,
    required this.longitude,
    this.speedMps,
    this.headingDegrees,
    required this.recordedAt,
    this.eventType,
  });

  factory LocationHistoryPoint.fromJson(Map<String, dynamic> json) {
    return LocationHistoryPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedMps: json['speed_mps'] != null
          ? (json['speed_mps'] as num).toDouble()
          : null,
      headingDegrees: json['heading_degrees'],
      recordedAt: DateTime.parse(json['recorded_at']),
      eventType: json['event_type'],
    );
  }
}

class ActiveDriversResponse {
  final int totalActive;
  final int onDelivery;
  final List<DriverLocation> drivers;
  final DateTime updatedAt;

  ActiveDriversResponse({
    required this.totalActive,
    required this.onDelivery,
    required this.drivers,
    required this.updatedAt,
  });

  factory ActiveDriversResponse.fromJson(Map<String, dynamic> json) {
    return ActiveDriversResponse(
      totalActive: json['total_active'],
      onDelivery: json['on_delivery'],
      drivers: (json['drivers'] as List)
          .map((d) => DriverLocation.fromJson(d))
          .toList(),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
```

**Testing:**
```bash
# Create test file
flutter test test/models/driver_location_test.dart
```

---

## Phase 3: Location Service (Day 3-4)

### Step 3.1: Create Location Service

**File:** `frontend/lib/services/location_service.dart`

```dart
import 'dart:async';
import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  final Battery _battery = Battery();

  /// Check and request location permissions
  Future<bool> checkAndRequestPermissions() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      log('[LocationService] Location services are disabled');
      return false;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        log('[LocationService] Location permissions denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      log('[LocationService] Location permissions permanently denied');
      return false;
    }

    log('[LocationService] Location permissions granted');
    return true;
  }

  /// Request background location permission (Android 10+)
  Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Start continuous location tracking
  Stream<Position> startLocationTracking({
    int updateIntervalSeconds = 10,
    bool highAccuracy = true,
  }) {
    final locationSettings = LocationSettings(
      accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
      distanceFilter: 10, // Update every 10 meters
      timeLimit: Duration(seconds: updateIntervalSeconds),
    );

    log('[LocationService] Starting location tracking (interval: ${updateIntervalSeconds}s)');
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Get single location update
  Future<Position?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      log('[LocationService] Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      log('[LocationService] getCurrentLocation error: $e');
      return null;
    }
  }

  /// Get current battery level
  Future<int?> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      log('[LocationService] getBatteryLevel error: $e');
      return null;
    }
  }

  /// Check if battery is in low power mode
  Future<bool> isLowBattery() async {
    final level = await getBatteryLevel();
    return level != null && level < 20;
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    log('[LocationService] Location tracking stopped');
  }

  /// Calculate distance between two points (in meters)
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calculate bearing/heading between two points (in degrees)
  double calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }
}
```

### Step 3.2: Create Tracking API Service

**File:** `frontend/lib/services/tracking_service.dart`

```dart
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/driver_location.dart';
import '../config/api_config.dart';

class TrackingService {
  final String baseUrl = ApiConfig.baseUrl;

  /// Driver: Update current location
  Future<bool> updateLocation(
    String token, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? altitudeMeters,
    int? headingDegrees,
    double? speedMps,
    int? batteryLevel,
  }) async {
    final url = Uri.parse('$baseUrl/api/driver/location');
    final timestamp = DateTime.now().toIso8601String();

    final body = {
      'latitude': latitude,
      'longitude': longitude,
      'location_timestamp': timestamp,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (altitudeMeters != null) 'altitude_meters': altitudeMeters,
      if (headingDegrees != null) 'heading_degrees': headingDegrees,
      if (speedMps != null) 'speed_mps': speedMps,
      if (batteryLevel != null) 'battery_level': batteryLevel,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      log('[TrackingService] updateLocation: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        log('[TrackingService] updateLocation failed: ${response.body}');
        return false;
      }
    } catch (e) {
      log('[TrackingService] updateLocation error: $e');
      return false;
    }
  }

  /// Driver: Start tracking session
  Future<Map<String, dynamic>?> startTrackingSession(
    String token, {
    int? orderId,
  }) async {
    final url = Uri.parse('$baseUrl/api/driver/tracking/start');

    final body = {
      if (orderId != null) 'order_id': orderId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      log('[TrackingService] startTrackingSession: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        return null;
      }
    } catch (e) {
      log('[TrackingService] startTrackingSession error: $e');
      return null;
    }
  }

  /// Driver: Stop tracking session
  Future<bool> stopTrackingSession(String token) async {
    final url = Uri.parse('$baseUrl/api/driver/tracking/stop');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      log('[TrackingService] stopTrackingSession: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      log('[TrackingService] stopTrackingSession error: $e');
      return false;
    }
  }

  /// Admin: Get all active drivers
  Future<ActiveDriversResponse?> getActiveDrivers(String token) async {
    final url = Uri.parse('$baseUrl/api/admin/tracking/active-drivers');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      log('[TrackingService] getActiveDrivers: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ActiveDriversResponse.fromJson(data['data']);
      } else {
        return null;
      }
    } catch (e) {
      log('[TrackingService] getActiveDrivers error: $e');
      return null;
    }
  }

  /// Customer: Get driver location for specific order
  Future<DriverLocation?> getOrderDriverLocation(
    String token,
    int orderId,
  ) async {
    final url = Uri.parse('$baseUrl/api/orders/$orderId/driver-location');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DriverLocation.fromJson(data['data']);
      } else {
        return null;
      }
    } catch (e) {
      log('[TrackingService] getOrderDriverLocation error: $e');
      return null;
    }
  }

  /// Get location history for order
  Future<List<LocationHistoryPoint>> getOrderLocationHistory(
    String token,
    int orderId,
  ) async {
    final url = Uri.parse('$baseUrl/api/orders/$orderId/location-history');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final points = (data['data']['points'] as List)
            .map((json) => LocationHistoryPoint.fromJson(json))
            .toList();
        return points;
      } else {
        return [];
      }
    } catch (e) {
      log('[TrackingService] getOrderLocationHistory error: $e');
      return [];
    }
  }
}
```

**Testing:**
```bash
flutter test test/services/location_service_test.dart
flutter test test/services/tracking_service_test.dart
```

---

## Phase 4: Driver Tracking Screen (Day 5-6)

### Step 4.1: Create Driver Tracking Screen

**File:** `frontend/lib/screens/driver/active_delivery_tracking_screen.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/location_service.dart';
import '../../services/tracking_service.dart';
import '../../providers/auth_provider.dart';

class ActiveDeliveryTrackingScreen extends StatefulWidget {
  final int orderId;

  const ActiveDeliveryTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<ActiveDeliveryTrackingScreen> createState() =>
      _ActiveDeliveryTrackingScreenState();
}

class _ActiveDeliveryTrackingScreenState
    extends State<ActiveDeliveryTrackingScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final TrackingService _trackingService = TrackingService();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  bool _isTracking = false;
  int _updatesSent = 0;
  DateTime? _lastUpdateTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    // Check permissions
    final hasPermission = await _locationService.checkAndRequestPermissions();
    if (!hasPermission) {
      setState(() {
        _errorMessage = 'Location permission denied. Please enable in settings.';
      });
      _showPermissionDialog();
      return;
    }

    // Request background permission
    final hasBackground = await _locationService.requestBackgroundPermission();
    if (!hasBackground) {
      setState(() {
        _errorMessage = 'Background location permission needed for tracking.';
      });
    }

    // Start tracking
    _startTracking();
  }

  Future<void> _startTracking() async {
    if (_isTracking) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      setState(() => _errorMessage = 'Not authenticated');
      return;
    }

    // Start tracking session
    final session = await _trackingService.startTrackingSession(
      token,
      orderId: widget.orderId,
    );

    if (session == null) {
      setState(() => _errorMessage = 'Failed to start tracking session');
      return;
    }

    setState(() {
      _isTracking = true;
      _errorMessage = null;
    });

    // Start location updates every 10 seconds
    _positionStream = _locationService
        .startLocationTracking(
      updateIntervalSeconds: 10,
      highAccuracy: true,
    )
        .listen((position) {
      _handleLocationUpdate(position, token);
    });
  }

  Future<void> _handleLocationUpdate(Position position, String token) async {
    setState(() {
      _currentPosition = position;
      _lastUpdateTime = DateTime.now();
    });

    // Get battery level
    final batteryLevel = await _locationService.getBatteryLevel();

    // Send to backend
    final success = await _trackingService.updateLocation(
      token,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      altitudeMeters: position.altitude,
      headingDegrees:
          position.heading.isFinite ? position.heading.toInt() : null,
      speedMps: position.speed,
      batteryLevel: batteryLevel,
    );

    if (success) {
      setState(() => _updatesSent++);
    } else {
      setState(() => _errorMessage = 'Failed to update location');
    }
  }

  Future<void> _stopTracking() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token != null) {
      await _trackingService.stopTrackingSession(token);
    }

    _positionStream?.cancel();
    setState(() {
      _isTracking = false;
      _updatesSent = 0;
      _currentPosition = null;
      _lastUpdateTime = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isTracking) {
      print('[Tracking] App paused, continuing background tracking');
    } else if (state == AppLifecycleState.resumed) {
      print('[Tracking] App resumed');
    }
  }

  @override
  void dispose() {
    _stopTracking();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location permission to track deliveries. Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else {
      return '${diff.inMinutes}m ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active Delivery #${widget.orderId}'),
        actions: [
          Icon(
            _isTracking ? Icons.gps_fixed : Icons.gps_off,
            color: _isTracking ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Tracking status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildStatusRow(
                      'Tracking Active',
                      _isTracking ? 'Yes' : 'No',
                      _isTracking ? Colors.green : Colors.red,
                    ),
                    _buildStatusRow(
                      'Updates Sent',
                      '$_updatesSent',
                      Colors.blue,
                    ),
                    if (_lastUpdateTime != null)
                      _buildStatusRow(
                        'Last Update',
                        _formatTime(_lastUpdateTime!),
                        Colors.grey,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current location card
            if (_currentPosition != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
                      Text(
                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                      Text(
                          'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(1)} m'),
                      Text(
                          'Speed: ${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h'),
                      if (_currentPosition!.heading.isFinite)
                        Text(
                            'Heading: ${_currentPosition!.heading.toStringAsFixed(0)}°'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Control button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: _isTracking
                  ? ElevatedButton.icon(
                      onPressed: _stopTracking,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _startTracking,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 5: Admin Dashboard Map View (Day 7-9)

### Step 5.1: Create Driver Tracking Map Screen

**File:** `frontend/lib/screens/admin/driver_tracking_map_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';
import '../../models/driver_location.dart';
import '../../services/tracking_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/mapbox_config.dart';
import 'dart:async';

class DriverTrackingMapScreen extends StatefulWidget {
  const DriverTrackingMapScreen({super.key});

  @override
  State<DriverTrackingMapScreen> createState() =>
      _DriverTrackingMapScreenState();
}

class _DriverTrackingMapScreenState extends State<DriverTrackingMapScreen> {
  final TrackingService _trackingService = TrackingService();

  MapboxMapController? _mapController;
  Map<int, DriverLocation> _driverLocations = {};
  Map<int, Symbol> _driverMarkers = {};

  bool _isLoading = true;
  Timer? _refreshTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    // Load initial driver locations
    await _loadActiveDrivers();

    // Poll every 10 seconds for updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadActiveDrivers();
    });

    setState(() => _isLoading = false);
  }

  Future<void> _loadActiveDrivers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) return;

    try {
      final response = await _trackingService.getActiveDrivers(token);
      if (response != null) {
        setState(() {
          _driverLocations = {
            for (var driver in response.drivers) driver.driverId: driver
          };
          _errorMessage = null;
        });
        _updateMarkers();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load active drivers: $e');
    }
  }

  void _updateMarkers() {
    if (_mapController == null) return;

    for (var location in _driverLocations.values) {
      _updateDriverMarker(location);
    }
  }

  Future<void> _updateDriverMarker(DriverLocation location) async {
    if (_mapController == null) return;

    final latLng = LatLng(location.latitude, location.longitude);

    // Remove old marker if exists
    if (_driverMarkers.containsKey(location.driverId)) {
      await _mapController!.removeSymbol(_driverMarkers[location.driverId]!);
    }

    // Add new marker with rotation (heading)
    final symbol = await _mapController!.addSymbol(
      SymbolOptions(
        geometry: latLng,
        iconImage: 'marker-15', // Default Mapbox marker
        iconSize: 1.5,
        iconRotate: location.headingDegrees?.toDouble() ?? 0.0,
        iconAnchor: 'center',
        textField: location.driverName,
        textSize: 12.0,
        textOffset: const Offset(0, 1.5),
        textAnchor: 'top',
        textColor: '#000000',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 2.0,
      ),
    );

    _driverMarkers[location.driverId] = symbol;
  }

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    _updateMarkers();
  }

  Color _getStatusColor(DriverLocationStatus status) {
    switch (status) {
      case DriverLocationStatus.onDelivery:
        return Colors.green;
      case DriverLocationStatus.online:
        return Colors.blue;
      case DriverLocationStatus.paused:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _focusOnDriver(DriverLocation location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        15.0,
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveDrivers,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_driverLocations.length} Active',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Stack(
                  children: [
                    MapboxMap(
                      accessToken: MapboxConfig.accessToken,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          MapboxConfig.defaultLatitude,
                          MapboxConfig.defaultLongitude,
                        ),
                        zoom: MapboxConfig.defaultZoom,
                      ),
                      onMapCreated: _onMapCreated,
                      myLocationEnabled: false,
                      compassEnabled: true,
                      styleString: MapboxConfig.mapStyle,
                    ),
                    _buildDriverListPanel(),
                  ],
                ),
    );
  }

  Widget _buildDriverListPanel() {
    return Positioned(
      left: 16,
      top: 16,
      bottom: 16,
      width: 300,
      child: Card(
        elevation: 8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Active Drivers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Expanded(
              child: _driverLocations.isEmpty
                  ? const Center(child: Text('No active drivers'))
                  : ListView.builder(
                      itemCount: _driverLocations.length,
                      itemBuilder: (context, index) {
                        final location =
                            _driverLocations.values.elementAt(index);
                        return ListTile(
                          leading: Icon(
                            Icons.directions_car,
                            color: _getStatusColor(location.status),
                          ),
                          title: Text(location.driverName),
                          subtitle: Text(location.status.displayName),
                          trailing: location.orderId != null
                              ? Chip(label: Text('Order #${location.orderId}'))
                              : null,
                          onTap: () => _focusOnDriver(location),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 6: Navigation Integration (Day 10)

### Step 6.1: Add Routes

**File:** `frontend/lib/main.dart` (update routes)

```dart
import 'screens/driver/active_delivery_tracking_screen.dart';
import 'screens/admin/driver_tracking_map_screen.dart';

// In MaterialApp routes:
routes: {
  // ... existing routes ...

  '/driver/tracking': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return ActiveDeliveryTrackingScreen(orderId: args['order_id']);
  },

  '/admin/driver-tracking-map': (context) => const DriverTrackingMapScreen(),
},
```

### Step 6.2: Add Navigation from Driver Dashboard

**File:** `frontend/lib/screens/driver/driver_dashboard_screen.dart`

```dart
// Add button to start tracking for active order
ElevatedButton.icon(
  onPressed: () {
    Navigator.pushNamed(
      context,
      '/driver/tracking',
      arguments: {'order_id': activeOrder.id},
    );
  },
  icon: const Icon(Icons.navigation),
  label: const Text('Start Tracking'),
)
```

### Step 6.3: Add Navigation from Admin Dashboard

**File:** `frontend/lib/screens/admin/admin_dashboard_screen.dart`

```dart
// Add navigation tile for driver tracking map
ListTile(
  leading: const Icon(Icons.map),
  title: const Text('Driver Tracking Map'),
  onTap: () {
    Navigator.pushNamed(context, '/admin/driver-tracking-map');
  },
)
```

---

## Phase 7: Testing (Day 11-12)

### Step 7.1: Unit Tests

**File:** `frontend/test/services/location_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/services/location_service.dart';

void main() {
  group('LocationService', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
    });

    test('calculateDistance returns correct distance', () {
      // San Francisco to Los Angeles
      final distance = locationService.calculateDistance(
        37.7749, -122.4194, // SF
        34.0522, -118.2437, // LA
      );

      // Approximately 559 km
      expect(distance, greaterThan(500000));
      expect(distance, lessThan(600000));
    });

    test('getBatteryLevel returns value between 0 and 100', () async {
      final level = await locationService.getBatteryLevel();

      if (level != null) {
        expect(level, greaterThanOrEqualTo(0));
        expect(level, lessThanOrEqualTo(100));
      }
    });
  });
}
```

**File:** `frontend/test/models/driver_location_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/models/driver_location.dart';

void main() {
  group('DriverLocation', () {
    test('fromJson creates correct object', () {
      final json = {
        'driver_id': 1,
        'driver_name': 'John Doe',
        'latitude': 37.7749,
        'longitude': -122.4194,
        'heading_degrees': 90,
        'speed_mps': 5.2,
        'status': 'on_delivery',
        'order_id': 123,
        'updated_at': '2025-01-15T10:30:00Z',
      };

      final location = DriverLocation.fromJson(json);

      expect(location.driverId, 1);
      expect(location.driverName, 'John Doe');
      expect(location.latitude, 37.7749);
      expect(location.status, DriverLocationStatus.onDelivery);
    });

    test('toJson creates correct map', () {
      final location = DriverLocation(
        driverId: 1,
        driverName: 'John Doe',
        latitude: 37.7749,
        longitude: -122.4194,
        status: DriverLocationStatus.online,
        updatedAt: DateTime.parse('2025-01-15T10:30:00Z'),
      );

      final json = location.toJson();

      expect(json['driver_id'], 1);
      expect(json['latitude'], 37.7749);
      expect(json['status'], 'online');
    });
  });
}
```

### Step 7.2: Widget Tests

**File:** `frontend/test/screens/driver_tracking_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/screens/driver/active_delivery_tracking_screen.dart';

void main() {
  testWidgets('ActiveDeliveryTrackingScreen shows order ID', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveDeliveryTrackingScreen(orderId: 123),
      ),
    );

    expect(find.text('Active Delivery #123'), findsOneWidget);
  });

  testWidgets('Shows start tracking button when not tracking', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveDeliveryTrackingScreen(orderId: 123),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Start Tracking'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
```

### Step 7.3: Integration Tests

**File:** `frontend/integration_test/tracking_flow_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:delivery_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Driver can start and stop tracking', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Login as driver
    // Navigate to active delivery
    // Start tracking
    // Verify location updates sent
    // Stop tracking
    // Verify tracking stopped
  });

  testWidgets('Admin can view driver locations on map', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Login as admin
    // Navigate to driver tracking map
    // Verify map loads
    // Verify driver markers appear
  });
}
```

**Run Tests:**
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

---

## Deployment Checklist

### Android
- [ ] Add location permissions to `AndroidManifest.xml`
- [ ] Request background location permission at runtime
- [ ] Test on Android 10+ for background location restrictions
- [ ] Configure ProGuard rules if using obfuscation
- [ ] Test battery optimization impact

### iOS
- [ ] Add location usage descriptions to `Info.plist`
- [ ] Request "Always" location permission
- [ ] Configure background modes for location updates
- [ ] Test on iOS 14+ for location permission changes
- [ ] Submit privacy description to App Store

### General
- [ ] Add Mapbox access token to `MapboxConfig`
- [ ] Test HTTP polling on production server
- [ ] Verify SSL/TLS for HTTPS connections
- [ ] Test with multiple concurrent drivers
- [ ] Monitor battery drain during tracking
- [ ] Test offline/online transitions
- [ ] Verify location updates frequency (10s interval)
- [ ] Test permission flows on both platforms
- [ ] Configure polling interval (10 seconds recommended)
- [ ] Test map performance with 50+ active drivers

---

## Performance Optimization

1. **Location Updates**: Configurable interval (default 10s)
2. **Battery Saving**: Reduce accuracy and frequency when battery < 20%
3. **HTTP Polling**: Admin dashboard polls every 10 seconds
4. **Map Markers**: Reuse symbols instead of recreating
5. **Location History**: Limit displayed points to last 100

---

## Troubleshooting

### Common Issues

**Location permission denied:**
```dart
// Check if permission is permanently denied
if (permission == LocationPermission.deniedForever) {
  // Open app settings
  await Geolocator.openAppSettings();
}
```

**HTTP polling delays:**
```dart
// Adjust polling interval based on network conditions
final pollInterval = networkQuality == 'good'
  ? Duration(seconds: 10)
  : Duration(seconds: 15);
```

**Background tracking stops:**
```dart
// iOS: Ensure background modes enabled
// Android: Handle doze mode and battery optimization
// Use WorkManager for periodic background tasks
```

---

## Next Steps

After frontend is complete:
1. Test end-to-end flow with backend
2. Optimize battery consumption
3. Add push notifications for geofence events
4. Implement offline queue for location updates
5. Add analytics tracking
6. Create user documentation
7. Submit to app stores
