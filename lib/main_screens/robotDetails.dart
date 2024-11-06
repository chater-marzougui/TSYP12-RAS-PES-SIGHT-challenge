import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../values/classes.dart';

class RobotDetailsPage extends StatefulWidget {
  final String robotId;

  const RobotDetailsPage({super.key, required this.robotId});

  @override
  State<RobotDetailsPage> createState() => _RobotDetailsPageState();
}

class _RobotDetailsPageState extends State<RobotDetailsPage> {
  final RobotService _robotService = RobotService();
  late Future<Robot> _robotFuture;
  late MqttServerClient _client;
  bool _isRobotRunning = false;
  String _location = '';

  @override
  void initState() {
    super.initState();
    _robotFuture = _robotService.getRobotById(widget.robotId);
    _setupMqttClient();
  }

  void _setupMqttClient() async {
    _client = MqttServerClient('broker.hivemq.com', 'flutter_client_${widget.robotId}');
    _client.port = 1883;
    _client.logging(on: false);
    _client.onConnected = () => Fluttertoast.showToast(msg: 'MQTT Connected No Clients Subscribed');
    // flutter toast message when disconnected from mqtt_client.
    _client.onDisconnected = () => Fluttertoast.showToast(msg: 'Disconnected from MQTT');
    await _client.connect();
  }

  void _sendMqttCommand(String command) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(command);
    _client.publishMessage('robot/control/${widget.robotId}', MqttQos.atLeastOnce, builder.payload!);
  }

  void _toggleRobot() {
    setState(() {
      _isRobotRunning = !_isRobotRunning;
    });
    _sendMqttCommand(_isRobotRunning ? 'RUN' : 'STOP');
  }

  void _getLocation(Robot robot) async {
    final location = await getLocationFromLatLong(robot.currentLocation.latitude, robot.currentLocation.longitude);
    setState(() {
      if(location.displayName != "") {
        _location = location.displayName;
      } else {
        _location = getCurrentLocation(location.address);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Robot Details'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<Robot>(
        future: _robotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('Robot not found'));
          }
          Robot robot = snapshot.data!;
          _getLocation(robot);
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailHeader(robot),
                SizedBox(height: 20),
                _buildControlSection(),
                SizedBox(height: 20),
                _buildDetailSection(
                  'Robot Information',
                  [
                    'Model: ${robot.model}',
                    'Current Status: ${robot.status}',
                    'Trash Percentage: ${robot.trashCollectionPercentage}%',
                  ],
                  icon: Icons.info_outline,
                ),
                SizedBox(height: 20),
                _buildDetailSection(
                  'Battery & Location',
                  [
                    'Battery Level: ${robot.batteryLevel.toStringAsFixed(1)}%',
                    'Current Location: $_location',
                  ],
                  icon: Icons.battery_charging_full,
                ),
                SizedBox(height: 20),
                _buildDetailSection(
                  'Performance',
                  [
                    'Areas Cleaned Today: ${robot.totalAreasCleanedToday}',
                    'Assigned Areas: ${robot.assignedAreas.join(", ")}',
                    'Last Maintenance: ${robot.lastMaintenance.toLocal()}',
                  ],
                  icon: Icons.analytics_outlined,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control Robot',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent[700]),
            ),
            SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: _toggleRobot,
                icon: Icon(_isRobotRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isRobotRunning ? 'Stop Robot' : 'Run Robot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRobotRunning ? Colors.red : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailHeader(Robot robot) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.teal[100],
            child: Icon(Icons.cleaning_services, size: 50, color: Colors.blueAccent),
          ),
          SizedBox(height: 10),
          Text(
            robot.name,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(robot.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              robot.status.toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(robot.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> details, {required IconData icon}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent[700]),
                  ),
                  SizedBox(height: 10),
                  ...details.map((detail) => Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(detail, style: TextStyle(fontSize: 15)),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'charging':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
