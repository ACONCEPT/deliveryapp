import 'package:flutter/material.dart';
import '../models/address.dart';
import '../services/address_service.dart';
import '../mixins/form_state_mixin.dart';

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

    _isDefault = widget.address?.isDefault ?? false;
  }

  Future<void> _saveAddress() async {
    await executeSave(
      operation: () async {
        final address = Address(
          id: widget.address?.id,
          customerId: widget.address?.customerId,
          addressLine1: getText('addressLine1'),
          addressLine2: getTextOrNull('addressLine2'),
          city: getText('city'),
          state: getTextOrNull('state'),
          postalCode: getTextOrNull('postalCode'),
          country: getText('country'),
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
            TextFormField(
              controller: controller('addressLine1'),
              decoration: const InputDecoration(
                labelText: 'Address Line 1',
                hintText: 'Street address, P.O. box',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: controller('city'),
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
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
                    decoration: const InputDecoration(
                      labelText: 'State/Province',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.map),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: controller('postalCode'),
                    decoration: const InputDecoration(
                      labelText: 'Postal Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_post_office),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller('country'),
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Country is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
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
