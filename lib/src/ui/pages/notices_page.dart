import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/notice_service.dart';
import '../../state/app_controller.dart';
import '../../utils/logger.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  bool _hasCheckedNewNotice = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查新公告（使用预加载的数据）
    if (!_hasCheckedNewNotice) {
      final controller = Provider.of<AppController>(context, listen: false);
      if (controller.noticesLoaded) {
        _hasCheckedNewNotice = true;
        // 使用 addPostFrameCallback 确保在 build 完成后显示弹窗
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowLatestNotice(controller);
        });
      }
    }
  }

  Future<void> _checkAndShowLatestNotice(AppController controller) async {
    if (!controller.noticesLoaded || controller.cachedNotices.isEmpty) return;

    final settingsStore = controller.settingsStore;
    final settings = controller.settings;
    
    // 获取最新公告（已排序）
    final latestNotice = controller.cachedNotices.first;
    final lastTime = settings.lastNoticeTime;
    
    L.d('checking latest notice: ${latestNotice.time}', tag: 'notices');
    L.d('last stored time: $lastTime', tag: 'notices');
    
    // 比较最新公告时间和存储的时间
    bool hasNew = false;
    if (lastTime == null || lastTime.isEmpty) {
      hasNew = true;
    } else {
      try {
        final latestTime = DateTime.parse(latestNotice.time.replaceAll(' ', 'T'));
        final storedTime = DateTime.parse(lastTime.replaceAll(' ', 'T'));
        hasNew = latestTime.isAfter(storedTime);
      } catch (_) {
        // 如果解析失败，使用字符串比较兜底
        hasNew = latestNotice.time.compareTo(lastTime) > 0;
      }
    }
    
    if (hasNew) {
      L.i('showing new notice dialog', tag: 'notices');
      _showNoticeDialog(latestNotice);
      
      // 更新存储的时间为最新公告的时间
      final updatedSettings = settings.copyWith(lastNoticeTime: latestNotice.time);
      controller.settings = updatedSettings;
      await settingsStore.save(updatedSettings);
      L.d('saved lastNoticeTime: ${latestNotice.time}', tag: 'notices');
    } else {
      L.d('no new notices', tag: 'notices');
    }
  }

  void _showNoticeDialog(Notice notice) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // 防止点击外部关闭
      builder: (_) => AlertDialog(
        title: Text(notice.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notice.content),
              const SizedBox(height: 16),
              Text(
                notice.time,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotices(AppController controller) async {
    // 从 AppController 刷新公告数据
    await controller.refreshNotices();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, controller, _) {
        final notices = controller.cachedNotices;
        final isLoading = !controller.noticesLoaded;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('公告'),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: () => _loadNotices(controller),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : notices.isEmpty
                  ? const Center(child: Text('暂无公告'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: notices.length,
                      itemBuilder: (_, i) {
                        final notice = notices[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notice.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  notice.content,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  notice.time,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
