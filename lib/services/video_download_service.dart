import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../core/services/download_manager.dart';
import '../models/download_model.dart';
import '../services/token_storage_service.dart';

enum DownloadTrackingStatus { inProgress, completed, failed, cancelled }

class DownloadTrackingState {
  final String lessonId;
  final int progress;
  final DownloadTrackingStatus status;

  const DownloadTrackingState({
    required this.lessonId,
    required this.progress,
    required this.status,
  });
}

class _TrackedDownload {
  int progress;
  DownloadTrackingStatus status;
  final Future<void> Function() onCancel;

  _TrackedDownload({
    required this.progress,
    required this.status,
    required this.onCancel,
  });
}

class VideoDownloadService {
  static final VideoDownloadService _instance =
      VideoDownloadService._internal();
  factory VideoDownloadService() => _instance;
  VideoDownloadService._internal();

  static Database? _database;
  static const String _tableName = 'downloaded_videos';
  static final Map<String, _TrackedDownload> _trackedDownloads = {};
  static final StreamController<DownloadTrackingState> _trackingController =
      StreamController<DownloadTrackingState>.broadcast();

  // Initialize the download service
  Future<void> initialize() async {
    await _initializeDatabase();
  }

  String _sanitizeFileName(String input) {
    var sanitized = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) return 'video';
    // اختصار الاسم الطويل جداً
    if (sanitized.length > 60) {
      sanitized = sanitized.substring(0, 60);
    }
    return sanitized;
  }

  // Initialize local database for downloaded videos
  Future<void> _initializeDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'downloaded_videos.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          '''
          CREATE TABLE $_tableName(
            id TEXT PRIMARY KEY,
            lesson_id TEXT,
            course_id TEXT,
            course_title TEXT,
            title TEXT,
            description TEXT,
            video_url TEXT,
            local_path TEXT,
            file_size INTEGER,
            file_size_mb REAL,
            file_type TEXT,
            duration INTEGER,
            duration_text TEXT,
            video_source TEXT,
            downloaded_at TEXT,
            thumbnail_path TEXT
          )
          ''',
        );
      },
    );
  }

  /// Offline videos are written only to the app sandbox (see [DownloadManager]). No READ_MEDIA_*,
  /// legacy storage, or MANAGE_EXTERNAL_STORAGE is required.
  Future<bool> requestPermission() async => true;

  /// See [requestPermission] — always allowed because downloads never use shared external storage.
  Future<bool> hasStoragePermission() async => true;

  Stream<DownloadTrackingState> watchTrackedDownload(String lessonId) {
    return _trackingController.stream
        .where((state) => state.lessonId == lessonId);
  }

  DownloadTrackingState? getTrackedDownloadState(String lessonId) {
    final task = _trackedDownloads[lessonId];
    if (task == null) return null;
    return DownloadTrackingState(
      lessonId: lessonId,
      progress: task.progress,
      status: task.status,
    );
  }

  void startTrackingDownload({
    required String lessonId,
    required Future<void> Function() onCancel,
  }) {
    _trackedDownloads[lessonId] = _TrackedDownload(
      progress: 0,
      status: DownloadTrackingStatus.inProgress,
      onCancel: onCancel,
    );
    _trackingController.add(
      DownloadTrackingState(
        lessonId: lessonId,
        progress: 0,
        status: DownloadTrackingStatus.inProgress,
      ),
    );
  }

  void updateTrackedDownloadProgress(String lessonId, int progress) {
    final task = _trackedDownloads[lessonId];
    if (task == null || task.status != DownloadTrackingStatus.inProgress) {
      return;
    }

    final safeProgress = progress.clamp(0, 100);
    task.progress = safeProgress;
    _trackingController.add(
      DownloadTrackingState(
        lessonId: lessonId,
        progress: safeProgress,
        status: DownloadTrackingStatus.inProgress,
      ),
    );
  }

  void completeTrackedDownload(String lessonId) {
    _trackedDownloads.remove(lessonId);
    _trackingController.add(
      DownloadTrackingState(
        lessonId: lessonId,
        progress: 100,
        status: DownloadTrackingStatus.completed,
      ),
    );
  }

  void failTrackedDownload(String lessonId) {
    _trackedDownloads.remove(lessonId);
    _trackingController.add(
      DownloadTrackingState(
        lessonId: lessonId,
        progress: 0,
        status: DownloadTrackingStatus.failed,
      ),
    );
  }

  Future<void> cancelTrackedDownload(String lessonId) async {
    final task = _trackedDownloads.remove(lessonId);
    if (task == null) return;

    await task.onCancel();
    _trackingController.add(
      DownloadTrackingState(
        lessonId: lessonId,
        progress: task.progress,
        status: DownloadTrackingStatus.cancelled,
      ),
    );
  }

  /// تحميل فيديو باستخدام DownloadManager
  Future<String?> downloadVideoWithManager({
    required String videoUrl,
    required String lessonId,
    required String courseId,
    required String title,
    String? courseTitle,
    String? description,
    double? fileSizeMb,
    String? durationText,
    String? videoSource,
    Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      print('🎬 Starting video download with DownloadManager');
      print('Video URL: $videoUrl');
      print('Lesson ID: $lessonId');

      // الحصول على token للمصادقة
      final token = await TokenStorageService.instance.getAccessToken();

      // إنشاء اسم ملف فريد يعتمد على اسم الكورس واسم الدرس
      final safeCourseTitle =
          _sanitizeFileName(courseTitle ?? 'course_$courseId');
      final safeLessonTitle = _sanitizeFileName(title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${safeCourseTitle}_${safeLessonTitle}_$timestamp.mp4';

      // تحميل الفيديو باستخدام DownloadManager
      String? localPath = await DownloadManager.download(
        videoUrl,
        name: fileName,
        onDownload: (progress) {
          print('Download progress: $progress%');
          // استدعاء callback التقدم إذا كان موجوداً
          if (onProgress != null) {
            onProgress(progress);
          }
        },
        isOpen: false,
        authToken: token,
        cancelToken: cancelToken,
      );

      if (localPath != null) {
        log(localPath);
        //print('✅ Video downloaded successfully to: $localPath');

        // حفظ معلومات الفيديو في قاعدة البيانات
        String videoId = DateTime.now().millisecondsSinceEpoch.toString();

        await _database?.insert(
          _tableName,
          {
            'id': videoId,
            'lesson_id': lessonId,
            'course_id': courseId,
            'course_title': courseTitle ?? 'كورس $courseId',
            'title': title,
            'description': description ?? '',
            'video_url': videoUrl,
            'local_path': localPath,
            'file_size': 0, // سيتم حسابه لاحقاً
            'file_size_mb': fileSizeMb ?? 0.0,
            'file_type': 'video/mp4',
            'duration': 0,
            'duration_text': durationText ?? '',
            'video_source': videoSource ?? 'server',
            'downloaded_at': DateTime.now().toIso8601String(),
            'thumbnail_path': '',
          },
        );

        print('✅ Video info saved to database');
        return videoId;
      } else {
        print('❌ Video download failed');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading video with DownloadManager: $e');
      return null;
    }
  }

  /// حفظ فيديو تم تحميله مسبقاً (مثلاً من YouTube) في قاعدة البيانات
  Future<String?> saveDownloadedVideoRecord({
    required String lessonId,
    required String courseId,
    required String title,
    required String videoUrl,
    required String localPath,
    String? courseTitle,
    String? description,
    double? fileSizeMb,
    String? durationText,
    String videoSource = 'server',
  }) async {
    try {
      if (_database == null) {
        await _initializeDatabase();
      }

      final videoId = DateTime.now().millisecondsSinceEpoch.toString();

      await _database?.insert(
        _tableName,
        {
          'id': videoId,
          'lesson_id': lessonId,
          'course_id': courseId,
          'course_title': courseTitle ?? 'كورس $courseId',
          'title': title,
          'description': description ?? '',
          'video_url': videoUrl,
          'local_path': localPath,
          'file_size': 0,
          'file_size_mb': fileSizeMb ?? 0.0,
          'file_type': 'video/mp4',
          'duration': 0,
          'duration_text': durationText ?? '',
          'video_source': videoSource,
          'downloaded_at': DateTime.now().toIso8601String(),
          'thumbnail_path': '',
        },
      );

      print('✅ External video info saved to database (source: $videoSource)');
      return videoId;
    } catch (e) {
      print('❌ Error saving downloaded video record: $e');
      return null;
    }
  }

  /// الحصول على معلومات التحميل من API
  Future<DownloadData?> getDownloadInfo(String lessonId) async {
    try {
      // TODO: إضافة endpoint للتحميل في API إذا كان موجوداً
      // حالياً سنستخدم lesson content للحصول على معلومات الفيديو
      // يمكن تعديل هذا لاحقاً إذا كان هناك endpoint مخصص للتحميل

      // يمكن إضافة endpoint مثل: ApiEndpoints.downloadLesson(lessonId)
      return null;
    } catch (e) {
      print('❌ Error getting download info: $e');
      return null;
    }
  }

  /// التحقق من وجود ملف محمل مسبقاً
  Future<String?> checkLocalVideoFile(String lessonId) async {
    // البحث في قاعدة البيانات أولاً
    final result = await _database?.query(
      _tableName,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );

    if (result?.isNotEmpty ?? false) {
      final localPath = result!.first['local_path'] as String;

      // التحقق من وجود الملف فعلياً وأنه ليس ملف HTML/JSON محفوظاً كـ .mp4
      final file = File(localPath);
      if (await file.exists()) {
        if (!await DownloadManager.isLikelyPlayableVideoFile(localPath)) {
          print(
              '🚫 Local video file is not playable (corrupt/old), cleaning: $localPath');
          try {
            await file.delete();
          } catch (_) {}
          await _database?.delete(
            _tableName,
            where: 'lesson_id = ?',
            whereArgs: [lessonId],
          );
          return null;
        }
        print('✅ Local video file exists: $localPath');
        return localPath;
      } else {
        print('🚫 Local video file not found, cleaning database entry');
        // حذف السجل من قاعدة البيانات إذا كان الملف غير موجود
        await _database?.delete(
          _tableName,
          where: 'lesson_id = ?',
          whereArgs: [lessonId],
        );
      }
    }

    return null;
  }

  /// الحصول على جميع الفيديوهات المحملة
  Future<List<DownloadedVideoModel>> getDownloadedVideosWithManager() async {
    try {
      print('Getting downloaded videos from database...');

      if (_database == null) {
        await _initializeDatabase();
      }

      final results = await _database?.query(_tableName);

      if (results == null || results.isEmpty) {
        print('No downloaded videos found in database');
        return [];
      }

      print('Found ${results.length} videos in database');

      List<DownloadedVideoModel> videos = [];

      for (final row in results) {
        final localPath = row['local_path'] as String;
        final file = File(localPath);

        // التحقق من وجود الملف وأنه فيديو حقيقي (ليس صفحة خطأ محفوظة كـ mp4)
        if (await file.exists()) {
          if (!await DownloadManager.isLikelyPlayableVideoFile(localPath)) {
            print(
                '🚫 Video file not playable, removing file + DB row: $localPath');
            try {
              await file.delete();
            } catch (_) {}
            await _database?.delete(
              _tableName,
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            continue;
          }
          print('✅ Video file exists: $localPath');

          // حساب حجم الملف الفعلي
          int fileSize = await file.length();
          double fileSizeMb = fileSize / (1024 * 1024);

          videos.add(DownloadedVideoModel(
            id: row['id'] as String,
            lessonId: row['lesson_id'] as String,
            courseId: row['course_id'] as String,
            courseTitle:
                row['course_title'] as String? ?? 'كورس ${row['course_id']}',
            title: row['title'] as String,
            description: row['description'] as String,
            videoUrl: row['video_url'] as String,
            localPath: localPath,
            fileSize: fileSize,
            fileSizeMb: fileSizeMb,
            fileType: row['file_type'] as String,
            duration: row['duration'] as int,
            durationText: row['duration_text'] as String,
            videoSource: row['video_source'] as String,
            downloadedAt: DateTime.parse(row['downloaded_at'] as String),
            thumbnailPath: row['thumbnail_path'] as String? ?? '',
          ));
        } else {
          print('🚫 Video file not found, removing from database: $localPath');
          // حذف السجل إذا كان الملف غير موجود
          await _database?.delete(
            _tableName,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }

      print('Returning ${videos.length} valid videos');
      return videos;
    } catch (e) {
      print('Error getting downloaded videos: $e');
      return [];
    }
  }

  /// حذف فيديو محمل
  Future<bool> deleteDownloadedVideo(String videoId) async {
    try {
      // الحصول على معلومات الفيديو من قاعدة البيانات
      final result = await _database?.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [videoId],
        limit: 1,
      );

      if (result?.isNotEmpty ?? false) {
        final localPath = result!.first['local_path'] as String;
        final fileName = localPath.split('/').last;

        // حذف الملف من التخزين
        await DownloadManager.deleteFile(fileName);

        // حذف السجل من قاعدة البيانات
        await _database?.delete(
          _tableName,
          where: 'id = ?',
          whereArgs: [videoId],
        );

        print('✅ Video deleted successfully');
        return true;
      } else {
        print('🚫 Video not found in database');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting video: $e');
      return false;
    }
  }

  Future<void> updateLocalPath({
    required String videoId,
    required String localPath,
    String? fileType,
  }) async {
    await _database?.update(
      _tableName,
      {
        'local_path': localPath,
        if (fileType != null) 'file_type': fileType,
      },
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<String?> getLocalPathByVideoId(String videoId) async {
    final result = await _database?.query(
      _tableName,
      columns: ['local_path'],
      where: 'id = ?',
      whereArgs: [videoId],
      limit: 1,
    );
    if (result == null || result.isEmpty) return null;
    return result.first['local_path'] as String?;
  }

  /// التحقق من أن الفيديو محمل
  Future<bool> isVideoDownloaded(String lessonId) async {
    final result = await _database?.query(
      _tableName,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );

    if (result?.isNotEmpty ?? false) {
      final localPath = result!.first['local_path'] as String;
      final file = File(localPath);
      if (!await file.exists()) return false;
      if (!await DownloadManager.isLikelyPlayableVideoFile(localPath)) {
        await _database?.delete(
          _tableName,
          where: 'lesson_id = ?',
          whereArgs: [lessonId],
        );
        try {
          await file.delete();
        } catch (_) {}
        return false;
      }
      return true;
    }

    return false;
  }
}
