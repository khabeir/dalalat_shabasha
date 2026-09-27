import 'dart:convert';

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

  Future<SharedPreferences> get _prefs async {
    return SharedPreferences.getInstance();
  }

  // =========================================================
  // الإعلانات
  // =========================================================

  Future<void> saveListings(
    List<Map<String, dynamic>> listings,
  ) async {
    try {
      final prefs = await _prefs;

      final data = jsonEncode(listings);

      await prefs.setString(
        _listingsKey,
        data,
      );
    } catch (_) {
      // التخزين المحلي لا يجب أن يوقف التطبيق.
    }
  }

  Future<List<Map<String, dynamic>>> getListings() async {
    try {
      final prefs = await _prefs;

      final data = prefs.getString(_listingsKey);

      if (data == null || data.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(data);

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

  // =========================================================
  // التصنيفات
  // =========================================================

  Future<void> saveCategories(
    List<Map<String, dynamic>> categories,
  ) async {
    try {
      final prefs = await _prefs;

      final data = jsonEncode(categories);

      await prefs.setString(
        _categoriesKey,
        data,
      );
    } catch (_) {
      // تجاهل خطأ التخزين المحلي.
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final prefs = await _prefs;

      final data = prefs.getString(_categoriesKey);

      if (data == null || data.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(data);

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

  // =========================================================
  // الإعلانات المميزة
  // =========================================================

  Future<void> savePromotedListings(
    List<Map<String, dynamic>> listings,
  ) async {
    try {
      final prefs = await _prefs;

      final data = jsonEncode(listings);

      await prefs.setString(
        _promotedListingsKey,
        data,
      );
    } catch (_) {
      // تجاهل خطأ التخزين المحلي.
    }
  }

  Future<List<Map<String, dynamic>>>
      getPromotedListings() async {
    try {
      final prefs = await _prefs;

      final data =
          prefs.getString(_promotedListingsKey);

      if (data == null || data.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(data);

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

  // =========================================================
  // حذف الكاش
  // =========================================================

  Future<void> clearAll() async {
    try {
      final prefs = await _prefs;

      await prefs.remove(_listingsKey);
      await prefs.remove(_categoriesKey);
      await prefs.remove(
        _promotedListingsKey,
      );
    } catch (_) {
      // تجاهل الخطأ.
    }
  }
}
