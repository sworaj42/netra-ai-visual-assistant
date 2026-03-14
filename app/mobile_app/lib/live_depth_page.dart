// import 'dart:async';
// import 'dart:typed_data';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import "package:image/image.dart" as img;
//
// import 'depth_native.dart';
//
// class LiveDepthPage extends StatefulWidget {
//   final CameraDescription camera;
//
//   const LiveDepthPage({super.key, required this.camera});
//
//   @override
//   State<LiveDepthPage> createState() => _LiveDepthPageState();
// }
//
// class _LiveDepthPageState extends State<LiveDepthPage> {
//   CameraController? _controller;
//   bool _processing = false;
//
//   Uint8List? _latestAnnotated;
//   String? _error;
//
//   static const Duration _interval = Duration(milliseconds: 700);
//   DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
//
//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//   }
//
//   Future<void> _initCamera() async {
//     try {
//       _controller = CameraController(
//         widget.camera,
//         ResolutionPreset.low,
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.yuv420,
//       );
//
//       await _controller!.initialize();
//
//       // Stream frames (faster than takePicture)
//       await _controller!.startImageStream(_onFrame);
//       setState(() {});
//     } catch (e) {
//       setState(() => _error = 'Camera init error: $e');
//     }
//   }
//
//   Future<void> _onFrame(CameraImage image) async {
//     // throttle
//     final now = DateTime.now();
//     if (now.difference(_lastSent) < _interval) return;
//     if (_processing) return;
//
//     _processing = true;
//     _lastSent = now;
//
//     try {
//       final jpegBytes = _cameraImageToJpeg(image);
//
//       final annotated = await DepthNative.runDetectDepth(jpegBytes);
//
//       if (!mounted) return;
//       setState(() {
//         _latestAnnotated = annotated;
//         _error = null;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _error = 'Detect-depth error: $e');
//     } finally {
//       _processing = false;
//     }
//   }
//
//   Uint8List _cameraImageToJpeg(CameraImage image) {
//     // Convert YUV420 -> RGB using image package
//     final width = image.width;
//     final height = image.height;
//
//     final yPlane = image.planes[0].bytes;
//     final uPlane = image.planes[1].bytes;
//     final vPlane = image.planes[2].bytes;
//
//     final yRowStride = image.planes[0].bytesPerRow;
//     final uvRowStride = image.planes[1].bytesPerRow;
//     final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
//
//     final rgb = img.Image(width: width, height: height);
//
//     for (int y = 0; y < height; y++) {
//       final yRow = yRowStride * y;
//       final uvRow = uvRowStride * (y >> 1);
//
//       for (int x = 0; x < width; x++) {
//         final yIndex = yRow + x;
//         final uvIndex = uvRow + (x >> 1) * uvPixelStride;
//
//         final yp = yPlane[yIndex];
//         final up = uPlane[uvIndex];
//         final vp = vPlane[uvIndex];
//
//         // YUV -> RGB (BT.601)
//         int r = (yp + 1.402 * (vp - 128)).round();
//         int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
//         int b = (yp + 1.772 * (up - 128)).round();
//
//         r = r.clamp(0, 255);
//         g = g.clamp(0, 255);
//         b = b.clamp(0, 255);
//
//         rgb.setPixelRgba(x, y, r, g, b, 255);
//       }
//     }
//
//     return Uint8List.fromList(img.encodeJpg(rgb, quality: 75));
//   }
//
//   @override
//   void dispose() async {
//     final c = _controller;
//     if (c != null) {
//       try {
//         await c.stopImageStream();
//       } catch (_) {}
//       await c.dispose();
//     }
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final controller = _controller;
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('YOLO + Depth (API)')),
//       body: SafeArea(
//         child: Column(
//           children: [
//             if (_error != null)
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text(_error!, style: const TextStyle(color: Colors.red)),
//               ),
//             Expanded(
//               child: controller == null || !controller.value.isInitialized
//                   ? const Center(child: CircularProgressIndicator())
//                   : Row(
//                 children: [
//                   Expanded(child: CameraPreview(controller)),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: _latestAnnotated == null
//                         ? const Center(
//                       child: Text(
//                         'Annotated result will appear here',
//                         textAlign: TextAlign.center,
//                       ),
//                     )
//                         : Image.memory(
//                       _latestAnnotated!,
//                       gaplessPlayback: true,
//                       fit: BoxFit.contain,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
