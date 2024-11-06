import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../values/classes.dart';

class RobotProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Robot> _robots = [];
  bool _isLoading = false;

  List<Robot> get robots => _robots;
  bool get isLoading => _isLoading;

  // Fetch robots from Firestore
  Future<void> fetchRobots() async {
    _isLoading = true;
    notifyListeners();

    try {
      QuerySnapshot querySnapshot = await _firestore.collection('robots').get();
      _robots = querySnapshot.docs
          .map((doc) => Robot.fromFirestore(doc))
          .toList();
    } catch (e) {
      _robots = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Generate and add random robots to Firestore
  Future<void> generateRandomRobots() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Generate random robots
      List<Robot> randomRobots = Robot.generateRandomRobots();

      // Add each robot to Firestore
      for (var robot in randomRobots) {
        await _firestore.collection('robots').add(robot.toFirestore());
      }

      await fetchRobots();
    } catch (e) {
      print('Error generating random robots: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Update robot status
  Future<void> updateRobotStatus(String robotId, String newStatus) async {
    try {
      // Find the robot in the local list
      int index = _robots.indexWhere((robot) => robot.id == robotId);
      if (index != -1) {
        // Update local state
        _robots[index].status = newStatus;
        notifyListeners();

        // Update in Firestore
        await _firestore
            .collection('robots')
            .doc(robotId)
            .update({'status': newStatus});
      }
    } catch (e) {
      print('Error updating robot status: $e');
    }
  }
}