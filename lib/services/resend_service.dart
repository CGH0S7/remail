import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/email.dart';

class ResendService {
  final String apiKey;
  static const String _baseUrl = 'https://api.resend.com';

  ResendService(this.apiKey);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  Future<List<EmailListItem>> listSentEmails() async {
    final response = await http.get(Uri.parse('$_baseUrl/emails'), headers: _headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).map((e) => EmailListItem.fromJson(e)).toList();
    } else {
      throw Exception('Failed to list sent emails: ${response.body}');
    }
  }

  Future<Email> getSentEmail(String id) async {
    final response = await http.get(Uri.parse('$_baseUrl/emails/$id'), headers: _headers);
    if (response.statusCode == 200) {
      return Email.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get sent email: ${response.body}');
    }
  }

  Future<List<EmailListItem>> listReceivedEmails() async {
    // Note: This endpoint is based on the rusend implementation (resend.receiving.list)
    final response = await http.get(Uri.parse('$_baseUrl/receiving/emails'), headers: _headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).map((e) => EmailListItem.fromJson(e)).toList();
    } else {
      throw Exception('Failed to list received emails: ${response.body}');
    }
  }

  Future<Email> getReceivedEmail(String id) async {
    final response = await http.get(Uri.parse('$_baseUrl/receiving/emails/$id'), headers: _headers);
    if (response.statusCode == 200) {
      return Email.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get received email: ${response.body}');
    }
  }

  Future<void> sendEmail({
    required String from,
    required List<String> to,
    required String subject,
    String? html,
    String? text,
    List<File>? attachments,
  }) async {
    final body = {
      'from': from,
      'to': to,
      'subject': subject,
      'html': html,
      'text': text,
    }..removeWhere((key, value) => value == null);

    if (attachments != null && attachments.isNotEmpty) {
      final attachmentList = <Map<String, dynamic>>[];
      for (final file in attachments) {
        final bytes = await file.readAsBytes();
        attachmentList.add({
          'content': base64Encode(bytes),
          'filename': path.basename(file.path),
        });
      }
      body['attachments'] = attachmentList;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/emails'),
      headers: _headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send email: ${response.body}');
    }
  }
}
