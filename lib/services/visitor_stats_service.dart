// lib/services/visitor_stats_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class VisitorStatsService {
  VisitorStatsService._();

  static final VisitorStatsService instance =
      VisitorStatsService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<int> getCurrentAnonymousVisitors() async {
    final response = await _supabase.rpc(
      'get_current_anonymous_visitors',
    );

    if (response is num) {
      return response.toInt();
    }

    return int.tryParse(response.toString()) ?? 0;
  }

  Future<int> getCurrentMembers() async {
    final response = await _supabase.rpc(
      'get_current_members',
    );

    if (response is num) {
      return response.toInt();
    }

    return int.tryParse(response.toString()) ?? 0;
  }

  Future<int> getCurrentTotal() async {
    final response = await _supabase.rpc(
      'get_current_total',
    );

    if (response is num) {
      return response.toInt();
    }

    return int.tryParse(response.toString()) ?? 0;
  }

  Future<int> getTotalVisits() async {
    final response = await _supabase.rpc(
      'get_total_visits',
    );

    if (response is num) {
      return response.toInt();
    }

    return int.tryParse(response.toString()) ?? 0;
  }

  Future<Map<String, int>> getStats() async {
    final results = await Future.wait([
      getCurrentAnonymousVisitors(),
      getCurrentMembers(),
      getCurrentTotal(),
      getTotalVisits(),
    ]);

    return {
      'anonymous': results[0],
      'members': results[1],
      'current': results[2],
      'total': results[3],
    };
  }
  Future<List<Map<String, dynamic>>> getCurrentMemberList() async {
  final response = await _supabase.rpc(
    'get_current_member_list',
  );

  if (response is List) {
    return response
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  return [];
}
}

