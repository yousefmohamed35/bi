import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pod_player/pod_player.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/design/app_colors.dart';
import '../../core/localization/localization_helper.dart';
import '../../services/courses_service.dart';
import '../../services/token_storage_service.dart';
import '../../services/video_download_service.dart';
import '../../services/youtube_video_service.dart';
import '../../widgets/secure_video_player/dynamic_watermark_overlay.dart';

/// Lesson Viewer Screen - Modern & Eye-Friendly Design
class LessonViewerScreen extends StatefulWidget {
  final Map<String, dynamic>? lesson;
  final String? courseId;

  const LessonViewerScreen({super.key, this.lesson, this.courseId});

  @override
  State<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends State<LessonViewerScreen> {
  static const List<String> _supportedVideoQualities = <String>[
    'auto',
    '1080p',
    '720p',
    '480p',
    '360p',
  ];

  PodPlayerController? _controller;
  WebViewController? _webViewController;
  bool _isVideoLoading = true;
  bool _useWebViewFallback = false;
  Map<String, dynamic>? _lessonContent;
  File? _tempVideoFile;
  final VideoDownloadService _downloadService = VideoDownloadService();
  bool _isDownloading = false;
  int _downloadProgress = 0;
  bool _isDownloaded = false;
  bool _isFileLessonWithoutVideo = false;
  bool _isRecordLesson = false;
  bool _isRecordPlayerLoading = false;
  VideoPlayerController? _recordPlayerController;
  StreamSubscription<DownloadTrackingState>? _downloadTrackingSubscription;
  DynamicWatermarkData _videoWatermark = DynamicWatermarkData.fallback;
  OverlayEntry? _fullscreenWatermarkEntry;
  OverlayEntry? _fullscreenSeekEntry;
  Timer? _fullscreenWatermarkMonitor;

  @override
  void initState() {
    super.initState();
    _loadVideoWatermark();
    _startFullscreenWatermarkMonitor();
    _initializeDownloadService();
    _loadLessonContent().then((_) {
      // Initialize video after content is loaded (or failed)
      // This ensures we can use video data from the API response
      _initializeVideo();
      _checkIfDownloaded();
    });
  }

  Future<void> _loadVideoWatermark() async {
    final user = await TokenStorageService.instance.getUserData();
    if (!mounted) return;
    setState(() {
      _videoWatermark = DynamicWatermarkData.fromCachedUser(user);
    });
  }

  void _startFullscreenWatermarkMonitor() {
    _fullscreenWatermarkMonitor?.cancel();
    _fullscreenWatermarkMonitor = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (!mounted) return;
        final isFullscreen = _controller?.isFullScreen ?? false;
        if (isFullscreen) {
          _showFullscreenWatermark();
          _showFullscreenSeekOverlay();
        } else {
          _hideFullscreenWatermark();
          _hideFullscreenSeekOverlay();
        }
      },
    );
  }

  void _showFullscreenWatermark() {
    if (_fullscreenWatermarkEntry != null || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _fullscreenWatermarkEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: DynamicWatermarkOverlay(data: _videoWatermark),
        ),
      ),
    );
    overlay.insert(_fullscreenWatermarkEntry!);
  }

  void _hideFullscreenWatermark() {
    _fullscreenWatermarkEntry?.remove();
    _fullscreenWatermarkEntry = null;
  }

  void _showFullscreenSeekOverlay() {
    if (_fullscreenSeekEntry != null || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _fullscreenSeekEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTapDown: _handlePodDoubleTap,
        ),
      ),
    );
    overlay.insert(_fullscreenSeekEntry!);
  }

  void _hideFullscreenSeekOverlay() {
    _fullscreenSeekEntry?.remove();
    _fullscreenSeekEntry = null;
  }

  Future<void> _initializeDownloadService() async {
    await _downloadService.initialize();
    _syncTrackedDownloadState();
    _subscribeToTrackedDownload();
  }

  String? _currentLessonId() {
    final lesson = widget.lesson;
    if (lesson == null) return null;
    final lessonId = lesson['id']?.toString();
    if (lessonId == null || lessonId.isEmpty) return null;
    return lessonId;
  }

  void _syncTrackedDownloadState() {
    final lessonId = _currentLessonId();
    if (lessonId == null) return;

    final trackedState = _downloadService.getTrackedDownloadState(lessonId);
    if (trackedState == null) return;

    if (!mounted) return;
    setState(() {
      _isDownloading = trackedState.status == DownloadTrackingStatus.inProgress;
      _downloadProgress = trackedState.progress;
    });
  }

  void _subscribeToTrackedDownload() {
    final lessonId = _currentLessonId();
    if (lessonId == null) return;

    _downloadTrackingSubscription?.cancel();
    _downloadTrackingSubscription =
        _downloadService.watchTrackedDownload(lessonId).listen((state) {
      if (!mounted) return;

      setState(() {
        _downloadProgress = state.progress;
        _isDownloading = state.status == DownloadTrackingStatus.inProgress;
        if (state.status == DownloadTrackingStatus.completed) {
          _isDownloaded = true;
        }
      });
    });
  }

  Future<void> _checkIfDownloaded() async {
    final lesson = widget.lesson;
    if (lesson == null) return;

    final lessonId = lesson['id']?.toString();
    if (lessonId == null || lessonId.isEmpty) return;

    final isDownloaded = await _downloadService.isVideoDownloaded(lessonId);
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
      });
    }
  }

  Future<void> _seekPodBySeconds(int seconds) async {
    final controller = _controller;
    if (controller == null) return;

    final current = controller.currentVideoPosition;
    final duration = controller.totalVideoLength;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);

    await controller.videoSeekTo(clamped);
  }

  void _handlePodDoubleTap(TapDownDetails details) {
    final width = MediaQueryData.fromView(View.of(context)).size.width;
    final isLeftSide = details.globalPosition.dx < (width / 2);
    _seekPodBySeconds(isLeftSide ? -10 : 10);
  }

  Future<void> _loadLessonContent() async {
    final lesson = widget.lesson;
    if (lesson == null) return;

    // Get courseId from widget or extract from lesson
    String? courseId = widget.courseId;
    if (courseId == null || courseId.isEmpty) {
      courseId =
          lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    }

    final lessonId = lesson['id']?.toString();

    if (courseId == null ||
        courseId.isEmpty ||
        lessonId == null ||
        lessonId.isEmpty) {
      return;
    }

    try {
      final content = await CoursesService.instance.getLessonContent(
        courseId,
        lessonId,
      );

      if (mounted) {
        setState(() {
          _lessonContent = content;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading lesson content: $e');
      }
    }
  }

  /// Clean and normalize video URL
  String? _cleanVideoUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Remove any blob: prefix if present at the start
    url = url.replaceFirst(RegExp(r'^blob:'), '').trim();

    // Fix URLs that have blob: in the middle (like "https://domain.com/blob:https://...")
    if (url.contains('blob:')) {
      final blobIndex = url.indexOf('blob:');
      if (blobIndex != -1) {
        final afterBlob =
            url.substring(blobIndex + 5).trim(); // 5 is length of "blob:"
        // If the part after blob: starts with http/https, use it directly
        if (afterBlob.startsWith('http://') ||
            afterBlob.startsWith('https://')) {
          url = afterBlob;
        } else {
          // Otherwise, remove the blob: part and keep everything before and after
          url = url.substring(0, blobIndex).trim() + afterBlob;
        }
      }
    }

    // Ensure URL is valid
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (kDebugMode) {
        print('⚠️ Invalid video URL format: $url');
      }
      return null;
    }

    return url.trim();
  }

  String? _normalizeQualityKey(String? quality) {
    final value = quality?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return _supportedVideoQualities.contains(value) ? value : null;
  }

  Map<String, String> _extractVideoQualities(dynamic source) {
    final out = <String, String>{};
    if (source is! Map) return out;

    final rawQualities = source['video_qualities'];
    if (rawQualities is! Map) return out;

    rawQualities.forEach((key, value) {
      final quality = _normalizeQualityKey(key?.toString());
      final url = _cleanVideoUrl(value?.toString());
      if (quality != null && url != null && url.isNotEmpty) {
        out[quality] = url;
      }
    });
    return out;
  }

  String? _resolvePreferredVideoUrl(Map<String, dynamic> lesson) {
    final qualityUrls = <String, String>{};
    qualityUrls.addAll(_extractVideoQualities(lesson));
    qualityUrls.addAll(_extractVideoQualities(lesson['video']));

    final options = <String>{};
    final topLevelOptions = lesson['quality_options'];
    if (topLevelOptions is List) {
      for (final option in topLevelOptions) {
        final normalized = _normalizeQualityKey(option?.toString());
        if (normalized != null) options.add(normalized);
      }
    }

    final fallbackVideoUrl = _cleanVideoUrl(lesson['video_url']?.toString()) ??
        _cleanVideoUrl(lesson['video']?['url']?.toString());
    if (fallbackVideoUrl != null && fallbackVideoUrl.isNotEmpty) {
      qualityUrls.putIfAbsent('auto', () => fallbackVideoUrl);
    }

    String? selectedQuality = _normalizeQualityKey(
      lesson['default_quality']?.toString(),
    );
    if (selectedQuality == null) {
      selectedQuality = options.contains('auto') ? 'auto' : null;
    }

    if (selectedQuality != null && qualityUrls[selectedQuality] != null) {
      return qualityUrls[selectedQuality];
    }

    for (final quality in _supportedVideoQualities) {
      if (options.isNotEmpty && !options.contains(quality)) continue;
      final url = qualityUrls[quality];
      if (url != null && url.isNotEmpty) return url;
    }

    for (final quality in _supportedVideoQualities) {
      final url = qualityUrls[quality];
      if (url != null && url.isNotEmpty) return url;
    }

    return fallbackVideoUrl;
  }

  Future<void> _initializeVideo() async {
    final lesson = widget.lesson;
    if (lesson == null) {
      setState(() => _isVideoLoading = false);
      return;
    }

    // Wait for content to load, then use it for video
    // If content is already loaded, use it; otherwise use lesson data
    final mergedLesson = _lessonMapMergedWithContent(lesson, _lessonContent);
    final videoData = mergedLesson['video'];

    // Extract video ID from lesson content or lesson - try all possible fields
    String? videoId;
    String? videoUrl;
    final lessonType = mergedLesson['type']?.toString().toLowerCase();
    final recordUrl = _resolveRecordUrl(mergedLesson);

    // 1. Contract-first quality-aware URL resolution.
    videoUrl = _resolvePreferredVideoUrl(mergedLesson);

    // 2. Try video object with youtube_id from content
    if (videoUrl == null && videoData is Map) {
      videoId = videoData['youtube_id']?.toString();
      videoUrl = _cleanVideoUrl(videoData['url']?.toString());
    }

    // 3. Try video object with youtube_id from lesson
    if (videoUrl == null && lesson['video'] is Map) {
      videoId = lesson['video']?['youtube_id']?.toString();
      videoUrl = _cleanVideoUrl(lesson['video']?['url']?.toString());
    }

    // 4. Try direct youtube_id field
    videoId = videoId ?? lesson['youtube_id']?.toString();

    // 5. Try youtubeVideoId field
    videoId = videoId ?? lesson['youtubeVideoId']?.toString();

    // Never use lesson ID as a YouTube fallback.
    videoId = (videoId ?? '').trim();

    if ((lessonType == 'record' ||
            lessonType == 'audio' ||
            lessonType == 'podcast' ||
            lessonType == 'sound') &&
        recordUrl != null &&
        recordUrl.isNotEmpty) {
      await _initializeRecord(recordUrl);
      return;
    }

    if (videoUrl == null &&
        videoId.isEmpty &&
        (lessonType == 'file' ||
            lessonType == 'pdf' ||
            lessonType == 'material')) {
      if (kDebugMode) {
        print(
            '📄 File lesson without video source. Skipping video initialization.');
      }
      if (mounted) {
        setState(() {
          _isFileLessonWithoutVideo = true;
          _isRecordLesson = false;
          _isVideoLoading = false;
        });
      }
      return;
    }

    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('🎥 INITIALIZING VIDEO IN LESSON VIEWER');
      print('═══════════════════════════════════════════════════════════');
      print('Video ID: $videoId');
      print('Video URL (cleaned): $videoUrl');
      print('Record URL: $recordUrl');
      print('Lesson ID: ${lesson['id']}');
      print('Lesson Title: ${lesson['title']}');
      print('Video Object: $videoData');
      print('Raw video_url: ${lesson['video_url']}');
      print('All Lesson Keys: ${lesson.keys.toList()}');
      print('═══════════════════════════════════════════════════════════');
    }

    try {
      // Use video URL if available, otherwise use YouTube ID
      if (videoUrl != null && videoUrl.isNotEmpty) {
        // Check if it's a YouTube URL
        if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
          if (kDebugMode) {
            print('📺 Using YouTube URL: $videoUrl');
          }
          _controller = PodPlayerController(
            playVideoFrom: PlayVideoFrom.youtube(videoUrl),
            podPlayerConfig: const PodPlayerConfig(
              autoPlay: false,
              isLooping: false,
            ),
          )..initialise().then((_) {
              if (mounted) {
                setState(() => _isVideoLoading = false);
              }
            }).catchError((error) {
              if (kDebugMode) {
                print('❌ Error initializing YouTube video: $error');
              }
              if (mounted) {
                setState(() => _isVideoLoading = false);
              }
            });
        } else {
          // Direct video URL from server - use pod_player with network
          if (kDebugMode) {
            print('📹 Using pod_player for direct video URL: $videoUrl');
          }
          _initializeDirectVideo(videoUrl);
        }
      } else if (videoId.isNotEmpty) {
        // Fallback to YouTube ID
        if (kDebugMode) {
          print('📺 Using YouTube ID fallback: $videoId');
        }
        final youtubeUrl = 'https://www.youtube.com/watch?v=$videoId';
        _controller = PodPlayerController(
          playVideoFrom: PlayVideoFrom.youtube(youtubeUrl),
          podPlayerConfig: const PodPlayerConfig(
            autoPlay: false,
            isLooping: false,
          ),
        )..initialise().then((_) {
            if (mounted) {
              setState(() => _isVideoLoading = false);
            }
          }).catchError((error) {
            if (kDebugMode) {
              print('❌ Error initializing YouTube video by ID: $error');
            }
            if (mounted) {
              setState(() => _isVideoLoading = false);
            }
          });
      } else {
        // No valid video source
        if (kDebugMode) {
          print('⚠️ No valid video source found');
        }
        if (mounted) {
          setState(() {
            _isRecordLesson = false;
            _isVideoLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing video: $e');
      }
      if (mounted) {
        setState(() {
          _isRecordLesson = false;
          _isVideoLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _lessonMapMergedWithContent(
    Map<String, dynamic> lesson,
    Map<String, dynamic>? content,
  ) {
    if (content == null || content.isEmpty) return lesson;
    final out = Map<String, dynamic>.from(lesson);
    content.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out;
  }

  String? _resolveRecordUrl(Map<String, dynamic> lesson) {
    for (final key in const [
      'audio_url',
      'record_url',
      'sound_url',
      'audio',
      'recording_url',
      'voice_url',
      'media_url',
      'file',
      'file_url',
      'url',
    ]) {
      final value = lesson[key];
      if (value == null) continue;
      if (value is String) {
        final cleaned = _cleanVideoUrl(value);
        if (cleaned != null && cleaned.isNotEmpty) return cleaned;
      } else if (value is Map) {
        final cleaned = _cleanVideoUrl(value['url']?.toString());
        if (cleaned != null && cleaned.isNotEmpty) return cleaned;
      }
    }
    return null;
  }

  Future<void> _initializeRecord(String recordUrl) async {
    _recordPlayerController?.dispose();
    _recordPlayerController = null;

    if (mounted) {
      setState(() {
        _isRecordLesson = true;
        _isRecordPlayerLoading = true;
        _isFileLessonWithoutVideo = false;
      });
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(recordUrl));
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _recordPlayerController = controller;
        _isRecordPlayerLoading = false;
        _isVideoLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing record player: $e');
      }
      if (!mounted) return;
      setState(() {
        _recordPlayerController = null;
        _isRecordPlayerLoading = false;
        _isVideoLoading = false;
      });
    }
  }

  String _formatDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  /// Initialize direct video playback using pod_player
  Future<void> _initializeDirectVideo(String videoUrl) async {
    try {
      if (kDebugMode) {
        print('📹 Initializing direct video with pod_player: $videoUrl');
      }

      // Get authorization token for video access
      final token = await TokenStorageService.instance.getAccessToken();

      // Add token as query parameter if available
      String videoUrlWithToken = videoUrl;
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse(videoUrl);
        videoUrlWithToken = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'token': token,
        }).toString();

        if (kDebugMode) {
          print('🔑 Added token to video URL');
        }
      }

      // Use pod_player with PlayVideoFrom.network()
      _controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(videoUrlWithToken),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: false,
          isLooping: false,
        ),
      )..initialise().then((_) {
          if (mounted) {
            setState(() {
              _isVideoLoading = false;
              _useWebViewFallback = false;
            });
          }
          if (kDebugMode) {
            print('✅ Direct video initialized successfully with pod_player');
          }
        }).catchError((error) {
          if (kDebugMode) {
            print('❌ Error initializing direct video with pod_player: $error');
            print('   Falling back to WebView...');
          }
          // Fallback to WebView if pod_player fails
          if (mounted) {
            _initializeWebView(videoUrl);
          }
        });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _initializeDirectVideo: $e');
        print('   Falling back to WebView...');
      }
      // Fallback to WebView if there's an error
      if (mounted) {
        _initializeWebView(videoUrl);
      }
    }
  }

  /// Initialize WebView for direct video playback (fallback method)
  Future<void> _initializeWebView(String videoUrl) async {
    try {
      if (kDebugMode) {
        print('🌐 Initializing WebView for video playback: $videoUrl');
      }

      // Get authorization token for video access
      final token = await TokenStorageService.instance.getAccessToken();

      setState(() {
        _useWebViewFallback = true;
      });

      // Try to load video via Flutter HTTP request first (to bypass CORS)
      // Then pass it to WebView as blob URL
      try {
        if (kDebugMode) {
          print('📥 Loading video via Flutter HTTP request...');
        }

        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        // Load video and save to temporary file
        final response = await http
            .get(
              Uri.parse(videoUrl),
              headers: headers,
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          if (kDebugMode) {
            print(
                '✅ Video loaded successfully via HTTP (${response.bodyBytes.length} bytes)');
          }

          // Save to temporary file
          final tempDir = await getTemporaryDirectory();
          final fileName = videoUrl.split('/').last.split('?').first;
          final fileExtension = fileName.split('.').last;
          final tempFile = File(
              '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');

          await tempFile.writeAsBytes(response.bodyBytes);

          if (kDebugMode) {
            print('💾 Video saved to temporary file: ${tempFile.path}');
          }

          // Use file:// URL for WebView
          final fileUrl = tempFile.path;
          _createWebViewWithFileUrl(fileUrl);

          // Store reference to temp file for cleanup
          setState(() {
            _tempVideoFile = tempFile;
          });

          return;
        } else {
          if (kDebugMode) {
            print('❌ HTTP request failed with status: ${response.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to load video via HTTP: $e');
          print('   Falling back to direct WebView method...');
        }
      }

      // Fallback: Try direct WebView method

      _createWebViewWithDirectUrl(videoUrl, token);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing WebView: $e');
      }
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  /// Create WebView with file URL (from temporary file)
  void _createWebViewWithFileUrl(String filePath) {
    // Convert file path to file:// URL
    final fileUrl =
        Platform.isAndroid ? 'file://$filePath' : 'file://$filePath';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000;
      overflow: hidden;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      background-color: #000;
    }
  </style>
</head>
<body>
  <video id="videoPlayer" controls autoplay playsinline webkit-playsinline>
    <source src="$fileUrl" type="video/mp4">
    Your browser does not support the video tag.
  </video>
  <script>
    var video = document.getElementById('videoPlayer');
    video.addEventListener('loadeddata', function() {
      console.log('Video loaded successfully from file URL');
    });
    video.addEventListener('error', function(e) {
      console.error('Video error:', e);
      var error = video.error;
      if (error) {
        console.error('Error code:', error.code, 'Message:', error.message);
      }
    });
  </script>
</body>
</html>
''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (kDebugMode) {
              print('✅ WebView page finished: $url');
            }
            if (mounted) {
              setState(() {
                _isVideoLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('❌ WebView resource error: ${error.description}');
            }
            if (mounted) {
              setState(() {
                _isVideoLoading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
      });
    }
  }

  /// Create WebView with direct URL (fallback method)
  void _createWebViewWithDirectUrl(String videoUrl, String? token) {
    // Build video URL with token as query parameter (fallback method)
    String videoUrlWithToken = videoUrl;
    if (token != null && token.isNotEmpty) {
      final uri = Uri.parse(videoUrl);
      videoUrlWithToken = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'token': token,
      }).toString();
    }

    // Create HTML5 video player with multiple fallback methods
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      background-color: #000;
      overflow: hidden;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
      background-color: #000;
    }
    .loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-family: Arial, sans-serif;
      text-align: center;
    }
    .error {
      color: #ff6b6b;
    }
  </style>
