import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class Journey {
  final String userId;
  final List<LatLng> points;
  final Color color;

  Journey({
    required this.userId,
    required this.points,
    required this.color,
  });
}

List<LatLng> generateRandomJourney(LatLng startLocation, int numPoints) {
  List<LatLng> journey = [];
  final random = Random();

  journey.add(startLocation);

  for (int i = 1; i < numPoints; i++) {
    // Create small random offsets to simulate movement
    double offsetLat = (random.nextDouble() - 0.5) / 1000;
    double offsetLng = (random.nextDouble() - 0.5) / 1000;

    LatLng previousPoint = journey.last;
    LatLng newPoint = LatLng(
      previousPoint.latitude + offsetLat,
      previousPoint.longitude + offsetLng,
    );

    journey.add(newPoint);
  }

  return journey;
}

List<LatLng> journeysFromFirestore(Map<String, dynamic> data, String id) {
  if (data['points'] is List) {
    List<LatLng> points = (data['points'] as List)
        .map((point) => LatLng(point['latitude'], point['longitude']))
        .toList();
    return points;
  }
  return [];
}



class Robot {
  final String id;
  String name;
  String model;
  String status;
  double batteryLevel;
  LatLng currentLocation; // Changed from String to LatLng
  DateTime lastMaintenance;
  List<String> assignedAreas;
  int totalAreasCleanedToday;
  double trashCollectionPercentage;

  Robot({
    required this.id,
    required this.name,
    required this.model,
    required this.status,
    required this.batteryLevel,
    required this.currentLocation, // Updated type to LatLng
    required this.lastMaintenance,
    required this.assignedAreas,
    required this.totalAreasCleanedToday,
    required this.trashCollectionPercentage,
  });

  // Factory constructor to create a Robot from Firestore document
  factory Robot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Robot(
      id: doc.id,
      name: data['name'] ?? 'Unknown Robot',
      model: data['model'] ?? 'Generic Cleaner',
      status: data['status'] ?? 'Offline',
      batteryLevel: (data['batteryLevel'] ?? 0.0).toDouble(),
      currentLocation: LatLng(
        data['currentLocation']['lat'] ?? 0.0,
        data['currentLocation']['lng'] ?? 0.0,
      ),
      lastMaintenance: (data['lastMaintenance'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAreas: List<String>.from(data['assignedAreas'] ?? []),
      totalAreasCleanedToday: data['totalAreasCleanedToday'] ?? 0,
      trashCollectionPercentage: (data['trashCollectionPercentage'] ?? 0.0).toDouble(),
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'model': model,
      'status': status,
      'batteryLevel': batteryLevel,
      'currentLocation': {
        'lat': currentLocation.latitude,
        'lng': currentLocation.longitude,
      },
      'lastMaintenance': Timestamp.fromDate(lastMaintenance),
      'assignedAreas': assignedAreas,
      'totalAreasCleanedToday': totalAreasCleanedToday,
      'trashCollectionPercentage': trashCollectionPercentage,
    };
  }

  static List<Robot> generateRandomRobots() {
    final random = Random();
    final status = ['Active', 'Charging', 'Maintenance', 'Offline'];
    final robotNames = ['CleanMaster 3000', 'UrbanSweeper', 'CityBot', 'StreetCleaner Pro'];
    final models = ['Compact Cleaner', 'Heavy Duty', 'Urban Maintenance', 'Precision Clean'];


    return List.generate(4, (index) {
      return Robot(
        id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(),
        name: robotNames[random.nextInt(robotNames.length)],
        model: models[random.nextInt(models.length)],
        status: status[random.nextInt(status.length)],
        batteryLevel: random.nextDouble() * 100,
        currentLocation: generateRandomLocation(35.56203,9.61098),
        lastMaintenance: DateTime.now().subtract(Duration(days: random.nextInt(30))),
        assignedAreas: List.generate(
          random.nextInt(3) + 1,
              (_) => ['Downtown', 'Residential Area', 'Industrial Zone', 'City Center'][random.nextInt(4)],
        ),
        totalAreasCleanedToday: random.nextInt(10),
        trashCollectionPercentage: random.nextDouble() * 100,
      );
    });
  }
}

LatLng generateRandomLocation(double latitude, double longitude) {
  // Range for randomization (around 0.01 degrees, which is approx. 1.1km)
  const double latRange = 0.5;
  const double longRange = 0.5;

  double randomLat = latitude + Random().nextDouble() * latRange - (latRange / 2);
  double randomLong = longitude + Random().nextDouble() * longRange - (longRange / 2);

  return LatLng(randomLat, randomLong);
}

class RobotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Robot>> getRobots() {
    return _firestore
        .collection('robots')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Robot.fromFirestore(doc)).toList());
  }

  Future<Robot> getRobotById(String id) async {
    DocumentSnapshot doc = await _firestore.collection('robots').doc(id).get();
    return Robot.fromFirestore(doc);
  }
}


