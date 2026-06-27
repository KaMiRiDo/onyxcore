import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/archive_manager/presentation/widgets/password_dialog.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: PasswordDialog(),
        ),
      ),
    );
  }

  group('PasswordDialog', () {
    testWidgets('renders correctly with default text', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      expect(find.text('Enter Password'), findsOneWidget);
      expect(find.text('This archive is encrypted and requires a password to extract.'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('UNLOCK'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);

      final visibilityIcon = find.byIcon(Icons.visibility_rounded);
      expect(visibilityIcon, findsOneWidget);
      
      await tester.tap(visibilityIcon);
      await tester.pumpAndSettle();
      
      final textFieldVisible = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldVisible.obscureText, isFalse);
      
      final visibilityOffIcon = find.byIcon(Icons.visibility_off_rounded);
      expect(visibilityOffIcon, findsOneWidget);
    });

    testWidgets('cancels dialog when cancel button is pressed', (tester) async {
      var canceled = false;
      
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final result = await PasswordDialog.show(context);
                if (result == null) {
                  canceled = true;
                }
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      
      expect(canceled, isTrue);
    });

    testWidgets('returns password when unlock button is pressed', (tester) async {
      String? returnedPassword;
      
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                returnedPassword = await PasswordDialog.show(context);
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextField), 'mysecretpassword');
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('UNLOCK'));
      await tester.pumpAndSettle();
      
      expect(returnedPassword, 'mysecretpassword');
    });

    testWidgets('does not return anything if text is empty when unlock is pressed', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await PasswordDialog.show(context);
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('UNLOCK'));
      await tester.pumpAndSettle();
      
      // Dialog should still be open
      expect(find.byType(PasswordDialog), findsOneWidget);
    });
  });
}