</head>
<body>
  <div class="loading" id="loading">جاري تحميل الفيديو...</div>
  <video id="videoPlayer" controls autoplay playsinline webkit-playsinline style="display: none;">
    Your browser does not support the video tag.
  </video>
  <script>
    var video = document.getElementById('videoPlayer');
    var loading = document.getElementById('loading');
    var videoUrl = '$videoUrl';
    var videoUrlWithToken = '$videoUrlWithToken';
    ${token != null ? "var token = '$token';" : 'var token = null;'}
    var currentMethod = 0;
    var methods = ['direct', 'no-cors', 'token-param'];
    
    function showVideo() {
      video.style.display = 'block';
      loading.style.display = 'none';
    }
    
    function showError(message) {
      loading.textContent = message;
      loading.className = 'loading error';
    }
    
    // Method 1: Try direct video source first (simplest, may work if server allows)
    function tryDirectVideo() {
      console.log('Trying method 1: Direct video source');
      video.src = videoUrl;
      video.load();
      
      var timeout = setTimeout(function() {
        if (video.readyState === 0) {
          console.log('Direct method failed, trying next method');
          tryNoCorsFetch();
        }
      }, 3000);
      
      video.addEventListener('loadeddata', function() {
        clearTimeout(timeout);
        console.log('Direct method succeeded');
        showVideo();
      }, { once: true });
      
      video.addEventListener('error', function(e) {
        clearTimeout(timeout);
        console.log('Direct method failed:', e);
        tryNoCorsFetch();
      }, { once: true });
    }
    
    // Method 2: Try fetch with no-cors mode
    async function tryNoCorsFetch() {
      console.log('Trying method 2: Fetch with no-cors mode');
      try {
        var response = await fetch(videoUrl, {
          method: 'GET',
          mode: 'no-cors',
          cache: 'default'
        });
        
        // With no-cors, we can't read the response, but we can try to use it
        // Try to create a blob URL anyway
        if (response.type === 'opaque') {
          // Opaque response - try to use video tag with the URL directly
          console.log('Got opaque response, trying direct video');
          video.src = videoUrl;
          video.load();
          
          video.addEventListener('loadeddata', function() {
            console.log('Video loaded after no-cors fetch');
            showVideo();
          }, { once: true });
          
          video.addEventListener('error', function(e) {
            console.log('No-cors method failed:', e);
            tryTokenParam();
          }, { once: true });
        }
      } catch (error) {
        console.log('No-cors fetch failed:', error);
        tryTokenParam();
      }
    }
    
    // Method 3: Try with token as query parameter
    function tryTokenParam() {
      if (!token) {
        showError('لا يمكن تحميل الفيديو');
        return;
      }
      
      console.log('Trying method 3: Token as query parameter');
      video.src = videoUrlWithToken;
      video.load();
      
      video.addEventListener('loadeddata', function() {
        console.log('Token param method succeeded');
        showVideo();
      }, { once: true });
      
      video.addEventListener('error', function(e) {
        console.log('Token param method failed:', e);
        showError('فشل تحميل الفيديو. يرجى التحقق من الاتصال بالإنترنت.');
      }, { once: true });
    }
    
    // Add error handlers
    video.addEventListener('error', function(e) {
      var error = video.error;
      if (error) {
        console.error('Video error code:', error.code, 'Message:', error.message);
        if (error.code === 4) {
          // MEDIA_ELEMENT_ERROR: Format error
          showError('تنسيق الفيديو غير مدعوم');
        } else if (error.code === 3) {
          // MEDIA_ELEMENT_ERROR: Decode error
          showError('خطأ في فك تشفير الفيديو');
        } else if (error.code === 2) {
          // MEDIA_ELEMENT_ERROR: Network error
          showError('خطأ في الاتصال بالشبكة');
        } else {
          showError('خطأ في تحميل الفيديو');
        }
      }
    });
    
    // Start loading
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', tryDirectVideo);
    } else {
      tryDirectVideo();
    }
  </script>
