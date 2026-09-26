import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService =
      NotificationService.instance;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // =========================================================
  // تحميل الإشعارات
  // =========================================================

  Future<void> _loadNotifications() async {
    if (!_notificationService.isSignedIn) {
      if (!mounted) return;

      setState(() {
        _notifications = [];
        _isLoading = false;
      });

      return;
    }

    try {
      final notifications =
          await _notificationService.getNotifications();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('تعذر تحميل الإشعارات');
    }
  }

  // =========================================================
  // تحديث
  // =========================================================

  Future<void> _refreshNotifications() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final notifications =
          await _notificationService.getNotifications();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRefreshing = false;
      });

      _showError('تعذر تحديث الإشعارات');
    }
  }

  // =========================================================
  // تعليم إشعار كمقروء
  // =========================================================

  Future<void> _markAsRead(
    Map<String, dynamic> notification,
  ) async {
    final id = (notification['id'] as num?)?.toInt();

    if (id == null) return;

    if (notification['is_read'] == true) return;

    try {
      await _notificationService.markAsRead(id);

      if (!mounted) return;

      setState(() {
        notification['is_read'] = true;
      });
    } catch (_) {
      _showError('تعذر تحديث حالة الإشعار');
    }
  }

  // =========================================================
  // تعليم الكل كمقروء
  // =========================================================

  Future<void> _markAllAsRead() async {
    final hasUnread = _notifications.any(
      (notification) => notification['is_read'] != true,
    );

    if (!hasUnread) return;

    try {
      await _notificationService.markAllAsRead();

      if (!mounted) return;

      setState(() {
        for (final notification in _notifications) {
          notification['is_read'] = true;
        }
      });
    } catch (_) {
      _showError('تعذر تحديث الإشعارات');
    }
  }

  // =========================================================
  // حذف إشعار
  // =========================================================

  Future<void> _deleteNotification(
    Map<String, dynamic> notification,
  ) async {
    final id = (notification['id'] as num?)?.toInt();

    if (id == null) return;

    try {
      await _notificationService.deleteNotification(id);

      if (!mounted) return;

      setState(() {
        _notifications.remove(notification);
      });
    } catch (_) {
      _showError('تعذر حذف الإشعار');
    }
  }

  // =========================================================
  // حذف جميع الإشعارات
  // =========================================================

  Future<void> _deleteAllNotifications() async {
    if (_notifications.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف جميع الإشعارات'),
          content: const Text(
            'هل تريد حذف جميع الإشعارات؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _notificationService.deleteAllNotifications();

      if (!mounted) return;

      setState(() {
        _notifications.clear();
      });
    } catch (_) {
      _showError('تعذر حذف الإشعارات');
    }
  }

  // =========================================================
  // فتح الإشعار
  // =========================================================

  Future<void> _openNotification(
    Map<String, dynamic> notification,
  ) async {
    await _markAsRead(notification);

    final listingId =
        (notification['listing_id'] as num?)?.toInt();

    if (listingId == null || !mounted) {
      return;
    }

    // سيتم ربط فتح الإعلان هنا في الخطوة القادمة.
    //
    // لا نضع ListingDetailsScreen الآن لأننا نحتاج أولاً
    // مطابقة طريقة فتح الإعلان الموجودة في مشروعك.
  }

  // =========================================================
  // نوع الإشعار
  // =========================================================

  IconData _notificationIcon(String? type) {
    switch (type) {
      case 'new_listing':
        return Icons.new_releases_rounded;

      case 'featured_listing':
        return Icons.star_rounded;

      case 'admin':
      case 'announcement':
        return Icons.campaign_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color _notificationIconColor(String? type) {
    switch (type) {
      case 'new_listing':
        return Colors.blue;

      case 'featured_listing':
        return AppColors.orange;

      case 'admin':
      case 'announcement':
        return AppColors.brand;

      default:
        return AppColors.brand;
    }
  }

  // =========================================================
  // التاريخ
  // =========================================================

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'الآن';
      }

      if (difference.inMinutes < 60) {
        return 'منذ ${difference.inMinutes} دقيقة';
      }

      if (difference.inHours < 24) {
        return 'منذ ${difference.inHours} ساعة';
      }

      if (difference.inDays == 1) {
        return 'أمس';
      }

      if (difference.inDays < 7) {
        return 'منذ ${difference.inDays} أيام';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  // =========================================================
  // رسالة خطأ
  // =========================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // البناء
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where(
      (notification) => notification['is_read'] != true,
    ).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.pageBackground,
          foregroundColor: AppColors.ink,
          centerTitle: true,
          title: const Text(
            'الإشعارات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            if (unreadCount > 0)
              IconButton(
                tooltip: 'تحديد الكل كمقروء',
                onPressed: _markAllAsRead,
                icon: const Icon(
                  Icons.done_all_rounded,
                ),
              ),
            if (_notifications.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete_all') {
                    _deleteAllNotifications();
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'delete_all',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.red,
                          ),
                          SizedBox(width: 10),
                          Text('حذف الكل'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  // =========================================================
  // محتوى الصفحة
  // =========================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_notificationService.isSignedIn) {
      return _buildLoginMessage();
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.28,
            ),
            _buildEmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          30,
        ),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _buildNotificationCard(
            _notifications[index],
          );
        },
      ),
    );
  }

  // =========================================================
  // بطاقة الإشعار
  // =========================================================

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
  ) {
    final isRead = notification['is_read'] == true;

    final type = notification['type']?.toString();

    final title =
        notification['title']?.toString() ?? 'إشعار';

    final body =
        notification['body']?.toString() ?? '';

    final date =
        _formatDate(notification['created_at']);

    final iconColor = _notificationIconColor(type);

    return Dismissible(
      key: ValueKey(
        notification['id'],
      ),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteNotification(notification);
        return false;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openNotification(notification),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(15),
          decoration: AppDecorations.card(
            color: isRead
                ? Colors.white
                : AppColors.brandSoft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationIcon(
                iconColor,
                type,
                isRead,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin:
                                const EdgeInsets.only(
                              right: 8,
                            ),
                            decoration:
                                const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        body,
                        maxLines: 3,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // أيقونة الإشعار
  // =========================================================

  Widget _buildNotificationIcon(
    Color color,
    String? type,
    bool isRead,
  ) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isRead ? 0.08 : 0.14,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _notificationIcon(type),
        color: color.withValues(
          alpha: isRead ? 0.65 : 1,
        ),
        size: 23,
      ),
    );
  }

  // =========================================================
  // لا توجد إشعارات
  // =========================================================

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.brand,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'لا توجد إشعارات حالياً',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'عند وجود إعلانات أو عروض جديدة ستظهر '
            'الإشعارات هنا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              // سيتم ربطها بصفحة إعدادات الإشعارات.
            },
            icon: const Icon(
              Icons.tune_rounded,
            ),
            label: const Text(
              'إعدادات الإشعارات',
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // المستخدم غير مسجل
  // =========================================================

  Widget _buildLoginMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.brand,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'سجّل الدخول أولاً',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يجب تسجيل الدخول لعرض إشعاراتك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
