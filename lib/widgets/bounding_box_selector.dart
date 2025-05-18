import 'dart:io';
import 'package:flutter/material.dart';
import '../models/detection_model.dart';
import '../utils/image_utils.dart';

class BoundingBoxSelector extends StatefulWidget {
  final String imagePath;
  final List<Detection> detections;
  final Function(BoundingBox) onBoundingBoxChanged;
  final bool initialEditingMode;

  const BoundingBoxSelector({
    super.key,
    required this.imagePath,
    required this.detections,
    required this.onBoundingBoxChanged,
    this.initialEditingMode = false,
  });

  @override
  _BoundingBoxSelectorState createState() => _BoundingBoxSelectorState();
}

class _BoundingBoxSelectorState extends State<BoundingBoxSelector> {
  BoundingBox? _currentBoundingBox;
  bool _isEditing = false;

  // Keep track of resize handles being dragged
  bool _isDraggingTopLeft = false;
  bool _isDraggingTopRight = false;
  bool _isDraggingBottomLeft = false;
  bool _isDraggingBottomRight = false;
  bool _isDraggingBox = false;

  // Offset for box dragging
  Offset _dragStartOffset = Offset.zero;
  late BoundingBox _originalBox;

  // Image dimensions
  double _imageWidth = 0;
  double _imageHeight = 0;
  @override
  void initState() {
    super.initState();
    // Set initial editing mode
    _isEditing = widget.initialEditingMode;

    // Initialize with the first detection if available
    if (widget.detections.isNotEmpty) {
      _initializeBoundingBox();
    }
  }

