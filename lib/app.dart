import 'package:flutter/material.dart';
import 'data/products.dart';
import 'models/product.dart';

class BelvonApp extends StatelessWidget {
  const BelvonApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BELVON SHOP',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF08090D),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFF), brightness: Brightness.dark),
    ),
    home: const ShopPage(),
  );
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int tab = 0;
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
      title: const Text('BELVON SHOP', style: TextStyle(fontWeight: FontWeight.w900)),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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

  Widget profile() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
      const SizedBox(height: 16),
      const Center(child: Text('Мой профиль', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
      const SizedBox(height: 20),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Мои заказы'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Настройки'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
      ])),
    ],
  );

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
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
              ),
            ]),
            Text(p.category),
            const SizedBox(height: 5),
            Text(p.price.toStringAsFixed(0) + ' ₽', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
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
        Text(p.price.toStringAsFixed(0) + ' ₽', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
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
              subtitle: Text(p.price.toStringAsFixed(0) + ' ₽ × ' + cart[p.id].toString()),
              trailing: IconButton(onPressed: () => setState(() => cart.remove(p.id)), icon: const Icon(Icons.delete_outline)),
            )),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Итого: ' + cartTotal.toStringAsFixed(0) + ' ₽', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Оформить заказ'))),
          ],
        ]),
      ),
    ),
  );
}
