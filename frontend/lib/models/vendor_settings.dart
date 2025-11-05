/// DaySchedule represents operating hours for a single day
class DaySchedule {
  final String open; // "HH:MM" format (24-hour)
  final String close; // "HH:MM" format (24-hour)
  final bool closed; // If true, open/close times are ignored

  const DaySchedule({
    required this.open,
    required this.close,
    this.closed = false,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      open: json['open'] as String? ?? '09:00',
      close: json['close'] as String? ?? '21:00',
      closed: json['closed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'open': open,
      'close': close,
      'closed': closed,
    };
  }

  DaySchedule copyWith({
    String? open,
    String? close,
    bool? closed,
  }) {
    return DaySchedule(
      open: open ?? this.open,
      close: close ?? this.close,
      closed: closed ?? this.closed,
    );
  }

  // Create a default "closed" schedule
  factory DaySchedule.closed() {
    return const DaySchedule(
      open: '09:00',
      close: '21:00',
      closed: true,
    );
  }

  // Create a default "open" schedule
  factory DaySchedule.open() {
    return const DaySchedule(
      open: '09:00',
      close: '21:00',
      closed: false,
    );
  }
}

/// HoursOfOperation represents weekly operating hours
class HoursOfOperation {
  final DaySchedule monday;
  final DaySchedule tuesday;
  final DaySchedule wednesday;
  final DaySchedule thursday;
  final DaySchedule friday;
  final DaySchedule saturday;
  final DaySchedule sunday;

  const HoursOfOperation({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
  });

  factory HoursOfOperation.fromJson(Map<String, dynamic> json) {
    return HoursOfOperation(
      monday: DaySchedule.fromJson(json['monday'] as Map<String, dynamic>? ?? {}),
      tuesday: DaySchedule.fromJson(json['tuesday'] as Map<String, dynamic>? ?? {}),
      wednesday: DaySchedule.fromJson(json['wednesday'] as Map<String, dynamic>? ?? {}),
      thursday: DaySchedule.fromJson(json['thursday'] as Map<String, dynamic>? ?? {}),
      friday: DaySchedule.fromJson(json['friday'] as Map<String, dynamic>? ?? {}),
      saturday: DaySchedule.fromJson(json['saturday'] as Map<String, dynamic>? ?? {}),
      sunday: DaySchedule.fromJson(json['sunday'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monday': monday.toJson(),
      'tuesday': tuesday.toJson(),
      'wednesday': wednesday.toJson(),
      'thursday': thursday.toJson(),
      'friday': friday.toJson(),
      'saturday': saturday.toJson(),
      'sunday': sunday.toJson(),
    };
  }

  // Create default hours (Mon-Sun 9:00-21:00)
  factory HoursOfOperation.defaultHours() {
    return HoursOfOperation(
      monday: DaySchedule.open(),
      tuesday: DaySchedule.open(),
      wednesday: DaySchedule.open(),
      thursday: DaySchedule.open(),
      friday: DaySchedule.open(),
      saturday: DaySchedule.open(),
      sunday: DaySchedule.open(),
    );
  }

  HoursOfOperation copyWith({
    DaySchedule? monday,
    DaySchedule? tuesday,
    DaySchedule? wednesday,
    DaySchedule? thursday,
    DaySchedule? friday,
    DaySchedule? saturday,
    DaySchedule? sunday,
  }) {
    return HoursOfOperation(
      monday: monday ?? this.monday,
      tuesday: tuesday ?? this.tuesday,
      wednesday: wednesday ?? this.wednesday,
      thursday: thursday ?? this.thursday,
      friday: friday ?? this.friday,
      saturday: saturday ?? this.saturday,
      sunday: sunday ?? this.sunday,
    );
  }

  // Get a day's schedule by name
  DaySchedule getDaySchedule(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday':
        return monday;
      case 'tuesday':
        return tuesday;
      case 'wednesday':
        return wednesday;
      case 'thursday':
        return thursday;
      case 'friday':
        return friday;
      case 'saturday':
        return saturday;
      case 'sunday':
        return sunday;
      default:
        return DaySchedule.open();
    }
  }
}

/// VendorSettings represents vendor restaurant settings for a specific restaurant
class VendorSettings {
  final int restaurantId;
  final String restaurantName;
  final int averagePrepTimeMinutes;
  final HoursOfOperation? hoursOfOperation;

  const VendorSettings({
    required this.restaurantId,
    required this.restaurantName,
    required this.averagePrepTimeMinutes,
    this.hoursOfOperation,
  });

  factory VendorSettings.fromJson(Map<String, dynamic> json) {
    return VendorSettings(
      restaurantId: json['restaurant_id'] as int,
      restaurantName: json['restaurant_name'] as String,
      averagePrepTimeMinutes: json['average_prep_time_minutes'] as int,
      hoursOfOperation: json['hours_of_operation'] != null
          ? HoursOfOperation.fromJson(json['hours_of_operation'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'average_prep_time_minutes': averagePrepTimeMinutes,
      if (hoursOfOperation != null) 'hours_of_operation': hoursOfOperation!.toJson(),
    };
  }

  VendorSettings copyWith({
    int? restaurantId,
    String? restaurantName,
    int? averagePrepTimeMinutes,
    HoursOfOperation? hoursOfOperation,
  }) {
    return VendorSettings(
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      averagePrepTimeMinutes: averagePrepTimeMinutes ?? this.averagePrepTimeMinutes,
      hoursOfOperation: hoursOfOperation ?? this.hoursOfOperation,
    );
  }
}

/// UpdateVendorSettingsRequest represents the request to update vendor restaurant settings
class UpdateVendorSettingsRequest {
  final int? averagePrepTimeMinutes;
  final HoursOfOperation? hoursOfOperation;

  const UpdateVendorSettingsRequest({
    this.averagePrepTimeMinutes,
    this.hoursOfOperation,
  });

  Map<String, dynamic> toJson() {
    return {
      if (averagePrepTimeMinutes != null)
        'average_prep_time_minutes': averagePrepTimeMinutes,
      if (hoursOfOperation != null)
        'hours_of_operation': hoursOfOperation!.toJson(),
    };
  }

  // Validation helper
  bool get hasUpdates =>
      averagePrepTimeMinutes != null || hoursOfOperation != null;
}
