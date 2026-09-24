import 'dart:async';

import 'package:flutter/material.dart';
import 'data/products.dart';
import 'models/product.dart';
import 'services/update_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'admin/admin_page.dart';
import 'theme/app_theme.dart';
import 'widgets/belvon_card.dart';
import 'widgets/belvon_states.dart';
import 'widgets/belvon_responsive.dart';
import 'theme/app_dimensions.dart';

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

  void openTab(int index) => setState(() => tab = index);

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
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
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
        IconButton(onPressed: () => openTab(2), icon: const Icon(Icons.favorite_rounded)),
        Badge(
          isLabelVisible: cartCount > 0,
          label: Text(cartCount.toString()),
          child: IconButton(onPressed: showCart, icon: const Icon(Icons.shopping_bag_rounded)),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Row(
      children: [
        if (wide)
          NavigationRail(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Главная')),
              NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: Text('Каталог')),
              NavigationRailDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: Text('Избранное')),
              NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Профиль')),
            ],
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            reverseDuration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.025, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(tab),
              child: tab == 0 ? home() : tab == 1 ? catalog() : tab == 2 ? favoritesPage() : profile(),
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: wide ? null : NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
        NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Каталог'),
        NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Избранное'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
      ],
    ),
  );
  }

  Widget home() {
    final user = AuthService.user;
    return BelvonResponsive(
      mobile: _homeContent(wide: false, userEmail: user?.email),
      desktop: _homeContent(wide: true, userEmail: user?.email),
    );
  }

  Widget _homeContent({required bool wide, String? userEmail}) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 8, wide ? 28 : 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BelvonCard(
            padding: EdgeInsets.zero,
            child: Container(
              constraints: BoxConstraints(minHeight: wide ? 270 : 300),
              padding: EdgeInsets.all(wide ? 34 : 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF241449), Color(0xFF141D36), Color(0xFF0E1017)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text('BELVON • APP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          userEmail == null ? 'Добро пожаловать.' : 'С возвращением.',
                          style: TextStyle(fontSize: wide ? 38 : 31, height: 1.05, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Главный экран BELVON — быстрый доступ к каталогу, избранному и профилю.',
                          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () => openTab(1),
                              icon: const Icon(Icons.storefront_rounded),
                              label: const Text('Открыть каталог'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => openTab(2),
                              icon: const Icon(Icons.favorite_border_rounded),
                              label: const Text('Избранное'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 30),
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: .22),
                            blurRadius: 55,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 76),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('Быстрый доступ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: wide ? 1.7 : 2.1,
                children: [
                  _homeAction(icon: Icons.storefront_rounded, title: 'Каталог', subtitle: 'Все доступные разделы', onTap: () => openTab(1)),
                  _homeAction(icon: Icons.favorite_rounded, title: 'Избранное', subtitle: favorites.isEmpty ? 'Пока ничего нет' : '${favorites.length} сохранено', onTap: () => openTab(2)),
                  _homeAction(icon: Icons.person_rounded, title: 'Профиль', subtitle: userEmail ?? 'Войти или создать аккаунт', onTap: () => openTab(3)),
                  _homeAction(icon: Icons.system_update_rounded, title: 'Обновления', subtitle: 'Проверить версию приложения', onTap: checkForUpdate),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const SizedBox(height: 22),
          const Text(
            'Состояние приложения',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
              final cards = [
                _homeStatus(
                  icon: Icons.devices_rounded,
                  title: 'Мультиплатформа',
                  subtitle: wide ? 'Windows • адаптивный интерфейс' : 'Android • адаптивный интерфейс',
                ),
                _homeStatus(
                  icon: Icons.favorite_rounded,
                  title: 'Избранное',
                  subtitle: favorites.isEmpty ? 'Нет сохранённых элементов' : '${favorites.length} сохранено',
                ),
                _homeStatus(
                  icon: Icons.system_update_rounded,
                  title: 'Версия',
                  subtitle: UpdateService.currentVersion,
                  onTap: checkForUpdate,
                ),
              ];
              return GridView.builder(
                itemCount: cards.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 112,
                ),
                itemBuilder: (_, index) => cards[index],
              );
            },
          ),
          const SizedBox(height: 22),
          const BelvonCard(
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 30),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Единый стиль, плавные переходы и адаптация под Windows и Android.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeStatus({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return BelvonCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x332A1D4D),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  Widget _homeAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return BelvonCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0x332A1D4D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  Widget catalog() => BelvonResponsive(
    mobile: _catalogGrid(),
    desktop: _catalogGrid(),
  );

  Widget _catalogGrid() => CustomScrollView(
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
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380, mainAxisExtent: 330, crossAxisSpacing: AppDimensions.gridGap, mainAxisSpacing: AppDimensions.gridGap,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => productCard(filtered[i]),
        ),
      ),
    ],
  );

  Widget favoritesPage() {
    final list = products.where((p) => favorites.contains(p.id)).toList();
    if (list.isEmpty) {
      return const BelvonEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'В избранном пока пусто',
        message: 'Добавленные элементы появятся здесь.',
      );
    }
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

    return BelvonCard(
      onTap: () => showProduct(p),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF242638), Color(0xFF101116)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.shopping_bag_outlined, size: 58),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: liked ? 'Убрать из избранного' : 'Добавить в избранное',
                    onPressed: () => setState(
                      () => liked
                          ? favorites.remove(p.id)
                          : favorites.add(p.id),
                    ),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(liked),
                      ),
                    ),
                  ),
                ],
              ),
              Text(p.category),
              const SizedBox(height: 5),
              Text(
                '${p.price.toStringAsFixed(0)} ₽',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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
