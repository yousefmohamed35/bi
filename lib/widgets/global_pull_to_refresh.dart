import 'package:flutter/material.dart';

class GlobalPullToRefresh extends StatefulWidget {
  final Widget child;

  const GlobalPullToRefresh({
    super.key,
    required this.child,
  });

  @override
  State<GlobalPullToRefresh> createState() => _GlobalPullToRefreshState();
}

class _GlobalPullToRefreshState extends State<GlobalPullToRefresh> {
  int _refreshVersion = 0;

  Future<void> _handleRefresh() async {
    if (!mounted) return;

    setState(() {
      _refreshVersion++;
    });

    // Keep the indicator visible briefly for clearer UX feedback.
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      notificationPredicate: (notification) {
        return notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical;
      },
      child: KeyedSubtree(
        key: ValueKey(_refreshVersion),
        child: widget.child,
      ),
    );
  }
}
