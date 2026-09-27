import 'package:supabase_flutter/supabase_flutter.dart';

class VisitorStatsService {
  VisitorStatsService._();

  static final VisitorStatsService instance =
      VisitorStatsService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<int> getCurrentVisitors() async {
    final response = await _supabase.rpc(
      'get_current_visitors',
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
      getCurrentVisitors(),
      getTotalVisits(),
    ]);

    return {
      'current': results[0],
      'total': results[1],
    };
  }
}
