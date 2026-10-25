import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/sync/sync_repository.dart';
import 'package:studyplan/core/sync/sync_state.dart';

/// SharedPreferences key of the sync cursor (`last_synced_at`, epoch ms).
/// Must match `SyncRepository._lastSyncedKey`.
const kSyncCursorPrefsKey = 'studyplan_last_synced_at';

/// Resets the sync cursor to 0 so the next sync pulls every row the server
/// has for the user (e.g. group tasks published before joining a group).
///
/// Same as `SyncRepository.resetCursor()`, for callers without a repository
/// (the auth screen, before the shell exists).
Future<void> resetSyncCursor() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(kSyncCursorPrefsKey, 0);
}

abstract class SyncEvent {}

class SyncCheckRequested extends SyncEvent {}

class SyncTriggered extends SyncEvent {}

/// Full resync: the cursor is reset to 0 right before the next sync starts
/// (after the running one, if any, so it cannot overwrite the reset).
class SyncFullResyncRequested extends SyncEvent {}

class SyncPendingUpdated extends SyncEvent {
  final int count;
  SyncPendingUpdated(this.count);
}

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository repository;
  final String userId;

  /// Delay between a local change and the automatic sync it schedules.
  final Duration pendingDebounce;

  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _localChangesSubscription;
  Timer? _debounceTimer;

  /// True while a sync request is in flight; further triggers are ignored.
  bool _syncing = false;

  /// A trigger arrived during the running sync; checked when it ends.
  bool _triggerDropped = false;

  /// Set by [SyncFullResyncRequested]; consumed when the next sync starts.
  bool _cursorResetPending = false;
  int _lastPendingCount = 0;

  SyncBloc({
    required this.repository,
    required this.userId,
    this.pendingDebounce = const Duration(seconds: 5),
    bool listenToConnectivity = true,
    bool watchLocalChanges = true,
  }) : super(const SyncState()) {
    on<SyncCheckRequested>(_onCheckRequested);
    on<SyncTriggered>(_onSyncTriggered);
    on<SyncPendingUpdated>(_onPendingUpdated);
    on<SyncFullResyncRequested>((event, emit) {
      _cursorResetPending = true;
      add(SyncTriggered());
    });

    if (listenToConnectivity) _initConnectivityListener();
    if (watchLocalChanges) _initLocalChangesListener();
    add(SyncCheckRequested());
  }

  /// Whether a sync is running right now.
  bool get isSyncing => _syncing;

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline) add(SyncTriggered());
      },
      onError: (_) {},
    );
  }

  /// Recounts pending rows after every local database write.
  void _initLocalChangesListener() {
    _localChangesSubscription = repository.db.tableUpdates().listen((_) async {
      if (isClosed) return;
      try {
        final count = await repository.getPendingChangesCount(userId);
        if (!isClosed) add(SyncPendingUpdated(count));
      } catch (_) {}
    });
  }

  void _onPendingUpdated(SyncPendingUpdated event, Emitter<SyncState> emit) {
    final increased = event.count > _lastPendingCount;
    _lastPendingCount = event.count;
    if (event.count > 0 && state.status == SyncStatusState.synced) {
      emit(state.copyWith(status: SyncStatusState.offlinePending, pendingCount: event.count));
    } else {
      emit(state.copyWith(pendingCount: event.count));
    }
    // New local changes: sync once the user stops editing for a moment.
    if (increased) _scheduleDebouncedSync();
  }

  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(pendingDebounce, () {
      if (!isClosed) add(SyncTriggered());
    });
  }

  Future<void> _onCheckRequested(SyncCheckRequested event, Emitter<SyncState> emit) async {
    try {
      final count = await repository.getPendingChangesCount(userId);
      _lastPendingCount = count;
      if (_syncing) return;
      if (count > 0) {
        emit(state.copyWith(status: SyncStatusState.offlinePending, pendingCount: count));
      } else {
        emit(state.copyWith(status: SyncStatusState.synced, pendingCount: 0));
      }
    } catch (_) {}
  }

  Future<void> _onSyncTriggered(SyncTriggered event, Emitter<SyncState> emit) async {
    // A single sync at a time: triggers that arrive meanwhile are dropped
    // (the running sync already pushes what was pending when it started;
    // later changes schedule their own debounced sync).
    if (_syncing) {
      _triggerDropped = true;
      return;
    }
    _syncing = true;
    _triggerDropped = false;
    _debounceTimer?.cancel();
    emit(state.copyWith(status: SyncStatusState.syncing));
    try {
      if (_cursorResetPending) {
        _cursorResetPending = false;
        await repository.resetCursor();
      }
      final result = await repository.syncWithServer(userId);
      final count = await _pendingCountOrZero();
      _lastPendingCount = count;
      emit(state.copyWith(
        status: count > 0 ? SyncStatusState.offlinePending : SyncStatusState.synced,
        pendingCount: count,
        lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(result.serverTime),
        errorMessage: null,
      ));
    } catch (e) {
      final count = await _pendingCountOrZero();
      _lastPendingCount = count;
      emit(state.copyWith(
        status: count > 0 ? SyncStatusState.offlinePending : SyncStatusState.error,
        pendingCount: count,
        errorMessage: e.toString(),
      ));
    } finally {
      _syncing = false;
    }
    // A trigger was dropped meanwhile: run one follow-up sync now for a
    // requested full resync, or debounced for changes made while syncing.
    if (_triggerDropped && !isClosed) {
      _triggerDropped = false;
      if (_cursorResetPending) {
        add(SyncTriggered());
      } else if (_lastPendingCount > 0) {
        _scheduleDebouncedSync();
      }
    }
  }

  Future<int> _pendingCountOrZero() async {
    try {
      return await repository.getPendingChangesCount(userId);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _localChangesSubscription?.cancel();
    return super.close();
  }
}
