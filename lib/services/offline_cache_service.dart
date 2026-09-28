import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  OfflineCacheService._();

  static final OfflineCacheService instance =
      OfflineCacheService._();

  static const String _listingsKey =
      'offline_listings_v1';

  static const String _categoriesKey =
      'offline_categories_v1';

  static const String _promotedListingsKey =
      'offline_promoted_listings_v1';

  // ============================================================
  // كاش مستقل لإعلانات المستخدم
  // ============================================================

  static const String _myListingsKey =
      'my_listings_v1';

  // مسارات الصور المحلية لإعلانات المستخدم.
  //
  // الشكل:
  // {
  //   "123": "/data/user/0/.../123.img",
  //   "456": "/data/user/0/.../456.img"
  // }
  static const String _myListingImagesKey =
      'my_listing_images_v1';

  Future<SharedPreferences> get _prefs async {
    return SharedPreferences.getInstance();
  }

  // ============================================================
  // الصفحة الرئيسية - الإعلانات
  // ============================================================

  Future<void> saveListings(
    List<Map<String, dynamic>> listings,
  ) async {
    final prefs = await _prefs;

    await prefs.setString(
      _listingsKey,
      jsonEncode(listings),
    );
  }

  Future<List<Map<String, dynamic>>> getListings() async {
    final prefs = await _prefs;

    final raw = prefs.getString(_listingsKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // التصنيفات
  // ============================================================

  Future<void> saveCategories(
    List<Map<String, dynamic>> categories,
  ) async {
    final prefs = await _prefs;

    await prefs.setString(
      _categoriesKey,
      jsonEncode(categories),
    );
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final prefs = await _prefs;

    final raw = prefs.getString(_categoriesKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // الإعلانات المميزة
  // ============================================================

  Future<void> savePromotedListings(
    List<Map<String, dynamic>> listings,
  ) async {
    final prefs = await _prefs;

    await prefs.setString(
      _promotedListingsKey,
      jsonEncode(listings),
    );
  }

  Future<List<Map<String, dynamic>>>
      getPromotedListings() async {
    final prefs = await _prefs;

    final raw = prefs.getString(
      _promotedListingsKey,
    );

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // إعلاناتي
  // ============================================================

  Future<void> saveMyListings(
    List<Map<String, dynamic>> listings,
  ) async {
    final prefs = await _prefs;

    await prefs.setString(
      _myListingsKey,
      jsonEncode(listings),
    );
  }

  Future<List<Map<String, dynamic>>> getMyListings() async {
    final prefs = await _prefs;

    final raw = prefs.getString(_myListingsKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearMyListings() async {
    final prefs = await _prefs;

    await prefs.remove(_myListingsKey);
  }

  // ============================================================
  // صور إعلاناتي - المسارات المحلية
  // ============================================================

  Future<void> saveMyListingImages(
    Map<String, String> imagePaths,
  ) async {
    final prefs = await _prefs;

    await prefs.setString(
      _myListingImagesKey,
      jsonEncode(imagePaths),
    );
  }

  Future<Map<String, String>> getMyListingImages() async {
    final prefs = await _prefs;

    final raw = prefs.getString(
      _myListingImagesKey,
    );

    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return {};
      }

      final result = <String, String>{};

      decoded.forEach((key, value) {
        if (key != null &&
            value != null &&
            value.toString().isNotEmpty) {
          result[key.toString()] =
              value.toString();
        }
      });

      return result;
    } catch (_) {
      return {};
    }
  }

  // ============================================================
  // مجلد صور إعلانات المستخدم
  // ============================================================

  Future<Directory> _getMyListingImagesDirectory() async {
    final baseDirectory =
        await getApplicationSupportDirectory();

    final directory = Directory(
      '${baseDirectory.path}/my_listings_images',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  // ============================================================
  // الحصول على مسار الصورة المحلية
  // ============================================================

  Future<String> getMyListingImagePath(
    String listingId,
  ) async {
    final directory =
        await _getMyListingImagesDirectory();

    return '${directory.path}/listing_$listingId.img';
  }

  // ============================================================
  // حفظ صورة إعلان على الهاتف
  // ============================================================

  Future<String?> saveMyListingImageBytes(
    String listingId,
    List<int> bytes,
  ) async {
    if (listingId.isEmpty || bytes.isEmpty) {
      return null;
    }

    try {
      final path =
          await getMyListingImagePath(listingId);

      final file = File(path);

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      return path;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // التأكد من وجود الصورة المحلية
  // ============================================================

  Future<bool> localMyListingImageExists(
    String? path,
  ) async {
    if (path == null || path.isEmpty) {
      return false;
    }

    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // حذف صورة إعلان واحدة من الهاتف
  // ============================================================

  Future<void> removeMyListingImage(
    String listingId,
  ) async {
    if (listingId.isEmpty) return;

    try {
      final paths =
          await getMyListingImages();

      final path = paths.remove(listingId);

      if (path != null &&
          path.isNotEmpty) {
        try {
          final file = File(path);

          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // لا نوقف العملية بسبب فشل حذف الملف.
        }
      }

      await saveMyListingImages(paths);
    } catch (_) {
      // الكاش ليس سببًا لإيقاف العملية الأساسية.
    }
  }

  // ============================================================
  // تنظيف الصور التي لم تعد مرتبطة بإعلانات موجودة
  // ============================================================

  Future<void> pruneMyListingImages(
    List<String> activeListingIds,
  ) async {
    try {
      final activeIds =
          activeListingIds.toSet();

      final paths =
          await getMyListingImages();

      final updatedPaths =
          <String, String>{};

      for (final entry in paths.entries) {
        if (activeIds.contains(entry.key)) {
          updatedPaths[entry.key] =
              entry.value;
          continue;
        }

        try {
          final file = File(entry.value);

          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // نتجاهل فشل حذف الملف.
        }
      }

      await saveMyListingImages(
        updatedPaths,
      );
    } catch (_) {
      // لا نوقف التطبيق بسبب الكاش.
    }
  }

  // ============================================================
  // حذف جميع صور إعلانات المستخدم
  // ============================================================

  Future<void> clearMyListingImages() async {
    try {
      final paths =
          await getMyListingImages();

      for (final path in paths.values) {
        try {
          final file = File(path);

          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // تجاهل خطأ حذف صورة واحدة.
        }
      }
    } catch (_) {
      // تجاهل أخطاء الكاش.
    }

    final prefs = await _prefs;

    await prefs.remove(
      _myListingImagesKey,
    );

    try {
      final directory =
          await _getMyListingImagesDirectory();

      if (await directory.exists()) {
        final files =
            await directory.list().toList();

        for (final entity in files) {
          try {
            if (entity is File) {
              await entity.delete();
            }
          } catch (_) {
            // تجاهل.
          }
        }
      }
    } catch (_) {
      // تجاهل.
    }
  }

  // ============================================================
  // حذف جميع بيانات الكاش
  // ============================================================

  Future<void> clearAll() async {
    final prefs = await _prefs;

    await prefs.remove(_listingsKey);
    await prefs.remove(_categoriesKey);
    await prefs.remove(_promotedListingsKey);
    await prefs.remove(_myListingsKey);

    await clearMyListingImages();
  }
}