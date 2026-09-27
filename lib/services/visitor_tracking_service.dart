// lib/services/visitor_tracking_service.dart

import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class VisitorTrackingService {
  VisitorTrackingService._();

  static final VisitorTrackingService instance =
      VisitorTrackingService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Timer? _heartbeatTimer;

  String? _sessionId;

  bool _started = false;

  Future<void> start() async {
    if (_started) return;

    final sessionId = _createSessionId();

    try {
      await _supabase.rpc(
        'start_visitor_session',
        params: {
          'p_session_id': sessionId,
        },
      );

      _sessionId = sessionId;
      _started = true;

      _startHeartbeat();
    } catch (_) {
      // لا نوقف التطبيق إذا فشل تسجيل الزيارة.
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) async {
        await _sendHeartbeat();
      },
    );
  }

  Future<void> _sendHeartbeat() async {
    final sessionId = _sessionId;

    if (!_started || sessionId == null) return;

    try {
      await _supabase.rpc(
        'heartbeat_visitor_session',
        params: {
          'p_session_id': sessionId,
        },
      );
    } catch (_) {
      // تجاهل الخطأ حتى لا يؤثر على التطبيق.
    }
  }

  String _createSessionId() {
    final random = Random();

    final randomPart = List.generate(
      16,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();

    return '${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sessionId = null;
    _started = false;
  }
}