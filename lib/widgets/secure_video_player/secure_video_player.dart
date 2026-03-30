import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'dynamic_watermark_overlay.dart';
import 'youtube_stream_resolver.dart';

class Mp4QualitySource {
  final String label;
  final Uri url;

  const Mp4QualitySource({required this.label, required this.url});
}

class SecureVideoSource {
  final List<Mp4QualitySource>? mp4Qualities;
  final Uri? mp4Url;
  final File? localFile;
  final String? youtubeUrl;

  const SecureVideoSource._({
    this.mp4Qualities,
    this.mp4Url,
    this.localFile,
    this.youtubeUrl,
  });

  factory SecureVideoSource.mp4(
    Uri url, {
    List<Mp4QualitySource>? qualities,
  }) =>
      SecureVideoSource._(mp4Url: url, mp4Qualities: qualities);

  factory SecureVideoSource.youtube(String url) =>
      SecureVideoSource._(youtubeUrl: url);

  factory SecureVideoSource.file(File file) =>
      SecureVideoSource._(localFile: file);

  bool get isYoutube => youtubeUrl != null && youtubeUrl!.isNotEmpty;
  bool get isLocalFile => localFile != null;
}

class SecureVideoPlayer extends StatefulWidget {
  final SecureVideoSource source;
  final DynamicWatermarkData watermark;
  final Future<Duration?> Function()? loadResumePosition;
  final Future<void> Function(Duration position)? saveResumePosition;

  const SecureVideoPlayer({
    super.key,
    required this.source,
    required this.watermark,
    this.loadResumePosition,
    this.saveResumePosition,
  });

  @override
  State<SecureVideoPlayer> createState() => _SecureVideoPlayerState();
}

