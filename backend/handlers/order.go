package handlers

import (
	"database/sql"
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
)

// ============================================================================
// CUSTOMER ORDER HANDLERS (Sprint 1.1)
// ============================================================================

// CreateOrder creates a new order for a customer
func (h *Handler) CreateOrder(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get customer ID
	customer, err := h.App.Deps.Users.GetCustomerByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Customer profile not found")
		return
	}

	// Decode request
	var req models.CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate restaurant exists and is active/approved
	restaurant, err := h.App.Deps.Restaurants.GetByID(req.RestaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	if !restaurant.IsActive {
		sendError(w, http.StatusBadRequest, "Restaurant is not active")
		return
	}

	// Check if restaurant is approved (if approval system is implemented)
	if restaurant.ApprovalStatus != "approved" {
		sendError(w, http.StatusBadRequest, "Restaurant is not approved")
		return
	}

	// Validate delivery address belongs to customer
	address, err := h.App.Deps.Addresses.GetByID(req.DeliveryAddressID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Delivery address not found")
		return
	}

	if address.CustomerID != customer.ID {
		sendError(w, http.StatusForbidden, "Delivery address does not belong to you")
		return
	}

	// Validate order has items
	if len(req.Items) == 0 {
		sendError(w, http.StatusBadRequest, "Order must have at least one item")
		return
	}

	// Get system settings for order calculation
	taxRateSetting, err := h.App.Deps.Config.GetSettingByKey("tax_rate")
	if err != nil {
		// Use default if setting not found
		log.Printf("Warning: Failed to get tax_rate setting: %v, using default 0.085", err)
		taxRateSetting = &models.SystemSetting{SettingValue: "0.085", DataType: models.SettingDataTypeNumber}
	}
	taxRate, err := taxRateSetting.GetAsFloat64()
	if err != nil {
		log.Printf("Warning: Failed to parse tax_rate: %v, using default 0.085", err)
		taxRate = 0.085
	}

	minOrderSetting, err := h.App.Deps.Config.GetSettingByKey("minimum_order_amount")
	if err != nil {
		log.Printf("Warning: Failed to get minimum_order_amount setting: %v, using default 10.00", err)
		minOrderSetting = &models.SystemSetting{SettingValue: "10.00", DataType: models.SettingDataTypeNumber}
	}
	minOrderAmount, err := minOrderSetting.GetAsFloat64()
	if err != nil {
		log.Printf("Warning: Failed to parse minimum_order_amount: %v, using default 10.00", err)
		minOrderAmount = 10.00
	}

	// Calculate totals
	subtotal, tax, deliveryFee, total := req.CalculateTotals(taxRate)

	// Validate minimum order amount
	if subtotal < minOrderAmount {
		sendError(w, http.StatusBadRequest, fmt.Sprintf("Minimum order amount is $%.2f", minOrderAmount))
		return
	}

	// Create order
	order := &models.Order{
		CustomerID:          customer.ID,
		RestaurantID:        req.RestaurantID,
		DeliveryAddressID:   models.NullInt64{NullInt64: sql.NullInt64{Int64: int64(req.DeliveryAddressID), Valid: true}},
		Status:              models.OrderStatusPending,
		SubtotalAmount:      subtotal,
		TaxAmount:           tax,
		DeliveryFee:         deliveryFee,
		DiscountAmount:      0.00,
		TotalAmount:         total,
		PlacedAt:            models.NullTime{NullTime: sql.NullTime{Time: time.Now(), Valid: true}},
		SpecialInstructions: models.NullString{NullString: sql.NullString{String: req.SpecialInstructions, Valid: req.SpecialInstructions != ""}},
		IsActive:            true,
	}

	// Create order items
	orderItems := make([]models.OrderItem, len(req.Items))
	for i, item := range req.Items {
		// Convert customizations to JSON
		customizationsJSON, err := json.Marshal(item.Customizations)
		if err != nil {
			sendError(w, http.StatusBadRequest, "Invalid item customizations")
			return
		}

		orderItems[i] = models.OrderItem{
			MenuItemName:        item.MenuItemName,
			MenuItemDescription: models.NullString{NullString: sql.NullString{String: item.MenuItemDescription, Valid: item.MenuItemDescription != ""}},
			PriceAtTime:         item.Price,
			Quantity:            item.Quantity,
			Customizations:      customizationsJSON,
			LineTotal:           item.Price * float64(item.Quantity),
		}
	}

	// Create order with items in transaction
	err = h.App.Deps.Orders.CreateOrderWithItems(order, orderItems)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create order", err)
		return
	}

	// TODO: Trigger notification to vendor about new order
	// TODO: Create payment intent if payment integration is ready

	// Return created order
	sendSuccessWithDebug(w, r, http.StatusCreated, "Order placed successfully", map[string]interface{}{
		"order_id":     order.ID,
		"total_amount": order.TotalAmount,
		"status":       order.Status,
	})
}