class NominatimReverse {
  double lat;
  double lon;
  String addressType;
  String name;
  String displayName;
  Address address;
  List<String> boundingBox;

  NominatimReverse(
      {required this.lat,
        required this.lon,
        required this.addressType,
        required this.name,
        required this.displayName,
        required this.address,
        required this.boundingBox});

  factory NominatimReverse.fromJson(Map<String, dynamic> json) {
    return NominatimReverse(
        lat: double.parse(json['lat']),
        lon: double.parse(json['lon']),
        addressType: json['addresstype'],
        name: json['name'],
        displayName: json['display_name'],
        address: Address.fromJson(json['address']),
        boundingBox: List<String>.from(json['boundingbox']));
  }
}

class Address {
  String road;
  String suburb;
  String village;
  String stateDistrict;
  String state;
  String postcode;
  String county;
  String country;
  String countryCode;

  Address(
      {required this.road,
        required this.village,
        required this.suburb,
        required this.stateDistrict,
        required this.state,
        required this.postcode,
        required this.county,
        required this.country,
        required this.countryCode});

  factory Address.fromJson(Map<String, dynamic> json) {
    bool isNormalType = json['country'] != null;

    if (isNormalType) {
      return Address(
        road: json['road'] ?? "",
        suburb: json['suburb'] ?? "",
        village: json['village'] ?? "",
        stateDistrict: json['state_district'] ?? "",
        state: json['state'] ?? "",
        postcode: json['postcode'] ?? "",
        county: json['county'] ?? "",
        country: json['country'] ?? "",
        countryCode: json['country_code'] ?? "",
      );
    } else {
      String road = "";
      String suburb = "";
      String village = "";
      String stateDistrict = "";
      String state = "";
      String postcode = "";
      String county = "";
      String country = "";
      String countryCode = "";

      final List<dynamic> components = json.values as List<dynamic>;

      for (var component in components) {
        switch (component['type']) {
          case 'road':
          case 'residential':
            road = component['localname'] ?? "";
            break;
          case 'suburb':
            suburb = component['localname'] ?? "";
            break;
          case 'village':
            village = component['localname'] ?? "";
            break;
          case 'administrative':
          // Check admin_level to determine the type of administrative division
            switch (component['admin_level']) {
              case 4:
                state = component['localname'] ?? "";
                break;
              case 5:
                stateDistrict = component['localname'] ?? "";
                break;
              case 6:
                county = component['localname'] ?? "";
                break;
            }
            break;
          case 'postcode':
            postcode = component['localname'] ?? "";
            break;
          case 'country':
            country = component['localname'] ?? "";
            break;
          case 'country_code':
            countryCode = component['localname'] ?? "";
            break;
        }
      }

      return Address(
        road: road,
        suburb: suburb,
        village: village,
        stateDistrict: stateDistrict,
        state: state,
        postcode: postcode,
        county: county,
        country: country,
        countryCode: countryCode,
      );
    }
  }
}

Future<NominatimReverse> getLocationFromLatLong(double lat, double long) async {
  try {
    final response = await http.get(
      Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$long'),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'samsar/0.2.0',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = NominatimReverse.fromJson(jsonDecode(response.body));
      return jsonData;
    } else {
      throw Exception('Failed to load location data: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error getting location data: $e');
  }
}

String getCurrentLocation(Address address) {
  String loc;
  if (address.county != "") {
    loc = address.county;
  } else if (address.suburb != "") {
    loc = address.suburb;
  } else if (address.stateDistrict != "") {
    loc = address.stateDistrict;
  } else if (address.state != "") {
    loc = address.state;
  } else if (address.village != "") {
    loc = address.village;
  } else {
    loc = address.country;
  }
  return loc;
}
