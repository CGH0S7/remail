import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/email.dart';
import '../providers/auth_provider.dart';
import '../providers/email_provider.dart';
import '../services/resend_service.dart';
import 'compose_screen.dart';

class EmailDetailScreen extends StatelessWidget {
  final String id;
  final bool isReceived;

  const EmailDetailScreen({
    super.key,
    required this.id,
    required this.isReceived,
  });

  Future<void> _downloadAttachment(
    BuildContext context,
    String attachmentId,
    String filename,
  ) async {
    final auth = context.read<AuthProvider>();
    final service = ResendService(auth.apiKey!);

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloading $filename...')));

      final bytes = await service.downloadAttachment(id, attachmentId);
      Directory? dir;
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        dir = await getDownloadsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final filePath = path.join(dir.path, filename);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $filePath'),
          action: SnackBarAction(
            label: 'Open Folder',
            onPressed: () async {
              final uri = Uri.directory(dir!.path);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else if (Platform.isLinux) {
                  await Process.run('xdg-open', [dir.path]);
                } else if (Platform.isWindows) {
                  await Process.run('explorer.exe', [dir.path]);
                } else if (Platform.isMacOS) {
                  await Process.run('open', [dir.path]);
                }
              } catch (error) {
                debugPrint('Error opening folder: $error');
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to download: $error')));
    }
  }

  String _replySubject(String subject) {
    return subject.toLowerCase().startsWith('re:') ? subject : 'Re: $subject';
  }

  String _forwardSubject(String subject) {
    return subject.toLowerCase().startsWith('fwd:') ? subject : 'Fwd: $subject';
  }

  String _quotedBody(Email email) {
    final buffer = StringBuffer()
      ..writeln()
      ..writeln('--- Original message ---')
      ..writeln('From: ${email.from}')
      ..writeln('To: ${email.to.join(', ')}')
      ..writeln(
        'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(email.createdAt)}',
      )
      ..writeln('Subject: ${email.subject}')
      ..writeln();

    if (email.text != null && email.text!.trim().isNotEmpty) {
      buffer.write(email.text!.trim());
    } else if (email.html != null && email.html!.trim().isNotEmpty) {
      buffer.write(email.html!.replaceAll(RegExp(r'<[^>]*>'), ' ').trim());
    }

    return buffer.toString().trimRight();
  }

  void _openCompose(
    BuildContext context, {
    List<String> to = const [],
    required String subject,
    required String body,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeScreen(
          initialTo: to,
          initialSubject: subject,
          initialBody: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final service = ResendService(auth.apiKey!);

    return Scaffold(
      appBar: AppBar(title: const Text('Email Details')),
      body: FutureBuilder<Email>(
        future: context.read<EmailProvider>().fetchEmailDetail(
          service,
          id,
          isReceived,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Email not found.'));
          }

          final email = snapshot.data!;
          final provider = context.watch<EmailProvider>();
          final isStarred = provider.isStarred(email.id);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        email.subject,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await provider.toggleStarEmail(email);
                      },
                      icon: Icon(isStarred ? Icons.star : Icons.star_border),
                      color: isStarred ? Colors.amber : null,
                      tooltip: isStarred ? 'Remove star' : 'Star email',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      child: Text(
                        extractDisplayName(
                          email.from,
                        ).substring(0, 1).toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From: ${email.from}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('To: ${email.to.join(', ')}'),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, HH:mm').format(email.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        _openCompose(
                          context,
                          to: [extractEmailAddress(email.from)],
                          subject: _replySubject(email.subject),
                          body: '\n\n${_quotedBody(email)}',
                        );
                      },
                      icon: const Icon(Icons.reply),
                      label: const Text('Reply'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _openCompose(
                          context,
                          subject: _forwardSubject(email.subject),
                          body: _quotedBody(email),
                        );
                      },
                      icon: const Icon(Icons.forward),
                      label: const Text('Forward'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                if (email.html != null && email.html!.isNotEmpty)
                  HtmlWidget(email.html!)
                else if (email.text != null && email.text!.isNotEmpty)
                  Text(email.text!)
                else
                  const Text(
                    'No content available.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                if (email.attachments.isNotEmpty) ...[
                  const Divider(height: 48),
                  const Text(
                    'Attachments:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: email.attachments.map((attachment) {
                      return ActionChip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(attachment.filename),
                        onPressed: () => _downloadAttachment(
                          context,
                          attachment.id,
                          attachment.filename,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
