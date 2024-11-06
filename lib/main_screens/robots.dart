import 'package:cleaner_tunisia/main_screens/robotDetails.dart';
import 'package:cleaner_tunisia/helpers/robot_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../values/classes.dart';

class RobotOverviewPage extends StatefulWidget {
  const RobotOverviewPage({super.key});

  @override
  State<RobotOverviewPage> createState() => _RobotOverviewPageState();
}

class _RobotOverviewPageState extends State<RobotOverviewPage> {
  @override
  void initState() {
    super.initState();

    // Fetch robots when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RobotProvider>(context, listen: false).fetchRobots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Robots Management'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              // Generate random robots
              Provider.of<RobotProvider>(context, listen: false)
                  .generateRandomRobots();
            },
          ),
        ],
      ),
      body: Consumer<RobotProvider>(
        builder: (context, robotProvider, child) {
          if (robotProvider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (robotProvider.robots.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No robots found'),
                  ElevatedButton(
                    onPressed: () {
                      robotProvider.generateRandomRobots();
                    },
                    child: Text('Generate Random Robots'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: robotProvider.robots.length,
                  itemBuilder: (context, index) {
                    Robot robot = robotProvider.robots[index];
                    return RobotOverviewCard(robot: robot);
                  },
                ),
              ),
              SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }
}

class RobotOverviewCard extends StatelessWidget {
  final Robot robot;

  const RobotOverviewCard({super.key, required this.robot});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getGradientColors(robot.status),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _buildLeadingWidget(),
            title: _buildTitleSection(),
            subtitle: _buildSubtitleSection(),
            trailing: _buildTrailingSection(context),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RobotDetailsPage(robotId: robot.id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingWidget() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Battery circle
        CircularProgressIndicator(
          value: robot.batteryLevel / 100,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(_getBatteryColor(robot.batteryLevel)),
        ),
        // Battery percentage text
        Text(
          '${robot.batteryLevel.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          robot.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        Text(
          robot.model,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        _buildTrashCollectionIndicator(),
      ],
    );
  }

  Widget _buildTrashCollectionIndicator() {
    return Row(
      children: [
        Icon(
          Icons.delete_sweep,
          color: _getTrashColor(robot.trashCollectionPercentage),
          size: 20,
        ),
        SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: robot.trashCollectionPercentage / 100,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getTrashColor(robot.trashCollectionPercentage),
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          '${robot.trashCollectionPercentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingSection(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.white,
      onSelected: (String newStatus) {
        Provider.of<RobotProvider>(context, listen: false)
            .updateRobotStatus(robot.id, newStatus);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'Active',
          child: Text('Start Moving'),
        ),
        const PopupMenuItem<String>(
          value: 'Charging',
          child: Text('Start Charging'),
        ),
        const PopupMenuItem<String>(
          value: 'Maintenance',
          child: Text('Send to Maintenance'),
        ),
        const PopupMenuItem<String>(
          value: 'Offline',
          child: Text('Take Offline'),
        ),
      ],
      child: Text(
        robot.status,
        style: TextStyle(
          color: _getStatusColor(robot.status),
          fontWeight: FontWeight.bold,
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

  Color _getBatteryColor(double batteryLevel) {
    if (batteryLevel > 70) return Colors.green;
    if (batteryLevel > 30) return Colors.orange;
    return Colors.red;
  }

  Color _getTrashColor(double trashPercentage) {
    if (trashPercentage > 80) return Colors.red;
    if (trashPercentage > 50) return Colors.orange;
    return Colors.green;
  }

  List<Color> _getGradientColors(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return [
          Colors.green.shade400.withOpacity(0.6),
          Colors.green.shade600.withOpacity(0.6)
        ];
      case 'charging':
        return [
          Colors.blue.shade400.withOpacity(0.6),
          Colors.blue.shade600.withOpacity(0.6)
        ];
      case 'maintenance':
        return [
          Colors.orange.shade400.withOpacity(0.6),
          Colors.orange.shade600.withOpacity(0.6)
        ];
      case 'offline':
        return [
          Colors.red.shade400.withOpacity(0.6),
          Colors.red.shade600.withOpacity(0.6)
        ];
      default:
        return [
          Colors.grey.shade400.withOpacity(0.6),
          Colors.grey.shade600.withOpacity(0.6)
        ];
    }
  }
}