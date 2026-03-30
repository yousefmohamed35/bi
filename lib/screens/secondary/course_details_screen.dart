import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/localization/localization_helper.dart';
import '../../core/navigation/route_names.dart';
import '../../services/courses_service.dart';
import '../../services/exams_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../services/wishlist_service.dart';
import '../../services/profile_service.dart';

/// Modern Course Details Screen with Beautiful UI
class CourseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const CourseDetailsScreen({super.key, this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
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
    _tabController = TabController(length: 3, vsync: this);
    _loadCourseDetails();
    _checkWishlistStatus();
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
        _reviewsError = e.toString().replaceFirst('Exception: ', '');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
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
    return Row(
      children: List.generate(5, (i) {
        final v = i + 1;
        final selected = v <= _selectedReviewRating;
        return IconButton(
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
        ? (review['user'] as Map)['name']?.toString()
        : review['user_name']?.toString();
    final title = review['title']?.toString() ?? '';
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
    _tabController.dispose();
    _reviewTitleController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

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

  void _playLesson(int index, Map<String, dynamic> lesson) async {
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('▶️ NAVIGATING TO LESSON');
      print('═══════════════════════════════════════════════════════════');
      print('Lesson Index: $index');
      print('Lesson ID: ${lesson['id']}');
      print('Lesson Title: ${lesson['title']}');
      print('All Lesson Keys: ${lesson.keys.toList()}');
      print('═══════════════════════════════════════════════════════════');
    }

    setState(() {
      _selectedLessonIndex = index;
    });

    // Preload materials for "الاختبارات والمواد" tab (PDF/resources).
    _loadMaterialsForCurrentLesson();

    // Navigate to lesson viewer screen
    if (mounted) {
      final course = _courseData ?? widget.course;
      final courseId = course?['id']?.toString();
      context.push(RouteNames.lessonViewer, extra: {
        'lesson': lesson,
        'courseId': courseId,
      });
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

                    // Tabs
                    _buildTabs(),

                    // Tab Content
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAboutTab(course),
                          _buildLessonsTab(),
                          _buildExamsTab(),
                        ],
                      ),
                    ),
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
    // Get thumbnail image
    final thumbnail = course?['thumbnail']?.toString() ??
        course?['image']?.toString() ??
        course?['banner']?.toString();

    return Container(
      height: 220,
      color: Colors.black,
      child: Stack(
        children: [
          // Thumbnail Image
          if (thumbnail != null && thumbnail.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primaryMap.withOpacity(0.1),
                  child: const Center(
                    child: Icon(
                      Icons.image,
                      color: AppColors.primaryMap,
                      size: 50,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryMap,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              color: AppColors.primaryMap.withOpacity(0.1),
              child: const Center(
                child: Icon(
                  Icons.image,
                  color: AppColors.primaryMap,
                  size: 50,
                ),
              ),
            ),

          // Gradient Overlay
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

          // Play Button Overlay (if enrolled)
          if (_isEnrolled)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to first lesson
                    final firstLesson = _getFirstLesson();
                    if (firstLesson != null && mounted) {
                      final course = _courseData ?? widget.course;
                      final courseId = course?['id']?.toString();
                      context.push(RouteNames.lessonViewer, extra: {
                        'lesson': firstLesson,
                        'courseId': courseId,
                      });
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

          // Top Bar
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
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
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
                      child: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 20,
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

  Widget _buildCourseHeader(
      Map<String, dynamic>? course, bool isFree, num price) {
    if (course == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Badge & Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryMap.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  course['category'] is Map
                      ? (course['category'] as Map)['name']?.toString() ??
                          context.l10n.design
                      : course['category']?.toString() ?? context.l10n.design,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryMap,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isFree
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFF97316), const Color(0xFFEA580C)],
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

          // Title
          Text(
            course['title']?.toString() ?? context.l10n.courseTitle,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // Instructor
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
              Text(
                course['instructor'] is Map
                    ? (course['instructor'] as Map)['name']?.toString() ??
                        context.l10n.instructor
                    : course['instructor']?.toString() ??
                        context.l10n.instructor,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.primaryMap,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              _buildStatChip(
                Icons.star_rounded,
                _safeParseRating(course['rating']),
                Colors.amber,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.people_rounded,
                _safeParseCount(course['students_count'] ?? course['students']),
                AppColors.primaryMap,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.access_time_rounded,
                '${_safeParseHours(course['duration_hours'] ?? course['hours'])} ${context.l10n.hour}',
                const Color(0xFF10B981),
              ),
            ],
          ),
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

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.mutedForeground,
        labelStyle:
            GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 10),
        padding: const EdgeInsets.all(0),
        tabs: [
          Tab(text: context.l10n.about),
          Tab(text: context.l10n.lessonsAndChapters),
          Tab(text: context.l10n.examsAndMaterials),
        ],
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

  Widget _buildLessonsTab() {
    final course = _courseData ?? widget.course;
    // Try curriculum first, then lessons
    final curriculum = course?['curriculum'] as List?;
    final lessons = course?['lessons'] as List?;

    // Primary course info card shown before chapters/lessons
    final courseTitle = course?['title']?.toString() ?? '';
    final instructorName = (course?['instructor'] is Map)
        ? (course?['instructor']?['name']?.toString() ?? '')
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
            // This is a topic - add it even if it has no lessons
            final topicLessons = <Map<String, dynamic>>[];
            if (nestedLessons != null && nestedLessons.isNotEmpty) {
              for (var nestedLesson in nestedLessons) {
                if (nestedLesson is Map<String, dynamic>) {
                  topicLessons.add(nestedLesson);
                  // Add to flat list for indexing
                  flatLessonsList.add(nestedLesson);
                }
              }
            }
            // Add topic even if it has no lessons (empty array or null)
            topicsWithLessons.add({
              'is_topic': true,
              'topic': item,
              'lessons': topicLessons,
            });
          } else {
            // This item is a lesson itself (has video or id)
            if (hasVideo || item['id'] != null || hasYoutubeId) {
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

    // If no lessons from curriculum, use lessons directly
    if (topicsWithLessons.isEmpty && lessons != null && lessons.isNotEmpty) {
      for (var lesson in lessons) {
        if (lesson is Map<String, dynamic>) {
          flatLessonsList.add(lesson);
          topicsWithLessons.add({
            'is_topic': false,
            'lesson': lesson,
          });
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
      return ListView(
        padding: const EdgeInsets.all(20),
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: topicsWithLessons.length + 1,
      itemBuilder: (context, index) {
        // First item is the course summary square
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCourseSummaryCard(
                title: courseTitle,
                instructorName: instructorName,
                durationHours: durationHours,
                lessonsCount: totalLessonsCount,
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        final item = topicsWithLessons[index - 1];
        final isTopic = item['is_topic'] == true;

        if (isTopic) {
          // Render topic header with nested lessons
          final topic = item['topic'] as Map<String, dynamic>;
          final topicLessons = item['lessons'] as List<Map<String, dynamic>>;
          final topicTitle = topic['title']?.toString() ?? context.l10n.topic;
          final topicOrder = topic['order'] ?? index + 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Topic Header
              Container(
                margin: EdgeInsets.only(bottom: 12, top: index > 0 ? 16 : 0),
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
              // Nested Lessons
              ...topicLessons.map((lesson) {
                // Find global index for this lesson
                final globalIndex = flatLessonsList.indexWhere(
                    (l) => l['id']?.toString() == lesson['id']?.toString());
                final actualIndex = globalIndex >= 0 ? globalIndex : 0;

                return _buildLessonItem(lesson, actualIndex, flatLessonsList);
              }),
            ],
          );
        } else {
          // Render standalone lesson
          final lesson = item['lesson'] as Map<String, dynamic>;
          final globalIndex = flatLessonsList.indexWhere(
              (l) => l['id']?.toString() == lesson['id']?.toString());
          final actualIndex = globalIndex >= 0 ? globalIndex : 0;

          return _buildLessonItem(lesson, actualIndex, flatLessonsList);
        }
      },
    );
  }

  Widget _buildLessonItem(Map<String, dynamic> lesson, int index,
      List<Map<String, dynamic>> allLessons) {
    final isLocked = lesson['is_locked'] == true || lesson['locked'] == true;
    final isCompleted =
        lesson['is_completed'] == true || lesson['completed'] == true;
    final isSelected = index == _selectedLessonIndex;

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              _playLesson(index, lesson);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
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
        ),
        child: Row(
          children: [
            // Index/Status Circle
            Container(
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
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : isSelected
                          ? const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22)
                          : Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryMap,
                                ),
                              ),
                            ),
            ),
            const SizedBox(width: 14),

            // Lesson Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson['title']?.toString() ?? context.l10n.lesson,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isLocked
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
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

            // Play Icon
            if (!isLocked)
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
                  isSelected ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
    final description =
        courseData?['description']?.toString() ?? context.l10n.courseSuitable;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            context.l10n.whatYouWillGet,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        size: 18,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      feature['text'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              )),

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

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
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
    final canStart = exam['can_start'] == true;
    final isPassed = exam['is_passed'] == true;
    final bestScore = exam['best_score'];
    final questionsCount = exam['questions_count'] ?? 0;
    final durationMinutes = exam['duration_minutes'] ?? 15;
    final passingScore = exam['passing_score'] ?? 70;
    final maxAttempts = exam['max_attempts'] ?? exam['maxAttempts'];
    final attemptsUsed = exam['attempts_used'] ??
        exam['attempts_count'] ??
        exam['attemptsCount'] ??
        0;
    final examId = exam['id']?.toString() ?? '';
    final examTitle = exam['title']?.toString() ?? context.l10n.exam;
    final examDescription = exam['description']?.toString() ?? '';
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
                    if (maxAttempts != null)
                      _buildExamInfoChip(
                        Icons.repeat,
                        context.l10n
                            .attemptsUsedLabel(attemptsUsed, maxAttempts),
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
                              : (maxAttempts != null &&
                                      attemptsUsed >= maxAttempts
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
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _isEnrolling
                    ? null
                    : () async {
                        final courseData = _courseData ?? course;

                        // If already enrolled, go to first lesson
                        if (_isEnrolled) {
                          final firstLesson = _getFirstLesson();
                          if (firstLesson != null && mounted) {
                            final course = _courseData ?? widget.course;
                            final courseId = course?['id']?.toString();
                            context.push(RouteNames.lessonViewer, extra: {
                              'lesson': firstLesson,
                              'courseId': courseId,
                            });
                          }
                          return;
                        }

                        // If free course, enroll directly
                        if (isFree) {
                          await _enrollInCourse();
                        } else {
                          // If paid course, go to checkout
                          context.push(RouteNames.checkout, extra: courseData);
                        }
                      },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isEnrolling
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
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
                          _isEnrolled
                              ? Icons.play_circle_rounded
                              : isFree
                                  ? Icons.play_circle_rounded
                                  : Icons.shopping_cart_rounded,
                          color: _isEnrolling ? Colors.grey : Colors.white,
                          size: 22,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _isEnrolling
                            ? context.l10n.enrolling
                            : _isEnrolled
                                ? context.l10n.startLearningNow
                                : isFree
                                    ? context.l10n.enrollFree
                                    : context.l10n.enrollInCourse,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isEnrolling ? Colors.grey[600] : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

      // Navigate to first lesson if available
      final firstLesson = _getFirstLesson();
      if (firstLesson != null && mounted) {
        final course = _courseData ?? widget.course;
        final courseId = course?['id']?.toString();
        context.push(RouteNames.lessonViewer, extra: {
          'lesson': firstLesson,
          'courseId': courseId,
        });
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

  Future<void> _startExam(String examId, Map<String, dynamic> examData) async {
    if (examId.isEmpty) return;

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
              onSubmitted: _loadCourseExams,
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
        throw Exception('Attempt ID is missing');
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
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primaryMap,
          title: Text(
            context.l10n.trialExam,
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
          context.l10n.trialExam,
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
                                    String.fromCharCode(1571 + index),
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
