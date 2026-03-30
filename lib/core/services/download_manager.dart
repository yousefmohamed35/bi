import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class DownloadManager {
  static List<FileSystemEntity> files = [];
  static final Dio _dio = Dio();

  /// True if bytes look like a real media file (not HTML/JSON error pages).
  /// Used when reusing cached downloads and when cleaning the offline library.
  static Future<bool> isLikelyPlayableVideoFile(String filePath) async {
    return _looksLikePlayableVideo(filePath);
  }

  static bool _hasFtypBox(List<int> bytes) {
    const pat = [0x66, 0x74, 0x79, 0x70]; // 'ftyp'
    final limit = bytes.length < 65536 ? bytes.length : 65536;
    for (var i = 0; i <= limit - pat.length; i++) {
      var ok = true;
      for (var j = 0; j < pat.length; j++) {
        if (bytes[i + j] != pat[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  static Future<bool> _looksLikePlayableVideo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final length = await file.length();
      if (length < 1024) return false;

      final random = await file.open();
      final sampleSize = length < 65536 ? length : 65536;
      final bytes = await random.read(sampleSize);
      await random.close();

      if (bytes.isEmpty) return false;

      final ascii = String.fromCharCodes(bytes).toLowerCase();
      if (ascii.contains('<!doctype html') ||
          ascii.contains('<html') ||
          ascii.contains('{"message"') ||
          ascii.contains('"error"') ||
          ascii.contains('"status"')) {
        return false;
      }

      if (_hasFtypBox(bytes)) return true;

      final signature = String.fromCharCodes(bytes.take(16));
      if (signature.contains('ftyp')) return true;

      // Allow common video container signatures in case backend does not return mp4.
      if (bytes.length >= 4) {
        // Matroska/WebM
        if (bytes[0] == 0x1A &&
            bytes[1] == 0x45 &&
            bytes[2] == 0xDF &&
            bytes[3] == 0xA3) {
          return true;
        }
        // MPEG-TS packet
        if (bytes[0] == 0x47) return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _downloadAttempt({
    required String url,
    required String fullPath,
    required Function(int progress) onDownload,
    CancelToken? cancelToken,
    required Map<String, String> headers,
  }) async {
    final response = await _dio.download(
      url,
      fullPath,
      onReceiveProgress: (count, total) {
        if (total != -1 && total > 0) {
          int progress = (count / total * 100).clamp(0, 100).toInt();
          onDownload(progress);
          debugPrint('📥 Download progress: $progress%');
        } else if (total == -1 && count > 0) {
          final estimatedMb = count / (1024 * 1024);
          final progress = (estimatedMb / 20 * 100).clamp(0, 95).toInt();
          onDownload(progress);
          debugPrint('📥 Download progress (estimated): $progress%');
        }
      },
      cancelToken: cancelToken,
      options: Options(
        followRedirects: true,
        headers: headers,
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 10),
      ),
    );

    if (response.statusCode != 200) {
      debugPrint('❌ Download failed with status: ${response.statusCode}');
      return null;
    }

    final isPlayable = await _looksLikePlayableVideo(fullPath);
    if (!isPlayable) {
      debugPrint('❌ Downloaded payload is not a playable video: $fullPath');
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
      }
      return null;
    }

    debugPrint('✅ Download completed and validated: $fullPath');
    return fullPath;
  }

  static Future<String?> download(
    String url, {
    required Function(int progress) onDownload,
    CancelToken? cancelToken,
    String? name,
    Function? onLoadAtLocal,
    bool isOpen = true,
    String? authToken,
  }) async {
    try {
      // التحقق من الصلاحيات أولاً (بدون طلب)
      bool hasPermission = false;

      if (Platform.isAndroid) {
        // التحقق من الصلاحيات الموجودة
        final storageStatus = await Permission.storage.status;
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;

        hasPermission = storageStatus.isGranted ||
            photosStatus.isGranted ||
            videosStatus.isGranted;

        // إذا لم تكن الصلاحيات موجودة، نحاول طلبها
        if (!hasPermission) {
          debugPrint('📱 Checking storage permissions...');

          // طلب صلاحيات التخزين
          final storageStatusAfter = await Permission.storage.request();

          if (!storageStatusAfter.isGranted) {
            // محاولة طلب صلاحيات أخرى للأندرويد 13+
            final photosStatusAfter = await Permission.photos.request();
            final videosStatusAfter = await Permission.videos.request();

            hasPermission =
                photosStatusAfter.isGranted || videosStatusAfter.isGranted;
          } else {
            hasPermission = true;
          }
        }

        // حتى لو لم تكن الصلاحيات موجودة، يمكننا استخدام مجلد التطبيق الخاص
        // الذي لا يحتاج صلاحيات على Android 13+
        if (!hasPermission) {
          debugPrint(
              '⚠️ No storage permissions, but will use app directory (no permission needed)');
        } else {
          debugPrint('✅ Storage permissions granted');
        }
      } else {
        // iOS لا يحتاج صلاحيات لمجلد التطبيق
        hasPermission = true;
      }

      // الحصول على مسار التخزين الداخلي للتطبيق (لا يحتاج صلاحيات)
      String directory = (await getApplicationSupportDirectory()).path;
      String fileName = name ?? url.split('/').last;
      String fullPath = '$directory/$fileName';

      // Exact path only — old logic used substring matching and skipped validation,
      // so corrupt HTML/JSON "mp4" files from earlier builds were reused forever.
      final existing = File(fullPath);
      if (await existing.exists()) {
        final valid = await _looksLikePlayableVideo(fullPath);
        if (valid) {
          debugPrint('✅ File already exists and is valid video: $fullPath');
          if (onLoadAtLocal != null) {
            onLoadAtLocal(fullPath);
          }
          return fullPath;
        }
        debugPrint(
            '⚠️ Existing file is not playable (corrupt or old error payload); deleting: $fullPath');
        try {
          await existing.delete();
        } catch (e) {
          debugPrint('⚠️ Could not delete invalid file: $e');
        }
      }

      // تحميل الملف
      debugPrint('⬇️ Downloading file: $fileName...');

      Map<String, String> headers = {
        "Accept": "*/*",
      };

      if (authToken != null) {
        headers["Authorization"] = "Bearer $authToken";
      }

      try {
        final firstTry = await _downloadAttempt(
          url: url,
          fullPath: fullPath,
          onDownload: onDownload,
          cancelToken: cancelToken,
          headers: headers,
        );
        if (firstTry != null) return firstTry;

        // Some backends serve protected files only when token is passed as query param.
        if (authToken != null &&
            authToken.isNotEmpty &&
            !url.contains('token=')) {
          final uri = Uri.parse(url);
          final retryUrl = uri.replace(queryParameters: {
            ...uri.queryParameters,
            'token': authToken,
          }).toString();
          debugPrint('🔁 Retrying download with token query parameter...');
          final secondTry = await _downloadAttempt(
            url: retryUrl,
            fullPath: fullPath,
            onDownload: onDownload,
            cancelToken: cancelToken,
            headers: headers,
          );
          if (secondTry != null) return secondTry;
        }

        return null;
      } on DioException catch (e) {
        debugPrint('❌ Download error: ${e.message}');
        // حذف الملف الجزئي في حالة الفشل
        File file = File(fullPath);
        if (await file.exists()) {
          await file.delete();
        }
        return null;
      }
    } catch (e) {
      debugPrint('❌ Unexpected error during download: $e');
      return null;
    }
  }

  /// البحث عن ملف في المجلد
  static Future<bool> findFile(
    String directory,
    String name, {
    Function? onLoadAtLocal,
    bool isOpen = true,
  }) async {
    try {
      files = Directory(directory).listSync().toList();

      for (var i = 0; i < files.length; i++) {
        if (files[i].path.contains(name)) {
          debugPrint('✅ File found: ${files[i].path}');

          if (onLoadAtLocal != null) {
            onLoadAtLocal(files[i].path);
          }

          return true;
        }
      }

      debugPrint('🚫 File not found: $name');
      return false;
    } catch (e) {
      debugPrint('❌ Error searching for file: $e');
      return false;
    }
  }

  /// الحصول على مسار ملف محمل
  static Future<String?> getLocalFilePath(String fileName) async {
    try {
      String directory = (await getApplicationSupportDirectory()).path;
      List<FileSystemEntity> files = Directory(directory).listSync();

      for (var file in files) {
        if (file.path.contains(fileName)) {
          debugPrint('✅ Local file path: ${file.path}');
          return file.path;
        }
      }

      debugPrint('🚫 Local file not found: $fileName');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting local file path: $e');
      return null;
    }
  }

  /// حذف ملف محمل
  static Future<bool> deleteFile(String fileName) async {
    try {
      String directory = (await getApplicationSupportDirectory()).path;
      String fullPath = '$directory/$fileName';

      File file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ File deleted: $fullPath');
        return true;
      } else {
        debugPrint('🚫 File not found for deletion: $fullPath');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      return false;
    }
  }

  /// الحصول على حجم الملف بالـ MB
  static Future<double> getFileSize(String fileName) async {
    try {
      String directory = (await getApplicationSupportDirectory()).path;
      String fullPath = '$directory/$fileName';

      File file = File(fullPath);
      if (await file.exists()) {
        int bytes = await file.length();
        double mb = bytes / (1024 * 1024);
        debugPrint('📊 File size: ${mb.toStringAsFixed(2)} MB');
        return mb;
      } else {
        return 0.0;
      }
    } catch (e) {
      debugPrint('❌ Error getting file size: $e');
      return 0.0;
    }
  }

  /// الحصول على قائمة بجميع الملفات المحملة
  static Future<List<FileSystemEntity>> getAllDownloadedFiles() async {
    try {
      String directory = (await getApplicationSupportDirectory()).path;
      List<FileSystemEntity> files = Directory(directory).listSync();
      debugPrint('📁 Found ${files.length} downloaded files');
      return files;
    } catch (e) {
      debugPrint('❌ Error getting downloaded files: $e');
      return [];
    }
  }

  /// حذف جميع الملفات المحملة
  static Future<bool> deleteAllFiles() async {
    try {
      String directory = (await getApplicationSupportDirectory()).path;
      List<FileSystemEntity> files = Directory(directory).listSync();

      for (var file in files) {
        if (file is File) {
          await file.delete();
        }
      }

      debugPrint('✅ All files deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting all files: $e');
      return false;
    }
  }

  /// تحميل فيديو من رابط مباشر
  static Future<String?> downloadVideo(
    String url,
    String videoId,
    String videoTitle, {
    required Function(int progress) onProgress,
    String? authToken,
    CancelToken? cancelToken,
  }) async {
    // إنشاء اسم ملف فريد
    String fileName =
        'video_${videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    return await download(
      url,
      name: fileName,
      onDownload: onProgress,
      authToken: authToken,
      cancelToken: cancelToken,
      isOpen: false,
    );
  }

  /// التحقق من توفر المساحة الكافية
  static Future<bool> hasEnoughSpace(int requiredBytes) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // في الواقع يجب استخدام حزمة مثل disk_space للتحقق من المساحة المتاحة
        // هنا نفترض افتراضياً أن المساحة كافية
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error checking space: $e');
      return true;
    }
  }
}
