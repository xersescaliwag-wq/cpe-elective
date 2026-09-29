import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'api/mail_repository.dart';
import 'screens/inbox_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      theme: GlassThemeData.simple(blur: 14, thickness: 30),
      child: const MailApp(),
    ),
  );
}

class MailApp extends StatelessWidget {
  const MailApp({super.key, this.repository});

  final MailRepository? repository;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF07090E),
      debugShowCheckedModeBanner: false,
      supportedLocales: const <Locale>[Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: (settings) {
        return PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) {
            return InboxScreen(repository: repository);
          },
        );
      },
    );
  }
}
