import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pod_player/pod_player.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/design/app_colors.dart';
import '../../core/localization/localization_helper.dart';
import '../../core/navigation/route_names.dart';
import '../../services/courses_service.dart';
import '../../services/exams_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../services/token_storage_service.dart';
import '../../services/video_download_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/youtube_video_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/secure_video_player/dynamic_watermark_overlay.dart';

/// Modern Course Details Screen with Beautiful UI
class CourseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const CourseDetailsScreen({super.key, this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with TickerProviderStateMixin {
  String get _autoQualityLabel => context.l10n.videoQualityAuto;
  int _selectedLessonIndex = 0;
  bool _isLoading = false;
  bool _isEnrolling = false;
  bool _isEnrolled = false;
  Map<String, dynamic>? _courseData;
  List<Map<String, dynamic>> _courseExams = [];
  bool _isLoadingExams = false;
  bool _isLoadingMaterials = false;
  Map<String, dynamic>? _materialsContent;
  String? _materialsLessonId;
  bool _isInWishlist = false;
  bool _isTogglingWishlist = false;
  bool _isViewingOwnCourse = false;

  // Inline video player
  PodPlayerController? _videoController;
  WebViewController? _webViewController;
  bool _isVideoLoading = false;
  bool _useWebViewFallback = false;
  bool _isFileLessonWithoutVideo = false;
  Map<String, dynamic>? _currentLesson;
  Map<String, dynamic>? _lessonContent;
  File? _tempVideoFile;
  final VideoDownloadService _downloadService = VideoDownloadService();
  bool _isDownloading = false;
  int _downloadProgress = 0;
  bool _isDownloaded = false;
  StreamSubscription<DownloadTrackingState>? _downloadTrackingSubscription;
  bool _isVideoPlaying = false;

  /// 0 = inline video (Pod/WebView), 1 = image gallery, 2 = audio/record
  int _inlinePlayerKind = 0;
  List<String> _inlineImageUrls = [];
  int _inlineImagePageIndex = 0;
  VideoPlayerController? _recordPlayerController;
  bool _recordPlayerLoading = false;
  DynamicWatermarkData _videoWatermark = DynamicWatermarkData.fallback;
  OverlayEntry? _fullscreenWatermarkEntry;
  OverlayEntry? _fullscreenSeekEntry;
  Timer? _fullscreenWatermarkMonitor;
  Map<String, String> _availableVideoQualities = {};
  String? _selectedVideoQualityLabel;
  String? _activeVideoUrl;
  Timer? _lessonProgressMonitor;
  final Set<String> _reportedCompletedLessonIds = <String>{};

  // Reviews / comments
  bool _isLoadingReviews = false;
  List<Map<String, dynamic>> _reviews = [];
  String? _reviewsError;
  int _selectedReviewRating = 5;
  final TextEditingController _reviewTitleController = TextEditingController();
  final TextEditingController _reviewCommentController =
      TextEditingController();
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
    _checkWishlistStatus();
    _initializeDownloadService();
    _loadVideoWatermark();
    _startFullscreenWatermarkMonitor();
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
        final isFullscreen = _videoController?.isFullScreen ?? false;
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

  Future<void> _loadCourseDetails() async {
    // If course data is already provided, use it
    if (widget.course != null && widget.course!['id'] != null) {
      final courseId = widget.course!['id']?.toString();
      if (courseId != null && courseId.isNotEmpty) {
        setState(() => _isLoading = true);
        try {
          final courseDetails =
              await CoursesService.instance.getCourseDetails(courseId);

          // Print detailed response
          if (kDebugMode) {
            print(
                '═══════════════════════════════════════════════════════════');
            print('📋 COURSE DETAILS RESPONSE (getCourseDetails)');
            print(
                '═══════════════════════════════════════════════════════════');
            print('Course ID: $courseId');
            print('Response Type: ${courseDetails.runtimeType}');
            print('Response Keys: ${courseDetails.keys.toList()}');
            print(
                '───────────────────────────────────────────────────────────');
            print('Full Response JSON:');
            try {
              const encoder = JsonEncoder.withIndent('  ');
              print(encoder.convert(courseDetails));
            } catch (e) {
              print('Could not convert to JSON: $e');
              print('Raw Response: $courseDetails');
            }
            print(
                '───────────────────────────────────────────────────────────');
            print('Key Fields:');
            print('  - id: ${courseDetails['id']}');
            print('  - title: ${courseDetails['title']}');
            print('  - price: ${courseDetails['price']}');
            print('  - is_free: ${courseDetails['is_free']}');
            print('  - is_enrolled: ${courseDetails['is_enrolled']}');
            print('  - is_in_wishlist: ${courseDetails['is_in_wishlist']}');
            print('  - rating: ${courseDetails['rating']}');
            print('  - students_count: ${courseDetails['students_count']}');
            print('  - duration_hours: ${courseDetails['duration_hours']}');
            print(
                '  - curriculum length: ${(courseDetails['curriculum'] as List?)?.length ?? 0}');
            print(
                '  - lessons length: ${(courseDetails['lessons'] as List?)?.length ?? 0}');
            print(
                '───────────────────────────────────────────────────────────');
            print('📚 CURRICULUM DETAILS:');
            final curriculum = courseDetails['curriculum'] as List?;
            if (curriculum != null && curriculum.isNotEmpty) {
              print('  Total Items: ${curriculum.length}');

              // First, show summary of all topics
              print('');
              print('📁 ALL TOPICS FROM API:');
              print(
                  '═══════════════════════════════════════════════════════════');
              int topicCount = 0;
              for (int i = 0; i < curriculum.length; i++) {
                final item = curriculum[i];
                if (item is Map) {
                  // Check if this is a topic (has lessons field, even if empty)
                  // A topic is identified by having a 'lessons' field (can be empty list)
                  // OR by not having video/youtube_id fields (which indicate it's a lesson)
                  final nestedLessons = item['lessons'] as List?;
                  final hasVideo = item['video'] != null;
                  final hasYoutubeId = item['youtube_id'] != null ||
                      item['youtubeVideoId'] != null;

                  // It's a topic if:
                  // 1. It has a 'lessons' field (even if empty), OR
                  // 2. It doesn't have video/youtube_id (meaning it's a container, not a lesson)
                  final isTopic =
                      nestedLessons != null || (!hasVideo && !hasYoutubeId);

                  if (isTopic) {
                    topicCount++;
                    final lessonsCount = nestedLessons?.length ?? 0;
                    print('📁 TOPIC $topicCount:');
                    print('  - ID: ${item['id']}');
                    print('  - Title: ${item['title']}');
                    print('  - Order: ${item['order']}');
                    print('  - Type: ${item['type']}');
                    print('  - Lessons Count: $lessonsCount');
                    print('  - Duration Minutes: ${item['duration_minutes']}');
                    print('  - Has Lessons Field: ${nestedLessons != null}');
                    print('  - All Topic Keys: ${item.keys.toList()}');

                    // If it has lessons, show them
                    if (nestedLessons != null && nestedLessons.isNotEmpty) {
                      print('  - Lessons:');
                      for (int j = 0; j < nestedLessons.length; j++) {
                        final lesson = nestedLessons[j];
                        if (lesson is Map) {
                          print(
                              '      Lesson ${j + 1}: ${lesson['title'] ?? lesson['id']}');
                        }
                      }
                    } else if (nestedLessons != null && nestedLessons.isEmpty) {
                      print('  - ⚠️ This topic has an empty lessons array');
                    } else {
                      print('  - ⚠️ This topic does not have a lessons field');
                    }
                    print('');
                  }
                }
              }
              print(
                  '═══════════════════════════════════════════════════════════');
              print('Total Topics Found: $topicCount');
              print('Total Curriculum Items: ${curriculum.length}');
              print(
                  '═══════════════════════════════════════════════════════════');
              print('');

              // Then show all items in detail
              print('📋 ALL CURRICULUM ITEMS (DETAILED):');
              for (int i = 0; i < curriculum.length; i++) {
                final item = curriculum[i];
                if (item is Map) {
                  print(
                      '───────────────────────────────────────────────────────────');
                  print('  Item ${i + 1}:');
                  print('    - id: ${item['id']}');
                  print('    - title: ${item['title']}');
                  print('    - order: ${item['order']}');
                  print('    - type: ${item['type']}');
                  print('    - video: ${item['video']}');
                  print('    - youtube_id: ${item['youtube_id']}');
                  print('    - youtubeVideoId: ${item['youtubeVideoId']}');
                  print('    - duration_minutes: ${item['duration_minutes']}');
                  print('    - is_locked: ${item['is_locked']}');
                  print('    - is_completed: ${item['is_completed']}');
                  if (item['lessons'] != null) {
                    final lessonsList = item['lessons'] as List?;
                    print('    - has lessons: ${lessonsList?.length ?? 0}');
                    if (lessonsList != null && lessonsList.isNotEmpty) {
                      print('    - Lessons in this topic:');
                      for (int j = 0; j < lessonsList.length; j++) {
                        final lesson = lessonsList[j];
                        if (lesson is Map) {
                          print('      Lesson ${j + 1}:');
                          print('        - id: ${lesson['id']}');
                          print('        - title: ${lesson['title']}');
                          print('        - type: ${lesson['type']}');
                        }
                      }
                    }
                  }
                  print('    - All Keys: ${item.keys.toList()}');

                  // Print full JSON for topics
                  final nestedLessons = item['lessons'] as List?;
                  if (nestedLessons != null && nestedLessons.isNotEmpty) {
                    try {
                      const encoder = JsonEncoder.withIndent('    ');
                      print('    - Full Topic JSON:');
                      print(encoder.convert(item));
                    } catch (e) {
                      print('    - Could not convert topic to JSON: $e');
                    }
                  }
                }
              }
            } else {
              print('  Curriculum is empty or null');
            }
            print(
                '───────────────────────────────────────────────────────────');
            print('📖 LESSONS DETAILS:');
            final lessons = courseDetails['lessons'] as List?;
            if (lessons != null && lessons.isNotEmpty) {
              print('  Total Lessons: ${lessons.length}');
              for (int i = 0; i < lessons.length && i < 3; i++) {
                final lesson = lessons[i];
                if (lesson is Map) {
                  print('  Lesson $i:');
                  print('    - id: ${lesson['id']}');
                  print('    - title: ${lesson['title']}');
                  print('    - video: ${lesson['video']}');
                  print('    - All Keys: ${lesson.keys.toList()}');
                }
              }
            } else {
              print('  Lessons is empty or null');
            }
            print(
                '═══════════════════════════════════════════════════════════');
          }

          setState(() {
            _courseData = courseDetails;
            _isEnrolled = courseDetails['is_enrolled'] == true;
            _isInWishlist = courseDetails['is_in_wishlist'] == true;
            _isLoading = false;
          });
          _loadCourseExams();
          _checkWishlistStatus();
          _checkIfViewingOwnCourse(courseDetails);
          _loadMaterialsForCurrentLesson();
          _loadReviews();
        } catch (e) {
          if (kDebugMode) {
            print(
                '═══════════════════════════════════════════════════════════');
            print('❌ ERROR LOADING COURSE DETAILS');
            print(
                '═══════════════════════════════════════════════════════════');
            print('Course ID: $courseId');
            print('Error: $e');
            print('Error Type: ${e.runtimeType}');
            print(
                '═══════════════════════════════════════════════════════════');
          }
          setState(() {
            _courseData = widget.course; // Fallback to provided course
            _isLoading = false;
          });
          _checkIfViewingOwnCourse(widget.course);
        }
      } else {
        setState(() {
          _courseData = widget.course;
        });
        _checkIfViewingOwnCourse(widget.course);
      }
    } else {
      setState(() {
        _courseData = widget.course;
      });
      _checkIfViewingOwnCourse(widget.course);
    }
  }

  Future<void> _checkIfViewingOwnCourse(Map<String, dynamic>? course) async {
    if (course == null) return;
    final instructorId = course['instructor_id']?.toString() ??
        course['instructorId']?.toString() ??
        (course['instructor'] is Map
            ? (course['instructor'] as Map)['id']?.toString()
            : null);
    if (instructorId == null || instructorId.isEmpty) return;
    try {
      final profile = await ProfileService.instance.getProfile();
      final myId = profile['id']?.toString();
      if (myId != null && myId == instructorId && mounted) {
        setState(() => _isViewingOwnCourse = true);
      }
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    final course = _courseData ?? widget.course;
    final courseId = course?['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });

    try {
      final response = await CoursesService.instance.getCourseReviews(courseId);
      final data = response['data'];

      List<Map<String, dynamic>> list = [];
      if (data is List) {
        list = data
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      } else if (data is Map<String, dynamic>) {
        final inner = data['reviews'] ?? data['data'] ?? data['items'];
        if (inner is List) {
          list = inner
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _reviews = list;
        _isLoadingReviews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviews = [];
        _isLoadingReviews = false;
        _reviewsError = context.l10n.errorLoadingReviews;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_isSubmittingReview) return;
    final course = _courseData ?? widget.course;
    final courseId = course?['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    final title = _reviewTitleController.text.trim();
    final comment = _reviewCommentController.text.trim();
    if (title.isEmpty || comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.pleaseEnterReviewTitleAndComment,
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      await CoursesService.instance.addCourseReview(
        courseId,
        rating: _selectedReviewRating,
        title: title,
        comment: comment,
      );

      _reviewTitleController.clear();
      _reviewCommentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.reviewSubmittedSuccessfully,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _loadReviews();
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.contains('401') || message.contains('Unauthorized')
                  ? context.l10n.loginRequired
                  : context.l10n.errorSubmittingReview,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  int _parseReviewRating(Map<String, dynamic> review) {
    final r = review['rating'] ?? review['stars'];
    if (r is int) return r.clamp(1, 5);
    if (r is num) return r.toInt().clamp(1, 5);
    final parsed = int.tryParse(r?.toString() ?? '');
    return (parsed ?? 0).clamp(1, 5);
  }

  Widget _buildStarsPicker() {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: List.generate(5, (i) {
        final v = i + 1;
        final selected = v <= _selectedReviewRating;
        return IconButton(
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: _isSubmittingReview
              ? null
              : () => setState(() => _selectedReviewRating = v),
          icon: Icon(
            selected ? Icons.star_rounded : Icons.star_outline_rounded,
            color: selected ? Colors.amber : Colors.grey[400],
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final name = review['user'] is Map
        ? context.localizedApiText(
            Map<String, dynamic>.from(review['user'] as Map),
            'name',
          )
        : review['user_name']?.toString();
    final title = context.localizedApiText(review, 'title');
    final comment =
        review['comment']?.toString() ?? review['body']?.toString() ?? '';
    final rating = _parseReviewRating(review);
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name?.isNotEmpty == true ? name! : context.l10n.student,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fullscreenWatermarkMonitor?.cancel();
    _stopLessonProgressMonitor();
    _hideFullscreenWatermark();
    _hideFullscreenSeekOverlay();
    _reviewTitleController.dispose();
    _reviewCommentController.dispose();
    _downloadTrackingSubscription?.cancel();
    _videoController?.dispose();
    _recordPlayerController?.dispose();
    if (_tempVideoFile != null) {
      try {
        _tempVideoFile!.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  // ── Video player helpers ──────────────────────────────────────────

  Future<void> _initializeDownloadService() async {
    await _downloadService.initialize();
    _syncTrackedDownloadState();
    _subscribeToTrackedDownload();
  }

  String? _currentLessonId() {
    final lesson = _currentLesson;
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
    final lesson = _currentLesson;
    if (lesson == null) return;
    final lessonId = lesson['id']?.toString();
    if (lessonId == null || lessonId.isEmpty) return;
    final isDownloaded = await _downloadService.isVideoDownloaded(lessonId);
    if (mounted) {
      setState(() => _isDownloaded = isDownloaded);
    }
  }

  Future<void> _seekPodBySeconds(int seconds) async {
    final controller = _videoController;
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

  String? _cleanVideoUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    url = url.replaceFirst(RegExp(r'^blob:'), '').trim();
    if (url.contains('blob:')) {
      final blobIndex = url.indexOf('blob:');
      if (blobIndex != -1) {
        final afterBlob = url.substring(blobIndex + 5).trim();
        if (afterBlob.startsWith('http://') ||
            afterBlob.startsWith('https://')) {
          url = afterBlob;
        } else {
          url = url.substring(0, blobIndex).trim() + afterBlob;
        }
      }
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return url.trim();
  }

  String? _extractBackendVideoId(dynamic videoNode) {
    if (videoNode is! Map) return null;
    final id = videoNode['id']?.toString() ??
        videoNode['video_id']?.toString() ??
        videoNode['videoId']?.toString();
    if (id == null) return null;
    final trimmed = id.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _extractVideoIdFromStreamUrl(String? url) {
    final clean = _cleanVideoUrl(url);
    if (clean == null) return null;

    final uri = Uri.tryParse(clean);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final videosIndex = segments.indexOf('videos');
    if (videosIndex == -1 || videosIndex + 2 >= segments.length) return null;
    if (segments[videosIndex + 2] != 'stream') return null;

    final id = segments[videosIndex + 1].trim();
    return id.isEmpty ? null : id;
  }

  String? _extractVideoIdFromAnyStreamPattern(String? url) {
    final clean = _cleanVideoUrl(url);
    if (clean == null) return null;

    final match = RegExp(r'/videos/([^/]+)/stream(?:$|[/?])').firstMatch(clean);
    if (match == null) return null;

    final id = (match.group(1) ?? '').trim();
    return id.isEmpty ? null : id;
  }

  String? _extractVideoIdFromUploadsUrl(String? url) {
    final clean = _cleanVideoUrl(url);
    if (clean == null) return null;

    // Pattern: /uploads/videos/<id>.<ext>
    final match = RegExp(
      r'/uploads/videos/([^/?]+)\.(mp4|mkv|mov|avi|webm)(?:$|[?#])',
      caseSensitive: false,
    ).firstMatch(clean);
    if (match == null) return null;
    final id = (match.group(1) ?? '').trim();
    return id.isEmpty ? null : id;
  }

  String _buildStreamUrlForQuality(String videoId, String quality) {
    final baseUri = Uri.parse(ApiEndpoints.videoStream(videoId));
    return baseUri.replace(
      queryParameters: <String, String>{
        ...baseUri.queryParameters,
        'quality': quality,
      },
    ).toString();
  }

  Map<String, String> _buildDefaultStreamQualities(String videoId) {
    return <String, String>{
      _autoQualityLabel: _buildStreamUrlForQuality(videoId, 'auto'),
      '1080p': _buildStreamUrlForQuality(videoId, '1080p'),
      '720p': _buildStreamUrlForQuality(videoId, '720p'),
      '480p': _buildStreamUrlForQuality(videoId, '480p'),
      '360p': _buildStreamUrlForQuality(videoId, '360p'),
    };
  }

  static const List<String> _videoQualityOrder = <String>[
    'auto',
    '1080p',
    '720p',
    '480p',
    '360p',
  ];

  String? _normalizeQualityKey(String? quality) {
    final value = quality?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return _videoQualityOrder.contains(value) ? value : null;
  }

  List<String> _extractQualityOptions(Map<String, dynamic> lesson) {
    final out = <String>[];
    final seen = <String>{};

    void collectFrom(dynamic node) {
      if (node is! List) return;
      for (final option in node) {
        final normalized = _normalizeQualityKey(option?.toString());
        if (normalized != null && seen.add(normalized)) {
          out.add(normalized);
        }
      }
    }

    collectFrom(lesson['quality_options']);
    if (lesson['video'] is Map) {
      collectFrom((lesson['video'] as Map)['quality_options']);
    }
    return out;
  }

  String _selectBestQualityLabel({
    required Map<String, String> available,
    required String? defaultQuality,
    required List<String> qualityOptions,
  }) {
    final normalizedDefault = _normalizeQualityKey(defaultQuality);
    if (normalizedDefault != null &&
        available[normalizedDefault] != null &&
        available[normalizedDefault]!.isNotEmpty) {
      return normalizedDefault;
    }

    for (final option in qualityOptions) {
      if (available[option] != null && available[option]!.isNotEmpty) {
        return option;
      }
    }

    for (final quality in _videoQualityOrder) {
      if (available[quality] != null && available[quality]!.isNotEmpty) {
        return quality;
      }
    }

    return available.keys.isNotEmpty ? available.keys.first : _autoQualityLabel;
  }

  Map<String, dynamic> _lessonMapMergedWithContent(
    Map<String, dynamic> lesson,
    Map<String, dynamic>? content,
  ) {
    final out = Map<String, dynamic>.from(lesson);
    if (content == null) return out;
    content.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out;
  }

  List<String> _collectImageUrls(Map<String, dynamic> lesson) {
    final urls = <String>[];
    final seen = <String>{};

    void addRaw(String? raw) {
      final trimmed = raw?.trim();
      if (trimmed == null || trimmed.isEmpty) return;
      final normalized = _normalizeRemoteUrl(trimmed);
      if (seen.add(normalized)) urls.add(normalized);
    }

    for (final key in [
      'image',
      'image_url',
      'content_image',
      'photo',
    ]) {
      addRaw(lesson[key]?.toString());
    }

    for (final listKey in ['images', 'gallery', 'photos']) {
      final list = lesson[listKey];
      if (list is! List) continue;
      for (final item in list) {
        if (item is String) {
          addRaw(item);
        } else if (item is Map) {
          addRaw(item['url']?.toString() ?? item['src']?.toString());
        }
      }
    }

    if (lesson['attachments'] is List) {
      for (final item in lesson['attachments'] as List) {
        if (item is! Map) continue;
        final type = item['type']?.toString().toLowerCase() ?? '';
        if (type.contains('image') ||
            type.contains('photo') ||
            type.contains('gallery')) {
          addRaw(item['url']?.toString());
        }
      }
    }

    return urls;
  }

  String? _resolveRecordUrl(Map<String, dynamic> lesson) {
    return _resolveAssetUrl(lesson, [
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
    ]);
  }

  Future<void> _openImageLessonPage(Map<String, dynamic> lesson) async {
    setState(() {
      _isLoadingMaterials = true;
    });

    Map<String, dynamic>? content;
    final course = _courseData ?? widget.course;
    String? courseId = course?['id']?.toString();
    courseId ??=
        lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    final lessonId = lesson['id']?.toString();

    if (courseId != null &&
        courseId.isNotEmpty &&
        lessonId != null &&
        lessonId.isNotEmpty) {
      try {
        content =
            await CoursesService.instance.getLessonContent(courseId, lessonId);
      } catch (_) {
        content = null;
      }
    }

    final merged = _lessonMapMergedWithContent(lesson, content);
    final urls = _collectImageUrls(merged);

    if (!mounted) return;
    setState(() {
      _isLoadingMaterials = false;
    });

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noImageForLesson)),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageLessonViewerPage(
          title: context.localizedApiText(lesson, 'title',
              fallback: context.l10n.lesson),
          imageUrls: urls,
        ),
      ),
    );

    await _trackLessonProgress(
      lesson: lesson,
      contentType: 'image',
      isCompleted: true,
      completionRatio: 1.0,
    );
  }

  Future<void> _startInlineRecordLesson(Map<String, dynamic> lesson) async {
    _disposeCurrentVideo();
    setState(() {
      _inlinePlayerKind = 2;
      _currentLesson = lesson;
      _isVideoPlaying = true;
      _isVideoLoading = true;
      _recordPlayerLoading = true;
    });

    await _loadLessonContentForVideo();
    final merged = _lessonMapMergedWithContent(lesson, _lessonContent);
    final audioUrl = _resolveRecordUrl(merged);

    if (kDebugMode) {
      print('🎙 RECORD LESSON (inline)');
      print('  lessonId: ${lesson['id']}');
      print('  merged keys: ${merged.keys.toList()}');
      print('  resolved audioUrl: $audioUrl');
    }

    if (!mounted) return;
    if (audioUrl == null || audioUrl.isEmpty) {
      setState(() {
        _isVideoLoading = false;
        _recordPlayerLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noRecordForLesson)),
      );
      _stopPlaying();
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(audioUrl));
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _recordPlayerController = controller;
        _recordPlayerLoading = false;
        _isVideoLoading = false;
      });
      _startLessonProgressMonitor();
    } catch (e) {
      if (kDebugMode) print('🎙 Record init error: $e');
      if (!mounted) return;
      setState(() {
        _recordPlayerLoading = false;
        _isVideoLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToLoadRecord)),
      );
      _stopPlaying();
    }
  }

  Future<void> _loadLessonContentForVideo() async {
    final lesson = _currentLesson;
    if (lesson == null) return;

    final course = _courseData ?? widget.course;
    String? courseId = course?['id']?.toString();
    if (courseId == null || courseId.isEmpty) {
      courseId =
          lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    }
    final lessonId = lesson['id']?.toString();
    if (courseId == null ||
        courseId.isEmpty ||
        lessonId == null ||
        lessonId.isEmpty) return;

    try {
      final content =
          await CoursesService.instance.getLessonContent(courseId, lessonId);
      if (mounted) {
        setState(() => _lessonContent = content);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading lesson content: $e');
    }
  }

  Future<void> _initializeVideoForLesson() async {
    final lesson = _currentLesson;
    if (lesson == null) {
      if (kDebugMode) print('🎬 _initializeVideoForLesson: lesson is null');
      setState(() => _isVideoLoading = false);
      return;
    }

    final mergedLesson = _lessonMapMergedWithContent(lesson, _lessonContent);
    final videoData = mergedLesson['video'];
    String? youtubeVideoId;
    String? backendVideoId;
    String? videoUrl;
    final lessonType = mergedLesson['type']?.toString().toLowerCase();

    if (kDebugMode) {
      print('🎬 ═══════════════════════════════════════════════════');
      print('🎬 INITIALIZING VIDEO FOR LESSON');
      print('🎬 Lesson ID: ${mergedLesson['id']}');
      print('🎬 Lesson Title: ${mergedLesson['title']}');
      print('🎬 Lesson Type: $lessonType');
      print('🎬 lesson[video_url]: ${mergedLesson['video_url']}');
      print(
          '🎬 lesson[video]: ${mergedLesson['video']?.runtimeType} = ${mergedLesson['video']}');
      print(
          '🎬 _lessonContent[video]: ${_lessonContent?['video']?.runtimeType} = ${_lessonContent?['video']}');
      print('🎬 videoData: ${videoData?.runtimeType} = $videoData');
    }

    videoUrl = _cleanVideoUrl(mergedLesson['video_url']?.toString());

    if (videoData is Map) {
      youtubeVideoId = videoData['youtube_id']?.toString();
      backendVideoId ??= _extractBackendVideoId(videoData);
      videoUrl ??= _cleanVideoUrl(videoData['url']?.toString());
    }

    youtubeVideoId = youtubeVideoId ?? mergedLesson['youtube_id']?.toString();
    youtubeVideoId =
        youtubeVideoId ?? mergedLesson['youtubeVideoId']?.toString();
    youtubeVideoId = (youtubeVideoId ?? '').trim();
    backendVideoId ??= _extractBackendVideoId(mergedLesson['video']);
    backendVideoId ??= mergedLesson['video_id']?.toString();
    backendVideoId ??= mergedLesson['videoId']?.toString();
    backendVideoId ??= _extractVideoIdFromStreamUrl(videoUrl);
    backendVideoId ??= _extractVideoIdFromAnyStreamPattern(videoUrl);
    backendVideoId ??= _extractVideoIdFromUploadsUrl(videoUrl);
    backendVideoId ??= _extractVideoIdFromAnyStreamPattern(
        mergedLesson['video_url']?.toString());
    backendVideoId ??= _extractVideoIdFromAnyStreamPattern(
      mergedLesson['video'] is Map
          ? (mergedLesson['video'] as Map)['url']?.toString()
          : null,
    );
    backendVideoId ??= _extractVideoIdFromUploadsUrl(
      mergedLesson['video'] is Map
          ? (mergedLesson['video'] as Map)['url']?.toString()
          : null,
    );
    backendVideoId ??= _extractVideoIdFromAnyStreamPattern(
      _lessonContent?['video'] is Map
          ? (_lessonContent?['video'] as Map)['url']?.toString()
          : null,
    );
    backendVideoId ??= _extractVideoIdFromUploadsUrl(
      _lessonContent?['video'] is Map
          ? (_lessonContent?['video'] as Map)['url']?.toString()
          : null,
    );
    backendVideoId = (backendVideoId ?? '').trim();

    if ((videoUrl == null || videoUrl.isEmpty) && backendVideoId.isNotEmpty) {
      videoUrl = _buildStreamUrlForQuality(backendVideoId, 'auto');
    }

    if (kDebugMode) {
      print('🎬 Resolved videoUrl: $videoUrl');
      print('🎬 Resolved backendVideoId: $backendVideoId');
      print('🎬 Resolved youtubeVideoId: $youtubeVideoId');
    }

    if (videoUrl != null && videoUrl.isNotEmpty) {
      final extractedQualities = backendVideoId.isNotEmpty
          ? _buildDefaultStreamQualities(backendVideoId)
          : <String, String>{};
      extractedQualities
          .addAll(_extractVideoQualities(_lessonContent?['video']));
      extractedQualities.addAll(_extractVideoQualities(_lessonContent));
      extractedQualities.addAll(_extractVideoQualities(mergedLesson));
      extractedQualities.addAll(_extractVideoQualities(lesson['video']));
      extractedQualities.addAll(_extractVideoQualities(videoData));
      extractedQualities.putIfAbsent(_autoQualityLabel, () => videoUrl!);
      _availableVideoQualities = extractedQualities;
      _activeVideoUrl = videoUrl;
      final qualityOptions = _extractQualityOptions(mergedLesson);
      final defaultQuality = mergedLesson['default_quality']?.toString() ??
          (mergedLesson['video'] is Map
              ? (mergedLesson['video'] as Map)['default_quality']?.toString()
              : null);
      _selectedVideoQualityLabel = _selectedVideoQualityLabel != null &&
              extractedQualities.containsKey(_selectedVideoQualityLabel)
          ? _selectedVideoQualityLabel
          : _selectBestQualityLabel(
              available: extractedQualities,
              defaultQuality: defaultQuality,
              qualityOptions: qualityOptions,
            );
      if (kDebugMode) {
        print(
            '🎬 Available qualities (${extractedQualities.length}): ${extractedQualities.keys.toList()}');
      }
    } else {
      _availableVideoQualities = {};
      _selectedVideoQualityLabel = null;
      _activeVideoUrl = null;
    }

    if (videoUrl == null &&
        youtubeVideoId.isEmpty &&
        backendVideoId.isEmpty &&
        (lessonType == 'file' ||
            lessonType == 'pdf' ||
            lessonType == 'material')) {
      if (kDebugMode) print('🎬 File lesson without video, skipping');
      if (mounted) {
        setState(() {
          _isFileLessonWithoutVideo = true;
          _isVideoLoading = false;
        });
      }
      return;
    }

    try {
      if (videoUrl != null && videoUrl.isNotEmpty) {
        if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
          if (kDebugMode) print('🎬 Playing YouTube video: $videoUrl');
          _videoController = PodPlayerController(
            playVideoFrom: PlayVideoFrom.youtube(videoUrl),
            podPlayerConfig: const PodPlayerConfig(
              autoPlay: true,
              isLooping: false,
            ),
          )..initialise().then((_) {
              if (kDebugMode) print('🎬 YouTube player initialized');
              if (mounted) setState(() => _isVideoLoading = false);
            }).catchError((error) {
              if (kDebugMode) print('🎬 YouTube player error: $error');
              if (mounted) setState(() => _isVideoLoading = false);
            });
        } else {
          if (kDebugMode) print('🎬 Playing direct video: $videoUrl');
          await _initializeDirectVideo(
            videoUrl,
            qualityLabel: _selectedVideoQualityLabel ?? _autoQualityLabel,
          );
        }
      } else if (youtubeVideoId.isNotEmpty) {
        final youtubeUrl = 'https://www.youtube.com/watch?v=$youtubeVideoId';
        if (kDebugMode) print('🎬 Playing YouTube by ID: $youtubeUrl');
        _videoController = PodPlayerController(
          playVideoFrom: PlayVideoFrom.youtube(youtubeUrl),
          podPlayerConfig: const PodPlayerConfig(
            autoPlay: true,
            isLooping: false,
          ),
        )..initialise().then((_) {
            if (kDebugMode) print('🎬 YouTube (by ID) initialized');
            if (mounted) setState(() => _isVideoLoading = false);
          }).catchError((error) {
            if (kDebugMode) print('🎬 YouTube (by ID) error: $error');
            if (mounted) setState(() => _isVideoLoading = false);
          });
      } else {
        if (kDebugMode) print('🎬 No video URL or ID found');
        if (mounted) setState(() => _isVideoLoading = false);
      }
    } catch (e) {
      if (kDebugMode) print('🎬 _initializeVideoForLesson exception: $e');
      if (mounted) setState(() => _isVideoLoading = false);
    }
  }

  Future<void> _logVideoQualityRequestResponse({
    required String qualityLabel,
    required String videoUrl,
    required Map<String, String> headers,
  }) async {
    if (!kDebugMode) return;
    try {
      print('🎬════════ VIDEO QUALITY REQUEST ════════');
      print('🎬 Quality: $qualityLabel');
      print('🎬 URL: $videoUrl');
      print('🎬 Authorization header: ${headers.containsKey('Authorization')}');
      print('🎬 Headers: $headers');

      final response = await http.get(
        Uri.parse(videoUrl),
        headers: <String, String>{
          ...headers,
          'Range': 'bytes=0-1',
        },
      ).timeout(const Duration(seconds: 15));

      print('🎬════════ VIDEO QUALITY RESPONSE ════════');
      print('🎬 Status: ${response.statusCode}');
      print('🎬 Content-Type: ${response.headers['content-type']}');
      print('🎬 Content-Range: ${response.headers['content-range']}');
      print('🎬 Accept-Ranges: ${response.headers['accept-ranges']}');
      print('🎬 Cache-Control: ${response.headers['cache-control']}');
      print('🎬 Response bytes length: ${response.bodyBytes.length}');
    } catch (e) {
      print('🎬 Video quality probe failed: $e');
    }
  }

  Future<void> _initializeDirectVideo(
    String videoUrl, {
    String? qualityLabel,
  }) async {
    try {
      final resolvedQualityLabel = qualityLabel ?? _autoQualityLabel;
      final token = await TokenStorageService.instance.getAccessToken();
      if (kDebugMode) {
        print('🎬 _initializeDirectVideo: $videoUrl');
        print('🎬 Token available: ${token != null && token.isNotEmpty}');
      }

      final Map<String, String> headers = {};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      unawaited(
        _logVideoQualityRequestResponse(
          qualityLabel: resolvedQualityLabel,
          videoUrl: videoUrl,
          headers: headers,
        ),
      );

      _videoController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(
          videoUrl,
          httpHeaders: headers,
        ),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
        ),
      )..initialise().then((_) {
          if (kDebugMode) print('🎬 PodPlayer initialized successfully');
          if (mounted) {
            setState(() {
              _isVideoLoading = false;
              _useWebViewFallback = false;
            });
          }
        }).catchError((error) {
          if (kDebugMode) print('🎬 PodPlayer init error: $error');
          if (mounted) _initializeWebView(videoUrl);
        });
    } catch (e) {
      if (kDebugMode) print('🎬 _initializeDirectVideo exception: $e');
      if (mounted) _initializeWebView(videoUrl);
    }
  }

  Future<void> _initializeWebView(String videoUrl) async {
    try {
      if (kDebugMode) print('🎬 _initializeWebView fallback: $videoUrl');
      final token = await TokenStorageService.instance.getAccessToken();
      setState(() => _useWebViewFallback = true);

      try {
        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) print('🎬 Downloading video for WebView...');
        final response = await http
            .get(Uri.parse(videoUrl), headers: headers)
            .timeout(const Duration(seconds: 60));

        if (kDebugMode)
          print(
              '🎬 Download response: ${response.statusCode}, size: ${response.bodyBytes.length}');
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final fileName = videoUrl.split('/').last.split('?').first;
          final fileExtension = fileName.split('.').last;
          final tempFile = File(
              '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
          await tempFile.writeAsBytes(response.bodyBytes);
          final fileUrl = tempFile.path;
          if (kDebugMode) print('🎬 Video saved to: $fileUrl');
          _createWebViewWithFileUrl(fileUrl);
          setState(() => _tempVideoFile = tempFile);
          return;
        }
      } catch (e) {
        if (kDebugMode) print('🎬 WebView download error: $e');
      }

      if (kDebugMode) print('🎬 Using direct URL in WebView');
      _createWebViewWithDirectUrl(videoUrl, token);
    } catch (e) {
      if (kDebugMode) print('🎬 _initializeWebView exception: $e');
      if (mounted) setState(() => _isVideoLoading = false);
    }
  }

  void _createWebViewWithFileUrl(String filePath) {
    final fileUrl = 'file://$filePath';
    final htmlContent = '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>*{margin:0;padding:0;box-sizing:border-box}html,body{width:100%;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:contain;background:#000}</style>
</head><body>
<video id="v" controls autoplay playsinline webkit-playsinline><source src="$fileUrl" type="video/mp4"></video>
</body></html>''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _isVideoLoading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isVideoLoading = false);
        },
      ))
      ..loadHtmlString(htmlContent);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isVideoLoading = false);
      });
    }
  }

  void _createWebViewWithDirectUrl(String videoUrl, String? token) {
    String videoUrlWithToken = videoUrl;
    if (token != null && token.isNotEmpty) {
      final uri = Uri.parse(videoUrl);
      videoUrlWithToken = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'token': token,
      }).toString();
    }

    final htmlContent = '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>*{margin:0;padding:0;box-sizing:border-box}html,body{width:100%;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:contain;background:#000}</style>
