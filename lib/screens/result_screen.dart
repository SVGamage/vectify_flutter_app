import 'dart:io';
import 'package:flutter/material.dart';
import '../models/detection_model.dart';
import '../widgets/bounding_box_selector.dart';
import '../utils/image_utils.dart';

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
  bool _showCroppedImage = false;
  String? _croppedImagePath;
  bool _isLoading = false;

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
          if (!_showCroppedImage)
            IconButton(
              icon: const Icon(Icons.crop),
              onPressed: _cropImage,
              tooltip: 'Crop Image',
            ),
          if (_showCroppedImage)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _showCroppedImage = false),
              tooltip: 'Edit Crop',
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _showCroppedImage ? _saveAndProceed : _cropImage,
            tooltip:
                _showCroppedImage ? 'Save and Proceed' : 'Crop and Preview',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _showCroppedImage
                      ? _buildCroppedImageView()
                      : BoundingBoxSelector(
                          imagePath: widget.imagePath,
                          detections: widget.detections,
                          onBoundingBoxChanged: (box) {
                            setState(() {
                              _currentBoundingBox = box;
                              // Reset cropped image when box changes
                              if (_croppedImagePath != null) {
                                _croppedImagePath = null;
                                _showCroppedImage = false;
                              }
                            });
                          },
                        ),
                ),
                _buildInfoPanel(),
              ],
            ),
    );
  }

  Widget _buildCroppedImageView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_croppedImagePath != null)
          Image.file(
            File(_croppedImagePath!),
            fit: BoxFit.contain,
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'adjust_crop',
            onPressed: () => setState(() => _showCroppedImage = false),
            child: const Icon(Icons.edit),
            backgroundColor: Colors.blue.withOpacity(0.7),
          ),
        ),
      ],
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
          if (_showCroppedImage && _croppedImagePath != null)
            Text(
              'Image cropped successfully',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              'Bounding Box: (${_currentBoundingBox.x1}, ${_currentBoundingBox.y1}) - (${_currentBoundingBox.x2}, ${_currentBoundingBox.y2})',
              style: const TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 16),
          Text(
            _showCroppedImage
                ? 'Tap "Save" to proceed or "Edit Crop" to adjust the selection.'
                : 'You can adjust the bounding box by tapping the "Edit Box" button.',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cropImage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First ensure the bounding box is properly normalized
      // This ensures we get consistent results whether we edit or not
      final normalizedBox = await ImageUtils.convertToNormalizedBoundingBox(
        widget.imagePath,
        _currentBoundingBox,
      );

      // Update the current bounding box to the normalized one
      setState(() {
        _currentBoundingBox = normalizedBox;
      });

      // Automatically crop the image using the normalized bounding box
      final croppedPath = await ImageUtils.cropImageWithBoundingBox(
        widget.imagePath,
        normalizedBox,
      );

      if (mounted) {
        setState(() {
          _croppedImagePath = croppedPath;
          _showCroppedImage = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Image cropped successfully! You can adjust if needed.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to crop image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveAndProceed() async {
    if (_croppedImagePath == null) {
      // If no cropped image yet, crop first
      await _cropImage();
      if (_croppedImagePath == null) return; // Cropping failed
    }

    // Return to previous screen with the cropped image path
    Navigator.pop(context, _croppedImagePath);
  }
}
