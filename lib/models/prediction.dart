class TopPrediction {
  final String disease;
  final double confidence;

  TopPrediction({required this.disease, required this.confidence});

  factory TopPrediction.fromJson(Map<String, dynamic> json) {
    return TopPrediction(
      disease: json['disease'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class Prediction {
  final String disease;
  final double confidence;
  final List<String> precautions;
  final List<String> symptoms;
  final List<TopPrediction> topPredictions;
  final DateTime timestamp;
  final int? id;
  
  // Patient clinical intake fields
  final int? age;
  final String? sex;
  final String? smoker;
  final double? weight;
  final double? height;
  final List<String> existingConditions;
  final String? duration;
  final String? severity;
  final String? recommendation;

  Prediction({
    required this.disease,
    required this.confidence,
    required this.precautions,
    required this.symptoms,
    required this.topPredictions,
    required this.timestamp,
    this.id,
    this.age,
    this.sex,
    this.smoker,
    this.weight,
    this.height,
    this.existingConditions = const [],
    this.duration,
    this.severity,
    this.recommendation,
  });

  factory Prediction.fromApiResponse(Map<String, dynamic> json, List<String> selectedSymptoms) {
    return Prediction(
      id: json['id'] as int?,
      disease: json['disease'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      precautions: List<String>.from(json['precautions'] as List),
      symptoms: selectedSymptoms,
      topPredictions: (json['top_predictions'] as List?)
              ?.map((e) => TopPrediction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: DateTime.now(),
      age: json['age'] as int?,
      sex: json['sex'] as String?,
      smoker: json['smoker'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      existingConditions: List<String>.from(json['existing_conditions'] as List? ?? []),
      duration: json['duration'] as String?,
      severity: json['severity'] as String?,
      recommendation: json['recommendation'] as String?,
    );
  }

  factory Prediction.fromHistory(Map<String, dynamic> json) {
    return Prediction(
      id: json['id'] as int?,
      disease: json['predicted_disease'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      precautions: List<String>.from(json['precautions'] as List? ?? []),
      symptoms: List<String>.from(json['symptoms'] as List? ?? []),
      topPredictions: [],
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      age: json['age'] as int?,
      sex: json['sex'] as String?,
      smoker: json['smoker'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      existingConditions: List<String>.from(json['existing_conditions'] as List? ?? []),
      duration: json['duration'] as String?,
      severity: json['severity'] as String?,
      recommendation: json['recommendation'] as String?,
    );
  }

  String get confidenceLabel {
    if (confidence >= 80) return 'High';
    if (confidence >= 50) return 'Medium';
    return 'Low';
  }
}
