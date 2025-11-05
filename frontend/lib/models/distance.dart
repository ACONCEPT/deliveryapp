/// Distance calculation data models
/// Represents distance and duration estimates from the backend API
library;

/// Distance information in multiple units
class DistanceInfo {
  final int meters;
  final double miles;
  final double kilometers;

  DistanceInfo({
    required this.meters,
    required this.miles,
    required this.kilometers,
  });

  factory DistanceInfo.fromJson(Map<String, dynamic> json) {
    return DistanceInfo(
      meters: json['meters'] as int? ?? 0,
      miles: (json['miles'] as num?)?.toDouble() ?? 0.0,
      kilometers: (json['kilometers'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meters': meters,
      'miles': miles,
      'kilometers': kilometers,
    };
  }
}

/// Duration information in multiple formats
class DurationInfo {
  final int seconds;
  final int minutes;
  final String text;

  DurationInfo({
    required this.seconds,
    required this.minutes,
    required this.text,
  });

  factory DurationInfo.fromJson(Map<String, dynamic> json) {
    return DurationInfo(
      seconds: json['seconds'] as int? ?? 0,
      minutes: json['minutes'] as int? ?? 0,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seconds': seconds,
      'minutes': minutes,
      'text': text,
    };
  }
}

/// Complete distance estimate response
class DistanceEstimate {
  final DistanceInfo distance;
  final DurationInfo duration;
  final DateTime calculatedAt;

  DistanceEstimate({
    required this.distance,
    required this.duration,
    required this.calculatedAt,
  });

  factory DistanceEstimate.fromJson(Map<String, dynamic> json) {
    return DistanceEstimate(
      distance: DistanceInfo.fromJson(json['distance'] as Map<String, dynamic>),
      duration: DurationInfo.fromJson(json['duration'] as Map<String, dynamic>),
      calculatedAt: DateTime.parse(json['calculated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance': distance.toJson(),
      'duration': duration.toJson(),
      'calculated_at': calculatedAt.toIso8601String(),
    };
  }

  /// Calculate estimated delivery time based on travel duration + preparation time
  /// Default preparation time is 20 minutes
  DateTime estimatedDeliveryTime({int preparationMinutes = 20}) {
    final totalMinutes = preparationMinutes + duration.minutes;
    return DateTime.now().add(Duration(minutes: totalMinutes));
  }

  /// Get formatted delivery time range (e.g., "30-40 minutes")
  String formattedDeliveryTimeRange({int preparationMinutes = 20, int bufferMinutes = 10}) {
    final minTime = preparationMinutes + duration.minutes;
    final maxTime = minTime + bufferMinutes;
    return '$minTime-$maxTime minutes';
  }
}
