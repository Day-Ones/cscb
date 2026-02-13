import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';

/// Sync status enum
enum SyncStatus {
  offline,      // No internet connection
  syncing,      // Currently syncing
  synced,       // All data synced
  error,        // Sync error occurred
}

/// Manages automatic syncing when internet connection is restored
class AutoSyncManager {
  final SyncService _syncService;
  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;
  Timer? _syncTimer;
  
  // Status stream for UI updates
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus _currentStatus = SyncStatus.offline;
  SyncStatus get currentStatus => _currentStatus;

  AutoSyncManager(this._syncService);

  /// Start monitoring connectivity and auto-sync
  Future<void> start() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    
    if (_isOnline) {
      debugPrint('AutoSync: Online - triggering initial sync');
      _triggerSync();
    } else {
      debugPrint('AutoSync: Offline - waiting for connection');
      _updateStatus(SyncStatus.offline);
    }

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        debugPrint('AutoSync: Connectivity error: $error');
      },
    );

    // Also set up periodic sync every 5 minutes when online
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && !_isSyncing) {
        debugPrint('AutoSync: Periodic sync triggered');
        _triggerSync();
      }
    });
  }

  /// Stop monitoring
  void stop() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _statusController.close();
    debugPrint('AutoSync: Stopped');
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);

    debugPrint('AutoSync: Connectivity changed - Online: $_isOnline');

    if (!_isOnline) {
      _updateStatus(SyncStatus.offline);
    }

    // If we just came online, trigger sync
    if (!wasOnline && _isOnline) {
      debugPrint('AutoSync: Connection restored - triggering sync');
      _triggerSync();
    }
  }

  /// Trigger sync (with debouncing to avoid multiple simultaneous syncs)
  void _triggerSync() {
    if (_isSyncing) {
      debugPrint('AutoSync: Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);
    
    _syncService.syncAll().then((result) {
      if (result.success) {
        debugPrint('AutoSync: ✅ ${result.message}');
        _updateStatus(SyncStatus.synced);
      } else {
        debugPrint('AutoSync: ❌ ${result.message}');
        _updateStatus(SyncStatus.error);
      }
    }).catchError((error) {
      debugPrint('AutoSync: ❌ Error: $error');
      _updateStatus(SyncStatus.error);
    }).whenComplete(() {
      _isSyncing = false;
    });
  }

  /// Update status and notify listeners
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Manually trigger sync (useful for pull-to-refresh)
  Future<void> manualSync() async {
    if (!_isOnline) {
      debugPrint('AutoSync: Cannot sync - offline');
      return;
    }
    
    debugPrint('AutoSync: Manual sync triggered');
    _triggerSync();
  }
}
