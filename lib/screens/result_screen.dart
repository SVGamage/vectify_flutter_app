import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/detection_model.dart';
import '../widgets/bounding_box_selector.dart';
import '../utils/image_utils.dart';
import '../services/vectorize_service.dart';

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
  bool _isManualSelection = false;
  String? _vectorizedSvgString; // Holds SVG response
  bool _isVectorizing = false;

  @override
  void initState() {
    super.initState();
    // Initialize with the first detection's bounding box
    if (widget.detections.isNotEmpty) {
      _currentBoundingBox = widget.detections.first.boundingBox;

      // If this is a manual selection, set the flag
      if (widget.detections.first.className == 'Manual Selection') {
        _isManualSelection = true;

        // Show help dialog after widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showInitialHelp();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isManualSelection
              ? 'Manual Logo Selection'
              : 'Logo Detection Result',
        ),
        actions: [
          if (_isManualSelection && !_showCroppedImage)
            Tooltip(
              message: 'Adjust the red box to select your logo',
              child: IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _showHelpDialog,
              ),
            ),
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
                      ? _vectorizedSvgString != null
                          ? _buildSvgView()
                          : _buildCroppedImageView()
                      : BoundingBoxSelector(
                          imagePath: widget.imagePath,
                          detections: widget.detections,
                          initialEditingMode: _isManualSelection,
                          onBoundingBoxChanged: (box) {
                            setState(() {
                              _currentBoundingBox = box;
                              if (_croppedImagePath != null) {
                                _croppedImagePath = null;
                                _showCroppedImage = false;
                                _vectorizedSvgString = null;
                              }
                            });
                          },
                        ),
                ),
                if (_showCroppedImage && _vectorizedSvgString == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton.icon(
                      icon: _isVectorizing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Vectorize'),
                      onPressed: _isVectorizing ? null : _vectorizeImage,
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

  Widget _buildSvgView() {
    // Requires flutter_svg in pubspec.yaml
    return _vectorizedSvgString == null
        ? const SizedBox.shrink()
        : Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SvgPicture.string(
                    _vectorizedSvgString!,
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildInfoPanel() {
    final detection = widget.detections.first;
    final bool isManual = detection.className == 'Manual Selection';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isManual
                ? 'Manual Selection Mode'
                : 'Detected: ${detection.className}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (!isManual)
            Text(
              'Confidence: ${(detection.confidence * 100).toStringAsFixed(2)}%',
              style: const TextStyle(fontSize: 16),
            ),
          if (isManual)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Position the red box around the logo',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.edit, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    const Text('Use the Edit Box button to make adjustments'),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.crop, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    const Text('Tap Crop when done to see the result'),
                  ],
                ),
              ],
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

  Future<void> _vectorizeImage() async {
    if (_croppedImagePath == null) return;
    setState(() {
      _isVectorizing = true;
    });
    try {
      final file = File(_croppedImagePath!);
      final svgString = await VectorizeService.vectorizeImage(file);
      setState(() {
        _vectorizedSvgString = svgString;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isVectorizing = false;
      });
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Selection Help'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to Select a Logo:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. The red box shows your current selection'),
            Text('2. Tap "Edit Box" to enable editing mode'),
            Text('3. Drag the corners to resize the selection'),
            Text('4. Drag inside the box to move the entire selection'),
            Text('5. When finished, tap "Done" in the box'),
            Text('6. Tap the crop icon in the app bar to confirm'),
          ],
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

  void _showInitialHelp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Adjust the red box to select your logo area'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Help',
          onPressed: _showHelpDialog,
        ),
      ),
    );
  }
}
