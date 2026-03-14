// lib/depth_services/detect_json.dart

class Detection {
  final String label;
  final double conf; // matches Python: "conf"
  final String direction;
  final double depth;
  final String depthBucket; // matches Python: "depth_bucket"
  final List<int> box;
  final String source;

  Detection({
    required this.label,
    required this.conf,
    required this.direction,
    required this.depth,
    required this.depthBucket,
    required this.box,
    required this.source,
  });

  factory Detection.fromJson(Map<String, dynamic> j) {
    return Detection(
      label: (j['label'] ?? '').toString(),
      conf: (j['conf'] is num) ? (j['conf'] as num).toDouble() : 0.0,
      direction: (j['direction'] ?? 'centre').toString(),
      depth: (j['depth'] is num) ? (j['depth'] as num).toDouble() : 0.0,
      depthBucket: (j['depth_bucket'] ?? 'far').toString(),
      box: (j['box'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList(),
      source: (j['source'] ?? '').toString(),
    );
  }
}

class DetectResponse {
  final int w;
  final int h;
  final List<Detection> detections;

  // ✅ NEW: returned by /detect-depth-json
  final String narrative;

  // Optional demo fields (only present when demo=true)
  final String? previewJpgB64;
  final int? previewW;
  final int? jpegQ;

  DetectResponse({
    required this.w,
    required this.h,
    required this.detections,
    required this.narrative,
    this.previewJpgB64,
    this.previewW,
    this.jpegQ,
  });

  factory DetectResponse.fromJson(Map<String, dynamic> j) {
    final detList = (j['detections'] as List<dynamic>? ?? const [])
        .map((e) => Detection.fromJson(e as Map<String, dynamic>))
        .toList();

    return DetectResponse(
      w: (j['w'] ?? 0) as int,
      h: (j['h'] ?? 0) as int,
      detections: detList,
      narrative: (j['narrative'] ?? '').toString(), // ✅ IMPORTANT
      previewJpgB64: j['preview_jpg_b64']?.toString(),
      previewW: (j['preview_w'] is int) ? j['preview_w'] as int : null,
      jpegQ: (j['jpeg_q'] is int) ? j['jpeg_q'] as int : null,
    );
  }
}