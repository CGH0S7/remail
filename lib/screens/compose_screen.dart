import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/resend_service.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<File> _attachments = [];
  bool _isSending = false;

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _attachments.addAll(result.paths.where((p) => p != null).map((p) => File(p!)));
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _send() async {
    if (_toController.text.isEmpty || _subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in To and Subject')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      final service = ResendService(auth.apiKey!);
      
      final toList = _toController.text.split(',').map((e) => e.trim()).toList();
      
      await service.sendEmail(
        from: auth.defaultFrom!,
        to: toList,
        subject: _subjectController.text,
        text: _bodyController.text,
        attachments: _attachments,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email sent successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Email'),
        actions: [
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _send,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('From: ${auth.defaultFrom}', style: Theme.of(context).textTheme.bodyLarge),
            const Divider(height: 24),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To (comma separated)',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                hintText: 'Email body...',
                border: InputBorder.none,
              ),
              maxLines: null,
              minLines: 10,
            ),
            const SizedBox(height: 16),
            if (_attachments.isNotEmpty) ...[
              const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._attachments.asMap().entries.map((entry) {
                return ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(path.basename(entry.value.path)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeAttachment(entry.key),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: _pickAttachments,
              icon: const Icon(Icons.attach_file),
              label: const Text('Add Attachments'),
            ),
          ],
        ),
      ),
    );
  }
}
