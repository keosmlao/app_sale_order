import 'package:flutter_test/flutter_test.dart';
import 'package:odg_sale_app/config.dart';
import 'package:odg_sale_app/main.dart';

void main() {
  testWidgets('App launches without crashing', (tester) async {
    await tester.pumpWidget(
      OdgSaleApp(
        baseUrl: AppConfig.defaultApiBaseUrl,
        config: ConfigService(),
      ),
    );
    await tester.pump();
    expect(find.byType(OdgSaleApp), findsOneWidget);
  });
}
