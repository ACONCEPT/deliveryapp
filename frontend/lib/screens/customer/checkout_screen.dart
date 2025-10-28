import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/address_service.dart';
import '../../services/order_service.dart';
import '../../models/address.dart';
import '../../models/order.dart';
import '../../widgets/cart/cart_item_tile.dart';
import '../../widgets/cart/cart_summary.dart';
import '../../config/dashboard_constants.dart';
import '../../utils/jwt_decoder.dart';
import '../address_list_screen.dart';
import 'order_confirmation_screen.dart';

/// Screen for reviewing order and completing checkout
/// Allows address selection and order placement
class CheckoutScreen extends StatefulWidget {
  final String token;

  const CheckoutScreen({
    super.key,
    required this.token,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AddressService _addressService = AddressService();
  final OrderService _orderService = OrderService();

  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _isLoadingAddresses = true;
  bool _isPlacingOrder = false;
  String? _errorMessage;
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
      _errorMessage = null;
    });

    try {
      final addresses = await _addressService.getAddresses(widget.token);
      setState(() {
        _addresses = addresses;
        // Auto-select default address if available
        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => addresses.first,
          );
        } else {
          _selectedAddress = null;
        }
        _isLoadingAddresses = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingAddresses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    if (!cartProvider.hasItems && !_isPlacingOrder) {
      // Cart was cleared, go back (but not during order placement)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery address section
            _buildDeliveryAddressSection(),
            const SizedBox(height: DashboardConstants.sectionSpacing),

            // Order items section
            _buildOrderItemsSection(cartProvider),
            const SizedBox(height: DashboardConstants.sectionSpacing),

            // Special instructions
            _buildSpecialInstructions(),
            const SizedBox(height: DashboardConstants.sectionSpacing),

            // Order summary
            CartSummary(
              subtotal: cartProvider.subtotal,
              taxAmount: cartProvider.taxAmount,
              deliveryFee: cartProvider.deliveryFee,
              totalAmount: cartProvider.totalAmount,
            ),
            const SizedBox(height: DashboardConstants.sectionSpacing),

            // Place order button
            _buildPlaceOrderButton(cartProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressSection() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _navigateToAddressSelection,
                  icon: const Icon(Icons.edit),
                  label: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoadingAddresses)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              _buildAddressError()
            else if (_selectedAddress == null || _addresses.isEmpty)
              _buildNoAddress()
            else
              _buildSelectedAddress(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressError() {
    return Column(
      children: [
        Text(
          'Failed to load addresses',
          style: TextStyle(color: Colors.red.shade700),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _loadAddresses,
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildNoAddress() {
    return Column(
      children: [
        const Text(
          'No delivery address selected',
          style: TextStyle(color: Colors.red),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _navigateToAddressSelection,
          icon: const Icon(Icons.add),
          label: const Text('Add Address'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedAddress() {
    return Container(
      padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(
          DashboardConstants.cardBorderRadiusExtraSmall,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedAddress!.formattedAddress,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection(CartProvider cartProvider) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${cartProvider.itemCount} ${cartProvider.itemCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of items (read-only, no controls)
            ...cartProvider.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CartItemTile(
                  item: item,
                  showControls: false,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialInstructions() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Special Instructions (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText: 'e.g., Ring doorbell, leave at door...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    DashboardConstants.cardBorderRadiusExtraSmall,
                  ),
                ),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceOrderButton(CartProvider cartProvider) {
    final canPlaceOrder = _selectedAddress != null &&
        _selectedAddress!.id != null &&
        !_isPlacingOrder;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canPlaceOrder ? () => _placeOrder(cartProvider) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isPlacingOrder
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text('Place Order - \$${cartProvider.totalAmount.toStringAsFixed(2)}'),
      ),
    );
  }

  void _navigateToAddressSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressListScreen(token: widget.token),
      ),
    );

    // Reload addresses after returning
    if (result != null || mounted) {
      await _loadAddresses();
    }
  }

  Future<void> _placeOrder(CartProvider cartProvider) async {
    // Validate address is selected and has an ID
    if (_selectedAddress == null || _selectedAddress!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address with a valid ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate restaurant ID is not null
    if (cartProvider.restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant ID is missing. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      // Extract customer ID from JWT token
      final customerId = JwtDecoder.getCustomerIdFromToken(widget.token);

      if (customerId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to identify customer from token'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isPlacingOrder = false;
        });
        return;
      }

      // Debug logging
      print('Creating order with:');
      print('- customerId: $customerId (extracted from JWT)');
      print('- restaurantId: ${cartProvider.restaurantId}');
      print('- deliveryAddressId: ${_selectedAddress!.id}');
      print('- Number of items: ${cartProvider.items.length}');

      // Convert cart items to order items
      // Note: Backend expects menu_item_name, menu_item_description, price, quantity, and customizations
      final orderItems = cartProvider.items.map((cartItem) {
        // Build customizations map from selected customizations
        Map<String, dynamic>? customizations;
        if (cartItem.selectedCustomizations.isNotEmpty) {
          customizations = {};
          for (var customization in cartItem.selectedCustomizations) {
            // Store customization by its name or ID
            customizations[customization.name] = {
              'name': customization.name,
              'price_modifier': customization.priceModifier,
            };
          }
        }

        return OrderItem(
          menuItemName: cartItem.menuItem.name,
          menuItemDescription: cartItem.menuItem.description,
          quantity: cartItem.quantity,
          basePrice: cartItem.menuItem.price,
          totalPrice: cartItem.totalPrice,
          customizations: customizations,
          specialInstructions: cartItem.specialInstructions,
        );
      }).toList();

      // Create order
      final order = Order(
        customerId: customerId,
        restaurantId: cartProvider.restaurantId!,
        restaurantName: cartProvider.restaurantName,
        deliveryAddressId: _selectedAddress!.id,
        status: OrderStatus.pending,
        subtotal: cartProvider.subtotal,
        taxAmount: cartProvider.taxAmount,
        deliveryFee: cartProvider.deliveryFee,
        totalAmount: cartProvider.totalAmount,
        items: orderItems,
        specialInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      );

      // Submit order (auth header added automatically by HttpClientService)
      print('🚀 Submitting order to API...');
      final createdOrder = await _orderService.createOrder(order);
      print('✅ Order created successfully! ID: ${createdOrder.id}');

      // Navigate to order confirmation screen FIRST (before clearing cart)
      print('📍 Navigating to confirmation screen...');
      if (mounted) {
        // Navigate first, then clear cart in the new screen's callback
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(
              order: createdOrder,
              token: widget.token,
            ),
          ),
        );
        print('✅ Navigation completed');

        // Clear cart after navigation completes
        print('🗑️ Clearing cart...');
        cartProvider.clearCart();
      } else {
        print('❌ Widget not mounted, cannot navigate');
      }
      // Don't reset _isPlacingOrder here - the screen is being replaced
    } catch (e, stackTrace) {
      print('❌ Error placing order: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
