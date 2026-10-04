import 'package:flutter/material.dart';

class BelvonNotification {
  final String id;
  final String title;
  final String message;
  final String timeLabel;
  final IconData icon;

  const BelvonNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.icon,
  });
}

const belvonNotifications = <BelvonNotification>[
  BelvonNotification(
    id: 'welcome',
    title: 'Добро пожаловать',
    message: 'BELVON SHOP готов к работе. Здесь будут отображаться важные уведомления приложения.',
    timeLabel: 'Сейчас',
    icon: Icons.waving_hand_rounded,
  ),
  BelvonNotification(
    id: 'updates',
    title: 'Обновления',
    message: 'Следите за новыми версиями приложения и изменениями интерфейса.',
    timeLabel: 'Недавно',
    icon: Icons.system_update_rounded,
  ),
];

class NotificationsPage extends StatelessWidget {
  final Set<String> readIds;
  final ValueChanged<String> onRead;
  final VoidCallback onReadAll;

  const NotificationsPage({
    super.key,
    required this.readIds,
    required this.onRead,
    required this.onReadAll,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = belvonNotifications.where((n) => !readIds.contains(n.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: onReadAll,
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: belvonNotifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = belvonNotifications[index];
          final unread = !readIds.contains(item.id);

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: unread ? () => onRead(item.id) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: unread
                            ? const Color(0x332A1D4D)
                            : Colors.white.withValues(alpha: .05),
                      ),
                      child: Icon(item.icon),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: unread ? Colors.white : Colors.white70,
                                  ),
                                ),
                              ),
                              if (unread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.message,
                            style: const TextStyle(color: Colors.white60, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.timeLabel,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
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
}
