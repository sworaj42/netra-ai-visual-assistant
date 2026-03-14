// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
//
// class DepthNative {
//   static const String _baseUrl = 'http://192.168.1.71:8000';
//
//   static Future<Uint8List> runDetectDepth(Uint8List imageBytes) async {
//     final uri = Uri.parse('$_baseUrl/detect-depth');
//
//     final request = http.MultipartRequest('POST', uri)
//       ..files.add(http.MultipartFile.fromBytes(
//         'file',
//         imageBytes,
//         filename: 'frame.jpg',
//       ));
//
//     final streamed = await request.send();
//
//     // ✅ Read raw bytes from the stream
//     final bytes = await streamed.stream.toBytes();
//     final contentType = streamed.headers['content-type'] ?? '';
//
//     if (streamed.statusCode == 200) {
//       // Optional safety check (helps debugging)
//       if (!contentType.contains('image/png')) {
//         throw Exception('Expected image/png but got: $contentType');
//       }
//       return bytes; // ✅ PNG bytes
//     } else {
//       // If server returns JSON error, decode as text for error display
//       final text = String.fromCharCodes(bytes);
//       throw Exception('API ${streamed.statusCode}: $text');
//     }
//   }
// }
