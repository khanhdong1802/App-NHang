import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard/dashboard_page.dart';

import 'providers/chat_provider.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..restoreSession()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'BeVietnamPro',
          fontFamilyFallback: const [
            'Segoe UI Emoji',
            'Segoe UI Symbol',
            'Apple Color Emoji',
            'Noto Color Emoji',
            'Noto Emoji',
          ],
        ),
        initialRoute: "/login",
        routes: {
          "/login": (_) => const LoginScreen(),
          "/register": (_) => const RegisterScreen(),
          "/dashboard": (_) => const DashboardPage(),
        },
      ),
    );
  }
}
