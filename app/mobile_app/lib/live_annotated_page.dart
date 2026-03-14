// import 'dart:async';
// import 'dart:typed_data';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
//
// import 'depth_services/detect_service.dart';
//
// class LiveAnnotatedPage extends StatefulWidget {
//   final CameraDescription camera;
//   const LiveAnnotatedPage({super.key, required this.camera});
//
//   @override
//   State<LiveAnnotatedPage> createState() => _LiveAnnotatedPageState();
// }
//
// class _LiveAnnotatedPageState extends State<LiveAnnotatedPage> {
//   CameraController? _controller;
//   bool _processing = false;
//
//   Uint8List? _annotatedFrame; // PNG from API
//   String? _error;
//
//   static const Duration _interval = Duration(milliseconds: 1000);
//   Timer? _timer;
//
//   int _quarterTurns = 1; // start with 90° (most Android phones)
//
//   @override
//   void initState() {
//     super.initState();
//     _init();
//   }
//
//   Future<void> _init() async {
//     try {
//       _controller = CameraController(
//         widget.camera,
//         ResolutionPreset.low,
//         enableAudio: false,
//       );
//
//       await _controller!.initialize();
//
//       _timer = Timer.periodic(_interval, (_) => _captureAndSend());
//
//       if (mounted) setState(() {});
//     } catch (e) {
//       setState(() => _error = 'Camera init error: $e');
//     }
//   }
//
//   Future<void> _captureAndSend() async {
//     if (_controller == null || !_controller!.value.isInitialized) return;
//     if (_processing) return;
//
//     _processing = true;
//
//     try {
//       final XFile file = await _controller!.takePicture();
//       final bytes = await file.readAsBytes();
//
//       // API returns annotated PNG
//       final png = await DetectService.detectWithDepth(bytes);
//
//       if (!mounted) return;
//       setState(() {
//         _annotatedFrame = png;
//         _error = null;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _error = 'Detect error: $e');
//     } finally {
//       _processing = false;
//     }
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Netra – API Annotated Feed'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.rotate_right),
//             tooltip: 'Rotate',
//             onPressed: () {
//               setState(() {
//                 _quarterTurns = (_quarterTurns + 1) % 4;
//               });
//             },
//           )
//         ],
//       ),
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: _annotatedFrame == null
//                 ? const Center(child: Text('Waiting for API feed…'))
//                 : GestureDetector(
//               onTap: () {
//                 // tap anywhere to rotate
//                 setState(() {
//                   _quarterTurns = (_quarterTurns + 1) % 4;
//                 });
//               },
//               child: RotatedBox(
//                 quarterTurns: _quarterTurns,
//                 child: Image.memory(
//                   _annotatedFrame!,
//                   gaplessPlayback: true,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//           ),
//
//           if (_error != null)
//             Positioned(
//               left: 12,
//               right: 12,
//               bottom: 24,
//               child: Container(
//                 padding: const EdgeInsets.all(12),
//                 color: Colors.black54,
//                 child: Text(
//                   _error!,
//                   style: const TextStyle(color: Colors.red),
//                 ),
//               ),
//             ),
//
//           // Small overlay hint
//           Positioned(
//             top: 12,
//             left: 12,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//               color: Colors.black54,
//               child: const Text(
//                 'Tap screen to rotate',
//                 style: TextStyle(fontSize: 12),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
