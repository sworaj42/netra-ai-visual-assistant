// import 'dart:async';
// import 'dart:typed_data';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
//
// import 'depth_services/detect_service.dart';
//
// class DepthLivePanel extends StatefulWidget {
//   final CameraDescription camera;
//   const DepthLivePanel({super.key, required this.camera});
//
//   @override
//   State<DepthLivePanel> createState() => _DepthLivePanelState();
// }
//
// class _DepthLivePanelState extends State<DepthLivePanel> {
//   CameraController? _controller;
//   Future<void>? _initFuture;
//   Timer? _timer;
//   bool _processing = false;
//   Uint8List? _annotatedPng;
//   String? _error;
//
//   static const Duration _interval = Duration(milliseconds: 10); // ✅ realistic
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = CameraController(widget.camera, ResolutionPreset.low, enableAudio: false);
//
//     _initFuture = _controller!.initialize().then((_) {
//       _timer = Timer.periodic(_interval, (_) => _captureAndSend());
//     }).catchError((e) {
//       if (mounted) setState(() => _error = 'Camera init error: $e');
//     });
//   }
//
//   Future<void> _captureAndSend() async {
//     final c = _controller;
//     if (c == null || !c.value.isInitialized) return;
//     if (_processing) return;
//
//     _processing = true;
//     try {
//       final XFile file = await c.takePicture();
//       final bytes = await file.readAsBytes();
//
//       final png = await DetectService.detectWithDepth(bytes);
//
//       if (!mounted) return;
//       setState(() {
//         _annotatedPng = png;
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
//     final c = _controller;
//
//     return FutureBuilder<void>(
//       future: _initFuture,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState != ConnectionState.done || c == null) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         return Column(
//           children: [
//             if (_error != null)
//               Padding(
//                 padding: const EdgeInsets.all(6),
//                 child: Text(_error!, style: const TextStyle(color: Colors.red)),
//               ),
//             Expanded(
//               child: Row(
//                 children: [
//                   Expanded(flex: 1, child: CameraPreview(c)),
//                   const SizedBox(width: 6),
//                   Expanded(
//                     flex: 1,
//                     child: Container(
//                       color: Colors.black,
//                       child: _annotatedPng == null
//                           ? const Center(child: Text('Waiting…'))
//                           : Image.memory(_annotatedPng!, gaplessPlayback: true, fit: BoxFit.cover),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }