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
}
