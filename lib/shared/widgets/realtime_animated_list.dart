import 'package:flutter/material.dart';
import 'list_animations.dart';

/// A generic animated list that diffs state changes and calls
/// [AnimatedListState.insertItem] / [AnimatedListState.removeItem]
/// to animate enter/leave transitions.
///
/// Usage:
/// ```dart
/// RealtimeAnimatedList<Trip>(
///   items: trips,
///   keyExtractor: (t) => t.id,
///   itemBuilder: (ctx, trip, animation) => slideInBuilder(ctx, GroupCard(group: trip), animation),
///   removedItemBuilder: (ctx, trip, animation) => slideOutBuilder(ctx, GroupCard(group: trip), animation),
/// )
/// ```
class RealtimeAnimatedList<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) keyExtractor;
  final Widget Function(BuildContext, T, Animation<double>) itemBuilder;
  final Widget Function(BuildContext, T, Animation<double>) removedItemBuilder;
  final Duration insertDuration;
  final Duration removeDuration;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollController? controller;
  final bool reverse;

  const RealtimeAnimatedList({
    super.key,
    required this.items,
    required this.keyExtractor,
    required this.itemBuilder,
    required this.removedItemBuilder,
    this.insertDuration = kListInsertDuration,
    this.removeDuration = kListRemoveDuration,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.controller,
    this.reverse = false,
  });

  @override
  State<RealtimeAnimatedList<T>> createState() =>
      _RealtimeAnimatedListState<T>();
}

class _RealtimeAnimatedListState<T> extends State<RealtimeAnimatedList<T>> {
  final _listKey = GlobalKey<AnimatedListState>();

  /// Internal copy synced 1:1 with AnimatedList's item count.
  List<T> _currentItems = [];
  List<String> _currentKeys = [];

  @override
  void initState() {
    super.initState();
    _currentItems = List.of(widget.items);
    _currentKeys = _currentItems.map(widget.keyExtractor).toList();
  }

  @override
  void didUpdateWidget(RealtimeAnimatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _diffAndAnimate(widget.items);
  }

  void _diffAndAnimate(List<T> newItems) {
    final newKeys = newItems.map(widget.keyExtractor).toList();
    final oldKeySet = _currentKeys.toSet();
    final newKeySet = newKeys.toSet();

    final removedKeys = oldKeySet.difference(newKeySet);
    final addedKeys = newKeySet.difference(oldKeySet);

    // --- Removals (backwards to preserve indices) ---
    // Call removeItem FIRST, then mutate _currentItems, keeping them in sync.
    if (removedKeys.isNotEmpty) {
      for (var i = _currentKeys.length - 1; i >= 0; i--) {
        if (removedKeys.contains(_currentKeys[i])) {
          final removedItem = _currentItems[i];
          // Tell AnimatedList to animate removal at index i.
          _listKey.currentState?.removeItem(
            i,
            (context, animation) =>
                widget.removedItemBuilder(context, removedItem, animation),
            duration: widget.removeDuration,
          );
          // Now mutate our tracking lists to match.
          _currentItems.removeAt(i);
          _currentKeys.removeAt(i);
        }
      }
    }

    // --- Updates (in-place data replacement for kept items) ---
    for (final key in oldKeySet.intersection(newKeySet)) {
      final oldIdx = _currentKeys.indexOf(key);
      final newIdx = newKeys.indexOf(key);
      if (oldIdx >= 0 && newIdx >= 0) {
        _currentItems[oldIdx] = newItems[newIdx];
      }
    }

    // --- Insertions (synchronous — no Future.delayed) ---
    // Insert each new item at its target position and immediately tell
    // AnimatedList, keeping counts perfectly in sync.
    if (addedKeys.isNotEmpty) {
      for (var i = 0; i < newKeys.length; i++) {
        if (addedKeys.contains(newKeys[i])) {
          final insertAt = i.clamp(0, _currentItems.length);
          _currentItems.insert(insertAt, newItems[i]);
          _currentKeys.insert(insertAt, newKeys[i]);
          _listKey.currentState?.insertItem(
            insertAt,
            duration: widget.insertDuration,
          );
        }
      }
    }

    // --- Pure reorder / data-only update ---
    if (addedKeys.isEmpty && removedKeys.isEmpty) {
      _currentItems = List.of(newItems);
      _currentKeys = newKeys;
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      controller: widget.controller,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      reverse: widget.reverse,
      initialItemCount: _currentItems.length,
      itemBuilder: (context, index, animation) {
        if (index >= _currentItems.length) return const SizedBox.shrink();
        final item = _currentItems[index];
        return widget.itemBuilder(context, item, animation);
      },
    );
  }
}

/// A simpler variant for non-scrollable contexts (e.g., inside a Column
/// within a SingleChildScrollView).
class RealtimeAnimatedColumn<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T) keyExtractor;
  final Widget Function(BuildContext, T, Animation<double>) itemBuilder;
  final Widget Function(BuildContext, T, Animation<double>) removedItemBuilder;
  final Duration insertDuration;
  final Duration removeDuration;

  const RealtimeAnimatedColumn({
    super.key,
    required this.items,
    required this.keyExtractor,
    required this.itemBuilder,
    required this.removedItemBuilder,
    this.insertDuration = kListInsertDuration,
    this.removeDuration = kListRemoveDuration,
  });

  @override
  Widget build(BuildContext context) {
    return RealtimeAnimatedList<T>(
      items: items,
      keyExtractor: keyExtractor,
      itemBuilder: itemBuilder,
      removedItemBuilder: removedItemBuilder,
      insertDuration: insertDuration,
      removeDuration: removeDuration,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}
