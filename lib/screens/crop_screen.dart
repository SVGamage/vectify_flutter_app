import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:crop_image/crop_image.dart';
import '../models/detection_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CropScreen extends StatefulWidget {
  final String imagePath;
  final BoundingBox boundingBox;

  const CropScreen({
    Key? key,
    required this.imagePath,
    required this.boundingBox,
  }) : super(key: key);

  @override
  _CropScreenState createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final controller = CropController();
  late File _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);

    // Set initial crop area based on the bounding box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCropArea();
    });
  }

  void _initializeCropArea() async {
    try {
      // Calculate crop area from bounding box
      // The crop controller uses normalized values (0.0 to 1.0)
      double x1 = widget.boundingBox.x1 / 1000;
      double y1 = widget.boundingBox.y1 / 1000;
      double x2 = widget.boundingBox.x2 / 1000;
      double y2 = widget.boundingBox.y2 / 1000;

      // Crop controller uses normalized coordinates
      controller.crop = Rect.fromLTRB(x1, y1, x2, y2);
    } catch (e) {
      debugPrint('Error initializing crop area: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Logo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _cropAndSave,
            tooltip: 'Crop and Save',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CropImage(
              controller: controller,
              image: Image.file(_imageFile),
              alwaysShowThirdLines: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    controller.rotateLeft();
                  },
                  icon: const Icon(Icons.rotate_left),
                  label: const Text('Rotate Left'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    controller.rotateRight();
                  },
                  icon: const Icon(Icons.rotate_right),
                  label: const Text('Rotate Right'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Get the cropped image as a file
  Future<void> _cropAndSave() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get the cropped image
      final cropped = await controller.croppedBitmap();

      // Create a file to save the cropped image
      final directory = await getTemporaryDirectory();
      final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = path.join(directory.path, fileName);

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(await cropped
          .toByteData(format: ui.ImageByteFormat.png)
          .then((byteData) => byteData!.buffer.asUint8List()));

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Return to previous screen with the cropped image path
      if (mounted) Navigator.pop(context, filePath);
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
