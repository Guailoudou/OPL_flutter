import 'package:flutter/material.dart';
import '../../core/notice_service.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<Notice> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
    });

    final service = NoticeService();
    final response = await service.fetchNotices();
    
    if (response != null) {
      // Sort notices by time (newest first)
      final sortedNotices = response.notices..sort((a, b) {
        try {
          final timeA = DateTime.parse(a.time.replaceAll(' ', 'T'));
          final timeB = DateTime.parse(b.time.replaceAll(' ', 'T'));
          return timeB.compareTo(timeA); // Descending order
        } catch (_) {
          // Fallback to string comparison
          return b.time.compareTo(a.time);
        }
      });
      
      setState(() {
        _notices = sortedNotices;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loadNotices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notices.isEmpty
              ? const Center(child: Text('暂无公告'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _notices.length,
                  itemBuilder: (_, i) {
                    final notice = _notices[i];
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
  }
}
