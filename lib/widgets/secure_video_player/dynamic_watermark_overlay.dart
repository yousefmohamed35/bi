import 'dart:math';

import 'package:flutter/material.dart';

class DynamicWatermarkData {
  final String username;
  final String identifier; // phone / national id

  const DynamicWatermarkData({
    required this.username,
    required this.identifier,
  });

  static const DynamicWatermarkData fallback = DynamicWatermarkData(
    username: 'مشترك',
    identifier: '—',
  );

  /// Builds watermark text from [TokenStorageService] / login payload shape.
  static DynamicWatermarkData fromCachedUser(Map<String, dynamic>? user) {
    if (user == null || user.isEmpty) return fallback;

    String? s(dynamic v) {
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    final name = s(user['name']) ?? s(user['nameAr']);
    final email = s(user['email']);
    final phone = s(user['phone']);
    final nationalId = s(user['nationalId']) ?? s(user['national_id']);

    final username = name ?? email ?? fallback.username;
    final identifier = phone ?? nationalId ?? email ?? fallback.identifier;

    return DynamicWatermarkData(username: username, identifier: identifier);
  }
}

/// A moving watermark overlay that stays visible above the video
/// (play/pause/buffering/fullscreen).
class DynamicWatermarkOverlay extends StatefulWidget {
  final DynamicWatermarkData data;
  final int instances;

  const DynamicWatermarkOverlay({
    super.key,
    required this.data,
    this.instances = 1,
  });

  @override
  State<DynamicWatermarkOverlay> createState() =>
      _DynamicWatermarkOverlayState();
}

class _DynamicWatermarkOverlayState extends State<DynamicWatermarkOverlay>
    with SingleTickerProviderStateMixin {
  final _rand = Random.secure();

  // 0..1 positions within parent.
  late List<Offset> _fromPositions;
  late List<Offset> _toPositions;

  late final AnimationController _controller;
  late final Animation<double> _t;

  double _opacity = 0.22;
  double _rotation = 0.0;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _fromPositions = List.generate(widget.instances, (_) => _randomOffset());
    _toPositions = List.generate(widget.instances, (_) => _randomOffset());

    _controller = AnimationController(
      vsync: this,
      // Continuous movement; pick a new target every cycle.
      duration: const Duration(milliseconds: 12000),
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.linear);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _fromPositions = _toPositions;
        _toPositions = List.generate(widget.instances, (_) => _randomOffset());

        // Subtle variation per cycle (but always moving).
        _opacity = 0.14 + (_rand.nextDouble() * 0.10); // 0.14–0.24
        _rotation = (_rand.nextDouble() - 0.5) * 0.10; // ~ -6° .. +6°
        _scale = 0.90 + (_rand.nextDouble() * 0.10); // 0.90–1.00

        _controller.forward(from: 0);
      }
    });

    _controller.forward();
  }

  Offset _randomOffset() {
    // Avoid edges a bit (keep text visible).
    const min = 0.08;
    const max = 0.92;
    final dx = min + _rand.nextDouble() * (max - min);
    final dy = min + _rand.nextDouble() * (max - min);
    return Offset(dx, dy);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          final text = '${widget.data.username} • ${widget.data.identifier}';

          return AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final children = <Widget>[];
              for (int i = 0; i < widget.instances; i++) {
                final from = _fromPositions[i];
                final to = _toPositions[i];
                final p = Offset(
                  from.dx + (to.dx - from.dx) * _t.value,
                  from.dy + (to.dy - from.dy) * _t.value,
                );
                children.add(
                  Positioned(
                    left: (w * p.dx).clamp(0, max(0.0, w - 10)),
                    top: (h * p.dy).clamp(0, max(0.0, h - 10)),
                    child: Opacity(
                      opacity: _opacity,
                      child: Transform.rotate(
                        angle: _rotation,
                        child: Transform.scale(
                          scale: _scale,
                          child: _WatermarkChip(text: text),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Stack(children: children);
            },
          );
        },
      ),
    );
  }
}

class _WatermarkChip extends StatelessWidget {
  final String text;

  const _WatermarkChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
