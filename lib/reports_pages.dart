import 'package:cleaner_tunisia/main_screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String imageUrl;
  final String description;
  final LatLng location;
  final DateTime timestamp;
  final bool isTreated;
  final String userId;

  Report({
    required this.id,
    required this.imageUrl,
    required this.description,
    required this.location,
    required this.timestamp,
    required this.isTreated,
    required this.userId,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final GeoPoint geoPoint = data['location'] as GeoPoint;
    print(data.values);
    return Report(
      id: doc.id,
      imageUrl: data['imageUrl'],
      description: data['description'] ?? '',
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isTreated: data['isTreated'] ?? false,
      userId: data['userId'],
    );
  }
}

class ViewReportsScreen extends StatefulWidget {
  final String userID;
  const ViewReportsScreen({super.key, required this.userID});

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen> {
  final MapController _mapController = MapController();
  List<Report> _reports = [];
  bool _isLoading = true;
  Report? _selectedReport;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _reports = snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching reports: $e')),
        );
      }
    }
  }

  void _showReportDetails(Report report) {
    setState(() {
      _selectedReport = report;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.network(
                report.imageUrl,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(child: CircularProgressIndicator());
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status: ${report.isTreated ? "Treated" : "Pending"}',
                          style: TextStyle(
                            color: report.isTreated ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          report.timestamp.toString().split('.')[0],
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reported Places'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _reports.isNotEmpty
              ? _reports.first.location
              : const LatLng(36.8002275, 10.186199454411298),
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate:
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          MarkerLayer(
            markers: _reports.map((report) {
              return Marker(
                point: report.location,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showReportDetails(report),
                  child: Icon(
                    Icons.location_on,
                    color: report.isTreated ? Colors.green : Colors.red,
                    size: 40,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReportDirtyPlaceScreen(userID: widget.userID),
            ),
          );
          _fetchReports(); // Refresh reports after returning
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}