</head><body>
<video id="v" controls autoplay playsinline webkit-playsinline style="display:none"></video>
<script>
var v=document.getElementById('v'),url='$videoUrl',urlT='$videoUrlWithToken';
${token != null ? "var tk='$token';" : 'var tk=null;'}
function go(){v.src=url;v.load();v.onloadeddata=function(){v.style.display='block'};
v.onerror=function(){if(tk){v.src=urlT;v.load();v.onloadeddata=function(){v.style.display='block'}}}}
go();
</script></body></html>''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _isVideoLoading = false);
        },
        onWebResourceError: (error) {
          if (error.errorType == WebResourceErrorType.hostLookup ||
              error.errorType == WebResourceErrorType.timeout) {
            if (mounted) setState(() => _isVideoLoading = false);
          }
        },
      ))
      ..loadHtmlString(htmlContent);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isVideoLoading = false);
      });
    }
  }

  void _disposeCurrentVideo() {
    _stopLessonProgressMonitor();
    _videoController?.dispose();
    _videoController = null;
    _webViewController = null;
    _useWebViewFallback = false;
    _isFileLessonWithoutVideo = false;
    _lessonContent = null;
    _availableVideoQualities = {};
    _selectedVideoQualityLabel = null;
    _activeVideoUrl = null;
    _inlinePlayerKind = 0;
    _inlineImageUrls = [];
    _inlineImagePageIndex = 0;
    _recordPlayerController?.dispose();
    _recordPlayerController = null;
    _recordPlayerLoading = false;
    if (_tempVideoFile != null) {
      try {
        _tempVideoFile!.deleteSync();
      } catch (_) {}
      _tempVideoFile = null;
    }
  }

  Future<void> _startPlayingLesson(Map<String, dynamic> lesson) async {
    _disposeCurrentVideo();

    setState(() {
      _inlinePlayerKind = 0;
      _currentLesson = lesson;
      _isVideoPlaying = true;
      _isVideoLoading = true;
      _isDownloaded = false;
      _isDownloading = false;
      _downloadProgress = 0;
    });

    await _loadLessonContentForVideo();
    await _initializeVideoForLesson();
    _checkIfDownloaded();
    _syncTrackedDownloadState();
    _subscribeToTrackedDownload();
    _startLessonProgressMonitor();
  }

  void _stopPlaying() {
    _stopLessonProgressMonitor();
    _disposeCurrentVideo();
    setState(() {
      _currentLesson = null;
      _isVideoPlaying = false;
      _isVideoLoading = false;
      _isDownloaded = false;
      _isDownloading = false;
      _downloadProgress = 0;
    });
  }

  Map<String, String> _extractVideoQualities(dynamic videoNode) {
    final result = <String, String>{};
    if (videoNode is! Map) return result;

    void addQuality(String label, dynamic urlValue) {
      final clean = _cleanVideoUrl(urlValue?.toString());
      if (clean == null || clean.isEmpty) return;
      final normalizedLabel = label.trim().isEmpty ? _autoQualityLabel : label;
      result[normalizedLabel] = clean;
    }

    addQuality(_autoQualityLabel, videoNode['url']);

    // Mobile lesson contract field.
    final mobileContractQualities = videoNode['video_qualities'];
    if (mobileContractQualities is Map) {
      mobileContractQualities.forEach((key, value) {
        addQuality(key.toString(), value);
      });
    }

    final candidates = [
      videoNode['qualities'],
      videoNode['quality'],
      videoNode['sources'],
      videoNode['resolutions'],
      videoNode['streams'],
    ];

    for (final source in candidates) {
      if (source is Map) {
        source.forEach((key, value) {
          if (value is Map) {
            addQuality(
              value['label']?.toString() ??
                  value['quality']?.toString() ??
                  key.toString(),
              value['url'] ?? value['src'] ?? value['file'],
            );
          } else {
            addQuality(key.toString(), value);
          }
        });
      } else if (source is List) {
        for (final item in source) {
          if (item is! Map) continue;
          addQuality(
            item['label']?.toString() ??
                item['quality']?.toString() ??
                item['resolution']?.toString() ??
                item['name']?.toString() ??
                _autoQualityLabel,
            item['url'] ?? item['src'] ?? item['file'],
          );
        }
      }
    }

    return result;
  }

  Future<void> _showVideoActionsBottomSheet() async {
    final qualities = _availableVideoQualities.entries.toList();
    if (qualities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.noVideoQualityOptions,
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      return;
    }
    if (qualities.length == 1) {
      final onlyLabel = qualities.first.key;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            onlyLabel == _autoQualityLabel
                ? context.l10n.onlyAutoQualityAvailable
                : '${context.l10n.videoQualitySheetTitle}: $onlyLabel',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.videoQualitySheetTitle,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...qualities.map((entry) {
                  final isSelected = entry.key == _selectedVideoQualityLabel;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? AppColors.primaryMap
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      entry.key,
                      style: GoogleFonts.cairo(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _changeVideoQuality(entry.key, entry.value);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeVideoQuality(String label, String targetUrl) async {
    if (_videoController == null || targetUrl.isEmpty) return;
    if (_activeVideoUrl == targetUrl) {
      setState(() => _selectedVideoQualityLabel = label);
      return;
    }

    final previousController = _videoController;
    final currentPosition = previousController?.currentVideoPosition;
    previousController?.dispose();
    _videoController = null;

    if (mounted) {
      setState(() {
        _isVideoLoading = true;
        _selectedVideoQualityLabel = label;
        _activeVideoUrl = targetUrl;
      });
    }

    await _initializeDirectVideo(targetUrl, qualityLabel: label);

    if (!mounted || currentPosition == null || _videoController == null) return;
    try {
      final targetDuration = _videoController!.totalVideoLength;
      final safeSeek =
          currentPosition > targetDuration ? targetDuration : currentPosition;
      if (safeSeek > Duration.zero) {
        _videoController!.videoSeekTo(safeSeek);
      }
    } catch (_) {}
  }

  Future<void> _handleDownload() async {
    final lesson = _currentLesson;
    if (lesson == null) return;

    final lessonId = lesson['id']?.toString();
    final course = _courseData ?? widget.course;
    final courseId =
        course?['id']?.toString() ?? lesson['course_id']?.toString();
    final title = context.localizedApiText(
      lesson,
      'title',
      fallback: context.l10n.defaultVideoLessonTitle,
    );
    final description = context.localizedApiText(lesson, 'description');

    if (lessonId == null || courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.cannotDownloadVideoMissingIds,
            style: GoogleFonts.cairo()),
        backgroundColor: Colors.red,
      ));
      return;
    }

    String? rawVideoUrl = _lessonContent?['video']?['url']?.toString() ??
        lesson['video_url']?.toString() ??
        lesson['video']?['url']?.toString();
    final videoUrl = _cleanVideoUrl(rawVideoUrl);

    if (videoUrl == null || videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(context.l10n.noVideoDownloadUrl, style: GoogleFonts.cairo()),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final cancelToken = CancelToken();
    _downloadService.startTrackingDownload(
      lessonId: lessonId,
      onCancel: () async => cancelToken.cancel('user_cancelled_download'),
    );
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
        _isDownloaded = false;
      });
    }

    try {
      String? courseTitle;
      try {
        final courseDetails =
            await CoursesService.instance.getCourseDetails(courseId);
        courseTitle = courseDetails['title']?.toString();
      } catch (_) {}

      if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
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
            if (mounted) setState(() => _downloadProgress = progress);
          },
        );

        if (localPath != null) {
          await _downloadService.saveDownloadedVideoRecord(
            lessonId: lessonId,
            courseId: courseId,
            title: courseTitle ?? title,
            videoUrl: videoUrl,
            localPath: localPath,
            courseTitle:
                courseTitle ?? context.l10n.defaultCourseTitleWithId(courseId),
            description: description.isNotEmpty ? description : title,
            durationText: lesson['duration']?.toString(),
            videoSource: 'youtube',
          );
          _downloadService.completeTrackedDownload(lessonId);
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _isDownloaded = true;
              _downloadProgress = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.videoDownloadedSuccessfully,
                  style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ));
          }
        } else {
          _downloadService.failTrackedDownload(lessonId);
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _downloadProgress = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.videoDownloadFailed,
                  style: GoogleFonts.cairo()),
              backgroundColor: Colors.red,
            ));
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
          if (mounted) setState(() => _downloadProgress = progress);
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.videoDownloadedSuccessfully,
                style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ));
        }
      } else {
        _downloadService.failTrackedDownload(lessonId);
        throw Exception(context.l10n.videoDownloadFailed);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              context.l10n.videoDownloadError(
                  e.toString().replaceFirst('Exception: ', '')),
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(context.l10n.videoDownloadStopped, style: GoogleFonts.cairo()),
      backgroundColor: Colors.orange,
    ));
  }

  // ── End video player helpers ────────────────────────────────────

  Map<String, dynamic>? _getFirstLesson() {
    final course = _courseData ?? widget.course;
    final curriculum = course?['curriculum'] as List?;
    final lessons = course?['lessons'] as List?;
    Map<String, dynamic>? firstLesson;

    if (curriculum != null && curriculum.isNotEmpty) {
      for (var item in curriculum) {
        if (item is Map<String, dynamic>) {
          // Check if this item has nested lessons (it's a topic/section)
          final nestedLessons = item['lessons'] as List?;
          if (nestedLessons != null && nestedLessons.isNotEmpty) {
            // Use first nested lesson
            final nestedLesson = nestedLessons[0];
            if (nestedLesson is Map<String, dynamic>) {
              firstLesson = nestedLesson;
              break;
            }
          } else {
            // This item is a lesson itself (has video or id)
            if (item['video'] != null ||
                item['id'] != null ||
                item['youtube_id'] != null ||
                item['youtubeVideoId'] != null) {
              firstLesson = item;
              break;
            }
          }
        }
      }
    }

    // If no lesson from curriculum, use lessons directly
    if (firstLesson == null && lessons != null && lessons.isNotEmpty) {
      final lesson = lessons[0];
      if (lesson is Map<String, dynamic>) {
        firstLesson = lesson;
      }
    }

    return firstLesson;
  }

  List<Map<String, dynamic>> _getFlatLessonsList() {
    final course = _courseData ?? widget.course;
    final curriculum = course?['curriculum'] as List?;
    final lessons = course?['lessons'] as List?;

    final List<Map<String, dynamic>> flat = [];

    if (curriculum != null && curriculum.isNotEmpty) {
      for (final item in curriculum) {
        if (item is! Map<String, dynamic>) continue;
        final nestedLessons = item['lessons'] as List?;
        final hasVideo = item['video'] != null;
        final hasYoutubeId =
            item['youtube_id'] != null || item['youtubeVideoId'] != null;
        final isTopic = nestedLessons != null || (!hasVideo && !hasYoutubeId);

        if (isTopic) {
          if (nestedLessons != null && nestedLessons.isNotEmpty) {
            for (final l in nestedLessons) {
              if (l is Map<String, dynamic>) flat.add(l);
            }
          }
        } else {
          flat.add(item);
        }
      }
    }

    if (flat.isEmpty && lessons != null && lessons.isNotEmpty) {
      for (final l in lessons) {
        if (l is Map<String, dynamic>) flat.add(l);
      }
    }

    return flat;
  }

  Future<void> _loadMaterialsForCurrentLesson() async {
    final course = _courseData ?? widget.course;
    final courseId = course?['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    final flat = _getFlatLessonsList();
    if (flat.isEmpty) return;

    final safeIndex = _selectedLessonIndex.clamp(0, flat.length - 1);
    final lessonId = flat[safeIndex]['id']?.toString();
    if (lessonId == null || lessonId.isEmpty) return;

    if (_materialsLessonId == lessonId && _materialsContent != null) return;

    setState(() => _isLoadingMaterials = true);
    try {
      final content =
          await CoursesService.instance.getLessonContent(courseId, lessonId);
      if (!mounted) return;
      setState(() {
        _materialsLessonId = lessonId;
        _materialsContent = content;
        _isLoadingMaterials = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _materialsLessonId = lessonId;
        _materialsContent = null;
        _isLoadingMaterials = false;
      });
    }
  }

  void _stopLessonProgressMonitor() {
    _lessonProgressMonitor?.cancel();
    _lessonProgressMonitor = null;
  }

  void _startLessonProgressMonitor() {
    _stopLessonProgressMonitor();
    _lessonProgressMonitor = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _maybeReportMediaCompletion(),
    );
  }

  void _markLessonCompletedLocally(String lessonId) {
    bool changed = false;
    final updatedCourse =
        Map<String, dynamic>.from(_courseData ?? widget.course ?? {});

    if (updatedCourse['lessons'] is List) {
      final updatedLessons = (updatedCourse['lessons'] as List).map((item) {
        if (item is! Map) return item;
        final lessonMap = Map<String, dynamic>.from(item);
        if (lessonMap['id']?.toString() == lessonId) {
          lessonMap['is_completed'] = true;
          lessonMap['completed'] = true;
          changed = true;
        }
        return lessonMap;
      }).toList();
      updatedCourse['lessons'] = updatedLessons;
    }

    if (updatedCourse['curriculum'] is List) {
      final updatedCurriculum =
          (updatedCourse['curriculum'] as List).map((item) {
        if (item is! Map) return item;
        final topic = Map<String, dynamic>.from(item);
        final nested = topic['lessons'];
        if (nested is List) {
          topic['lessons'] = nested.map((lesson) {
            if (lesson is! Map) return lesson;
            final lessonMap = Map<String, dynamic>.from(lesson);
            if (lessonMap['id']?.toString() == lessonId) {
              lessonMap['is_completed'] = true;
              lessonMap['completed'] = true;
              changed = true;
            }
            return lessonMap;
          }).toList();
        } else if (topic['id']?.toString() == lessonId) {
          topic['is_completed'] = true;
          topic['completed'] = true;
          changed = true;
        }
        return topic;
      }).toList();
      updatedCourse['curriculum'] = updatedCurriculum;
    }

    if (!changed || !mounted) return;
    setState(() {
      _courseData = updatedCourse;
    });
  }

  Future<void> _trackLessonProgress({
    required Map<String, dynamic> lesson,
    required String contentType,
    required bool isCompleted,
    int? watchedSeconds,
    double? completionRatio,
  }) async {
    final lessonId = lesson['id']?.toString();
    if (lessonId == null || lessonId.isEmpty) return;
    if (isCompleted && _reportedCompletedLessonIds.contains(lessonId)) return;

    final course = _courseData ?? widget.course;
    String? courseId = course?['id']?.toString();
    courseId ??=
        lesson['course_id']?.toString() ?? lesson['courseId']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      await CoursesService.instance.trackLessonProgress(
        courseId,
        lessonId,
        contentType: contentType,
        isCompleted: isCompleted,
        watchedSeconds: watchedSeconds,
        completionRatio: completionRatio,
      );
      if (isCompleted) {
        _reportedCompletedLessonIds.add(lessonId);
        _markLessonCompletedLocally(lessonId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to track lesson progress: $e');
      }
    }
  }

  void _maybeReportMediaCompletion() {
    final lesson = _currentLesson;
    if (lesson == null) return;
    final lessonType = _normalizeLessonType(lesson);
    if (lessonType != 'video' && lessonType != 'record') return;

    Duration position = Duration.zero;
    Duration duration = Duration.zero;

    if (lessonType == 'record' && _recordPlayerController != null) {
      final value = _recordPlayerController!.value;
      position = value.position;
      duration = value.duration;
    } else if (_videoController != null) {
      position = _videoController!.currentVideoPosition;
      duration = _videoController!.totalVideoLength;
    } else {
      return;
    }

    if (duration.inSeconds <= 0) return;
    final clampedPosition = position > duration ? duration : position;
    final ratio = clampedPosition.inMilliseconds / duration.inMilliseconds;
    final isCompleted = ratio >= 0.95;

    _trackLessonProgress(
      lesson: lesson,
      contentType: lessonType == 'record' ? 'record' : 'video',
      isCompleted: isCompleted,
      watchedSeconds: clampedPosition.inSeconds,
      completionRatio: ratio,
    );
  }

  Future<void> _playLesson(int index, Map<String, dynamic> lesson) async {
    setState(() {
      _selectedLessonIndex = index;
    });

    _loadMaterialsForCurrentLesson();

    final type = _normalizeLessonType(lesson);
    switch (type) {
      case 'pdf':
        await _openPdfLesson(lesson);
        return;
      case 'exam':
        await _openExamLesson(lesson);
        return;
      case 'image':
        await _openImageLessonPage(lesson);
        return;
      case 'record':
        await _startInlineRecordLesson(lesson);
        return;
      default:
        await _startPlayingLesson(lesson);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _courseData ?? widget.course;

    if (_isLoading && _courseData == null) {
      return Scaffold(
        body: _buildSkeleton(),
      );
    }

    if (course == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.courseDetailsTitle),
        ),
        body: Center(
          child: Text(
            context.l10n.noCourseData,
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    }

    final isFree = course['is_free'] == true || course['isFree'] == true;

    // Safely parse price
    num priceValue = 0.0;
    if (course['price'] != null) {
      if (course['price'] is num) {
        priceValue = course['price'] as num;
      } else if (course['price'] is String) {
        priceValue = num.tryParse(course['price'] as String) ?? 0.0;
      }
    }
    final isFreeFromPrice = priceValue == 0;
    final finalIsFree = isFree || isFreeFromPrice;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Video Player Section
              _buildVideoSection(),
              const SizedBox(
                height: 20,
              ),
              // Content Section - Scrollable
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    // Course Info Header
                    _buildCourseHeader(course, finalIsFree, priceValue),

                    // Expandable sections (Lessons / About)
                    _buildExpandableSections(course),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Action Button
      bottomNavigationBar: _buildBottomBar(course, finalIsFree),
    );
  }

  Widget _buildVideoSection() {
    final course = _courseData ?? widget.course;
    final thumbnail = course?['thumbnail']?.toString() ??
        course?['image']?.toString() ??
        course?['banner']?.toString();

    if (_isVideoPlaying) {
      if (_inlinePlayerKind == 1) return _buildInlineImageViewer();
      if (_inlinePlayerKind == 2) return _buildInlineRecordPlayer();
      return _buildInlineVideoPlayer();
    }

    return Container(
      height: 270,
      color: Colors.black,
      child: Stack(
        children: [
          if (thumbnail != null && thumbnail.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primaryMap.withOpacity(0.1),
                  child: const Center(
                    child: Icon(Icons.image,
                        color: AppColors.primaryMap, size: 50),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryMap),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              color: AppColors.primaryMap.withOpacity(0.1),
              child: const Center(
                child: Icon(Icons.image, color: AppColors.primaryMap, size: 50),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          if (_isEnrolled)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    final firstLesson = _getFirstLesson();
                    if (firstLesson != null && mounted) {
                      _playLesson(0, firstLesson);
                    }
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.primaryMap,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _isTogglingWishlist ? null : _toggleWishlist,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isTogglingWishlist
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(
                                _isInWishlist
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineVideoPlayer() {
    final lesson = _currentLesson;
    final lessonTitle = context.localizedApiText(
      lesson,
      'title',
      fallback: context.l10n.lesson,
    );
    final lessonDuration = lesson?['duration']?.toString();

    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar with lesson info & back
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 12,
              right: 12,
              bottom: 6,
            ),
            color: Colors.black,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _stopPlaying,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lessonTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lessonDuration != null)
                        Text(
                          lessonDuration,
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: Colors.white60),
                        ),
                    ],
                  ),
                ),
                if (_isEnrolled && !_isFileLessonWithoutVideo)
                  _buildDownloadIconButton(),
                if (!_isFileLessonWithoutVideo) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showVideoActionsBottomSheet,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Video player area
          SizedBox(
            height: 220,
            child: _isVideoLoading
                ? Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryMap),
                    ),
                  )
                : _isFileLessonWithoutVideo
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.insert_drive_file_rounded,
                                  color: Colors.white54, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.lessonIsFile,
                                style: GoogleFonts.cairo(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _videoController != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              PodVideoPlayer(
                                controller: _videoController!,
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Colors.white54, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        context.l10n.videoPlayerLoadError,
                                        style: GoogleFonts.cairo(
                                            color: Colors.white54,
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
          ),

          // Download progress bar (if downloading)
          if (_isDownloading)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress / 100,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryMap),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.downloadProgressPercent(_downloadProgress),
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: Colors.white60),
                      ),
                      GestureDetector(
                        onTap: _cancelDownload,
                        child: Text(
                          context.l10n.stopDownloading,
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatMediaClock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _seekRecordBySeconds(int seconds) async {
    final c = _recordPlayerController;
    if (c == null || !c.value.isInitialized) return;
    final current = c.value.position;
    final target = current + Duration(seconds: seconds);
    final duration = c.value.duration;
    var clamped = target;
    if (target < Duration.zero) clamped = Duration.zero;
    if (target > duration) clamped = duration;
    await c.seekTo(clamped);
    if (mounted) setState(() {});
  }

  Widget _buildInlineImageViewer() {
    final lesson = _currentLesson;
    final lessonTitle = context.localizedApiText(
      lesson,
      'title',
      fallback: context.l10n.lesson,
    );

    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 12,
              right: 12,
              bottom: 6,
            ),
            color: Colors.black,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _stopPlaying,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lessonTitle,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: _isVideoLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primaryMap),
                  )
                : _inlineImageUrls.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.noImageForLesson,
                          style: GoogleFonts.cairo(color: Colors.white54),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          PageView.builder(
                            key: ValueKey(_inlineImageUrls.join('|')),
                            onPageChanged: (i) =>
                                setState(() => _inlineImagePageIndex = i),
                            itemCount: _inlineImageUrls.length,
                            itemBuilder: (_, index) {
                              return InteractiveViewer(
                                minScale: 1,
                                maxScale: 5,
                                child: Center(
                                  child: Image.network(
                                    _inlineImageUrls[index],
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.primaryMap,
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white38,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_inlineImageUrls.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_inlineImagePageIndex + 1}/${_inlineImageUrls.length}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineRecordPlayer() {
    final lesson = _currentLesson;
    final lessonTitle = context.localizedApiText(
      lesson,
      'title',
      fallback: context.l10n.lesson,
    );

    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 12,
              right: 12,
              bottom: 6,
            ),
            color: Colors.black,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _stopPlaying,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lessonTitle,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: _recordPlayerLoading || _isVideoLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primaryMap),
                  )
                : _recordPlayerController == null
                    ? Center(
                        child: Text(
                          context.l10n.unableToLoadRecord,
                          style: GoogleFonts.cairo(color: Colors.white54),
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _recordPlayerController!,
                        builder: (_, __) {
                          final c = _recordPlayerController!;
                          final duration = c.value.duration;
                          final position = c.value.position > duration
                              ? duration
                              : c.value.position;
                          final progress = duration.inMilliseconds == 0
                              ? 0.0
                              : (position.inMilliseconds /
                                      duration.inMilliseconds)
                                  .clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 64,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(24, (index) {
                                      final normalized = (index + 1) / 24;
                                      final isActive = normalized <= progress;
                                      final randomizer =
                                          math.sin(index * 0.8).abs();
                                      final barHeight = 12 + (36 * randomizer);
                                      return Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 1.4),
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? AppColors.primaryMap
                                                : AppColors.primaryMap
                                                    .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Slider(
                                  value: duration.inMilliseconds == 0
                                      ? 0
                                      : position.inMilliseconds
                                          .clamp(0, duration.inMilliseconds)
                                          .toDouble(),
                                  min: 0,
                                  max: duration.inMilliseconds == 0
                                      ? 1
                                      : duration.inMilliseconds.toDouble(),
                                  onChanged: (value) {
                                    c.seekTo(
                                        Duration(milliseconds: value.toInt()));
                                  },
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatMediaClock(position),
                                        style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: Colors.white60),
                                      ),
                                      Text(
                                        _formatMediaClock(duration),
                                        style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: Colors.white60),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _seekRecordBySeconds(-10),
                                      icon: const Icon(
                                        Icons.replay_10_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        if (c.value.isPlaying) {
                                          c.pause();
                                        } else {
                                          c.play();
                                        }
                                        setState(() {});
                                      },
                                      icon: Icon(
                                        c.value.isPlaying
                                            ? Icons.pause_circle_rounded
                                            : Icons.play_circle_fill_rounded,
                                        size: 48,
                                        color: AppColors.primaryMap,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _seekRecordBySeconds(10),
                                      icon: const Icon(
                                        Icons.forward_10_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadIconButton() {
    if (_isDownloaded) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.download_done_rounded,
            color: Colors.green, size: 18),
      );
    }
    if (_isDownloading) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: _downloadProgress / 100,
                strokeWidth: 2,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primaryMap),
              ),
            ),
            Text(
              '$_downloadProgress',
              style: GoogleFonts.cairo(fontSize: 8, color: Colors.white),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _handleDownload,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.download_rounded, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildCourseHeader(
      Map<String, dynamic>? course, bool isFree, num price) {
    if (course == null) {
      return const SizedBox.shrink();
    }

    // Course meta is intentionally shown in the About tab.
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildExpandableSections(Map<String, dynamic>? course) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _buildMainExpansionCard(
            title: context.l10n.lessons,
            icon: Icons.play_lesson_rounded,
            initiallyExpanded: false,
            child: _buildLessonsAccordionContent(),
          ),
          const SizedBox(height: 12),
          _buildMainExpansionCard(
            title: context.l10n.about,
            icon: Icons.info_outline_rounded,
            child: _buildAboutTab(course),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMainExpansionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryMap.withOpacity(0.14)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding:
              const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          iconColor: AppColors.primaryMap,
          collapsedIconColor: AppColors.primaryMap,
          leading: Icon(icon, color: AppColors.primaryMap),
          title: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  String _safeParseRating(dynamic rating) {
    if (rating == null) return '0.0';
    if (rating is num) return rating.toStringAsFixed(1);
    if (rating is String) {
      final parsed = num.tryParse(rating);
      return parsed?.toStringAsFixed(1) ?? '0.0';
    }
    return '0.0';
  }

  String _safeParseCount(dynamic count) {
    if (count == null) return '0';
    if (count is int) return count.toString();
    if (count is num) return count.toInt().toString();
    if (count is String) {
      final parsed = int.tryParse(count);
      return parsed?.toString() ?? '0';
    }
    return '0';
  }

  int _safeParseHours(dynamic hours) {
    if (hours == null) return 0;
    if (hours is int) return hours;
    if (hours is num) return hours.toInt();
    if (hours is String) {
      final parsed = int.tryParse(hours);
      return parsed ?? 0;
    }
    return 0;
  }

  Widget _buildCourseSummaryCard({
    required String title,
    required String instructorName,
    required int durationHours,
    required int lessonsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: AppColors.primaryMap.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.play_lesson_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? context.l10n.courseContentTitle : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (instructorName.isNotEmpty)
                      Text(
                        instructorName,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLessonMetaChip(
                icon: Icons.play_circle_outline_rounded,
                label: context.l10n.lessonsCount(lessonsCount),
              ),
              if (durationHours > 0)
                _buildLessonMetaChip(
                  icon: Icons.schedule_rounded,
                  label: '$durationHours ${context.l10n.hour}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonMetaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryMap.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryMap),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryMap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumSectionCard({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> lessons,
    required List<Map<String, dynamic>> flatForIndex,
  }) {
    final grouped = <String, List<Map<String, dynamic>>>{
      'video': [],
      'pdf': [],
      'image': [],
      'record': [],
      'exam': [],
      'other': [],
    };

    for (final lesson in lessons) {
      final t = _normalizeLessonType(lesson);
      (grouped[t] ?? grouped['other']!).add(lesson);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          leading: Icon(Icons.folder_outlined, color: AppColors.primaryMap),
          title: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          children: lessons.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      context.l10n.noLessonsAvailable,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ]
              : [
                  if ((grouped['video'] ?? []).isNotEmpty)
                    _buildCurriculumGroupTile(
                      groupKey: 'sec_${title}_videos',
                      title: _localizedGroupLabel('videos'),
                      icon: Icons.play_circle_outline_rounded,
                      count: grouped['video']!.length,
                      children: [
                        for (final lesson in grouped['video']!)
                          _buildLessonRowFromFlatIndex(lesson, flatForIndex),
                      ],
                    ),
                  if ((grouped['image'] ?? []).isNotEmpty)
                    _buildCurriculumGroupTile(
                      groupKey: 'sec_${title}_images',
                      title: _localizedGroupLabel('images'),
                      icon: Icons.image_outlined,
                      count: grouped['image']!.length,
                      children: [
                        for (final lesson in grouped['image']!)
                          _buildLessonRowFromFlatIndex(lesson, flatForIndex),
                      ],
                    ),
                  if ((grouped['record'] ?? []).isNotEmpty)
                    _buildCurriculumGroupTile(
                      groupKey: 'sec_${title}_records',
                      title: _localizedGroupLabel('records'),
                      icon: Icons.graphic_eq_rounded,
                      count: grouped['record']!.length,
                      children: [
                        for (final lesson in grouped['record']!)
                          _buildLessonRowFromFlatIndex(lesson, flatForIndex),
                      ],
                    ),
                  if ((grouped['exam'] ?? []).isNotEmpty)
                    _buildCurriculumGroupTile(
                      groupKey: 'sec_${title}_exams',
                      title: context.l10n.exams,
                      icon: Icons.quiz_rounded,
                      count: grouped['exam']!.length,
                      children: [
                        for (final lesson in grouped['exam']!)
                          _buildLessonRowFromFlatIndex(lesson, flatForIndex),
                      ],
                    ),
                  if ((grouped['pdf'] ?? []).isNotEmpty)
                    _buildCurriculumGroupTile(
                      groupKey: 'sec_${title}_pdfs',
                      title: context.l10n.pdfFileTitle,
                      icon: Icons.picture_as_pdf_rounded,
                      count: grouped['pdf']!.length,
                      children: [
                        for (final lesson in grouped['pdf']!)
                          _buildLessonRowFromFlatIndex(lesson, flatForIndex),
                      ],
                    ),
                  if ((grouped['other'] ?? []).isNotEmpty)
                    _buildCurriculumGroupTile(
                      groupKey: 'sec_${title}_other',
                      title: context.l10n.lessons,
                      icon: Icons.play_lesson_rounded,
                      count: grouped['other']!.length,
                      children: [
                        for (final lesson in grouped['other']!)
                          _buildLessonRowFromFlatIndex(lesson, flatForIndex),
                      ],
                    ),
                ],
        ),
      ),
    );
  }

  String _localizedGroupLabel(String kind) {
    final isAr = (context.l10n.localeName).toLowerCase().startsWith('ar');
    if (isAr) {
      return switch (kind) {
        'videos' => 'فيديوهات',
        'images' => 'صور',
        'records' => 'ريكورد',
        _ => kind,
      };
    }
    return switch (kind) {
      'videos' => 'Videos',
      'images' => 'Images',
      'records' => 'Records',
      _ => kind,
    };
  }

  Widget _buildCurriculumGroupTile({
    required String groupKey,
    required String title,
    required IconData icon,
    required int count,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryMap.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryMap.withOpacity(0.10)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(groupKey),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Icon(icon, color: AppColors.primaryMap),
          title: Text(
            '$title ($count)',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildLessonRowFromFlatIndex(
      Map<String, dynamic> lesson, List<Map<String, dynamic>> flatForIndex) {
    final idx = flatForIndex.indexWhere(
      (l) => l['id']?.toString() == lesson['id']?.toString(),
    );
    return _buildLessonItem(lesson, idx < 0 ? 0 : idx, flatForIndex);
  }

  List<Widget> _buildCurriculumLessonSections() {
    final course = _courseData ?? widget.course;
    final curriculum = course?['curriculum'] as List?;
    final flatForIndex = _getFlatLessonsList();
    final widgets = <Widget>[];

    if (curriculum != null && curriculum.isNotEmpty) {
      for (final raw in curriculum) {
        if (raw is! Map<String, dynamic>) continue;
        final item = raw;
        final nestedLessons = item['lessons'] as List?;
        final hasVideo = item['video'] != null;
        final hasYoutubeId =
            item['youtube_id'] != null || item['youtubeVideoId'] != null;
        final isTopic = nestedLessons != null || (!hasVideo && !hasYoutubeId);

        if (isTopic) {
          final lessonMaps = <Map<String, dynamic>>[];
          if (nestedLessons != null) {
            for (final l in nestedLessons) {
              if (l is Map<String, dynamic>) lessonMaps.add(l);
            }
          }
          final sectionTitle = context.localizedApiText(
            item,
            'title',
            fallback: context.l10n.courseContentTitle,
          );
          widgets.add(
            _buildCurriculumSectionCard(
              title: sectionTitle,
              subtitle: context.l10n.lessonsCount(lessonMaps.length),
              lessons: lessonMaps,
              flatForIndex: flatForIndex,
            ),
          );
        } else {
          final idx = flatForIndex.indexWhere(
            (l) => l['id']?.toString() == item['id']?.toString(),
          );
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildLessonItem(item, idx < 0 ? 0 : idx, flatForIndex),
            ),
          );
        }
      }
      return widgets;
    }

    if (flatForIndex.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            context.l10n.noLessonsAvailable,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    widgets.add(
      _buildCurriculumSectionCard(
        title: context.l10n.lessons,
        subtitle: context.l10n.lessonsCount(flatForIndex.length),
        lessons: flatForIndex,
        flatForIndex: flatForIndex,
      ),
    );
    return widgets;
  }

  Widget _buildLessonsAccordionContent() {
    // final course = _courseData ?? widget.course;
    // final courseTitle = context.localizedApiText(course, 'title');
    // final instructorName = (course?['instructor'] is Map)
    //     ? context.localizedApiText(
    //         Map<String, dynamic>.from(course?['instructor'] as Map),
    //         'name',
    //       )
    //     : (course?['instructor_name']?.toString() ??
    //         course?['instructorName']?.toString() ??
    //         '');
    // final durationHours = _safeParseHours(
    //   course?['duration_hours'] ?? course?['durationHours'],
    // );
    // final totalLessonsCount =
    //     (course?['lessons_count'] ?? course?['lessonsCount']) as int? ??
    //         _getFlatLessonsList().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // _buildCourseSummaryCard(
        //   title: courseTitle,
        //   instructorName: instructorName,
        //   durationHours: durationHours,
        //   lessonsCount: totalLessonsCount,
        // ),
        // const SizedBox(height: 12),
        ..._buildCurriculumLessonSections(),
      ],
    );
  }

  String _normalizeLessonType(Map<String, dynamic> lesson) {
    final raw = lesson['type']?.toString().toLowerCase() ?? '';
    if (raw.contains('video')) return 'video';
    if (raw.contains('pdf') ||
        raw.contains('file') ||
        raw.contains('material')) {
      return 'pdf';
    }
    if (raw.contains('exam') || raw.contains('quiz') || raw.contains('test')) {
      return 'exam';
    }
    if (raw.contains('image') ||
        raw.contains('photo') ||
        raw.contains('gallery')) {
      return 'image';
    }
    if (raw.contains('record') ||
        raw.contains('audio') ||
        raw.contains('sound')) {
      return 'record';
    }

    if (lesson['video'] != null || lesson['youtube_id'] != null) return 'video';
    if (_resolveAssetUrl(lesson, ['content_pdf', 'pdf', 'file_url']) != null) {
      return 'pdf';
    }
    if (lesson['exam_id'] != null) return 'exam';
    if (_resolveRecordUrl(lesson) != null) {
      return 'record';
    }
    if (_collectImageUrls(lesson).isNotEmpty) return 'image';
    return 'video';
  }

  String? _resolveAssetUrl(
      Map<String, dynamic> lesson, List<String> candidates) {
    for (final key in candidates) {
      final raw = lesson[key]?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        return _normalizeRemoteUrl(raw);
      }
    }
    if (lesson['attachments'] is List) {
      final attachments = lesson['attachments'] as List;
      for (final item in attachments) {
        if (item is Map) {
          final attachmentUrl = item['url']?.toString().trim();
          if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
            return _normalizeRemoteUrl(attachmentUrl);
          }
        }
      }
    }
    return null;
  }

  String _normalizeRemoteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiEndpoints.imageBaseUrl}$url';
    return '${ApiEndpoints.imageBaseUrl}/$url';
  }

  Future<void> _openPdfLesson(Map<String, dynamic> lesson) async {
    final pdfUrl = _resolveAssetUrl(lesson, ['content_pdf', 'pdf', 'file_url']);
    if (pdfUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noPdfForCurrentLesson)),
      );
      return;
    }
    await context.push(
      RouteNames.pdfViewer,
      extra: {
        'pdfUrl': pdfUrl,
        'title': context.localizedApiText(
          lesson,
          'title',
          fallback: context.l10n.pdfFileTitle,
        ),
      },
    );

    await _trackLessonProgress(
      lesson: lesson,
      contentType: 'pdf',
      isCompleted: true,
      completionRatio: 1.0,
    );
  }

  Future<void> _openExamLesson(Map<String, dynamic> lesson) async {
    if (_courseExams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noTrialExamAvailable)),
      );
      return;
    }
    final lessonExamId = lesson['exam_id']?.toString();
    final exam = lessonExamId == null
        ? _courseExams.first
        : _courseExams.firstWhere(
            (item) => item['id']?.toString() == lessonExamId,
            orElse: () => _courseExams.first,
          );
    final rawMaxAttempts =
        exam['max_attempts'] ?? exam['maxAttempts'] ?? exam['attempts_limit'];
    final rawAttemptsUsed = exam['attempts_used'] ??
        exam['attempts_count'] ??
        exam['attemptsCount'] ??
        0;
    final rawAttemptsLeft = exam['attempts_left'] ??
        exam['remaining_attempts'] ??
        exam['attemptsLeft'];
    final maxAttempts = rawMaxAttempts is num
        ? rawMaxAttempts.toInt()
        : int.tryParse(rawMaxAttempts?.toString() ?? '');
    final attemptsUsed = rawAttemptsUsed is num
        ? rawAttemptsUsed.toInt()
        : int.tryParse(rawAttemptsUsed.toString()) ?? 0;
    final attemptsLeft = rawAttemptsLeft is num
        ? rawAttemptsLeft.toInt()
        : int.tryParse(rawAttemptsLeft?.toString() ?? '');
    final inferredMaxAttempts = maxAttempts ??
        (attemptsLeft != null ? attemptsUsed + attemptsLeft : null);
    final attemptsExhausted = inferredMaxAttempts != null &&
        inferredMaxAttempts > 0 &&
        attemptsUsed >= inferredMaxAttempts;
    final examUnavailable = exam['can_start'] != true;
    if (attemptsExhausted || examUnavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attemptsExhausted
                ? context.l10n.attemptsExhausted
                : context.l10n.notAvailable,
          ),
        ),
      );
      return;
    }
    final examId = exam['id']?.toString() ?? '';
    await _startExam(examId, exam, sourceLesson: lesson);
  }

  // ignore: unused_element
  Widget _buildLessonsTab() {
    final course = _courseData ?? widget.course;
    // Try curriculum first, then lessons
    final curriculum = course?['curriculum'] as List?;
    final lessons = course?['lessons'] as List?;

    // Primary course info card shown before chapters/lessons
    final courseTitle = context.localizedApiText(course, 'title');
    final instructorName = (course?['instructor'] is Map)
        ? context.localizedApiText(
            Map<String, dynamic>.from(course?['instructor'] as Map),
            'name',
          )
        : (course?['instructor_name']?.toString() ??
            course?['instructorName']?.toString() ??
            '');
    final durationHours = _safeParseHours(
      course?['duration_hours'] ?? course?['durationHours'],
    );
    final totalLessonsCount =
        (course?['lessons_count'] ?? course?['lessonsCount']) as int? ??
            (lessons?.length ?? 0);

    // Build hierarchical structure: topics with nested lessons
    final List<Map<String, dynamic>> topicsWithLessons = [];
    final List<Map<String, dynamic>> flatLessonsList = [];

    // First, try to get lessons from curriculum
    if (curriculum != null && curriculum.isNotEmpty) {
      for (var item in curriculum) {
        if (item is Map<String, dynamic>) {
          // Check if this item has nested lessons (it's a topic/section)
          final nestedLessons = item['lessons'] as List?;
          final hasVideo = item['video'] != null;
          final hasYoutubeId =
              item['youtube_id'] != null || item['youtubeVideoId'] != null;

          // It's a topic if it has lessons field (even if empty) OR doesn't have video/youtube_id
          final isTopic = nestedLessons != null || (!hasVideo && !hasYoutubeId);

          if (isTopic) {
            final topicLessons = <Map<String, dynamic>>[];
            if (nestedLessons != null && nestedLessons.isNotEmpty) {
              for (var nestedLesson in nestedLessons) {
                if (nestedLesson is Map<String, dynamic>) {
                  final type = nestedLesson['type']?.toString().toLowerCase();
                  if (type == 'video') {
                    topicLessons.add(nestedLesson);
                    flatLessonsList.add(nestedLesson);
                  }
                }
              }
            }
            if (topicLessons.isNotEmpty) {
              topicsWithLessons.add({
                'is_topic': true,
                'topic': item,
                'lessons': topicLessons,
              });
            }
          } else {
            final type = item['type']?.toString().toLowerCase();
            if (type == 'video' &&
                (hasVideo || item['id'] != null || hasYoutubeId)) {
              flatLessonsList.add(item);
              topicsWithLessons.add({
                'is_topic': false,
                'lesson': item,
              });
            }
          }
        }
      }
    }

    if (topicsWithLessons.isEmpty && lessons != null && lessons.isNotEmpty) {
      for (var lesson in lessons) {
        if (lesson is Map<String, dynamic>) {
          final type = lesson['type']?.toString().toLowerCase();
          if (type == 'video') {
            flatLessonsList.add(lesson);
            topicsWithLessons.add({
              'is_topic': false,
              'lesson': lesson,
            });
          }
        }
      }
    }

    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📚 BUILDING LESSONS TAB');
      print('═══════════════════════════════════════════════════════════');
      print('Curriculum items: ${curriculum?.length ?? 0}');
      print('Lessons items: ${lessons?.length ?? 0}');
      print('Topics with lessons: ${topicsWithLessons.length}');
      print('Total flat lessons: ${flatLessonsList.length}');

      // Count topics
      int topicCount = 0;
      int standaloneLessonCount = 0;
      for (var item in topicsWithLessons) {
        if (item['is_topic'] == true) {
          topicCount++;
        } else {
          standaloneLessonCount++;
        }
      }

      print('');
      print('📊 SUMMARY:');
      print('  - Total Topics: $topicCount');
      print('  - Standalone Lessons: $standaloneLessonCount');
      print('  - Total Items: ${topicsWithLessons.length}');
      print('');

      // Show ALL topics from curriculum (even if they have no lessons)
      if (curriculum != null && curriculum.isNotEmpty) {
        print('📁 ALL TOPICS FROM CURRICULUM (COMPLETE LIST):');
        print('═══════════════════════════════════════════════════════════');
        int allTopicsCount = 0;
        for (int i = 0; i < curriculum.length; i++) {
          final item = curriculum[i];
          if (item is Map<String, dynamic>) {
            final nestedLessons = item['lessons'] as List?;
            final hasVideo = item['video'] != null;
            final hasYoutubeId =
                item['youtube_id'] != null || item['youtubeVideoId'] != null;

            // It's a topic if it has lessons field OR doesn't have video/youtube_id
            final isTopic =
                nestedLessons != null || (!hasVideo && !hasYoutubeId);

            if (isTopic) {
              allTopicsCount++;
              final lessonsCount = nestedLessons?.length ?? 0;
              print('📁 TOPIC $allTopicsCount:');
              print('  - ID: ${item['id']}');
              print('  - Title: ${item['title']}');
              print('  - Order: ${item['order']}');
              print('  - Type: ${item['type']}');
              print('  - Lessons Count: $lessonsCount');
              print('  - Has Lessons Field: ${nestedLessons != null}');
              if (nestedLessons == null) {
                print('  - ⚠️ No lessons field found');
              } else if (nestedLessons.isEmpty) {
                print('  - ⚠️ Empty lessons array');
              }
              print('  - All Keys: ${item.keys.toList()}');
              print('');
            }
          }
        }
        print('═══════════════════════════════════════════════════════════');
        print('Total Topics in Curriculum: $allTopicsCount');
        print('═══════════════════════════════════════════════════════════');
        print('');
      }

      // Show all topics summary (only topics that have lessons)
      if (topicCount > 0) {
        print('📁 TOPICS WITH LESSONS (FOR DISPLAY):');
        print('═══════════════════════════════════════════════════════════');
        int currentTopicNum = 0;
        for (int i = 0; i < topicsWithLessons.length; i++) {
          final item = topicsWithLessons[i];
          if (item['is_topic'] == true) {
            currentTopicNum++;
            final topic = item['topic'] as Map<String, dynamic>;
            final topicLessons = item['lessons'] as List<Map<String, dynamic>>;
            print('📁 TOPIC $currentTopicNum:');
            print('  - ID: ${topic['id']}');
            print('  - Title: ${topic['title']}');
            print('  - Order: ${topic['order']}');
            print('  - Lessons Count: ${topicLessons.length}');
            print('');
          }
        }
        print('═══════════════════════════════════════════════════════════');
        print('');
      }

      if (topicsWithLessons.isNotEmpty) {
        print('First item:');
        final first = topicsWithLessons[0];
        if (first['is_topic'] == true) {
          print('  - Type: Topic');
          print('  - Topic Title: ${first['topic']?['title']}');
          print(
              '  - Lessons Count: ${(first['lessons'] as List?)?.length ?? 0}');
        } else {
          print('  - Type: Lesson');
          print('  - Lesson Title: ${first['lesson']?['title']}');
        }
      }
      print('═══════════════════════════════════════════════════════════');
      print('📖 DETAILED LESSONS DATA:');
      print('═══════════════════════════════════════════════════════════');
      for (int i = 0; i < topicsWithLessons.length; i++) {
        final item = topicsWithLessons[i];
        final isTopic = item['is_topic'] == true;

        if (isTopic) {
          final topic = item['topic'] as Map<String, dynamic>;
          final topicLessons = item['lessons'] as List<Map<String, dynamic>>;

          print('───────────────────────────────────────────────────────────');
          print('📁 TOPIC ${i + 1}:');
          print('  - ID: ${topic['id']}');
          print('  - Title: ${topic['title']}');
          print('  - Order: ${topic['order']}');
          print('  - Type: ${topic['type']}');
          print('  - Lessons Count: ${topicLessons.length}');
          print('  - All Topic Keys: ${topic.keys.toList()}');
          print('');
          print('  📚 LESSONS IN THIS TOPIC:');

          for (int j = 0; j < topicLessons.length; j++) {
            final lesson = topicLessons[j];
            print(
                '    ───────────────────────────────────────────────────────');
            print('    📝 LESSON ${j + 1}:');
            print('      - ID: ${lesson['id']}');
            print('      - Title: ${lesson['title']}');
            print('      - Order: ${lesson['order']}');
            print('      - Type: ${lesson['type']}');
            print('      - Duration Minutes: ${lesson['duration_minutes']}');
            print('      - Is Locked: ${lesson['is_locked']}');
            print('      - Is Completed: ${lesson['is_completed']}');
            print('      - Video: ${lesson['video']}');
            print('      - YouTube ID: ${lesson['youtube_id']}');
            print('      - YouTube Video ID: ${lesson['youtubeVideoId']}');

            // Print video object details if exists
            if (lesson['video'] is Map) {
              final video = lesson['video'] as Map;
              print('      - Video Object Keys: ${video.keys.toList()}');
              video.forEach((key, value) {
                print('        - video.$key: $value');
              });
            }

            print('      - All Lesson Keys: ${lesson.keys.toList()}');

            // Print full lesson JSON
            try {
              const encoder = JsonEncoder.withIndent('        ');
              print('      - Full Lesson JSON:');
              print(encoder.convert(lesson));
            } catch (e) {
              print('      - Could not convert lesson to JSON: $e');
            }
          }
        } else {
          final lesson = item['lesson'] as Map<String, dynamic>;
          print('───────────────────────────────────────────────────────────');
          print('📝 STANDALONE LESSON ${i + 1}:');
          print('  - ID: ${lesson['id']}');
          print('  - Title: ${lesson['title']}');
          print('  - Order: ${lesson['order']}');
          print('  - Type: ${lesson['type']}');
          print('  - Duration Minutes: ${lesson['duration_minutes']}');
          print('  - Is Locked: ${lesson['is_locked']}');
          print('  - Is Completed: ${lesson['is_completed']}');
          print('  - Video: ${lesson['video']}');
          print('  - YouTube ID: ${lesson['youtube_id']}');
          print('  - YouTube Video ID: ${lesson['youtubeVideoId']}');

          // Print video object details if exists
          if (lesson['video'] is Map) {
            final video = lesson['video'] as Map;
            print('  - Video Object Keys: ${video.keys.toList()}');
            video.forEach((key, value) {
              print('    - video.$key: $value');
            });
          }

          print('  - All Lesson Keys: ${lesson.keys.toList()}');

          // Print full lesson JSON
          try {
            const encoder = JsonEncoder.withIndent('    ');
            print('  - Full Lesson JSON:');
            print(encoder.convert(lesson));
          } catch (e) {
            print('  - Could not convert lesson to JSON: $e');
          }
        }
      }
      print('═══════════════════════════════════════════════════════════');
    }

    if (topicsWithLessons.isEmpty) {
      // Show course info even if there are no lessons
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCourseSummaryCard(
              title: courseTitle,
              instructorName: instructorName,
              durationHours: durationHours,
              lessonsCount: totalLessonsCount,
            ),
            const SizedBox(height: 16),
            _buildEmptyState(
              context.l10n.noLessonsAvailable,
              Icons.play_lesson_rounded,
            ),
          ],
        ),
      );
    }

    final lessonWidgets = <Widget>[
      _buildCourseSummaryCard(
        title: courseTitle,
        instructorName: instructorName,
        durationHours: durationHours,
        lessonsCount: totalLessonsCount,
      ),
      const SizedBox(height: 16),
    ];

    for (var i = 0; i < topicsWithLessons.length; i++) {
      final item = topicsWithLessons[i];
      final isTopic = item['is_topic'] == true;

      if (isTopic) {
        final topic = item['topic'] as Map<String, dynamic>;
        final topicLessons = item['lessons'] as List<Map<String, dynamic>>;
        final topicTitle = context.localizedApiText(
          topic,
          'title',
          fallback: context.l10n.topic,
        );
        final topicOrder = topic['order'] ?? i + 1;

        lessonWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 12, top: i > 0 ? 16 : 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryMap.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryMap.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMap,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$topicOrder',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        topicTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryMap,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMap.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.l10n.lessonsCount(topicLessons.length),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryMap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...topicLessons.map((lesson) {
                final globalIndex = flatLessonsList.indexWhere(
                    (l) => l['id']?.toString() == lesson['id']?.toString());
                final actualIndex = globalIndex >= 0 ? globalIndex : 0;
                return _buildLessonItem(lesson, actualIndex, flatLessonsList);
              }),
            ],
          ),
        );
      } else {
        final lesson = item['lesson'] as Map<String, dynamic>;
        final globalIndex = flatLessonsList
            .indexWhere((l) => l['id']?.toString() == lesson['id']?.toString());
        final actualIndex = globalIndex >= 0 ? globalIndex : 0;
        lessonWidgets
            .add(_buildLessonItem(lesson, actualIndex, flatLessonsList));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lessonWidgets,
      ),
    );
  }

  Widget _buildLessonItem(Map<String, dynamic> lesson, int index,
      List<Map<String, dynamic>> allLessons) {
    final isLocked = lesson['is_locked'] == true || lesson['locked'] == true;
    final isCompleted =
        lesson['is_completed'] == true || lesson['completed'] == true;
    final isSelected = index == _selectedLessonIndex;
    final lessonId = lesson['id']?.toString() ?? 'idx_$index';
    final title = context.localizedApiText(
      lesson,
      'title',
      fallback: context.l10n.lesson,
    );
    final lessonType = _normalizeLessonType(lesson);
    final IconData trailingIcon = switch (lessonType) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'exam' => Icons.quiz_rounded,
      'image' => Icons.image_rounded,
      'record' => Icons.graphic_eq_rounded,
      _ => Icons.play_arrow_rounded,
    };

    Widget indexWidget() {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
              : isCompleted
                  ? const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    )
                  : null,
          color: isLocked
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLocked
            ? Icon(Icons.lock_rounded, color: Colors.grey[400], size: 20)
            : isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.primaryMap,
                      ),
                    ),
                  ),
      );
    }

    final containerDecoration = BoxDecoration(
      color: isSelected
          ? AppColors.primaryMap.withOpacity(0.08)
          : isLocked
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isSelected
            ? AppColors.primaryMap
            : isCompleted
                ? const Color(0xFF10B981)
                : Theme.of(context).colorScheme.outlineVariant,
        width: isSelected || isCompleted ? 2 : 1,
      ),
    );

    // Locked lessons: keep them non-expandable/non-interactive.
    if (isLocked) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16),
        padding: const EdgeInsets.all(14),
        decoration: containerDecoration,
        child: Row(
          children: [
            indexWidget(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(lesson),
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _playLesson(index, lesson),
      child: Container(
        key: PageStorageKey<String>('lesson_$lessonId'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: containerDecoration,
        child: Row(
          children: [
            indexWidget(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(lesson),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : AppColors.primaryMap.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                trailingIcon,
                color: AppColors.primaryMap,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Map<String, dynamic> lesson) {
    // Try duration_minutes first, then duration
    if (lesson['duration_minutes'] != null) {
      final minutes = lesson['duration_minutes'];
      if (minutes is int) {
        return '$minutes ${context.l10n.minute}';
      } else if (minutes is num) {
        return '${minutes.toInt()} ${context.l10n.minute}';
      } else if (minutes is String) {
        final parsed = int.tryParse(minutes);
        if (parsed != null) return '$parsed ${context.l10n.minute}';
      }
    }
    return lesson['duration']?.toString() ?? '10 ${context.l10n.minute}';
  }

  Widget _buildAboutTab(Map<String, dynamic>? course) {
    final courseData = _courseData ?? course;
    final description = context.localizedApiText(
      courseData,
      'description',
      fallback: context.l10n.courseSuitable,
    );
    final isFree =
        courseData?['is_free'] == true || courseData?['isFree'] == true;
    final priceRaw = courseData?['price'];
    final price = priceRaw is num ? priceRaw : num.tryParse('$priceRaw') ?? 0;
    final categoryName = courseData?['category'] is Map
        ? context.localizedApiText(
            Map<String, dynamic>.from(courseData?['category'] as Map),
            'name',
            fallback: context.l10n.design,
          )
        : courseData?['category']?.toString() ?? context.l10n.design;
    final teacherName = courseData?['instructor'] is Map
        ? context.localizedApiText(
            Map<String, dynamic>.from(courseData?['instructor'] as Map),
            'name',
            fallback: context.l10n.instructor,
          )
        : courseData?['instructor']?.toString() ?? context.l10n.instructor;
    final courseName = context.localizedApiText(
      courseData,
      'title',
      fallback: context.l10n.courseTitle,
    );
    final courseRating = _safeParseRating(courseData?['rating']);
    final studentsCount = _safeParseCount(
        courseData?['students_count'] ?? courseData?['students']);
    final hours =
        '${_safeParseHours(courseData?['duration_hours'] ?? courseData?['hours'])} ${context.l10n.hour}';

    // Get what_you_learn from API
    final whatYouLearn = courseData?['what_you_learn'] as List?;
    final features = <Map<String, dynamic>>[];

    if (whatYouLearn != null && whatYouLearn.isNotEmpty) {
      for (var item in whatYouLearn) {
        if (item is String) {
          features.add({'icon': Icons.check_circle_outline, 'text': item});
        } else if (item is Map) {
          features.add({
            'icon': Icons.check_circle_outline,
            'text': item['text']?.toString() ?? item.toString()
          });
        }
      }
    }

    // Add default features if empty
    if (features.isEmpty) {
      features.addAll([
        {
          'icon': Icons.check_circle_outline,
          'text': context.l10n.certifiedCertificate
        },
        {'icon': Icons.access_time, 'text': context.l10n.lifetimeAccess},
        {
          'icon': Icons.phone_android,
          'text': context.l10n.availableOnAllDevices
        },
        {'icon': Icons.download_rounded, 'text': context.l10n.filesForDownload},
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMap.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryMap,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isFree
                              ? [
                                  const Color(0xFF10B981),
                                  const Color(0xFF059669)
                                ]
                              : [
                                  const Color(0xFFF97316),
                                  const Color(0xFFEA580C)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFree
                            ? context.l10n.free
                            : context.l10n.egyptianPound(price.toInt()),
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  courseName,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMap.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person,
                          size: 16, color: AppColors.primaryMap),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        teacherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.primaryMap,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatChip(
                      Icons.star_rounded,
                      courseRating,
                      Colors.amber,
                    ),
                    _buildStatChip(
                      Icons.people_rounded,
                      studentsCount,
                      AppColors.primaryMap,
                    ),
                    _buildStatChip(
                      Icons.access_time_rounded,
                      hours,
                      const Color(0xFF10B981),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.courseDescriptionTitle,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              description,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Text(
          //   context.l10n.whatYouWillGet,
          //   style: GoogleFonts.cairo(
          //     fontSize: 16,
          //     fontWeight: FontWeight.bold,
          //     color: Theme.of(context).colorScheme.onSurface,
          //   ),
          // ),
          // const SizedBox(height: 12),
          // ...features.map((feature) => Padding(
          //       padding: const EdgeInsets.only(bottom: 10),
          //       child: Row(
          //         children: [
          //           Container(
          //             width: 36,
          //             height: 36,
          //             decoration: BoxDecoration(
          //               color: const Color(0xFF10B981).withOpacity(0.1),
          //               borderRadius: BorderRadius.circular(10),
          //             ),
          //             child: Icon(
          //               feature['icon'] as IconData,
          //               size: 18,
          //               color: const Color(0xFF10B981),
          //             ),
          //           ),
          //           const SizedBox(width: 12),
          //           Text(
          //             feature['text'] as String,
          //             style: GoogleFonts.cairo(
          //               fontSize: 14,
          //               color: Theme.of(context).colorScheme.onSurface,
          //             ),
          //           ),
          //         ],
          //       ),
          //     )),

          const SizedBox(height: 24),
          Text(
            context.l10n.reviewsCommentsTitle,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Add review form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.addYourReview,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStarsPicker(),
                const SizedBox(height: 8),
                TextField(
                  controller: _reviewTitleController,
                  enabled: !_isSubmittingReview,
                  decoration: InputDecoration(
                    hintText: context.l10n.reviewTitleHint,
                    hintStyle: GoogleFonts.cairo(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primaryMap),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reviewCommentController,
                  enabled: !_isSubmittingReview,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: context.l10n.reviewCommentHint,
                    hintStyle: GoogleFonts.cairo(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primaryMap),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmittingReview ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMap,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmittingReview
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            context.l10n.send,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.l10n.studentReviewsTitle,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isLoadingReviews ? null : _loadReviews,
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.primaryMap),
              ),
            ],
          ),

          if (_isLoadingReviews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryMap),
              ),
            )
          else if (_reviewsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _reviewsError!,
                style: GoogleFonts.cairo(color: Colors.red, fontSize: 13),
              ),
            )
          else if (_reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.l10n.noReviewsYet,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._reviews.map(_buildReviewCard),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildExamsTab() {
    if (_isLoadingExams) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primaryMap,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.loadingExam,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMaterialsCard(),
          const SizedBox(height: 16),
          if (_courseExams.isEmpty)
            _buildEmptyState(
                context.l10n.noTrialExamAvailable, Icons.quiz_rounded)
          else
            ..._courseExams.asMap().entries.map((entry) {
              final index = entry.key;
              final exam = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < _courseExams.length - 1 ? 16 : 0,
                ),
                child: _buildExamCard(exam, index),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMaterialsCard() {
    final flat = _getFlatLessonsList();
    final safeIndex =
        flat.isEmpty ? 0 : _selectedLessonIndex.clamp(0, flat.length - 1);
    final lessonTitle =
        flat.isEmpty ? null : flat[safeIndex]['title']?.toString();

    final contentPdf = _materialsContent?['content_pdf']?.toString().trim();
    final hasPdf = contentPdf != null && contentPdf.isNotEmpty;

    String normalizeUrl(String url) {
      final trimmed = url.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      if (trimmed.startsWith('/')) {
        return '${ApiEndpoints.imageBaseUrl}$trimmed';
      }
      return '${ApiEndpoints.imageBaseUrl}/$trimmed';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryMap.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_rounded,
                    color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.lessonMaterialsTitle,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      lessonTitle != null && lessonTitle.isNotEmpty
                          ? lessonTitle
                          : context.l10n.selectLessonForMaterials,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isLoadingMaterials)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryMap,
                  ),
                )
              else
                IconButton(
                  onPressed: _loadMaterialsForCurrentLesson,
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.primaryMap),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasPdf)
            Text(
              context.l10n.noPdfForCurrentLesson,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            GestureDetector(
              onTap: () {
                final pdfUrl = normalizeUrl(contentPdf);
                context.push(
                  RouteNames.pdfViewer,
                  extra: {
                    'pdfUrl': pdfUrl,
                    'title': context.l10n.pdfFileTitle,
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf,
                          color: Colors.red, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.pdfLessonSummary,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const Icon(Icons.preview_rounded,
                        color: AppColors.primaryMap, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam, int index) {
    final rawMaxAttempts =
        exam['max_attempts'] ?? exam['maxAttempts'] ?? exam['attempts_limit'];
    final rawAttemptsUsed = exam['attempts_used'] ??
        exam['attempts_count'] ??
        exam['attemptsCount'] ??
        0;
    final rawAttemptsLeft = exam['attempts_left'] ??
        exam['remaining_attempts'] ??
        exam['attemptsLeft'];
    final maxAttempts = rawMaxAttempts is num
        ? rawMaxAttempts.toInt()
        : int.tryParse(rawMaxAttempts?.toString() ?? '');
    final attemptsUsed = rawAttemptsUsed is num
        ? rawAttemptsUsed.toInt()
        : int.tryParse(rawAttemptsUsed.toString()) ?? 0;
    final attemptsLeft = rawAttemptsLeft is num
        ? rawAttemptsLeft.toInt()
        : int.tryParse(rawAttemptsLeft?.toString() ?? '');
    final inferredMaxAttempts = maxAttempts ??
        (attemptsLeft != null ? attemptsUsed + attemptsLeft : null);
    final attemptsExhausted = inferredMaxAttempts != null &&
        inferredMaxAttempts > 0 &&
        attemptsUsed >= inferredMaxAttempts;
    final canStart = exam['can_start'] == true && !attemptsExhausted;
    final isPassed = exam['is_passed'] == true;
    final bestScore = exam['best_score'];
    final questionsCount = exam['questions_count'] ?? 0;
    final durationMinutes = exam['duration_minutes'] ?? 15;
    final passingScore = exam['passing_score'] ?? 70;
    final examId = exam['id']?.toString() ?? '';
    final examTitle =
        context.localizedApiText(exam, 'title', fallback: context.l10n.exam);
    final examDescription = context.localizedApiText(exam, 'description');
    // Optional reward points for this exam
    final points = exam['points'] ??
        exam['reward_points'] ??
        exam['exam_points'] ??
        exam['score_points'];

    // Determine if it's a trial exam
    final isTrial = exam['type'] == 'trial' ||
        exam['type'] == 'trial_exam' ||
        examTitle.contains(context.l10n.trialExam) ||
        examTitle.contains('trial');

    return Container(
      margin: EdgeInsets.only(bottom: index < _courseExams.length - 1 ? 16 : 0),
      decoration: BoxDecoration(
        gradient: isTrial
            ? const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.primary, AppColors.primaryDark],
              )
            : null,
        color: isTrial ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isTrial
            ? null
            : Border.all(
                color: AppColors.primaryMap.withOpacity(0.2),
                width: 1,
              ),
        boxShadow: isTrial
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isTrial
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.primaryMap.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isTrial ? Icons.quiz_rounded : Icons.assignment_rounded,
                        size: 28,
                        color: isTrial ? Colors.white : AppColors.primaryMap,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            examTitle,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isTrial
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (examDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              examDescription,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: isTrial
                                    ? Colors.white.withOpacity(0.8)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Exam Info
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildExamInfoChip(
                      Icons.help_outline,
                      '$questionsCount ${context.l10n.question}',
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.primaryMap.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.primaryMap,
                    ),
                    _buildExamInfoChip(
                      Icons.access_time,
                      '$durationMinutes ${context.l10n.minute}',
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.primaryMap.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.primaryMap,
                    ),
                    _buildExamInfoChip(
                      Icons.star,
                      '$passingScore% ${context.l10n.passingLabel}',
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.primaryMap.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.primaryMap,
                    ),
                    if (inferredMaxAttempts != null && inferredMaxAttempts > 0)
                      _buildExamInfoChip(
                        Icons.repeat,
                        context.l10n.attemptsUsedLabel(
                            attemptsUsed, inferredMaxAttempts),
                        isTrial
                            ? Colors.white.withOpacity(0.3)
                            : AppColors.primaryMap.withOpacity(0.1),
                        isTrial ? Colors.white : AppColors.primaryMap,
                      ),
                    if (points != null && points is num && points > 0)
                      _buildExamInfoChip(
                        Icons.workspace_premium_rounded,
                        '$points ${context.l10n.pointsLabel}',
                        isTrial
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFF10B981).withOpacity(0.1),
                        isTrial ? Colors.white : const Color(0xFF10B981),
                      ),
                  ],
                ),
                if (inferredMaxAttempts != null && inferredMaxAttempts > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 16,
                        color: isTrial
                            ? Colors.white.withOpacity(0.9)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.attemptsUsedLabel(
                            attemptsUsed, inferredMaxAttempts),
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isTrial
                              ? Colors.white.withOpacity(0.95)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (bestScore != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? Colors.green.withOpacity(isTrial ? 0.3 : 0.1)
                          : Colors.orange.withOpacity(isTrial ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPassed ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: isTrial
                              ? Colors.white
                              : (isPassed ? Colors.green : Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPassed
                              ? context.l10n
                                  .bestScorePassed(bestScore.toString())
                              : context.l10n.bestScore(bestScore.toString()),
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isTrial
                                ? Colors.white
                                : (isPassed ? Colors.green : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: canStart ? () => _startExam(examId, exam) : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: canStart
                          ? (isTrial ? Colors.white : AppColors.primaryMap)
                          : (isTrial
                              ? Colors.white.withOpacity(0.5)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canStart
                              ? Icons.play_arrow_rounded
                              : Icons.lock_rounded,
                          color: canStart
                              ? (isTrial ? AppColors.primaryMap : Colors.white)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canStart
                              ? context.l10n.startExam
                              : (attemptsExhausted
                                  ? context.l10n.attemptsExhausted
                                  : context.l10n.notAvailable),
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: canStart
                                ? (isTrial
                                    ? AppColors.primaryMap
                                    : Colors.white)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamInfoChip(
    IconData icon,
    String text,
    Color bgColor, [
    Color? iconColor,
  ]) {
    final finalIconColor = iconColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: finalIconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: finalIconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryMap.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.primaryMap),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic>? course, bool isFree) {
    if (_isEnrolled) {
      return const SizedBox.shrink();
    }

    if (_isViewingOwnCourse) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_rounded, color: AppColors.primaryMap, size: 22),
              const SizedBox(width: 8),
              Text(
                context.l10n.youAreCourseInstructor,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryMap,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _isTogglingWishlist ? null : _toggleWishlist,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isTogglingWishlist
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.orange),
                        ),
                      )
                    : Icon(
                        _isInWishlist
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: AppColors.orange,
                        size: 24,
                      ),
              ),
            ),
            if (!_isEnrolled) ...[
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _isEnrolling
                      ? null
                      : () async {
                          final courseData = _courseData ?? course;

                          // If free course, enroll directly
                          if (isFree) {
                            await _enrollInCourse();
                          } else {
                            // If paid course, go to checkout
                            context.push(RouteNames.checkout,
                                extra: courseData);
                          }
                        },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _isEnrolling
                          ? null
                          : const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark
                              ],
                            ),
                      color: _isEnrolling ? Colors.grey[300] : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isEnrolling)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
                          )
                        else
                          Icon(
                            isFree
                                ? Icons.play_circle_rounded
                                : Icons.shopping_cart_rounded,
                            color: _isEnrolling ? Colors.grey : Colors.white,
                            size: 22,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          _isEnrolling
                              ? context.l10n.enrolling
                              : isFree
                                  ? context.l10n.enrollFree
                                  : context.l10n.enrollInCourse,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                _isEnrolling ? Colors.grey[600] : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _enrollInCourse() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isEnrolling = true);

    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📤 ENROLL REQUEST (enrollInCourse)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        final title = course['title']?.toString();
        if (title != null) {
          print('Course Title: $title');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      final enrollment = await CoursesService.instance.enrollInCourse(courseId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ ENROLLMENT RESPONSE (enrollInCourse)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${enrollment.runtimeType}');
        print('Response Keys: ${enrollment.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(enrollment));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $enrollment');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        enrollment.forEach((key, value) {
          print('  - $key: $value (${value.runtimeType})');
        });
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _isEnrolled = true;
        _isEnrolling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.enrolledSuccessfully,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      final firstLesson = _getFirstLesson();
      if (firstLesson != null && mounted) {
        _playLesson(0, firstLesson);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enrolling in course: $e');
      }

      setState(() => _isEnrolling = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? context.l10n.loginRequired
                  : context.l10n.errorEnrolling,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCourseExams() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isLoadingExams = true);

    try {
      final exams = await ExamsService.instance.getCourseExams(courseId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📝 COURSE EXAMS RESPONSE (getCourseExams)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${exams.runtimeType}');
        print('Total Exams: ${exams.length}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(exams));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $exams');
        }
        print('───────────────────────────────────────────────────────────');
        print('Exams Summary:');
        for (int i = 0; i < exams.length; i++) {
          final exam = exams[i];
          print('  Exam ${i + 1}:');
          print('    - ID: ${exam['id']}');
          print('    - Title: ${exam['title']}');
          print('    - Type: ${exam['type']}');
          print('    - Questions Count: ${exam['questions_count']}');
          print('    - Can Start: ${exam['can_start']}');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _courseExams = exams;
        _isLoadingExams = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ ERROR LOADING COURSE EXAMS');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('═══════════════════════════════════════════════════════════');
      }
      setState(() => _isLoadingExams = false);
    }
  }

  Future<void> _checkWishlistStatus() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      final wishlist = await WishlistService.instance.getWishlist();

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❤️ WISHLIST RESPONSE (getWishlist)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${wishlist.runtimeType}');
        print('Response Keys: ${wishlist.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(wishlist));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $wishlist');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        wishlist.forEach((key, value) {
          if (key == 'data' && value is List) {
            print('  - $key: List with ${value.length} items');
            for (int i = 0; i < value.length && i < 3; i++) {
              print('    Item $i: ${value[i]}');
            }
          } else {
            print('  - $key: $value (${value.runtimeType})');
          }
        });
        print('═══════════════════════════════════════════════════════════');
      }

      final items = wishlist['data'] as List?;

      if (items != null) {
        final isInWishlist = items.any((item) {
          final itemCourse = item['course'] as Map<String, dynamic>?;
          final itemCourseId =
              itemCourse?['id']?.toString() ?? item['course_id']?.toString();
          return itemCourseId == courseId;
        });

        if (kDebugMode) {
          print('Is Course in Wishlist: $isInWishlist');
        }

        if (mounted) {
          setState(() {
            _isInWishlist = isInWishlist;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ ERROR CHECKING WISHLIST STATUS');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('═══════════════════════════════════════════════════════════');
      }
      // Don't update state on error, keep current state
    }
  }

  Future<void> _toggleWishlist() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isTogglingWishlist = true);

    try {
      if (_isInWishlist) {
        if (kDebugMode) {
          print('═══════════════════════════════════════════════════════════');
          print('🗑️ REMOVING FROM WISHLIST');
          print('═══════════════════════════════════════════════════════════');
          print('Course ID: $courseId');
          print('═══════════════════════════════════════════════════════════');
        }
        await WishlistService.instance.removeFromWishlist(courseId);
        if (kDebugMode) {
          print('✅ Successfully removed from wishlist');
        }
      } else {
        if (kDebugMode) {
          print('═══════════════════════════════════════════════════════════');
          print('➕ ADDING TO WISHLIST');
          print('═══════════════════════════════════════════════════════════');
          print('Course ID: $courseId');
          print('═══════════════════════════════════════════════════════════');
        }
        await WishlistService.instance.addToWishlist(courseId);
        if (kDebugMode) {
          print('✅ Successfully added to wishlist');
        }
      }

      setState(() {
        _isInWishlist = !_isInWishlist;
        _isTogglingWishlist = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isInWishlist
                  ? context.l10n.addedToWishlist
                  : context.l10n.removedFromWishlist,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling wishlist: $e');
      }

      setState(() => _isTogglingWishlist = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? context.l10n.loginRequired
                  : context.l10n.errorWishlist(
                      _isInWishlist
                          ? context.l10n.removingFrom
                          : context.l10n.addingTo,
                    ),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startExam(
    String examId,
    Map<String, dynamic> examData, {
    Map<String, dynamic>? sourceLesson,
  }) async {
    if (examId.isEmpty) return;
    final rawMaxAttempts = examData['max_attempts'] ??
        examData['maxAttempts'] ??
        examData['attempts_limit'];
    final rawAttemptsUsed = examData['attempts_used'] ??
        examData['attempts_count'] ??
        examData['attemptsCount'] ??
        0;
    final rawAttemptsLeft = examData['attempts_left'] ??
        examData['remaining_attempts'] ??
        examData['attemptsLeft'];
    final maxAttempts = rawMaxAttempts is num
        ? rawMaxAttempts.toInt()
        : int.tryParse(rawMaxAttempts?.toString() ?? '');
    final attemptsUsed = rawAttemptsUsed is num
        ? rawAttemptsUsed.toInt()
        : int.tryParse(rawAttemptsUsed.toString()) ?? 0;
    final attemptsLeft = rawAttemptsLeft is num
        ? rawAttemptsLeft.toInt()
        : int.tryParse(rawAttemptsLeft?.toString() ?? '');
    final inferredMaxAttempts = maxAttempts ??
        (attemptsLeft != null ? attemptsUsed + attemptsLeft : null);
    final attemptsExhausted = inferredMaxAttempts != null &&
        inferredMaxAttempts > 0 &&
        attemptsUsed >= inferredMaxAttempts;
    final examUnavailable = examData['can_start'] != true;
    if (attemptsExhausted || examUnavailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              attemptsExhausted
                  ? context.l10n.attemptsExhausted
                  : context.l10n.notAvailable,
              style: GoogleFonts.cairo(),
            ),
          ),
        );
      }
      return;
    }

    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      // Start exam via API
      final examSession =
          await ExamsService.instance.startCourseExam(courseId, examId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('🚀 START EXAM RESPONSE (startExam)');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: $examId');
        print('Response Type: ${examSession.runtimeType}');
        print('Response Keys: ${examSession.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(examSession));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $examSession');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        examSession.forEach((key, value) {
          if (key == 'questions' && value is List) {
            print('  - $key: List with ${value.length} questions');
            for (int i = 0; i < value.length && i < 2; i++) {
              print('    Question $i: ${value[i]}');
            }
          } else {
            print('  - $key: $value (${value.runtimeType})');
          }
        });
        print('═══════════════════════════════════════════════════════════');
      }

      final questions = examSession['questions'] as List?;
      final attemptId = examSession['attempt_id']?.toString();

      if (questions == null || questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.noQuestionsAvailable,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrialExamScreen(
              examId: examId,
              courseId: courseId,
              attemptId: attemptId,
              courseName:
                  (_courseData ?? widget.course)?['title']?.toString() ??
                      context.l10n.course,
              examData: examData,
              examSession: examSession,
              onSubmitted: () async {
                await _loadCourseExams();
                if (sourceLesson != null) {
                  await _trackLessonProgress(
                    lesson: sourceLesson,
                    contentType: 'exam',
                    isCompleted: true,
                    completionRatio: 1.0,
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting exam: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? context.l10n.loginRequired
                  : context.l10n.errorStartingExam,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Video skeleton
              Container(
                height: 220,
                color: Colors.black,
              ),
              // Content skeleton
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header skeleton
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 80,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 24,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 24,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Tabs skeleton
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Lessons skeleton
                          ...List.generate(5, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageLessonViewerPage extends StatefulWidget {
  final String title;
  final List<String> imageUrls;

  const _ImageLessonViewerPage({
    required this.title,
    required this.imageUrls,
  });

  @override
  State<_ImageLessonViewerPage> createState() => _ImageLessonViewerPageState();
}

class _ImageLessonViewerPageState extends State<_ImageLessonViewerPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final imageUrl = widget.imageUrls[index];
              return Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryMap,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        context.l10n.noImageForLesson,
                        style: GoogleFonts.cairo(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${widget.imageUrls.length}',
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Trial Exam Screen
class TrialExamScreen extends StatefulWidget {
  final String examId;
  final String courseId;
  final String? attemptId;
  final String courseName;
  final Map<String, dynamic>? examData;
  final Map<String, dynamic>? examSession;
  final List<Map<String, dynamic>>? questions; // Fallback for static questions
  final VoidCallback? onSubmitted;

  const TrialExamScreen({
    super.key,
    required this.examId,
    required this.courseId,
    this.attemptId,
    required this.courseName,
    this.examData,
    this.examSession,
    this.questions,
    this.onSubmitted,
  });

  @override
  State<TrialExamScreen> createState() => _TrialExamScreenState();
}

class _TrialExamScreenState extends State<TrialExamScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, List<String>> _selectedAnswers =
      {}; // For multiple choice questions
  final Map<int, String?> _singleAnswers = {}; // For single choice questions
  bool _showResult = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _examResult;
  List<Map<String, dynamic>> _questions = [];
  String? _attemptId;

  String _resolveExamTitle(BuildContext context) {
    final examData = widget.examData;
    final title = examData?['title']?.toString().trim();
    final altTitle = examData?['name']?.toString().trim();
    final examTitle = examData?['exam_title']?.toString().trim();

    if (title != null && title.isNotEmpty) return title;
    if (altTitle != null && altTitle.isNotEmpty) return altTitle;
    if (examTitle != null && examTitle.isNotEmpty) return examTitle;
    return context.l10n.trialExam;
  }

  String _optionLabel(BuildContext context, int index) {
    const englishLabels = ['A', 'B', 'C', 'D'];
    const arabicLabels = ['أ', 'ب', 'ج', 'د'];
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final labels = isArabic ? arabicLabels : englishLabels;
    if (index >= 0 && index < labels.length) return labels[index];
    return (index + 1).toString();
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    // Get questions from exam session or use fallback
    if (widget.examSession != null &&
        widget.examSession!['questions'] != null) {
      final questions = widget.examSession!['questions'] as List;
      _questions = questions.map((q) => q as Map<String, dynamic>).toList();
      _attemptId =
          widget.examSession!['attempt_id']?.toString() ?? widget.attemptId;
    } else if (widget.questions != null) {
      _questions = List<Map<String, dynamic>>.from(widget.questions!);
    }

    // Initialize answers
    for (int i = 0; i < _questions.length; i++) {
      _singleAnswers[i] = null;
      _selectedAnswers[i] = [];
    }
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      final question = _questions[_currentQuestionIndex];

      // Check if multiple choice
      final isMultiple = question['is_multiple'] == true ||
          question['type'] == 'multiple_choice';

      if (isMultiple) {
        final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
        final optionId = question['options']?[optionIndex]?['id']?.toString() ??
            question['options']?[optionIndex]?['option_id']?.toString();

        if (selected.contains(optionId)) {
          selected.remove(optionId);
        } else {
          selected.add(optionId ?? optionIndex.toString());
        }
        _selectedAnswers[_currentQuestionIndex] = selected;
      } else {
        // Single choice
        final optionId = question['options']?[optionIndex]?['id']?.toString() ??
            question['options']?[optionIndex]?['option_id']?.toString();
        _singleAnswers[_currentQuestionIndex] =
            optionId ?? optionIndex.toString();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitExam();
    }
  }

  bool get _hasSelectedAnswer {
    final question = _questions[_currentQuestionIndex];
    final isMultiple = question['is_multiple'] == true ||
        question['type'] == 'multiple_choice';

    if (isMultiple) {
      final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
      return selected.isNotEmpty;
    } else {
      return _singleAnswers[_currentQuestionIndex] != null;
    }
  }

  Future<void> _submitExam() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // Prepare answers in API format
      final answers = <Map<String, dynamic>>[];

      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final questionId = question['id']?.toString() ??
            question['question_id']?.toString() ??
            'q_$i';

        final isMultiple = question['is_multiple'] == true ||
            question['type'] == 'multiple_choice';

        if (isMultiple) {
          final selected = _selectedAnswers[i] ?? [];
          answers.add({
            'question_id': questionId,
            'selected_options': selected,
          });
        } else {
          final selected = _singleAnswers[i];
          if (selected != null) {
            answers.add({
              'question_id': questionId,
              'selected_options': [selected],
            });
          }
        }
      }

      if (_attemptId == null || _attemptId!.isEmpty) {
        throw Exception(context.l10n.attemptIdMissing);
      }

      // Print answers before submission
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📤 SUBMITTING EXAM');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: ${widget.examId}');
        print('Attempt ID: $_attemptId');
        print('Total Questions: ${_questions.length}');
        print('Answers to Submit:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(answers));
        } catch (e) {
          print('Could not convert answers to JSON: $e');
          print('Raw Answers: $answers');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      final result = await ExamsService.instance.submitExam(
        widget.courseId,
        widget.examId,
        attemptId: _attemptId!,
        answers: answers,
      );

      // Refresh attempts/can_start in course exams list after submit.
      widget.onSubmitted?.call();

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ EXAM SUBMISSION RESPONSE (submitExam)');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: ${widget.examId}');
        print('Attempt ID: $_attemptId');
        print('Response Type: ${result.runtimeType}');
        print('Response Keys: ${result.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(result));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $result');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        result.forEach((key, value) {
          print('  - $key: $value (${value.runtimeType})');
        });
        print('───────────────────────────────────────────────────────────');
        print('Summary:');
        print('  - Score: ${result['score']}%');
        print('  - Is Passed: ${result['is_passed']}');
        print(
            '  - Correct Answers: ${result['correct_answers']}/${result['total_questions']}');
        if (result['time_taken_minutes'] != null) {
          print('  - Time Taken: ${result['time_taken_minutes']} minutes');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _examResult = result;
        _showResult = true;
        _isSubmitting = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error submitting exam: $e');
      }

      setState(() => _isSubmitting = false);

      final errorMessage = () {
        if (e is ApiException && e.message.isNotEmpty) {
          return e.message;
        }

        final message = e.toString();
        if (message.contains('401') ||
            message.toLowerCase().contains('unauthorized')) {
          return context.l10n.loginRequired;
        }

        return message.isNotEmpty ? message : context.l10n.errorSubmittingExam;
      }();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final examTitle = _resolveExamTitle(context);
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primaryMap,
          title: Text(
            examTitle,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primaryMap,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.loadingQuestions,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showResult) {
      return _buildResultScreen();
    }

    final question = _questions[_currentQuestionIndex];
    final options = question['options'] as List? ?? [];
    final isMultiple = question['is_multiple'] == true ||
        question['type'] == 'multiple_choice';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryMap,
        title: Text(
          examTitle,
          style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Text(
                '${_currentQuestionIndex + 1}/${_questions.length}',
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.questionNumber(_currentQuestionIndex + 1),
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryMap,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question['question']?.toString() ??
                        question['text']?.toString() ??
                        context.l10n.question,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Options
            ...List.generate(options.length, (index) {
              final option = options[index];
              final optionId = option['id']?.toString() ??
                  option['option_id']?.toString() ??
                  index.toString();

              bool isSelected = false;
              if (isMultiple) {
                final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
                isSelected = selected.contains(optionId);
              } else {
                isSelected = _singleAnswers[_currentQuestionIndex] == optionId;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _selectAnswer(index),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryMap.withOpacity(0.1)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryMap
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryMap
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isSelected && isMultiple
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : Text(
                                    _optionLabel(context, index),
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            option['text']?.toString() ??
                                option['option']?.toString() ??
                                option.toString(),
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primaryMap
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // Next Button
            GestureDetector(
              onTap:
                  (_hasSelectedAnswer && !_isSubmitting) ? _nextQuestion : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: (_hasSelectedAnswer && !_isSubmitting)
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark])
                      : null,
                  color: (!_hasSelectedAnswer || _isSubmitting)
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : Text(
                          _currentQuestionIndex == _questions.length - 1
                              ? context.l10n.finishExamButton
                              : context.l10n.next,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _hasSelectedAnswer
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    int score = 0;
    bool passed = false;
    int correctAnswers = 0;
    int totalQuestions = _questions.length;
    String? message;

    if (_examResult != null) {
      score = (_examResult!['score'] as num?)?.toInt() ?? 0;
      passed = _examResult!['is_passed'] == true;
      correctAnswers = _examResult!['correct_answers'] as int? ?? 0;
      totalQuestions =
          _examResult!['total_questions'] as int? ?? _questions.length;
      message = _examResult!['message']?.toString();
    } else {
      // Fallback calculation (should not happen if API works)
      score = 0;
      passed = false;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: passed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  message ??
                      (passed
                          ? '${context.l10n.excellent} 🎉'
                          : context.l10n.tryAgain),
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.yourScore(score),
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: passed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF97316),
                  ),
                ),
                Text(
                  context.l10n.correctAnswersSummary(
                    correctAnswers,
                    totalQuestions,
                  ),
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_examResult != null &&
                    _examResult!['time_taken_minutes'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.timeTaken(
                      (_examResult!['time_taken_minutes'] as num?)?.toInt() ??
                          0,
                    ),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        context.l10n.finish,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
