import 'package:flutter/material.dart';
import '../models/address.dart';
import '../services/address_service.dart';
import '../widgets/common/paginated_list_screen.dart';
import 'address_form_screen.dart';

/// Address list management screen with CRUD operations using the generic
/// PaginatedListScreen widget for consistent UI and behavior.
class AddressListScreen extends StatefulWidget {
  final String token;

  const AddressListScreen({
    super.key,
    required this.token,
  });

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  final AddressService _addressService = AddressService();
  final GlobalKey<PaginatedListScreenState<Address>> _listKey = GlobalKey();

  Future<void> _deleteAddress(int addressId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _addressService.deleteAddress(widget.token, addressId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address deleted successfully')),
      );
      _listKey.currentState?.reload(); // Reload the list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete address: $e')),
      );
    }
  }

  Future<void> _setDefaultAddress(int addressId) async {
    try {
      await _addressService.setDefaultAddress(widget.token, addressId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default address updated')),
      );
      _listKey.currentState?.reload(); // Reload the list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set default: $e')),
      );
    }
  }

  Future<void> _navigateToAddAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressFormScreen(
          token: widget.token,
        ),
      ),
    );

    if (result == true) {
      _listKey.currentState?.reload(); // Reload if address was added
    }
  }

  Future<void> _navigateToEditAddress(Address address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressFormScreen(
          token: widget.token,
          address: address,
        ),
      ),
    );

    if (result == true) {
      _listKey.currentState?.reload(); // Reload if address was updated
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedListScreen<Address>(
      key: _listKey,
      title: 'Manage Addresses',
      appBarColor: Colors.blue,
      loadItems: (token) => _addressService.getAddresses(token!),
      token: widget.token,
      itemBuilder: (address, index) => _AddressCard(
        address: address,
        onEdit: () => _navigateToEditAddress(address),
        onDelete: () => _deleteAddress(address.id!),
        onSetDefault:
            address.isDefault ? null : () => _setDefaultAddress(address.id!),
      ),
      emptyIcon: Icons.location_off,
      emptyTitle: 'No addresses yet',
      emptyMessage: 'Add your first delivery address',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddAddress,
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

/// Individual address card widget
class _AddressCard extends StatelessWidget {
  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.addressLine1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (address.addressLine2 != null &&
                          address.addressLine2!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          address.addressLine2!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${address.city}, ${address.state ?? ''} ${address.postalCode ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        address.country,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onSetDefault != null)
                  TextButton.icon(
                    onPressed: onSetDefault,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Set Default'),
                  ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
