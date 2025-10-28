package models

import "time"

// ApprovalStatus represents the approval state of an entity
type ApprovalStatus string

const (
	ApprovalStatusPending  ApprovalStatus = "pending"
	ApprovalStatusApproved ApprovalStatus = "approved"
	ApprovalStatusRejected ApprovalStatus = "rejected"
)

// ApprovalHistory tracks approval/rejection events
type ApprovalHistory struct {
	ID         int            `json:"id" db:"id"`
	EntityType string         `json:"entity_type" db:"entity_type"` // "vendor" or "restaurant"
	EntityID   int            `json:"entity_id" db:"entity_id"`
	AdminID    int            `json:"admin_id" db:"admin_id"`
	Action     ApprovalStatus `json:"action" db:"action"`
	Reason     *string        `json:"reason,omitempty" db:"reason"`
	CreatedAt  time.Time      `json:"created_at" db:"created_at"`
}

// VendorWithApproval extends Vendor with approval fields
type VendorWithApproval struct {
	Vendor
	ApprovalStatus    ApprovalStatus `json:"approval_status" db:"approval_status"`
	ApprovedByAdminID *int           `json:"approved_by_admin_id,omitempty" db:"approved_by_admin_id"`
	ApprovedAt        *time.Time     `json:"approved_at,omitempty" db:"approved_at"`
	RejectionReason   *string        `json:"rejection_reason,omitempty" db:"rejection_reason"`
	// Admin info (for display purposes)
	ApprovedByAdminName *string `json:"approved_by_admin_name,omitempty" db:"approved_by_admin_name"`
}

// RestaurantWithApproval extends Restaurant with approval fields
type RestaurantWithApproval struct {
	Restaurant
	ApprovalStatus    ApprovalStatus `json:"approval_status" db:"approval_status"`
	ApprovedByAdminID *int           `json:"approved_by_admin_id,omitempty" db:"approved_by_admin_id"`
	ApprovedAt        *time.Time     `json:"approved_at,omitempty" db:"approved_at"`
	RejectionReason   *string        `json:"rejection_reason,omitempty" db:"rejection_reason"`
	// Admin info (for display purposes)
	ApprovedByAdminName *string `json:"approved_by_admin_name,omitempty" db:"approved_by_admin_name"`
}

// ApprovalActionRequest represents a request to approve/reject an entity
type ApprovalActionRequest struct {
	Reason *string `json:"reason,omitempty"` // Required for rejection, optional for approval
}

// ApprovalDashboardResponse provides summary counts for admin dashboard
type ApprovalDashboardResponse struct {
	PendingVendors     int `json:"pending_vendors"`
	PendingRestaurants int `json:"pending_restaurants"`
	ApprovedVendors    int `json:"approved_vendors"`
	ApprovedRestaurants int `json:"approved_restaurants"`
	RejectedVendors    int `json:"rejected_vendors"`
	RejectedRestaurants int `json:"rejected_restaurants"`
}

// VendorApprovalStatusResponse provides status info for a vendor
type VendorApprovalStatusResponse struct {
	VendorID          int            `json:"vendor_id"`
	ApprovalStatus    ApprovalStatus `json:"approval_status"`
	RejectionReason   *string        `json:"rejection_reason,omitempty"`
	ApprovedAt        *time.Time     `json:"approved_at,omitempty"`
	CanCreateRestaurants bool        `json:"can_create_restaurants"`
}