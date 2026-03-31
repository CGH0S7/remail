import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../models/email.dart';
import '../providers/auth_provider.dart';
import '../providers/email_provider.dart';
import '../services/resend_service.dart';
import 'compose_screen.dart';
import 'email_detail_screen.dart';
import 'settings_screen.dart';

enum MailSection { inbox, sent, contacts, starred, settings }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MailSection _selectedSection = MailSection.inbox;
  String? _selectedEmailId;
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmails();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isFabExtended) {
        setState(() => _isFabExtended = false);
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isFabExtended) {
        setState(() => _isFabExtended = true);
      }
    }
  }

  Future<void> _fetchEmails() async {
    final auth = context.read<AuthProvider>();
    if (auth.apiKey == null) {
      return;
    }

    final service = ResendService(auth.apiKey!);
    if (_selectedSection == MailSection.inbox) {
      await context.read<EmailProvider>().fetchReceivedEmails(service);
    } else if (_selectedSection == MailSection.sent) {
      await context.read<EmailProvider>().fetchSentEmails(service);
    }
  }

  void _setSection(MailSection section, {bool closeDrawer = false}) {
    setState(() {
      _selectedSection = section;
      _selectedEmailId = null;
      _searchQuery = '';
      _searchController.clear();
    });
    if (closeDrawer) {
      Navigator.pop(context);
    }
    _fetchEmails();
  }

  Future<void> _confirmLogout({required bool closeDrawer}) async {
    if (closeDrawer) {
      Navigator.pop(context);
    }

    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirm logout'),
              content: const Text('Sign out from Remail on this device?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Logout'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldLogout && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final body = _buildBody(isWide: isWide);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: isWide ? null : _buildDrawer(isPermanent: false),
      body: body,
      floatingActionButton: _selectedSection == MailSection.settings
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ComposeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Compose'),
              isExtended: _isFabExtended,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
    );
  }

  Widget _buildBody({required bool isWide}) {
    if (isWide) {
      return Row(
        children: [
          _buildDrawer(isPermanent: true),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildSectionBody(isWide: true)),
          if (_showsEmailPreview && _selectedEmailId != null) ...[
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              flex: 2,
              child: EmailDetailScreen(
                key: ValueKey('${_selectedSection.name}-${_selectedEmailId!}'),
                id: _selectedEmailId!,
                isReceived: _selectedSection != MailSection.sent,
              ),
            ),
          ],
        ],
      );
    }

    return _buildSectionBody(isWide: false);
  }

  Widget _buildDrawer({required bool isPermanent}) {
    final auth = context.watch<AuthProvider>();
    final selectedIndex = _selectedSection.index;
    final content = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 16, 10),
            child: Text(
              'Remail',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: NavigationDrawer(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                _setSection(
                  MailSection.values[index],
                  closeDrawer: !isPermanent,
                );
              },
              children: const [
                NavigationDrawerDestination(
                  icon: Icon(Icons.inbox_outlined),
                  selectedIcon: Icon(Icons.inbox),
                  label: Text('Inbox'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.send_outlined),
                  selectedIcon: Icon(Icons.send),
                  label: Text('Sent'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Contacts'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.star_border),
                  selectedIcon: Icon(Icons.star),
                  label: Text('Starred'),
                ),
                NavigationDrawerDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          ),
          const Divider(indent: 28, endIndent: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 16, 4),
            child: Text(
              auth.displayName ?? '',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 16, 4),
            child: Text(
              auth.defaultFrom ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 16, 12),
            child: FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                final version = snapshot.hasData
                    ? 'Version ${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                    : 'Version...';
                return Text(
                  version,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 28),
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _confirmLogout(closeDrawer: !isPermanent),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (isPermanent) {
      return SizedBox(width: 320, child: content);
    }

    return Drawer(child: content);
  }

  bool get _showsEmailPreview {
    return _selectedSection == MailSection.inbox ||
        _selectedSection == MailSection.sent ||
        _selectedSection == MailSection.starred;
  }

  Widget _buildSectionBody({required bool isWide}) {
    switch (_selectedSection) {
      case MailSection.settings:
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(title: 'Search settings'),
            const SliverToBoxAdapter(child: SettingsScreen()),
          ],
        );
      case MailSection.contacts:
        return _buildContactsView();
      case MailSection.starred:
        return _buildStarredView(isWide: isWide);
      case MailSection.inbox:
      case MailSection.sent:
        return _buildEmailListView(isWide: isWide);
    }
  }

  Widget _buildEmailListView({required bool isWide}) {
    return RefreshIndicator(
      onRefresh: _fetchEmails,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildSliverList(
            isWide: isWide,
            emailsSelector: (provider) {
              final emails = _selectedSection == MailSection.inbox
                  ? provider.receivedEmails
                  : provider.sentEmails;
              if (_searchQuery.isEmpty) {
                return emails;
              }
              final query = _searchQuery.toLowerCase();
              return emails.where((email) {
                return email.subject.toLowerCase().contains(query) ||
                    email.from.toLowerCase().contains(query) ||
                    email.to.any((t) => t.toLowerCase().contains(query));
              }).toList();
            },
            emptyText: _searchQuery.isEmpty
                ? 'Nothing to see here.'
                : 'No results for "$_searchQuery"',
            isReceived: _selectedSection == MailSection.inbox,
          ),
        ],
      ),
    );
  }

  Widget _buildStarredView({required bool isWide}) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        _buildSliverAppBar(title: 'Starred mail'),
        Consumer<EmailProvider>(
          builder: (context, provider, child) {
            var emails = provider.starredEmails
                .map(EmailListItem.fromEmail)
                .toList();

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              emails = emails.where((email) {
                return email.subject.toLowerCase().contains(query) ||
                    email.from.toLowerCase().contains(query) ||
                    email.to.any((t) => t.toLowerCase().contains(query));
              }).toList();
            }

            if (emails.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No starred emails yet. Starred mail is cached locally.'
                        : 'No results for "$_searchQuery"',
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildEmailItem(
                  emails[index],
                  provider,
                  isWide: isWide,
                  isReceived: true,
                ),
                childCount: emails.length,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactsView() {
    return Consumer<EmailProvider>(
      builder: (context, provider, child) {
        var contacts = provider.contacts;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          contacts = contacts.where((contact) {
            return contact.name.toLowerCase().contains(query) ||
                contact.email.toLowerCase().contains(query);
          }).toList();
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(title: 'Search contacts'),
            if (contacts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Contacts will appear after you load inbox or sent mail.'
                        : 'No results for "$_searchQuery"',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Contacts are inferred from your recent senders and recipients.'
                        : 'Results for "$_searchQuery"',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final contact = contacts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              contact.name.substring(0, 1).toUpperCase(),
                            ),
                          ),
                          title: Text(contact.name),
                          subtitle: Text(contact.email),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ComposeScreen(
                                  initialTo: [contact.email],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: contacts.length,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSliverAppBar({String? title}) {
    final auth = context.watch<AuthProvider>();
    final avatarSource = auth.displayName?.trim().isNotEmpty == true
        ? auth.displayName!
        : (auth.defaultFrom ?? 'U');

    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      title: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    MediaQuery.of(context).size.width > 900
                        ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.search),
                        )
                        : IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: title ?? 'Search in mail',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                        onSubmitted: (value) {
                          // Optional: can trigger something on submit
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        avatarSource.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverList({
    required bool isWide,
    required List<EmailListItem> Function(EmailProvider provider)
    emailsSelector,
    required String emptyText,
    required bool isReceived,
  }) {
    return Consumer<EmailProvider>(
      builder: (context, provider, child) {
        final emails = emailsSelector(provider);
        if (provider.isLoading && emails.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (provider.error != null && emails.isEmpty) {
          return SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _fetchEmails,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (emails.isEmpty) {
          return SliverFillRemaining(child: Center(child: Text(emptyText)));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildEmailItem(
              emails[index],
              provider,
              isWide: isWide,
              isReceived: isReceived,
            ),
            childCount: emails.length,
          ),
        );
      },
    );
  }

  Widget _buildEmailItem(
    EmailListItem email,
    EmailProvider provider, {
    required bool isWide,
    required bool isReceived,
  }) {
    final isSelected = _selectedEmailId == email.id;
    final isRead = provider.isRead(email.id);
    final isStarred = provider.isStarred(email.id);
    final fontWeight = isRead ? FontWeight.normal : FontWeight.bold;
    final color = isRead
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.onSurface;

    return Dismissible(
      key: Key('${_selectedSection.name}-${email.id}'),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        provider.removeEmailLocally(
          email.id,
          _selectedSection == MailSection.inbox,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message removed from local list')),
        );
      },
      child: Material(
        color: isSelected && isWide
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.markAsRead(email.id);
            if (isWide) {
              setState(() {
                _selectedEmailId = email.id;
              });
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EmailDetailScreen(id: email.id, isReceived: isReceived),
                ),
              ).then((_) => setState(() {}));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(email.from),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              extractDisplayName(email.from),
                              style: TextStyle(
                                fontWeight: fontWeight,
                                color: color,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(email.createdAt),
                            style: TextStyle(
                              fontWeight: fontWeight,
                              fontSize: 12,
                              color: isRead
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email.subject,
                                  style: TextStyle(
                                    fontWeight: fontWeight,
                                    color: color,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isReceived
                                      ? 'From ${extractEmailAddress(email.from)}'
                                      : 'To ${email.to.join(', ')}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isStarred ? Icons.star : Icons.star_border,
                              color: isStarred
                                  ? Colors.amber
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(left: 8),
                            onPressed: () async {
                              final auth = context.read<AuthProvider>();
                              final service = ResendService(auth.apiKey!);
                              try {
                                await provider.toggleStarById(
                                  id: email.id,
                                  isReceived: isReceived,
                                  service: service,
                                );
                              } catch (error) {
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to update star: $error',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String from) {
    final initial = extractDisplayName(from).substring(0, 1).toUpperCase();
    final bgColor = _getAvatarColor(from);
    return CircleAvatar(
      backgroundColor: bgColor,
      radius: 24,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.red[300],
      Colors.blue[300],
      Colors.green[300],
      Colors.orange[300],
      Colors.purple[300],
      Colors.teal[300],
      Colors.pink[300],
      Colors.indigo[300],
      Colors.cyan[300],
    ];
    final hash = name.hashCode;
    return colors[hash.abs() % colors.length]!;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('MMM d').format(date);
  }
}
