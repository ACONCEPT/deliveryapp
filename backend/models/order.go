package models

import (
	"database/sql"
	"encoding/json"
	"time"

	"delivery_app/backend/models/base"
)

// Custom nullable types with proper JSON serialization
type NullInt64 struct {
	sql.NullInt64
}

// MarshalJSON for NullInt64 - returns 0 for null values
func (n NullInt64) MarshalJSON() ([]byte, error) {
	if !n.Valid {
		return []byte("0"), nil
	}
	return json.Marshal(n.Int64)
}

// UnmarshalJSON for NullInt64
func (n *NullInt64) UnmarshalJSON(data []byte) error {
	var value *int64
	if err := json.Unmarshal(data, &value); err != nil {
		return err
	}
	if value != nil {
		n.Valid = true
		n.Int64 = *value
	} else {
		n.Valid = false
	}
	return nil
}

type NullString struct {
	sql.NullString
}

// MarshalJSON for NullString - returns empty string for null values
func (n NullString) MarshalJSON() ([]byte, error) {
	if !n.Valid {
		return []byte(`""`), nil
	}
	return json.Marshal(n.String)
}

// UnmarshalJSON for NullString
func (n *NullString) UnmarshalJSON(data []byte) error {
	var value *string
	if err := json.Unmarshal(data, &value); err != nil {
		return err
	}
	if value != nil {
		n.Valid = true
		n.String = *value
	} else {
		n.Valid = false
	}
	return nil
}

type NullTime struct {
	sql.NullTime
}

// MarshalJSON for NullTime - returns epoch time (1970-01-01) for null values
func (n NullTime) MarshalJSON() ([]byte, error) {
	if !n.Valid {
		return []byte(`"1970-01-01T00:00:00Z"`), nil
	}
	return json.Marshal(n.Time)
}

// UnmarshalJSON for NullTime
func (n *NullTime) UnmarshalJSON(data []byte) error {
	var value *time.Time
	if err := json.Unmarshal(data, &value); err != nil {
		return err
	}
	if value != nil {
		n.Valid = true
		n.Time = *value
	} else {
		n.Valid = false
	}
	return nil
}

// OrderStatus represents the state of an order
type OrderStatus string

const (
	OrderStatusCart           OrderStatus = "cart"
	OrderStatusPending        OrderStatus = "pending"
	OrderStatusConfirmed      OrderStatus = "confirmed"
	OrderStatusPreparing      OrderStatus = "preparing"
	OrderStatusReady          OrderStatus = "ready"
	OrderStatusDriverAssigned OrderStatus = "driver_assigned"
	OrderStatusPickedUp       OrderStatus = "picked_up"
	OrderStatusInTransit      OrderStatus = "in_transit"
	OrderStatusDelivered      OrderStatus = "delivered"
	OrderStatusCancelled      OrderStatus = "cancelled"
	OrderStatusRefunded       OrderStatus = "refunded"
)

// Order represents a customer order
type Order struct {
	base.Timestamps `db:""` // Embedded timestamps (created_at, updated_at)

	ID                       int         `json:"id" db:"id"`
	CustomerID               int         `json:"customer_id" db:"customer_id"`
	RestaurantID             int         `json:"restaurant_id" db:"restaurant_id"`
	RestaurantName           string      `json:"restaurant_name" db:"restaurant_name"`
	DeliveryAddressID        NullInt64   `json:"delivery_address_id" db:"delivery_address_id"`
	DriverID                 NullInt64   `json:"driver_id" db:"driver_id"`
	Status                   OrderStatus `json:"status" db:"status"`
	SubtotalAmount           float64     `json:"subtotal_amount" db:"subtotal_amount"`
	TaxAmount                float64     `json:"tax_amount" db:"tax_amount"`
	DeliveryFee              float64     `json:"delivery_fee" db:"delivery_fee"`
	DiscountAmount           float64     `json:"discount_amount" db:"discount_amount"`
	TotalAmount              float64     `json:"total_amount" db:"total_amount"`
	PlacedAt                 NullTime    `json:"placed_at" db:"placed_at"`
	ConfirmedAt              NullTime    `json:"confirmed_at" db:"confirmed_at"`
	ReadyAt                  NullTime    `json:"ready_at" db:"ready_at"`
	DeliveredAt              NullTime    `json:"delivered_at" db:"delivered_at"`
	CancelledAt              NullTime    `json:"cancelled_at" db:"cancelled_at"`
	SpecialInstructions      NullString  `json:"special_instructions" db:"special_instructions"`
	CancellationReason       NullString  `json:"cancellation_reason" db:"cancellation_reason"`
	EstimatedPreparationTime NullInt64   `json:"estimated_preparation_time" db:"estimated_preparation_time"`
	EstimatedDeliveryTime    NullTime    `json:"estimated_delivery_time" db:"estimated_delivery_time"`
	IsActive                 bool        `json:"is_active" db:"is_active"`
}

