import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/confirmation_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'services/http_client_service.dart';

void main() async {
  print('🚀 main() called - Starting app initialization');

  try {
    print('  Initializing WidgetsFlutterBinding...');
    WidgetsFlutterBinding.ensureInitialized();
    print('  ✅ WidgetsFlutterBinding initialized');

    // Initialize auth provider and restore session
    print('  Creating AuthProvider...');
    final authProvider = AuthProvider();
    print('  ✅ AuthProvider created');

    print('  Calling authProvider.initialize()...');
    await authProvider.initialize();
    print('  ✅ authProvider.initialize() completed');

    // Initialize HttpClientService with AuthProvider
    print('  Creating HttpClientService...');
    final httpClient = HttpClientService();
    print('  Setting AuthProvider in HttpClientService...');
    httpClient.setAuthProvider(authProvider);
    print('  ✅ HttpClientService configured');

    print('  Calling runApp...');
    runApp(DeliveryApp(authProvider: authProvider));
    print('  ✅ runApp called');
  } catch (e, stackTrace) {
    print('❌ ERROR in main(): $e');
    print('Stack trace: $stackTrace');
    // Still try to run the app even if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text('App Initialization Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text('$e', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    ));
  }
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
          // Input field theme with mobile-friendly defaults
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            // Add default content padding for better touch targets
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16, // Ensures minimum 48dp touch target
            ),
            // Add constraints for minimum height (Material Design guideline)
            constraints: const BoxConstraints(
              minHeight: 48, // Minimum touch target size
            ),
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
          // Text theme with mobile-optimized font sizes
          textTheme: const TextTheme(
            // Default text style for body text and input fields
            bodyLarge: TextStyle(fontSize: 16), // Prevents iOS auto-zoom
            bodyMedium: TextStyle(fontSize: 16), // Prevents iOS auto-zoom
            bodySmall: TextStyle(fontSize: 14),
            // Input field text style
            titleMedium: TextStyle(fontSize: 16), // Used by TextFormField
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              // Increased padding for better touch targets on mobile
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              minimumSize: const Size(88, 48), // Material Design minimum
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
            print('');
            print('═══════════════════════════════════════════════════');
            print('🔄 [Main Consumer] Building/Rebuilding UI');
            print('═══════════════════════════════════════════════════');
            print('  isInitialized: ${auth.isInitialized}');
            print('  isAuthenticated: ${auth.isAuthenticated}');
            print('  user: ${auth.user?.username ?? "null"}');
            print('  token: ${auth.token != null ? '${auth.token!.substring(0, math.min(20, auth.token!.length))}...' : 'null'}');
            print('═══════════════════════════════════════════════════');

            if (!auth.isInitialized) {
              print('➡️  Decision: Showing LOADING screen (not initialized)');
              print('═══════════════════════════════════════════════════');
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Initializing...', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            }

            if (auth.isAuthenticated && auth.user != null) {
              print('➡️  Decision: Showing CONFIRMATION screen (authenticated)');
              print('═══════════════════════════════════════════════════');
              return ConfirmationScreen(
                user: auth.user!,
                profile: auth.profile,
                token: auth.token!,
              );
            }

            print('➡️  Decision: Showing LOGIN screen (not authenticated)');
            print('═══════════════════════════════════════════════════');
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
