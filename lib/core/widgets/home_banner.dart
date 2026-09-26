import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

// =============================================================
// بيانات خانة واحدة من البنر
// =============================================================
class BannerSlideData {
  final int slot;
  final String headline;
  final String subtitle;

  const BannerSlideData({
    required this.slot,
    required this.headline,
    required this.subtitle,
  });

  factory BannerSlideData.fromRow(
    Map<String, dynamic> row,
  ) {
    return BannerSlideData(
      slot: row['slot'] is int
          ? row['slot'] as int
          : 0,
      headline:
          row['headline']?.toString() ?? '',
      subtitle:
          row['subtitle']?.toString() ?? '',
    );
  }

  static const fallback =
      BannerSlideData(
    slot: 1,
    headline: 'دلالة شبشة',
    subtitle:
        'اعرض منتجك أو ابحث عما تحتاجه',
  );
}

// =============================================================
// البنر الرئيسي
// =============================================================
class HomeBanner extends StatefulWidget {
  final VoidCallback onAddListing;
  final VoidCallback onBrowseCategories;

  const HomeBanner({
    super.key,
    required this.onAddListing,
    required this.onBrowseCategories,
  });

  @override
  State<HomeBanner> createState() =>
      _HomeBannerState();
}

class _HomeBannerState
    extends State<HomeBanner> {
  static const _refreshInterval =
      Duration(minutes: 5);

  final _pageController =
      PageController();

  final _currentPage =
      ValueNotifier<int>(0);

  List<BannerSlideData> _slides =
      const [];

  Timer? _refreshTimer;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();

    _loadSlides();

    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _loadSlides(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _autoPlayTimer?.cancel();

    _pageController.dispose();
    _currentPage.dispose();

    super.dispose();
  }

  // ===========================================================
  // تحميل البنرات من Supabase
  // ===========================================================
  Future<void> _loadSlides() async {
    try {
      final response =
          await Supabase.instance.client
              .from('home_banner_slides')
              .select(
                'slot, headline, subtitle',
              )
              .eq('is_active', true)
              .order('slot');

      final rows =
          List<Map<String, dynamic>>.from(
        response,
      )
              .map(
                BannerSlideData.fromRow,
              )
              .where(
                (slide) =>
                    slide.headline
                        .trim()
                        .isNotEmpty,
              )
              .toList();

      if (!mounted) return;

      setState(() {
        _slides = rows;
      });

      // التأكد من أن الصفحة الحالية
      // لا تتجاوز عدد البنرات الجديدة.
      if (_slides.isNotEmpty &&
          _currentPage.value >=
              _slides.length) {
        _currentPage.value =
            _slides.length - 1;

        if (_pageController.hasClients) {
          _pageController.jumpToPage(
            _currentPage.value,
          );
        }
      }

      _restartAutoPlay();
    } catch (e) {
      debugPrint(
        'loadBannerSlides error: $e',
      );
    }
  }

  // ===========================================================
  // التشغيل التلقائي
  // ===========================================================
  void _restartAutoPlay() {
    _autoPlayTimer?.cancel();

    if (_slides.length < 2) return;

    _autoPlayTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) {
        if (!mounted ||
            !_pageController.hasClients ||
            _slides.length < 2) {
          return;
        }

        final nextPage =
            (_currentPage.value + 1) %
                _slides.length;

        _pageController.animateToPage(
          nextPage,
          duration:
              const Duration(
            milliseconds: 450,
          ),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final slides = _slides.isEmpty
        ? const [
            BannerSlideData.fallback,
          ]
        : _slides;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // =====================================================
        // البنر
        // =====================================================
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller:
                _pageController,
            itemCount: slides.length,
            onPageChanged: (index) {
              _currentPage.value =
                  index;
            },
            itemBuilder:
                (context, index) {
              final slide =
                  slides[index];

              return Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child:
                    BannerCardContent(
                  slot: slide.slot,
                  headline:
                      slide.headline,
                  subtitle:
                      slide.subtitle,
                  onAddListing:
                      widget
                          .onAddListing,
                  onBrowseCategories:
                      widget
                          .onBrowseCategories,
                ),
              );
            },
          ),
        ),

        // =====================================================
        // مؤشرات الصفحات
        // =====================================================
        if (slides.length > 1) ...[
          const SizedBox(height: 6),

          ValueListenableBuilder<int>(
            valueListenable:
                _currentPage,
            builder: (
              context,
              current,
              _,
            ) {
              final currentIndex =
                  current
                      .clamp(
                        0,
                        slides.length - 1,
                      )
                      .toInt();

              return Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children:
                    List.generate(
                  slides.length,
                  (index) {
                    final active =
                        index ==
                            currentIndex;

                    final color =
                        BannerCardContent
                            .primaryColorForSlot(
                      slides[index].slot,
                    );

                    return AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 220,
                      ),
                      margin:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 3,
                      ),
                      width:
                          active ? 19 : 7,
                      height: 7,
                      decoration:
                          BoxDecoration(
                        color: active
                            ? color
                            : color.withValues(
                                alpha: 0.22,
                              ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          4,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// =============================================================
// بطاقة البنر
// =============================================================
class BannerCardContent
    extends StatelessWidget {
  final int slot;
  final String headline;
  final String subtitle;

  final VoidCallback? onAddListing;
  final VoidCallback?
      onBrowseCategories;

  const BannerCardContent({
    super.key,
    required this.slot,
    required this.headline,
    required this.subtitle,
    this.onAddListing,
    this.onBrowseCategories,
  });

  // ===========================================================
  // اللون الأساسي لكل خانة
  // ===========================================================
  static Color primaryColorForSlot(
    int slot,
  ) {
    switch (slot) {
      // البنر الثاني
      case 2:
        return const Color(
          0xFFFF8A1F,
        );

      // البنر الثالث
      case 3:
        return const Color(
          0xFF00A884,
        );

      // البنر الأول
      case 1:
      default:
        return AppColors.brand;
    }
  }

  // ===========================================================
  // اللون الداكن لكل خانة
  // ===========================================================
  static Color darkColorForSlot(
    int slot,
  ) {
    switch (slot) {
      case 2:
        return const Color(
          0xFFD95F00,
        );

      case 3:
        return const Color(
          0xFF00695C,
        );

      case 1:
      default:
        return AppColors.brandDark;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final primaryColor =
        primaryColorForSlot(slot);

    final darkColor =
        darkColorForSlot(slot);

    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      height: 172,
      clipBehavior:
          Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(
              alpha: isDark
                  ? 0.25
                  : 0.18,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ===================================================
          // الخلفية
          // ===================================================
          DecoratedBox(
            decoration:
                BoxDecoration(
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topRight,
                end:
                    Alignment.bottomLeft,
                colors: [
                  primaryColor,
                  darkColor,
                ],
              ),
            ),
          ),

          // ===================================================
          // زخارف ناعمة
          // ===================================================
          Positioned(
            top: -65,
            right: -45,
            child:
                _BannerCircle(
              size: 175,
              color:
                  Colors.white,
              opacity:
                  isDark
                      ? 0.08
                      : 0.12,
            ),
          ),

          Positioned(
            bottom: -75,
            left: -45,
            child:
                _BannerCircle(
              size: 185,
              color:
                  Colors.white,
              opacity:
                  isDark
                      ? 0.07
                      : 0.10,
            ),
          ),

          Positioned(
            top: 38,
            left: -25,
            child:
                _BannerCircle(
              size: 80,
              color:
                  Colors.white,
              opacity:
                  isDark
                      ? 0.05
                      : 0.08,
            ),
          ),

          // ===================================================
          // أشكال صغيرة
          // ===================================================
          Positioned(
            top: 22,
            left: 32,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color:
                  Colors.white.withValues(
                alpha: 0.45,
              ),
            ),
          ),

          Positioned(
            bottom: 24,
            right: 115,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 12,
              color:
                  Colors.white.withValues(
                alpha: 0.35,
              ),
            ),
          ),

          // ===================================================
          // أيقونة المتجر الخلفية
          // ===================================================
          Positioned(
            top: 15,
            right: 18,
            child: Icon(
              Icons.storefront_rounded,
              size: 55,
              color:
                  Colors.white.withValues(
                alpha: 0.12,
              ),
            ),
          ),

          // ===================================================
          // المحتوى
          // ===================================================
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              17,
              18,
              15,
            ),
            child:
                LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final compact =
                    constraints.maxWidth <
                        380;

                return Row(
                  children: [
                    // =========================================
                    // المحتوى النصي
                    // =========================================
                    Expanded(
                      child:
                          Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          // -------------------------------------
                          // العنوان
                          // -------------------------------------
                          Text(
                            headline,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  compact
                                      ? 21
                                      : 24,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              height:
                                  1.08,
                              letterSpacing:
                                  -0.2,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          // -------------------------------------
                          // النص أسفل العنوان
                          // -------------------------------------
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color: Colors
                                  .white
                                  .withValues(
                                alpha: 0.92,
                              ),
                              fontSize:
                                  compact
                                      ? 12
                                      : 13.5,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              height:
                                  1.32,
                            ),
                          ),

                          const SizedBox(
                            height: 11,
                          ),

                          // -------------------------------------
                          // الأزرار
                          // -------------------------------------
                          LayoutBuilder(
                            builder: (
                              context,
                              buttonConstraints,
                            ) {
                              final smallButtons =
                                  buttonConstraints
                                          .maxWidth <
                                      260;

                              return Row(
                                children: [
                                  // ===========================
                                  // أضف إعلانك
                                  // ===========================
                                  Flexible(
                                    child:
                                        _BannerButton(
                                      icon: Icons
                                          .add_rounded,
                                      label:
                                          'أضف إعلانك',
                                      onTap:
                                          onAddListing,
                                      darkColor:
                                          darkColor,
                                      compact:
                                          smallButtons,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 7,
                                  ),

                                  // ===========================
                                  // التصنيفات
                                  // ===========================
                                  Flexible(
                                    child:
                                        _BannerButton(
                                      icon: Icons
                                          .grid_view_rounded,
                                      label:
                                          'التصنيفات',
                                      outlined:
                                          true,
                                      onTap:
                                          onBrowseCategories,
                                      darkColor:
                                          darkColor,
                                      compact:
                                          smallButtons,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    // =========================================
                    // أيقونة الحقيبة
                    // =========================================
                    _buildShoppingIcon(
                      compact,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // أيقونة حقيبة التسوق
  // ===========================================================
  Widget _buildShoppingIcon(
    bool compact,
  ) {
    final size =
        compact ? 58.0 : 68.0;

    return SizedBox(
      width: compact ? 62 : 72,
      child: Center(
        child: Stack(
          alignment:
              Alignment.center,
          clipBehavior:
              Clip.none,
          children: [
            // ---------------------------------------------------
            // دائرة خلف الحقيبة
            // ---------------------------------------------------
            Container(
              width: size + 12,
              height: size + 12,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withValues(
                  alpha: 0.10,
                ),
              ),
            ),

            // ---------------------------------------------------
            // الحقيبة
            // ---------------------------------------------------
            Icon(
              Icons
                  .shopping_bag_rounded,
              size: size,
              color:
                  Colors.white,
            ),

            // ---------------------------------------------------
            // نقطة ذهبية
            // ---------------------------------------------------
            Positioned(
              top: -1,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      AppColors.gold,
                ),
                child: const Icon(
                  Icons
                      .auto_awesome_rounded,
                  size: 9,
                  color:
                      AppColors.brandDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// زر البنر المتجاوب
// =============================================================
class _BannerButton
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final Color darkColor;
  final bool compact;

  const _BannerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.darkColor,
    required this.compact,
    this.outlined = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final iconSize =
        compact ? 15.5 : 18.0;

    final fontSize =
        compact ? 10.5 : 13.0;

    final horizontalPadding =
        compact ? 8.0 : 12.0;

    final verticalPadding =
        compact ? 5.5 : 7.0;

    final radius =
        compact ? 14.0 : 18.0;

    return Material(
      color: outlined
          ? Colors.white.withValues(
              alpha: 0.13,
            )
          : Colors.white,
      borderRadius:
          BorderRadius.circular(
        radius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          radius,
        ),
        child: Container(
          constraints:
              BoxConstraints(
            minHeight:
                compact ? 34 : 38,
          ),
          padding:
              EdgeInsets.symmetric(
            horizontal:
                horizontalPadding,
            vertical:
                verticalPadding,
          ),
          decoration: outlined
              ? BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    radius,
                  ),
                  border:
                      Border.all(
                    color: Colors
                        .white
                        .withValues(
                      alpha: 0.62,
                    ),
                    width: 1.1,
                  ),
                )
              : null,
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              // -----------------------------------------------
              // الأيقونة
              // -----------------------------------------------
              Icon(
                icon,
                size: iconSize,
                color: outlined
                    ? Colors.white
                    : darkColor,
              ),

              const SizedBox(
                width: 5,
              ),

              // -----------------------------------------------
              // النص
              // -----------------------------------------------
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color: outlined
                        ? Colors.white
                        : darkColor,
                    fontSize:
                        fontSize,
                    fontWeight:
                        FontWeight
                            .w900,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// دائرة زخرفية للبنر
// =============================================================
class _BannerCircle
    extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _BannerCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(
          alpha: opacity,
        ),
      ),
    );
  }
}