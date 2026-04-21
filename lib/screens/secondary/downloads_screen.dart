import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/localization/localization_helper.dart';
import '../../services/video_download_service.dart';
import '../../models/download_model.dart';
import 'downloaded_video_player.dart';

/// Downloads Screen - Pixel-perfect match to React version
/// Matches: components/screens/downloads-screen.tsx
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  bool _isLoading = true;
  List<DownloadedVideoModel> _downloadedVideos = [];
  final VideoDownloadService _downloadService = VideoDownloadService();

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    await _downloadService.initialize();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);
    try {
      // تحميل الفيديوهات المحملة محلياً
      final videos = await _downloadService.getDownloadedVideosWithManager();

      // حساب إجمالي المساحة المستخدمة
      double totalSize = 0;
      for (var video in videos) {
        totalSize += video.fileSizeMb;
      }

      if (kDebugMode) {
        print('✅ Downloaded videos loaded:');
        print('  videos count: ${videos.length}');
        print('  total size: ${totalSize.toStringAsFixed(2)} MB');
      }

      setState(() {
        _downloadedVideos = videos;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading downloads: $e');
      }
      setState(() {
        _downloadedVideos = [];
        _isLoading = false;
      });
    }
  }

  String _formatSize(double sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(1)} GB';
    } else {
      return '${sizeMB.toStringAsFixed(0)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header - Purple gradient like Home
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.largeCard),
                    bottomRight: Radius.circular(AppRadius.largeCard),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16, // pt-4
                  bottom: 32, // pb-8
                  left: 16, // px-4
                  right: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button and title - matches React: gap-4 mb-4
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40, // w-10
                            height: 40, // h-10
                            decoration: const BoxDecoration(
                              color: AppColors.whiteOverlay20, // bg-white/20
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 20, // w-5 h-5
                            ),
                          ),
                        ),
                        const SizedBox(width: 16), // gap-4
                        Text(
                          context.l10n.downloads,
                          style: AppTextStyles.h3(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), // mb-4
                    // Download count - matches React: gap-2
                    Row(
                      children: [
                        Icon(
                          Icons.download,
                          size: 20, // w-5 h-5
                          color: Colors.white.withOpacity(0.7), // white/70
                        ),
                        const SizedBox(width: 8), // gap-2
                        Text(
                          context.l10n
                              .downloadedFiles(_downloadedVideos.length),
                          style: AppTextStyles.bodyMedium(
                            color: Colors.white.withOpacity(0.7), // white/70
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content below header with full-page scrolling
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    if (_isLoading) _buildLoadingState(context),
                    if (!_isLoading) ...[
                      // Downloaded Videos List
                      if (_downloadedVideos.isEmpty)
                        _buildEmptyState()
                      else
                        ..._downloadedVideos
                            .map((video) => _buildVideoCard(context, video)),
                    ],
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, DownloadedVideoModel video) {
    final title = video.title;
    final courseTitle = video.courseTitle;
    final sizeStr = _formatSize(video.fileSizeMb);
    final durationText =
        video.durationText.isNotEmpty ? video.durationText : 'غير محدد';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12), // space-y-3
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Course info row - matches React: flex items-center gap-4
          Row(
            children: [
              // Video icon - matches React: w-16 h-16 rounded-xl
              Container(
                width: 64, // w-16
                height: 64, // h-16
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                ),
                child: Icon(
                  Icons.video_library,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16), // gap-4

              // Course info - matches React: flex-1
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium(
                        color: colorScheme.onSurface,
                      ).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4), // mb-1
                    Text(
                      courseTitle,
                      style: AppTextStyles.labelSmall(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          durationText,
                          style: AppTextStyles.labelSmall(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: AppTextStyles.labelSmall(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sizeStr,
                          style: AppTextStyles.labelSmall(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              GestureDetector(
                onTap: () => _handleDelete(video),
                child: Container(
                  width: 40, // w-10
                  height: 40, // h-10
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                  ),
                  child: Icon(
                    Icons.delete,
                    size: 20, // w-5 h-5
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12), // mt-3

          // Play button - matches React: w-full py-3 rounded-xl bg-[var(--purple)]
          GestureDetector(
            onTap: () => _handlePlayOffline(video),
            child: Container(
              alignment: Alignment.center,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12), // py-3
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12), // rounded-xl
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: 20, // w-5 h-5
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8), // gap-2
                  Text(
                    context.l10n.watchOffline,
                    style: AppTextStyles.bodyMedium(
                      color: colorScheme.onPrimary,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePlayOffline(DownloadedVideoModel video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadedVideoPlayer(
          videoPath: video.localPath,
          videoTitle: video.title,
        ),
      ),
    );
  }

  Future<void> _handleDelete(DownloadedVideoModel video) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حذف الفيديو',
          style: GoogleFonts.cairo(),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا الفيديو؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _downloadService.deleteDownloadedVideo(video.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'تم حذف الفيديو بنجاح' : 'فشل حذف الفيديو',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Refresh the list
      _loadDownloads();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting video: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في حذف الفيديو: ${e.toString().replaceFirst('Exception: ', '')}',
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

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 150,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            ...List.generate(
                3,
                (index) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 200,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96, // w-24
            height: 96, // h-24
            decoration: const BoxDecoration(
              color: AppColors.lavenderLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download,
              size: 48, // w-12 h-12
              color: AppColors.primaryMap,
            ),
          ),
          const SizedBox(height: 16), // mb-4
          Text(
            context.l10n.noDownloads,
            style: AppTextStyles.h4(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8), // mb-2
          Text(
            context.l10n.downloadCoursesToWatchOffline,
            style: AppTextStyles.bodyMedium(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
