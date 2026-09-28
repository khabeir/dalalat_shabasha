import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'brand_theme.dart';
import 'support_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // ============================================================
  // —Ê«»ÿ «· ÿ»Ìﬁ
  // ============================================================

  static const _privacyPolicyUrl = '';
  static const _termsUrl = '';

  // ============================================================
  // »Ì«‰«  «·œ⁄„
  // ============================================================

  static const _supportWhatsAppNumber = '0914111214';
  static const _supportPhoneNumber = '0113339644';

  // ============================================================
  // «·‰„Ê–Ã
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _supabase = Supabase.instance.client;

  bool _isLogin = true;
  bool _usePhone = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ============================================================
  // œÊ—… ÕÌ«… «·‘«‘…
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // «·—”«∆·
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            message,
            textAlign: TextAlign.right,
          ),
        ),
      );
  }

  // ============================================================
  //  ÕÊÌ· «·√—ﬁ«„ «·⁄—»Ì…
  // ============================================================

  String _toWesternDigits(String input) {
    const arabic = '';

    final buffer = StringBuffer();

    for (final char in input.split('')) {
      final index = arabic.indexOf(char);

      buffer.write(
        index == -1 ? char : index.toString(),
      );
    }

    return buffer.toString();
  }

  // ============================================================
  //  ÿ»Ì⁄ —ﬁ„ «·Â« › «·”Êœ«‰Ì
  // ============================================================

  String? _normalizePhone(
    String value, {
    bool strict = false,
  }) {
    var phone = _toWesternDigits(value)
        .replaceAll(RegExp(r'[\s\-().]'), '')
        .trim();

    if (phone.isEmpty) return null;

    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    } else if (phone.startsWith('+')) {
      // ﬂ„« ÂÊ.
    } else if (phone.startsWith('0')) {
      phone = '+249${phone.substring(1)}';
    } else if (phone.startsWith('249')) {
      phone = '+$phone';
    } else if (RegExp(r'^[19]\d{8}$').hasMatch(phone)) {
      phone = '+249$phone';
    } else {
      return null;
    }

    final digits = phone.substring(1);

    if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) {
      return null;
    }

    if (strict &&
        phone.startsWith('+249') &&
        digits.length != 12) {
      return null;
    }

    return phone;
  }

  // ============================================================
  // «· Õﬁﬁ „‰ «·»—Ìœ
  // ============================================================

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value.trim());
  }

  String? _validateIdentifier(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return _usePhone
          ? '√œŒ· —ﬁ„ «·Â« ›'
          : '√œŒ· «·»—Ìœ «·≈·ﬂ —Ê‰Ì';
    }

    if (_usePhone) {
      return _normalizePhone(
                text,
                strict: !_isLogin,
              ) ==
              null
          ? '√œŒ· —ﬁ„ Â« › ’ÕÌÕ'
          : null;
    }

    return _isValidEmail(text)
        ? null
        : '√œŒ· »—Ìœ« ≈·ﬂ —Ê‰Ì« ’ÕÌÕ«';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '√œŒ· ﬂ·„… «·„—Ê—';
    }

    if (value.length < 6) {
      return 'ﬂ·„… «·„—Ê— ÌÃ» √‰  ﬂÊ‰ 6 √Õ—› ⁄·Ï «·√ﬁ·';
    }

    return null;
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '√œŒ· «·«”„ «·ﬂ«„·';
    }

    if (text.length < 2) {
      return '«·«”„ ﬁ’Ì— Ãœ«';
    }

    return null;
  }

  // ============================================================
  //  »œÌ· «·Ê÷⁄
  // ============================================================

  void _setMode(bool isLogin) {
    if (_loading || isLogin == _isLogin) return;

    final identifier = _identifierController.text;

    setState(() {
      _isLogin = isLogin;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });

    _formKey.currentState?.reset();
    _identifierController.text = identifier;
  }

  void _setMethod(bool usePhone) {
    if (_loading || usePhone == _usePhone) return;

    setState(() {
      _usePhone = usePhone;
      _identifierController.clear();
    });

    _formKey.currentState?.reset();
  }

  // ============================================================
  // «·≈—”«·
  // ============================================================

  Future<void> _submit() async {
    if (_loading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      final signedIn = _isLogin
          ? await _login()
          : await _register();

      if (signedIn && mounted) {
        TextInput.finishAutofillContext();

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('auth error: $e');

      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  //  ”ÃÌ· «·œŒÊ·
  // ============================================================

  Future<bool> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (_usePhone) {
      final phone = _normalizePhone(identifier);

      if (phone == null) {
        _showMessage('—ﬁ„ «·Â« › €Ì— ’ÕÌÕ');
        return false;
      }

      final response = await _phoneAuthRequest(
        action: 'login',
        phone: phone,
        password: password,
      );

      if (response['success'] != true) {
        _showMessage(
          response['message']?.toString() ??
              '—ﬁ„ «·Â« › √Ê ﬂ·„… «·„—Ê— €Ì— ’ÕÌÕ…',
        );

        return false;
      }

      final session = _readSession(response);

      if (session == null) {
        _showMessage(
          ' ⁄–— ≈‰‘«¡ Ã·”…  ”ÃÌ· «·œŒÊ·',
        );

        return false;
      }

      await _setSupabaseSession(session);
    } else {
      await _supabase.auth.signInWithPassword(
        email: identifier.toLowerCase(),
        password: password,
      );
    }

    _showMessage(' „  ”ÃÌ· «·œŒÊ· »‰Ã«Õ');

    return true;
  }

  // ============================================================
  // ≈‰‘«¡ «·Õ”«»
  // ============================================================

  Future<bool> _register() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    final fullName = _nameController.text.trim();

    // ------------------------------------------------------------
    // «· ”ÃÌ· »«·»—Ìœ «·≈·ﬂ —Ê‰Ì
    // ------------------------------------------------------------

    if (!_usePhone) {
      final response = await _supabase.auth.signUp(
        email: identifier.toLowerCase(),
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      if (response.user == null) {
        _showMessage(' ⁄–— ≈‰‘«¡ «·Õ”«»');
        return false;
      }

      if (response.session != null) {
        _showMessage(
          ' „ ≈‰‘«¡ «·Õ”«» Ê ”ÃÌ· «·œŒÊ· »‰Ã«Õ',
        );

        return true;
      }

      _showMessage(
        ' „ ≈‰‘«¡ «·Õ”«». √ﬂ¯œ »—Ìœﬂ «·≈·ﬂ —Ê‰Ì „‰ «·—”«·… '
        '«· Ì Ê’· ﬂ° À„ ”Ã¯· «·œŒÊ·.',
      );

      if (mounted) {
        setState(() {
          _isLogin = true;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      }

      return false;
    }

    // ------------------------------------------------------------
    // «· ”ÃÌ· »«·Â« ›
    // ------------------------------------------------------------

    final phone = _normalizePhone(
      identifier,
      strict: true,
    );

    if (phone == null) {
      _showMessage('—ﬁ„ «·Â« › €Ì— ’ÕÌÕ');
      return false;
    }

    final response = await _phoneAuthRequest(
      action: 'signup',
      phone: phone,
      password: password,
      fullName: fullName,
    );

    if (response['success'] != true) {
      _showMessage(
        response['message']?.toString() ??
            ' ⁄–— ≈‰‘«¡ «·Õ”«»',
      );

      return false;
    }

    final session = _readSession(response);

    if (session == null) {
      _showMessage(
        ' „ ≈‰‘«¡ «·Õ”«» Ê·ﬂ‰  ⁄–—  ”ÃÌ· «·œŒÊ·',
      );

      return false;
    }

    await _setSupabaseSession(session);

    _showMessage(
      ' „ ≈‰‘«¡ «·Õ”«» Ê ”ÃÌ· «·œŒÊ· »‰Ã«Õ',
    );

    return true;
  }

  // ============================================================
  // Edge Function «·Œ«’… »«·Â« ›
  // ============================================================

  Future<Map<String, dynamic>> _phoneAuthRequest({
    required String action,
    required String phone,
    required String password,
    String fullName = '',
  }) async {
    final response = await _supabase.functions.invoke(
      'phone-auth',
      body: {
        'action': action,
        'phone': phone,
        'password': password,
        if (fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );

    final data = response.data;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception(
      '«” Ã«»… €Ì— ’ÕÌÕ… „‰ Œ«œ„  ”ÃÌ· «·Â« ›',
    );
  }

  Map<String, dynamic>? _readSession(
    Map<String, dynamic> response,
  ) {
    final value = response['session'];

    return value is Map
        ? Map<String, dynamic>.from(value)
        : null;
  }

  Future<void> _setSupabaseSession(
    Map<String, dynamic> session,
  ) async {
    final refreshToken =
        session['refresh_token']?.toString();

    if (refreshToken == null ||
        refreshToken.isEmpty) {
      throw Exception(
        '»Ì«‰«  Ã·”…  ”ÃÌ· «·œŒÊ· ‰«ﬁ’…',
      );
    }

    await _supabase.auth.setSession(
      refreshToken,
    );
  }

  // ============================================================
  // „⁄«·Ã… «·√Œÿ«¡
  // ============================================================

  bool _isNetworkError(Object error) {
    if (error is AuthRetryableFetchException) {
      return true;
    }

    final text = error.toString().toLowerCase();

    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('timeout') ||
        text.contains('network is unreachable');
  }

  String _errorMessage(Object error) {
    if (_isNetworkError(error)) {
      return ' ⁄–— «·« ’«· »«·≈‰ —‰ . '
          ' Õﬁﬁ „‰ « ’«·ﬂ ÊÕ«Ê· „—… √Œ—Ï.';
    }

    if (error is AuthException) {
      return _translateAuthError(error.message);
    }

    if (error is FunctionException) {
      return _extractFunctionError(error);
    }

    if (error.toString().contains(
          '—ﬁ„ «·Â« › √Ê ﬂ·„… «·„—Ê—',
        )) {
      return '—ﬁ„ «·Â« › √Ê ﬂ·„… «·„—Ê— €Ì— ’ÕÌÕ…';
    }

    return 'ÕœÀ Œÿ√ €Ì— „ Êﬁ⁄. Õ«Ê· „—… √Œ—Ï.';
  }

  String _extractFunctionError(
    FunctionException error,
  ) {
    final details = error.details;

    if (details is Map) {
      final message = details['message']?.toString();

      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    if (details != null &&
        details.toString().contains('—ﬁ„ «·Â« ›')) {
      return '—ﬁ„ «·Â« › √Ê ﬂ·„… «·„—Ê— €Ì— ’ÕÌÕ…';
    }

    if (error.status == 429) {
      return '„Õ«Ê·«  ﬂÀÌ—…. «‰ Ÿ— ﬁ·Ì·« À„ Õ«Ê· „—… √Œ—Ï.';
    }

    if (error.status >= 500) {
      return '«·Œ«œ„ „‘€Ê· Õ«·Ì«. Õ«Ê· „—… √Œ—Ï »⁄œ ﬁ·Ì·.';
    }

    return ' ⁄–— «·« ’«· »Œ«œ„  ”ÃÌ· «·Â« ›';
  }

  String _translateAuthError(String message) {
    final text = message.toLowerCase();

    if (text.contains('invalid login credentials')) {
      return _usePhone
          ? '—ﬁ„ «·Â« › √Ê ﬂ·„… «·„—Ê— €Ì— ’ÕÌÕ…'
          : '«·»—Ìœ «·≈·ﬂ —Ê‰Ì √Ê ﬂ·„… «·„—Ê— €Ì— ’ÕÌÕ…';
    }

    if (text.contains('user already registered')) {
      return 'Â–« «·»—Ìœ «·≈·ﬂ —Ê‰Ì „”Ã· »«·›⁄·';
    }

    if (text.contains('email address') &&
        text.contains('invalid')) {
      return '√œŒ· »—Ìœ« ≈·ﬂ —Ê‰Ì« ’ÕÌÕ«';
    }

    if (text.contains('password should be at least')) {
      return 'ﬂ·„… «·„—Ê— ÌÃ» √‰  ﬂÊ‰ 6 √Õ—› ⁄·Ï «·√ﬁ·';
    }

    if (text.contains('weak password')) {
      return 'ﬂ·„… «·„—Ê— ÷⁄Ì›…° «Œ — ﬂ·„… „—Ê— √ﬁÊÏ';
    }

    if (text.contains('email not confirmed')) {
      return 'Ì—ÃÏ  √ﬂÌœ «·»—Ìœ «·≈·ﬂ —Ê‰Ì √Ê·«';
    }

    if (text.contains('too many requests') ||
        text.contains('rate limit')) {
      return ' „  Ã«Ê“ ⁄œœ «·„Õ«Ê·« . Õ«Ê· „—… √Œ—Ï ·«Õﬁ«';
    }

    return ' ⁄–— ≈ﬂ„«· «·⁄„·Ì…. Õ«Ê· „—… √Œ—Ï.';
  }

  // ============================================================
  // «·—Ê«»ÿ
  // ============================================================

  Future<void> _launch(
    Uri uri,
    String errorMessage,
  ) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showMessage(errorMessage);
      }
    } catch (_) {
      _showMessage(errorMessage);
    }
  }

  Future<void> _openLink(String url) {
    return _launch(
      Uri.parse(url),
      ' ⁄–— › Õ «·—«»ÿ',
    );
  }

  // ============================================================
  // “Œ«—› «·ÂÌœ— V3
  // ============================================================

  Widget _buildHeaderDecorations() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ======================================================
            //  ÊÂÃ »‰›”ÃÌ
            // ======================================================

            Positioned(
              top: -90,
              right: -70,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: 0.055,
                  ),
                ),
              ),
            ),

            // ======================================================
            // œ«∆—… –Â»Ì… ﬂ»Ì—…
            // ======================================================

            Positioned(
              top: -70,
              right: -50,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Brand.gold.withValues(
                    alpha: 0.18,
                  ),
                ),
              ),
            ),

            // ======================================================
            // ﬁÊ” –Â»Ì
            // ======================================================

            Positioned(
              top: -15,
              right: -72,
              child: Container(
                width: 185,
                height: 185,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Brand.gold.withValues(
                      alpha: 0.32,
                    ),
                    width: 2.2,
                  ),
                ),
              ),
            ),

            // ======================================================
            // ﬁÊ” –Â»Ì À«‰Ì
            // ======================================================

            Positioned(
              top: 18,
              right: -98,
              child: Container(
                width: 225,
                height: 225,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.09,
                    ),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // ======================================================
            // œ«∆—… “Œ—›Ì… Ì”«—
            // ======================================================

            Positioned(
              bottom: -105,
              left: -75,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: 0.045,
                  ),
                ),
              ),
            ),

            // ======================================================
            // ﬁÊ” Ì”«—
            // ======================================================

            Positioned(
              bottom: -80,
              left: -55,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Brand.gold.withValues(
                      alpha: 0.18,
                    ),
                    width: 2,
                  ),
                ),
              ),
            ),

            // ======================================================
            // Œÿ ﬁÿ—Ì ⁄·ÊÌ
            // ======================================================

            Positioned(
              top: 95,
              left: -55,
              child: Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: 170,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.045,
                    ),
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            // ======================================================
            // Œÿ ﬁÿ—Ì –Â»Ì
            // ======================================================

            Positioned(
              bottom: 48,
              right: -45,
              child: Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: 150,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Brand.gold.withValues(
                      alpha: 0.22,
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
              ),
            ),

            // ======================================================
            // ‰ﬁ«ÿ –Â»Ì…
            // ======================================================

            Positioned(
              top: 52,
              right: 76,
              child: _buildHeaderDot(7),
            ),

            Positioned(
              top: 77,
              right: 51,
              child: _buildHeaderDot(4),
            ),

            Positioned(
              top: 103,
              right: 92,
              child: _buildHeaderDot(3),
            ),

            Positioned(
              bottom: 54,
              right: 38,
              child: _buildHeaderDot(6),
            ),

            Positioned(
              bottom: 75,
              right: 60,
              child: _buildHeaderDot(3),
            ),

            Positioned(
              bottom: 45,
              left: 48,
              child: _buildHeaderDot(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderDot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Brand.gold.withValues(
          alpha: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: Brand.gold.withValues(
              alpha: 0.25,
            ),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // «·ÂÌœ— «·—∆Ì”Ì V3
  // ============================================================

  Widget _buildHeader() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 50,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==================================================
              // «·‘⁄«—
              // ==================================================

              const BrandWordmark(
                logoSize: 66,
                titleSize: 27,
              ),

              const SizedBox(height: 12),

              // ==================================================
              // «·Œÿ «·–Â»Ì
              // ==================================================

              Container(
                width: 62,
                height: 4,
                decoration: BoxDecoration(
                  color: Brand.gold,
                  borderRadius:
                      BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Brand.gold.withValues(
                        alpha: 0.30,
                      ),
                      blurRadius: 8,
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

  // ============================================================
  // “— «·—ÃÊ⁄ «·œ«∆—Ì
  // ============================================================

  Widget _buildBackButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(
          alpha: 0.12,
        ),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.18,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.10,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        tooltip: '—ÃÊ⁄',
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.maybePop(context);
        },
        icon: const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // ============================================================
  // «·„»œ· «·„ﬁ”„
  // ============================================================

  Widget _buildPillSwitch<T>({
    required List<
        (T value, IconData? icon, String label)> options,
    required T selected,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Brand.soft,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Brand.primary.withValues(
            alpha: 0.055,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: _loading
                    ? null
                    : () => onChanged(option.$1),
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: option.$1 == selected
                        ? Brand.primary
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(14),
                    boxShadow:
                        option.$1 == selected
                            ? [
                                BoxShadow(
                                  color: Brand.primary
                                      .withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 12,
                                  offset:
                                      const Offset(0, 5),
                                ),
                              ]
                            : null,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      if (option.$2 != null) ...[
                        Icon(
                          option.$2,
                          size: 18,
                          color:
                              option.$1 == selected
                                  ? Colors.white
                                  : Brand.ink,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          option.$3,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color:
                                option.$1 == selected
                                    ? Colors.white
                                    : Brand.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSwitch() {
    return _buildPillSwitch<bool>(
      options: const [
        (
          true,
          null,
          ' ”ÃÌ· «·œŒÊ·',
        ),
        (
          false,
          null,
          'Õ”«» ÃœÌœ',
        ),
      ],
      selected: _isLogin,
      onChanged: _setMode,
    );
  }

  Widget _buildMethodSwitch() {
    return _buildPillSwitch<bool>(
      options: const [
        (
          true,
          Icons.phone_outlined,
          '—ﬁ„ «·Â« ›',
        ),
        (
          false,
          Icons.email_outlined,
          '«·»—Ìœ «·≈·ﬂ —Ê‰Ì',
        ),
      ],
      selected: _usePhone,
      onChanged: _setMethod,
    );
  }

  // ============================================================
  //  ‰”Ìﬁ «·ÕﬁÊ·
  // ============================================================

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,

      prefixIcon: Icon(
        icon,
        color: Brand.primary,
        size: 22,
      ),

      suffixIcon: suffixIcon,

      filled: true,

      fillColor: Brand.soft.withValues(
        alpha: 0.65,
      ),

      contentPadding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 14,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: Brand.primary.withValues(
            alpha: 0.045,
          ),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Brand.primary,
          width: 1.6,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .error,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .error,
          width: 1.4,
        ),
      ),
    );
  }

  // ============================================================
  // ÕﬁÊ· «·‰„Ê–Ã
  // ============================================================

  Widget _buildFields() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        if (!_isLogin) ...[
          TextFormField(
            controller: _nameController,
            enabled: !_loading,
            textInputAction:
                TextInputAction.next,
            textCapitalization:
                TextCapitalization.words,
            autofillHints: const [
              AutofillHints.name,
            ],
            decoration: _fieldDecoration(
              label: '«·«”„ «·ﬂ«„·',
              icon:
                  Icons.person_outline_rounded,
            ),
            validator: _validateName,
          ),
          const SizedBox(height: 16),
        ],

        TextFormField(
          controller:
              _identifierController,
          enabled: !_loading,
          keyboardType: _usePhone
              ? TextInputType.phone
              : TextInputType.emailAddress,
          textInputAction:
              TextInputAction.next,
          autocorrect: false,
          autofillHints: [
            _usePhone
                ? AutofillHints.telephoneNumber
                : AutofillHints.email,
          ],
          inputFormatters: _usePhone
              ? [
                  FilteringTextInputFormatter.allow(
                    RegExp(
                      r'[0-9-+\s\-]',
                    ),
                  ),
                ]
              : null,
          decoration: _fieldDecoration(
            label: _usePhone
                ? '—ﬁ„ «·Â« ›'
                : '«·»—Ìœ «·≈·ﬂ —Ê‰Ì',
            hint: _usePhone
                ? '0912345678 „À·«'
                : 'example@email.com',
            helper: _usePhone && !_isLogin
                ? '—ﬁ„ ”Êœ«‰Ì° „À«·: 0912345678'
                : null,
            icon: _usePhone
                ? Icons.phone_outlined
                : Icons.email_outlined,
          ),
          validator: _validateIdentifier,
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller:
              _passwordController,
          enabled: !_loading,
          obscureText:
              _obscurePassword,
          textInputAction: _isLogin
              ? TextInputAction.done
              : TextInputAction.next,
          autofillHints: [
            _isLogin
                ? AutofillHints.password
                : AutofillHints.newPassword,
          ],
          decoration: _fieldDecoration(
            label: 'ﬂ·„… «·„—Ê—',
            icon:
                Icons.lock_outline_rounded,
            helper: _isLogin
                ? null
                : '6 √Õ—› ⁄·Ï «·√ﬁ·',
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? '≈ŸÂ«—'
                  : '≈Œ›«¡',
              onPressed: () {
                setState(
                  () => _obscurePassword =
                      !_obscurePassword,
                );
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Brand.ink,
              ),
            ),
          ),
          validator: _validatePassword,
          onFieldSubmitted: (_) {
            if (_isLogin) {
              _submit();
            }
          },
        ),

        if (!_isLogin) ...[
          const SizedBox(height: 16),

          TextFormField(
            controller:
                _confirmPasswordController,
            enabled: !_loading,
            obscureText:
                _obscureConfirmPassword,
            textInputAction:
                TextInputAction.done,
            autofillHints: const [
              AutofillHints.newPassword,
            ],
            decoration: _fieldDecoration(
              label:
                  ' √ﬂÌœ ﬂ·„… «·„—Ê—',
              icon:
                  Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                tooltip:
                    _obscureConfirmPassword
                        ? '≈ŸÂ«—'
                        : '≈Œ›«¡',
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword =
                        !_obscureConfirmPassword;
                  });
                },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Brand.ink,
                ),
              ),
            ),
            validator: (value) {
              if (value == null ||
                  value.isEmpty) {
                return '√ﬂœ ﬂ·„… «·„—Ê—';
              }

              if (value !=
                  _passwordController.text) {
                return 'ﬂ·„ « «·„—Ê— €Ì— „ ÿ«»ﬁ Ì‰';
              }

              return null;
            },
            onFieldSubmitted: (_) =>
                _submit(),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // “— «· ”ÃÌ·
  // ============================================================

  Widget _buildSubmitButton() {
    return BrandGoldButton(
      label: _isLogin
          ? ' ”ÃÌ· «·œŒÊ·'
          : '≈‰‘«¡ «·Õ”«»',
      icon: Icons.arrow_back_rounded,
      loading: _loading,
      onTap: _loading ? null : _submit,
    );
  }

  // ============================================================
  // «·‘—Êÿ Ê«·Œ’Ê’Ì…
  // ============================================================

  Widget _buildLegalNote() {
    final hasLinks =
        _privacyPolicyUrl.isNotEmpty ||
            _termsUrl.isNotEmpty;

    return Column(
      children: [
        Text(
          '»≈‰‘«¡ «·Õ”«» ›≈‰ﬂ  Ê«›ﬁ ⁄·Ï ‘—Êÿ «·«” Œœ«„ '
          'Ê”Ì«”… «·Œ’Ê’Ì….',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: Brand.ink.withValues(
              alpha: 0.65,
            ),
          ),
        ),

        if (hasLinks)
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (_termsUrl.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      _openLink(_termsUrl),
                  child: const Text(
                    '‘—Êÿ «·«” Œœ«„',
                  ),
                ),

              if (_privacyPolicyUrl
                  .isNotEmpty)
                TextButton(
                  onPressed: () =>
                      _openLink(
                        _privacyPolicyUrl,
                      ),
                  child: const Text(
                    '”Ì«”… «·Œ’Ê’Ì…',
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // ============================================================
  // »ÿ«ﬁ… «·œŒÊ·
  // ============================================================

  Widget _buildAuthCard() {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 460,
          ),
          child: Container(
            margin:
                const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              24,
              20,
              25,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .cardColor,
              borderRadius:
                  BorderRadius.circular(30),
              border: Border.all(
                color: Brand.primary
                    .withValues(
                  alpha: 0.055,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Brand.primary
                      .withValues(
                    alpha: 0.15,
                  ),
                  blurRadius: 30,
                  spreadRadius: 1,
                  offset:
                      const Offset(0, 12),
                ),
              ],
            ),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    _buildModeSwitch(),

                    const SizedBox(
                      height: 14,
                    ),

                    _buildMethodSwitch(),

                    const SizedBox(
                      height: 20,
                    ),

                    _buildFields(),

                    const SizedBox(
                      height: 23,
                    ),

                    _buildSubmitButton(),

                    if (!_isLogin) ...[
                      const SizedBox(
                        height: 13,
                      ),
                      _buildLegalNote(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // »ÿ«ﬁ… «·œ⁄„
  // ============================================================

  Widget _buildSupportCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        26,
      ),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 460,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Brand.primary
                    .withValues(
                  alpha: 0.08,
                ),
                blurRadius: 18,
                offset:
                    const Offset(0, 7),
              ),
            ],
          ),
          child: const SupportContactCard(
            title:
                '·«  ” ÿÌ⁄ «· ”ÃÌ· √Ê ≈÷«›… ≈⁄·«‰ﬂø',
            subtitle:
                ' Ê«’· „⁄‰« Ê”‰”«⁄œﬂ° √Ê ‰÷Ì› ≈⁄·«‰ﬂ '
                '»œ·« ⁄‰ﬂ. Ê≈‰ ‰”Ì  ﬂ·„… «·„—Ê— '
                '›‰⁄Ìœ  ⁄ÌÌ‰Â« ·ﬂ.',
            whatsappNumber:
                _supportWhatsAppNumber,
            phoneNumber:
                _supportPhoneNumber,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // «·»‰«¡ «·—∆Ì”Ì
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final topPadding =
        MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection:
          TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            Theme.of(context)
                .scaffoldBackgroundColor,

        body: Stack(
          children: [
            // ======================================================
            // «·Œ·›Ì…
            // ======================================================

            SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior
                      .onDrag,

              child: Column(
                children: [
                  // ==================================================
                  // «·ÂÌœ— V3
                  // ==================================================

                  Container(
                    width: double.infinity,
                    height: topPadding + 250,
                    decoration:
                        const BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment.topRight,
                        end:
                            Alignment.bottomLeft,
                        colors: [
                          Color(0xFF35147D),
                          Color(0xFF5423A5),
                          Color(0xFF6D35C2),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        _buildHeaderDecorations(),
                        Positioned.fill(
                          child: Padding(
                            padding:
                                EdgeInsets.only(
                              top: topPadding + 16,
                              bottom: 40,
                            ),
                            child:
                                _buildHeader(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // »ÿ«ﬁ… «·œŒÊ·
                  // ==================================================

                  _buildAuthCard(),

                  // ==================================================
                  // «·œ⁄„
                  // ==================================================

                  _buildSupportCard(),
                ],
              ),
            ),

            // ========================================================
            // “— «·—ÃÊ⁄ ›Êﬁ «·ÂÌœ—
            // ========================================================

            Positioned(
              top: topPadding + 8,
              right: 14,
              child: _buildBackButton(),
            ),
          ],
        ),
      ),
    );
  }
}
