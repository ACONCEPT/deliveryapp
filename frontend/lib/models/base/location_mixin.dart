/// Mixin providing location formatting utilities to reduce duplication.
/// Classes using this mixin can override the location getters they have.
mixin LocationFormatterMixin {
  String? get city => null;
  String? get state => null;
  String? get address => null;
  String? get addressLine1 => null;
  String? get addressLine2 => null;
  String? get zipCode => null;

  /// Formats city and state into a readable location string.
  /// Returns [defaultText] if both city and state are empty.
  ///
  /// Example: "San Francisco, CA"
  String formatLocation({String defaultText = 'Location not specified'}) {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    return parts.isEmpty ? defaultText : parts.join(', ');
  }

  /// Formats the complete address including street, city, state, and zip.
  /// Returns [defaultText] if all fields are empty.
  ///
  /// Example: "123 Main St, San Francisco, CA 94102"
  String formatFullAddress({String defaultText = 'Address not specified'}) {
    final parts = <String>[];

    // Add street address
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (addressLine1 != null && addressLine1!.isNotEmpty) parts.add(addressLine1!);
    if (addressLine2 != null && addressLine2!.isNotEmpty) parts.add(addressLine2!);

    // Add city and state
    final cityState = <String>[];
    if (city != null && city!.isNotEmpty) cityState.add(city!);
    if (state != null && state!.isNotEmpty) cityState.add(state!);
    if (cityState.isNotEmpty) {
      parts.add(cityState.join(', '));
    }

    // Add zip code
    if (zipCode != null && zipCode!.isNotEmpty) parts.add(zipCode!);

    return parts.isEmpty ? defaultText : parts.join(', ');
  }

  /// Formats address in multi-line format for display.
  /// Returns [defaultText] if all fields are empty.
  ///
  /// Example:
  /// ```
  /// 123 Main St
  /// Apt 4B
  /// San Francisco, CA 94102
  /// ```
  String formatMultilineAddress({String defaultText = 'Address not specified'}) {
    final lines = <String>[];

    // Add street address lines
    if (address != null && address!.isNotEmpty) lines.add(address!);
    if (addressLine1 != null && addressLine1!.isNotEmpty) lines.add(addressLine1!);
    if (addressLine2 != null && addressLine2!.isNotEmpty) lines.add(addressLine2!);

    // Add city, state, zip on one line
    final cityStateLine = <String>[];
    if (city != null && city!.isNotEmpty) cityStateLine.add(city!);
    if (state != null && state!.isNotEmpty) cityStateLine.add(state!);
    if (zipCode != null && zipCode!.isNotEmpty) {
      if (cityStateLine.isNotEmpty) {
        cityStateLine.add(zipCode!);
      } else {
        lines.add(zipCode!);
      }
    }
    if (cityStateLine.isNotEmpty) {
      lines.add(cityStateLine.join(', '));
    }

    return lines.isEmpty ? defaultText : lines.join('\n');
  }

  /// Returns true if the location has at least city or state defined.
  bool get hasLocation =>
      (city != null && city!.isNotEmpty) ||
      (state != null && state!.isNotEmpty);

  /// Returns true if the address has at least one address field defined.
  bool get hasAddress =>
      (address != null && address!.isNotEmpty) ||
      (addressLine1 != null && addressLine1!.isNotEmpty) ||
      (addressLine2 != null && addressLine2!.isNotEmpty) ||
      hasLocation;
}
