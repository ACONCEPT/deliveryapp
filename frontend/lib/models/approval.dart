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
    switch (value.toLowerCase()) {
      case 'pending':
        return ApprovalStatus.pending;
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      default:
        throw ArgumentError('Invalid approval status: $value');
    }
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
      id: (json['id'] as int?) ?? 0,
      entityType: json['entity_type'] as String? ?? '',
      entityId: (json['entity_id'] as int?) ?? 0,
      adminId: (json['admin_id'] as int?) ?? 0,
      action: ApprovalStatus.fromString(json['action'] as String? ?? 'pending'),
      reason: json['reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
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
  final int approvedVendors;
  final int approvedRestaurants;
  final int rejectedVendors;
  final int rejectedRestaurants;

  ApprovalDashboardStats({
    required this.pendingVendors,
    required this.pendingRestaurants,
    required this.approvedVendors,
    required this.approvedRestaurants,
    required this.rejectedVendors,
    required this.rejectedRestaurants,
  });

  /// Creates ApprovalDashboardStats from JSON response
  factory ApprovalDashboardStats.fromJson(Map<String, dynamic> json) {
    return ApprovalDashboardStats(
      pendingVendors: (json['pending_vendors'] as int?) ?? 0,
      pendingRestaurants: (json['pending_restaurants'] as int?) ?? 0,
      approvedVendors: (json['approved_vendors'] as int?) ?? 0,
      approvedRestaurants: (json['approved_restaurants'] as int?) ?? 0,
      rejectedVendors: (json['rejected_vendors'] as int?) ?? 0,
      rejectedRestaurants: (json['rejected_restaurants'] as int?) ?? 0,
    );
  }

  /// Total pending items requiring admin action
  int get totalPending => pendingVendors + pendingRestaurants;

  /// Total approved items
  int get totalApproved => approvedVendors + approvedRestaurants;

  /// Total rejected items
  int get totalRejected => rejectedVendors + rejectedRestaurants;
}

/// Vendor with approval status information
class VendorWithApproval {
  final int id;
  final int userId;
  final String businessName;
  final String? phone;
  final String? city;
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
      id: (json['id'] as int?) ?? 0,
      userId: (json['user_id'] as int?) ?? 0,
      businessName: json['business_name'] as String? ?? '',
      phone: json['phone'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      approvalStatus: ApprovalStatus.fromString(json['approval_status'] as String? ?? 'pending'),
      approvedByAdminId: json['approved_by_admin_id'] as int?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      approvedByAdminName: json['approved_by_admin_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Location display string
  String get location {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    return parts.isEmpty ? 'Location not specified' : parts.join(', ');
  }
}

/// Restaurant with approval status information
class RestaurantWithApproval {
  final int id;
  final String name;
  final String? cuisine;
  final String? address;
  final String? city;
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
      id: (json['id'] as int?) ?? 0,
      name: json['name'] as String? ?? '',
      cuisine: json['cuisine'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      phone: json['phone'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
      approvalStatus: ApprovalStatus.fromString(json['approval_status'] as String? ?? 'pending'),
      approvedByAdminId: json['approved_by_admin_id'] as int?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      approvedByAdminName: json['approved_by_admin_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Location display string
  String get location {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    return parts.isEmpty ? 'Location not specified' : parts.join(', ');
  }
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
