import 'package:flutter/foundation.dart';
import '../models/symptom.dart';
import '../models/prediction.dart';
import '../models/reminder.dart';
import '../services/api_service.dart';

enum AppState { idle, loading, success, error }

class HealthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // ── Symptoms ──────────────────────────────────────────────────────────────
  List<Symptom> _allSymptoms = [];
  String _searchQuery = '';
  AppState _symptomsState = AppState.idle;
  String _symptomsError = '';

  List<Symptom> get allSymptoms => _allSymptoms;
  List<Symptom> get filteredSymptoms => _searchQuery.isEmpty
      ? _allSymptoms
      : _allSymptoms
          .where((s) =>
              s.displayName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
  List<Symptom> get selectedSymptoms =>
      _allSymptoms.where((s) => s.isSelected).toList();
  AppState get symptomsState => _symptomsState;
  String get symptomsError => _symptomsError;

  // ── Prediction ────────────────────────────────────────────────────────────
  Prediction? _currentPrediction;
  AppState _predictionState = AppState.idle;
  String _predictionError = '';

  Prediction? get currentPrediction => _currentPrediction;
  AppState get predictionState => _predictionState;
  String get predictionError => _predictionError;

  // ── Patient Intake Details ──────────────────────────────────────────────────
  int _age = 30;
  String _sex = 'Male';
  String _smoker = 'No';
  double _weight = 70.0;
  double _height = 170.0;
  List<String> _existingConditions = [];
  String _duration = '1-3 days';
  String _severity = 'Moderate';

  int get age => _age;
  String get sex => _sex;
  String get smoker => _smoker;
  double get weight => _weight;
  double get height => _height;
  List<String> get existingConditions => _existingConditions;
  String get duration => _duration;
  String get severity => _severity;

  void setAge(int val) {
    _age = val;
    notifyListeners();
  }

  void setSex(String val) {
    _sex = val;
    notifyListeners();
  }

  void setSmoker(String val) {
    _smoker = val;
    notifyListeners();
  }

  void setWeight(double val) {
    _weight = val;
    notifyListeners();
  }

  void setHeight(double val) {
    _height = val;
    notifyListeners();
  }

  void setDuration(String val) {
    _duration = val;
    notifyListeners();
  }

  void setSeverity(String val) {
    _severity = val;
    notifyListeners();
  }

  void toggleCondition(String condition) {
    if (_existingConditions.contains(condition)) {
      _existingConditions.remove(condition);
    } else {
      _existingConditions.add(condition);
    }
    notifyListeners();
  }

  void resetPatientDetails() {
    _age = 30;
    _sex = 'Male';
    _smoker = 'No';
    _weight = 70.0;
    _height = 170.0;
    _existingConditions = [];
    _duration = '1-3 days';
    _severity = 'Moderate';
    notifyListeners();
  }

  // ── History ───────────────────────────────────────────────────────────────
  List<Prediction> _history = [];
  AppState _historyState = AppState.idle;
  String _historyError = '';

  List<Prediction> get history => _history;
  AppState get historyState => _historyState;
  String get historyError => _historyError;

  // ── Reminders ─────────────────────────────────────────────────────────────
  List<Reminder> _reminders = [];
  AppState _remindersState = AppState.idle;
  String _remindersError = '';

  List<Reminder> get reminders => _reminders;
  AppState get remindersState => _remindersState;
  String get remindersError => _remindersError;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> loadSymptoms() async {
    _symptomsState = AppState.loading;
    _symptomsError = '';
    notifyListeners();

    try {
      _allSymptoms = await _api.fetchSymptoms();
      _symptomsState = AppState.success;
    } catch (e) {
      _symptomsState = AppState.error;
      _symptomsError = e.toString();
    }
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleSymptom(String id) {
    final index = _allSymptoms.indexWhere((s) => s.id == id);
    if (index != -1) {
      _allSymptoms[index] =
          _allSymptoms[index].copyWith(isSelected: !_allSymptoms[index].isSelected);
      notifyListeners();
    }
  }

  void clearSelection() {
    for (int i = 0; i < _allSymptoms.length; i++) {
      _allSymptoms[i] = _allSymptoms[i].copyWith(isSelected: false);
    }
    notifyListeners();
  }

  /// Parses natural language voice/text input to extract symptoms, duration, and severity.
  /// Example input: "I have fever and headache for 3 days."
  Map<String, dynamic> parseVoiceInput(String text) {
    final normalized = text.toLowerCase();
    
    // 1. Reset selections
    for (int i = 0; i < _allSymptoms.length; i++) {
      _allSymptoms[i] = _allSymptoms[i].copyWith(isSelected: false);
    }
    
    // 2. Match symptoms
    int symptomsMatched = 0;
    List<String> matchedNames = [];
    
    for (int i = 0; i < _allSymptoms.length; i++) {
      final symptom = _allSymptoms[i];
      final idLower = symptom.id.toLowerCase();
      final displayLower = symptom.displayName.toLowerCase();
      
      bool isMatch = false;
      
      // Exact word matching or substring matching for multi-word symptoms
      if (displayLower.contains(' ')) {
        if (normalized.contains(displayLower) || normalized.contains(idLower.replaceAll('_', ' '))) {
          isMatch = true;
        }
      } else {
        // Single word symptom (e.g. "fever")
        if (normalized.contains(displayLower) || normalized.contains(idLower)) {
          isMatch = true;
        }
      }
      
      // Extra synonym mappings for improved UX
      if (!isMatch) {
        final synonyms = {
          'temperature': ['fever', 'chills'],
          'hot': ['fever'],
          'cold': ['common_cold', 'runny_nose', 'cough'],
          'breath': ['difficulty_breathing'],
          'breathing': ['difficulty_breathing'],
          'shortness': ['difficulty_breathing'],
          'head': ['headache'],
          'stomach': ['abdominal_pain'],
          'belly': ['abdominal_pain'],
          'joint': ['joint_pain'],
          'throat': ['sore_throat'],
          'taste': ['loss_of_taste'],
          'smell': ['loss_of_smell'],
          'chest': ['chest_pain'],
          'heart': ['chest_pain'],
          'tired': ['fatigue', 'weakness'],
          'exhausted': ['fatigue'],
          'weak': ['weakness'],
          'ache': ['muscle_pain', 'joint_pain', 'headache'],
          'pain': ['muscle_pain', 'joint_pain', 'chest_pain', 'abdominal_pain'],
          'coughing': ['cough'],
          'sneezed': ['sneezing'],
        };
        
        for (final entry in synonyms.entries) {
          if (normalized.contains(entry.key) && entry.value.contains(symptom.id)) {
            isMatch = true;
            break;
          }
        }
      }

      if (isMatch) {
        _allSymptoms[i] = symptom.copyWith(isSelected: true);
        symptomsMatched++;
        matchedNames.add(symptom.displayName);
      }
    }
    
    // 3. Match duration
    String? detectedDuration;
    final durationMappings = {
      'Less than 24h': ['24h', '24 hours', 'one day', '1 day', 'today', 'yesterday', 'less than a day'],
      '1-3 days': ['1-3 days', '2 days', '3 days', 'few days', 'couple of days'],
      '4-7 days': ['4-7 days', '4 days', '5 days', '6 days', '7 days', 'a week', 'one week'],
      '1-2 weeks': ['1-2 weeks', '8 days', '9 days', '10 days', 'two weeks', '2 weeks', 'fortnight'],
      'More than 2 weeks': ['more than 2 weeks', 'weeks', 'months', 'long time', 'chronic'],
    };
    
    for (final entry in durationMappings.entries) {
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) {
          detectedDuration = entry.key;
          _duration = entry.key;
          break;
        }
      }
      if (detectedDuration != null) break;
    }
    
    // 4. Match severity
    String? detectedSeverity;
    final severityMappings = {
      'Severe': ['severe', 'worst', 'extremely bad', 'high', 'unbearable', 'very bad'],
      'Mild': ['mild', 'slight', 'low', 'little', 'not bad', 'minor'],
      'Moderate': ['moderate', 'medium', 'average', 'tolerable'],
    };
    
    for (final entry in severityMappings.entries) {
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) {
          detectedSeverity = entry.key;
          _severity = entry.key;
          break;
        }
      }
      if (detectedSeverity != null) break;
    }
    
    notifyListeners();
    
    return {
      'symptomsMatched': symptomsMatched,
      'matchedNames': matchedNames,
      'duration': detectedDuration ?? _duration,
      'severity': detectedSeverity ?? _severity,
    };
  }


  Future<bool> predict() async {
    final selected = selectedSymptoms.map((s) => s.id).toList();
    if (selected.isEmpty) return false;

    _predictionState = AppState.loading;
    _predictionError = '';
    notifyListeners();

    try {
      _currentPrediction = await _api.predict(
        symptoms: selected,
        age: _age,
        sex: _sex,
        smoker: _smoker,
        weight: _weight,
        height: _height,
        existingConditions: _existingConditions,
        duration: _duration,
        severity: _severity,
      );
      _predictionState = AppState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _predictionState = AppState.error;
      _predictionError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadHistory() async {
    _historyState = AppState.loading;
    _historyError = '';
    notifyListeners();

    try {
      _history = await _api.fetchHistory();
      _historyState = AppState.success;
    } catch (e) {
      _historyState = AppState.error;
      _historyError = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteHistoryItem(int id) async {
    try {
      await _api.deleteHistory(id);
      _history.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      // silently fail — UI can retry
    }
  }

  Future<void> loadReminders() async {
    _remindersState = AppState.loading;
    _remindersError = '';
    notifyListeners();

    try {
      _reminders = await _api.fetchReminders();
      _remindersState = AppState.success;
    } catch (e) {
      _remindersState = AppState.error;
      _remindersError = e.toString();
    }
    notifyListeners();
  }

  Future<bool> addReminderItem(Reminder reminder) async {
    try {
      final added = await _api.addReminder(reminder);
      _reminders.insert(0, added);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteReminderItem(int id) async {
    try {
      await _api.deleteReminder(id);
      _reminders.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      // silently fail
    }
  }
}
