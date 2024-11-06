
import 'dart:async';

import 'package:cleaner_tunisia/helpers/robot_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../helpers/cached_tile_provider.dart';
import '../reports_pages.dart';
import '../values/classes.dart';

class HomeScreen extends StatefulWidget {
  final String userID;
  const HomeScreen({super.key, required this.userID});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool isMapReady = false;
  List<Report> _reports = [];

  final MapController _mapController = MapController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final List<Color> _journeyColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  LatLng? _currentPosition;
  LatLng _currentMapCenter = const LatLng(36.8002275, 10.186199454411298);
  double _zoomLevel = 9.0;
  bool _isLoading = true;
  List<Journey> _journeys = [];
  List<Robot> _robots = [];
  Report? _selectedReport;


  final List<LatLng> _currentJourneyPoints = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTrackingLocation = false;
  Timer? _locationUpdateTimer;
  final int _locationUpdateInterval = 10;
  bool _hasLocationPermission = false;
  bool _hasInternetConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RobotProvider>(context, listen: false).fetchRobots();
    });
    _initializeApp();
    _robots = RobotProvider().robots;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationTracking();
    _locationUpdateTimer?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _handleAppBackground();
        break;
      case AppLifecycleState.resumed:
        _handleAppForeground();
        break;
      case AppLifecycleState.hidden:
        _handleAppBackground();
    }
  }

  Future<void> _handleAppBackground() async {
    if (_currentJourneyPoints.isNotEmpty) {
      await _uploadCurrentJourney();
    }
    _stopLocationTracking();
  }

  Future<void> _handleAppForeground() async {
    await _checkPermissionsAndConnectivity();
    if (_hasLocationPermission && _hasInternetConnection) {
      _startLocationTracking();
    }
  }

  Future<void> _initializeApp() async {
    await _checkPermissionsAndConnectivity();
    if (_hasLocationPermission && _hasInternetConnection) {
      _startLocationTracking();
      await _fetchJourneys();
      await _fetchReports();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkPermissionsAndConnectivity() async {
    await _checkLocationPermission();
    await _checkInternetConnectivity();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      final result = await Permission.location.request();
      _hasLocationPermission = result.isGranted;
    } else {
      _hasLocationPermission = status.isGranted;
    }

    if (!_hasLocationPermission) {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _checkInternetConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult.isEmpty) {
      _showNoInternetDialog();
    } else {
      _hasInternetConnection = true;
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Required'),
          content: Text(
              'This app needs location permission to track your journey. '
                  'Please grant location permission in your device settings.'
          ),
          actions: [
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('No Internet Connection'),
          content: Text(
              'Please check your internet connection. '
                  'The app needs internet to save your journey.'
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _startLocationTracking() {
    if (_isTrackingLocation) return;

    _isTrackingLocation = true;
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _updateCurrentPosition(position);
    });

    // Set up timer for adding points to journey
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: _locationUpdateInterval),
          (timer) => _addCurrentPositionToJourney(),
    );
  }

  void _stopLocationTracking() {
    _isTrackingLocation = false;
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
  }

  void _updateCurrentPosition(Position position) {
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, _zoomLevel);
      }
    });
  }

  void _addCurrentPositionToJourney() {
    if (_currentPosition != null) {
      if(_currentJourneyPoints.isEmpty) {
        setState(() {
          _currentJourneyPoints.add(_currentPosition!);
        });
      } else if(_currentJourneyPoints.last != _currentPosition || _currentJourneyPoints.length < 2) {
        setState(() {
          _currentJourneyPoints.add(_currentPosition!);
        });
      }
    }
  }

  Future<void> _uploadCurrentJourney() async {
    if (_currentJourneyPoints.isEmpty || !_hasInternetConnection) return;

    try {
      List<Map<String, double>> pointsData = _currentJourneyPoints.map((point) {
        return {
          'latitude': point.latitude,
          'longitude': point.longitude,
        };
      }).toList();

      if(pointsData.length < 2) return;
      await _db.collection('journeys').add({
        'userId': widget.userID,
        'points': pointsData,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _currentJourneyPoints.clear();
      });
    } catch (e) {
      Exception('Error uploading journey: $e');
    }
  }


  Future<void> _fetchJourneys() async {
    final journeys = await _getDataFromFireStore();
    final robots = await _getRobotsFromFirestore();
    setState(() {
      _journeys = journeys;
      _robots = robots;
      _isLoading = false;
    });
  }

  Future<List<Journey>> _getDataFromFireStore() async {
    QuerySnapshot snapshot = await _db.collection('journeys').get();
    List<Journey> journeys = [];
    int colorIndex = 0;

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String userId = data['userId'] ?? 'unknown';
      List<LatLng> points = [];

      if (data['points'] is List) {
        points = (data['points'] as List)
            .map((point) => LatLng(
          point['latitude'] as double,
          point['longitude'] as double,
        ))
            .toList();
      }

      if (points.isNotEmpty) {
        journeys.add(Journey(
          userId: userId,
          points: points,
          color: _journeyColors[colorIndex % _journeyColors.length],
        ));
        colorIndex++;
      }
    }

    return journeys;
  }

  Future<List<Robot>> _getRobotsFromFirestore() async {
    QuerySnapshot snapshot = await _db.collection('robots').get();
    List<Robot> robots = [];

    for (var doc in snapshot.docs) {
      robots.add(Robot.fromFirestore(doc));
    }

    return robots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentMapCenter,
              initialZoom: _zoomLevel,
              maxZoom: 19,
              minZoom: 4.5,
              onMapReady: () {
                setState(() {
                  isMapReady = true;
                });
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, _zoomLevel);
                }
              },
              onPositionChanged: (mapPosition, _) {
                _currentMapCenter = mapPosition.center;
                _zoomLevel = mapPosition.zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: CachedTileProvider(),
              ),
              // Draw completed journeys
              PolylineLayer(
                polylines: [
                  ..._journeys.map((journey) => Polyline(
                    points: journey.points,
                    color: journey.color,
                    strokeWidth: 3.0,
                  )),
                  // Draw current journey
                  if (_currentJourneyPoints.isNotEmpty)
                    Polyline(
                      points: _currentJourneyPoints,
                      color: Colors.blue,
                      strokeWidth: 3.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Current position marker
                  // if (_currentPosition != null)
                  //   Marker(
                  //     point: _currentPosition!,
                  //     width: 40,
                  //     height: 40,
                  //     child: const Icon(
                  //       Icons.person_pin_circle,
                  //       color: Colors.red,
                  //       size: 40.0,
                  //     ),
                  //   ),
                  // Markers for completed journeys
                  ..._getJourneyMarkers(),
                  ..._getRobotsMarkers(),
                  ..._getReports(),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          _buildControls(),
        ],
      ),
    );
  }

  List<Marker> _getRobotsMarkers() {
    List<Marker> markers = [];

    for (var robot in _robots) {
      markers.add(Marker(
        point: robot.currentLocation,
        width: 30,
        height: 30,
        child: Image.asset(
          'assets/img/robot.png',
          width: 30.0,
          height: 30.0,
          semanticLabel: 'Robot',
        ),
      ));
    }
    return markers;
  }

  List<Marker> _getJourneyMarkers() {
    List<Marker> markers = [];

    // Add markers for completed journeys
    for (var journey in _journeys) {
      if (journey.points.isNotEmpty) {
        // Start marker
        markers.add(Marker(
          point: journey.points.first,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ));

        // End marker
        markers.add(Marker(
          point: journey.points.last,
          width: 20,
          height: 20,
          child: Icon(
            Icons.close,
            color: Colors.red,
            size: 20,
          ),
        ));
      }
    }

    // Add markers for current journey
    if (_currentJourneyPoints.isNotEmpty) {
      markers.add(Marker(
        point: _currentJourneyPoints.first,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ));
    }

    return markers;
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 120,
      left: 20,
      child: Column(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            color: Colors.blue,
            iconSize: 36.0,
          ),
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            color: Colors.blue,
            iconSize: 36.0,
          ),
        ],
      ),
    );
  }

  List<Marker> _getReports() {
    return _reports.map((report) {
      return Marker(
        point: report.location,
        width: 20,
        height: 20,
        child: GestureDetector(
          onTap: () => _showReportDetails(report),
          child: Icon(
            Icons.report,
            color: report.isTreated ? Colors.green : Colors.yellowAccent,
            size: 20,
          ),
        ),
      );
    }).toList();
  }
  void _showReportDetails(Report report) {
    setState(() {
      _selectedReport = report;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.6,
        maxChildSize: 0.6,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                report.imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Status and Timestamp Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      report.isTreated ? Icons.check_circle : Icons.access_time,
                      color: report.isTreated ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.isTreated ? "Treated" : "Pending",
                      style: TextStyle(
                        fontSize: 16,
                        color: report.isTreated ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  report.timestamp.toString().split('.')[0],
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              "Description",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            // Additional options/actions (if needed)
            ElevatedButton.icon(
              onPressed: () {
                // Placeholder for additional actions, e.g., delete report, mark as treated, etc.
              },
              icon: Icon(Icons.edit),
              label: Text("Edit Report"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .get();

    _reports = snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching reports: $e')),
        );
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel++;
      _mapController.move(_currentMapCenter, _zoomLevel);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel--;
      _mapController.move(_currentMapCenter, _zoomLevel);
    });
  }
}
