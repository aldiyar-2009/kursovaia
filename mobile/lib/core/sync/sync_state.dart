import 'package:equatable/equatable.dart';

enum SyncStatusState { synced, syncing, offlinePending, error }

class SyncState extends Equatable {
  final SyncStatusState status;
  final String? errorMessage;
  final int pendingCount;
  final DateTime? lastSyncedAt;

  const SyncState({
    this.status = SyncStatusState.synced,
    this.errorMessage,
    this.pendingCount = 0,
    this.lastSyncedAt,
  });

  SyncState copyWith({
    SyncStatusState? status,
    String? errorMessage,
    int? pendingCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, pendingCount, lastSyncedAt];
}
