import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../services/notification_service.dart';
import '../../screens/notifications_screen.dart';

class HomeHeader extends StatelessWidget {
  // =========================================================
  // ارتفاع محتوى الترويسة.
  // =========================================================
  static const headerContentHeight = 160.0;

  final double topPadding;
  final bool isDark;
  final Color pageBackground;
  final Color titleColor;
  final TextEditingController searchController;
  final bool isSignedIn;

  final VoidCallback onOpenDrawer;
  final VoidCallback onProfile;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  const HomeHeader({
    super.key,
    required this.topPadding,
    required this.isDark,
    required this.pageBackground,
    required this.titleColor,
    required this.searchController,
    required this.isSignedIn,
    required this.onOpenDrawer,
    required this.onProfile,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final height = topPadding + headerContentHeight;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // =====================================================
          // الخلفية الجديدة
          // =====================================================
          Positioned.fill(
            child: _buildBackground(),
          ),

          // =====================================================
          // زخارف الخلفية
          // =====================================================
          Positioned.fill(
            child: IgnorePointer(
              child: _buildDecorations(),
            ),
          ),

          // =====================================================
          // الصف العلوي
          // =====================================================
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: _buildTopRow(context),
          ),

          // =====================================================
          // مربع البحث
          // =====================================================
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: _buildSearchField(context),
          ),

