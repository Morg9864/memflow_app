import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/models/models.dart';

typedef PaginatedSliceLoader<T> =
    Future<PaginatedSlice<T>> Function({
      required int offset,
      required int limit,
    });

class PaginatedListState<T> {
  const PaginatedListState({
    required this.items,
    required this.totalCount,
    required this.isInitialLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    this.error,
  });

  const PaginatedListState.initial()
    : items = const [],
      totalCount = 0,
      isInitialLoading = true,
      isRefreshing = false,
      isLoadingMore = false,
      error = null;

  final List<T> items;
  final int totalCount;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Object? error;

  bool get hasMore => items.length < totalCount;

  PaginatedListState<T> copyWith({
    List<T>? items,
    int? totalCount,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = _sentinel,
  }) {
    return PaginatedListState<T>(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error,
    );
  }
}

class PaginatedListController<T> extends ChangeNotifier {
  PaginatedListController({
    required PaginatedSliceLoader<T> loadSlice,
    Stream<Object?>? refreshStream,
    this.pageSize = 40,
  }) : _loadSlice = loadSlice,
       _refreshStream = refreshStream;

  final PaginatedSliceLoader<T> _loadSlice;
  final Stream<Object?>? _refreshStream;
  final int pageSize;

  PaginatedListState<T> _state = PaginatedListState<T>.initial();
  PaginatedListState<T> get state => _state;

  StreamSubscription<Object?>? _refreshSubscription;
  var _started = false;
  var _fetchInFlight = false;
  var _refreshQueued = false;
  var _disposed = false;
  var _visibleItemTarget = 0;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _refreshSubscription = _refreshStream?.listen((_) {
      unawaited(refresh());
    });
    await _reload(preserveVisibleItems: false);
  }

  Future<void> refresh() async {
    await _reload(preserveVisibleItems: true);
  }

  Future<void> loadMore() async {
    if (_fetchInFlight || !_state.hasMore) {
      return;
    }

    _fetchInFlight = true;
    _updateState(
      _state.copyWith(
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: true,
        error: null,
      ),
    );

    try {
      final slice = await _loadSlice(
        offset: _state.items.length,
        limit: pageSize,
      );
      final nextItems = [..._state.items, ...slice.items];
      _visibleItemTarget = nextItems.length;
      _updateState(
        _state.copyWith(
          items: nextItems,
          totalCount: slice.totalCount,
          isLoadingMore: false,
          error: null,
        ),
      );
    } catch (error) {
      _updateState(
        _state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          error: error,
        ),
      );
    } finally {
      _fetchInFlight = false;
      await _flushQueuedRefreshIfNeeded();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_refreshSubscription?.cancel());
    super.dispose();
  }

  Future<void> _reload({required bool preserveVisibleItems}) async {
    if (_fetchInFlight) {
      _refreshQueued = true;
      return;
    }

    final hasItems = _state.items.isNotEmpty;
    final targetLimit = preserveVisibleItems
        ? math.max(_visibleItemTarget, pageSize)
        : pageSize;

    _fetchInFlight = true;
    _updateState(
      _state.copyWith(
        isInitialLoading: !hasItems,
        isRefreshing: hasItems,
        isLoadingMore: false,
        error: null,
      ),
    );

    try {
      final slice = await _loadSlice(offset: 0, limit: targetLimit);
      _visibleItemTarget = slice.items.length;
      _updateState(
        _state.copyWith(
          items: slice.items,
          totalCount: slice.totalCount,
          isInitialLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          error: null,
        ),
      );
    } catch (error) {
      _updateState(
        _state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          error: error,
        ),
      );
    } finally {
      _fetchInFlight = false;
      await _flushQueuedRefreshIfNeeded();
    }
  }

  Future<void> _flushQueuedRefreshIfNeeded() async {
    if (_refreshQueued && !_disposed) {
      _refreshQueued = false;
      await _reload(preserveVisibleItems: true);
    }
  }

  void _updateState(PaginatedListState<T> nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }
}

const _sentinel = Object();
