import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'detect_json.dart';

class YoloJsonResponse {
  final int w;
  final int h;
  final int count;
  final String narrative;
  final List<dynamic> detections;

  YoloJsonResponse({
    required this.w,
    required this.h,
    required this.count,
    required this.narrative,
    required this.detections,
  });

  factory YoloJsonResponse.fromJson(Map<String, dynamic> j) {
    return YoloJsonResponse(
      w: j['w'] ?? 0,
      h: j['h'] ?? 0,
      count: j['count'] ?? 0,
      narrative: (j['narrative'] ?? '').toString(),
      detections: (j['detections'] as List<dynamic>? ?? const []),
    );
  }
}

class DetectService {
  static const String baseUrl = 'http://192.168.1.71:8000';

  // PNG bytes (keep for UI)
  static Future<Uint8List> detectWithDepth(Uint8List imageBytes) async {
    final uri = Uri.parse('$baseUrl/detect-depth');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'frame.jpg',
      ));

    final streamed = await request.send();
    final bytes = await streamed.stream.toBytes();

    if (streamed.statusCode == 200) {
      return bytes;
    } else {
      final msg = String.fromCharCodes(bytes);
      throw Exception('Detect API error: ${streamed.statusCode} $msg');
    }
  }

  // JSON (for speech)
  static Future<DetectResponse> detectWithDepthJson(Uint8List imageBytes) async {
    final uri = Uri.parse('$baseUrl/detect-depth-json');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'frame.jpg',
      ));

    final streamed = await request.send();

    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('Detect JSON API error: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
    return DetectResponse.fromJson(jsonMap);
  }

  static Future<YoloJsonResponse> detectYoloJson(
      Uint8List imageBytes, {
        double conf = 0.5,
        int maxDet = 25,
      }) async {
    final uri = Uri.parse("$baseUrl/detect-yolo-json")
        .replace(queryParameters: {
      "conf": conf.toString(),
      "max_det": maxDet.toString(),
    });

    final request = http.MultipartRequest("POST", uri)
      ..files.add(http.MultipartFile.fromBytes(
        "file",
        imageBytes,
        filename: "frame.jpg",
      ));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception("detect-yolo-json failed ${streamed.statusCode}: $body");
    }

    final decoded = json.decode(body) as Map<String, dynamic>;
    return YoloJsonResponse.fromJson(decoded);
  }
}