</body>
</html>
''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (kDebugMode) {
              print('🌐 WebView page started: $url');
            }
          },
          onPageFinished: (String url) {
            if (kDebugMode) {
              print('✅ WebView page finished: $url');
            }
            if (mounted) {
              setState(() {
                _isVideoLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('❌ WebView resource error: ${error.description}');
              print('   Error code: ${error.errorCode}');
              print('   Error type: ${error.errorType}');
              print('   Failed URL: ${error.url}');

              // Log specific error types
              if (error.errorCode == -1) {
                print(
                    '   ⚠️ CORS or ORB (Opaque Response Blocking) error detected');
                print(
                    '   💡 This is expected - JavaScript will handle fallback methods');
              }
            }
            // Don't set loading to false immediately - let JavaScript try fallback methods
            // Only set to false if it's a critical error
            if (error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout) {
              if (mounted) {
                setState(() {
                  _isVideoLoading = false;
                });
              }
            }
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _fullscreenWatermarkMonitor?.cancel();
    _hideFullscreenWatermark();
    _hideFullscreenSeekOverlay();
    _downloadTrackingSubscription?.cancel();
    _controller?.dispose();
    _recordPlayerController?.dispose();
    // Clean up temporary video file
    if (_tempVideoFile != null) {
      try {
        _tempVideoFile!.deleteSync();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error deleting temp video file: $e');
        }
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final lesson = widget.lesson;
    if (lesson == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                'لا يوجد درس',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Video Player Section
            _buildVideoSection(lesson),

            // Lesson Info Section
            Expanded(
              child: _buildLessonInfo(lesson),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection(Map<String, dynamic> lesson) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson['title'] as String? ?? 'عنوان الدرس',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'المدة: ${lesson['duration'] ?? 'غير محدد'}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Video Player
          SizedBox(
            height: 220,
            child: _isVideoLoading
                ? Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryMap,
                      ),
                    ),
                  )
                : _isFileLessonWithoutVideo
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: Text(
                            context.l10n.lessonIsFile,
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : _isRecordLesson
                        ? Container(
                            color: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _isRecordPlayerLoading || _isVideoLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryMap,
                                    ),
                                  )
                                : _recordPlayerController == null
                                    ? Center(
                                        child: Text(
                                          context.l10n.unableToLoadRecord,
                                          style: GoogleFonts.cairo(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    : AnimatedBuilder(
                                        animation: _recordPlayerController!,
                                        builder: (_, __) {
                                          final c = _recordPlayerController!;
                                          final duration = c.value.duration;
                                          final position =
                                              c.value.position > duration
                                                  ? duration
                                                  : c.value.position;
                                          return Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    onPressed: () {
                                                      if (c.value.isPlaying) {
                                                        c.pause();
                                                      } else {
                                                        c.play();
                                                      }
                                                    },
                                                    icon: Icon(
                                                      c.value.isPlaying
                                                          ? Icons.pause_circle
                                                          : Icons.play_circle,
                                                      color:
                                                          AppColors.primaryMap,
                                                      size: 44,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Slider(
                                                value: duration
                                                            .inMilliseconds ==
                                                        0
                                                    ? 0
                                                    : position.inMilliseconds
                                                        .clamp(
                                                          0,
                                                          duration
                                                              .inMilliseconds,
                                                        )
                                                        .toDouble(),
                                                min: 0,
                                                max: duration.inMilliseconds ==
                                                        0
                                                    ? 1
                                                    : duration.inMilliseconds
                                                        .toDouble(),
                                                onChanged: (value) {
                                                  c.seekTo(
                                                    Duration(
                                                      milliseconds:
                                                          value.toInt(),
                                                    ),
                                                  );
                                                },
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    _formatDuration(position),
                                                    style: GoogleFonts.cairo(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatDuration(duration),
                                                    style: GoogleFonts.cairo(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                          )
                        : _controller != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  PodVideoPlayer(
                                    controller: _controller!,
                                    videoAspectRatio: 16 / 9,
                                    podProgressBarConfig:
                                        const PodProgressBarConfig(
                                      playingBarColor: AppColors.primaryMap,
                                      circleHandlerColor: AppColors.primaryMap,
                                      bufferedBarColor: Colors.white30,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: DynamicWatermarkOverlay(
                                      data: _videoWatermark,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onDoubleTapDown: _handlePodDoubleTap,
                                    ),
                                  ),
                                ],
                              )
                            : _useWebViewFallback && _webViewController != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      WebViewWidget(
                                          controller: _webViewController!),
                                      Positioned.fill(
                                        child: DynamicWatermarkOverlay(
                                          data: _videoWatermark,
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.white54, size: 48),
                                          const SizedBox(height: 12),
                                          Text(
                                            'لا يمكن تحميل الفيديو',
                                            style: GoogleFonts.cairo(
                                              color: Colors.white54,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonInfo(Map<String, dynamic> lesson) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Lesson Title & Stats
            Text(
              lesson['title'] as String? ?? 'عنوان الدرس',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Stats Row
            Row(
              children: [
                _buildStatBadge(
                    Icons.access_time_rounded, lesson['duration'] ?? '0'),
                // const SizedBox(width: 12),
                // _buildStatBadge(Icons.visibility_rounded, '0 مشاهدة'),
                // const SizedBox(width: 12),
                // _buildStatBadge(Icons.thumb_up_rounded, '0%'),
              ],
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 20),

            // Download Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMap.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.download_rounded,
                            color: AppColors.primaryMap, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'تحميل للعرض بدون إنترنت',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isDownloading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: _downloadProgress / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryMap,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'جاري التحميل: $_downloadProgress%',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _cancelDownload,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(
                            'إيقاف التحميل',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    )
                  else if (_isDownloaded)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'تم تحميل الفيديو',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _handleDownload,
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: Text(
                        'تحميل للعرض بدون إنترنت',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 24),

            // Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: _buildNavButton(
                    'الدرس السابق',
                    Icons.arrow_forward_rounded,
                    false,
                    () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildNavButton(
                    'الدرس التالي',
                    Icons.arrow_back_rounded,
                    true,
                    () => context.pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryMap),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownload() async {
    final lesson = widget.lesson;
    if (lesson == null) return;

    final lessonId = lesson['id']?.toString();
    final courseId = widget.courseId ?? lesson['course_id']?.toString();
    final title = context.localizedApiText(lesson, 'title',
        fallback: context.l10n.lesson);
    final description = context.localizedApiText(lesson, 'description');

    if (lessonId == null || courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن تحميل هذا الفيديو',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // التحميل يُحفظ داخل مجلد التطبيق فقط — لا حاجة لصلاحية التخزين المشترك (Android 13+).

    // Use the same contract-first quality selection logic used in playback.
    final mergedLesson = _lessonMapMergedWithContent(lesson, _lessonContent);
    final videoUrl = _resolvePreferredVideoUrl(mergedLesson);

    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يوجد رابط فيديو للتحميل',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cancelToken = CancelToken();
    _downloadService.startTrackingDownload(
      lessonId: lessonId,
      onCancel: () async {
        cancelToken.cancel('user_cancelled_download');
      },
    );
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
        _isDownloaded = false;
      });
    }

    try {
      // الحصول على عنوان الكورس
      String? courseTitle;
      try {
        final courseDetails =
            await CoursesService.instance.getCourseDetails(courseId);
        courseTitle = context.localizedApiText(courseDetails, 'title');
      } catch (e) {
        print('Error getting course title: $e');
      }
      if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
        // Build fileName with course title for better organization
        final safeCourseTitle = (courseTitle ?? 'course_$courseId')
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .trim();
        final safeLessonTitle =
            title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
        final fileName =
            '${safeCourseTitle}_${safeLessonTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final localPath =
            await YoutubeVideoService.instance.downloadYoutubeVideo(
          videoUrl,
          fileName: fileName,
          cancelToken: cancelToken,
          onProgress: (progress) {
            _downloadService.updateTrackedDownloadProgress(lessonId, progress);
            if (mounted) {
              setState(() => _downloadProgress = progress);
            }
          },
        );

        if (localPath != null) {
          // Save to database so it appears in Downloads screen (like server downloads)
          // title = course title (main display), courseTitle = course for grouping
          final videoId = await _downloadService.saveDownloadedVideoRecord(
            lessonId: lessonId,
            courseId: courseId,
            title: courseTitle ?? title,
            videoUrl: videoUrl,
            localPath: localPath,
            courseTitle: courseTitle ?? 'كورس $courseId',
            description: description.isNotEmpty ? description : title,
            durationText: lesson['duration']?.toString(),
            videoSource: 'youtube',
          );

          if (kDebugMode && videoId != null) {
            log('YouTube video saved to database: $videoId');
          }

          _downloadService.completeTrackedDownload(lessonId);

          if (mounted) {
            setState(() {
              _isDownloading = false;
              _isDownloaded = true;
              _downloadProgress = 0;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم تحميل الفيديو بنجاح',
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          _downloadService.failTrackedDownload(lessonId);
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _downloadProgress = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'فشل تحميل الفيديو',
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      final videoId = await _downloadService.downloadVideoWithManager(
        videoUrl: videoUrl,
        lessonId: lessonId,
        courseId: courseId,
        title: title,
        courseTitle: courseTitle,
        description: description,
        cancelToken: cancelToken,
        onProgress: (progress) {
          _downloadService.updateTrackedDownloadProgress(lessonId, progress);
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      if (videoId != null) {
        _downloadService.completeTrackedDownload(lessonId);
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isDownloaded = true;
            _downloadProgress = 0;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم تحميل الفيديو بنجاح',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _downloadService.failTrackedDownload(lessonId);
        throw Exception('فشل تحميل الفيديو');
      }
    } catch (e) {
      final isCancelled = e is DioException && CancelToken.isCancel(e);
      if (isCancelled) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 0;
          });
        }
        return;
      }

      _downloadService.failTrackedDownload(lessonId);
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تحميل الفيديو: ${e.toString().replaceFirst('Exception: ', '')}',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelDownload() async {
    final lessonId = _currentLessonId();
    if (lessonId == null) return;

    await _downloadService.cancelTrackedDownload(lessonId);

    if (!mounted) return;
    setState(() {
      _isDownloading = false;
      _downloadProgress = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم إيقاف التحميل',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildNavButton(
      String text, IconData icon, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)])
              : null,
          color: isPrimary ? null : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primaryMap.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isPrimary)
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.onSurface),
            if (!isPrimary) const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPrimary
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (isPrimary) const SizedBox(width: 8),
            if (isPrimary) Icon(icon, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
