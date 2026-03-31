import 'dart:convert';

class Email {
  final String id;
  final String from;
  final List<String> to;
  final String subject;
  final String? html;
  final String? text;
  final DateTime createdAt;
  final List<Attachment> attachments;

  Email({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    this.html,
    this.text,
    required this.createdAt,
    this.attachments = const [],
  });

  factory Email.fromJson(Map<String, dynamic> json) {
    return Email(
      id: json['id'],
      from: json['from'],
      to: (json['to'] as List).cast<String>(),
      subject: json['subject'],
      html: json['html'],
      text: json['text'],
      createdAt: DateTime.parse(json['created_at']),
      attachments: (json['attachments'] as List? ?? [])
          .map((a) => Attachment.fromJson(a))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'subject': subject,
      'html': html,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
    };
  }

  String toRawJson() => jsonEncode(toJson());

  factory Email.fromRawJson(String source) {
    return Email.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }
}

class Attachment {
  final String id;
  final String filename;
  final String contentType;
  final int size;

  Attachment({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'],
      filename: json['filename'],
      contentType: json['content_type'],
      size: json['size'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'content_type': contentType,
      'size': size,
    };
  }
}

class EmailListItem {
  final String id;
  final String from;
  final List<String> to;
  final String subject;
  final DateTime createdAt;

  EmailListItem({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    required this.createdAt,
  });

  factory EmailListItem.fromJson(Map<String, dynamic> json) {
    return EmailListItem(
      id: json['id'],
      from: json['from'],
      to: (json['to'] as List).cast<String>(),
      subject: json['subject'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  factory EmailListItem.fromEmail(Email email) {
    return EmailListItem(
      id: email.id,
      from: email.from,
      to: email.to,
      subject: email.subject,
      createdAt: email.createdAt,
    );
  }
}

class ContactEntry {
  final String email;
  final String name;

  const ContactEntry({required this.email, required this.name});

  String get label => name.isNotEmpty ? '$name <$email>' : email;
}

String formatMailbox(String email, {String? name}) {
  final trimmedEmail = email.trim();
  final trimmedName = name?.trim() ?? '';
  if (trimmedName.isEmpty) {
    return trimmedEmail;
  }
  return '$trimmedName <$trimmedEmail>';
}

String extractEmailAddress(String mailbox) {
  final match = RegExp(r'<([^>]+)>').firstMatch(mailbox);
  if (match != null) {
    return match.group(1)!.trim();
  }
  return mailbox.trim();
}

String extractDisplayName(String mailbox) {
  final match = RegExp(r'^(.*?)\s*<[^>]+>$').firstMatch(mailbox.trim());
  if (match != null) {
    return match.group(1)!.trim();
  }

  final email = extractEmailAddress(mailbox);
  final atIndex = email.indexOf('@');
  if (atIndex > 0) {
    return email.substring(0, atIndex);
  }
  return email;
}
