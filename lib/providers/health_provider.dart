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

  Future<bool> predict() async {
    final selected = selectedSymptoms.map((s) => s.id).toList();
    if (selected.isEmpty) return false;

    _predictionState = AppState.loading;
    _predictionError = '';
    notifyListeners();

    try {
      _currentPrediction = await _api.predict(selected);
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
