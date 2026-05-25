import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/prediction.dart';
import '../models/symptom.dart';
import '../models/reminder.dart';

class ApiService {
  // Set to your PC's local IP address for Wi-Fi local testing (e.g. '192.168.0.123')
  static const String _pcLocalIp = '192.168.0.123'; 

  // Dynamically determine the URL based on the platform
  static String get _baseUrl {
    if (_pcLocalIp.isNotEmpty && _pcLocalIp != '127.0.0.1' && _pcLocalIp != 'YOUR_PC_IP_HERE') {
      return 'http://$_pcLocalIp:5000';
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    } else {
      try {
        if (Platform.isAndroid) {
          // 10.0.2.2 is the special alias to loopback (127.0.0.1) for the Android Emulator.
          return 'http://10.0.2.2:5000';
        }
      } catch (_) {}
      return 'http://127.0.0.1:5000';
    }
  }

  static String getReportUrl(int id) {
    return '$_baseUrl/api/history/$id/pdf';
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  Future<List<Symptom>> fetchSymptoms() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/symptoms'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        return data.map((e) => Symptom.fromRaw(e as String)).toList();
      }
      throw ApiException('Failed to load symptoms (${response.statusCode})');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }

  Future<Prediction> predict(List<String> symptoms) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/predict'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'symptoms': symptoms}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;
        return Prediction.fromApiResponse(data, symptoms);
      }
      final error = json.decode(response.body) as Map<String, dynamic>;
      throw ApiException(error['error'] as String? ?? 'Prediction failed');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }

  Future<List<Prediction>> fetchHistory() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/history'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        return data
            .map((e) => Prediction.fromHistory(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Failed to load history (${response.statusCode})');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }

  Future<void> deleteHistory(int id) async {
    try {
      final response = await _client
          .delete(Uri.parse('$_baseUrl/api/history/$id'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw ApiException('Failed to delete record');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }

  Future<List<Reminder>> fetchReminders() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/reminders'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        return data
            .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiException('Failed to load reminders (${response.statusCode})');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }

  Future<Reminder> addReminder(Reminder reminder) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/reminders'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(reminder.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;
        return Reminder.fromJson(data);
      }
      final error = json.decode(response.body) as Map<String, dynamic>;
      throw ApiException(error['error'] as String? ?? 'Failed to add reminder');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }

  Future<void> deleteReminder(int id) async {
    try {
      final response = await _client
          .delete(Uri.parse('$_baseUrl/api/reminders/$id'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw ApiException('Failed to delete reminder');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }

  Future<String> sendChatMessage(String message) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'message': message}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;
        return data['reply']?.toString() ?? 'No response received.';
      }
      final error = json.decode(response.body) as Map<String, dynamic>;
      throw ApiException(error['error'] as String? ?? 'Failed to send chat message');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        throw ApiException('Connection timed out. Make sure the Flask backend is running on port 5000.');
      }
      throw ApiException('Cannot connect to server. Make sure the Flask backend is running.');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
