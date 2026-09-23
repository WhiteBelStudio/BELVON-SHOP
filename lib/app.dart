import 'dart:async';

import 'package:flutter/material.dart';
import 'data/products.dart';
import 'models/product.dart';
import 'services/update_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'admin/admin_page.dart';
import 'theme/app_theme.dart';

class BelvonApp extends StatelessWidget {
  const BelvonApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BELVON SHOP',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    home: const AuthGate(),
  );
}



class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService.user == null) {
      return const AuthPage();
    }
    return const ShopPage();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final secondPassword = TextEditingController();
  bool registerMode = false;
  bool ownerMode = false;
  bool busy = false;
  String? error;
  String? pendingRequestId;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      if (registerMode) {
        await ApiService.register(email.text.trim(), password.text);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ShopPage()),
            (route) => false,
          );
        }
        return;
      }

      if (ownerMode) {
        await ApiService.ownerLogin(
          email.text.trim(),
          password.text,
          secondPassword.text,
        );
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ShopPage()),
            (route) => false,
          );
        }
        return;
      }

      final result = await ApiService.secureLogin(
        email.text.trim(),
        password.text,
      );
      final status = result['status']?.toString();

      if (status == 'approved') {
        final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
        await AuthService.save(result['access_token'] as String, user);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ShopPage()),
            (route) => false,
          );
        }
        return;
      }

      if (status == 'pending') {
        pendingRequestId = result['request_id']?.toString();
        setState(() => busy = false);
        await waitForApproval();
        return;
      }

      throw Exception('Не удалось определить состояние входа');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> waitForApproval() async {
    final requestId = pendingRequestId;
    if (requestId == null) return;

    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final result = await ApiService.deviceStatus(requestId);
        final status = result['status']?.toString();

        if (status == 'approved') {
          final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
          await AuthService.save(result['access_token'] as String, user);
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ShopPage()),
              (route) => false,
            );
          }
          return;
        }

        if (status == 'denied') {
          setState(() {
            busy = false;
            pendingRequestId = null;
            error = 'Вход отклонён на доверенном устройстве.';
          });
          return;
        }

        if (status == 'expired') {
          setState(() {
            busy = false;
            pendingRequestId = null;
            error = 'Запрос на вход истёк. Попробуйте ещё раз.';
          });
          return;
        }
      } catch (_) {
        // Network interruptions are retried until the request expires.
      }
    }

    if (mounted) {
      setState(() {
        busy = false;
        pendingRequestId = null;
        error = 'Не удалось получить подтверждение вовремя.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = registerMode ? 'Создать аккаунт' : ownerMode ? 'Вход владельца' : 'Вход';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, size: 36),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'BELVON SHOP',
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pendingRequestId == null
                          ? 'Безопасный вход в приложение'
                          : 'Ожидаем подтверждение на доверенном устройстве',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: email,
                      enabled: pendingRequestId == null && !busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      enabled: pendingRequestId == null && !busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (ownerMode && !registerMode) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: secondPassword,
                        enabled: pendingRequestId == null && !busy,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Дополнительный пароль владельца',
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    if (pendingRequestId != null) ...[
                      const SizedBox(height: 18),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        'Откройте BELVON SHOP на уже авторизованном устройстве и подтвердите этот вход.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (pendingRequestId == null) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy ? null : submit,
                          child: Text(busy ? 'Проверяем...' : title),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  registerMode = !registerMode;
                                  ownerMode = false;
                                  error = null;
                                }),
                        child: Text(
                          registerMode ? 'У меня уже есть аккаунт' : 'Создать новый аккаунт',
                        ),
                      ),
                      if (!registerMode)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    ownerMode = !ownerMode;
                                    error = null;
                                  }),
                          child: Text(
                            ownerMode ? 'Обычный вход' : 'Вход владельца',
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int tab = 0;
  Timer? approvalTimer;

  @override
  void initState() {
    super.initState();
    if (AuthService.user?.isAdmin == true) {
      approvalTimer = Timer.periodic(const Duration(seconds: 6), (_) => checkDeviceRequests());
      Future<void>.delayed(const Duration(seconds: 2), checkDeviceRequests);
    }
  }

  @override
  void dispose() {
    approvalTimer?.cancel();
    super.dispose();
  }

  Future<void> checkDeviceRequests() async {
    if (!mounted || AuthService.user == null) return;
    try {
      final requests = await ApiService.deviceRequests();
      if (!mounted || requests.isEmpty) return;
      final request = requests.first as Map<String, dynamic>;
      final id = request['id']?.toString();
      if (id == null) return;
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Новый вход'),
          content: Text(
            'Запрос на вход с нового устройства.\\n\\nУстройство: ${request['device_name'] ?? 'Неизвестно'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отклонить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Разрешить'),
            ),
          ],
        ),
      );
      if (approved != null) await ApiService.decideDeviceRequest(id, approved);
    } catch (_) {}
  }
  String category = 'Все';
  String query = '';
  final favorites = <int>{};
  final cart = <int, int>{};

  List<String> get categories => ['Все', ...{for (final p in products) p.category}];

  List<Product> get filtered => products.where((p) {
    final q = query.trim().toLowerCase();
    return (category == 'Все' || p.category == category) &&
      (q.isEmpty || p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q));
  }).toList();

  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  double get cartTotal => cart.entries.fold(0, (total, entry) {
    final p = products.firstWhere((x) => x.id == entry.key);
    return total + p.price * entry.value;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
            ),
            child: const Icon(Icons.shopping_bag_rounded, size: 21),
          ),
          const SizedBox(width: 11),
          const Text('BELVON', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ],
      ),
      actions: [
        IconButton(onPressed: () => setState(() => tab = 1), icon: const Icon(Icons.favorite_rounded)),
        Badge(
          isLabelVisible: cartCount > 0,
          label: Text(cartCount.toString()),
          child: IconButton(onPressed: showCart, icon: const Icon(Icons.shopping_bag_rounded)),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: IndexedStack(index: tab, children: [catalog(), favoritesPage(), profile()]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Каталог'),
        NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Избранное'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
      ],
    ),
  );

  Widget catalog() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF21143D), Color(0xFF101A2C), Color(0xFF0D0F16)],
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BELVON SHOP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    SizedBox(height: 10),
                    Text('Выбирай своё.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    SizedBox(height: 7),
                    Text('Современный каталог и быстрый заказ.', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 32),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: 'Поиск по каталогу',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(categories[i]),
              selected: category == categories[i],
              onSelected: (_) => setState(() => category = categories[i]),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380, mainAxisExtent: 330, crossAxisSpacing: 14, mainAxisSpacing: 14,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => productCard(filtered[i]),
        ),
      ),
    ],
  );

  Widget favoritesPage() {
    final list = products.where((p) => favorites.contains(p.id)).toList();
    if (list.isEmpty) return const Center(child: Text('В избранном пока ничего нет'));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380, mainAxisExtent: 330, crossAxisSpacing: 14, mainAxisSpacing: 14,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => productCard(list[i]),
    );
  }

  Widget profile() {
    final user = AuthService.user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(radius: 42, child: Icon(user == null ? Icons.person : Icons.verified_user, size: 42)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            user?.email ?? 'Гость',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 5),
          Center(child: Text(user.isOwner ? 'Владелец' : user.isAdmin ? 'Администратор' : 'Покупатель')),
        ],
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              if (user == null)
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Войти в аккаунт'),
                  subtitle: const Text('Авторизация для профиля и админ-панели'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: showLogin,
                ),
              if (user != null && user.isAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded),
                  title: const Text('Админ-панель'),
                  subtitle: Text(user.isOwner ? 'Полный доступ владельца' : 'Управление магазином'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminPage()),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Мои заказы'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Настройки'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: const Text('Обновление приложения'),
                subtitle: const Text('Проверить новую версию'),
                trailing: const Icon(Icons.chevron_right),
                onTap: checkForUpdate,
              ),
              if (user != null)
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Выйти'),
                  onTap: () async {
                    await AuthService.logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                        (route) => false,
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> showLogin() async {
    final email = TextEditingController();
    final password = TextEditingController();
    var busy = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('Вход'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('Отмена')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialog(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ApiService.login(email.text.trim(), password.text);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) setState(() {});
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialog(() {
                            busy = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Вход...' : 'Войти'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> checkForUpdate() async {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final update = await UpdateService.checkForUpdate();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (update == null) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Обновлений нет'),
            content: Text('Установлена последняя версия ${UpdateService.currentVersion}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final open = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Доступна версия ${update.version}'),
          content: const Text('Откройте страницу релиза, чтобы установить обновление для вашей платформы.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Позже'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Обновить'),
            ),
          ],
        ),
      );

      if (open == true) {
        await UpdateService.openRelease(update.url);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Не удалось проверить обновления'),
          content: const Text('Проверьте подключение к интернету и попробуйте ещё раз.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget productCard(Product p) {
    final liked = favorites.contains(p.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showProduct(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(colors: [Color(0xFF242638), Color(0xFF101116)]),
                ),
                child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 58)),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
              IconButton(
                onPressed: () => setState(() => liked ? favorites.remove(p.id) : favorites.add(p.id)),
                icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              ),
            ]),
            Text(p.category),
            const SizedBox(height: 5),
            Text('${p.price.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }

  void showProduct(Product p) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(p.description),
        const SizedBox(height: 14),
        Text('${p.price.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              setState(() => cart[p.id] = (cart[p.id] ?? 0) + 1);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Добавить в корзину'),
          ),
        ),
      ]),
    ),
  );

  void showCart() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Корзина', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (cart.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('Корзина пуста'))
          else ...[
            ...products.where((p) => cart.containsKey(p.id)).map((p) => ListTile(
              title: Text(p.name),
              subtitle: Text('${p.price.toStringAsFixed(0)} ₽ × ${cart[p.id]}'),
              trailing: IconButton(onPressed: () => setState(() => cart.remove(p.id)), icon: const Icon(Icons.delete_outline)),
            )),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Итого: ${cartTotal.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Оформить заказ'))),
          ],
        ]),
      ),
    ),
  );
}