// GetCustomerOrders retrieves all orders for the authenticated customer
func (h *Handler) GetCustomerOrders(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get customer ID
	customer, err := h.App.Deps.Users.GetCustomerByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Customer profile not found")
		return
	}

	// Parse pagination parameters
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	perPage, _ := strconv.Atoi(r.URL.Query().Get("per_page"))
	if perPage < 1 || perPage > 100 {
		perPage = 20
	}

	offset := (page - 1) * perPage

	// Get orders
	orders, err := h.App.Deps.Orders.GetOrdersByCustomerID(customer.ID, perPage, offset)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve orders", err)
		return
	}

	// Return orders
	sendSuccessWithDebug(w, r, http.StatusOK, "Orders retrieved successfully", map[string]interface{}{
		"orders":   orders,
		"page":     page,
		"per_page": perPage,
	})
}

// GetOrderDetails retrieves detailed information about a specific order
func (h *Handler) GetOrderDetails(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get order ID from URL
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Get order
	order, err := h.App.Deps.Orders.GetOrderByID(orderID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Order not found")
		return
	}

	// Verify customer ownership (unless admin/vendor)
	if user.UserType == models.UserTypeCustomer {
		customer, err := h.App.Deps.Users.GetCustomerByUserID(user.UserID)
		if err != nil || order.CustomerID != customer.ID {
			sendError(w, http.StatusForbidden, "You don't have permission to view this order")
			return
		}
	}

	// Get order items
	items, err := h.App.Deps.Orders.GetOrderItems(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve order items", err)
		return
	}

	// Get status history
	history, err := h.App.Deps.Orders.GetOrderStatusHistory(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve order history", err)
		return
	}

	// Build response
	response := models.OrderDetailsResponse{
		Order:         *order,
		Items:         items,
		StatusHistory: history,
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Order details retrieved successfully", response)
}

// CancelOrder cancels a customer's order
func (h *Handler) CancelOrder(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get customer ID
	customer, err := h.App.Deps.Users.GetCustomerByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Customer profile not found")
		return
	}

	// Get order ID from URL
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Decode request
	var req models.CancelOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Reason == "" {
		sendError(w, http.StatusBadRequest, "Cancellation reason is required")
		return
	}

	// Get order
	order, err := h.App.Deps.Orders.GetOrderByID(orderID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Order not found")
		return
	}

	// Verify customer ownership
	if order.CustomerID != customer.ID {
		sendError(w, http.StatusForbidden, "You don't have permission to cancel this order")
		return
	}

	// Check if order can be cancelled
	if !order.CanBeCancelled() {
		sendError(w, http.StatusBadRequest, fmt.Sprintf("Order cannot be cancelled in %s status", order.Status))
		return
	}

	// Cancel order
	err = h.App.Deps.Orders.CancelOrder(orderID, req.Reason)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to cancel order", err)
		return
	}

	// TODO: Trigger refund if payment was processed
	// TODO: Notify vendor and driver about cancellation

	sendSuccessWithDebug(w, r, http.StatusOK, "Order cancelled successfully", nil)
}

// ============================================================================
// VENDOR ORDER HANDLERS (Sprint 1.2)
// ============================================================================

// GetVendorOrders retrieves all orders for vendor's restaurants
func (h *Handler) GetVendorOrders(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor profile not found")
		return
	}

	// Get vendor's restaurants
	restaurants, err := h.App.Deps.Restaurants.GetByVendorID(vendor.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve restaurants", err)
		return
	}

	if len(restaurants) == 0 {
		sendSuccessWithDebug(w, r, http.StatusOK, "No restaurants found", map[string]interface{}{
			"orders": []models.Order{},
		})
		return
	}

	// Extract restaurant IDs
	restaurantIDs := make([]int, len(restaurants))
	for i, r := range restaurants {
		restaurantIDs[i] = r.ID
	}

	// Parse query parameters
	status := r.URL.Query().Get("status")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	perPage, _ := strconv.Atoi(r.URL.Query().Get("per_page"))
	if perPage < 1 || perPage > 100 {
		perPage = 20
	}

	offset := (page - 1) * perPage

	// Get orders
	orders := make([]models.Order, 0)
	if status != "" {
		// Validate status value
		orderStatus := models.OrderStatus(status)
		if !isValidOrderStatus(orderStatus) {
			sendError(w, http.StatusBadRequest, "Invalid status value")
			return
		}
		orders, err = h.App.Deps.Orders.GetOrdersByRestaurantIDsAndStatus(restaurantIDs, orderStatus, perPage, offset)
	} else {
		orders, err = h.App.Deps.Orders.GetOrdersByRestaurantIDs(restaurantIDs, perPage, offset)
	}

	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve orders", err)
		return
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Orders retrieved successfully", map[string]interface{}{
		"orders":   orders,
		"page":     page,
		"per_page": perPage,
	})
}

