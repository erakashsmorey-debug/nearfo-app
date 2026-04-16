import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Singleton service that monitors network connectivity state.
/// Provides a stream of connectivity changes and a synchronous getter.
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription? _sub;
  bool _isOnline = true; // Assume online at start
  bool _initialized = false;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Initialize — call once at app startup
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(result);
      debugPrint('[Connectivity] Initial state: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    } catch (e) {
      debugPrint('[Connectivity] Init check error: $e');
      _isOnline = true; // Assume online if check fails
    }

    try {
      _sub = _connectivity.onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = _isConnected(result);
        if (wasOnline != _isOnline) {
          debugPrint('[Connectivity] State changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
          if (!_controller.isClosed) {
            _controller.add(_isOnline);
          }
        }
      }, onError: (e) {
        debugPrint('[Connectivity] Stream error (non-fatal): $e');
      });
    } catch (e) {
      debugPrint('[Connectivity] Failed to listen for changes (non-fatal): $e');
      // App still works — just won't auto-detect connectivity changes
    }
  }

  bool _isConnected(dynamic result) {
    // connectivity_plus returns List<ConnectivityResult> in newer versions
    if (result is List<ConnectivityResult>) {
      return result.any((r) => r != ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return true;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
    _instance = null;
  }
}
