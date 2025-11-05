import 'base/enum_helpers.dart';
import 'base/json_parsers.dart';
import 'base/location_mixin.dart';

/// Approval-related data models for admin approval workflow
///
/// This file defines models for approval status tracking, approval history,
/// and approval-related response structures from the backend API.

/// Approval status enum matching backend ApprovalStatus type
enum ApprovalStatus {
  pending,
  approved,
  rejected;

  /// Creates ApprovalStatus from string value
  static ApprovalStatus fromString(String value) {
    return EnumHelpers.enumFromString(
      ApprovalStatus.values,
      value,
      defaultValue: ApprovalStatus.pending,
    );
  }

  /// Converts ApprovalStatus to string for API calls
  String toApiString() {
    return name;
  }
}

/// Approval history entry tracking approval/rejection events
class ApprovalHistory {
  final int id;
  final String entityType; // "vendor" or "restaurant"
  final int entityId;
  final int adminId;
  final ApprovalStatus action;
  final String? reason;
  final DateTime createdAt;

  ApprovalHistory({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.adminId,
    required this.action,
    this.reason,
    required this.createdAt,
  });

  /// Creates ApprovalHistory from JSON response
  factory ApprovalHistory.fromJson(Map<String, dynamic> json) {
    return ApprovalHistory(
      id: JsonParsers.parseInt(json['id']) ?? 0,
      entityType: json['entity_type'] as String? ?? '',
      entityId: JsonParsers.parseInt(json['entity_id']) ?? 0,
      adminId: JsonParsers.parseInt(json['admin_id']) ?? 0,
      action: ApprovalStatus.fromString(json['action'] as String? ?? 'pending'),
      reason: json['reason'] as String?,
      createdAt: JsonParsers.parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  /// Converts ApprovalHistory to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'admin_id': adminId,
      'action': action.toApiString(),
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Dashboard summary statistics for admin approval overview
class ApprovalDashboardStats {
  final int pendingVendors;
  final int pendingRestaurants;
  final int pendingDrivers;
  final int approvedVendors;
  final int approvedRestaurants;
  final int approvedDrivers;
  final int rejectedVendors;
  final int rejectedRestaurants;
  final int rejectedDrivers;

  ApprovalDashboardStats({
    required this.pendingVendors,
    required this.pendingRestaurants,
    required this.pendingDrivers,
    required this.approvedVendors,
    required this.approvedRestaurants,
    required this.approvedDrivers,
    required this.rejectedVendors,
    required this.rejectedRestaurants,
    required this.rejectedDrivers,
  });

  /// Creates ApprovalDashboardStats from JSON response
  factory ApprovalDashboardStats.fromJson(Map<String, dynamic> json) {
    return ApprovalDashboardStats(
      pendingVendors: (json['pending_vendors'] as int?) ?? 0,
      pendingRestaurants: (json['pending_restaurants'] as int?) ?? 0,
      pendingDrivers: (json['pending_drivers'] as int?) ?? 0,
      approvedVendors: (json['approved_vendors'] as int?) ?? 0,
      approvedRestaurants: (json['approved_restaurants'] as int?) ?? 0,
      approvedDrivers: (json['approved_drivers'] as int?) ?? 0,
      rejectedVendors: (json['rejected_vendors'] as int?) ?? 0,
      rejectedRestaurants: (json['rejected_restaurants'] as int?) ?? 0,
      rejectedDrivers: (json['rejected_drivers'] as int?) ?? 0,
    );
  }

  /// Total pending items requiring admin action
  int get totalPending => pendingVendors + pendingRestaurants + pendingDrivers;

  /// Total approved items
  int get totalApproved => approvedVendors + approvedRestaurants + approvedDrivers;

  /// Total rejected items
  int get totalRejected => rejectedVendors + rejectedRestaurants + rejectedDrivers;
}

/// Vendor with approval status information
class VendorWithApproval with LocationFormatterMixin {
  final int id;
  final int userId;
  final String businessName;
  final String? phone;
  @override
  final String? city;
  @override
  final String? state;
  final double rating;
  final ApprovalStatus approvalStatus;
  final int? approvedByAdminId;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? approvedByAdminName;
  final DateTime createdAt;

  VendorWithApproval({
    required this.id,
    required this.userId,
    required this.businessName,
    this.phone,
    this.city,
    this.state,
    required this.rating,
    required this.approvalStatus,
    this.approvedByAdminId,
    this.approvedAt,
    this.rejectionReason,
    this.approvedByAdminName,
    required this.createdAt,
  });

  /// Creates VendorWithApproval from JSON response
  factory VendorWithApproval.fromJson(Map<String, dynamic> json) {
    return VendorWithApproval(
      id: JsonParsers.parseInt(json['id']) ?? 0,
      userId: JsonParsers.parseInt(json['user_id']) ?? 0,
      businessName: json['business_name'] as String? ?? '',
      phone: json['phone'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      rating: JsonParsers.parseDouble(json['rating']) ?? 0.0,
      approvalStatus: ApprovalStatus.fromString(json['approval_status'] as String? ?? 'pending'),
      approvedByAdminId: JsonParsers.parseInt(json['approved_by_admin_id']),
      approvedAt: JsonParsers.parseDateTime(json['approved_at']),
      rejectionReason: json['rejection_reason'] as String?,
      approvedByAdminName: json['approved_by_admin_name'] as String?,
      createdAt: JsonParsers.parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  /// Location display string
  String get location => formatLocation();
}

/// Driver with approval status information
class DriverWithApproval with LocationFormatterMixin {
  final int id;
  final int userId;
  final String fullName;
  final String? phone;
  final String? vehicleType;
  final String? vehiclePlate;
  final String? licenseNumber;
  @override
  final String? city;
  @override
  final String? state;
  final double rating;
  final bool isAvailable;
  final ApprovalStatus approvalStatus;
  final int? approvedByAdminId;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? approvedByAdminName;
  final DateTime createdAt;

  DriverWithApproval({
    required this.id,
    required this.userId,
    required this.fullName,
    this.phone,
    this.vehicleType,
    this.vehiclePlate,
    this.licenseNumber,
    this.city,
    this.state,
    required this.rating,
    required this.isAvailable,
    required this.approvalStatus,
    this.approvedByAdminId,
    this.approvedAt,
    this.rejectionReason,
    this.approvedByAdminName,
    required this.createdAt,
  });

  /// Creates DriverWithApproval from JSON response
  factory DriverWithApproval.fromJson(Map<String, dynamic> json) {
    return DriverWithApproval(
      id: JsonParsers.parseInt(json['id']) ?? 0,
      userId: JsonParsers.parseInt(json['user_id']) ?? 0,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      licenseNumber: json['license_number'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      rating: JsonParsers.parseDouble(json['rating']) ?? 0.0,
      isAvailable: json['is_available'] as bool? ?? false,
      approvalStatus: ApprovalStatus.fromString(json['approval_status'] as String? ?? 'pending'),
      approvedByAdminId: JsonParsers.parseInt(json['approved_by_admin_id']),
      approvedAt: JsonParsers.parseDateTime(json['approved_at']),
      rejectionReason: json['rejection_reason'] as String?,
      approvedByAdminName: json['approved_by_admin_name'] as String?,
      createdAt: JsonParsers.parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  /// Location display string
  String get location => formatLocation();

  /// Vehicle display string
  String get vehicleInfo {
    final parts = <String>[];
    if (vehicleType != null && vehicleType!.isNotEmpty) parts.add(vehicleType!);
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) parts.add(vehiclePlate!);
    return parts.isEmpty ? 'Vehicle info not specified' : parts.join(' - ');
  }

  /// Availability display string
  String get availabilityStatus => isAvailable ? 'Available' : 'Unavailable';
}

/// Restaurant with approval status information
class RestaurantWithApproval with LocationFormatterMixin {
  final int id;
  final String name;
  final String? cuisine;
  @override
  final String? address;
  @override
  final String? city;
  @override
  final String? state;
  final String? phone;
  final double rating;
  final bool isActive;
  final ApprovalStatus approvalStatus;
  final int? approvedByAdminId;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? approvedByAdminName;
  final DateTime createdAt;

  RestaurantWithApproval({
    required this.id,
    required this.name,
    this.cuisine,
    this.address,
    this.city,
    this.state,
    this.phone,
    required this.rating,
    required this.isActive,
    required this.approvalStatus,
    this.approvedByAdminId,
    this.approvedAt,
    this.rejectionReason,
    this.approvedByAdminName,
    required this.createdAt,
  });

  /// Creates RestaurantWithApproval from JSON response
  factory RestaurantWithApproval.fromJson(Map<String, dynamic> json) {
    return RestaurantWithApproval(
      id: JsonParsers.parseInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      cuisine: json['cuisine'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      phone: json['phone'] as String?,
      rating: JsonParsers.parseDouble(json['rating']) ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
      approvalStatus: ApprovalStatus.fromString(json['approval_status'] as String? ?? 'pending'),
      approvedByAdminId: JsonParsers.parseInt(json['approved_by_admin_id']),
      approvedAt: JsonParsers.parseDateTime(json['approved_at']),
      rejectionReason: json['rejection_reason'] as String?,
      approvedByAdminName: json['approved_by_admin_name'] as String?,
      createdAt: JsonParsers.parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  /// Location display string
  String get location => formatLocation();
}

/// Request body for approval/rejection actions
class ApprovalActionRequest {
  final String? reason;

  ApprovalActionRequest({this.reason});

  /// Converts to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      if (reason != null) 'reason': reason,
    };
  }
}
