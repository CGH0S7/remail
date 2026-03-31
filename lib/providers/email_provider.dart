import 'package:flutter/material.dart';
import '../models/email.dart';
import '../services/resend_service.dart';

class EmailProvider extends ChangeNotifier {
  List<EmailListItem> _sentEmails = [];
  List<EmailListItem> _receivedEmails = [];
  bool _isLoading = false;
  String? _error;

  // Local state to simulate read/unread and starred since Resend API might not provide it natively
  final Set<String> _readEmailIds = {};
  final Set<String> _starredEmailIds = {};

  List<EmailListItem> get sentEmails => _sentEmails;
  List<EmailListItem> get receivedEmails => _receivedEmails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isRead(String id) => _readEmailIds.contains(id);
  bool isStarred(String id) => _starredEmailIds.contains(id);

  void markAsRead(String id) {
    if (!_readEmailIds.contains(id)) {
      _readEmailIds.add(id);
      notifyListeners();
    }
  }

  void toggleStar(String id) {
    if (_starredEmailIds.contains(id)) {
      _starredEmailIds.remove(id);
    } else {
      _starredEmailIds.add(id);
    }
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

  Future<Email> fetchEmailDetail(ResendService service, String id, bool isReceived) async {
    markAsRead(id);
    if (isReceived) {
      return await service.getReceivedEmail(id);
    } else {
      return await service.getSentEmail(id);
    }
  }
}