  Future<void> _initializeBoundingBox() async {
    // Get the original bounding box
    final originalBox = widget.detections.first.boundingBox;

    // Check if the coordinates might be in pixels rather than normalized
    if (originalBox.x2 > 1000 || originalBox.y2 > 1000) {
      // Convert from pixel coordinates to 0-1000 range
      final normalizedBox = await ImageUtils.convertToNormalizedBoundingBox(
          widget.imagePath, originalBox);
      if (mounted) {
        setState(() {
          _currentBoundingBox = normalizedBox;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentBoundingBox = originalBox;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: _handlePanDown,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Stack(
            children: [
              // Image
              Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  // Only update dimensions once when image is fully loaded
                  if (frame != null && _imageWidth == 0 && _imageHeight == 0) {
                    _updateImageDimensions(context);
                  }
                  return child;
                },
              ),

              // Bounding box overlay
              if (_currentBoundingBox != null) _buildBoundingBoxOverlay(),

              // Edit button
              Positioned(
                top: 10,
                right: 10,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                  child: Text(_isEditing ? 'Done' : 'Edit Box'),
                ),
              ),

              // Instructions for manual editing (when in edit mode)
              if (_isEditing)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Adjust Logo Selection',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Drag the corners to resize\n• Drag the box to reposition\n• Tap "Done" when finished',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _updateImageDimensions(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final size = renderBox.size;

      // Only update dimensions if they've changed
      if (size.width != _imageWidth || size.height != _imageHeight) {
        setState(() {
          _imageWidth = size.width;
          _imageHeight = size.height;
        });
      }
    });
  }

  Widget _buildBoundingBoxOverlay() {
    if (_currentBoundingBox == null) {
      return Container();
    }

    final box = _currentBoundingBox!;

    // Use the API coordinates directly (0-1000 range)
    final double left = box.x1.toDouble();
    final double top = box.y1.toDouble();
    final double width = (box.x2 - box.x1).toDouble();
    final double height = (box.y2 - box.y1).toDouble();

    return Stack(
      children: [
        // Semi-transparent overlay
        Positioned.fill(
          child: ClipPath(
            clipper: BoundingBoxClipper(
              left: left,
              top: top,
              width: width,
              height: height,
              imageWidth: _imageWidth,
              imageHeight: _imageHeight,
            ),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ), // Bounding box outline - convert from API coordinates (0-1000) to screen pixels
        Positioned(
          left: left * _imageWidth / 1000,
          top: top * _imageHeight / 1000,
          width: width * _imageWidth / 1000,
          height: height * _imageHeight / 1000,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red,
                width: 3,
              ),
            ),
            // Show handlers when editing
            child: _isEditing
                ? Stack(
                    children: [
                      _buildResizeHandle(Alignment.topLeft),
                      _buildResizeHandle(Alignment.topRight),
                      _buildResizeHandle(Alignment.bottomLeft),
                      _buildResizeHandle(Alignment.bottomRight),
                    ],
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildResizeHandle(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24, // Handle size in screen pixels - slightly larger
        height: 24,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  void _handlePanDown(DragDownDetails details) {
    if (!_isEditing || _currentBoundingBox == null) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(details.globalPosition);

    final currentBox = _currentBoundingBox!;
    _originalBox = currentBox;
    _dragStartOffset = localOffset;

    // Convert touch position to API coordinates (0-1000 range)
    final double touchX = localOffset.dx * 1000 / _imageWidth;
    final double touchY = localOffset.dy * 1000 / _imageHeight;

    // Use API coordinates directly
    final double left = currentBox.x1.toDouble();
    final double top = currentBox.y1.toDouble();
    final double width = (currentBox.x2 - currentBox.x1).toDouble();
    final double height = (currentBox.y2 - currentBox.y1).toDouble();

    // Check if user is dragging a resize handle
    // Define handle range in normalized coordinates
    const double handleRange = 30.0;
    // Convert handle range to API coordinates
    final double scaledHandleRange = handleRange * 1000 / _imageWidth;

    if ((touchX - left).abs() < scaledHandleRange &&
        (touchY - top).abs() < scaledHandleRange) {
      _isDraggingTopLeft = true;
    } else if ((touchX - (left + width)).abs() < scaledHandleRange &&
        (touchY - top).abs() < scaledHandleRange) {
      _isDraggingTopRight = true;
    } else if ((touchX - left).abs() < scaledHandleRange &&
        (touchY - (top + height)).abs() < scaledHandleRange) {
      _isDraggingBottomLeft = true;
    } else if ((touchX - (left + width)).abs() < scaledHandleRange &&
        (touchY - (top + height)).abs() < scaledHandleRange) {
      _isDraggingBottomRight = true;
    } else if (touchX >= left &&
        touchX <= left + width &&
        touchY >= top &&
        touchY <= top + height) {
      _isDraggingBox = true;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isEditing || _currentBoundingBox == null) return;
    if (!(_isDraggingTopLeft ||
        _isDraggingTopRight ||
        _isDraggingBottomLeft ||
        _isDraggingBottomRight ||
        _isDraggingBox)) {
      return;
    }

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(details.globalPosition);

    // Calculate delta from start position in screen pixels
    final double dx = localOffset.dx - _dragStartOffset.dx;
    final double dy = localOffset.dy - _dragStartOffset.dy;

    // Convert pixel movement to API coordinates (0-1000 range)
    final double scaledDx = dx * 1000 / _imageWidth;
    final double scaledDy = dy * 1000 / _imageHeight;

    setState(() {
      if (_isDraggingBox) {
        // Move the entire box
        _currentBoundingBox = BoundingBox(
          x1: (_originalBox.x1 + scaledDx).round().clamp(0, 1000),
          y1: (_originalBox.y1 + scaledDy).round().clamp(0, 1000),
          x2: (_originalBox.x2 + scaledDx).round().clamp(0, 1000),
          y2: (_originalBox.y2 + scaledDy).round().clamp(0, 1000),
        );
      } else {
        // Resize the box based on which handle is being dragged
        int newX1 = _originalBox.x1;
        int newY1 = _originalBox.y1;
        int newX2 = _originalBox.x2;
        int newY2 = _originalBox.y2;

        if (_isDraggingTopLeft) {
          newX1 = (_originalBox.x1 + scaledDx)
              .round()
              .clamp(0, _originalBox.x2 - 10);
          newY1 = (_originalBox.y1 + scaledDy)
              .round()
              .clamp(0, _originalBox.y2 - 10);
        } else if (_isDraggingTopRight) {
          newX2 = (_originalBox.x2 + scaledDx)
              .round()
              .clamp(_originalBox.x1 + 10, 1000);
          newY1 = (_originalBox.y1 + scaledDy)
              .round()
              .clamp(0, _originalBox.y2 - 10);
        } else if (_isDraggingBottomLeft) {
          newX1 = (_originalBox.x1 + scaledDx)
              .round()
              .clamp(0, _originalBox.x2 - 10);
          newY2 = (_originalBox.y2 + scaledDy)
              .round()
              .clamp(_originalBox.y1 + 10, 1000);
        } else if (_isDraggingBottomRight) {
          newX2 = (_originalBox.x2 + scaledDx)
              .round()
              .clamp(_originalBox.x1 + 10, 1000);
          newY2 = (_originalBox.y2 + scaledDy)
              .round()
              .clamp(_originalBox.y1 + 10, 1000);
        }

        _currentBoundingBox = BoundingBox(
          x1: newX1,
          y1: newY1,
          x2: newX2,
          y2: newY2,
        );
      }

      // Notify parent of the change
      widget.onBoundingBoxChanged(_currentBoundingBox!);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDraggingTopLeft = false;
    _isDraggingTopRight = false;
    _isDraggingBottomLeft = false;
    _isDraggingBottomRight = false;
    _isDraggingBox = false;
  }
}

class BoundingBoxClipper extends CustomClipper<Path> {
  // These values are in API coordinates (0-1000 range)
  final double left;
  final double top;
  final double width;
  final double height;
  final double imageWidth;
  final double imageHeight;

  BoundingBoxClipper({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  Path getClip(Size size) {
    // Convert API coordinates (0-1000) to screen pixels for drawing
    final scaledLeft = left * imageWidth / 1000;
    final scaledTop = top * imageHeight / 1000;
    final scaledWidth = width * imageWidth / 1000;
    final scaledHeight = height * imageHeight / 1000;

    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()
        ..addRect(
            Rect.fromLTWH(scaledLeft, scaledTop, scaledWidth, scaledHeight)),
    );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
