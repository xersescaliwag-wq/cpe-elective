import 'package:cpeelective/api/mail_repository.dart';
import 'package:cpeelective/main.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Inbox renders messages from the repository', (tester) async {
    final repo = MockMailRepository();
    await tester.pumpWidget(MailApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.textContaining('Welcome to Flutter'), findsOneWidget);
    expect(find.text('Loading sender'), findsNothing); // skeleton gone
  });

  testWidgets('Compose opens from the inbox and can be closed', (tester) async {
    final repo = MockMailRepository();
    await tester.pumpWidget(MailApp(repository: repo));
    await tester.pumpAndSettle();

    // Open compose from the inbox app bar's compose button.
    await tester.tap(find.byKey(const ValueKey('compose-open')));
    await tester.pumpAndSettle();

    expect(find.text('New Message'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);

    // Close via the compose app bar's back button.
    await tester.tap(find.byKey(const ValueKey('compose-back')));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets('A message opens detail and can be deleted via the dialog',
      (tester) async {
    final repo = MockMailRepository();
    await tester.pumpWidget(MailApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Welcome to Flutter 3.44'));
    await tester.pumpAndSettle();

    // Detail app bar: tap the trash (delete) button.
    await tester.tap(find.byKey(const ValueKey('message-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Back on the inbox, the deleted message is gone.
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Welcome to Flutter 3.44'), findsNothing);
  });
}