// OrderItem represents an item in an order
type OrderItem struct {
	base.Timestamps `db:""` // Embedded timestamps (created_at, updated_at)

	ID                  int             `json:"id" db:"id"`
	OrderID             int             `json:"order_id" db:"order_id"`
	MenuItemName        string          `json:"menu_item_name" db:"menu_item_name"`
	MenuItemDescription NullString      `json:"menu_item_description" db:"menu_item_description"`
	PriceAtTime         float64         `json:"price_at_time" db:"price_at_time"`
	Quantity            int             `json:"quantity" db:"quantity"`
	Customizations      json.RawMessage `json:"customizations" db:"customizations"`
	LineTotal           float64         `json:"line_total" db:"line_total"`
}

// OrderStatusHistory represents the audit trail for order status changes
type OrderStatusHistory struct {
	ID         int              `json:"id" db:"id"`
	OrderID    int              `json:"order_id" db:"order_id"`
	UserID     NullInt64        `json:"user_id" db:"user_id"`
	FromStatus NullString       `json:"from_status" db:"from_status"`
	ToStatus   string           `json:"to_status" db:"to_status"`
	Notes      NullString       `json:"notes" db:"notes"`
	Metadata   *json.RawMessage `json:"metadata,omitempty" db:"metadata"`
	CreatedAt  time.Time        `json:"created_at" db:"created_at"`
}

// ============================================================================
// REQUEST/RESPONSE DTOs
// ============================================================================

// CreateOrderRequest represents a request to create a new order
type CreateOrderRequest struct {
	RestaurantID        int                    `json:"restaurant_id" validate:"required"`
	DeliveryAddressID   int                    `json:"delivery_address_id" validate:"required"`
	SpecialInstructions string                 `json:"special_instructions"`
	Items               []CreateOrderItemRequest `json:"items" validate:"required,min=1"`
}

// CreateOrderItemRequest represents an item in the order creation request
type CreateOrderItemRequest struct {
	MenuItemName        string                 `json:"menu_item_name" validate:"required"`
	MenuItemDescription string                 `json:"menu_item_description"`
	Price               float64                `json:"price" validate:"required,gt=0"`
	Quantity            int                    `json:"quantity" validate:"required,min=1"`
	Customizations      map[string]interface{} `json:"customizations"`
}

// UpdateOrderStatusRequest represents a request to update order status
type UpdateOrderStatusRequest struct {
	Status                   OrderStatus `json:"status" validate:"required"`
	Notes                    string      `json:"notes"`
	EstimatedPreparationTime *int        `json:"estimated_preparation_time"` // in minutes
}

// CancelOrderRequest represents a request to cancel an order
type CancelOrderRequest struct {
	Reason string `json:"reason" validate:"required"`
}

// OrderDetailsResponse represents detailed order information with items
type OrderDetailsResponse struct {
	Order            Order                     `json:"order"`
	Items            []OrderItem               `json:"items"`
	StatusHistory    []OrderStatusHistory      `json:"status_history,omitempty"`
	Restaurant       *RestaurantInfo           `json:"restaurant,omitempty"`
	DeliveryAddress  *CustomerAddress          `json:"delivery_address,omitempty"`
	Customer         *CustomerInfo             `json:"customer,omitempty"`
	Driver           *DriverInfo               `json:"driver,omitempty"`
}

// OrderListResponse represents a paginated list of orders
type OrderListResponse struct {
	Orders     []OrderSummary `json:"orders"`
	TotalCount int            `json:"total_count"`
	Page       int            `json:"page"`
	PerPage    int            `json:"per_page"`
}

// OrderSummary represents a simplified order for list views
type OrderSummary struct {
	ID              int         `json:"id" db:"id"`
	CustomerID      int         `json:"customer_id" db:"customer_id"`
	RestaurantID    int         `json:"restaurant_id" db:"restaurant_id"`
	RestaurantName  string      `json:"restaurant_name" db:"restaurant_name"`
	Status          OrderStatus `json:"status" db:"status"`
	TotalAmount     float64     `json:"total_amount" db:"total_amount"`
	ItemCount       int         `json:"item_count" db:"item_count"`
	PlacedAt        *time.Time  `json:"placed_at" db:"placed_at"`
	EstimatedTime   *time.Time  `json:"estimated_delivery_time" db:"estimated_time"`
	CreatedAt       time.Time   `json:"created_at" db:"created_at"`
}

