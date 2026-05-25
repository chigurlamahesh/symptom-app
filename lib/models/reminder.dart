import 'dart:convert';

class Reminder {
  final int? id;
  final String medicineName;
  final String alarmTime;
  final String dosage;
  final List<String> repeatDays;
  final String labelColor;

  Reminder({
    this.id,
    required this.medicineName,
    required this.alarmTime,
    required this.dosage,
    required this.repeatDays,
    required this.labelColor,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    List<String> days = [];
    if (json['repeat_days'] != null) {
      if (json['repeat_days'] is String) {
        try {
          final parsed = jsonDecode(json['repeat_days']);
          if (parsed is List) {
            days = parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {
          days = (json['repeat_days'] as String).split(',');
        }
      } else if (json['repeat_days'] is List) {
        days = (json['repeat_days'] as List).map((e) => e.toString()).toList();
      }
    }
    return Reminder(
      id: json['id'] as int?,
      medicineName: json['medicine_name'] as String,
      alarmTime: json['alarm_time'] as String,
      dosage: json['dosage'] as String,
      repeatDays: days,
      labelColor: json['label_color'] as String? ?? 'blue',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicine_name': medicineName,
      'alarm_time': alarmTime,
      'dosage': dosage,
      'repeat_days': repeatDays,
      'label_color': labelColor,
    };
  }

  Reminder copyWith({
    int? id,
    String? medicineName,
    String? alarmTime,
    String? dosage,
    List<String>? repeatDays,
    String? labelColor,
  }) {
    return Reminder(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      alarmTime: alarmTime ?? this.alarmTime,
      dosage: dosage ?? this.dosage,
      repeatDays: repeatDays ?? this.repeatDays,
      labelColor: labelColor ?? this.labelColor,
    );
  }
}
