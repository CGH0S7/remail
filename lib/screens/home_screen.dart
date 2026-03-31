import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/email_provider.dart';
import '../services/resend_service.dart';
import 'email_detail_screen.dart';
import 'compose_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedEmailId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmails();
    });
  }

  void _fetchEmails() {
    final auth = context.read<AuthProvider>();
    final service = ResendService(auth.apiKey!);
    if (_selectedIndex == 0) {
      context.read<EmailProvider>().fetchReceivedEmails(service);
    } else {
      context.read<EmailProvider>().fetchSentEmails(service);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Inbox' : 'Sent'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchEmails),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
                _selectedEmailId = null;
              });
              _fetchEmails();
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox),
                label: Text('Inbox'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.send_outlined),
                selectedIcon: Icon(Icons.send),
                label: Text('Sent'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            flex: 2,
            child: _buildEmailList(),
          ),
          if (isWide && _selectedEmailId != null) ...[
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              flex: 3,
              child: EmailDetailScreen(
                key: ValueKey(_selectedEmailId),
                id: _selectedEmailId!,
                isReceived: _selectedIndex == 0,
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeScreen()),
          );
        },
        icon: const Icon(Icons.edit),
        label: const Text('Compose'),
      ),
    );
  }

  Widget _buildEmailList() {
    return Consumer<EmailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null) {
          return Center(child: Text('Error: ${provider.error}'));
        }

        final emails = _selectedIndex == 0 ? provider.receivedEmails : provider.sentEmails;

        if (emails.isEmpty) {
          return const Center(child: Text('No emails found.'));
        }

        return ListView.separated(
          itemCount: emails.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final email = emails[index];
            final bool isSelected = _selectedEmailId == email.id;

            return ListTile(
              selected: isSelected,
              leading: CircleAvatar(child: Text(email.from[0].toUpperCase())),
              title: Text(
                email.subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email.from, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, HH:mm').format(email.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: () {
                final bool isWide = MediaQuery.of(context).size.width > 900;
                if (isWide) {
                  setState(() {
                    _selectedEmailId = email.id;
                  });
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmailDetailScreen(
                        id: email.id,
                        isReceived: _selectedIndex == 0,
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}
