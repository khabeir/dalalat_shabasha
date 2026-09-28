import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_form_widgets.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  static const Color _brandPurple = Color(0xFF5125A8);
  static const Color _deepPurple = Color(0xFF351477);
  static const Color _warmCream = Color(0xFFFFFBF5);
  static const Color _accentOrange = Color(0xFFFFB21A);

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _phoneController = TextEditingController();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _categories = [];
  final List<ListingImageItem> _images = [];

  int? _selectedCategoryId;
  String _priceType = 'negotiable';
  String _condition = 'used';

  // مدة ظهور الإعلان المطلوبة من صاحب الإعلان.
  // تبدأ فعلياً عند اعتماد الإعلان من الإدارة.
  String _displayDuration = 'month';

  bool _loadingCategories = true;
  bool _saving = false;
  String? _progress;

  // ============================================================
  // رسالة الإدارة
  // ============================================================

  String? _adminMessage;
  bool _adminMessageActive = false;

  @override
  void initState() {
    super.initState();

    _loadCategories();
    _loadDefaults();
    _loadAdminMessage();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // ============================================================
  // أدوات مساعدة
  // ============================================================

  void _showSnack(
    String message, {
    int seconds = 4,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: seconds),
        ),
      );
  }

  bool get _hasChanges {
    return _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _priceController.text.trim().isNotEmpty ||
        _areaController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _images.isNotEmpty ||
        _selectedCategoryId != null;
  }

  Future<void> _onBackPressed() async {
    if (_saving) return;

    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    final leave = await confirmListingDialog(
      context,
      title: 'تجاهل الإعلان؟',
      message: 'لديك بيانات لم تُنشر. هل تريد الخروج وتجاهلها؟',
      confirmLabel: 'خروج',
      destructive: true,
    );

    if (leave && mounted) {
      Navigator.pop(context);
    }
  }

  // ============================================================
  // تحميل البيانات
  // ============================================================

  Future<void> _loadCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('id, name, icon')
          .eq('is_active', true)
          .order('sort_order');

      if (!mounted) return;

      setState(() {
        _categories =
            List<Map<String, dynamic>>.from(response);
        _loadingCategories = false;
      });
    } catch (e) {
      debugPrint('loadCategories error: $e');

      if (!mounted) return;

      setState(() {
        _loadingCategories = false;
      });

      _showSnack('تعذر تحميل التصنيفات');
    }
  }

  Future<void> _loadDefaults() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('phone, area')
          .eq('id', user.id)
          .maybeSingle();

      var phone =
          profile?['phone']?.toString().trim() ?? '';

      if (phone.isEmpty) {
        phone =
            user.userMetadata?['phone']?.toString().trim() ??
                '';
      }

      if (phone.isEmpty) {
        phone = user.phone?.trim() ?? '';
      }

      final area =
          profile?['area']?.toString().trim() ?? '';

      if (!mounted) return;

      if (_phoneController.text.trim().isEmpty &&
          phone.isNotEmpty) {
        _phoneController.text = phone;
      }

      if (_areaController.text.trim().isEmpty &&
          area.isNotEmpty) {
        _areaController.text = area;
      }
    } catch (e) {
      debugPrint('loadDefaults error: $e');
    }
  }

  // ============================================================
  // تحميل رسالة الإدارة
  // ============================================================

  Future<void> _loadAdminMessage() async {
  try {
    final response = await _supabase
        .from('add_listing_admin_message')
        .select('id, message, is_active')
        .eq('id', 1)
        .maybeSingle();

    debugPrint('========================================');
    debugPrint('ADMIN MESSAGE RESPONSE: $response');
    debugPrint('========================================');

    if (!mounted) return;

    if (response == null) {
      setState(() {
        _adminMessage = null;
        _adminMessageActive = false;
      });
      return;
    }

    final message = response['message']?.toString().trim();
    final isActive = response['is_active'] == true;

    setState(() {
      _adminMessage =
          message != null && message.isNotEmpty ? message : null;

      _adminMessageActive =
          isActive && (_adminMessage?.isNotEmpty ?? false);
    });
  } catch (e, stackTrace) {
    debugPrint('========================================');
    debugPrint('ADMIN MESSAGE ERROR: $e');
    debugPrint('$stackTrace');
    debugPrint('========================================');

    if (!mounted) return;

    setState(() {
      _adminMessage = null;
      _adminMessageActive = false;
    });
  }
}

  // ============================================================
  // الصور
  // ============================================================

  Future<void> _addImages() async {
    final picked = await pickListingImages(
      context,
      _imagePicker,
      remaining:
          kMaxListingImages - _images.length,
    );

    if (picked.isEmpty || !mounted) return;

    setState(() {
      _images.addAll(
        picked.map(
          ListingImageItem.local,
        ),
      );
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _makeCover(int index) {
    setState(() {
      final item = _images.removeAt(index);
      _images.insert(0, item);
    });

    _showSnack(
      'تم تعيين الصورة كغلاف للإعلان',
      seconds: 2,
    );
  }

  // ============================================================
  // مدة الإعلان
  // ============================================================

  String _displayDurationTitle(
    String value,
  ) {
    switch (value) {
      case 'day':
        return 'يوم واحد';

      case 'week':
        return 'أسبوع واحد';

      case 'month':
        return 'شهر واحد';

      case 'unlimited':
        return 'غير محدود';

      default:
        return 'شهر واحد';
    }
  }

  String _displayDurationSubtitle(
    String value,
  ) {
    switch (value) {
      case 'day':
        return 'ينتهي بعد 24 ساعة من الموافقة';

      case 'week':
        return 'ينتهي بعد 7 أيام من الموافقة';

      case 'month':
        return 'ينتهي بعد شهر تقويمي من الموافقة';

      case 'unlimited':
        return 'يبقى منشوراً حتى تقوم الإدارة بإخفائه';

      default:
        return '';
    }
  }

  IconData _displayDurationIcon(
    String value,
  ) {
    switch (value) {
      case 'day':
        return Icons.today_outlined;

      case 'week':
        return Icons.date_range_outlined;

      case 'month':
        return Icons.calendar_month_outlined;

      case 'unlimited':
        return Icons.all_inclusive_rounded;

      default:
        return Icons.calendar_month_outlined;
    }
  }

  Widget _buildDisplayDurationOption({
    required String value,
  }) {
    final selected =
        _displayDuration == value;

    final colorScheme =
        Theme.of(context).colorScheme;

    return InkWell(
      borderRadius:
          BorderRadius.circular(16),
      onTap: _saving
          ? null
          : () {
              setState(() {
                _displayDuration = value;
              });
            },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding:
            const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? _brandPurple.withValues(
                  alpha: 0.08,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _brandPurple
                : colorScheme.outline.withValues(
                    alpha: 0.18,
                  ),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        _brandPurple.withValues(
                      alpha: 0.08,
                    ),
                    blurRadius: 10,
                    offset:
                        const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? _brandPurple
                    : _brandPurple.withValues(
                        alpha: 0.08,
                      ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _displayDurationIcon(value),
                size: 21,
                color: selected
                    ? Colors.white
                    : _brandPurple,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayDurationTitle(value),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          FontWeight.w800,
                      color: selected
                          ? _deepPurple
                          : colorScheme
                              .onSurface,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    _displayDurationSubtitle(
                      value,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? _brandPurple
                      : colorScheme.outline
                          .withValues(
                          alpha: 0.45,
                        ),
                  width: 1.6,
                ),
                color: selected
                    ? _brandPurple
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayDurationSection() {
    return ListingSectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const ListingSectionTitle(
            icon:
                Icons.schedule_outlined,
            title:
                'مدة ظهور الإعلان',
            subtitle:
                'اختر المدة المطلوبة لعرض إعلانك',
          ),

          const SizedBox(height: 8),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color:
                  _accentOrange.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 19,
                  color:
                      Colors.orange.shade800,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'تبدأ مدة الإعلان عند موافقة الإدارة، وليس عند إرسال الإعلان للمراجعة.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color:
                          Colors.orange.shade900,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _buildDisplayDurationOption(
            value: 'day',
          ),

          const SizedBox(height: 8),

          _buildDisplayDurationOption(
            value: 'week',
          ),

          const SizedBox(height: 8),

          _buildDisplayDurationOption(
            value: 'month',
          ),

          const SizedBox(height: 8),

          _buildDisplayDurationOption(
            value: 'unlimited',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // بطاقة رسالة الإدارة
  // ============================================================

  Widget _buildAdminMessage() {
    if (!_adminMessageActive ||
        _adminMessage == null ||
        _adminMessage!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topRight,
          end:
              Alignment.bottomLeft,
          colors: [
            _brandPurple.withValues(
              alpha: 0.10,
            ),
            _accentOrange.withValues(
              alpha: 0.10,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              _brandPurple.withValues(
            alpha: 0.16,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                _brandPurple.withValues(
              alpha: 0.06,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment:
                Alignment.center,
            decoration:
                const BoxDecoration(
              color: _brandPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'رسالة الإدارة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w900,
                    color: _deepPurple,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _adminMessage!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xFF3A3155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // التراجع عن الإعلان إذا فشل رفع الصور
  // ============================================================

  Future<void> _rollbackListing(
    int listingId,
  ) async {
    try {
      await _supabase
          .from('listings')
          .delete()
          .eq('id', listingId);
    } catch (e) {
      debugPrint(
        'rollbackListing error: $e',
      );
    }
  }

  // ============================================================
  // حفظ الإعلان
  // ============================================================

  Future<void> _saveListing() async {
    if (_saving) return;

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final categoryId =
        _selectedCategoryId;

    if (categoryId == null) {
      _showSnack(
        'اختر تصنيف الإعلان',
      );
      return;
    }

    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      _showSnack(
        'يجب تسجيل الدخول أولاً',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _progress =
          'جاري حفظ الإعلان...';
    });

    int? listingId;

    try {
      final response = await _supabase
          .from('listings')
          .insert({
        'seller_id': user.id,
        'category_id': categoryId,
        'title':
            _titleController.text.trim(),
        'description':
            _descriptionController
                .text
                .trim(),
        'price': _priceType == 'contact'
            ? null
            : parsePrice(
                _priceController.text,
              ),
        'currency': 'SDG',
        'price_type': _priceType,
        'condition': _condition,
        'area':
            _areaController.text.trim(),
        'contact_phone': cleanPhone(
          _phoneController.text,
        ),
        'status': 'pending',
        'display_duration':
            _displayDuration,
      })
          .select('id')
          .single();

      final id = response['id'];

      if (id is! int) {
        throw Exception(
          'تعذر الحصول على رقم الإعلان',
        );
      }

      listingId = id;

      var failed = 0;

      for (var i = 0;
          i < _images.length;
          i++) {
        final file =
            _images[i].file;

        if (file == null) continue;

        if (mounted) {
          setState(() {
            _progress =
                'جاري رفع الصورة ${i + 1} من ${_images.length}...';
          });
        }

        try {
          await uploadListingImage(
            supabase: _supabase,
            listingId: id,
            image: file,
            fileIndex: i,
            sortOrder: i,
          );
        } catch (e) {
          debugPrint(
            'upload image $i failed: $e',
          );
          failed++;
        }
      }

      if (_images.isNotEmpty &&
          failed == _images.length) {
        await _rollbackListing(id);
        listingId = null;

        _showSnack(
          'تعذر رفع الصور فلم يُحفظ الإعلان. '
          'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
          seconds: 6,
        );

        return;
      }

      if (!mounted) return;

      final buffer = StringBuffer(
        'تم إرسال الإعلان بنجاح، وهو الآن بانتظار المراجعة.',
      );

      if (failed > 0) {
        buffer.write(
          '\nتعذر رفع $failed من الصور، يمكنك إضافتها من "تعديل الإعلان".',
        );
      }

      _showSnack(
        buffer.toString(),
        seconds:
            failed > 0 ? 7 : 4,
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      debugPrint(
        'saveListing error: $e',
      );

      if (listingId != null) {
        await _rollbackListing(
          listingId,
        );
      }

      _showSnack(
        'تعذر حفظ الإعلان. تحقق من اتصال الإنترنت وحاول مرة أخرى.',
        seconds: 5,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  // ============================================================
  // إشعار المراجعة
  // ============================================================

  Widget _buildReviewNotice() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme
            .tertiaryContainer
            .withValues(
          alpha: 0.6,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color:
                colorScheme
                    .onTertiaryContainer,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              'سيُراجع الإعلان من الإدارة قبل ظهوره للمستخدمين.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color:
                    colorScheme
                        .onTertiaryContainer,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // بيانات الإعلان
  // ============================================================

  Widget _buildDetailsSection() {
    return ListingSectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const ListingSectionTitle(
            icon:
                Icons.edit_note_outlined,
            title:
                'بيانات الإعلان',
            subtitle:
                'أدخل المعلومات الأساسية',
          ),

          const SizedBox(height: 14),

          ListingCategoryField(
            categories:
                _categories,
            value:
                _selectedCategoryId,
            onChanged: (value) {
              setState(() {
                _selectedCategoryId =
                    value;
              });
            },
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller:
                _titleController,
            textInputAction:
                TextInputAction.next,
            maxLength:
                kMaxTitleLength,
            decoration:
                listingInputDecoration(
              context,
              label:
                  'عنوان الإعلان',
              hint:
                  'مثال: هاتف سامسونج للبيع',
              icon:
                  Icons.title_outlined,
            ),
            validator:
                validateListingTitle,
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller:
                _descriptionController,
            maxLines: 5,
            maxLength:
                kMaxDescriptionLength,
            decoration:
                listingInputDecoration(
              context,
              label:
                  'وصف الإعلان',
              hint:
                  'اكتب تفاصيل السلعة وحالتها...',
              icon:
                  Icons.description_outlined,
              alignLabelWithHint:
                  true,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // الموقع والتواصل
  // ============================================================

  Widget _buildContactSection() {
    return ListingSectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const ListingSectionTitle(
            icon:
                Icons.location_on_outlined,
            title:
                'الموقع والتواصل',
            subtitle:
                'كيف يمكن الوصول إليك؟',
          ),

          const SizedBox(height: 14),

          TextFormField(
            controller:
                _areaController,
            textInputAction:
                TextInputAction.next,
            decoration:
                listingInputDecoration(
              context,
              label:
                  'المنطقة',
              hint:
                  'مثال: الحي الثاني',
              icon:
                  Icons.location_on_outlined,
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller:
                _phoneController,
            keyboardType:
                TextInputType.phone,
            textInputAction:
                TextInputAction.done,
            decoration:
                listingInputDecoration(
              context,
              label:
                  'رقم التواصل',
              hint:
                  'رقم الهاتف أو الواتساب',
              icon:
                  Icons.phone_outlined,
              helper:
                  'يظهر للمشترين للاتصال بك',
            ),
            validator:
                validateContactPhone,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // زر نشر الإعلان
  // ============================================================

  Widget _buildPublishButton() {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  _brandPurple,
              foregroundColor:
                  Colors.white,
              elevation: 4,
              shadowColor:
                  _brandPurple.withValues(
                alpha: .28,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
            ),
            onPressed:
                _saving
                    ? null
                    : _saveListing,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.publish_outlined,
                    size: 21,
                  ),
            label: Text(
              _saving
                  ? 'جاري الحفظ...'
                  : 'نشر الإعلان',
              style:
                  const TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ),

        if (_saving &&
            _progress != null) ...[
          const SizedBox(height: 10),

          Text(
            _progress!,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ],
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
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult:
            (didPop, _) {
          if (!didPop) {
            _onBackPressed();
          }
        },
        child: Scaffold(
          backgroundColor:
              _warmCream,

          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            foregroundColor:
                Colors.white,
            flexibleSpace:
                const DecoratedBox(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topRight,
                  end:
                      Alignment.bottomLeft,
                  colors: [
                    _deepPurple,
                    _brandPurple,
                    Color(
                      0xFF7045C1,
                    ),
                  ],
                ),
              ),
            ),
            leading:
                IconButton(
              tooltip: 'رجوع',
              icon:
                  const Icon(
                Icons
                    .arrow_back_rounded,
              ),
              onPressed:
                  _onBackPressed,
            ),
            title:
                const Text(
              'إضافة إعلان',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
          ),

          body:
              _loadingCategories
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : Form(
                      key: _formKey,
                      autovalidateMode:
                          AutovalidateMode
                              .onUserInteraction,
                      child:
                          ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior
                                .onDrag,
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          16,
                          16,
                          16,
                          30,
                        ),
                        children: [
                          // ==================================================
                          // رسالة الإدارة - في أعلى الصفحة
                          // ==================================================

                          _buildAdminMessage(),

                          if (_adminMessageActive)
                            const SizedBox(
                              height: 12,
                            ),

                          // ==================================================
                          // إشعار المراجعة
                          // ==================================================

                          _buildReviewNotice(),

                          const SizedBox(
                            height: 14,
                          ),

                          // ==================================================
                          // بيانات الإعلان
                          // ==================================================

                          _buildDetailsSection(),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // الصور
                          // ==================================================

                          ListingSectionCard(
                            child:
                                ListingImagesSection(
                              items:
                                  _images,
                              enabled:
                                  !_saving,
                              onAdd:
                                  _addImages,
                              onRemove:
                                  _removeImage,
                              onMakeCover:
                                  _makeCover,
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // السعر
                          // ==================================================

                          ListingSectionCard(
                            child:
                                ListingPriceSection(
                              priceType:
                                  _priceType,
                              controller:
                                  _priceController,
                              onPriceTypeChanged:
                                  (value) {
                                setState(() {
                                  _priceType =
                                      value;
                                });
                              },
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // الحالة
                          // ==================================================

                          ListingSectionCard(
                            child:
                                ListingConditionSection(
                              condition:
                                  _condition,
                              onChanged:
                                  (value) {
                                setState(() {
                                  _condition =
                                      value;
                                });
                              },
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // مدة ظهور الإعلان
                          // ==================================================

                          _buildDisplayDurationSection(),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // الموقع والتواصل
                          // ==================================================

                          _buildContactSection(),

                          const SizedBox(
                            height: 18,
                          ),

                          // ==================================================
                          // نشر الإعلان
                          // ==================================================

                          _buildPublishButton(),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}