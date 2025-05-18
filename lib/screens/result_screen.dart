import 'package:flutter/material.dart';
import '../models/detection_model.dart';
import '../widgets/bounding_box_selector.dart';
import 'crop_screen.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final List<Detection> detections;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.detections,
  });

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late BoundingBox _currentBoundingBox;

  @override
  void initState() {
    super.initState();
    // Initialize with the first detection's bounding box
    if (widget.detections.isNotEmpty) {
      _currentBoundingBox = widget.detections.first.boundingBox;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logo Detection Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAndProceed,
            tooltip: 'Save and Proceed',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BoundingBoxSelector(
              imagePath: widget.imagePath,
              detections: widget.detections,
              onBoundingBoxChanged: (box) {
                setState(() {
                  _currentBoundingBox = box;
                });
              },
            ),
          ),
          _buildInfoPanel(),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final detection = widget.detections.first;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Detected: ${detection.className}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${(detection.confidence * 100).toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Bounding Box: (${_currentBoundingBox.x1}, ${_currentBoundingBox.y1}) - (${_currentBoundingBox.x2}, ${_currentBoundingBox.y2})',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'You can adjust the bounding box by tapping the "Edit Box" button.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _saveAndProceed() async {
    // Navigate to crop screen with the selected bounding box
    final croppedImagePath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(
          imagePath: widget.imagePath,
          boundingBox: _currentBoundingBox,
        ),
      ),
    );

    if (croppedImagePath != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image cropped successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Return to previous screen with the cropped image path
      Navigator.pop(context, croppedImagePath);
    }
  }
}
