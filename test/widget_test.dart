import 'package:flutter_test/flutter_test.dart';
import 'package:belvon_shop/app.dart';

void main() {
  testWidgets('BELVON SHOP opens the authentication screen', (tester) async {
    await tester.pumpWidget(const BelvonApp());

    expect(find.text('BELVON SHOP'), findsOneWidget);
    expect(find.text('Безопасный вход в приложение'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Создать новый аккаунт'), findsOneWidget);
  });
}
