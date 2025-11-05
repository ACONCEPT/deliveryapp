import 'package:flutter/material.dart';
import '../models/address.dart';
import '../services/address_service.dart';
import '../services/nominatim_service.dart';
import '../mixins/form_state_mixin.dart';
import '../widgets/address_autocomplete_field.dart';

/// Address creation and editing form with validation.
/// Uses FormStateMixin for consistent form state management.
class AddressFormScreen extends StatefulWidget {
  final String token;
  final Address? address; // null for new address, provided for editing

  const AddressFormScreen({
    super.key,
    required this.token,
    this.address,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen>
    with FormStateMixin {
  final AddressService _addressService = AddressService();
  bool _isDefault = false;

  bool get _isEditMode => widget.address != null;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data if editing
    createController('addressLine1',
        initialValue: widget.address?.addressLine1 ?? '');
    createController('addressLine2',
        initialValue: widget.address?.addressLine2 ?? '');
    createController('city', initialValue: widget.address?.city ?? '');
    createController('state', initialValue: widget.address?.state ?? '');
    createController('postalCode',
        initialValue: widget.address?.postalCode ?? '');
    createController('country',
        initialValue: widget.address?.country ?? 'USA');

    // Add controllers for latitude and longitude (optional, for future use)
    createController('latitude',
        initialValue: widget.address?.latitude?.toString() ?? '');
    createController('longitude',
        initialValue: widget.address?.longitude?.toString() ?? '');

    _isDefault = widget.address?.isDefault ?? false;
  }

  /// Handler for when an address is selected from autocomplete
  void _handleAddressSelected(AddressSuggestion suggestion) {
    setState(() {
      // Auto-fill address fields from the selected suggestion
      controller('addressLine1').text = suggestion.street;
      controller('addressLine2').text = ''; // Clear address line 2
      controller('city').text = suggestion.city ?? '';
      controller('state').text = suggestion.state ?? '';
      controller('postalCode').text = suggestion.postalCode ?? '';
      controller('country').text = suggestion.country ?? 'USA';
      controller('latitude').text = suggestion.lat.toString();
      controller('longitude').text = suggestion.lon.toString();
    });

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Address auto-filled from: ${suggestion.displayName}'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveAddress() async {
    await executeSave(
      operation: () async {
        // Parse latitude and longitude if available
        double? latitude;
        double? longitude;

        final latText = controller('latitude').text.trim();
        final lonText = controller('longitude').text.trim();

        if (latText.isNotEmpty) {
          latitude = double.tryParse(latText);
        }

        if (lonText.isNotEmpty) {
          longitude = double.tryParse(lonText);
        }

        final address = Address(
          id: widget.address?.id,
          customerId: widget.address?.customerId,
          addressLine1: getText('addressLine1'),
          addressLine2: getTextOrNull('addressLine2'),
          city: getText('city'),
          state: getTextOrNull('state'),
          postalCode: getTextOrNull('postalCode'),
          country: getText('country'),
          latitude: latitude,
          longitude: longitude,
          isDefault: _isDefault,
        );

        if (_isEditMode) {
          await _addressService.updateAddress(
            widget.token,
            widget.address!.id!,
            address,
          );
        } else {
          await _addressService.createAddress(widget.token, address);
        }
      },
      successMessage: _isEditMode
          ? 'Address updated successfully'
          : 'Address created successfully',
      popOnSuccess: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Address' : 'Add Address'),
        backgroundColor: Colors.blue,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Address Autocomplete Section Header
            Row(
              children: [
                Icon(Icons.search, color: Colors.deepOrange[700]),
                const SizedBox(width: 8),
                Text(
                  'Search Address',
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
              'Start typing to search and auto-fill address fields',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            // Address Autocomplete Field
            AddressAutocompleteField(
              controller: controller('addressLine1'),
              labelText: 'Address Line 1',
              hintText: 'Start typing street address...',
              onAddressSelected: _handleAddressSelected,
              countryCode: 'us', // Restrict to US addresses
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Address line 1 is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller('addressLine2'),
              decoration: const InputDecoration(
                labelText: 'Address Line 2 (Optional)',
                hintText: 'Apartment, suite, unit, building, floor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
              ),
            ),
            const SizedBox(height: 24),
            // Address Details Section Header
            Row(
              children: [
                Icon(Icons.edit, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Address Details',
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
              'These fields are auto-filled but you can edit them if needed',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller('city'),
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'Auto-filled from search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_city),
                filled: true,
                fillColor: Colors.blue[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'City is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller('state'),
                    decoration: InputDecoration(
                      labelText: 'State/Province',
                      hintText: 'Auto-filled',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.map),
                      filled: true,
                      fillColor: Colors.blue[50],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: controller('postalCode'),
                    decoration: InputDecoration(
                      labelText: 'Postal Code',
                      hintText: 'Auto-filled',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.local_post_office),
                      filled: true,
                      fillColor: Colors.blue[50],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller('country'),
              decoration: InputDecoration(
                labelText: 'Country',
                hintText: 'Auto-filled from search',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.flag),
                filled: true,
                fillColor: Colors.blue[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Country is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Note: Latitude and longitude are still tracked internally from address search
            // but hidden from the UI. The coordinates are auto-populated by the
            // AddressAutocompleteField's onAddressSelected callback (lines 56-78)
            // and sent to the API during save (lines 80-127).
            SwitchListTile(
              title: const Text('Set as default address'),
              subtitle: const Text('Use this address by default for deliveries'),
              value: _isDefault,
              onChanged: (value) {
                setState(() {
                  _isDefault = value;
                });
              },
              activeTrackColor: Colors.blue,
            ),
            const SizedBox(height: 24),
            buildLoadingButton(
              onPressed: _saveAddress,
              label: _isEditMode ? 'Update Address' : 'Add Address',
              backgroundColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
