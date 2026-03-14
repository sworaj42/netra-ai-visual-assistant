// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
//
// class YoloService {
//   // same base URL as depth/detect
//   static const String _baseUrl = 'http://192.168.1.71:8000';
//
//   static Future<Uint8List> getYoloImage(Uint8List imageBytes) async {
//     final uri = Uri.parse('$_baseUrl/yolo-image');
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
//     final streamedResponse = await request.send();
//     final response = await http.Response.fromStream(streamedResponse);
//
//     if (response.statusCode == 200) {
//       return response.bodyBytes; // PNG with YOLO boxes
//     } else {
//       throw Exception(
//         'YOLO image API error: ${response.statusCode} ${response.reasonPhrase}',
//       );
//     }
//   }
// }
