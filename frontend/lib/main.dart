import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/confirmation_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'services/http_client_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize auth provider and restore session
  final authProvider = AuthProvider();
  await authProvider.initialize();

  // Initialize HttpClientService with AuthProvider
  final httpClient = HttpClientService();
  httpClient.setAuthProvider(authProvider);

  runApp(DeliveryApp(authProvider: authProvider));
}

class DeliveryApp extends StatelessWidget {
  final AuthProvider authProvider;

  const DeliveryApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Delivery App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
            brightness: Brightness.light,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isInitialized) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (auth.isAuthenticated && auth.user != null) {
              return ConfirmationScreen(
                user: auth.user!,
                profile: auth.profile,
                token: auth.token!,
              );
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
