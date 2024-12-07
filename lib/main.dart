import 'dart:html';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // For BlockPicker
import 'dart:math';

void main() {
  runApp(SvgEditorApp());
}

class SvgEditorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: SvgEditorScreen(),
    );
  }
}

class SvgEditorScreen extends StatefulWidget {
  @override
  _SvgEditorScreenState createState() => _SvgEditorScreenState();
}

class _SvgEditorScreenState extends State<SvgEditorScreen> {
  List<_SvgLayer> svgLayers = [];
  double canvasScale = 1.0; // To scale the entire canvas
  Color canvasBackgroundColor = Colors.grey[300]!; // Default background color

  @override
  Widget build(BuildContext context) {
    // Fixed canvas size
    double canvasWidth = 400;
    double canvasHeight = 500;

    return Scaffold(
      backgroundColor: Color(0xFFFAF3E0), // Clay-like white color for the body background
      appBar: AppBar(
        title: const Text('Scott Mockup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _uploadSvg,
            tooltip: 'Upload SVG',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: _changeBackgroundColor,
            tooltip: 'Change Background Color',
          ),
        ],
      ),
      body: Row(
        children: [
          // Side panel for SVG details
          Container(
            width: 300,
            color: Colors.black26,
            child: ListView.builder(
              itemCount: svgLayers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('SVG ${index + 1}', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'dx: ${svgLayers[index].dx.toStringAsFixed(2)}, '
                    'dy: ${svgLayers[index].dy.toStringAsFixed(2)}, '
                    'size: ${svgLayers[index].size.toStringAsFixed(1)}, '
                    'Rotation: ${svgLayers[index].rotation.toStringAsFixed(1)}°',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.color_lens, color: Colors.white),
                        onPressed: () async {
                          Color? newColor = await _pickColor(svgLayers[index].color);
                          if (newColor != null) {
                            setState(() {
                              svgLayers[index].color = newColor;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.rotate_left, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            svgLayers[index].rotation -= 15; // Rotate left by 15 degrees
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.rotate_right, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            svgLayers[index].rotation += 15; // Rotate right by 15 degrees
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            svgLayers.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Main canvas for SVGs with border and border radius
          Expanded(
            child: Center(
              child: Container(
                width: canvasWidth,
                height: canvasHeight,
                decoration: BoxDecoration(
                  color: canvasBackgroundColor, // Background color of the canvas
                  border: Border.all(color: Colors.black, width: 2), // Black border color and width
                  borderRadius: BorderRadius.circular(8), // Border radius
                ),
                child: Stack(
                  children: [
                    for (int i = 0; i < svgLayers.length; i++)
                      Positioned(
                        left: svgLayers[i].dx * canvasWidth,
                        top: svgLayers[i].dy * canvasHeight,
                        child: Listener(
                          onPointerSignal: (event) {
                            if (event is PointerScrollEvent) {
                              setState(() {
                                if (event.scrollDelta.dy > 0) {
                                  svgLayers[i].size *= 1.1; // Zoom in on the SVG
                                } else {
                                  svgLayers[i].size /= 1.1; // Zoom out on the SVG
                                }
                              });
                            }
                          },
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                // Calculate new position as a normalized range (0 to 1)
                                double newDx = (svgLayers[i].dx * canvasWidth + details.delta.dx).clamp(0.0, canvasWidth - svgLayers[i].size) / canvasWidth;
                                double newDy = (svgLayers[i].dy * canvasHeight + details.delta.dy).clamp(0.0, canvasHeight - svgLayers[i].size) / canvasHeight;

                                svgLayers[i].dx = newDx;
                                svgLayers[i].dy = newDy;
                              });
                            },
                            onLongPress: () {
                              setState(() {
                                svgLayers[i].isFlipped = !svgLayers[i].isFlipped;
                              });
                            },
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..scale(
                                  svgLayers[i].isFlipped ? -svgLayers[i].scale : svgLayers[i].scale,
                                  svgLayers[i].scale,
                                )
                                ..rotateZ(svgLayers[i].rotation * pi / 180),
                              child: SvgPicture.string(
                                svgLayers[i].svgContent,
                                color: svgLayers[i].color,
                                width: svgLayers[i].size,
                                height: svgLayers[i].size,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadSvg() async {
    final uploadInput = FileUploadInputElement();
    uploadInput.accept = '.svg';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      if (file != null) {
        final reader = FileReader();
        reader.readAsText(file);

        reader.onLoadEnd.listen((event) {
          final rng = Random();
          setState(() {
            svgLayers.add(_SvgLayer(
              svgContent: reader.result as String,
              dx: rng.nextDouble(), // Random dx in the range 0 to 1
              dy: rng.nextDouble(), // Random dy in the range 0 to 1
              scale: 1.0, // Initial scale set to 1.0
              isFlipped: rng.nextBool(), // Random flip
              color: Colors.white,
              size: 50.0, // Initial size
              rotation: 0, // Initial rotation
            ));
          });
        });
      }
    });
  }

  Future<Color?> _pickColor(Color initialColor) async {
    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: initialColor,
              onColorChanged: (color) {
                Navigator.pop(context, color);
              },
            ),
          ),
        );
      },
    );
  }

  void _zoomIn() {
    setState(() {
      canvasScale *= 1.2;
    });
  }

  void _zoomOut() {
    setState(() {
      canvasScale /= 1.2;
    });
  }

  Future<void> _changeBackgroundColor() async {
    Color? newColor = await _pickColor(canvasBackgroundColor);
    if (newColor != null) {
      setState(() {
        canvasBackgroundColor = newColor;
      });
    }
  }
}

class _SvgLayer {
  String svgContent;
  double dx;
  double dy;
  double scale;
  bool isFlipped;
  Color color;
  double size;
  double rotation; // New property for rotation

  _SvgLayer({
    required this.svgContent,
    this.dx = 0,
    this.dy = 0,
    this.scale = 1.0,
    this.isFlipped = false,
    required this.color,
    this.size = 50.0,
    this.rotation = 0, // Default rotation
  });
}
