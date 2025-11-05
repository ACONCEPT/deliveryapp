package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// ============================================================================
// DRIVER ORDER HANDLERS
// ============================================================================

// GetAvailableOrders retrieves orders that are ready for driver assignment
func (h *Handler) GetAvailableOrders(w http.ResponseWriter, r *http.Request) {
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

	// Get available orders (status=ready, no driver assigned)
	orders, err := h.App.Deps.Orders.GetAvailableOrdersForDriver(perPage, offset)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve available orders", err)
		return
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Available orders retrieved successfully", map[string]interface{}{
		"orders":   orders,
		"page":     page,
		"per_page": perPage,
	})
}

// GetDriverOrders retrieves all orders assigned to the authenticated driver
func (h *Handler) GetDriverOrders(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get driver profile
	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver profile not found")
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

	// Get orders assigned to this driver
	orders, err := h.App.Deps.Orders.GetOrdersByDriverID(driver.ID, perPage, offset)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve driver orders", err)
		return
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Driver orders retrieved successfully", map[string]interface{}{
		"orders":   orders,
		"page":     page,
		"per_page": perPage,
	})
}

// GetDriverOrderDetails retrieves detailed information about a specific order for driver
func (h *Handler) GetDriverOrderDetails(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get driver profile
	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver profile not found")
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

	// Verify driver is assigned to this order (or order is available)
	if order.Status != models.OrderStatusReady {
		// If not ready, must be assigned to this driver
		if !order.DriverID.Valid || order.DriverID.Int64 != int64(driver.ID) {
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

	// Get delivery address
	var deliveryAddress *models.CustomerAddress
	if order.DeliveryAddressID.Valid {
		deliveryAddress, err = h.App.Deps.Addresses.GetByID(int(order.DeliveryAddressID.Int64))
		if err != nil {
			// Log but don't fail
			fmt.Printf("Warning: Failed to get delivery address: %v\n", err)
		}
	}

	// Get restaurant details
	var restaurant *models.Restaurant
	restaurant, err = h.App.Deps.Restaurants.GetByID(order.RestaurantID)
	if err != nil {
		// Log but don't fail
		fmt.Printf("Warning: Failed to get restaurant: %v\n", err)
	}

	// Get customer details
	var customer *models.Customer
	customer, err = h.App.Deps.Users.GetCustomerByUserID(order.CustomerID)
	if err != nil {
		// Log but don't fail
		fmt.Printf("Warning: Failed to get customer: %v\n", err)
	}

	// Get status history
	history, err := h.App.Deps.Orders.GetOrderStatusHistory(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve order history", err)
		return
	}

	// Safely dereference optional phone numbers
	customerPhone := ""
	if customer.Phone != nil {
		customerPhone = *customer.Phone
	}

	restaurantPhone := ""
	if restaurant.Phone != nil {
		restaurantPhone = *restaurant.Phone
	}

	// Build restaurant address from components
	restaurantAddress := ""
	if restaurant.AddressLine1 != nil {
		restaurantAddress = *restaurant.AddressLine1
	}
	if restaurant.City != nil {
		if restaurantAddress != "" {
			restaurantAddress += ", "
		}
		restaurantAddress += *restaurant.City
	}
	if restaurant.State != nil {
		if restaurantAddress != "" {
			restaurantAddress += ", "
		}
		restaurantAddress += *restaurant.State
	}

	// Build response with all related data
	response := models.OrderDetailsResponse{
		Order:           *order,
		Items:           items,
		StatusHistory:   history,
		DeliveryAddress: deliveryAddress,
		Customer: &models.CustomerInfo{
			ID:       customer.ID,
			FullName: customer.FullName,
			Phone:    customerPhone,
		},
		Restaurant: &models.RestaurantInfo{
			ID:      restaurant.ID,
			Name:    restaurant.Name,
			Phone:   restaurantPhone,
			Address: restaurantAddress,
		},
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Order details retrieved successfully", response)
}

// AssignOrderToDriver allows a driver to self-assign to an available order
func (h *Handler) AssignOrderToDriver(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get driver profile
	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver profile not found")
		return
	}

	// Get order ID from URL
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Assign driver to order (validates order status and availability)
	// Uses atomic check-and-set to prevent race conditions
	err = h.App.Deps.Orders.AssignDriverToOrder(orderID, driver.ID)
	if err != nil {
		// Use custom error types for proper HTTP status codes
		if orderErr, ok := models.GetOrderAssignmentError(err); ok {
			switch orderErr.Code {
			case models.ErrCodeOrderNotFound:
				sendError(w, http.StatusNotFound, orderErr.Error())
			case models.ErrCodeOrderAlreadyAssigned:
				// 409 Conflict - another driver already claimed this order
				sendError(w, http.StatusConflict, "This order has already been assigned to another driver")
			case models.ErrCodeOrderNotReady:
				sendError(w, http.StatusBadRequest, orderErr.Error())
			case models.ErrCodeOrderNotActive:
				sendError(w, http.StatusBadRequest, "Order is not active")
			case models.ErrCodeOrderNotAvailable:
				sendError(w, http.StatusBadRequest, "Order is not available for assignment")
			default:
				sendErrorWithContext(w, r, http.StatusBadRequest, orderErr.Error(), err)
			}
			return
		}

		// Generic database or other error
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to assign order", err)
		return
	}

	// TODO: Trigger notification to customer that driver has been assigned
	// TODO: Trigger notification to restaurant

	sendSuccessWithDebug(w, r, http.StatusOK, "Order assigned successfully", map[string]interface{}{
		"order_id":  orderID,
		"driver_id": driver.ID,
		"status":    models.OrderStatusDriverAssigned,
	})
}

// UpdateDriverOrderStatus updates the status of an order assigned to the driver
func (h *Handler) UpdateDriverOrderStatus(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get driver profile
	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver profile not found")
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

	// Verify driver is assigned to this order
	if !order.DriverID.Valid || order.DriverID.Int64 != int64(driver.ID) {
		sendError(w, http.StatusForbidden, "You are not assigned to this order")
		return
	}

	// Validate status transition
	// Drivers can only transition through: driver_assigned -> picked_up -> in_transit -> delivered
	validDriverTransitions := map[models.OrderStatus][]models.OrderStatus{
		models.OrderStatusDriverAssigned: {models.OrderStatusPickedUp, models.OrderStatusCancelled},
		models.OrderStatusPickedUp:       {models.OrderStatusInTransit, models.OrderStatusCancelled},
		models.OrderStatusInTransit:      {models.OrderStatusDelivered},
	}

	allowedStatuses, validCurrentStatus := validDriverTransitions[order.Status]
	if !validCurrentStatus {
		sendError(w, http.StatusBadRequest, fmt.Sprintf("Cannot update order in %s status", order.Status))
		return
	}

	isValidTransition := false
	for _, allowed := range allowedStatuses {
		if allowed == req.Status {
			isValidTransition = true
			break
		}
	}

	if !isValidTransition {
		sendError(w, http.StatusBadRequest, fmt.Sprintf("Invalid status transition from %s to %s", order.Status, req.Status))
		return
	}

	// Update status with history
	err = h.App.Deps.Orders.UpdateOrderStatusWithHistory(orderID, req.Status, req.Notes, user.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update order status", err)
		return
	}

	// TODO: Trigger notifications based on status
	// - picked_up: notify customer and restaurant
	// - in_transit: notify customer
	// - delivered: notify customer and restaurant, trigger payment processing

	sendSuccessWithDebug(w, r, http.StatusOK, "Order status updated successfully", map[string]interface{}{
		"order_id": orderID,
		"status":   req.Status,
	})
}

// GetDriverOrderInfo retrieves driver-focused order information for a specific order
func (h *Handler) GetDriverOrderInfo(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get driver profile
	driver, err := h.App.Deps.Users.GetDriverByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Driver profile not found")
		return
	}

	// Get order ID from URL
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Get order to verify driver assignment
	order, err := h.App.Deps.Orders.GetOrderByID(orderID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Order not found")
		return
	}

	// Verify driver is assigned to this order (or order is available for assignment)
	if order.Status != models.OrderStatusReady {
		// If not ready, must be assigned to this driver
		if !order.DriverID.Valid || order.DriverID.Int64 != int64(driver.ID) {
			sendError(w, http.StatusForbidden, "You don't have permission to view this order")
			return
		}
	}

	// Get driver-specific order information
	orderInfo, err := h.App.Deps.Orders.GetDriverOrderInfo(orderID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve order information", err)
		return
	}

	sendSuccessWithDebug(w, r, http.StatusOK, "Order information retrieved successfully", orderInfo)
}
