import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/restaurant_request.dart';
import '../services/restaurant_service.dart';
import '../services/nominatim_service.dart';
import '../widgets/address_autocomplete_field.dart';

class RestaurantFormScreen extends StatefulWidget {
  final String token;
  final Restaurant? restaurant; // null for create mode, provided for edit mode

  const RestaurantFormScreen({
    super.key,
    required this.token,
    this.restaurant,
  });

  @override
  State<RestaurantFormScreen> createState() => _RestaurantFormScreenState();
}

class _RestaurantFormScreenState extends State<RestaurantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final RestaurantService _restaurantService = RestaurantService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  bool _isLoading = false;

  bool get _isEditMode => widget.restaurant != null;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data if editing
    _nameController = TextEditingController(
      text: widget.restaurant?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.restaurant?.description ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.restaurant?.phone ?? '',
    );
    _addressLine1Controller = TextEditingController(
      text: widget.restaurant?.addressLine1 ?? '',
    );
    _addressLine2Controller = TextEditingController(
      text: widget.restaurant?.addressLine2 ?? '',
    );
    _cityController = TextEditingController(
      text: widget.restaurant?.city ?? '',
    );
    _stateController = TextEditingController(
      text: widget.restaurant?.state ?? '',
    );
    _postalCodeController = TextEditingController(
      text: widget.restaurant?.postalCode ?? '',
    );
    _countryController = TextEditingController(
      text: widget.restaurant?.country ?? 'USA',
    );
    _latitudeController = TextEditingController(
      text: widget.restaurant?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: widget.restaurant?.longitude?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _handleAddressSelected(AddressSuggestion suggestion) {
    setState(() {
      // Auto-fill address fields from the selected suggestion
      _addressLine1Controller.text = suggestion.street;
      _addressLine2Controller.text = ''; // Clear address line 2
      _cityController.text = suggestion.city ?? '';
      _stateController.text = suggestion.state ?? '';
      _postalCodeController.text = suggestion.postalCode ?? '';
      _countryController.text = suggestion.country ?? 'USA';
      _latitudeController.text = suggestion.lat.toString();
      _longitudeController.text = suggestion.lon.toString();
    });

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Address auto-filled from: ${suggestion.displayName}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveRestaurant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse latitude and longitude
      double? latitude;
      double? longitude;

      if (_latitudeController.text.trim().isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text.trim());
      }

      if (_longitudeController.text.trim().isNotEmpty) {
        longitude = double.tryParse(_longitudeController.text.trim());
      }

      if (_isEditMode) {
        // Update mode
        final request = UpdateRestaurantRequest(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          addressLine1: _addressLine1Controller.text.trim().isEmpty
              ? null
              : _addressLine1Controller.text.trim(),
          addressLine2: _addressLine2Controller.text.trim().isEmpty
              ? null
              : _addressLine2Controller.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
          latitude: latitude,
          longitude: longitude,
        );

        await _restaurantService.updateRestaurant(
          widget.token,
          widget.restaurant!.id!,
          request,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restaurant updated successfully')),
          );
        }
      } else {
        // Create mode
        final request = CreateRestaurantRequest(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          addressLine1: _addressLine1Controller.text.trim().isEmpty
              ? null
              : _addressLine1Controller.text.trim(),
          addressLine2: _addressLine2Controller.text.trim().isEmpty
              ? null
              : _addressLine2Controller.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          state: _stateController.text.trim().isEmpty
              ? null
              : _stateController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
          latitude: latitude,
          longitude: longitude,
        );

        await _restaurantService.createRestaurant(widget.token, request);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restaurant created successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Restaurant' : 'Create Restaurant'),
        backgroundColor: Colors.blue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Restaurant Name',
                hintText: 'Enter restaurant name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Restaurant name is required';
                }
                if (value.trim().length > 255) {
                  return 'Name must be 255 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter restaurant description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (Optional)',
                hintText: 'Enter phone number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            // Address Section Header
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.deepOrange[700]),
                const SizedBox(width: 8),
                Text(
                  'Restaurant Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Start typing an address to search and auto-fill all fields',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            // Address Autocomplete Field
            AddressAutocompleteField(
              controller: _addressLine1Controller,
              labelText: 'Search Address',
              hintText: 'Start typing street address...',
              onAddressSelected: _handleAddressSelected,
              countryCode: 'us', // Restrict to US addresses
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine2Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 2 (Optional)',
                hintText: 'Apartment, suite, unit',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'City (Auto-filled)',
                hintText: 'Will be filled from address search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_city),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'State (Auto-filled)',
                hintText: 'Will be filled from address search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.map),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _postalCodeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Postal Code (Auto-filled)',
                hintText: 'Will be filled from address search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.local_post_office),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countryController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Country (Auto-filled)',
                hintText: 'Will be filled from address search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.flag),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 24),
            // Coordinates Section Header
            Row(
              children: [
                Icon(Icons.my_location, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Coordinates (Auto-filled)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Latitude and longitude are automatically filled from address search',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _latitudeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Latitude (Auto-filled)',
                hintText: 'Will be filled from address search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.my_location),
                filled: true,
                fillColor: Colors.blue[50],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _longitudeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Longitude (Auto-filled)',
                hintText: 'Will be filled from address search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.place),
                filled: true,
                fillColor: Colors.blue[50],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveRestaurant,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEditMode ? 'Update Restaurant' : 'Create Restaurant',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
