import '../depth_services/detect_json.dart';

String? phraseFromDetections(List<Detection> dets) {
  if (dets.isEmpty) return null;

  // Priority: urgent first
  int bucketScore(String b) => switch (b) {
    "very_close" => 100,
    "close" => 70,
    "ahead" => 40,
    _ => 0,
  };

  int dirBonus(String d) => d == "centre" ? 10 : 0;

  // Small hazard boost (edit based on your model classes)
  int hazardBoost(String label) {
    const hazard = {
      "unknown_obstacle": 35,
      "car": 30,
      "truck": 30,
      "bus": 30,
      "motorbike": 25,
      "bicycle": 20,
      "stairs": 35,
      "door": 30,
      "table": 30,
      "chair": 30,
    };
    return hazard[label] ?? 0;
  }

  Detection best = dets.first;
  double bestScore = -1;

  for (final d in dets) {
    if (d.conf < 0.55) continue;
    final s = bucketScore(d.depthBucket) + dirBonus(d.direction) + hazardBoost(d.label) + (d.conf * 10);
    if (s > bestScore) {
      bestScore = s;
      best = d;
    }
  }

  // Don't talk about far things
  if (best.depthBucket == "far") return null;

  final dir = (best.direction == "centre") ? "ahead" : best.direction;
  final name = best.label.replaceAll("_", " ");

  if (best.label == "unknown_obstacle") {
    if (best.depthBucket == "very_close") return "Obstacle ahead, very close.";
    if (best.depthBucket == "close") return "Obstacle $dir, close.";
    return "Obstacle $dir.";
  }

  if (best.depthBucket == "very_close") return "$name $dir, very close.";
  if (best.depthBucket == "close") return "$name $dir, close.";
  return "$name $dir.";
}