import 'package:flutter/material.dart';
import '../data/sync/auto_sync_manager.dart';
import '../core/di/locator.dart';

/// Widget that displays the current sync status
class SyncStatusIndicator extends StatefulWidget {
  final bool showLabel;
  final bool compact;

  const SyncStatusIndicator({
    super.key,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final _autoSyncManager = getIt<AutoSyncManager>();
  SyncStatus _currentStatus = SyncStatus.offline;

  @override
  void initState() {
    super.initState();
    _currentStatus = _autoSyncManager.currentStatus;
    _autoSyncManager.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactIndicator();
    }
    return _buildFullIndicator();
  }

  Widget _buildCompactIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(size: 14),
          if (widget.showLabel) ...[
            const SizedBox(width: 4),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 11,
                color: _getStatusColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(size: 16),
          if (widget.showLabel) ...[
            const SizedBox(width: 8),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 13,
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon({required double size}) {
    switch (_currentStatus) {
      case SyncStatus.offline:
        return Icon(
          Icons.cloud_off,
          size: size,
          color: Colors.grey,
        );
      case SyncStatus.syncing:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
          ),
        );
      case SyncStatus.synced:
        return Icon(
          Icons.cloud_done,
          size: size,
          color: Colors.green,
        );
      case SyncStatus.error:
        return Icon(
          Icons.cloud_off,
          size: size,
          color: Colors.red,
        );
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case SyncStatus.offline:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText() {
    switch (_currentStatus) {
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.error:
        return 'Sync Error';
    }
  }
}
