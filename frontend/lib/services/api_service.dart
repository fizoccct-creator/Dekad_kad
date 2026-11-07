import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/user_profile.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

class BadgeText {
  final String title, message, cta, tone;
  BadgeText.fromJson(Map<String, dynamic> j)
    : title = j['title'],
      message = j['message'],
      cta = j['cta'],
      tone = j['tone'];
}

class FollowUpSuggestion {
  final String message, channel;
  final int delayDays;
  FollowUpSuggestion.fromJson(Map<String, dynamic> j)
    : message = j['suggested_message'],
      channel = j['send_channel'],
      delayDays = j['delay_days'];
}

/// Client for the Dekad backend (see backend/main.py).
class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 45);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_baseUrl/api/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw ApiException('Could not reach the server: $e');
    }
    if (res.statusCode != 200) {
      String detail = 'Request failed';
      try {
        detail = (jsonDecode(res.body) as Map)['detail'].toString();
      } catch (_) {}
      throw ApiException(detail, statusCode: res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> rewriteBio(
    String rawBio,
    ProfileMode mode, {
    int maxLength = 200,
  }) async {
    final data = await _post('bio-rewrite', {
      'raw_bio': rawBio,
      'mode': mode.name,
      'max_length': maxLength,
    });
    return data['rewritten_bio'] as String;
  }

  Future<BadgeText> generateBadgeText(
    String badgeId,
    String eventContext,
    String userRole,
  ) async {
    return BadgeText.fromJson(
      await _post('badge-text', {
        'badge_id': badgeId,
        'event_context': eventContext,
        'user_role': userRole,
      }),
    );
  }

  Future<FollowUpSuggestion> suggestFollowUp(
    String contactId,
    String previousConversation,
    DateTime lastMeeting,
  ) async {
    return FollowUpSuggestion.fromJson(
      await _post('follow-up', {
        'contact_id': contactId,
        'previous_conversation': previousConversation,
        'last_meeting_date': lastMeeting.toIso8601String().split('T').first,
      }),
    );
  }

  Future<List<String>> summarizeNotes(String notes) async {
    final data = await _post('notes-summary', {'notes': notes});
    return List<String>.from(data['summary_bullets']);
  }
}
