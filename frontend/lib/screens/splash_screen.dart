import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'confirmation_screen.dart';

/// Splash screen that checks for existing authentication on app startup
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    developer.log('SplashScreen initialized', name: 'SplashScreen');
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthProvider>(context);

    developer.log(
      'SplashScreen build - isAuthenticated: ${authState.isAuthenticated}, isInitialized: ${authState.isInitialized}',
      name: 'SplashScreen',
    );

    // Show splash screen while loading
    if (!authState.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delivery_dining,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Delivery App',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Navigate to appropriate screen after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.isAuthenticated && authState.user != null) {
        developer.log('User authenticated, navigating to dashboard', name: 'SplashScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ConfirmationScreen(
              user: authState.user!,
              profile: authState.profile,
              token: authState.token!,
            ),
          ),
        );
      } else {
        developer.log('User not authenticated, navigating to login', name: 'SplashScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    });

    // Return loading screen while navigation happens
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining,
              size: 100,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Delivery App',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
