import 'package:flutter/material.dart';
import '../models/email.dart';
import '../services/resend_service.dart';

class EmailProvider extends ChangeNotifier {
  List<EmailListItem> _sentEmails = [];
  List<EmailListItem> _receivedEmails = [];
  bool _isLoading = false;
  String? _error;

  List<EmailListItem> get sentEmails => _sentEmails;
  List<EmailListItem> get receivedEmails => _receivedEmails;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    if (isReceived) {
      return await service.getReceivedEmail(id);
    } else {
      return await service.getSentEmail(id);
    }
  }
}
