import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/email.dart';
import '../services/resend_service.dart';

class EmailProvider extends ChangeNotifier {
  static const String _readPrefsKey = 'read_email_ids';
  static const String _starredPrefsKey = 'starred_emails';
  static const String _draftPrefsKey = 'draft_emails';

  List<EmailListItem> _sentEmails = [];
  List<EmailListItem> _receivedEmails = [];
  bool _isLoading = false;
  String? _error;

  final Set<String> _readEmailIds = {};
  final Map<String, Email> _starredEmails = {};
  final Map<String, DraftEmail> _draftEmails = {};

  EmailProvider() {
    _loadLocalState();
  }

  List<EmailListItem> get sentEmails => _sentEmails;
  List<EmailListItem> get receivedEmails => _receivedEmails;
  List<Email> get starredEmails {
    final items = _starredEmails.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<DraftEmail> get draftEmails {
    final items = _draftEmails.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  List<ContactEntry> get contacts {
    final contacts = <String, ContactEntry>{};

    void collect(String mailbox) {
      final email = extractEmailAddress(mailbox);
      if (email.isEmpty) {
        return;
      }
      final name = extractDisplayName(mailbox);
      final existing = contacts[email.toLowerCase()];
      if (existing == null || existing.name == existing.email) {
        contacts[email.toLowerCase()] = ContactEntry(email: email, name: name);
      }
    }

    for (final email in _receivedEmails) {
      collect(email.from);
      for (final recipient in email.to) {
        collect(recipient);
      }
    }
    for (final email in _sentEmails) {
      collect(email.from);
      for (final recipient in email.to) {
        collect(recipient);
      }
    }
    for (final email in _starredEmails.values) {
      collect(email.from);
      for (final recipient in email.to) {
        collect(recipient);
      }
    }

    final list = contacts.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isRead(String id) => _readEmailIds.contains(id);
  bool isStarred(String id) => _starredEmails.containsKey(id);

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    _readEmailIds
      ..clear()
      ..addAll(prefs.getStringList(_readPrefsKey) ?? const []);

    _starredEmails.clear();
    final starredJson = prefs.getStringList(_starredPrefsKey) ?? const [];
    for (final rawEmail in starredJson) {
      final email = Email.fromRawJson(rawEmail);
      _starredEmails[email.id] = email;
    }

    _draftEmails.clear();
    final draftJson = prefs.getStringList(_draftPrefsKey) ?? const [];
    for (final rawDraft in draftJson) {
      final draft = DraftEmail.fromRawJson(rawDraft);
      _draftEmails[draft.id] = draft;
    }
    notifyListeners();
  }

  Future<void> _persistLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readPrefsKey, _readEmailIds.toList());
    await prefs.setStringList(
      _starredPrefsKey,
      _starredEmails.values.map((email) => email.toRawJson()).toList(),
    );
    await prefs.setStringList(
      _draftPrefsKey,
      _draftEmails.values.map((draft) => draft.toRawJson()).toList(),
    );
  }

  DraftEmail saveDraft({
    String? id,
    required List<String> to,
    required String subject,
    required String body,
  }) {
    final draft = DraftEmail(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      to: to,
      subject: subject,
      body: body,
      updatedAt: DateTime.now(),
    );
    _draftEmails[draft.id] = draft;
    _persistLocalState();
    notifyListeners();
    return draft;
  }

  Future<void> deleteDraft(String id) async {
    if (_draftEmails.remove(id) != null) {
      await _persistLocalState();
      notifyListeners();
    }
  }

  void markAsRead(String id) {
    if (!_readEmailIds.contains(id)) {
      _readEmailIds.add(id);
      _persistLocalState();
      notifyListeners();
    }
  }

  Future<void> toggleStarById({
    required String id,
    required bool isReceived,
    required ResendService service,
  }) async {
    if (_starredEmails.containsKey(id)) {
      _starredEmails.remove(id);
      await _persistLocalState();
      notifyListeners();
      return;
    }

    final email = isReceived
        ? await service.getReceivedEmail(id)
        : await service.getSentEmail(id);
    await toggleStarEmail(email);
  }

  Future<void> toggleStarEmail(Email email) async {
    if (_starredEmails.containsKey(email.id)) {
      _starredEmails.remove(email.id);
    } else {
      _starredEmails[email.id] = email;
    }
    await _persistLocalState();
    notifyListeners();
  }

  void removeEmailLocally(String id, bool isReceived) {
    if (isReceived) {
      _receivedEmails.removeWhere((e) => e.id == id);
    } else {
      _sentEmails.removeWhere((e) => e.id == id);
    }
    notifyListeners();
  }

  Future<void> fetchSentEmails(ResendService service) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sentEmails = await service.listSentEmails();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReceivedEmails(ResendService service) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _receivedEmails = await service.listReceivedEmails();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Email> fetchEmailDetail(
    ResendService service,
    String id,
    bool isReceived,
  ) async {
    markAsRead(id);
    try {
      final email = isReceived
          ? await service.getReceivedEmail(id)
          : await service.getSentEmail(id);

      if (_starredEmails.containsKey(id)) {
        _starredEmails[id] = email;
        await _persistLocalState();
        notifyListeners();
      }
      return email;
    } catch (_) {
      final cached = _starredEmails[id];
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
