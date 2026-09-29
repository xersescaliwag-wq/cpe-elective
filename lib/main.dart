import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'api/mail_repository.dart';
import 'screens/inbox_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-warms the glass shaders so the first frame doesn't white-flash.
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      theme: GlassThemeData.simple(blur: 14, thickness: 30),
      child: const MailApp(),
    ),
  );
}




/// MailFlow root.
///
/// Deliberately uses [WidgetsApp] (not MaterialApp/CupertinoApp): the glass
/// design system brings its own chrome, so the neutral shell keeps this file
/// free of any Material dependency.
class MailApp extends StatelessWidget {
  const MailApp({super.key, this.repository});

  /// Injectable for tests and demos; sails through to the inbox.
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
