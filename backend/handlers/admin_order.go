package handlers

import (
	"database/sql"
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
)

// ============================================================================
// ADMIN ORDER HANDLERS (Sprint 1.3)
// ============================================================================

// GetAllOrders retrieves all orders with filtering and pagination (admin only)
func (h *Handler) GetAllOrders(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	filters := make(map[string]interface{})

	if status := r.URL.Query().Get("status"); status != "" {
		filters["status"] = status
	}

	if restaurantID := r.URL.Query().Get("restaurant_id"); restaurantID != "" {
		if id, err := strconv.Atoi(restaurantID); err == nil {
			filters["restaurant_id"] = id
		}
	}

	if customerID := r.URL.Query().Get("customer_id"); customerID != "" {
		if id, err := strconv.Atoi(customerID); err == nil {
			filters["customer_id"] = id
		}
	}

	// Parse pagination
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	perPage, _ := strconv.Atoi(r.URL.Query().Get("per_page"))
	if perPage < 1 {
		perPage = 50
	}
	if perPage > 500 {
		perPage = 500 // Maximum limit
	}

	offset := (page - 1) * perPage

	// Get orders
	orders, totalCount, err := h.App.Deps.Orders.GetAllOrders(filters, perPage, offset)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve orders", err)
		return
	}

	// Build response
	response := map[string]interface{}{
		"orders":      orders,
		"total_count": totalCount,
		"page":        page,
		"per_page":    perPage,
		"total_pages": (totalCount + perPage - 1) / perPage,
	}

	sendSuccess(w, http.StatusOK, "Orders retrieved successfully", response)
}

// GetAdminOrderDetails retrieves detailed order information (admin can view any order)
func (h *Handler) GetAdminOrderDetails(w http.ResponseWriter, r *http.Request) {
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

	// Get restaurant details
	restaurant, err := h.App.Deps.Restaurants.GetByID(order.RestaurantID)
	if err == nil {
		// Restaurant found, include in response (optional)
		_ = restaurant // Use restaurant data as needed
	}

	// Get customer details
	customer, err := h.App.Deps.Users.GetCustomerByUserID(order.CustomerID)
	if err == nil {
		_ = customer // Use customer data as needed
	}

	// Build response
	response := models.OrderDetailsResponse{
		Order:         *order,
		Items:         items,
		StatusHistory: history,
	}

	sendSuccess(w, http.StatusOK, "Order details retrieved successfully", response)
}

// UpdateAdminOrder allows admin to update any order field (admin override)
func (h *Handler) UpdateAdminOrder(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user for audit trail
	user := middleware.MustGetUserFromContext(r.Context())

	// Get order ID from URL
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid order ID")
		return
	}

	// Get existing order
	order, err := h.App.Deps.Orders.GetOrderByID(orderID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Order not found")
		return
	}

	// Decode update request
	var updates map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Track old status for history
	oldStatus := order.Status

	// Apply updates (admin can update any field)
	if status, ok := updates["status"].(string); ok {
		order.Status = models.OrderStatus(status)
	}

	if totalAmount, ok := updates["total_amount"].(float64); ok {
		order.TotalAmount = totalAmount
	}

	if driverID, ok := updates["driver_id"].(float64); ok {
		order.DriverID.Int64 = int64(driverID)
		order.DriverID.Valid = true
	}

	// Update order
	err = h.App.Deps.Orders.UpdateOrder(order)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update order", err)
		return
	}

	// Log status change if status was updated
	if order.Status != oldStatus {
		history := &models.OrderStatusHistory{
			OrderID:    orderID,
			UserID:     models.NullInt64{NullInt64: sql.NullInt64{Int64: int64(user.UserID), Valid: true}},
			FromStatus: models.NullString{NullString: sql.NullString{String: string(oldStatus), Valid: true}},
			ToStatus:   string(order.Status),
			Notes:      models.NullString{NullString: sql.NullString{String: "Admin override", Valid: true}},
		}
		_ = h.App.Deps.Orders.CreateStatusHistory(history)
	}

	sendSuccess(w, http.StatusOK, "Order updated successfully", map[string]interface{}{
		"order_id": orderID,
	})
}

