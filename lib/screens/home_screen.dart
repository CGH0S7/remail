import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/email_provider.dart';
import '../services/resend_service.dart';
import '../models/email.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmails();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 监听滚动以收缩或展开 FAB
  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isFabExtended) setState(() => _isFabExtended = false);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isFabExtended) setState(() => _isFabExtended = true);
    }
  }

  Future<void> _fetchEmails() async {
    final auth = context.read<AuthProvider>();
    final service = ResendService(auth.apiKey!);
    if (_selectedIndex == 0) {
      await context.read<EmailProvider>().fetchReceivedEmails(service);
    } else {
      await context.read<EmailProvider>().fetchSentEmails(service);
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedEmailId = null;
    });
    // 移动端点击抽屉项后自动关闭抽屉
    Navigator.pop(context);
    _fetchEmails();
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否为宽屏（平板/桌面端）
    final bool isWide = MediaQuery.of(context).size.width > 900;

    Widget body = _buildBody();

    // 宽屏模式下使用分栏布局
    if (isWide) {
      body = Row(
        children: [
          _buildDrawer(isPermanent: true),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(flex: 2, child: _buildBody()),
          if (_selectedEmailId != null) ...[
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              flex: 3,
              child: EmailDetailScreen(
                key: ValueKey(_selectedEmailId),
                id: _selectedEmailId!,
                isReceived: _selectedIndex == 0,
              ),
            ),
          ]
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // 移动端使用 Drawer，宽屏端已经在 Row 中直接渲染
      drawer: isWide ? null : _buildDrawer(isPermanent: false),
      body: body,
      // 悬浮操作按钮 (FAB)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeScreen()),
          );
        },
        icon: const Icon(Icons.edit),
        label: const Text('Compose'),
        isExtended: _isFabExtended,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  /// MD3 样式的侧边导航抽屉
  Widget _buildDrawer({required bool isPermanent}) {
    final auth = context.read<AuthProvider>();
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: isPermanent ? (index) {
        setState(() {
          _selectedIndex = index;
          _selectedEmailId = null;
        });
        _fetchEmails();
      } : _onDestinationSelected,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'Rusend Next',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.inbox_outlined),
          selectedIcon: Icon(Icons.inbox),
          label: Text('Inbox'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.send_outlined),
          selectedIcon: Icon(Icons.send),
          label: Text('Sent'),
        ),
        const Divider(indent: 28, endIndent: 28),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            auth.defaultFrom ?? '',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () {
            if (!isPermanent) Navigator.pop(context);
            context.read<AuthProvider>().logout();
          },
        )
      ],
    );
  }

  /// 列表主体内容，包含下拉刷新和可滚动的列表
  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _fetchEmails,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildSliverList(),
        ],
      ),
    );
  }

  /// MD3 悬浮搜索栏样式的 SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      automaticallyImplyLeading: false, // 隐藏默认的汉堡菜单图标
      title: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Material(
              elevation: 0,
              // MD3 SearchBar 常用的背景色
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  // 点击执行搜索逻辑 (暂未实现)
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // 汉堡菜单按钮 (非宽屏时显示)
                      MediaQuery.of(context).size.width > 900
                          ? const Icon(Icons.search)
                          : IconButton(
                              icon: const Icon(Icons.menu),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Search in emails',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // 用户头像
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          context.read<AuthProvider>().defaultFrom?.substring(0, 1).toUpperCase() ?? 'U',
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
            ),
          );
        }
      ),
    );
  }

  /// 邮件列表区
  Widget _buildSliverList() {
    return Consumer<EmailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.receivedEmails.isEmpty && provider.sentEmails.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (provider.error != null) {
          return SliverFillRemaining(
            child: Center(child: Text('Error: ${provider.error}')),
          );
        }

        final emails = _selectedIndex == 0 ? provider.receivedEmails : provider.sentEmails;

        if (emails.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text('Nothing to see here.')),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final email = emails[index];
              return _buildEmailItem(email, provider);
            },
            childCount: emails.length,
          ),
        );
      },
    );
  }

  /// 单个邮件的 UI 展现，支持左右滑动删除/归档
  Widget _buildEmailItem(EmailListItem email, EmailProvider provider) {
    final bool isWide = MediaQuery.of(context).size.width > 900;
    final bool isSelected = _selectedEmailId == email.id;
    final bool isRead = provider.isRead(email.id);
    final bool isStarred = provider.isStarred(email.id);

    // 未读邮件使用粗体，已读邮件使用常规字体和灰色
    final fontWeight = isRead ? FontWeight.normal : FontWeight.bold;
    final color = isRead ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface;

    return Dismissible(
      key: Key(email.id),
      // 右滑：归档
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24.0),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      // 左滑：删除
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        provider.removeEmailLocally(email.id, _selectedIndex == 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(direction == DismissDirection.startToEnd ? 'Archived' : 'Deleted'),
          ),
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
                  builder: (context) => EmailDetailScreen(
                    id: email.id,
                    isReceived: _selectedIndex == 0,
                  ),
                ),
              ).then((_) {
                setState(() {}); // 刷新列表状态（已读状态）
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(email.from),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 第一行：发件人名称 & 时间
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _extractName(email.from),
                              style: TextStyle(fontWeight: fontWeight, color: color, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(email.createdAt),
                            style: TextStyle(
                              fontWeight: fontWeight, 
                              fontSize: 12, 
                              color: isRead ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.primary
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // 第二三行：主题与星标
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email.subject,
                                  style: TextStyle(fontWeight: fontWeight, color: color, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                // 假设列表 API 不返回正文摘要，暂用 subject 或预设文字代替 snippet
                                Text(
                                  email.subject, 
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // 星标按钮
                          IconButton(
                            icon: Icon(
                              isStarred ? Icons.star : Icons.star_border,
                              color: isStarred ? Colors.amber : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(left: 8.0),
                            onPressed: () {
                              provider.toggleStar(email.id);
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

  /// 构建圆形发件人头像，附带随机柔和背景色
  Widget _buildAvatar(String from) {
    final String initial = _extractName(from).substring(0, 1).toUpperCase();
    final Color bgColor = _getAvatarColor(from);
    return CircleAvatar(
      backgroundColor: bgColor,
      radius: 24,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
      ),
    );
  }

  /// 从 "Name <email@domain.com>" 中提取 Name
  String _extractName(String from) {
    if (from.contains('<')) {
      return from.substring(0, from.indexOf('<')).trim();
    }
    return from;
  }

  /// 为头像生成固定的随机柔和颜色
  Color _getAvatarColor(String name) {
    final colors = [
      Colors.red[300], Colors.blue[300], Colors.green[300],
      Colors.orange[300], Colors.purple[300], Colors.teal[300],
      Colors.pink[300], Colors.indigo[300], Colors.cyan[300]
    ];
    final hash = name.hashCode;
    return colors[hash % colors.length]!;
  }

  /// 格式化时间：当天显示时间，其他显示日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
