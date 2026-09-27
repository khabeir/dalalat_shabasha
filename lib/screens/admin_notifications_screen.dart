import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends State<AdminNotificationsScreen> {
  final _supabase = Supabase.instance.client;

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _sending = false;

  int? _lastRecipientCount;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // =========================
  // الأدوات
  // =========================

  void _showSnack(
    String message, {
    bool error = false,
    int seconds = 4,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor:
              error ? Colors.red.shade700 : AppColors.ink,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: seconds),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(14),
        ),
      );
  }

  // =========================
  // التحقق من الأدمن
  // =========================

  Future<void> _checkAdmin() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        final profile = await _supabase
            .from('profiles')
            .select('role, is_banned')
            .eq('id', user.id)
            .maybeSingle();

        _isAdmin = profile?['role'] == 'admin' &&
            profile?['is_banned'] != true;
      }
    } catch (e) {
      debugPrint('admin notification check error: $e');
      _isAdmin = false;
    }

    if (!mounted) return;

    setState(() {
      _checkingAdmin = false;
    });
  }

  // =========================
  // إرسال الإشعار
  // =========================

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _showSnack(
        'اكتب عنوان الإشعار أولاً',
        error: true,
      );
      return;
    }

    if (body.isEmpty) {
      _showSnack(
        'اكتب نص الإشعار أولاً',
        error: true,
      );
      return;
    }

    if (title.length > 120) {
      _showSnack(
        'عنوان الإشعار يجب ألا يتجاوز 120 حرفاً',
        error: true,
      );
      return;
    }

    if (body.length > 1000) {
      _showSnack(
        'نص الإشعار يجب ألا يتجاوز 1000 حرف',
        error: true,
      );
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: title,
      body: body,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _sending = true;
      _lastRecipientCount = null;
    });

    try {
      final response = await _supabase.rpc(
        'admin_send_notification',
        params: {
          'p_title': title,
          'p_body': body,
        },
      );

      final count = response is num
          ? response.toInt()
          : int.tryParse(response.toString()) ?? 0;

      if (!mounted) return;

      setState(() {
        _lastRecipientCount = count;
      });

      _titleController.clear();
      _bodyController.clear();

      _showSnack(
        'تم إرسال الإشعار إلى $count مستخدم',
        seconds: 6,
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'admin send notification error: '
        '${e.message}',
      );

      _showSnack(
        e.message.isNotEmpty
            ? e.message
            : 'تعذر إرسال الإشعار',
        error: true,
        seconds: 6,
      );
    } catch (e) {
      debugPrint(
        'admin send notification error: $e',
      );

      _showSnack(
        'تعذر إرسال الإشعار، تحقق من اتصال الإنترنت',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String body,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.campaign_outlined,
                  color: AppColors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تأكيد إرسال الإشعار',
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration:
                      AppDecorations.softCard(),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'سيتم إرسال هذا التنبيه إلى جميع المستخدمين الذين فعّلوا إشعارات الإدارة.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                ),
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                icon: const Icon(
                  Icons.send_rounded,
                  size: 18,
                ),
                label: const Text('إرسال'),
              ),
            ],
          ),
        );
      },
    );

    return result == true;
  }

  // =========================
  // واجهة غير مصرح
  // =========================

  Widget _buildLocked() {
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
                width: 84,
                height: 84,
                decoration:
                    AppDecorations.softCard(),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'هذه الصفحة مخصصة للأدمن فقط',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لا تملك صلاحية إرسال إشعارات الإدارة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // بطاقة معلومات
  // =========================

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand,
            AppColors.brandDark,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(
              alpha: 0.18,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'إشعارات الإدارة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'أرسل تنبيهات مهمة لأعضاء دلالة شبشة الذين فعّلوا إشعارات الإدارة.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // حقل النص
  // =========================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: AppColors.brand,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: AppColors.brand,
          width: 1.3,
        ),
      ),
    );
  }

  // =========================
  // الصفحة
  // =========================

  Widget _buildPage() {
    return SingleChildScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        30,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _infoCard(),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.edit_notifications_outlined,
                      color: AppColors.brand,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'إنشاء إشعار جديد',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _titleController,
                  maxLength: 120,
                  textInputAction:
                      TextInputAction.next,
                  decoration: _inputDecoration(
                    label: 'عنوان الإشعار',
                    hint: 'مثال: تنبيه مهم من إدارة دلالة شبشة',
                    icon: Icons.title_rounded,
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _bodyController,
                  maxLength: 1000,
                  maxLines: 7,
                  minLines: 4,
                  textInputAction:
                      TextInputAction.newline,
                  decoration: _inputDecoration(
                    label: 'نص الإشعار',
                    hint:
                        'اكتب الرسالة التي تريد إرسالها للمستخدمين...',
                    icon:
                        Icons.notes_rounded,
                  ),
                ),

                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration:
                      AppDecorations.softCard(),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 19,
                        color: AppColors.brand,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لن يصل الإشعار إلا للمستخدم الذي فعّل "الإشعارات" و"إعلانات وتنبيهات الإدارة" من إعداداته.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.55,
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      textStyle:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    onPressed:
                        _sending
                            ? null
                            : _sendNotification,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                          ),
                    label: Text(
                      _sending
                          ? 'جاري الإرسال...'
                          : 'إرسال الإشعار',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_lastRecipientCount != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green.shade100,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'تم الإرسال بنجاح إلى $_lastRecipientCount مستخدم.',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_checkingAdmin) {
      body = const Center(
        child: CircularProgressIndicator(
          color: AppColors.brand,
        ),
      );
    } else if (!_isAdmin) {
      body = _buildLocked();
    } else {
      body = _buildPage();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'إشعارات الإدارة',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: false,
        ),
        body: body,
      ),
    );
  }
}
