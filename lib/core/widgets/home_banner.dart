import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

// =============================================================
// بيانات خانة واحدة من البنر.
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

  factory BannerSlideData.fromRow(Map<String, dynamic> row) {
    return BannerSlideData(
      slot: row['slot'] is int ? row['slot'] as int : 0,
      headline: row['headline']?.toString() ?? '',
      subtitle: row['subtitle']?.toString() ?? '',
    );
  }

  static const fallback = BannerSlideData(
    slot: 0,
    headline: 'دلالة شبشة',
    subtitle: 'اعرض منتجك أو ابحث عما تحتاجه',
  );
}

// =============================================================
// البنر الرئيسي.
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
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  static const _refreshInterval = Duration(minutes: 5);

  final _pageController = PageController();
  final _currentPage = ValueNotifier<int>(0);

  List<BannerSlideData> _slides = const [];
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

  Future<void> _loadSlides() async {
    try {
      final response = await Supabase.instance.client
          .from('home_banner_slides')
          .select('slot, headline, subtitle')
          .eq('is_active', true)
          .order('slot');

      final rows = List<Map<String, dynamic>>.from(response)
          .map(BannerSlideData.fromRow)
          .where(
            (slide) => slide.headline.trim().isNotEmpty,
          )
          .toList();

      if (!mounted) return;

      setState(() => _slides = rows);

      _restartAutoPlay();
    } catch (e) {
      debugPrint('loadBannerSlides error: $e');
    }
  }

  void _restartAutoPlay() {
    _autoPlayTimer?.cancel();

    if (_slides.length < 2) return;

    _autoPlayTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) {
        if (!mounted || !_pageController.hasClients) return;

        _pageController.animateToPage(
          (_currentPage.value + 1) % _slides.length,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides.isEmpty
        ? const [BannerSlideData.fallback]
        : _slides;

    return Column(
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (index) {
              _currentPage.value = index;
            },
            itemBuilder: (context, index) {
              final slide = slides[index];

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: BannerCardContent(
                  slot: slide.slot,
                  headline: slide.headline,
                  subtitle: slide.subtitle,
                  onAddListing: widget.onAddListing,
                  onBrowseCategories:
                      widget.onBrowseCategories,
                ),
              );
            },
          ),
        ),

        if (slides.length > 1) ...[
          const SizedBox(height: 6),
          ValueListenableBuilder<int>(
            valueListenable: _currentPage,
            builder: (context, current, _) {
              final currentIndex =
                  current.clamp(0, slides.length - 1).toInt();

              final currentSlot =
                  slides[currentIndex].slot;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (index) {
                    final active = index == currentIndex;

                    return AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active
                            ? BannerCardContent
                                .primaryColorForSlot(
                                currentSlot,
                              )
                            : BannerCardContent
                                .primaryColorForSlot(
                                slides[index].slot,
                              )
                                .withValues(alpha: 0.25),
                        borderRadius:
                            BorderRadius.circular(4),
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
// بطاقة البنر.
// اللون يتحدد تلقائياً حسب رقم الخانة.
// =============================================================
class BannerCardContent extends StatelessWidget {
  final int slot;
  final String headline;
  final String subtitle;
  final VoidCallback? onAddListing;
  final VoidCallback? onBrowseCategories;

  const BannerCardContent({
    super.key,
    required this.slot,
    required this.headline,
    required this.subtitle,
    this.onAddListing,
    this.onBrowseCategories,
  });

  // ===========================================================
  // اللون الأساسي لكل خانة.
  // ===========================================================
  static Color primaryColorForSlot(int slot) {
    switch (slot) {
      case 2:
        return const Color(0xFFFF8A1F);

      case 3:
        return const Color(0xFF00A884);

      case 1:
      default:
        return AppColors.brand;
    }
  }

  // ===========================================================
  // اللون الداكن لكل خانة.
  // ===========================================================
  static Color darkColorForSlot(int slot) {
    switch (slot) {
      case 2:
        return const Color(0xFFD95F00);

      case 3:
        return const Color(0xFF00695C);

      case 1:
      default:
        return AppColors.brandDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        primaryColorForSlot(slot);

    final darkColor =
        darkColorForSlot(slot);

    return Container(
      height: 172,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                primaryColor.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // -----------------------------------------------------
          // خلفية البنر.
          // -----------------------------------------------------
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  primaryColor,
                  darkColor,
                ],
              ),
            ),
          ),

          // -----------------------------------------------------
          // الدائرة الزخرفية العلوية.
          // -----------------------------------------------------
          Positioned(
            top: -45,
            left: -30,
            child: _DecorativeCircle(
              size: 150,
              opacity: 0.10,
            ),
          ),

          // -----------------------------------------------------
          // الدائرة الزخرفية السفلية.
          // -----------------------------------------------------
          Positioned(
            bottom: -55,
            right: -25,
            child: _DecorativeCircle(
              size: 160,
              opacity: 0.09,
            ),
          ),

          // -----------------------------------------------------
          // أيقونة المتجر الخلفية.
          // -----------------------------------------------------
          Positioned(
            top: 18,
            right: 18,
            child: Icon(
              Icons.storefront_rounded,
              size: 58,
              color:
                  Colors.white.withValues(alpha: 0.16),
            ),
          ),

          // -----------------------------------------------------
          // محتوى البنر.
          // -----------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (
                      context,
                      constraints,
                    ) {
                      final isSmallScreen =
                          constraints.maxWidth < 260;

                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          // -------------------------------------
                          // العنوان.
                          // -------------------------------------
                          Text(
                            headline,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize:
                                  isSmallScreen
                                      ? 20
                                      : 24,
                              fontWeight:
                                  FontWeight.w900,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // -------------------------------------
                          // الوصف.
                          // -------------------------------------
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.92,
                              ),
                              fontSize:
                                  isSmallScreen
                                      ? 12
                                      : 13.5,
                              fontWeight:
                                  FontWeight.w600,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // -------------------------------------
                          // الأزرار المتجاوبة.
                          // -------------------------------------
                          LayoutBuilder(
                            builder: (
                              context,
                              buttonConstraints,
                            ) {
                              final compact =
                                  buttonConstraints
                                          .maxWidth <
                                      260;

                              return Row(
                                children: [
                                  Flexible(
                                    child:
                                        _BannerButton(
                                      icon:
                                          Icons.add_rounded,
                                      label:
                                          'أضف إعلانك',
                                      onTap:
                                          onAddListing,
                                      darkColor:
                                          darkColor,
                                      compact:
                                          compact,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 8,
                                  ),

                                  Flexible(
                                    child:
                                        _BannerButton(
                                      icon: Icons
                                          .grid_view_rounded,
                                      label:
                                          'التصنيفات',
                                      outlined: true,
                                      onTap:
                                          onBrowseCategories,
                                      darkColor:
                                          darkColor,
                                      compact:
                                          compact,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // -------------------------------------------------
                // مساحة صغيرة قبل الأيقونة.
                // -------------------------------------------------
                const SizedBox(width: 8),

                // -------------------------------------------------
                // أيقونة حقيبة التسوق.
                // -------------------------------------------------
                const SizedBox(
                  width: 76,
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// زر البنر المتجاوب.
// =============================================================
class _BannerButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final iconSize = compact ? 15.0 : 18.0;

    final fontSize = compact ? 10.0 : 12.5;

    final horizontalPadding =
        compact ? 8.0 : 12.0;

    final verticalPadding =
        compact ? 6.0 : 7.0;

    final radius = compact ? 14.0 : 18.0;

    return Material(
      color: outlined
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(radius),
        child: Container(
          constraints: BoxConstraints(
            minHeight: compact ? 34 : 38,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: outlined
              ? BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white
                        .withValues(alpha: 0.55),
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: outlined
                    ? Colors.white
                    : darkColor,
              ),

              const SizedBox(width: 5),

              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: outlined
                        ? Colors.white
                        : darkColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
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
// دائرة زخرفية.
// =============================================================
class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(
          alpha: opacity,
        ),
      ),
    );
  }
}