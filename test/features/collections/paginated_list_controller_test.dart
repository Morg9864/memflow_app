import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memflow/domain/models/models.dart';
import 'package:memflow/features/collections/paginated_list_controller.dart';

void main() {
  PaginatedSlice<int> buildSlice(
    List<int> source, {
    required int offset,
    required int limit,
  }) {
    final start = offset.clamp(0, source.length);
    final end = (offset + limit).clamp(0, source.length);
    return PaginatedSlice(
      items: source.sublist(start, end),
      totalCount: source.length,
    );
  }

  test(
    'initial load fetches the first page and exposes the total count',
    () async {
      final controller = PaginatedListController<int>(
        pageSize: 2,
        loadSlice: ({required offset, required limit}) async {
          return buildSlice([1, 2, 3, 4, 5], offset: offset, limit: limit);
        },
      );
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.items, [1, 2]);
      expect(controller.state.totalCount, 5);
      expect(controller.state.hasMore, isTrue);
      expect(controller.state.isInitialLoading, isFalse);
    },
  );

  test('loadMore appends the next page', () async {
    final controller = PaginatedListController<int>(
      pageSize: 2,
      loadSlice: ({required offset, required limit}) async {
        return buildSlice([1, 2, 3, 4, 5], offset: offset, limit: limit);
      },
    );
    addTearDown(controller.dispose);

    await controller.start();
    await controller.loadMore();

    expect(controller.state.items, [1, 2, 3, 4]);
    expect(controller.state.totalCount, 5);
    expect(controller.state.hasMore, isTrue);
    expect(controller.state.isLoadingMore, isFalse);
  });

  test(
    'refresh stream reloads the visible window after data changes',
    () async {
      final refreshController = StreamController<Object?>.broadcast();
      addTearDown(refreshController.close);

      var source = [1, 2, 3, 4, 5];
      final controller = PaginatedListController<int>(
        pageSize: 2,
        refreshStream: refreshController.stream,
        loadSlice: ({required offset, required limit}) async {
          return buildSlice(source, offset: offset, limit: limit);
        },
      );
      addTearDown(controller.dispose);

      await controller.start();
      await controller.loadMore();
      expect(controller.state.items, [1, 2, 3, 4]);

      source = [10, 11, 12, 13, 14];
      refreshController.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.items, [10, 11, 12, 13]);
      expect(controller.state.totalCount, 5);
      expect(controller.state.hasMore, isTrue);
    },
  );
}
