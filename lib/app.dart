import 'dart:async';

import 'package:flutter/material.dart';
import 'data/products.dart';
import 'models/product.dart';
import 'services/update_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/favorites_service.dart';
import 'admin/admin_page.dart';
import 'theme/app_theme.dart';
import 'widgets/belvon_card.dart';
import 'widgets/belvon_states.dart';
import 'widgets/belvon_responsive.dart';
import 'theme/app_dimensions.dart';


class ProductDetailsPage extends StatelessWidget {
  final Product product;
  final bool liked;
  final VoidCallback onToggleFavorite;

  const ProductDetailsPage({super.key, required this.product, required this.liked, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Товар'),
        actions: [
          IconButton(
            tooltip: liked ? 'Убрать из избранного' : 'Добавить в избранное',
            onPressed: onToggleFavorite,
            icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final preview = _preview();
                final info = _info();
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: preview),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: info),
                        ],
                      )
                    : Column(children: [preview, const SizedBox(height: 20), info]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview() => AspectRatio(
        aspectRatio: 1.05,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF242638), Color(0xFF101116)],
            ),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 92)),
        ),
      );

  Widget _info() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.category.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Colors.white60)),
          const SizedBox(height: 10),
          Text(product.name, style: const TextStyle(fontSize: 34, height: 1.05, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Text(product.description, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70)),
          const SizedBox(height: 22),
          Text('${product.price.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onToggleFavorite,
              icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              label: Text(liked ? 'В избранном' : 'Добавить в избранное'),
            ),
          ),
        ],
      );
}


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
    _loadFavorites();
    if (AuthService.user?.isAdmin == true) {
      approvalTimer = Timer.periodic(const Duration(seconds: 6), (_) => checkDeviceRequests());
      Future<void>.delayed(const Duration(seconds: 2), checkDeviceRequests);
    }
  }

  @override
  void dispose() {
    approvalTimer?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
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
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final recentSearches = <String>[];
  final favorites = <int>{};
  final cart = <int, int>{};
  bool favoritesLoaded = false;
  String favoritesSort = 'Недавно добавленные';

  Future<void> _loadFavorites() async {
    final saved = await FavoritesService.load();
    if (!mounted) return;
    setState(() {
      favorites
        ..clear()
        ..addAll(saved);
      favoritesLoaded = true;
    });
  }

  Future<void> _toggleFavorite(int productId) async {
    setState(() {
      if (favorites.contains(productId)) {
        favorites.remove(productId);
      } else {
        favorites.add(productId);
      }
    });
    await FavoritesService.save(favorites);
  }

  List<String> get categories => ['Все', ...{for (final p in products) p.category}];

  String _normalizeSearch(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  List<Product> get filtered => products.where((p) {
    final q = _normalizeSearch(query);
    return (category == 'Все' || p.category == category) &&
      (q.isEmpty || p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q));
  }).toList();

  void _setSearch(String value, {bool remember = false}) {
    final normalized = _normalizeSearch(value);
    searchController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    setState(() => query = normalized);
    if (remember && normalized.isNotEmpty) {
      setState(() {
        recentSearches.remove(normalized);
        recentSearches.insert(0, normalized);
        if (recentSearches.length > 5) recentSearches.removeLast();
      });
    }
  }

  void openSearch() {
    if (tab != 1) setState(() => tab = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      searchFocusNode.requestFocus();
    });
  }

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
        IconButton(
          tooltip: 'Поиск',
          onPressed: openSearch,
          icon: const Icon(Icons.search_rounded),
        ),
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
                  subtitle: wide ? 'Большой экран • адаптивный интерфейс' : 'Мобильный экран • адаптивный интерфейс',
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
                    'Единый стиль, плавные переходы и адаптивная компоновка на разных экранах.',
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

  Widget catalog() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: _catalogHeader()),
      SliverToBoxAdapter(child: _catalogSearch()),
      SliverToBoxAdapter(child: _catalogFilters()),
      SliverToBoxAdapter(child: _catalogSummary()),
      if (filtered.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: BelvonEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Ничего не найдено',
            message: 'Попробуйте изменить запрос или выбрать другую категорию.',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.pagePadding,
            4,
            AppDimensions.pagePadding,
            28,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 330,
              crossAxisSpacing: AppDimensions.gridGap,
              mainAxisSpacing: AppDimensions.gridGap,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) => productCard(filtered[i]),
          ),
        ),
    ],
  );

  Widget _catalogHeader() {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 8, wide ? 24 : 16, 12),
      child: BelvonCard(
        padding: EdgeInsets.zero,
        child: Container(
          constraints: BoxConstraints(minHeight: wide ? 190 : 210),
          padding: EdgeInsets.all(wide ? 28 : 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF241449),
                Color(0xFF141D36),
                Color(0xFF0E1017),
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BELVON SHOP • КАТАЛОГ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Каталог',
                      style: TextStyle(
                        fontSize: wide ? 36 : 30,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Поиск, категории и избранное — всё в одном месте.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 20),
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                  ),
                  child: const Icon(Icons.storefront_rounded, size: 36),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _catalogSearch() {
    final hasQuery = _normalizeSearch(query).isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: (value) => setState(() => query = value),
            onSubmitted: (value) {
              _setSearch(value, remember: true);
              searchFocusNode.unfocus();
            },
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Найти товар по названию или описанию',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: !hasQuery
                  ? null
                  : IconButton(
                      tooltip: 'Очистить поиск',
                      onPressed: () {
                        searchController.clear();
                        setState(() => query = '');
                        searchFocusNode.requestFocus();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          if (!hasQuery && recentSearches.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentSearches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final value = recentSearches[index];
                  return ActionChip(
                    avatar: const Icon(Icons.history_rounded, size: 16),
                    label: Text(value),
                    onPressed: () => _setSearch(value),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _catalogFilters() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final value = categories[index];
          return ChoiceChip(
            label: Text(value),
            selected: category == value,
            onSelected: (_) => setState(() => category = value),
          );
        },
      ),
    );
  }

  Widget _catalogSummary() {
    final count = filtered.length;
    final activeSearch = _normalizeSearch(query).isNotEmpty;
    final filterLabel = category == 'Все' ? 'Все категории' : category;
    final label = activeSearch
        ? 'Найдено: $count • $filterLabel'
        : '$count элементов • $filterLabel';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Align(
          key: ValueKey('$query|$category|$count'),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget favoritesPage() {
    var list = products.where((p) => favorites.contains(p.id)).toList();

    switch (favoritesSort) {
      case 'Цена ↑':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Цена ↓':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Название':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  favorites.isEmpty
                      ? 'Избранное'
                      : '${favorites.length} ${favorites.length == 1 ? 'товар' : favorites.length < 5 ? 'товара' : 'товаров'}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              if (favorites.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Сортировка',
                  initialValue: favoritesSort,
                  onSelected: (value) => setState(() => favoritesSort = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Недавно добавленные', child: Text('Недавно добавленные')),
                    PopupMenuItem(value: 'Цена ↑', child: Text('Цена: по возрастанию')),
                    PopupMenuItem(value: 'Цена ↓', child: Text('Цена: по убыванию')),
                    PopupMenuItem(value: 'Название', child: Text('По названию')),
                  ],
                  child: const Icon(Icons.sort_rounded),
                ),
            ],
          ),
        ),
        if (list.isEmpty)
          Expanded(
            child: BelvonEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'В избранном пока пусто',
              message: 'Сохраняйте понравившиеся товары — они появятся здесь.',
              action: () => openTab(1),
              actionLabel: 'Перейти в каталог',
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 330,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => productCard(list[i]),
            ),
          ),
      ],
    );
  }

  Widget profile() {
    final user = AuthService.user;
    final role = user?.isOwner == true
        ? 'Владелец'
        : user?.isAdmin == true
            ? 'Администратор'
            : 'Покупатель';
    final initials = user?.email.isNotEmpty == true
        ? user!.email.substring(0, 1).toUpperCase()
        : 'G';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1730), Color(0xFF11131B)],
                    ),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.email ?? 'Гость',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  user == null
                                      ? Icons.person_outline_rounded
                                      : Icons.verified_rounded,
                                  size: 17,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  user == null ? 'Не авторизован' : role,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (user != null)
                        IconButton(
                          tooltip: 'Выйти',
                          onPressed: _logoutFromProfile,
                          icon: const Icon(Icons.logout_rounded),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _profileStat(
                        Icons.favorite_rounded,
                        '${favorites.length}',
                        'Избранное',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _profileStat(
                        Icons.shopping_bag_outlined,
                        '${products.length}',
                        'В каталоге',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _profileStat(
                        Icons.security_rounded,
                        user == null ? 'Гость' : 'OK',
                        'Безопасность',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (user == null)
                  BelvonCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Войдите в аккаунт',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Синхронизируйте профиль и получите доступ к функциям аккаунта.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: showLogin,
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Войти в аккаунт'),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _profileSection(
                    title: 'Аккаунт',
                    children: [
                      _profileTile(Icons.email_outlined, 'Email', user.email),
                      _profileTile(Icons.badge_outlined, 'Роль', role),
                      _profileTile(
                        user.blocked
                            ? Icons.block_rounded
                            : Icons.verified_user_outlined,
                        'Статус',
                        user.blocked ? 'Аккаунт заблокирован' : 'Аккаунт активен',
                        valueColor: user.blocked
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _profileSection(
                    title: 'Быстрый доступ',
                    children: [
                      _profileTile(
                        Icons.favorite_border_rounded,
                        'Избранное',
                        '${favorites.length} сохранённых',
                        onTap: () => openTab(2),
                      ),
                      _profileTile(
                        Icons.receipt_long_rounded,
                        'Мои заказы',
                        'История заказов',
                        onTap: () {},
                      ),
                      if (user.isAdmin)
                        _profileTile(
                          Icons.admin_panel_settings_outlined,
                          'Админ-панель',
                          user.isOwner
                              ? 'Полный доступ владельца'
                              : 'Управление магазином',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminPage(),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _profileSection(
                    title: 'Приложение',
                    children: [
                      _profileTile(
                        Icons.settings_outlined,
                        'Настройки',
                        'Параметры приложения',
                        onTap: () {},
                      ),
                      _profileTile(
                        Icons.system_update_rounded,
                        'Обновление',
                        'Версия ${UpdateService.currentVersion}',
                        onTap: checkForUpdate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  BelvonCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text(
                        'Выйти из аккаунта',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Удалить текущую сессию на этом устройстве',
                      ),
                      onTap: _logoutFromProfile,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileStat(IconData icon, String value, String label) {
    return BelvonCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _profileSection({
    required String title,
    required List<Widget> children,
  }) {
    return BelvonCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
                color: Colors.white60,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _profileTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    Color? valueColor,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: valueColor ?? Colors.white60),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Future<void> _logoutFromProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Текущая сессия будет удалена с этого устройства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (route) => false,
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
                    onPressed: () => _toggleFavorite(p.id),
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

  Future<void> showProduct(Product p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          product: p,
          liked: favorites.contains(p.id),
          onToggleFavorite: () => _toggleFavorite(p.id),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

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
