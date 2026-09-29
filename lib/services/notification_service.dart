import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // =========================================================
  // المستخدم الحالي
  // =========================================================

  String? get currentUserId {
    return _supabase.auth.currentUser?.id;
  }

  bool get isSignedIn {
    return currentUserId != null;
  }

  // =========================================================
  // جلب الإشعارات
  // =========================================================

  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      return [];
    }

    final response = await _supabase
        .from('notifications')
        .select(
          'id, type, title, body, listing_id, category_id, is_read, created_at',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // =========================================================
  // عدد الإشعارات غير المقروءة
  // =========================================================

  Future<int> getUnreadCount() async {
    final userId = currentUserId;

    if (userId == null) {
      return 0;
    }

    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return response.length;
  }

  // =========================================================
  // تعليم إشعار واحد كمقروء
  // =========================================================

  Future<void> markAsRead(int notificationId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  // =========================================================
  // تعليم جميع الإشعارات كمقروءة
  // =========================================================

  Future<void> markAllAsRead() async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // =========================================================
// حذف إشعار واحد
// =========================================================

Future<void> deleteNotification(int notificationId) async {
  final userId = currentUserId;

  if (userId == null) {
    throw Exception('يجب تسجيل الدخول أولاً');
  }

  final deleted = await _supabase
      .from('notifications')
      .delete()
      .eq('id', notificationId)
      .eq('user_id', userId)
      .select('id');

  if (deleted.isEmpty) {
    throw Exception(
      'لم يتم حذف الإشعار. تحقق من صلاحيات RLS.',
    );
  }
}

// =========================================================
// حذف جميع الإشعارات
// =========================================================

Future<void> deleteAllNotifications() async {
  final userId = currentUserId;

  if (userId == null) {
    throw Exception('يجب تسجيل الدخول أولاً');
  }

  final deleted = await _supabase
      .from('notifications')
      .delete()
      .eq('user_id', userId)
      .select('id');

  if (deleted.isEmpty) {
    throw Exception(
      'لم يتم حذف الإشعارات. تحقق من صلاحيات RLS.',
    );
  }
}

  // =========================================================
  // جلب إعدادات الإشعارات
  // =========================================================

  Future<Map<String, dynamic>?> getNotificationSettings() async {
    final userId = currentUserId;

    if (userId == null) {
      return null;
    }

    final response = await _supabase
        .from('user_notification_settings')
        .select(
          'notifications_enabled, '
          'new_listings_enabled, '
          'featured_listings_enabled, '
          'admin_announcements_enabled',
        )
        .eq('user_id', userId)
        .maybeSingle();

    return response;
  }

  // =========================================================
  // إنشاء إعدادات افتراضية للمستخدم
  // =========================================================

  Future<Map<String, dynamic>> ensureNotificationSettings() async {
    final userId = currentUserId;

    if (userId == null) {
      return {
        'notifications_enabled': false,
        'new_listings_enabled': false,
        'featured_listings_enabled': false,
        'admin_announcements_enabled': false,
      };
    }

    final existing = await getNotificationSettings();

    if (existing != null) {
      return existing;
    }

    final response = await _supabase
        .from('user_notification_settings')
        .insert({
          'user_id': userId,
          'notifications_enabled': true,
          'new_listings_enabled': true,
          'featured_listings_enabled': true,
          'admin_announcements_enabled': true,
        })
        .select(
          'notifications_enabled, '
          'new_listings_enabled, '
          'featured_listings_enabled, '
          'admin_announcements_enabled',
        )
        .single();

    return response;
  }

  // =========================================================
  // تحديث الإعدادات العامة
  // =========================================================

  Future<void> updateNotificationSettings({
    bool? notificationsEnabled,
    bool? newListingsEnabled,
    bool? featuredListingsEnabled,
    bool? adminAnnouncementsEnabled,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await ensureNotificationSettings();

    final data = <String, dynamic>{};

    if (notificationsEnabled != null) {
      data['notifications_enabled'] = notificationsEnabled;
    }

    if (newListingsEnabled != null) {
      data['new_listings_enabled'] = newListingsEnabled;
    }

    if (featuredListingsEnabled != null) {
      data['featured_listings_enabled'] = featuredListingsEnabled;
    }

    if (adminAnnouncementsEnabled != null) {
      data['admin_announcements_enabled'] =
          adminAnnouncementsEnabled;
    }

    if (data.isEmpty) {
      return;
    }

    data['updated_at'] = DateTime.now().toIso8601String();

    await _supabase
        .from('user_notification_settings')
        .update(data)
        .eq('user_id', userId);
  }

  // =========================================================
  // جلب الأقسام المفعلة
  // =========================================================

  Future<List<int>> getEnabledCategoryIds() async {
    final userId = currentUserId;

    if (userId == null) {
      return [];
    }

    final response = await _supabase
        .from('notification_preferences')
        .select('category_id')
        .eq('user_id', userId)
        .eq('is_enabled', true);

    return response
        .map<int>((row) => (row['category_id'] as num).toInt())
        .toList();
  }

  // =========================================================
  // حفظ قسم
  // =========================================================

  Future<void> setCategoryNotification({
    required int categoryId,
    required bool enabled,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _supabase.from('notification_preferences').upsert(
      {
        'user_id': userId,
        'category_id': categoryId,
        'is_enabled': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,category_id',
    );
  }

  // =========================================================
  // حفظ عدة أقسام دفعة واحدة
  // =========================================================

  Future<void> saveCategoryNotifications(
    Map<int, bool> preferences,
  ) async {
    final userId = currentUserId;

    if (userId == null || preferences.isEmpty) {
      return;
    }

    final rows = preferences.entries.map((entry) {
      return {
        'user_id': userId,
        'category_id': entry.key,
        'is_enabled': entry.value,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    await _supabase.from('notification_preferences').upsert(
      rows,
      onConflict: 'user_id,category_id',
    );
  }

  // =========================================================
  // حذف تفضيل قسم
  // =========================================================

  Future<void> removeCategoryNotification(int categoryId) async {
    final userId = currentUserId;

    if (userId == null) {
      return;
    }

    await _supabase
        .from('notification_preferences')
        .delete()
        .eq('user_id', userId)
        .eq('category_id', categoryId);
  }
}
