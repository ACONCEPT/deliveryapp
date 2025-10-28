import 'package:flutter/material.dart';
import '../../models/menu.dart';
import '../../config/dashboard_constants.dart';

/// Dialog for customizing menu item before adding to cart
class ItemCustomizationDialog extends StatefulWidget {
  final MenuItem menuItem;

  const ItemCustomizationDialog({
    super.key,
    required this.menuItem,
  });

  @override
  State<ItemCustomizationDialog> createState() =>
      _ItemCustomizationDialogState();
}

class _ItemCustomizationDialogState extends State<ItemCustomizationDialog> {
  int _quantity = 1;
  final List<CustomizationChoice> _selectedChoices = [];
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  double get _calculatedPrice {
    double basePrice = widget.menuItem.price;
    double customizationsTotal = _selectedChoices.fold(
      0.0,
      (sum, choice) => sum + choice.priceModifier,
    );
    return (basePrice + customizationsTotal) * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with image
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DashboardConstants.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item name and price
                    Text(
                      widget.menuItem.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Description
                    if (widget.menuItem.description.isNotEmpty)
                      Text(
                        widget.menuItem.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Base price
                    Text(
                      'Base Price: \$${widget.menuItem.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Customization options
                    if (widget.menuItem.customizationOptions != null &&
                        widget.menuItem.customizationOptions!.isNotEmpty)
                      _buildCustomizationOptions(),

                    // Special instructions
                    _buildSpecialInstructions(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Footer with quantity and add to cart
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Image
        SizedBox(
          height: 200,
          width: double.infinity,
          child: widget.menuItem.imageUrl != null
              ? Image.network(
                  widget.menuItem.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildImagePlaceholder(),
                )
              : _buildImagePlaceholder(),
        ),

        // Close button
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.restaurant_menu,
        size: 80,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildCustomizationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customize Your Order',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.menuItem.customizationOptions!
            .map((option) => _buildCustomizationOption(option)),
      ],
    );
  }

  Widget _buildCustomizationOption(CustomizationOption option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Option name and requirement
        Row(
          children: [
            Text(
              option.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (option.required)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Render based on type
        if (option.type == 'single_choice' || option.type == 'multiple_choice')
          ...option.choices!
              .map((choice) => _buildChoiceOption(choice, option)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildChoiceOption(
      CustomizationChoice choice, CustomizationOption option) {
    final isSelected = _selectedChoices.contains(choice);

    return CheckboxListTile(
      title: Text(choice.name),
      subtitle: choice.priceModifier != 0
          ? Text(
              choice.priceModifier > 0
                  ? '+\$${choice.priceModifier.toStringAsFixed(2)}'
                  : '-\$${(-choice.priceModifier).toStringAsFixed(2)}',
              style: TextStyle(
                color: choice.priceModifier > 0
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            )
          : null,
      value: isSelected,
      onChanged: (bool? value) {
        setState(() {
          if (value == true) {
            // If single-selection option, remove other selections
            if (option.type == 'single_choice') {
              _selectedChoices.removeWhere(
                (c) => option.choices!.contains(c),
              );
            }
            _selectedChoices.add(choice);
          } else {
            _selectedChoices.remove(choice);
          }
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSpecialInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Special Instructions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionsController,
          decoration: InputDecoration(
            hintText: 'e.g., No onions, extra sauce...',
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
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DashboardConstants.cardPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // Quantity controls
          _buildQuantityControls(),
          const SizedBox(width: 16),

          // Add to cart button
          Expanded(
            child: ElevatedButton(
              onPressed: _handleAddToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Add to Cart - \$${_calculatedPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityControls() {
    return Row(
      children: [
        // Decrement
        IconButton(
          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: Colors.orange,
        ),

        // Quantity
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_quantity',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Increment
        IconButton(
          onPressed: () => setState(() => _quantity++),
          icon: const Icon(Icons.add_circle_outline),
          color: Colors.orange,
        ),
      ],
    );
  }

  void _handleAddToCart() {
    // Validate required options
    if (widget.menuItem.customizationOptions != null) {
      for (final option in widget.menuItem.customizationOptions!) {
        if (option.required) {
          final selectedInOption = _selectedChoices
              .where((c) => option.choices != null && option.choices!.contains(c))
              .length;
          if (selectedInOption == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please select ${option.name}'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
    }

    // Return customization data
    Navigator.of(context).pop({
      'quantity': _quantity,
      'customizations': _selectedChoices,
      'instructions': _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
    });
  }
}
