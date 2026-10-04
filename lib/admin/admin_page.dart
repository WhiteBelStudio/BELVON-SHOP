import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int section = 0;
  bool loading = true;
  Map<String, dynamic> dashboard = {};
  List<dynamic> users = [];
  List<dynamic> products = [];
  List<dynamic> orders = [];
  List<dynamic> reviews = [];
  List<dynamic> logs = [];
  final productSearch = TextEditingController();
  final orderSearch = TextEditingController();
  final userSearch = TextEditingController();
  final logSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    productSearch.dispose();
    orderSearch.dispose();
    userSearch.dispose();
    logSearch.dispose();
    super.dispose();
  }

  String _text(dynamic value) => value?.toString() ?? '';

  List<dynamic> get filteredProducts {
    final q = productSearch.text.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) => '${_text(p['name'])} ${_text(p['category'])} ${_text(p['id'])}'.toLowerCase().contains(q)).toList();
  }

  List<dynamic> get filteredOrders {
    final q = orderSearch.text.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders.where((o) => '${_text(o['id'])} ${_text(o['email'])} ${_text(o['status'])}'.toLowerCase().contains(q)).toList();
  }

  List<dynamic> get filteredUsers {
    final q = userSearch.text.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((u) => '${_text(u['id'])} ${_text(u['email'])} ${_text(u['role'])}'.toLowerCase().contains(q)).toList();
  }

  List<dynamic> get filteredLogs {
    final q = logSearch.text.trim().toLowerCase();
    if (q.isEmpty) return logs;
    return logs.where((l) => '${_text(l['action'])} ${_text(l['admin_email'])} ${_text(l['details'])}'.toLowerCase().contains(q)).toList();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final data = await Future.wait<dynamic>([
        ApiService.request('GET', '/admin/dashboard'),
        ApiService.request('GET', '/admin/products'),
        ApiService.request('GET', '/orders'),
        ApiService.request('GET', '/admin/reviews'),
        if (AuthService.user?.isOwner == true) ApiService.request('GET', '/admin/users'),
        if (AuthService.user?.isOwner == true) ApiService.request('GET', '/admin/logs'),
      ]);

      dashboard = Map<String, dynamic>.from(data[0] as Map);
      products = List<dynamic>.from(data[1] as List);
      orders = List<dynamic>.from(data[2] as List);
      reviews = List<dynamic>.from(data[3] as List);
      var index = 4;
      if (AuthService.user?.isOwner == true) {
        users = List<dynamic>.from(data[index++] as List);
        logs = List<dynamic>.from(data[index] as List);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = AuthService.user?.isOwner == true;
    final labels = <String>[
      'Главная',
      'Товары',
      'Заказы',
      'Отзывы',
      if (isOwner) 'Команда',
      if (isOwner) 'Логи',
    ];
    final icons = <IconData>[
      Icons.dashboard_outlined,
      Icons.inventory_2_outlined,
      Icons.receipt_long_outlined,
      Icons.rate_review_outlined,
      if (isOwner) Icons.admin_panel_settings_outlined,
      if (isOwner) Icons.history,
    ];

    if (section >= labels.length) section = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель BELVON SHOP', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Chip(
            avatar: Icon(isOwner ? Icons.verified_user : Icons.admin_panel_settings, size: 16),
            label: Text(isOwner ? 'Владелец' : 'Администратор'),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Обновить всё', onPressed: refresh, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final navigation = compact
              ? NavigationBar(
                  selectedIndex: section,
                  onDestinationSelected: (value) => setState(() => section = value),
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
                  ],
                )
              : NavigationRail(
                  selectedIndex: section,
                  onDestinationSelected: (value) => setState(() => section = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationRailDestination(icon: Icon(icons[i]), selectedIcon: Icon(icons[i]), label: Text(labels[i])),
                  ],
                );

          final content = loading
              ? const Center(child: CircularProgressIndicator())
              : _content(isOwner);

          return compact
              ? Column(children: [Expanded(child: content), navigation])
              : Row(children: [navigation, const VerticalDivider(width: 1), Expanded(child: content)]);
        },
      ),
    );
  }

  Widget _content(bool isOwner) {
    if (section == 0) return _dashboard();
    if (section == 1) return _products();
    if (section == 2) return _orders();
    if (section == 3) return _reviews();
    if (isOwner && section == 4) return _team();
    if (isOwner && section == 5) return _logs();
    return const SizedBox.shrink();
  }

  Widget _dashboard() {
    final cards = [
      ('Пользователи', dashboard['users'] ?? 0, Icons.people_alt),
      ('Сотрудники', dashboard['staff'] ?? 0, Icons.badge),
      ('Товары', dashboard['products'] ?? 0, Icons.inventory_2),
      ('Активные товары', dashboard['active_products'] ?? 0, Icons.visibility),
      ('Заказы', dashboard['orders'] ?? 0, Icons.receipt_long),
      ('Новые заказы', dashboard['new_orders'] ?? 0, Icons.notifications_active),
      ('Выручка', '${dashboard['revenue'] ?? 0} ₽', Icons.payments),
      ('Отзывы', dashboard['reviews'] ?? 0, Icons.reviews),
      ('На модерации', dashboard['pending_reviews'] ?? 0, Icons.pending_actions),
    ];

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Панель управления', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(AuthService.user?.isOwner == true ? 'Владелец • полный доступ' : 'Администратор • управление магазином'),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, mainAxisExtent: 130, crossAxisSpacing: 14, mainAxisSpacing: 14),
            itemCount: cards.length,
            itemBuilder: (_, i) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(cards[i].$3, size: 34),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(cards[i].$1),
                      const SizedBox(height: 5),
                      Text('${cards[i].$2}', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                    ])),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Центр управления', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Единая точка контроля каталога, пользователей, модерации, заказов и журнала действий.'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(onPressed: () => setState(() => section = 1), icon: const Icon(Icons.inventory_2), label: const Text('Каталог')),
                    FilledButton.tonalIcon(onPressed: () => setState(() => section = 2), icon: const Icon(Icons.receipt_long), label: const Text('Заказы')),
                    FilledButton.tonalIcon(onPressed: () => setState(() => section = 3), icon: const Icon(Icons.rate_review), label: const Text('Модерация')),
                    if (AuthService.user?.isOwner == true)
                      FilledButton.tonalIcon(onPressed: () => setState(() => section = 4), icon: const Icon(Icons.admin_panel_settings), label: const Text('Доступы')),
                    if (AuthService.user?.isOwner == true)
                      FilledButton.tonalIcon(onPressed: () => setState(() => section = 5), icon: const Icon(Icons.history), label: const Text('Аудит')),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _products() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(children: [
        Expanded(child: Text('Товары (${products.length})', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
        FilledButton.icon(onPressed: () => _productDialog(), icon: const Icon(Icons.add), label: const Text('Добавить')),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: productSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: 'Поиск по каталогу', suffixIcon: productSearch.text.isEmpty ? null : IconButton(onPressed: () { productSearch.clear(); setState(() {}); }, icon: const Icon(Icons.clear))),
      ),
      const SizedBox(height: 14),
      ...filteredProducts.map((p) => Card(child: ListTile(
        leading: CircleAvatar(child: Text('${p['id']}')),
        title: Text(p['name']?.toString() ?? ''),
        subtitle: Text('${p['category']} • ${p['price']} ₽ • ${p['available'] == true ? 'активен' : 'скрыт'}'),
        trailing: Wrap(children: [
          IconButton(onPressed: () => _productDialog(p), icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: () => _deleteProduct((p['id'] as num).toInt()), icon: const Icon(Icons.delete_outline)),
        ]),
      ))),
    ],
  );

  Future<void> _productDialog([dynamic product]) async {
    final name = TextEditingController(text: product?['name']?.toString() ?? '');
    final description = TextEditingController(text: product?['description']?.toString() ?? '');
    final category = TextEditingController(text: product?['category']?.toString() ?? 'Другое');
    final price = TextEditingController(text: product?['price']?.toString() ?? '');
    bool available = product?['available'] == true || product == null;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(product == null ? 'Новый товар' : 'Редактирование товара'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(child: Column(children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Название')),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Категория')),
              TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Описание')),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена')),
              SwitchListTile(value: available, onChanged: (v) => setDialog(() => available = v), title: const Text('Товар доступен')),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                try {
                  final body = {
                    'name': name.text.trim(),
                    'description': description.text.trim(),
                    'category': category.text.trim().isEmpty ? 'Другое' : category.text.trim(),
                    'price': double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
                    'available': available,
                  };
                  if (product == null) {
                    await ApiService.request('POST', '/products', body: body);
                  } else {
                    await ApiService.request('PATCH', '/products/${product['id']}', body: body);
                  }
                  if (context.mounted) Navigator.pop(context);
                  await refresh();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: const Text('Действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.request('DELETE', '/products/$id');
    await refresh();
  }

  Widget _orders() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text('Заказы', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      TextField(
        controller: orderSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: 'Поиск по заказам', suffixIcon: orderSearch.text.isEmpty ? null : IconButton(onPressed: () { orderSearch.clear(); setState(() {}); }, icon: const Icon(Icons.clear))),
      ),
      const SizedBox(height: 14),
      ...filteredOrders.map((o) => Card(child: ListTile(
        title: Text('Заказ #${o['id']} • ${o['total']} ₽'),
        subtitle: Text('${o['email'] ?? 'клиент'} • ${o['status']}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            await ApiService.request('PATCH', '/orders/${o['id']}/status?status_value=$value');
            await refresh();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'new', child: Text('Новый')),
            PopupMenuItem(value: 'processing', child: Text('В работе')),
            PopupMenuItem(value: 'completed', child: Text('Завершён')),
            PopupMenuItem(value: 'cancelled', child: Text('Отменён')),
          ],
          child: const Icon(Icons.more_vert),
        ),
      ))),
    ],
  );

  Widget _reviews() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text('Отзывы и модерация', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      ...reviews.map((r) => Card(child: ListTile(
        title: Text('${r['product_name']} • ${List.filled((r['rating'] as num).toInt(), '★').join()}'),
        subtitle: Text('${r['email']}\n${r['text'] ?? ''}'),
        isThreeLine: true,
        trailing: r['approved'] == true
            ? const Chip(label: Text('Одобрен'))
            : Wrap(children: [
                IconButton(onPressed: () => _moderateReview(r['id'], true), icon: const Icon(Icons.check_circle_outline)),
                IconButton(onPressed: () => _moderateReview(r['id'], false), icon: const Icon(Icons.cancel_outlined)),
              ]),
      ))),
    ],
  );

  Future<void> _moderateReview(dynamic id, bool approved) async {
    await ApiService.request('PATCH', '/admin/reviews/$id', body: {'approved': approved});
    await refresh();
  }

  Widget _team() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text('Команда и доступы', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Раздел владельца: управление ролями, блокировкой аккаунтов и доступом сотрудников.'),
      const SizedBox(height: 12),
      TextField(
        controller: userSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: 'Поиск пользователей', suffixIcon: userSearch.text.isEmpty ? null : IconButton(onPressed: () { userSearch.clear(); setState(() {}); }, icon: const Icon(Icons.clear))),
      ),
      const SizedBox(height: 14),
      ...filteredUsers.map((u) => Card(child: ListTile(
        title: Text(u['email']?.toString() ?? ''),
        subtitle: Text('ID ${u['id']} • ${u['role']} • ${u['blocked'] == true ? 'заблокирован' : 'активен'}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'admin' || value == 'customer') {
              await ApiService.request('PATCH', '/admin/users/${u['id']}/role', body: {'role': value});
            } else if (value == 'block') {
              await ApiService.request('PATCH', '/admin/users/${u['id']}/blocked', body: {'blocked': !(u['blocked'] == true)});
            }
            await refresh();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'admin', child: Text('Назначить админом')),
            const PopupMenuItem(value: 'customer', child: Text('Снять права админа')),
            PopupMenuItem(value: 'block', child: Text(u['blocked'] == true ? 'Разблокировать' : 'Заблокировать')),
          ],
          child: const Icon(Icons.more_vert),
        ),
      ))),
    ],
  );

  Widget _logs() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text('Журнал действий и аудит', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Все доступные сервером административные события отображаются здесь для контроля действий команды.'),
      const SizedBox(height: 12),
      TextField(
        controller: logSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: 'Поиск по журналу', suffixIcon: logSearch.text.isEmpty ? null : IconButton(onPressed: () { logSearch.clear(); setState(() {}); }, icon: const Icon(Icons.clear))),
      ),
      const SizedBox(height: 14),
      ...filteredLogs.map((l) => Card(child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(l['action']?.toString() ?? ''),
        subtitle: Text('${l['admin_email'] ?? 'система'} • ${l['details'] ?? ''}'),
      ))),
    ],
  );
}
