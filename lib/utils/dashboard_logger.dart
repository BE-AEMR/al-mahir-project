import 'package:flutter/foundation.dart';

/// Utilitaire pour tracer les cycles de vie et le flux de données du Dashboard
class DashboardLogger {
  static int _buildCount = 0;
  static int _setStateCount = 0;
  static final Map<String, int> _methodCallCounts = {};
  static final StringBuffer _eventLog = StringBuffer();

  static void reset() {
    _buildCount = 0;
    _setStateCount = 0;
    _methodCallCounts.clear();
    _eventLog.clear();
    log('TRACE RESET', type: LogType.reset);
  }

  static void logLifecycle(String event, {Object? details}) {
    log(event, type: LogType.lifecycle, details: details);
  }

  static void logStateChange(String description, {Object? details}) {
    _setStateCount++;
    log('setState #$_setStateCount: $description', type: LogType.stateChange, details: details);
  }

  static void logBuild() {
    _buildCount++;
    log('build #$_buildCount', type: LogType.build);
  }

  static void logDataLoading(String source, {Object? details}) {
    log('Chargement des données depuis $source', type: LogType.dataLoading, details: details);
  }

  static void logDataUpdate(String description, {Object? details}) {
    log('Mise à jour des données: $description', type: LogType.dataUpdate, details: details);
  }

  static void logMethodCall(String methodName) {
    _methodCallCounts[methodName] = (_methodCallCounts[methodName] ?? 0) + 1;
    int count = _methodCallCounts[methodName]!;
    log('$methodName appelé (appel #$count)', type: LogType.methodCall);
  }

  static void log(String message, {LogType type = LogType.other, Object? details}) {
    final timestamp = DateTime.now().toString().split('.').first;
    final emoji = _getEmojiForType(type);
    final formattedMessage = '$timestamp $emoji $message';
    
    _eventLog.writeln(formattedMessage);
    if (details != null) {
      _eventLog.writeln('    └─ $details');
    }
    
    // Afficher également dans la console
    if (kDebugMode) {
      print(formattedMessage);
      if (details != null) {
        print('    └─ $details');
      }
    }
  }

  static String _getEmojiForType(LogType type) {
    switch (type) {
      case LogType.lifecycle:
        return '🔄';
      case LogType.stateChange:
        return '🔔';
      case LogType.build:
        return '🏗️';
      case LogType.dataLoading:
        return '📥';
      case LogType.dataUpdate:
        return '📊';
      case LogType.methodCall:
        return '📞';
      case LogType.reset:
        return '🧹';
      case LogType.other:
      default:
        return '📌';
    }
  }

  static String getEventLog() {
    return _eventLog.toString();
  }

  static Map<String, dynamic> getSummary() {
    return {
      'buildCount': _buildCount,
      'setStateCount': _setStateCount,
      'methodCalls': Map<String, int>.from(_methodCallCounts),
    };
  }
}

enum LogType {
  lifecycle,
  stateChange,
  build,
  dataLoading,
  dataUpdate,
  methodCall,
  reset,
  other,
}
