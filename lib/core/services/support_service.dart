import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';

class SupportService {
  static Future<Options> _opts() async {
    final token = await ApiService.getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  static String errorMessage(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['error'] != null) return d['error'].toString();
    }
    return 'Something went wrong. Please try again.';
  }

  static String formatTime(String? s) {
    final d = DateTime.tryParse(s ?? '');
    if (d == null) return '';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  static Future<List<dynamic>> listTickets() async {
    final res = await Dio().get('${ApiService.baseUrl}/support/tickets', options: await _opts());
    return (res.data['tickets'] as List?) ?? [];
  }

  static Future<void> createTicket(String subject, String message) async {
    await Dio().post(
      '${ApiService.baseUrl}/support/tickets',
      data: {'subject': subject, 'message': message},
      options: await _opts(),
    );
  }

  static Future<Map<String, dynamic>> getTicket(String id) async {
    final res = await Dio().get('${ApiService.baseUrl}/support/tickets/$id', options: await _opts());
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<void> reply(String id, String message) async {
    await Dio().post(
      '${ApiService.baseUrl}/support/tickets/$id/reply',
      data: {'message': message},
      options: await _opts(),
    );
  }
}