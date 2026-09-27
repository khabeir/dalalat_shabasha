import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService =
      NotificationService.instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  bool _notificationsEnabled = true;
  bool _newListingsEnabled = true;
  bool _featuredListingsEnabled = true;
  bool _adminAnnouncementsEnabled = true;

  List<Map<String, dynamic>> _categories = [];
  final Map<int, bool> _categoryPreferences = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!_notificationService.isSignedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final userId = _notificationService.currentUserId!;

      // تحميل الإعدادات العامة.
      final settings =
          await _notificationService.ensureNotificationSettings();

      // تحميل التصنيفات النشطة.
      final categoriesResponse = await _supabase
          .from('categories')
          .select('id, name, icon, sort_order, is_active')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      // تحميل إعدادات التصنيفات الخاصة بالمستخدم.
      final preferencesResponse = await _supabase
          .from('notification_preferences')
          .select('category_id, is_enabled')
          .eq('user_id', userId);

      final categories = List<Map<String, dynamic>>.from(
        categoriesResponse,
      );

      final preferences = List<Map<String, dynamic>>.from(
        preferencesResponse,
      );

      final hasSavedCategoryPreferences = preferences.isNotEmpty;

      final savedPreferences = <int, bool>{};

      for (final row in preferences) {
        final categoryId = (row['category_id'] as num).toInt();
        savedPreferences[categoryId] = row['is_enabled'] == true;
      }

      final categoryPreferences = <int, bool>{};

      for (final category in categories) {
        final categoryId = (category['id'] as num).toInt();

        if (hasSavedCategoryPreferences) {
          // إذا كانت هناك إعدادات محفوظة، نستخدمها.
          // التصنيفات غير الموجودة تعتبر غير مفعلة.
          categoryPreferences[categoryId] =
              savedPreferences[categoryId] ?? false;
        } else {
          // المستخدم لأول مرة:
          // جميع التصنيفات مفعلة افتراضياً.
          categoryPreferences[categoryId] = true;
        }
      }

      if (!mounted) return;

      setState(() {
        _notificationsEnabled =
            settings['notifications_enabled'] == true;

        _newListingsEnabled =
            settings['new_listings_enabled'] == true;

        _featuredListingsEnabled =
            settings['featured_listings_enabled'] == true;

        _adminAnnouncementsEnabled =
            settings['admin_announcements_enabled'] == true;

        _categories = categories;

        _categoryPreferences
          ..clear()
          ..addAll(categoryPreferences);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('تعذر تحميل إعدادات الإشعارات');
    }
  }

  Future<void> _saveSettings() async {
    if (!_notificationService.isSignedIn) {
      _showError('يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // حفظ الإعدادات العامة.
      await _notificationService.updateNotificationSettings(
        notificationsEnabled: _notificationsEnabled,
        newListingsEnabled: _newListingsEnabled,
        featuredListingsEnabled: _featuredListingsEnabled,
        adminAnnouncementsEnabled: _adminAnnouncementsEnabled,
      );

      // حفظ إعدادات التصنيفات.
      if (_categoryPreferences.isNotEmpty) {
        await _notificationService.saveCategoryNotifications(
          _categoryPreferences,
        );
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ إعدادات الإشعارات بنجاح ✓',
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showError('تعذر حفظ الإعدادات، حاول مرة أخرى');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setAllCategories(bool enabled) {
    setState(() {
      for (final category in _categories) {
        final categoryId = (category['id'] as num).toInt();
        _categoryPreferences[categoryId] = enabled;
      }
    });
  }

  bool get _allCategoriesEnabled {
    if (_categories.isEmpty) return false;

    return _categories.every((category) {
      final categoryId = (category['id'] as num).toInt();
      return _categoryPreferences[categoryId] == true;
    });
  }

  bool get _someCategoriesEnabled {
    return _categories.any((category) {
      final categoryId = (category['id'] as num).toInt();
      return _categoryPreferences[categoryId] == true;
    });
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 4,
        left: 4,
        bottom: 10,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainNotificationCard() {
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            activeThumbColor: AppColors.brand,
            title: const Text(
              'تفعيل الإشعارات',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              _notificationsEnabled
                  ? 'الإشعارات مفعلة حالياً'
                  : 'تم إيقاف جميع الإشعارات',
              style: TextStyle(
                fontSize: 11,
                color: _notificationsEnabled
                    ? Colors.grey.shade600
                    : Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            secondary: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _notificationsEnabled
                    ? AppColors.brandSoft
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _notificationsEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: _notificationsEnabled
                    ? AppColors.brand
                    : Colors.grey,
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 3,
            ),
            value: _newListingsEnabled,
            onChanged: !_notificationsEnabled
                ? null
                : (value) {
                    setState(() {
                      _newListingsEnabled = value;
                    });
                  },
            activeThumbColor: AppColors.brand,
            title: const Text(
              'الإعلانات الجديدة',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            subtitle: const Text(
              'تنبيه عند إضافة إعلان جديد',
              style: TextStyle(
                fontSize: 10.5,
              ),
            ),
            secondary: const Icon(
              Icons.fiber_new_rounded,
              color: AppColors.brand,
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 3,
            ),
            value: _featuredListingsEnabled,
            onChanged: !_notificationsEnabled
                ? null
                : (value) {
                    setState(() {
                      _featuredListingsEnabled = value;
                    });
                  },
            activeThumbColor: AppColors.orange,
            title: const Text(
              'الإعلانات المميزة',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            subtitle: const Text(
              'تنبيه عند تمييز إعلان',
              style: TextStyle(
                fontSize: 10.5,
              ),
            ),
            secondary: const Icon(
              Icons.star_rounded,
              color: AppColors.orange,
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 3,
            ),
            value: _adminAnnouncementsEnabled,
            onChanged: !_notificationsEnabled
                ? null
                : (value) {
                    setState(() {
                      _adminAnnouncementsEnabled = value;
                    });
                  },
            activeThumbColor: AppColors.brand,
            title: const Text(
              'إعلانات وتنبيهات الإدارة',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            subtitle: const Text(
              'رسائل وتنبيهات مهمة من إدارة التطبيق',
              style: TextStyle(
                fontSize: 10.5,
              ),
            ),
            secondary: const Icon(
              Icons.campaign_rounded,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    if (_categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.card(),
        child: Column(
          children: [
            Icon(
              Icons.category_outlined,
              size: 42,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              'لا توجد تصنيفات متاحة حالياً',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Opacity(
      opacity: _notificationsEnabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !_notificationsEnabled,
        child: Container(
          decoration: AppDecorations.card(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            color: AppColors.brand,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'التصنيفات',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _setAllCategories(
                          !_allCategoriesEnabled,
                        );
                      },
                      child: Text(
                        _allCategoriesEnabled
                            ? 'إلغاء الكل'
                            : 'تفعيل الكل',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_someCategoriesEnabled)
                Padding(
                  padding: const EdgeInsets.only(
                    right: 16,
                    left: 16,
                    bottom: 8,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'لم يتم اختيار أي تصنيف للإشعارات.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ...List.generate(
                _categories.length,
                (index) {
                  final category = _categories[index];
                  final categoryId =
                      (category['id'] as num).toInt();

                  final categoryName =
                      category['name']?.toString() ?? 'تصنيف';

                  final iconText =
                      category['icon']?.toString().trim() ?? '';

                  final enabled =
                      _categoryPreferences[categoryId] ?? false;

                  return Column(
                    children: [
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey.shade200,
                        ),
                      SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        value: enabled,
                        onChanged: (value) {
                          setState(() {
                            _categoryPreferences[categoryId] =
                                value;
                          });
                        },
                        activeThumbColor: AppColors.brand,
                        title: Text(
                          categoryName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        subtitle: const Text(
                          'استقبال الإعلانات الجديدة لهذا التصنيف',
                          style: TextStyle(
                            fontSize: 10,
                          ),
                        ),
                        secondary: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: iconText.isNotEmpty
                              ? Text(
                                  iconText,
                                  style: const TextStyle(
                                    fontSize: 20,
                                  ),
                                )
                              : const Icon(
                                  Icons.category_rounded,
                                  color: AppColors.brand,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.softCard(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.brand,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الإشعارات هنا تظهر داخل تطبيق دلالة شبشة. '
              'يمكنك اختيار نوع الإشعارات والتصنيفات التي تريد متابعتها.',
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: AppColors.ink.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إعدادات الإشعارات',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.pageBackground,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brand,
              ),
            )
          : !_notificationService.isSignedIn
              ? _buildLoginRequired()
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.brand,
                          onRefresh: _loadSettings,
                          child: ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              10,
                              16,
                              20,
                            ),
                            children: [
                              _buildInfoCard(),
                              const SizedBox(height: 22),

                              _buildSectionTitle(
                                icon:
                                    Icons.notifications_active_rounded,
                                title: 'الإشعارات العامة',
                                subtitle:
                                    'تحكم في أنواع التنبيهات التي تظهر لك',
                              ),
                              _buildMainNotificationCard(),

                              const SizedBox(height: 24),

                              _buildSectionTitle(
                                icon: Icons.category_rounded,
                                title: 'إشعارات التصنيفات',
                                subtitle:
                                    'اختر التصنيفات التي تريد متابعة إعلاناتها',
                              ),
                              _buildCategoryCard(),
                            ],
                          ),
                        ),
                      ),

                      // زر الحفظ.
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pageBackground,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.06,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed:
                                _isSaving ? null : _saveSettings,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_rounded,
                                  ),
                            label: Text(
                              _isSaving
                                  ? 'جاري الحفظ...'
                                  : 'حفظ التغييرات',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
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

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: AppDecorations.card(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 34,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تسجيل الدخول مطلوب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سجل الدخول حتى تتمكن من إدارة إعدادات الإشعارات.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