// OrderStats represents order statistics (for admin/vendor dashboards)
type OrderStats struct {
	TotalOrders      int     `json:"total_orders"`
	PendingOrders    int     `json:"pending_orders"`
	ConfirmedOrders  int     `json:"confirmed_orders"`
	DeliveredOrders  int     `json:"delivered_orders"`
	CancelledOrders  int     `json:"cancelled_orders"`
	TotalRevenue     float64 `json:"total_revenue"`
	AverageOrderValue float64 `json:"average_order_value"`
}

// RestaurantInfo represents restaurant details for order response
type RestaurantInfo struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	Phone   string `json:"phone"`
	Address string `json:"address"`
}

// DriverOrderInfoResponse represents driver-focused order information
type DriverOrderInfoResponse struct {
	OrderID              int         `json:"order_id"`
	Status               OrderStatus `json:"status"`
	ItemCount            int         `json:"item_count"`
	EstimatedPrepTime    *int        `json:"estimated_prep_time"` // in minutes
	EstimatedDriveTime   *int        `json:"estimated_drive_time"` // in minutes (calculated from distance)
	TotalAmount          float64     `json:"total_amount"`
	RestaurantName       string      `json:"restaurant_name"`
	RestaurantAddress    string      `json:"restaurant_address"`
	DeliveryAddress      string      `json:"delivery_address"`
	SpecialInstructions  *string     `json:"special_instructions,omitempty"`
	PlacedAt             *time.Time  `json:"placed_at,omitempty"`
	EstimatedDeliveryTime *time.Time `json:"estimated_delivery_time,omitempty"`
}

// CustomerInfo represents customer details for order response
type CustomerInfo struct {
	ID       int    `json:"id"`
	FullName string `json:"full_name"`
	Phone    string `json:"phone"`
}

// DriverInfo represents driver details for order response
type DriverInfo struct {
	ID          int    `json:"id"`
	FullName    string `json:"full_name"`
	Phone       string `json:"phone"`
	VehicleType string `json:"vehicle_type"`
}

// ============================================================================
// HELPER METHODS
// ============================================================================

// IsValidStatusTransition checks if a status transition is allowed
func IsValidStatusTransition(from, to OrderStatus) bool {
	// Define valid transitions
	validTransitions := map[OrderStatus][]OrderStatus{
		OrderStatusCart: {
			OrderStatusPending,
			OrderStatusCancelled,
		},
		OrderStatusPending: {
			OrderStatusConfirmed,
			OrderStatusCancelled,
		},
		OrderStatusConfirmed: {
			OrderStatusPreparing,
			OrderStatusCancelled,
		},
		OrderStatusPreparing: {
			OrderStatusReady,
			OrderStatusCancelled,
		},
		OrderStatusReady: {
			OrderStatusDriverAssigned,
			OrderStatusCancelled,
		},
		OrderStatusDriverAssigned: {
			OrderStatusPickedUp,
			OrderStatusCancelled,
		},
		OrderStatusPickedUp: {
			OrderStatusInTransit,
			OrderStatusCancelled,
		},
		OrderStatusInTransit: {
			OrderStatusDelivered,
			OrderStatusCancelled,
		},
		OrderStatusDelivered: {
			OrderStatusRefunded,
		},
		OrderStatusCancelled: {
			OrderStatusRefunded,
		},
		OrderStatusRefunded: {},
	}

	allowedTransitions, exists := validTransitions[from]
	if !exists {
		return false
	}

	for _, allowed := range allowedTransitions {
		if allowed == to {
			return true
		}
	}

	return false
}

// CanBeCancelled checks if an order can be cancelled based on its status
func (o *Order) CanBeCancelled() bool {
	cancellableStatuses := []OrderStatus{
		OrderStatusCart,
		OrderStatusPending,
		OrderStatusConfirmed,
		OrderStatusPreparing,
		OrderStatusReady,
	}

	for _, status := range cancellableStatuses {
		if o.Status == status {
			return true
		}
	}

	return false
}

// CalculateTotals calculates the order totals from items
func (r *CreateOrderRequest) CalculateTotals(taxRate float64) (subtotal, tax, deliveryFee, total float64) {
	// Calculate subtotal from items
	for _, item := range r.Items {
		subtotal += item.Price * float64(item.Quantity)
	}

	// Calculate tax (e.g., 8.5% = 0.085)
	tax = subtotal * taxRate

	// Calculate delivery fee (could be based on distance, time, etc.)
	// For now, use a flat rate
	deliveryFee = 5.00

	// Calculate total
	total = subtotal + tax + deliveryFee

	return
}
