import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/widgets/home_banner.dart';

// شاشة الأدمن لتحرير الخانات الثلاث لبنر الصفحة الرئيسية
// + رسالة الإدارة التي تظهر في أعلى صفحة إضافة الإعلان.
//
// كل خانة:
// عنوان + نص فرعي + تفعيل + معاينة.
//
// رسالة الإدارة:
// نص + تفعيل + معاينة + حفظ.
//
// ملاحظة:
// رسالة الإدارة محفوظة في جدول:
// add_listing_admin_message
//
// والسجل المستخدم هو id = 1.
class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final _supabase = Supabase.instance.client;

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;

  // ============================================================
  // متحكمات خانات البنر الثلاث
  // ============================================================

  final _headlineControllers = <int, TextEditingController>{
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
  };

  final _subtitleControllers = <int, TextEditingController>{
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
  };

  final _activeBySlot = <int, bool>{
    1: false,
    2: false,
    3: false,
  };

  final _savingBySlot = <int, bool>{
    1: false,
    2: false,
    3: false,
  };

  final _dirtyBySlot = <int, bool>{
    1: false,
    2: false,
    3: false,
  };

  // ============================================================
  // رسالة الإدارة
  // ============================================================

  final _adminMessageController = TextEditingController();

  bool _adminMessageActive = false;
  bool _savingAdminMessage = false;
  bool _adminMessageDirty = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final controller in _headlineControllers.values) {
      controller.dispose();
    }

    for (final controller in _subtitleControllers.values) {
      controller.dispose();
    }

    _adminMessageController.dispose();

    super.dispose();
  }

  // ============================================================
  // SnackBar
  // ============================================================

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // التحقق من الأدمن
  // ============================================================

  Future<void> _init() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        final profile = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        _isAdmin = profile?['role'] == 'admin';
      }
    } catch (e) {
      debugPrint('admin check error: $e');
      _isAdmin = false;
    }

    if (!mounted) return;

    setState(() {
      _checkingAdmin = false;
    });

    if (_isAdmin) {
      await _loadSlides();
    }
  }

  // ============================================================
  // تحميل البنرات + رسالة الإدارة
  // ============================================================

  Future<void> _loadSlides() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ----------------------------------------------------------
      // تحميل خانات البنر الثلاث
      // ----------------------------------------------------------

      final response = await _supabase
          .from('home_banner_slides')
          .select(
            'slot, headline, subtitle, is_active',
          )
          .order('slot');

      for (final row in List<Map<String, dynamic>>.from(response)) {
        final slot = row['slot'];

        if (slot is! int) continue;

        if (!_headlineControllers.containsKey(slot)) {
          continue;
        }

        _headlineControllers[slot]!.text =
            row['headline']?.toString() ?? '';

        _subtitleControllers[slot]!.text =
            row['subtitle']?.toString() ?? '';

        _activeBySlot[slot] =
            row['is_active'] == true;

        _dirtyBySlot[slot] = false;
      }

      // ----------------------------------------------------------
      // تحميل رسالة الإدارة
      //
      // مهم:
      // فشل تحميل الرسالة لا يجب أن يعطل صفحة البنرات.
      // ----------------------------------------------------------

      try {
        final messageResponse = await _supabase
            .from('add_listing_admin_message')
            .select(
              'message, is_active',
            )
            .eq('id', 1)
            .maybeSingle();

        if (messageResponse != null) {
          _adminMessageController.text =
              messageResponse['message']?.toString() ?? '';

          _adminMessageActive =
              messageResponse['is_active'] == true;

          _adminMessageDirty = false;
        }
      } catch (e) {
        debugPrint(
          'loadAdminMessage error: $e',
        );

        // لا نوقف تحميل صفحة البنرات إذا حدث خطأ
        // في رسالة الإدارة.
        _adminMessageController.clear();
        _adminMessageActive = false;
        _adminMessageDirty = false;
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'loadBannerSlides error: $e',
      );

      if (!mounted) return;

      setState(() {
        _error =
            'تعذر تحميل البنر. تحقق من اتصال الإنترنت وحاول مجدداً.';
        _loading = false;
      });
    }
  }

  // ============================================================
  // حفظ خانة بنر
  // ============================================================

  Future<void> _saveSlot(int slot) async {
    setState(() {
      _savingBySlot[slot] = true;
    });

    final headline =
        _headlineControllers[slot]!.text.trim();

    final subtitle =
        _subtitleControllers[slot]!.text.trim();

    final active =
        _activeBySlot[slot] ?? false;

    if (active && headline.isEmpty) {
      _showSnack(
        'اكتب النص الإعلاني قبل تفعيل الخانة',
      );

      setState(() {
        _savingBySlot[slot] = false;
      });

      return;
    }

    try {
      await _supabase
          .from('home_banner_slides')
          .update({
        'headline': headline,
        'subtitle': subtitle,
        'is_active': active,
      }).eq(
        'slot',
        slot,
      );

      if (!mounted) return;

      setState(() {
        _dirtyBySlot[slot] = false;
      });

      _showSnack(
        'تم حفظ الخانة $slot',
      );
    } catch (e) {
      debugPrint(
        'saveBannerSlide error: $e',
      );

      _showSnack(
        'تعذر حفظ الخانة $slot، حاول مرة أخرى',
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingBySlot[slot] = false;
        });
      }
    }
  }

  // ============================================================
  // حفظ رسالة الإدارة
  // ============================================================

  Future<void> _saveAdminMessage() async {
    if (_savingAdminMessage) return;

    final message =
        _adminMessageController.text.trim();

    // إذا كانت الرسالة مفعلة، لا نسمح بحفظها فارغة.
    if (_adminMessageActive && message.isEmpty) {
      _showSnack(
        'اكتب رسالة الإدارة قبل تفعيلها',
      );

      return;
    }

    setState(() {
      _savingAdminMessage = true;
    });

    try {
      final user =
          _supabase.auth.currentUser;

      await _supabase
          .from('add_listing_admin_message')
          .update({
        'message': message,
        'is_active': _adminMessageActive,
        'updated_by': user?.id,
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
      }).eq(
        'id',
        1,
      );

      if (!mounted) return;

      setState(() {
        _adminMessageDirty = false;
      });

      _showSnack(
        'تم حفظ رسالة الإدارة',
      );
    } catch (e) {
      debugPrint(
        'saveAdminMessage error: $e',
      );

      _showSnack(
        'تعذر حفظ رسالة الإدارة، حاول مرة أخرى',
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingAdminMessage = false;
        });
      }
    }
  }

  // ============================================================
  // بطاقة خانة البنر
  // ============================================================

  Widget _buildSlotCard(int slot) {
    final headlineController =
        _headlineControllers[slot]!;

    final subtitleController =
        _subtitleControllers[slot]!;

    final active =
        _activeBySlot[slot] ?? false;

    final saving =
        _savingBySlot[slot] ?? false;

    final dirty =
        _dirtyBySlot[slot] ?? false;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          // ------------------------------------------------------
          // عنوان الخانة + التفعيل
          // ------------------------------------------------------

          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration:
                    const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$slot',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              const Text(
                'الخانة',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),

              const Spacer(),

              Switch(
                value: active,
                activeTrackColor:
                    AppColors.brand,
                onChanged: saving
                    ? null
                    : (value) {
                        setState(() {
                          _activeBySlot[slot] =
                              value;

                          _dirtyBySlot[slot] =
                              true;
                        });
                      },
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ------------------------------------------------------
          // العنوان الرئيسي
          // ------------------------------------------------------

          TextField(
            controller: headlineController,
            maxLength: 30,
            onChanged: (_) {
              setState(() {
                _dirtyBySlot[slot] = true;
              });
            },
            decoration:
                const InputDecoration(
              labelText:
                  'العنوان الرئيسي',
              hintText:
                  'مثال: عروض نهاية الأسبوع',
              border:
                  OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const SizedBox(height: 10),

          // ------------------------------------------------------
          // النص الفرعي
          // ------------------------------------------------------

          TextField(
            controller: subtitleController,
            maxLength: 70,
            maxLines: 2,
            onChanged: (_) {
              setState(() {
                _dirtyBySlot[slot] = true;
              });
            },
            decoration:
                const InputDecoration(
              labelText: 'النص الفرعي',
              hintText:
                  'مثال: خصومات على الأثاث حتى نهاية الأسبوع',
              border:
                  OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------------
          // المعاينة
          // ------------------------------------------------------

          AnimatedBuilder(
            animation: Listenable.merge([
              headlineController,
              subtitleController,
            ]),
            builder: (context, _) {
              final headline =
                  headlineController.text.trim();

              return Opacity(
                opacity: active ? 1 : 0.45,
                child: BannerCardContent(
                  slot: slot,
                  headline: headline.isEmpty
                      ? 'عنوان الإعلان'
                      : headline,
                  subtitle:
                      subtitleController.text.trim(),
                  onAddListing: null,
                  onBrowseCategories: null,
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------------
          // زر الحفظ
          // ------------------------------------------------------

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (!dirty || saving)
                      ? null
                      : () => _saveSlot(slot),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    AppColors.brand,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.save_outlined,
                    ),
              label: Text(
                saving
                    ? 'جاري الحفظ...'
                    : 'حفظ الخانة $slot',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // بطاقة رسالة الإدارة
  // ============================================================

  Widget _buildAdminMessageCard() {
    final active =
        _adminMessageActive;

    final saving =
        _savingAdminMessage;

    final dirty =
        _adminMessageDirty;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          // ------------------------------------------------------
          // عنوان القسم + التفعيل
          // ------------------------------------------------------

          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      AppColors.orange.withValues(
                    alpha: 0.14,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppColors.orange,
                ),
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رسالة الإدارة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),

                    SizedBox(height: 3),

                    Text(
                      'تظهر في أعلى صفحة إضافة الإعلان',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              Switch(
                value: active,
                activeTrackColor:
                    AppColors.brand,
                onChanged: saving
                    ? null
                    : (value) {
                        setState(() {
                          _adminMessageActive =
                              value;

                          _adminMessageDirty =
                              true;
                        });
                      },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ------------------------------------------------------
          // حقل الرسالة
          // ------------------------------------------------------

          TextField(
            controller:
                _adminMessageController,
            maxLength: 180,
            maxLines: 4,
            onChanged: (_) {
              setState(() {
                _adminMessageDirty = true;
              });
            },
            decoration:
                const InputDecoration(
              labelText:
                  'نص رسالة الإدارة',
              hintText:
                  'مثال: الإعلان متاح حاليا مجانا ولفتره محدودة',
              border:
                  OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 6),

          // ------------------------------------------------------
          // المعاينة
          // ------------------------------------------------------

          Container(
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  AppColors.brandSoft,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 19,
                  color: AppColors.brand,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: AnimatedBuilder(
                    animation:
                        _adminMessageController,
                    builder:
                        (context, _) {
                      final text =
                          _adminMessageController
                              .text
                              .trim();

                      return Text(
                        text.isEmpty
                            ? 'معاينة الرسالة ستظهر هنا'
                            : text,
                        style:
                            const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight:
                              FontWeight.w700,
                          color:
                              AppColors.ink,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------------
          // زر حفظ الرسالة
          // ------------------------------------------------------

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (!dirty || saving)
                      ? null
                      : _saveAdminMessage,
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    AppColors.brand,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.save_outlined,
                    ),
              label: Text(
                saving
                    ? 'جاري الحفظ...'
                    : 'حفظ رسالة الإدارة',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // جسم الصفحة
  // ============================================================

  Widget _buildBody() {
    // ----------------------------------------------------------
    // جاري التحقق / التحميل
    // ----------------------------------------------------------

    if (_checkingAdmin || _loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.brand,
        ),
      );
    }

    // ----------------------------------------------------------
    // ليس أدمن
    // ----------------------------------------------------------

    if (!_isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
              ),

              SizedBox(height: 16),

              Text(
                'هذه الصفحة مخصصة للأدمن فقط',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // خطأ تحميل البنرات
    // ----------------------------------------------------------

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),

              const SizedBox(height: 12),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(height: 16),

              FilledButton(
                onPressed:
                    _loadSlides,
                child:
                    const Text(
                  'إعادة المحاولة',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // المحتوى
    // ----------------------------------------------------------

    return RefreshIndicator(
      onRefresh: _loadSlides,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          14,
          14,
          14,
          24,
        ),
        children: [
          // ------------------------------------------------------
          // ملاحظة عامة
          // ------------------------------------------------------

          Container(
            margin:
                const EdgeInsets.only(
              bottom: 14,
            ),
            padding:
                const EdgeInsets.all(12),
            decoration:
                AppDecorations.softCard(),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color:
                      AppColors.brand,
                  size: 20,
                ),

                SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'يظهر البنر في الصفحة الرئيسية بالخانات المفعّلة فقط، '
                    'وتُعرض بالترتيب مع تمرير تلقائي عند وجود أكثر من خانة.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // رسالة الإدارة
          // ------------------------------------------------------

          _buildAdminMessageCard(),

          // ------------------------------------------------------
          // خانات البنر
          // ------------------------------------------------------

          _buildSlotCard(1),

          _buildSlotCard(2),

          _buildSlotCard(3),
        ],
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            AppColors.pageBackground,

        appBar: AppBar(
          backgroundColor:
              AppColors.brand,
          foregroundColor:
              Colors.white,
          elevation: 0,
          title: const Text(
            'البنر الإعلاني',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),

        body: _buildBody(),
      ),
    );
  }
}