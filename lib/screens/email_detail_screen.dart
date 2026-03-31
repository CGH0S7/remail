import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/email.dart';
import '../providers/auth_provider.dart';
import '../providers/email_provider.dart';
import '../services/resend_service.dart';

class EmailDetailScreen extends StatelessWidget {
  final String id;
  final bool isReceived;

  const EmailDetailScreen({super.key, required this.id, required this.isReceived});

  void _downloadAttachment(BuildContext context, String attachmentId, String filename) async {
    final auth = context.read<AuthProvider>();
    final service = ResendService(auth.apiKey!);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $filename...')),
      );

      final bytes = await service.downloadAttachment(id, attachmentId);
      
      // Get directory to save (e.g. Downloads or Documents)
      Directory? dir;
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        dir = await getDownloadsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final filePath = path.join(dir.path, filename);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $filePath'),
            action: SnackBarAction(
              label: 'Open Folder',
              onPressed: () {
                // Potential to use url_launcher to open the directory
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final service = ResendService(auth.apiKey!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Details'),
      ),
      body: FutureBuilder<Email>(
        future: context.read<EmailProvider>().fetchEmailDetail(service, id, isReceived),
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.subject,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(child: Text(email.from[0].toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From: ${email.from}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                const Divider(height: 32),
                if (email.html != null && email.html!.isNotEmpty)
                  HtmlWidget(email.html!)
                else if (email.text != null && email.text!.isNotEmpty)
                  Text(email.text!)
                else
                  const Text('No content available.', style: TextStyle(fontStyle: FontStyle.italic)),
                
                if (email.attachments.isNotEmpty) ...[
                  const Divider(height: 48),
                  const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: email.attachments.map((a) {
                      return ActionChip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(a.filename),
                        onPressed: () => _downloadAttachment(context, a.id, a.filename),
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
