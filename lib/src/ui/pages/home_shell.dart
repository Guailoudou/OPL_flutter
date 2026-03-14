import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import 'logs_page.dart';
import 'me_page.dart';
import 'notices_page.dart';
import 'settings_page.dart';
import 'tunnels_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.booting, required this.bootError});

  final bool booting;
  final String? bootError;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  bool _hasCheckedNotices = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 页面加载完成后检查公告
    if (!_hasCheckedNotices && !widget.booting && widget.bootError == null) {
      _hasCheckedNotices = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNotices();
      });
    }
  }

  Future<void> _checkNotices() async {
    final controller = Provider.of<AppController>(context, listen: false);
    await controller.checkNotices();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.booting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.bootError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('启动失败')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(widget.bootError!),
        ),
      );
    }

    final pages = const [
      TunnelsPage(),
      LogsPage(),
      NoticesPage(),
      SettingsPage(),
      MePage(),
    ];

    final size = MediaQuery.sizeOf(context);
    final useRail = size.width > size.height;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.tune),
                  label: Text('隧道'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long),
                  label: Text('日志'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications),
                  label: Text('公告'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings),
                  label: Text('设置'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person),
                  label: Text('我的'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[index]),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tune), label: '隧道'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: '日志'),
          NavigationDestination(icon: Icon(Icons.notifications), label: '公告'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

