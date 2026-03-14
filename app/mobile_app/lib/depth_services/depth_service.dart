// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
//
// class DepthService {
//   // IMPORTANT: change this to your PC's LAN IP
//   // On Windows: run `ipconfig` and use the IPv4 Address, e.g. 192.168.1.50
//   static const String _baseUrl = 'http://192.168.1.71:8000';
//
//   static Future<Uint8List> getDetectDepthImage(Uint8List imageBytes) async {
//     final uri = Uri.parse('$_baseUrl/detect-depth');
//
//     final request = http.MultipartRequest('POST', uri)
//       ..files.add(
//         http.MultipartFile.fromBytes(
//           'file',
//           imageBytes,
//           filename: 'frame.jpg',
//         ),
//       );
//
//     final streamed = await request.send();
//     final bytes = await streamed.stream.toBytes();
//
//     if (streamed.statusCode == 200) {
//       return bytes; // PNG with YOLO + depth text
//     } else {
//       final msg = String.fromCharCodes(bytes);
//       throw Exception('Detect-depth error: $msg');
//     }
//   }
//
// }
