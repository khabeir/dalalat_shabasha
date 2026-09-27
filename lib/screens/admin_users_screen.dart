import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import 'listing_details_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _pageSize = 30;

  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  String _query = '';
  Timer? _debounce;
  int _page = 0;

  List<Map<String, dynamic>> _users = [];

  final Map<String, int> _activeCounts = {};
  final Map<String, int> _pendingCounts = {};

  final Set<String> _busyIds = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();

    _currentUserId = _supabase.auth.currentUser?.id;

    _scrollController.addListener(_onScroll);

    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String _timeAgo(dynamic value) {
    final date = DateTime.tryParse(
      value?.toString() ?? '',
    )?.toLocal();

    if (date == null) return '';

    final diff = DateTime.now().difference(date);

    if (diff.inDays >= 365) {
      return 'منذ ${diff.inDays ~/ 365} سنة';
    }

    if (diff.inDays >= 30) {
      return 'منذ ${diff.inDays ~/ 30} شهر';
    }

    if (diff.inDays >= 1) {
      return 'منذ ${diff.inDays} يوم';
    }

    if (diff.inHours >= 1) {
      return 'منذ ${diff.inHours} ساعة';
    }

    if (diff.inMinutes >= 1) {
      return 'منذ ${diff.inMinutes} دقيقة';
    }

    return 'الآن';
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      )
                    : null,
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: Text(confirmLabel),
              ),
            ],
          ),
        );
      },
    );

    return result == true;
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
      await _loadUsers(reset: true);
    }
  }

  // ============================================================
  // تحميل الأعضاء
  // ============================================================

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadUsers(reset: false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 400),
      () {
        final query = value.trim();

        if (!mounted || query == _query) return;

        setState(() {
          _query = query;
        });

        _loadUsers(reset: true);
      },
    );
  }

  Future<void> _loadUsers({
    required bool reset,
  }) async {
    if (!reset && (_loadingMore || !_hasMore)) {
      return;
    }

    if (reset) {
      setState(() {
        _loading = _users.isEmpty;
        _error = null;
        _page = 0;
        _hasMore = true;
      });
    } else {
      setState(() {
        _loadingMore = true;
      });
    }

    final page = reset ? 0 : _page;

    try {
      var request = _supabase
          .from('profiles')
          .select(
            'id, full_name, phone, area, role, is_banned, created_at',
          );

      if (_query.isNotEmpty) {
        request = request.or(
          'full_name.ilike.%$_query%,phone.ilike.%$_query%',
        );
      }

      final from = page * _pageSize;

      final response = await request
          .order('created_at', ascending: false)
          .range(from, from + _pageSize - 1);

      final rows = List<Map<String, dynamic>>.from(response);

      await _loadListingCounts(rows);

      if (!mounted) return;

      setState(() {
        _users = reset ? rows : [..._users, ...rows];

        _page = page + 1;

        _hasMore = rows.length == _pageSize;

        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('loadUsers error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadingMore = false;
      });

      if (reset) {
        setState(() {
          _error =
              'تعذر تحميل الأعضاء. تحقق من اتصال الإنترنت وحاول مجدداً.';
        });
      } else {
        _showSnack('تعذر تحميل المزيد من الأعضاء');
      }
    }
  }

  Future<void> _loadListingCounts(
    List<Map<String, dynamic>> users,
  ) async {
    final ids = users
        .map((u) => u['id'])
        .whereType<String>()
        .toList();

    if (ids.isEmpty) return;

    try {
      final response = await _supabase
          .from('listings')
          .select('seller_id, status')
          .inFilter('seller_id', ids);

      for (final id in ids) {
        _activeCounts[id] = 0;
        _pendingCounts[id] = 0;
      }

      for (final row in List<Map<String, dynamic>>.from(response)) {
        final sellerId = row['seller_id']?.toString();

        if (sellerId == null) continue;

        if (row['status'] == 'approved') {
          _activeCounts[sellerId] =
              (_activeCounts[sellerId] ?? 0) + 1;
        } else if (row['status'] == 'pending') {
          _pendingCounts[sellerId] =
              (_pendingCounts[sellerId] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint('loadListingCounts error: $e');
    }
  }

  // ============================================================
  // تغيير الصلاحية
  // ============================================================

  Future<void> _toggleRole(
    Map<String, dynamic> user,
  ) async {
    final id = user['id']?.toString();

    if (id == null || _busyIds.contains(id)) return;

    final isAdmin = user['role'] == 'admin';

    final name =
        user['full_name']?.toString().trim().isNotEmpty == true
            ? user['full_name']
            : 'هذا المستخدم';

    if (isAdmin) {
      try {
        final admins = await _supabase
            .from('profiles')
            .select('id')
            .eq('role', 'admin');

        if (admins.length <= 1) {
          _showSnack(
            'لا يمكن إزالة صلاحية الأدمن عن آخر حساب أدمن',
          );
          return;
        }
      } catch (e) {
        debugPrint('count admins error: $e');
      }
    }

    final confirmed = await _confirm(
      title: isAdmin
          ? 'إزالة صلاحية الأدمن'
          : 'ترقية إلى أدمن',
      message: isAdmin
          ? 'هل تريد إزالة صلاحية الأدمن عن $name؟'
          : 'هل تريد منح $name صلاحيات الأدمن الكاملة؟\n'
              'سيستطيع مراجعة الإعلانات وإدارة الأعضاء.',
      confirmLabel: isAdmin ? 'إزالة' : 'ترقية',
      destructive: isAdmin,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _busyIds.add(id);
    });

    try {
      await _supabase
          .from('profiles')
          .update({
            'role': isAdmin ? 'user' : 'admin',
          })
          .eq('id', id);

      if (!mounted) return;

      setState(() {
        user['role'] = isAdmin ? 'user' : 'admin';
      });

      _showSnack(
        isAdmin
            ? 'تمت إزالة صلاحية الأدمن'
            : 'تمت الترقية إلى أدمن',
      );
    } catch (e) {
      debugPrint('toggleRole error: $e');
      _showSnack('تعذر تنفيذ العملية، حاول مرة أخرى');
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(id);
        });
      }
    }
  }

  // ============================================================
  // تعليق / إلغاء تعليق
  // ============================================================

  Future<void> _toggleBan(
    Map<String, dynamic> user,
  ) async {
    final id = user['id']?.toString();

    if (id == null || _busyIds.contains(id)) return;

    if (id == _currentUserId) {
      _showSnack('لا يمكنك تعليق حسابك الخاص');
      return;
    }

    final banned = user['is_banned'] == true;

    final name =
        user['full_name']?.toString().trim().isNotEmpty == true
            ? user['full_name']
            : 'هذا المستخدم';

    final confirmed = await _confirm(
      title: banned
          ? 'إلغاء تعليق الحساب'
          : 'تعليق الحساب',
      message: banned
          ? 'هل تريد إعادة تفعيل حساب $name؟'
          : 'سيُمنع $name من نشر إعلانات جديدة حتى تُلغي التعليق. '
              'إعلاناته الحالية تبقى كما هي. متابعة؟',
      confirmLabel: banned
          ? 'إلغاء التعليق'
          : 'تعليق الحساب',
      destructive: !banned,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _busyIds.add(id);
    });

    try {
      await _supabase
          .from('profiles')
          .update({
            'is_banned': !banned,
          })
          .eq('id', id);

      if (!mounted) return;

      setState(() {
        user['is_banned'] = !banned;
      });

      _showSnack(
        banned
            ? 'تم إلغاء تعليق الحساب'
            : 'تم تعليق الحساب',
      );
    } catch (e) {
      debugPrint('toggleBan error: $e');
      _showSnack('تعذر تنفيذ العملية، حاول مرة أخرى');
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(id);
        });
      }
    }
  }

  // ============================================================
  // تغيير كلمة السر
  // ============================================================

  Future<void> _changePassword(
    Map<String, dynamic> user,
  ) async {
    final id = user['id']?.toString();

    if (id == null || _busyIds.contains(id)) return;

    if (id == _currentUserId) {
      _showSnack(
        'لا يمكنك تغيير كلمة سر حسابك من هذه الصفحة',
      );
      return;
    }

    final name =
        user['full_name']?.toString().trim().isNotEmpty == true
            ? user['full_name'].toString().trim()
            : 'هذا المستخدم';

    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscurePassword = true;
    bool obscureConfirm = true;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  title: const Row(
                    children: [
                      Icon(
                        Icons.lock_reset_outlined,
                        color: AppColors.brand,
                      ),
                      SizedBox(width: 8),
                      Text('تغيير كلمة السر'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'العضو: $name',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          autofocus: true,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'كلمة السر الجديدة',
                            hintText: '6 أحرف أو أكثر',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  obscurePassword =
                                      !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmController,
                          obscureText: obscureConfirm,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة السر',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  obscureConfirm =
                                      !obscureConfirm;
                                });
                              },
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'يجب أن تكون كلمة السر 6 أحرف أو أكثر.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext, false);
                      },
                      child: const Text('إلغاء'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final password =
                            passwordController.text;
                        final confirm =
                            confirmController.text;

                        if (password.length < 6) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'كلمة السر يجب أن تكون 6 أحرف أو أكثر',
                              ),
                            ),
                          );
                          return;
                        }

                        if (password != confirm) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'كلمتا السر غير متطابقتين',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(dialogContext, true);
                      },
                      icon: const Icon(
                        Icons.save_outlined,
                      ),
                      label: const Text('حفظ'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (confirmed != true || !mounted) return;

      final password = passwordController.text;

      setState(() {
        _busyIds.add(id);
      });

      try {
        final response = await _supabase.functions.invoke(
          'admin-manage-user',
          body: {
            'action': 'change_password',
            'user_id': id,
            'password': password,
          },
        );

        if (!mounted) return;

        if (response.data is Map &&
            response.data['success'] == true) {
          _showSnack('تم تغيير كلمة سر العضو بنجاح');
        } else {
          final message = response.data is Map
              ? response.data['error']?.toString()
              : null;

          _showSnack(
            message == null || message.isEmpty
                ? 'تعذر تغيير كلمة السر'
                : message,
          );
        }
      } on FunctionException catch (e) {
        debugPrint(
          'changePassword FunctionException: '
          '${e.details}',
        );

        if (mounted) {
          _showSnack(
            _functionErrorMessage(e),
          );
        }
      } catch (e) {
        debugPrint('changePassword error: $e');

        if (mounted) {
          _showSnack(
            'تعذر تغيير كلمة السر. حاول مرة أخرى.',
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _busyIds.remove(id);
          });
        }
      }
    } finally {
      passwordController.dispose();
      confirmController.dispose();
    }
  }

  // ============================================================
  // حذف العضو نهائياً
  // ============================================================

  Future<void> _deleteUser(
    Map<String, dynamic> user,
  ) async {
    final id = user['id']?.toString();

    if (id == null || _busyIds.contains(id)) return;

    if (id == _currentUserId) {
      _showSnack(
        'لا يمكنك حذف حسابك الخاص من هذه الصفحة',
      );
      return;
    }

    final name =
        user['full_name']?.toString().trim().isNotEmpty == true
            ? user['full_name'].toString().trim()
            : 'هذا المستخدم';

    final phone =
        user['phone']?.toString().trim() ?? '';

    final isAdmin = user['role'] == 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('حذف العضو نهائياً'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'هل أنت متأكد من حذف حساب "$name" نهائياً؟',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    phone,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'تحذير: هذا الإجراء نهائي وسيتم حذف حساب '
                    'المستخدم من نظام تسجيل الدخول. لا يمكن التراجع '
                    'عن العملية بعد نجاحها.',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'هذا الحساب يمتلك صلاحية أدمن. سيتم التحقق '
                    'من وجود أدمن آخر قبل السماح بالحذف.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(
                  Icons.delete_forever_outlined,
                ),
                label: const Text('حذف نهائياً'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busyIds.add(id);
    });

    try {
      final response = await _supabase.functions.invoke(
        'admin-manage-user',
        body: {
          'action': 'delete_user',
          'user_id': id,
        },
      );

      if (!mounted) return;

      if (response.data is Map &&
          response.data['success'] == true) {
        setState(() {
          _users.removeWhere(
            (item) => item['id']?.toString() == id,
          );

          _activeCounts.remove(id);
          _pendingCounts.remove(id);
        });

        _showSnack('تم حذف العضو نهائياً');
      } else {
        final message = response.data is Map
            ? response.data['error']?.toString()
            : null;

        _showSnack(
          message == null || message.isEmpty
              ? 'تعذر حذف العضو'
              : message,
        );
      }
    } on FunctionException catch (e) {
      debugPrint(
        'deleteUser FunctionException: ${e.details}',
      );

      if (mounted) {
        _showSnack(
          _functionErrorMessage(e),
        );
      }
    } catch (e) {
      debugPrint('deleteUser error: $e');

      if (mounted) {
        _showSnack(
          'تعذر حذف العضو. حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(id);
        });
      }
    }
  }

  String _functionErrorMessage(
    FunctionException error,
  ) {
    final details = error.details;

    if (details is Map) {
      final message = details['error']?.toString();

      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    if (details is String && details.isNotEmpty) {
      return details;
    }

    return 'تعذر تنفيذ العملية. حاول مرة أخرى.';
  }

  // ============================================================
  // إعلانات المستخدم
  // ============================================================

  Future<void> _openUserListings(
    Map<String, dynamic> user,
  ) async {
    final id = user['id']?.toString();

    if (id == null) return;

    final name =
        user['full_name']?.toString().trim().isNotEmpty == true
            ? user['full_name']
            : 'المستخدم';

    List<Map<String, dynamic>> listings = [];

    String? error;

    try {
      final response = await _supabase
          .from('listings')
          .select(
            'id, title, price, currency, price_type, status, created_at',
          )
          .eq('seller_id', id)
          .order('created_at', ascending: false);

      listings = List<Map<String, dynamic>>.from(
        response,
      );
    } catch (e) {
      debugPrint('openUserListings error: $e');
      error = 'تعذر تحميل إعلانات هذا المستخدم';
    }

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SizedBox(
              height:
                  MediaQuery.of(sheetContext).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      8,
                    ),
                    child: Text(
                      'إعلانات $name',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: error != null
                        ? Center(
                            child: Text(error),
                          )
                        : listings.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد إعلانات لهذا المستخدم',
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                itemCount: listings.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(
                                  height: 1,
                                ),
                                itemBuilder:
                                    (context, index) {
                                  final listing =
                                      listings[index];

                                  final listingId =
                                      listing['id'];

                                  final title = listing['title']
                                      ?.toString()
                                      .trim();

                                  final status =
                                      listing['status']
                                          ?.toString();

                                  return ListTile(
                                    title: Text(
                                      (title == null ||
                                              title.isEmpty)
                                          ? 'إعلان بدون عنوان'
                                          : title,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _statusText(status),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_left,
                                    ),
                                    onTap: listingId is! int
                                        ? null
                                        : () {
                                            Navigator.pop(
                                              sheetContext,
                                            );

                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ListingDetailsScreen(
                                                  listingId:
                                                      listingId,
                                                ),
                                              ),
                                            );
                                          },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusText(String? status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'متاح';
      case 'rejected':
        return 'مرفوض';
      case 'sold':
        return 'تم البيع';
      case 'archived':
        return 'مؤرشف';
      default:
        return 'غير معروف';
    }
  }

  // ============================================================
  // بطاقة العضو
  // ============================================================

  Widget _buildUserCard(
    Map<String, dynamic> user,
  ) {
    final id = user['id']?.toString() ?? '';

    final busy = _busyIds.contains(id);

    final isAdmin = user['role'] == 'admin';

    final banned = user['is_banned'] == true;

    final isSelf = id == _currentUserId;

    final name =
        user['full_name']?.toString().trim().isNotEmpty == true
            ? user['full_name'].toString().trim()
            : 'بدون اسم';

    final phone =
        user['phone']?.toString().trim() ?? '';

    final area =
        user['area']?.toString().trim() ?? '';

    final activeCount =
        _activeCounts[id] ?? 0;

    final pendingCount =
        _pendingCounts[id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (busy)
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.brand,
            ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppColors.brandSoft,
                child: Text(
                  name.isNotEmpty
                      ? String.fromCharCode(
                          name.runes.first,
                        )
                      : '؟',
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  AppColors.ink,
                            ),
                          ),
                        ),

                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '(أنت)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 2),

                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style:
                            const TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey,
                        ),
                      ),

                    if (area.isNotEmpty)
                      Text(
                        area,
                        style:
                            const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                enabled: !busy,
                onSelected: (value) {
                  switch (value) {
                    case 'listings':
                      _openUserListings(user);
                      break;

                    case 'role':
                      _toggleRole(user);
                      break;

                    case 'ban':
                      _toggleBan(user);
                      break;

                    case 'password':
                      _changePassword(user);
                      break;

                    case 'delete':
                      _deleteUser(user);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'listings',
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_alt_outlined,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text('عرض إعلاناته'),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        Icon(
                          isAdmin
                              ? Icons
                                  .remove_moderator_outlined
                              : Icons
                                  .admin_panel_settings_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAdmin
                              ? 'إزالة صلاحية الأدمن'
                              : 'ترقية إلى أدمن',
                        ),
                      ],
                    ),
                  ),

                  if (!isSelf)
                    PopupMenuItem(
                      value: 'ban',
                      child: Row(
                        children: [
                          Icon(
                            banned
                                ? Icons
                                    .lock_open_outlined
                                : Icons.block_outlined,
                            size: 20,
                            color: banned
                                ? null
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            banned
                                ? 'إلغاء تعليق الحساب'
                                : 'تعليق الحساب',
                            style: TextStyle(
                              color: banned
                                  ? null
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (!isSelf)
                    const PopupMenuDivider(),

                  if (!isSelf)
                    const PopupMenuItem(
                      value: 'password',
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_reset_outlined,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text('تغيير كلمة السر'),
                        ],
                      ),
                    ),

                  if (!isSelf)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_forever_outlined,
                            size: 20,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'حذف العضو نهائياً',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (isAdmin)
                _badge(
                  'أدمن',
                  AppColors.gold,
                  AppColors.ink,
                ),

              if (banned)
                _badge(
                  'معلّق',
                  Colors.red.shade50,
                  Colors.red.shade700,
                ),

              _badge(
                '$activeCount نشط',
                AppColors.brandSoft,
                AppColors.brand,
              ),

              if (pendingCount > 0)
                _badge(
                  '$pendingCount قيد المراجعة',
                  Colors.orange.shade50,
                  Colors.orange.shade800,
                ),

              _badge(
                _timeAgo(user['created_at']),
                Colors.grey.shade100,
                Colors.grey.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(
    String text,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  // ============================================================
  // جسم الصفحة
  // ============================================================

  Widget _buildBody() {
    if (_checkingAdmin ||
        (_isAdmin && _loading)) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.brand,
        ),
      );
    }

    if (!_isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'هذه الصفحة مخصصة للأدمن فقط',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    _loadUsers(reset: true),
                child:
                    const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            14,
            12,
            14,
            8,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText:
                  'ابحث بالاسم أو رقم الهاتف',
              prefixIcon:
                  const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.clear,
                          ),
                          onPressed: () {
                            _searchController
                                .clear();

                            _onSearchChanged('');
                          },
                        ),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        Expanded(
          child: _users.isEmpty
              ? const Center(
                  child: Text(
                    'لا يوجد أعضاء مطابقون',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      _loadUsers(reset: true),
                  child: ListView.builder(
                    controller:
                        _scrollController,
                    padding:
                        const EdgeInsets.fromLTRB(
                      14,
                      4,
                      14,
                      24,
                    ),
                    itemCount:
                        _users.length +
                            (_hasMore ? 1 : 0),
                    itemBuilder:
                        (context, index) {
                      if (index >=
                          _users.length) {
                        return const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          child: Center(
                            child:
                                CircularProgressIndicator(),
                          ),
                        );
                      }

                      return _buildUserCard(
                        _users[index],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            AppColors.pageBackground,
        appBar: AppBar(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            _isAdmin
                ? 'الأعضاء (${_users.length}${_hasMore ? '+' : ''})'
                : 'الأعضاء',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }
}