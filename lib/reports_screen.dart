import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ReportDirtyPlaceScreen extends StatefulWidget {
  final String userID;

  const ReportDirtyPlaceScreen({super.key, required this.userID});

  @override
  State<ReportDirtyPlaceScreen> createState() => _ReportDirtyPlaceScreenState();
}

class _ReportDirtyPlaceScreenState extends State<ReportDirtyPlaceScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final TextEditingController _descriptionController = TextEditingController();

  Future<void> _getImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  Future<LatLng> _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.best),
    );
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _submitReport() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a photo first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current location
      final location = await _getCurrentLocation();

      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('reports')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(_image!);
      final imageUrl = await storageRef.getDownloadURL();

      // Save report to Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': widget.userID,
        'imageUrl': imageUrl,
        'description': _descriptionController.text,
        'location': GeoPoint(location.latitude, location.longitude),
        'timestamp': FieldValue.serverTimestamp(),
        'isTreated': false,
      });

      // Clear form and show success message
      setState(() {
        _image = null;
        _descriptionController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Dirty Place'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image != null)
              Image.file(
                _image!,
                height: 200,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 200,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.camera_alt,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _getImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReport,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}