// GetOrderStats retrieves order statistics (admin dashboard)
func (h *Handler) GetOrderStats(w http.ResponseWriter, r *http.Request) {
	// Parse filters
	filters := make(map[string]interface{})

	if restaurantID := r.URL.Query().Get("restaurant_id"); restaurantID != "" {
		if id, err := strconv.Atoi(restaurantID); err == nil {
			filters["restaurant_id"] = id
		}
	}

	if customerID := r.URL.Query().Get("customer_id"); customerID != "" {
		if id, err := strconv.Atoi(customerID); err == nil {
			filters["customer_id"] = id
		}
	}

	// Get statistics
	stats, err := h.App.Deps.Orders.GetOrderStats(filters)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve order statistics", err)
		return
	}

	// Get order counts by status
	statusCounts, err := h.App.Deps.Orders.GetOrderCountByStatus()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve status counts", err)
		return
	}

	// Build response
	response := map[string]interface{}{
		"stats":         stats,
		"status_counts": statusCounts,
	}

	sendSuccess(w, http.StatusOK, "Order statistics retrieved successfully", response)
}

// ExportOrders exports orders to CSV format
func (h *Handler) ExportOrders(w http.ResponseWriter, r *http.Request) {
	// Parse filters (same as GetAllOrders)
	filters := make(map[string]interface{})

	if status := r.URL.Query().Get("status"); status != "" {
		filters["status"] = status
	}

	if restaurantID := r.URL.Query().Get("restaurant_id"); restaurantID != "" {
		if id, err := strconv.Atoi(restaurantID); err == nil {
			filters["restaurant_id"] = id
		}
	}

	if customerID := r.URL.Query().Get("customer_id"); customerID != "" {
		if id, err := strconv.Atoi(customerID); err == nil {
			filters["customer_id"] = id
		}
	}

	// Get all matching orders (no pagination for export)
	orders, _, err := h.App.Deps.Orders.GetAllOrders(filters, 10000, 0) // Max 10k orders
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve orders for export", err)
		return
	}

	// Set headers for CSV download
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	filename := fmt.Sprintf("orders_export_%s.csv", timestamp)
	w.Header().Set("Content-Type", "text/csv")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filename))

	// Create CSV writer
	writer := csv.NewWriter(w)
	defer writer.Flush()

	// Write header row
	header := []string{
		"Order ID",
		"Customer ID",
		"Restaurant ID",
		"Status",
		"Subtotal",
		"Tax",
		"Delivery Fee",
		"Discount",
		"Total Amount",
		"Placed At",
		"Delivered At",
		"Created At",
	}
	if err := writer.Write(header); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to write CSV header", err)
		return
	}

	// Write data rows
	for _, order := range orders {
		placedAt := ""
		if order.PlacedAt.Valid {
			placedAt = order.PlacedAt.Time.Format("2006-01-02 15:04:05")
		}

		deliveredAt := ""
		if order.DeliveredAt.Valid {
			deliveredAt = order.DeliveredAt.Time.Format("2006-01-02 15:04:05")
		}

		row := []string{
			strconv.Itoa(order.ID),
			strconv.Itoa(order.CustomerID),
			strconv.Itoa(order.RestaurantID),
			string(order.Status),
			fmt.Sprintf("%.2f", order.SubtotalAmount),
			fmt.Sprintf("%.2f", order.TaxAmount),
			fmt.Sprintf("%.2f", order.DeliveryFee),
			fmt.Sprintf("%.2f", order.DiscountAmount),
			fmt.Sprintf("%.2f", order.TotalAmount),
			placedAt,
			deliveredAt,
			order.CreatedAt.Format("2006-01-02 15:04:05"),
		}

		if err := writer.Write(row); err != nil {
			// Log error but continue
			fmt.Printf("Error writing CSV row: %v\n", err)
		}
	}

	// CSV is automatically written to response writer
}

// GetVendorOrdersByStatus retrieves orders for vendor filtered by status
func (h *Handler) GetVendorOrdersByStatus(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "Vendor profile not found")
		return
	}

	// Get status from query parameter
	status := r.URL.Query().Get("status")
	if status == "" {
		sendError(w, http.StatusBadRequest, "Status parameter is required")
		return
	}

	// Get vendor's restaurants
	restaurants, err := h.App.Deps.Restaurants.GetByVendorID(vendor.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve restaurants", err)
		return
	}

	if len(restaurants) == 0 {
		sendSuccess(w, http.StatusOK, "No restaurants found", map[string]interface{}{
			"orders": []models.Order{},
		})
		return
	}

	// Get orders for each restaurant with the specified status
	allOrders := make([]models.Order, 0)
	for _, restaurant := range restaurants {
		orders, err := h.App.Deps.Orders.GetOrdersByStatusAndRestaurant(restaurant.ID, models.OrderStatus(status))
		if err != nil {
			// Log error but continue
			fmt.Printf("Error getting orders for restaurant %d: %v\n", restaurant.ID, err)
			continue
		}
		allOrders = append(allOrders, orders...)
	}

	sendSuccess(w, http.StatusOK, "Orders retrieved successfully", map[string]interface{}{
		"orders": allOrders,
		"status": status,
	})
}
