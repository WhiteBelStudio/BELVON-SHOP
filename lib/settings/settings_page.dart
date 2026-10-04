import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _notificationsKey = 'settings_notifications';
  static const _soundsKey = 'settings_sounds';
  static const _confirmLogoutKey = 'settings_confirm_logout';
  static const _updatesKey = 'settings_update_reminders';

  bool notifications = true;
  bool sounds = true;
  bool confirmLogout = true;
  bool updateReminders = true;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notifications = prefs.getBool(_notificationsKey) ?? true;
      sounds = prefs.getBool(_soundsKey) ?? true;
      confirmLogout = prefs.getBool(_confirmLogoutKey) ?? true;
      updateReminders = prefs.getBool(_updatesKey) ?? true;
      loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _clearLocalSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить настройки?'),
        content: const Text(
          'Будут сброшены только локальные параметры приложения. '
          'Аккаунт и данные сервера не удаляются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    await prefs.remove(_soundsKey);
    await prefs.remove(_confirmLogoutKey);
    await prefs.remove(_updatesKey);

    if (!mounted) return;
    setState(() {
      notifications = true;
      sounds = true;
      confirmLogout = true;
      updateReminders = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Локальные настройки сброшены')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      children: [
                        _section(
                          title: 'Уведомления',
                          children: [
                            _switchTile(
                              icon: Icons.notifications_none_rounded,
                              title: 'Уведомления приложения',
                              subtitle: 'Показывать уведомления и их индикаторы.',
                              value: notifications,
                              onChanged: (value) {
                                setState(() => notifications = value);
                                _set(_notificationsKey, value);
                              },
                            ),
                            _switchTile(
                              icon: Icons.volume_up_outlined,
                              title: 'Звуки',
                              subtitle: 'Использовать звуковые сигналы приложения.',
                              value: sounds,
                              onChanged: (value) {
                                setState(() => sounds = value);
                                _set(_soundsKey, value);
                              },
                            ),
                            _switchTile(
                              icon: Icons.system_update_outlined,
                              title: 'Напоминания об обновлениях',
                              subtitle: 'Разрешить локальные напоминания о новых версиях.',
                              value: updateReminders,
                              onChanged: (value) {
                                setState(() => updateReminders = value);
                                _set(_updatesKey, value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _section(
                          title: 'Безопасность',
                          children: [
                            _switchTile(
                              icon: Icons.logout_rounded,
                              title: 'Подтверждать выход',
                              subtitle: 'Запрашивать подтверждение перед завершением сессии.',
                              value: confirmLogout,
                              onChanged: (value) {
                                setState(() => confirmLogout = value);
                                _set(_confirmLogoutKey, value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _section(
                          title: 'Информация',
                          children: const [
                            ListTile(
                              leading: Icon(Icons.palette_outlined),
                              title: Text('Оформление'),
                              subtitle: Text('Тёмная тема BELVON'),
                            ),
                            ListTile(
                              leading: Icon(Icons.language_rounded),
                              title: Text('Язык'),
                              subtitle: Text('Русский'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.restore_rounded),
                            title: const Text(
                              'Сбросить локальные настройки',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text('Аккаунт и серверные данные не затрагиваются.'),
                            onTap: _clearLocalSettings,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