          // =====================================================
          // الحافة المنحنية أسفل الترويسة
          // =====================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pageBackground,
                borderRadius:
                    const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // خلفية الترويسة الجديدة
  // =========================================================
  Widget _buildBackground() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? const [
                  Color(0xFF25154A),
                  Color(0xFF38206B),
                  Color(0xFF4C2A83),
                ]
              : const [
                  Color(0xFFF3ECFF),
                  Color(0xFFE8DEFF),
                  Color(0xFFFDF9FF),
                ],
          stops: const [
            0.0,
            0.52,
            1.0,
          ],
        ),
      ),
    );
  }

  // =========================================================
  // زخارف الخلفية
  // =========================================================
  Widget _buildDecorations() {
    return Stack(
      children: [
        // -----------------------------------------------------
        // دائرة بنفسجية كبيرة أعلى اليمين
        // -----------------------------------------------------
        Positioned(
          top: -70,
          right: -45,
          child: _SoftCircle(
            size: 190,
            color: AppColors.brand,
            opacity: isDark ? 0.18 : 0.10,
          ),
        ),

        // -----------------------------------------------------
        // دائرة ذهبية صغيرة
        // -----------------------------------------------------
        Positioned(
          top: 28,
          right: 82,
          child: _SoftCircle(
            size: 46,
            color: AppColors.gold,
            opacity: isDark ? 0.22 : 0.28,
          ),
        ),

        // -----------------------------------------------------
        // دائرة بنفسجية يسار
        // -----------------------------------------------------
        Positioned(
          top: 74,
          left: -55,
          child: _SoftCircle(
            size: 150,
            color: AppColors.brand,
            opacity: isDark ? 0.15 : 0.08,
          ),
        ),

        // -----------------------------------------------------
        // دائرة برتقالية صغيرة
        // -----------------------------------------------------
        Positioned(
          top: 105,
          left: 65,
          child: _SoftCircle(
            size: 34,
            color: AppColors.orange,
            opacity: isDark ? 0.18 : 0.15,
          ),
        ),

        // -----------------------------------------------------
        // شكل زخرفي سفلي
        // -----------------------------------------------------
        Positioned(
          right: 145,
          bottom: 38,
          child: _SoftCircle(
            size: 70,
            color: AppColors.brand,
            opacity: isDark ? 0.10 : 0.06,
          ),
        ),

        // -----------------------------------------------------
        // لمعة صغيرة
        // -----------------------------------------------------
        Positioned(
          top: 48,
          left: 150,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: AppColors.gold.withValues(
              alpha: isDark ? 0.55 : 0.75,
            ),
          ),
        ),

        // -----------------------------------------------------
        // لمعة ثانية
        // -----------------------------------------------------
        Positioned(
          top: 76,
          right: 155,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: AppColors.brand.withValues(
              alpha: isDark ? 0.40 : 0.35,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // الصف العلوي
  // =========================================================
  Widget _buildTopRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // =====================================================
        // زر القائمة
        // =====================================================
        _HeaderCircleButton(
          tooltip: 'القائمة',
          icon: Icons.menu_rounded,
          onTap: onOpenDrawer,
        ),

        const SizedBox(width: 8),

        // =====================================================
        // الشعار
        // =====================================================
        _buildLogo(),

        const SizedBox(width: 7),

        // =====================================================
        // اسم التطبيق
        // =====================================================
        Expanded(
          child: _buildAppTitle(),
        ),

        const SizedBox(width: 8),

        // =====================================================
        // زر الإشعارات
        // =====================================================
        if (isSignedIn) ...[
          _NotificationHeaderButton(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const NotificationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 7),
        ],

        // =====================================================
        // حساب المستخدم
        // =====================================================
        _HeaderCircleButton(
          tooltip: isSignedIn
              ? 'الملف الشخصي'
              : 'تسجيل الدخول',
          icon: isSignedIn
              ? Icons.person_rounded
              : Icons.person_outline_rounded,
          onTap: onProfile,
        ),
      ],
    );
  }

  // =========================================================
  // عنوان التطبيق
  // =========================================================
  Widget _buildAppTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // -----------------------------------------------------
        // اسم التطبيق
        // -----------------------------------------------------
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'دلالة شبشة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: isDark
                  ? Colors.white
                  : AppColors.brandDark,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: isDark
                      ? Colors.black.withValues(
                          alpha: 0.25,
                        )
                      : Colors.white.withValues(
                          alpha: 0.80,
                        ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 4),

        // -----------------------------------------------------
        // الشعار النصي
        // -----------------------------------------------------
        Text(
          'سوقك المحلي في شبشة',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark
                ? Colors.white.withValues(
                    alpha: 0.85,
                  )
                : AppColors.brandDark.withValues(
                    alpha: 0.78,
                  ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // شعار دلالة شبشة
  // =========================================================
  Widget _buildLogo() {
    return SizedBox(
      width: 43,
      height: 50,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // ---------------------------------------------------
          // دبوس الموقع
          // ---------------------------------------------------
          const Icon(
            Icons.location_on_rounded,
            size: 49,
            color: AppColors.brand,
          ),

          // ---------------------------------------------------
          // عربة التسوق
          // ---------------------------------------------------
          const Positioned(
            top: 11,
            child: Icon(
              Icons.shopping_cart_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),

          // ---------------------------------------------------
          // علامة العرض الذهبية
          // ---------------------------------------------------
          Positioned(
            top: -1,
            left: -1,
            child: Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                size: 9,
                color: AppColors.brandDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // مربع البحث
  // =========================================================
  Widget _buildSearchField(
    BuildContext context,
  ) {
    final surfaceColor = isDark
        ? const Color(0xFF302052)
        : Colors.white;

    final textColor = isDark
        ? Colors.white
        : AppColors.ink;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(
                  alpha: 0.08,
                )
              : Colors.white,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(
              alpha: isDark ? 0.30 : 0.15,
            ),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withValues(
                alpha: 0.85,
              ),
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: searchController,
        builder: (
          context,
          value,
          _,
        ) {
          return TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            decoration: InputDecoration(
              hintText: 'ابحث عن إعلان أو منطقة ...',
              hintStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(
                        alpha: 0.55,
                      )
                    : AppColors.ink.withValues(
                        alpha: 0.48,
                      ),
              ),

              // ------------------------------------------------
              // أيقونة البحث
              // ------------------------------------------------
              prefixIcon: Padding(
                padding:
                    const EdgeInsetsDirectional.only(
                  start: 6,
                  end: 2,
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 28,
                  color: AppColors.brand,
                ),
              ),

              // ------------------------------------------------
              // زر مسح البحث
              // ------------------------------------------------
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      onPressed: onClearSearch,
                      tooltip: 'مسح البحث',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 21,
                        color: isDark
                            ? Colors.white70
                            : AppColors.ink.withValues(
                                alpha: 0.65,
                              ),
                      ),
                    )
                  : null,

              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 4,
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// زر الإشعارات في الهيدر
// =============================================================
class _NotificationHeaderButton
    extends StatelessWidget {
  final VoidCallback onTap;

  const _NotificationHeaderButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: NotificationService.instance.getUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Tooltip(
          message: 'الإشعارات',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.94,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.brand.withValues(
                      alpha: 0.08,
                    ),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(
                        alpha: 0.14,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_rounded,
                        size: 24,
                        color: AppColors.brandDark,
                      ),
                    ),

                    // =================================================
                    // عداد الإشعارات غير المقروءة
                    // =================================================
                    if (unreadCount > 0)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: _UnreadBadge(
                          count: unreadCount,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================
// عداد الإشعارات
// =============================================================
class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(
        minWidth: 19,
        minHeight: 19,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(
              alpha: 0.25,
            ),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

// =============================================================
// زر دائري للهيدر
// =============================================================
class _HeaderCircleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.94,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.brand.withValues(
                  alpha: 0.08,
                ),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(
                    alpha: 0.14,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 25,
              color: AppColors.brandDark,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// دائرة ناعمة للزخرفة
// =============================================================
class _SoftCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SoftCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(
          alpha: opacity,
        ),
      ),
    );
  }
}