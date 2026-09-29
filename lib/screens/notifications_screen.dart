import 'package:flutter/material.dart';

import 'listing_details_screen.dart';
import 'notification_settings_screen.dart';
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
      final notifications = await _notificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('تعذر تحميل الإشعارات');
    }
  }

  Future<void> _refreshNotifications() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final notifications = await _notificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      _showError('تعذر تحديث الإشعارات');
    }
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
    if (!mounted) return;
    await _loadNotifications();
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = (notification['id'] as num?)?.toInt();
    if (id == null || notification['is_read'] == true) return;

    try {
      await _notificationService.markAsRead(id);
      if (!mounted) return;
      setState(() => notification['is_read'] = true);
    } catch (_) {
      _showError('تعذر تحديث حالة الإشعار');
    }
  }

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

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final id = (notification['id'] as num?)?.toInt();
    if (id == null) return;

    try {
      await _notificationService.deleteNotification(id);
      if (!mounted) return;
      setState(() => _notifications.remove(notification));
    } catch (_) {
      _showError('تعذر حذف الإشعار');
    }
  }

  Future<void> _deleteAllNotifications() async {
    if (_notifications.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'حذف جميع الإشعارات',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text('هل تريد حذف جميع الإشعارات؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _notificationService.deleteAllNotifications();
      if (!mounted) return;
      setState(() => _notifications.clear());
    } catch (_) {
      _showError('تعذر حذف الإشعارات');
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    await _markAsRead(notification);
    if (!mounted) return;

    final listingId = (notification['listing_id'] as num?)?.toInt();
    if (listingId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingDetailsScreen(listingId: listingId),
      ),
    );

    if (!mounted) return;
    await _loadNotifications();
  }

  IconData _notificationIcon(String? type) {
    switch (type) {
      case 'new_listing':
        return Icons.campaign_rounded;
      case 'featured_listing':
        return Icons.auto_awesome_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _notificationIconColor(String? type) {
    switch (type) {
      case 'new_listing':
        return AppColors.brand;
      case 'featured_listing':
        return AppColors.orange;
      case 'admin':
        return AppColors.brandDark;
      case 'announcement':
        return AppColors.gold;
      default:
        return AppColors.brand;
    }
  }

  String _notificationLabel(String? type) {
    switch (type) {
      case 'new_listing':
        return 'إعلان جديد';
      case 'featured_listing':
        return 'إعلان مميز';
      case 'admin':
        return 'من الإدارة';
      case 'announcement':
        return 'إعلان عام';
      default:
        return 'تنبيه';
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.isNegative || difference.inMinutes < 1) return 'الآن';
      if (difference.inMinutes < 60) {
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      if (difference.inHours < 24) {
        return 'منذ ${difference.inHours} ساعة';
      }
      if (difference.inDays == 1) return 'أمس';
      if (difference.inDays < 7) return 'منذ ${difference.inDays} أيام';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

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
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.pageBackground,
          foregroundColor: AppColors.ink,
          centerTitle: true,
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الإشعارات',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'ابقَ على اطلاع بكل جديد',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            if (unreadCount > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 27),
                    height: 27,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.orange, AppColors.gold],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'إعدادات الإشعارات',
              onPressed: _openNotificationSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
            if (unreadCount > 0)
              IconButton(
                tooltip: 'تحديد الكل كمقروء',
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded),
              ),
            if (_notifications.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'المزيد',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'delete_all') _deleteAllNotifications();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.red),
                        SizedBox(width: 10),
                        Text('حذف الكل'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    if (!_notificationService.isSignedIn) {
      return _buildLoginMessage();
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _refreshNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            _buildEmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _refreshNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 11),
        itemBuilder: (context, index) {
          return _buildNotificationCard(_notifications[index]);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] == true;
    final type = notification['type']?.toString();
    final title = notification['title']?.toString() ?? 'إشعار';
    final body = notification['body']?.toString() ?? '';
    final date = _formatDate(notification['created_at']);
    final iconColor = _notificationIconColor(type);
    final listingId = (notification['listing_id'] as num?)?.toInt();
    final hasListing = listingId != null;

    return Dismissible(
      key: ValueKey(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Colors.red],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteNotification(notification);
        return false;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasListing
            ? () => _openNotification(notification)
            : () => _markAsRead(notification),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFF1ECFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? Colors.transparent
                  : AppColors.brand.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(
                  alpha: isRead ? 0.055 : 0.10,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationIcon(iconColor, type, isRead),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _notificationLabel(type),
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        if (date.isNotEmpty) ...[
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (hasListing) ...[
                          const Spacer(),
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 12,
                            color: iconColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'عرض الإعلان',
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(
    Color color,
    String? type,
    bool isRead,
  ) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            color.withValues(alpha: isRead ? 0.12 : 0.20),
            AppColors.brandSoft,
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: isRead ? 0.10 : 0.18),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            _notificationIcon(type),
            color: color.withValues(alpha: isRead ? 0.70 : 1),
            size: 25,
          ),
          if (!isRead)
            Positioned(
              top: 4,
              right: 5,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // أيقونة ملونة بدل الأيقونة الرمادية القديمة.
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.brand, AppColors.brandDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.gold,
                  size: 50,
                ),
                Positioned(
                  top: 20,
                  right: 22,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'كل جديد سيصل إليك هنا',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'لا توجد إشعارات حالياً. عند وصول إعلان جديد أو تنبيه مهم،\nستجده هنا بسهولة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: AppDecorations.softCard(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tips_and_updates_rounded,
                  color: AppColors.orange,
                  size: 19,
                ),
                SizedBox(width: 8),
                Text(
                  'يمكنك التحكم في التنبيهات من الإعدادات',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: _openNotificationSettings,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text(
              'إعدادات الإشعارات',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppColors.brand, AppColors.brandDark],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.20),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.gold,
                size: 48,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'سجّل الدخول أولاً',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سجّل الدخول لتستقبل إشعاراتك وتتابع\nكل جديد في دلالة شبشة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
