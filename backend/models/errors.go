package models

import (
	"fmt"
)

// ============================================================================
// ORDER ASSIGNMENT ERRORS
// ============================================================================

// OrderAssignmentErrorCode represents specific error conditions for order assignment
type OrderAssignmentErrorCode string

const (
	ErrCodeOrderNotFound       OrderAssignmentErrorCode = "ORDER_NOT_FOUND"
	ErrCodeOrderAlreadyAssigned OrderAssignmentErrorCode = "ORDER_ALREADY_ASSIGNED"
	ErrCodeOrderNotReady       OrderAssignmentErrorCode = "ORDER_NOT_READY"
	ErrCodeOrderNotActive      OrderAssignmentErrorCode = "ORDER_NOT_ACTIVE"
	ErrCodeOrderNotAvailable   OrderAssignmentErrorCode = "ORDER_NOT_AVAILABLE"
)

// OrderAssignmentError represents an error during driver order assignment
type OrderAssignmentError struct {
	Code    OrderAssignmentErrorCode
	Message string
	Details string // Optional additional context
}

func (e *OrderAssignmentError) Error() string {
	if e.Details != "" {
		return fmt.Sprintf("%s: %s", e.Message, e.Details)
	}
	return e.Message
}

// NewOrderAssignmentError creates a new order assignment error
func NewOrderAssignmentError(code OrderAssignmentErrorCode, message string, details ...string) *OrderAssignmentError {
	err := &OrderAssignmentError{
		Code:    code,
		Message: message,
	}
	if len(details) > 0 {
		err.Details = details[0]
	}
	return err
}

// Predefined error instances
var (
	ErrOrderNotFound = &OrderAssignmentError{
		Code:    ErrCodeOrderNotFound,
		Message: "Order not found",
	}

	ErrOrderAlreadyAssigned = &OrderAssignmentError{
		Code:    ErrCodeOrderAlreadyAssigned,
		Message: "Order already has a driver assigned",
	}

	ErrOrderNotActive = &OrderAssignmentError{
		Code:    ErrCodeOrderNotActive,
		Message: "Order is not active",
	}

	ErrOrderNotAvailable = &OrderAssignmentError{
		Code:    ErrCodeOrderNotAvailable,
		Message: "Order is not available for assignment",
	}
)

// NewOrderNotReadyError creates an error for orders not in ready status
func NewOrderNotReadyError(currentStatus string) *OrderAssignmentError {
	return &OrderAssignmentError{
		Code:    ErrCodeOrderNotReady,
		Message: "Order must be in 'ready' status to assign driver",
		Details: fmt.Sprintf("current status: %s", currentStatus),
	}
}

// IsOrderAssignmentError checks if an error is an OrderAssignmentError
func IsOrderAssignmentError(err error) bool {
	_, ok := err.(*OrderAssignmentError)
	return ok
}

// GetOrderAssignmentError safely casts to OrderAssignmentError
func GetOrderAssignmentError(err error) (*OrderAssignmentError, bool) {
	orderErr, ok := err.(*OrderAssignmentError)
	return orderErr, ok
}

// ============================================================================
// ORDER STATUS TRANSITION ERRORS
// ============================================================================

// OrderStatusTransitionError represents an invalid status transition attempt
type OrderStatusTransitionError struct {
	FromStatus OrderStatus
	ToStatus   OrderStatus
	Reason     string
}

func (e *OrderStatusTransitionError) Error() string {
	if e.Reason != "" {
		return fmt.Sprintf("invalid status transition from %s to %s: %s", e.FromStatus, e.ToStatus, e.Reason)
	}
	return fmt.Sprintf("invalid status transition from %s to %s", e.FromStatus, e.ToStatus)
}

// NewOrderStatusTransitionError creates a new status transition error
func NewOrderStatusTransitionError(from, to OrderStatus, reason ...string) *OrderStatusTransitionError {
	err := &OrderStatusTransitionError{
		FromStatus: from,
		ToStatus:   to,
	}
	if len(reason) > 0 {
		err.Reason = reason[0]
	}
	return err
}