// GetVendorOrderDetails retrieves detailed information about an order for vendor
func (h *Handler) GetVendorOrderDetails(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor profile not found")
		return
	}

	// Get order ID from URL
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Get order
	order, err := h.App.Deps.Orders.GetOrderByID(orderID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Order not found")
		return
	}

	// Verify vendor owns the restaurant
	restaurant, err := h.App.Deps.Restaurants.GetByID(order.RestaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	// Check vendor ownership
	vendorRestaurant, err := h.App.Deps.VendorRestaurants.GetByRestaurantID(restaurant.ID)
	if err != nil || vendorRestaurant.VendorID != vendor.ID {
		sendError(w, http.StatusForbidden, "You don't have permission to view this order")
		return
	}

	// Get order items
	items, err := h.App.Deps.Orders.GetOrderItems(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve order items", err)
		return
	}

	// Get status history
	history, err := h.App.Deps.Orders.GetOrderStatusHistory(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve order history", err)
		return
	}

	// Build response
	response := models.OrderDetailsResponse{
		Order:         *order,
		Items:         items,
		StatusHistory: history,
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Order details retrieved successfully", response)
}

// GetVendorOrderStats retrieves order statistics for vendor's restaurants
func (h *Handler) GetVendorOrderStats(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor profile not found")
		return
	}

	// Get vendor's restaurants
	restaurants, err := h.App.Deps.Restaurants.GetByVendorID(vendor.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve restaurants", err)
		return
	}

	if len(restaurants) == 0 {
		sendSuccessWithDebug(w, r, http.StatusOK, "No statistics available", &models.OrderStats{
			TotalOrders:       0,
			PendingOrders:     0,
			ConfirmedOrders:   0,
			DeliveredOrders:   0,
			CancelledOrders:   0,
			TotalRevenue:      0,
			AverageOrderValue: 0,
		})
		return
	}

	// Extract restaurant IDs
	restaurantIDs := make([]int, len(restaurants))
	for i, r := range restaurants {
		restaurantIDs[i] = r.ID
	}

	// Build filters for vendor's restaurants
	filters := map[string]interface{}{
		"restaurant_ids": restaurantIDs,
	}

	// Get statistics
	stats, err := h.App.Deps.Orders.GetOrderStats(filters)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve statistics", err)
		return
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Statistics retrieved successfully", stats)
}

// UpdateOrderStatus updates the status of an order (vendor action)
func (h *Handler) UpdateOrderStatus(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor profile not found")
		return
	}

	// Get order ID from URL
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Decode request
	var req models.UpdateOrderStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Get order
	order, err := h.App.Deps.Orders.GetOrderByID(orderID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Order not found")
		return
	}

	// Verify vendor owns the restaurant
	restaurant, err := h.App.Deps.Restaurants.GetByID(order.RestaurantID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Restaurant not found")
		return
	}

	vendorRestaurant, err := h.App.Deps.VendorRestaurants.GetByRestaurantID(restaurant.ID)
	if err != nil || vendorRestaurant.VendorID != vendor.ID {
		sendError(w, http.StatusForbidden, "You don't have permission to update this order")
		return
	}

	// Validate status transition
	if !models.IsValidStatusTransition(order.Status, req.Status) {
		sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid status transition from %s to %s", order.Status, req.Status))
		return
	}

	// Update status with history
	err = h.App.Deps.Orders.UpdateOrderStatusWithHistory(orderID, req.Status, req.Notes, user.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update order status", err)
		return
	}

	// Update estimated preparation time if provided
	if req.EstimatedPreparationTime != nil && req.Status == models.OrderStatusConfirmed {
		order.EstimatedPreparationTime = models.NullInt64{NullInt64: sql.NullInt64{Int64: int64(*req.EstimatedPreparationTime), Valid: true}}
		// Calculate estimated delivery time (prep time + 30 min delivery)
		estimatedTime := time.Now().Add(time.Duration(*req.EstimatedPreparationTime+30) * time.Minute)
		order.EstimatedDeliveryTime = models.NullTime{NullTime: sql.NullTime{Time: estimatedTime, Valid: true}}
		err = h.App.Deps.Orders.UpdateOrder(order)
		if err != nil {
			// Log error but don't fail the request
			fmt.Printf("Warning: Failed to update estimated time: %v\n", err)
		}
	}

	// TODO: Trigger notifications
	// - confirmed: notify customer
	// - ready: notify available drivers
	// - cancelled: notify customer and driver

	sendSuccessWithDebug(w, r, http.StatusOK, "Order status updated successfully", map[string]interface{}{
		"order_id": orderID,
		"status":   req.Status,
	})
}

// Helper functions

// isValidOrderStatus validates if the provided status is a valid order status
func isValidOrderStatus(status models.OrderStatus) bool {
	validStatuses := []models.OrderStatus{
		models.OrderStatusCart,
		models.OrderStatusPending,
		models.OrderStatusConfirmed,
		models.OrderStatusPreparing,
		models.OrderStatusReady,
		models.OrderStatusDriverAssigned,
		models.OrderStatusPickedUp,
		models.OrderStatusInTransit,
		models.OrderStatusDelivered,
		models.OrderStatusCancelled,
		models.OrderStatusRefunded,
	}

	for _, validStatus := range validStatuses {
		if status == validStatus {
			return true
		}
	}
	return false
}
