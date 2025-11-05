package base

import "time"

// ApprovalStatus represents the approval state of an entity
type ApprovalStatus string

const (
	ApprovalStatusPending  ApprovalStatus = "pending"
	ApprovalStatusApproved ApprovalStatus = "approved"
	ApprovalStatusRejected ApprovalStatus = "rejected"
)

// ApprovableEntity provides approval workflow fields that can be embedded
// in any model requiring approval (vendors, drivers, restaurants, etc.)
type ApprovableEntity struct {
	ApprovalStatus    ApprovalStatus `json:"approval_status" db:"approval_status"`
	ApprovedByAdminID *int           `json:"approved_by_admin_id,omitempty" db:"approved_by_admin_id"`
	ApprovedAt        *time.Time     `json:"approved_at,omitempty" db:"approved_at"`
	RejectionReason   *string        `json:"rejection_reason,omitempty" db:"rejection_reason"`
}

// IsApproved returns true if the entity has been approved
func (a *ApprovableEntity) IsApproved() bool {
	return a.ApprovalStatus == ApprovalStatusApproved
}

// IsPending returns true if the entity is pending approval
func (a *ApprovableEntity) IsPending() bool {
	return a.ApprovalStatus == ApprovalStatusPending
}

// IsRejected returns true if the entity has been rejected
func (a *ApprovableEntity) IsRejected() bool {
	return a.ApprovalStatus == ApprovalStatusRejected
}

// CanTransitionTo checks if the entity can transition to the target status
func (a *ApprovableEntity) CanTransitionTo(target ApprovalStatus) bool {
	switch a.ApprovalStatus {
	case ApprovalStatusPending:
		// Pending can transition to approved or rejected
		return target == ApprovalStatusApproved || target == ApprovalStatusRejected
	case ApprovalStatusRejected:
		// Rejected can be resubmitted to pending
		return target == ApprovalStatusPending
	case ApprovalStatusApproved:
		// Approved can be revoked to pending (for re-review)
		return target == ApprovalStatusPending
	default:
		return false
	}
}

// Approve marks the entity as approved by the specified admin
func (a *ApprovableEntity) Approve(adminID int) {
	a.ApprovalStatus = ApprovalStatusApproved
	a.ApprovedByAdminID = &adminID
	now := time.Now()
	a.ApprovedAt = &now
	a.RejectionReason = nil
}

// Reject marks the entity as rejected by the specified admin with a reason
func (a *ApprovableEntity) Reject(adminID int, reason string) {
	a.ApprovalStatus = ApprovalStatusRejected
	a.ApprovedByAdminID = &adminID
	now := time.Now()
	a.ApprovedAt = &now
	a.RejectionReason = &reason
}

// ResetToPending resets the entity to pending status (for resubmission)
func (a *ApprovableEntity) ResetToPending() {
	a.ApprovalStatus = ApprovalStatusPending
	a.ApprovedByAdminID = nil
	a.ApprovedAt = nil
	a.RejectionReason = nil
}
