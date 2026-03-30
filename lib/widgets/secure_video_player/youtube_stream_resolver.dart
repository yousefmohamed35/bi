import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeStreamQuality {
  final String label; // e.g. 360p, 720p
  final int? height;
  final Uri url;

  YoutubeStreamQuality({
    required this.label,
    required this.url,
    this.height,
  });
}

class YoutubeStreamResult {
  final Uri url;
  final List<YoutubeStreamQuality> qualities;

  YoutubeStreamResult({
    required this.url,
    required this.qualities,
  });
}

/// Best-effort YouTube stream resolver (no official UI / iframe).
///
/// Notes:
/// - YouTube stream URLs can expire; callers should re-resolve on failures.
/// - Signature/cipher changes are handled by `youtube_explode_dart` updates;
///   we handle runtime failures gracefully and provide fallback selection.
class YoutubeStreamResolver {
  YoutubeStreamResolver._();
  static final instance = YoutubeStreamResolver._();

  final YoutubeExplode _yt = YoutubeExplode();

  Future<YoutubeStreamResult> resolve(
    String youtubeUrl, {
    int? preferredHeight,
  }) async {
    final video = await _yt.videos.get(youtubeUrl);
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);

    // Prefer muxed MP4 (video+audio) for simplest playback.
    final muxed = manifest.muxed
        .where((e) => e.container.name.toLowerCase() == 'mp4')
        .toList();

    if (muxed.isEmpty) {
      // Fallback to any muxed if MP4 isn't available.
      final anyMuxed = manifest.muxed.toList();
      if (anyMuxed.isEmpty) {
        throw StateError('No playable YouTube streams found');
      }
      final best = anyMuxed.withHighestBitrate();
      return YoutubeStreamResult(
        url: best.url,
        qualities: _toQualities(anyMuxed),
      );
    }

    final qualities = _toQualities(muxed);

    MuxedStreamInfo chosen;
    if (preferredHeight != null) {
      // Choose closest height.
      muxed.sort((a, b) {
        final ah = _heightFromLabel(a.videoQualityLabel) ?? 0;
        final bh = _heightFromLabel(b.videoQualityLabel) ?? 0;
        return (ah - preferredHeight)
            .abs()
            .compareTo((bh - preferredHeight).abs());
      });
      chosen = muxed.first;
    } else {
      chosen = muxed.withHighestBitrate();
    }

    return YoutubeStreamResult(
      url: chosen.url,
      qualities: qualities,
    );
  }

  List<YoutubeStreamQuality> _toQualities(List<MuxedStreamInfo> muxed) {
    // Deduplicate by height/label, keep highest bitrate for each.
    final byHeight = <int, MuxedStreamInfo>{};
    for (final s in muxed) {
      final h = _heightFromLabel(s.videoQualityLabel) ?? 0;
      final existing = byHeight[h];
      if (existing == null ||
          s.bitrate.bitsPerSecond > existing.bitrate.bitsPerSecond) {
        byHeight[h] = s;
      }
    }
    final list = byHeight.entries.map((e) {
      final height =
          e.key == 0 ? _heightFromLabel(e.value.videoQualityLabel) : e.key;
      final label = height != null && height > 0
          ? '${height}p'
          : e.value.videoQualityLabel;
      return YoutubeStreamQuality(
        label: label,
        height: height,
        url: e.value.url,
      );
    }).toList()
      ..sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
    return list;
  }

  int? _heightFromLabel(String label) {
    final m = RegExp(r'(\d{3,4})').firstMatch(label);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  Future<void> dispose() async {
    _yt.close();
  }
}
