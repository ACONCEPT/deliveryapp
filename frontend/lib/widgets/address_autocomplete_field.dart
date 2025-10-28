import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/nominatim_service.dart';

/// Callback when an address is selected
typedef OnAddressSelected = void Function(AddressSuggestion address);

/// Reusable address autocomplete field using Nominatim
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final OnAddressSelected onAddressSelected;
  final String? countryCode;
  final String? Function(String?)? validator;
  final bool enabled;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.onAddressSelected,
    this.countryCode,
    this.validator,
    this.enabled = true,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final NominatimService _nominatimService = NominatimService();
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return TypeAheadFormField<AddressSuggestion>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: widget.controller,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.controller.clear();
                      },
                    )
                  : null,
        ),
      ),
      validator: widget.validator,
      suggestionsCallback: (pattern) async {
        if (pattern.trim().length < 3) {
          setState(() => _isSearching = false);
          return [];
        }

        setState(() => _isSearching = true);

        try {
          final suggestions = await _nominatimService.searchAddress(
            pattern,
            limit: 5,
            countryCode: widget.countryCode,
          );
          setState(() => _isSearching = false);
          return suggestions;
        } catch (e) {
          setState(() => _isSearching = false);
          return [];
        }
      },
      itemBuilder: (context, AddressSuggestion suggestion) {
        final bool hasHouseNumber = suggestion.houseNumber != null &&
                                    suggestion.houseNumber!.isNotEmpty;

        return ListTile(
          leading: Icon(
            hasHouseNumber ? Icons.home : Icons.place,
            color: hasHouseNumber ? Colors.green : Colors.deepOrange,
          ),
          title: Text(
            suggestion.displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: hasHouseNumber ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (hasHouseNumber)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Text(
                    'Complete Address',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  suggestion.typeDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
      onSuggestionSelected: (AddressSuggestion suggestion) {
        // Use the street field (which has house number + road) instead of full displayName
        // This prevents overwriting a specific address the user typed
        final streetAddress = suggestion.street;
        if (streetAddress.isNotEmpty) {
          widget.controller.text = streetAddress;
        } else {
          // Fallback to display name if street extraction failed
          widget.controller.text = suggestion.displayName;
        }
        widget.onAddressSelected(suggestion);
      },
      noItemsFoundBuilder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            widget.controller.text.trim().length < 3
                ? 'Type at least 3 characters to search...'
                : 'No addresses found. Try a different search.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
      loadingBuilder: (context) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Searching addresses...'),
            ],
          ),
        );
      },
      suggestionsBoxDecoration: SuggestionsBoxDecoration(
        borderRadius: BorderRadius.circular(8),
        elevation: 8,
        constraints: const BoxConstraints(maxHeight: 300),
      ),
      debounceDuration: const Duration(milliseconds: 500),
      hideOnEmpty: true,
      hideOnLoading: false,
      hideOnError: true,
      animationStart: 1.0,
      animationDuration: const Duration(milliseconds: 200),
    );
  }
}
