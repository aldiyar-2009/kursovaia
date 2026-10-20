import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:studyplan/core/sync/sync_repository.dart';
import 'package:studyplan/core/sync/sync_state.dart';

abstract class SyncEvent {}

class SyncCheckRequested extends SyncEvent {}

class SyncTriggered extends SyncEvent {}

class SyncPendingUpdated extends SyncEvent {
  final int count;
  SyncPendingUpdated(this.count);
}

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository repository;
  final String userId;
  StreamSubscription? _connectivitySubscription;

  SyncBloc({required this.repository, required this.userId}) : super(const SyncState()) {
    on<SyncCheckRequested>(_onCheckRequested);
    on<SyncTriggered>(_onSyncTriggered);
    on<SyncPendingUpdated>((event, emit) {
      if (event.count > 0 && state.status == SyncStatusState.synced) {
        emit(state.copyWith(status: SyncStatusState.offlinePending, pendingCount: event.count));
      } else {
        emit(state.copyWith(pendingCount: event.count));
      }
    });

    _initConnectivityListener();
    add(SyncCheckRequested());
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        add(SyncTriggered());
      }
    });
  }

  Future<void> _onCheckRequested(SyncCheckRequested event, Emitter<SyncState> emit) async {
    try {
      final count = await repository.getPendingChangesCount(userId);
      if (count > 0) {
        emit(state.copyWith(status: SyncStatusState.offlinePending, pendingCount: count));
      } else {
        emit(state.copyWith(status: SyncStatusState.synced, pendingCount: 0));
      }
    } catch (_) {}
  }

  Future<void> _onSyncTriggered(SyncTriggered event, Emitter<SyncState> emit) async {
    emit(state.copyWith(status: SyncStatusState.syncing));
    try {
      final result = await repository.syncWithServer(userId);
      emit(state.copyWith(
        status: SyncStatusState.synced,
        pendingCount: 0,
        lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(result.serverTime),
        errorMessage: null,
      ));
    } catch (e) {
      final count = await repository.getPendingChangesCount(userId);
      emit(state.copyWith(
        status: count > 0 ? SyncStatusState.offlinePending : SyncStatusState.error,
        pendingCount: count,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
