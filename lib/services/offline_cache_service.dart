import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  OfflineCacheService._();

  static final OfflineCacheService instance = OfflineCacheService._();

  static const String _listingsKey = 'offline_listings_v1';
  static const String _categoriesKey = 'offline_categories_v1';
  static const String _promotedListingsKey =
      'offline_promoted_listings_v1';

  // كاش مستقل لإعلانات المستخدم.
  static const String _myListingsKey = 'my_listings_v1';

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
  // حذف جميع بيانات الكاش
  // ============================================================

  Future<void> clearAll() async {
    final prefs = await _prefs;

    await prefs.remove(_listingsKey);
    await prefs.remove(_categoriesKey);
    await prefs.remove(_promotedListingsKey);
    await prefs.remove(_myListingsKey);
  }
}