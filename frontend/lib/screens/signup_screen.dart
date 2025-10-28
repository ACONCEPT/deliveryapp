import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Common fields
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Vendor-specific fields
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Driver-specific fields
  final _vehicleTypeController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  // State
  String _selectedUserType = 'customer'; // Default to customer
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _descriptionController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  /// Handles form submission and API call
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.signup(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userType: _selectedUserType,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        // Vendor-specific fields
        businessName: _selectedUserType == 'vendor'
            ? _businessNameController.text.trim()
            : null,
        description: _selectedUserType == 'vendor' && _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        // Driver-specific fields
        vehicleType: _selectedUserType == 'driver' && _vehicleTypeController.text.trim().isNotEmpty
            ? _vehicleTypeController.text.trim()
            : null,
        vehiclePlate: _selectedUserType == 'driver' && _vehiclePlateController.text.trim().isNotEmpty
            ? _vehiclePlateController.text.trim()
            : null,
        licenseNumber: _selectedUserType == 'driver' && _licenseNumberController.text.trim().isNotEmpty
            ? _licenseNumberController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (response.success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Basic email regex pattern
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Username validation (3-50 characters)
  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.length > 50) {
      return 'Username must be no more than 50 characters';
    }
    return null;
  }

  /// Password validation (minimum 6 characters)
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Confirm password validation
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon
                  Icon(
                    Icons.delivery_dining,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),

                  // App Title
                  Text(
                    'Delivery App',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Create your account',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // User Type Selector
                  Text(
                    'Account Type',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'customer',
                        label: Text('Customer'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment<String>(
                        value: 'vendor',
                        label: Text('Vendor'),
                        icon: Icon(Icons.store),
                      ),
                      ButtonSegment<String>(
                        value: 'driver',
                        label: Text('Driver'),
                        icon: Icon(Icons.local_shipping),
                      ),
                    ],
                    selected: {_selectedUserType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedUserType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Common Fields

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validateUsername,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validatePassword,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validateConfirmPassword,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Full Name Field
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Phone Field (Optional for all types)
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone (Optional)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Vendor-Specific Fields
                  if (_selectedUserType == 'vendor') ...[
                    // Business Name Field (Required for vendors)
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(
                        labelText: 'Business Name',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your business name';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Description Field (Optional)
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Business Description (Optional)',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Driver-Specific Fields
                  if (_selectedUserType == 'driver') ...[
                    // Vehicle Type Field (Optional)
                    TextFormField(
                      controller: _vehicleTypeController,
                      decoration: InputDecoration(
                        labelText: 'Vehicle Type (Optional)',
                        prefixIcon: const Icon(Icons.directions_car),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'e.g., Car, Motorcycle, Bike',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Plate Field (Optional)
                    TextFormField(
                      controller: _vehiclePlateController,
                      decoration: InputDecoration(
                        labelText: 'Vehicle Plate (Optional)',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'e.g., ABC-123',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // License Number Field (Optional)
                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: InputDecoration(
                        labelText: 'License Number (Optional)',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Signup Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Already have account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
