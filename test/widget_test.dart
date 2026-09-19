import 'package:flutter_test/flutter_test.dart';
import 'package:belvon_shop/app.dart';

void main() {
  testWidgets('BELVON SHOP starts with catalog', (tester) async {
    await tester.pumpWidget(const BelvonApp());
    expect(find.text('BELVON SHOP'), findsOneWidget);
    expect(find.text('Каталог'), findsOneWidget);
  });
}