class _SecureVideoPlayerState extends State<SecureVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _showControls = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;

  // Quality handling
  List<Mp4QualitySource> _mp4Qualities = const [];
  List<YoutubeStreamQuality> _ytQualities = const [];
  String? _selectedQualityLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    setState(() => _initializing = true);
    _showControls = false;

    if (widget.source.isYoutube) {
      await _initYoutube();
    } else {
      await _initMp4();
    }

    if (!mounted) return;
    setState(() {
      _initializing = false;
      _showControls = true;
    });
    _scheduleHide();
  }

  Future<void> _initMp4() async {
    if (widget.source.isLocalFile) {
      _selectedQualityLabel = 'Offline';
      await _switchToFile(widget.source.localFile!, keepPosition: false);
      return;
    }

    _mp4Qualities = widget.source.mp4Qualities ??
        (widget.source.mp4Url != null
            ? [Mp4QualitySource(label: 'Auto', url: widget.source.mp4Url!)]
            : const []);
    final initial = _mp4Qualities.isNotEmpty
        ? _mp4Qualities.first
        : Mp4QualitySource(label: 'Auto', url: widget.source.mp4Url!);
    _selectedQualityLabel = initial.label;
    await _switchToUrl(initial.url, keepPosition: false);
  }

  Future<void> _initYoutube() async {
    final result =
        await YoutubeStreamResolver.instance.resolve(widget.source.youtubeUrl!);
    _ytQualities = result.qualities;
    _selectedQualityLabel =
        _ytQualities.isNotEmpty ? _ytQualities.last.label : 'Auto';
    await _switchToUrl(result.url, keepPosition: false);
  }

  Future<void> _switchToUrl(Uri url, {required bool keepPosition}) async {
    final old = _controller;
    Duration? position;
    if (keepPosition && old != null && old.value.isInitialized) {
      position = old.value.position;
    }

    final controller = VideoPlayerController.networkUrl(url);
    _controller = controller;

    await controller.initialize();
    await controller.setLooping(false);
    await controller.setPlaybackSpeed(_playbackSpeed);

    // Restore resume
    Duration? resume;
    if (widget.loadResumePosition != null) {
      resume = await widget.loadResumePosition!();
    }
    final target = position ?? resume;
    if (target != null && target > Duration.zero) {
      final dur = controller.value.duration;
      final clamped = target < dur ? target : dur - const Duration(seconds: 1);
      if (clamped > Duration.zero) {
        await controller.seekTo(clamped);
      }
    }

    old?.removeListener(_onTick);
    old?.dispose();

    controller.addListener(_onTick);
    if (mounted) setState(() {});
  }

  Future<void> _switchToFile(File file, {required bool keepPosition}) async {
    final old = _controller;
    Duration? position;
    if (keepPosition && old != null && old.value.isInitialized) {
      position = old.value.position;
    }

    final controller = VideoPlayerController.file(file);
    _controller = controller;

    await controller.initialize();
    await controller.setLooping(false);
    await controller.setPlaybackSpeed(_playbackSpeed);

    Duration? resume;
    if (widget.loadResumePosition != null) {
      resume = await widget.loadResumePosition!();
    }
    final target = position ?? resume;
    if (target != null && target > Duration.zero) {
      final dur = controller.value.duration;
      final clamped = target < dur ? target : dur - const Duration(seconds: 1);
      if (clamped > Duration.zero) {
        await controller.seekTo(clamped);
      }
    }

    old?.removeListener(_onTick);
    old?.dispose();

    controller.addListener(_onTick);
    if (mounted) setState(() {});
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    if (!c.value.isInitialized) return;

    // Persist resume periodically
    if (widget.saveResumePosition != null) {
      // Save every ~2 seconds while playing
      if (c.value.isPlaying && (c.value.position.inMilliseconds % 2000) < 250) {
        widget.saveResumePosition!(c.value.position);
      }
    }

    // If YouTube URL expired / failed, re-resolve once.
    if (widget.source.isYoutube && c.value.hasError && !_initializing) {
      _retryYoutube();
    }
  }

  bool _retryingYoutube = false;
  Future<void> _retryYoutube() async {
    if (_retryingYoutube) return;
    _retryingYoutube = true;
    try {
      final result = await YoutubeStreamResolver.instance
          .resolve(widget.source.youtubeUrl!);
      _ytQualities = result.qualities;
      await _switchToUrl(result.url, keepPosition: true);
    } finally {
      _retryingYoutube = false;
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_showControls) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    setState(() {});
  }

  Future<void> _seekBy(Duration delta) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position + delta;
    final clamped = pos < Duration.zero
        ? Duration.zero
        : (pos > c.value.duration ? c.value.duration : pos);
    await c.seekTo(clamped);
  }

  Future<void> _seekToFraction(double fraction) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    final targetMs = (dur.inMilliseconds * fraction).round();
    final clampedMs = targetMs.clamp(0, dur.inMilliseconds);
    await c.seekTo(Duration(milliseconds: clampedMs));
  }

  Future<void> _setSpeed(double speed) async {
    final c = _controller;
    _playbackSpeed = speed;
    if (c != null && c.value.isInitialized) {
      await c.setPlaybackSpeed(speed);
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickQuality() async {
    final items = <String>[];
    if (widget.source.isYoutube) {
      if (_ytQualities.isNotEmpty) {
        items.addAll(_ytQualities.map((e) => e.label));
      }
      if (!items.contains('Auto')) items.insert(0, 'Auto');
    } else {
      items.addAll(_mp4Qualities.map((e) => e.label));
    }

    if (items.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 8),
              for (final label in items)
                ListTile(
                  title: Text(
                    label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: label == _selectedQualityLabel
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () => Navigator.of(context).pop(label),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (picked == null) return;
    _selectedQualityLabel = picked;

    if (widget.source.isYoutube) {
      if (picked == 'Auto' || _ytQualities.isEmpty) {
        final result = await YoutubeStreamResolver.instance
            .resolve(widget.source.youtubeUrl!);
        _ytQualities = result.qualities;
        await _switchToUrl(result.url, keepPosition: true);
      } else {
        final q = _ytQualities.firstWhere((e) => e.label == picked,
            orElse: () => _ytQualities.last);
        await _switchToUrl(q.url, keepPosition: true);
      }
    } else {
      final q = _mp4Qualities.firstWhere((e) => e.label == picked,
          orElse: () => _mp4Qualities.first);
      await _switchToUrl(q.url, keepPosition: true);
    }

    if (mounted) setState(() {});
  }

  Future<void> _pickSpeed() async {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0];
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 8),
              for (final s in speeds)
                ListTile(
                  title: Text(
                    '${s}x',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: s == _playbackSpeed
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () => Navigator.of(context).pop(s),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    await _setSpeed(picked);
  }

  Future<void> _enterFullscreen() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) {
          return _FullscreenScaffold(
            controller: c,
            watermark: widget.watermark,
            speed: _playbackSpeed,
            qualityLabel: _selectedQualityLabel,
            onTogglePlay: _togglePlay,
            onSeekBack: () => _seekBy(const Duration(seconds: -15)),
            onSeekForward: () => _seekBy(const Duration(seconds: 15)),
            onPickSpeed: _pickSpeed,
            onPickQuality: _pickQuality,
          );
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.paused) {
      c?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            if (_initializing || c == null || !c.value.isInitialized)
              const Center(
                  child: CircularProgressIndicator(color: Colors.white))
            else
              AnimatedBuilder(
                animation: c,
                builder: (context, _) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  );
                },
              ),

            // CRITICAL watermark: always above video
            Positioned.fill(
              child: DynamicWatermarkOverlay(
                data: widget.watermark,
                instances: 1,
              ),
            ),

            // Buffering indicator (only after initialized)
            if (!_initializing &&
                c != null &&
                c.value.isInitialized &&
                c.value.isBuffering)
              const Center(
                  child: CircularProgressIndicator(color: Colors.white)),

            // Controls overlay (only after video loaded)
            if (!_initializing &&
                c != null &&
                c.value.isInitialized &&
                _showControls)
              Positioned.fill(
                child: _ControlsOverlay(
                  isPlaying: c.value.isPlaying,
                  position: c.value.position,
                  duration: c.value.duration,
                  speed: _playbackSpeed,
                  qualityLabel: _selectedQualityLabel,
                  onPlayPause: _togglePlay,
                  onSeekBack: () => _seekBy(const Duration(seconds: -15)),
                  onSeekForward: () => _seekBy(const Duration(seconds: 15)),
                  onSeekToFraction: _seekToFraction,
                  onPickSpeed: _pickSpeed,
                  onPickQuality: _pickQuality,
                  onFullscreen: _enterFullscreen,
                  fullscreenIcon: Icons.fullscreen,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final String? qualityLabel;

  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final Future<void> Function(double fraction) onSeekToFraction;
  final VoidCallback onPickSpeed;
  final VoidCallback onPickQuality;
  final VoidCallback onFullscreen;
  final IconData fullscreenIcon;

  const _ControlsOverlay({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
    required this.qualityLabel,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onSeekToFraction,
    required this.onPickSpeed,
    required this.onPickQuality,
    required this.onFullscreen,
    required this.fullscreenIcon,
  });

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final safeDuration =
        duration == Duration.zero ? const Duration(seconds: 1) : duration;
    final value = position.inMilliseconds / safeDuration.inMilliseconds;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.55),
            Colors.transparent,
            Colors.black.withOpacity(0.65),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 8),
              _PillButton(
                label: '${speed}x',
                onTap: onPickSpeed,
              ),
              const SizedBox(width: 8),
              _PillButton(
                label: qualityLabel ?? 'Quality',
                onTap: onPickQuality,
              ),
              const Spacer(),
              IconButton(
                onPressed: onFullscreen,
                icon: Icon(fullscreenIcon, color: Colors.white),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onSeekBack,
                icon: const _SeekIcon(isForward: false),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onPlayPause,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.black,
                  size: 64,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onSeekForward,
                icon: const _SeekIcon(isForward: true),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: value.clamp(0.0, 1.0),
                    onChanged: (v) {
                      // Seek while dragging for immediate feedback
                      onSeekToFraction(v.clamp(0.0, 1.0));
                    },
                  ),
                ),
                Row(
                  children: [
                    Text(_fmt(position),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                    const Spacer(),
                    Text(_fmt(duration),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class _FullscreenScaffold extends StatefulWidget {
  final VideoPlayerController controller;
  final DynamicWatermarkData watermark;
  final double speed;
  final String? qualityLabel;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onPickSpeed;
  final VoidCallback onPickQuality;

  const _FullscreenScaffold({
    required this.controller,
    required this.watermark,
    required this.speed,
    required this.qualityLabel,
    required this.onTogglePlay,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onPickSpeed,
    required this.onPickQuality,
  });

  @override
  State<_FullscreenScaffold> createState() => _FullscreenScaffoldState();
}

class _FullscreenScaffoldState extends State<_FullscreenScaffold> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _enter();
    _scheduleHide();
  }

  Future<void> _enter() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exit() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _exit();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_showControls) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: c,
                  builder: (context, _) {
                    return Center(
                      child: AspectRatio(
                        aspectRatio: c.value.aspectRatio == 0
                            ? 16 / 9
                            : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: DynamicWatermarkOverlay(
                  data: widget.watermark,
                  instances: 1,
                ),
              ),
              if (c.value.isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_showControls)
                Positioned.fill(
                  child: _ControlsOverlay(
                    isPlaying: c.value.isPlaying,
                    position: c.value.position,
                    duration: c.value.duration,
                    speed: widget.speed,
                    qualityLabel: widget.qualityLabel,
                    onPlayPause: widget.onTogglePlay,
                    onSeekBack: widget.onSeekBack,
                    onSeekForward: widget.onSeekForward,
                    onSeekToFraction: (f) async {
                      final dur = c.value.duration;
                      if (dur == Duration.zero) return;
                      final ms = (dur.inMilliseconds * f)
                          .round()
                          .clamp(0, dur.inMilliseconds);
                      await c.seekTo(Duration(milliseconds: ms));
                    },
                    onPickSpeed: widget.onPickSpeed,
                    onPickQuality: widget.onPickQuality,
                    onFullscreen: () => Navigator.of(context).pop(),
                    fullscreenIcon: Icons.fullscreen_exit,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekIcon extends StatelessWidget {
  final bool isForward;

  const _SeekIcon({required this.isForward});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(isForward ? -1.0 : 1.0, 1.0),
            child: const Icon(Icons.replay, color: Colors.black, size: 30),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(0, 2),
                child: const Text(
                  '15',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
