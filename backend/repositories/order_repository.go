package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"

	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

// OrderRepository defines the interface for order data access
type OrderRepository interface {
	// Order CRUD
	CreateOrder(order *models.Order) error
	CreateOrderWithItems(order *models.Order, items []models.OrderItem) error
	GetOrderByID(id int) (*models.Order, error)
	GetOrdersByCustomerID(customerID int, limit, offset int) ([]models.OrderSummary, error)
	GetOrdersByRestaurantID(restaurantID int, limit, offset int) ([]models.Order, error)
	GetOrdersByRestaurantIDs(restaurantIDs []int, limit, offset int) ([]models.Order, error)
	GetOrdersByRestaurantIDsAndStatus(restaurantIDs []int, status models.OrderStatus, limit, offset int) ([]models.Order, error)
	GetOrdersByDriverID(driverID int, limit, offset int) ([]models.OrderSummary, error)
	GetOrdersByStatus(status models.OrderStatus, limit, offset int) ([]models.Order, error)
	GetOrdersByStatusAndRestaurant(restaurantID int, status models.OrderStatus) ([]models.Order, error)
	GetAllOrders(filters map[string]interface{}, limit, offset int) ([]models.Order, int, error)
	UpdateOrder(order *models.Order) error
	UpdateOrderStatus(orderID int, status models.OrderStatus) error
	UpdateOrderStatusWithHistory(orderID int, status models.OrderStatus, notes string, userID int) error
	CancelOrder(orderID int, reason string) error

	// Order Items
	AddItemToOrder(orderID int, item *models.OrderItem) error
	UpdateOrderItem(item *models.OrderItem) error
	RemoveOrderItem(itemID int) error
	GetOrderItems(orderID int) ([]models.OrderItem, error)

	// Status History
	GetOrderStatusHistory(orderID int) ([]models.OrderStatusHistory, error)
	CreateStatusHistory(history *models.OrderStatusHistory) error

	// Statistics
	GetOrderStats(filters map[string]interface{}) (*models.OrderStats, error)
	GetOrderCountByStatus() (map[string]int, error)

	// Driver-specific methods
	GetAvailableOrdersForDriver(limit, offset int) ([]models.Order, error)
	AssignDriverToOrder(orderID, driverID int) error
	GetDriverOrderInfo(orderID int) (*models.DriverOrderInfoResponse, error)
}

// orderRepository is the concrete implementation
type orderRepository struct {
	db *sqlx.DB
}

// NewOrderRepository creates a new order repository
func NewOrderRepository(db *sqlx.DB) OrderRepository {
	return &orderRepository{db: db}
}

// ============================================================================
// ORDER CRUD OPERATIONS
// ============================================================================

// CreateOrder creates a new order
func (r *orderRepository) CreateOrder(order *models.Order) error {
	// Fetch restaurant name if not already provided
	if order.RestaurantName == "" {
		var restaurantName string
		err := r.db.Get(&restaurantName, "SELECT name FROM restaurants WHERE id = $1", order.RestaurantID)
		if err != nil {
			return fmt.Errorf("failed to fetch restaurant name: %w", err)
		}
		order.RestaurantName = restaurantName
	}

	query := `
		INSERT INTO orders (
			customer_id, restaurant_id, restaurant_name, delivery_address_id, driver_id,
			status, subtotal_amount, tax_amount, delivery_fee, discount_amount, total_amount,
			placed_at, special_instructions, estimated_preparation_time, estimated_delivery_time
		) VALUES (
			$1, $2, $3, $4, $5,
			$6, $7, $8, $9, $10, $11,
			$12, $13, $14, $15
		)
		RETURNING id, created_at, updated_at, is_active
	`

	err := r.db.QueryRowx(
		query,
		order.CustomerID, order.RestaurantID, order.RestaurantName, nullInt64(order.DeliveryAddressID), nullInt64(order.DriverID),
		order.Status, order.SubtotalAmount, order.TaxAmount, order.DeliveryFee, order.DiscountAmount, order.TotalAmount,
		nullTime(order.PlacedAt), nullString(order.SpecialInstructions), nullInt64(order.EstimatedPreparationTime), nullTime(order.EstimatedDeliveryTime),
	).Scan(&order.ID, &order.CreatedAt, &order.UpdatedAt, &order.IsActive)

	if err != nil {
		return fmt.Errorf("failed to create order: %w", err)
	}

	return nil
}

// CreateOrderWithItems creates an order with its items in a transaction
func (r *orderRepository) CreateOrderWithItems(order *models.Order, items []models.OrderItem) error {
	tx, err := r.db.Beginx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Fetch restaurant name if not already provided
	if order.RestaurantName == "" {
		var restaurantName string
		err := tx.Get(&restaurantName, "SELECT name FROM restaurants WHERE id = $1", order.RestaurantID)
		if err != nil {
			return fmt.Errorf("failed to fetch restaurant name: %w", err)
		}
		order.RestaurantName = restaurantName
	}

	// Create order
	orderQuery := `
		INSERT INTO orders (
			customer_id, restaurant_id, restaurant_name, delivery_address_id, driver_id,
			status, subtotal_amount, tax_amount, delivery_fee, discount_amount, total_amount,
			placed_at, special_instructions, estimated_preparation_time, estimated_delivery_time
		) VALUES (
			$1, $2, $3, $4, $5,
			$6, $7, $8, $9, $10, $11,
			$12, $13, $14, $15
		)
		RETURNING id, created_at, updated_at, is_active
	`

	err = tx.QueryRowx(
		orderQuery,
		order.CustomerID, order.RestaurantID, order.RestaurantName, nullInt64(order.DeliveryAddressID), nullInt64(order.DriverID),
		order.Status, order.SubtotalAmount, order.TaxAmount, order.DeliveryFee, order.DiscountAmount, order.TotalAmount,
		nullTime(order.PlacedAt), nullString(order.SpecialInstructions), nullInt64(order.EstimatedPreparationTime), nullTime(order.EstimatedDeliveryTime),
	).Scan(&order.ID, &order.CreatedAt, &order.UpdatedAt, &order.IsActive)

	if err != nil {
		return fmt.Errorf("failed to create order: %w", err)
	}

	// Create order items
	itemQuery := `
		INSERT INTO order_items (
			order_id, menu_item_name, menu_item_description, price_at_time, quantity, customizations, line_total
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
		RETURNING id, created_at, updated_at
	`

	for i := range items {
		items[i].OrderID = order.ID

		// Convert customizations to JSONB
		var customizationsJSON []byte
		if items[i].Customizations != nil {
			customizationsJSON = items[i].Customizations
		} else {
			customizationsJSON = []byte("{}")
		}

		err = tx.QueryRowx(
			itemQuery,
			items[i].OrderID, items[i].MenuItemName, nullString(items[i].MenuItemDescription),
			items[i].PriceAtTime, items[i].Quantity, customizationsJSON, items[i].LineTotal,
		).Scan(&items[i].ID, &items[i].CreatedAt, &items[i].UpdatedAt)

		if err != nil {
			return fmt.Errorf("failed to create order item: %w", err)
		}
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

// GetOrderByID retrieves an order by ID
func (r *orderRepository) GetOrderByID(id int) (*models.Order, error) {
	var order models.Order
	query := `
		SELECT * FROM orders WHERE id = $1
	`

	err := r.db.Get(&order, query, id)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("order not found")
		}
		return nil, fmt.Errorf("failed to get order: %w", err)
	}

	return &order, nil
}

// GetOrdersByCustomerID retrieves orders for a specific customer
func (r *orderRepository) GetOrdersByCustomerID(customerID int, limit, offset int) ([]models.OrderSummary, error) {
	orders := make([]models.OrderSummary, 0) // Initialize empty slice instead of nil
	query := `
		SELECT
			id,
			customer_id,
			restaurant_id,
			restaurant_name,
			status,
			total_amount,
			(SELECT COUNT(*) FROM order_items WHERE order_id = orders.id) as item_count,
			placed_at,
			estimated_delivery_time as estimated_time,
			created_at
		FROM orders
		WHERE customer_id = $1 AND is_active = true
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	err := r.db.Select(&orders, query, customerID, limit, offset)
	if err != nil {
		return orders, fmt.Errorf("failed to get customer orders: %w", err)
	}

	return orders, nil
}

// GetOrdersByRestaurantID retrieves orders for a specific restaurant
func (r *orderRepository) GetOrdersByRestaurantID(restaurantID int, limit, offset int) ([]models.Order, error) {
	orders := make([]models.Order, 0) // Initialize empty slice instead of nil
	query := `
		SELECT * FROM orders
		WHERE restaurant_id = $1 AND is_active = true
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	err := r.db.Select(&orders, query, restaurantID, limit, offset)
	if err != nil {
		return orders, fmt.Errorf("failed to get restaurant orders: %w", err)
	}

	return orders, nil
}

// GetOrdersByRestaurantIDs retrieves orders for multiple restaurants (for vendors with multiple restaurants)
func (r *orderRepository) GetOrdersByRestaurantIDs(restaurantIDs []int, limit, offset int) ([]models.Order, error) {
	if len(restaurantIDs) == 0 {
		return []models.Order{}, nil
	}

	orders := make([]models.Order, 0) // Initialize empty slice instead of nil
	query := `
		SELECT * FROM orders
		WHERE restaurant_id = ANY($1) AND is_active = true
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	err := r.db.Select(&orders, query, pq.Array(restaurantIDs), limit, offset)
	if err != nil {
		return orders, fmt.Errorf("failed to get orders for restaurants: %w", err)
	}

	return orders, nil
}

// GetOrdersByRestaurantIDsAndStatus retrieves orders for multiple restaurants filtered by status
func (r *orderRepository) GetOrdersByRestaurantIDsAndStatus(restaurantIDs []int, status models.OrderStatus, limit, offset int) ([]models.Order, error) {
	if len(restaurantIDs) == 0 {
		return []models.Order{}, nil
	}

	orders := make([]models.Order, 0) // Initialize empty slice instead of nil
	query := `
		SELECT * FROM orders
		WHERE restaurant_id = ANY($1) AND status = $2 AND is_active = true
		ORDER BY created_at DESC
		LIMIT $3 OFFSET $4
	`

	err := r.db.Select(&orders, query, pq.Array(restaurantIDs), status, limit, offset)
	if err != nil {
		return orders, fmt.Errorf("failed to get orders for restaurants with status: %w", err)
	}

	return orders, nil
}

// GetOrdersByDriverID retrieves orders assigned to a specific driver with restaurant names
func (r *orderRepository) GetOrdersByDriverID(driverID int, limit, offset int) ([]models.OrderSummary, error) {
	orders := make([]models.OrderSummary, 0) // Initialize empty slice instead of nil
	query := `
		SELECT
			id,
			customer_id,
			restaurant_id,
			restaurant_name,
			status,
			total_amount,
			(SELECT COUNT(*) FROM order_items WHERE order_id = orders.id) as item_count,
			placed_at,
			estimated_delivery_time as estimated_time,
			created_at
		FROM orders
		WHERE driver_id = $1 AND is_active = true
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	err := r.db.Select(&orders, query, driverID, limit, offset)
	if err != nil {
		return orders, fmt.Errorf("failed to get driver orders: %w", err)
	}

	return orders, nil
}

// GetOrdersByStatus retrieves orders by status
func (r *orderRepository) GetOrdersByStatus(status models.OrderStatus, limit, offset int) ([]models.Order, error) {
	orders := make([]models.Order, 0) // Initialize empty slice instead of nil
	query := `
		SELECT * FROM orders
		WHERE status = $1 AND is_active = true
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`

	err := r.db.Select(&orders, query, status, limit, offset)
	if err != nil {
		return orders, fmt.Errorf("failed to get orders by status: %w", err)
	}

	return orders, nil
}

// GetOrdersByStatusAndRestaurant retrieves orders by status and restaurant
func (r *orderRepository) GetOrdersByStatusAndRestaurant(restaurantID int, status models.OrderStatus) ([]models.Order, error) {
	orders := make([]models.Order, 0) // Initialize empty slice instead of nil
	query := `
		SELECT * FROM orders
		WHERE restaurant_id = $1 AND status = $2 AND is_active = true
		ORDER BY created_at DESC
	`

	err := r.db.Select(&orders, query, restaurantID, status)
	if err != nil {
		return orders, fmt.Errorf("failed to get orders by status and restaurant: %w", err)
	}

	return orders, nil
}

// GetAllOrders retrieves all orders with optional filters (for admin)
func (r *orderRepository) GetAllOrders(filters map[string]interface{}, limit, offset int) ([]models.Order, int, error) {
	orders := make([]models.Order, 0) // Initialize empty slice instead of nil
	var totalCount int

	// Build dynamic query based on filters
	baseQuery := `SELECT * FROM orders WHERE is_active = true`
	countQuery := `SELECT COUNT(*) FROM orders WHERE is_active = true`
	args := []interface{}{}
	argPos := 1

	// Apply filters
	if status, ok := filters["status"].(string); ok && status != "" {
		baseQuery += fmt.Sprintf(" AND status = $%d", argPos)
		countQuery += fmt.Sprintf(" AND status = $%d", argPos)
		args = append(args, status)
		argPos++
	}

	if restaurantID, ok := filters["restaurant_id"].(int); ok && restaurantID > 0 {
		baseQuery += fmt.Sprintf(" AND restaurant_id = $%d", argPos)
		countQuery += fmt.Sprintf(" AND restaurant_id = $%d", argPos)
		args = append(args, restaurantID)
		argPos++
	}

	if customerID, ok := filters["customer_id"].(int); ok && customerID > 0 {
		baseQuery += fmt.Sprintf(" AND customer_id = $%d", argPos)
		countQuery += fmt.Sprintf(" AND customer_id = $%d", argPos)
		args = append(args, customerID)
		argPos++
	}

	// Get total count
	err := r.db.Get(&totalCount, countQuery, args...)
	if err != nil {
		return orders, 0, fmt.Errorf("failed to get total count: %w", err)
	}

	// Add pagination
	baseQuery += ` ORDER BY created_at DESC`
	baseQuery += fmt.Sprintf(" LIMIT $%d OFFSET $%d", argPos, argPos+1)
	args = append(args, limit, offset)

	// Execute query
	err = r.db.Select(&orders, baseQuery, args...)
	if err != nil {
		return orders, 0, fmt.Errorf("failed to get orders: %w", err)
	}

	return orders, totalCount, nil
}

// UpdateOrder updates an existing order
func (r *orderRepository) UpdateOrder(order *models.Order) error {
	query := `
		UPDATE orders SET
			restaurant_id = $2,
			restaurant_name = $3,
			delivery_address_id = $4,
			driver_id = $5,
			status = $6,
			subtotal_amount = $7,
			tax_amount = $8,
			delivery_fee = $9,
			discount_amount = $10,
			total_amount = $11,
			placed_at = $12,
			confirmed_at = $13,
			ready_at = $14,
			delivered_at = $15,
			cancelled_at = $16,
			special_instructions = $17,
			cancellation_reason = $18,
			estimated_preparation_time = $19,
			estimated_delivery_time = $20,
			is_active = $21
		WHERE id = $1
		RETURNING updated_at
	`

	err := r.db.QueryRowx(
		query,
		order.ID, order.RestaurantID, order.RestaurantName, nullInt64(order.DeliveryAddressID), nullInt64(order.DriverID),
		order.Status, order.SubtotalAmount, order.TaxAmount, order.DeliveryFee, order.DiscountAmount, order.TotalAmount,
		nullTime(order.PlacedAt), nullTime(order.ConfirmedAt), nullTime(order.ReadyAt), nullTime(order.DeliveredAt), nullTime(order.CancelledAt),
		nullString(order.SpecialInstructions), nullString(order.CancellationReason),
		nullInt64(order.EstimatedPreparationTime), nullTime(order.EstimatedDeliveryTime), order.IsActive,
	).Scan(&order.UpdatedAt)

	if err != nil {
		return fmt.Errorf("failed to update order: %w", err)
	}

	return nil
}

// UpdateOrderStatus updates only the order status
func (r *orderRepository) UpdateOrderStatus(orderID int, status models.OrderStatus) error {
	query := `
		UPDATE orders SET
			status = $2,
			confirmed_at = CASE WHEN $2 = 'confirmed' THEN CURRENT_TIMESTAMP ELSE confirmed_at END,
			ready_at = CASE WHEN $2 = 'ready' THEN CURRENT_TIMESTAMP ELSE ready_at END,
			delivered_at = CASE WHEN $2 = 'delivered' THEN CURRENT_TIMESTAMP ELSE delivered_at END,
			cancelled_at = CASE WHEN $2 = 'cancelled' THEN CURRENT_TIMESTAMP ELSE cancelled_at END
		WHERE id = $1
	`

	result, err := r.db.Exec(query, orderID, status)
	if err != nil {
		return fmt.Errorf("failed to update order status: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("order not found")
	}

	return nil
}

// UpdateOrderStatusWithHistory updates order status and creates history entry
func (r *orderRepository) UpdateOrderStatusWithHistory(orderID int, status models.OrderStatus, notes string, userID int) error {
	tx, err := r.db.Beginx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Get current status
	var currentStatus string
	err = tx.Get(&currentStatus, `SELECT status FROM orders WHERE id = $1`, orderID)
	if err != nil {
		return fmt.Errorf("failed to get current status: %w", err)
	}

	// Update status
	statusQuery := `
		UPDATE orders SET
			status = $2::order_status,
			confirmed_at = CASE WHEN $2::order_status = 'confirmed' THEN CURRENT_TIMESTAMP ELSE confirmed_at END,
			ready_at = CASE WHEN $2::order_status = 'ready' THEN CURRENT_TIMESTAMP ELSE ready_at END,
			delivered_at = CASE WHEN $2::order_status = 'delivered' THEN CURRENT_TIMESTAMP ELSE delivered_at END,
			cancelled_at = CASE WHEN $2::order_status = 'cancelled' THEN CURRENT_TIMESTAMP ELSE cancelled_at END
		WHERE id = $1
	`

	_, err = tx.Exec(statusQuery, orderID, status)
	if err != nil {
		return fmt.Errorf("failed to update order status: %w", err)
	}

	// Create history entry
	historyQuery := `
		INSERT INTO order_status_history (order_id, user_id, from_status, to_status, notes)
		VALUES ($1, $2, $3, $4, $5)
	`

	_, err = tx.Exec(historyQuery, orderID, userID, currentStatus, status, nullString(models.NullString{NullString: sql.NullString{String: notes, Valid: notes != ""}}))
	if err != nil {
		return fmt.Errorf("failed to create status history: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

// CancelOrder cancels an order with a reason
func (r *orderRepository) CancelOrder(orderID int, reason string) error {
	query := `
		UPDATE orders SET
			status = 'cancelled',
			cancelled_at = CURRENT_TIMESTAMP,
			cancellation_reason = $2
		WHERE id = $1
	`

	result, err := r.db.Exec(query, orderID, reason)
	if err != nil {
		return fmt.Errorf("failed to cancel order: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("order not found")
	}

	return nil
}

// ============================================================================
// ORDER ITEMS OPERATIONS
// ============================================================================

// AddItemToOrder adds an item to an existing order
func (r *orderRepository) AddItemToOrder(orderID int, item *models.OrderItem) error {
	query := `
		INSERT INTO order_items (
			order_id, menu_item_name, menu_item_description, price_at_time, quantity, customizations, line_total
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
		RETURNING id, created_at, updated_at
	`

	customizationsJSON := item.Customizations
	if customizationsJSON == nil {
		customizationsJSON = []byte("{}")
	}

	err := r.db.QueryRowx(
		query,
		orderID, item.MenuItemName, nullString(item.MenuItemDescription),
		item.PriceAtTime, item.Quantity, customizationsJSON, item.LineTotal,
	).Scan(&item.ID, &item.CreatedAt, &item.UpdatedAt)

	if err != nil {
		return fmt.Errorf("failed to add item to order: %w", err)
	}

	item.OrderID = orderID
	return nil
}

// UpdateOrderItem updates an existing order item
func (r *orderRepository) UpdateOrderItem(item *models.OrderItem) error {
	query := `
		UPDATE order_items SET
			menu_item_name = $2,
			menu_item_description = $3,
			price_at_time = $4,
			quantity = $5,
			customizations = $6,
			line_total = $7
		WHERE id = $1
		RETURNING updated_at
	`

	customizationsJSON := item.Customizations
	if customizationsJSON == nil {
		customizationsJSON = []byte("{}")
	}

	err := r.db.QueryRowx(
		query,
		item.ID, item.MenuItemName, nullString(item.MenuItemDescription),
		item.PriceAtTime, item.Quantity, customizationsJSON, item.LineTotal,
	).Scan(&item.UpdatedAt)

	if err != nil {
		return fmt.Errorf("failed to update order item: %w", err)
	}

	return nil
}

// RemoveOrderItem removes an item from an order
func (r *orderRepository) RemoveOrderItem(itemID int) error {
	query := `DELETE FROM order_items WHERE id = $1`

	result, err := r.db.Exec(query, itemID)
	if err != nil {
		return fmt.Errorf("failed to remove order item: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("order item not found")
	}

	return nil
}

// GetOrderItems retrieves all items for an order
func (r *orderRepository) GetOrderItems(orderID int) ([]models.OrderItem, error) {
	items := make([]models.OrderItem, 0)
	query := `
		SELECT * FROM order_items
		WHERE order_id = $1
		ORDER BY created_at ASC
	`

	err := r.db.Select(&items, query, orderID)
	if err != nil && err != sql.ErrNoRows {
		return items, fmt.Errorf("failed to get order items: %w", err)
	}

	return items, nil
}

// ============================================================================
// STATUS HISTORY OPERATIONS
// ============================================================================

// GetOrderStatusHistory retrieves the status history for an order
func (r *orderRepository) GetOrderStatusHistory(orderID int) ([]models.OrderStatusHistory, error) {
	history := make([]models.OrderStatusHistory, 0)
	query := `
		SELECT * FROM order_status_history
		WHERE order_id = $1
		ORDER BY created_at ASC
	`

	err := r.db.Select(&history, query, orderID)
	if err != nil && err != sql.ErrNoRows {
		return history, fmt.Errorf("failed to get order status history: %w", err)
	}

	return history, nil
}

// CreateStatusHistory creates a status history entry
func (r *orderRepository) CreateStatusHistory(history *models.OrderStatusHistory) error {
	query := `
		INSERT INTO order_status_history (order_id, user_id, from_status, to_status, notes, metadata)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`

	var metadataJSON interface{}
	if history.Metadata != nil {
		metadataJSON = *history.Metadata
	} else {
		metadataJSON = nil
	}

	err := r.db.QueryRowx(
		query,
		history.OrderID, nullInt64(history.UserID), nullString(history.FromStatus),
		history.ToStatus, nullString(history.Notes), metadataJSON,
	).Scan(&history.ID, &history.CreatedAt)

	if err != nil {
		return fmt.Errorf("failed to create status history: %w", err)
	}

	return nil
}

// ============================================================================
// STATISTICS OPERATIONS
// ============================================================================

// GetOrderStats retrieves order statistics
func (r *orderRepository) GetOrderStats(filters map[string]interface{}) (*models.OrderStats, error) {
	var stats models.OrderStats

	// Build dynamic query
	baseWhere := "WHERE is_active = true"
	args := []interface{}{}
	argPos := 1

	if restaurantID, ok := filters["restaurant_id"].(int); ok && restaurantID > 0 {
		baseWhere += fmt.Sprintf(" AND restaurant_id = $%d", argPos)
		args = append(args, restaurantID)
		argPos++
	}

	if restaurantIDs, ok := filters["restaurant_ids"].([]int); ok && len(restaurantIDs) > 0 {
		baseWhere += fmt.Sprintf(" AND restaurant_id = ANY($%d)", argPos)
		args = append(args, pq.Array(restaurantIDs))
		argPos++
	}

	if customerID, ok := filters["customer_id"].(int); ok && customerID > 0 {
		baseWhere += fmt.Sprintf(" AND customer_id = $%d", argPos)
		args = append(args, customerID)
		argPos++
	}

	query := fmt.Sprintf(`
		SELECT
			COUNT(*) as total_orders,
			COUNT(*) FILTER (WHERE status = 'pending') as pending_orders,
			COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed_orders,
			COUNT(*) FILTER (WHERE status = 'delivered') as delivered_orders,
			COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
			COALESCE(SUM(total_amount) FILTER (WHERE status = 'delivered'), 0) as total_revenue,
			COALESCE(AVG(total_amount) FILTER (WHERE status = 'delivered'), 0) as average_order_value
		FROM orders
		%s
	`, baseWhere)

	err := r.db.QueryRowx(query, args...).Scan(
		&stats.TotalOrders,
		&stats.PendingOrders,
		&stats.ConfirmedOrders,
		&stats.DeliveredOrders,
		&stats.CancelledOrders,
		&stats.TotalRevenue,
		&stats.AverageOrderValue,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get order stats: %w", err)
	}

	return &stats, nil
}

// GetOrderCountByStatus retrieves order counts grouped by status
func (r *orderRepository) GetOrderCountByStatus() (map[string]int, error) {
	counts := make(map[string]int)

	query := `
		SELECT status, COUNT(*) as count
		FROM orders
		WHERE is_active = true
		GROUP BY status
	`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get order counts by status: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var status string
		var count int
		if err := rows.Scan(&status, &count); err != nil {
			return nil, fmt.Errorf("failed to scan row: %w", err)
		}
		counts[status] = count
	}

	return counts, nil
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

func nullString(ns models.NullString) interface{} {
	if ns.Valid {
		return ns.String
	}
	return nil
}

func nullInt64(ni models.NullInt64) interface{} {
	if ni.Valid {
		return ni.Int64
	}
	return nil
}

func nullTime(nt models.NullTime) interface{} {
	if nt.Valid {
		return nt.Time
	}
	return nil
}

func jsonToRawMessage(data interface{}) (json.RawMessage, error) {
	if data == nil {
		return json.RawMessage("{}"), nil
	}
	bytes, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}
	return bytes, nil
}

// ============================================================================
// DRIVER-SPECIFIC OPERATIONS
// ============================================================================

// GetAvailableOrdersForDriver retrieves orders that are ready for driver assignment
// Shows orders in 'confirmed', 'preparing', or 'ready' status that haven't been assigned to a driver yet
// Prioritizes 'ready' orders first, then 'preparing', then 'confirmed'
func (r *orderRepository) GetAvailableOrdersForDriver(limit, offset int) ([]models.Order, error) {
	orders := make([]models.Order, 0) // Initialize empty slice instead of nil
	query := `
		SELECT * FROM orders
		WHERE status IN ('ready', 'preparing', 'confirmed')
		  AND driver_id IS NULL
		  AND is_active = true
		ORDER BY
		  CASE status
		    WHEN 'ready' THEN 1      -- Prioritize ready orders first
		    WHEN 'preparing' THEN 2  -- Then preparing
		    WHEN 'confirmed' THEN 3  -- Finally confirmed
		  END,
		  created_at ASC  -- Oldest first within each status tier
		LIMIT $1 OFFSET $2
	`

	err := r.db.Select(&orders, query, limit, offset)
	if err != nil {
		return orders, fmt.Errorf("failed to get available orders: %w", err)
	}

	return orders, nil
}

// AssignDriverToOrder assigns a driver to an order and updates status to driver_assigned
// Uses atomic check-and-set to prevent race conditions
func (r *orderRepository) AssignDriverToOrder(orderID, driverID int) error {
	tx, err := r.db.Beginx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Atomic check-and-set: only update if order is ready and unassigned
	// This prevents race conditions when multiple drivers try to assign simultaneously
	var updatedStatus string
	var updatedDriverID int64
	err = tx.QueryRow(`
		UPDATE orders
		SET driver_id = $2,
		    status = 'driver_assigned'
		WHERE id = $1
		  AND status = 'ready'
		  AND driver_id IS NULL
		  AND is_active = true
		RETURNING status, driver_id
	`, orderID, driverID).Scan(&updatedStatus, &updatedDriverID)

	if err == sql.ErrNoRows {
		// Update failed - determine why for better error message using custom error types
		var currentStatus string
		var currentDriverID sql.NullInt64
		var isActive bool
		checkErr := r.db.QueryRow(`
			SELECT status, driver_id, is_active
			FROM orders
			WHERE id = $1
		`, orderID).Scan(&currentStatus, &currentDriverID, &isActive)

		if checkErr == sql.ErrNoRows {
			return models.ErrOrderNotFound
		}
		if !isActive {
			return models.ErrOrderNotActive
		}
		if currentDriverID.Valid {
			return models.ErrOrderAlreadyAssigned
		}
		if currentStatus != string(models.OrderStatusReady) {
			return models.NewOrderNotReadyError(currentStatus)
		}
		// Shouldn't reach here, but just in case
		return models.ErrOrderNotAvailable
	}

	if err != nil {
		return fmt.Errorf("failed to assign driver: %w", err)
	}

	// Create status history entry
	historyQuery := `
		INSERT INTO order_status_history (order_id, user_id, from_status, to_status, notes)
		VALUES ($1, (SELECT user_id FROM drivers WHERE id = $2), $3, $4, $5)
	`

	_, err = tx.Exec(
		historyQuery,
		orderID,
		driverID,
		models.OrderStatusReady,
		models.OrderStatusDriverAssigned,
		"Driver self-assigned to order",
	)

	if err != nil {
		return fmt.Errorf("failed to create status history: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

// GetDriverOrderInfo retrieves driver-specific order information including item count and addresses
func (r *orderRepository) GetDriverOrderInfo(orderID int) (*models.DriverOrderInfoResponse, error) {
	query := `
		SELECT
			o.id as order_id,
			o.status,
			COUNT(oi.id) as item_count,
			o.estimated_preparation_time,
			o.total_amount,
			r.name as restaurant_name,
			COALESCE(r.address_line_1 || ', ' || r.city || ', ' || r.state || ' ' || r.zip_code, '') as restaurant_address,
			COALESCE(ca.address_line_1 || ', ' || ca.city || ', ' || ca.state || ' ' || ca.zip_code, '') as delivery_address,
			o.special_instructions,
			o.placed_at,
			o.estimated_delivery_time,
			r.latitude as restaurant_lat,
			r.longitude as restaurant_lng,
			ca.latitude as delivery_lat,
			ca.longitude as delivery_lng
		FROM orders o
		LEFT JOIN order_items oi ON o.id = oi.order_id
		LEFT JOIN restaurants r ON o.restaurant_id = r.id
		LEFT JOIN customer_addresses ca ON o.delivery_address_id = ca.id
		WHERE o.id = $1
		GROUP BY o.id, r.name, r.address_line_1, r.city, r.state, r.zip_code,
				 ca.address_line_1, ca.city, ca.state, ca.zip_code,
				 r.latitude, r.longitude, ca.latitude, ca.longitude
	`

	var (
		response           models.DriverOrderInfoResponse
		prepTime           sql.NullInt64
		specialInstructions sql.NullString
		placedAt           sql.NullTime
		estimatedDelivery  sql.NullTime
		restaurantLat      sql.NullFloat64
		restaurantLng      sql.NullFloat64
		deliveryLat        sql.NullFloat64
		deliveryLng        sql.NullFloat64
	)

	err := r.db.QueryRow(query, orderID).Scan(
		&response.OrderID,
		&response.Status,
		&response.ItemCount,
		&prepTime,
		&response.TotalAmount,
		&response.RestaurantName,
		&response.RestaurantAddress,
		&response.DeliveryAddress,
		&specialInstructions,
		&placedAt,
		&estimatedDelivery,
		&restaurantLat,
		&restaurantLng,
		&deliveryLat,
		&deliveryLng,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("order not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get driver order info: %w", err)
	}

	// Convert nullable fields
	if prepTime.Valid {
		prepTimeInt := int(prepTime.Int64)
		response.EstimatedPrepTime = &prepTimeInt
	}
	if specialInstructions.Valid {
		response.SpecialInstructions = &specialInstructions.String
	}
	if placedAt.Valid {
		response.PlacedAt = &placedAt.Time
	}
	if estimatedDelivery.Valid {
		response.EstimatedDeliveryTime = &estimatedDelivery.Time
	}

	// Calculate estimated drive time based on distance (if coordinates available)
	// Using simple estimation: assume average speed of 30 mph in city driving
	// This is a placeholder - in production you'd use a real routing API like Google Maps
	if restaurantLat.Valid && restaurantLng.Valid && deliveryLat.Valid && deliveryLng.Valid {
		// Simple straight-line distance approximation
		// At mid-latitudes, 1 degree latitude ≈ 69 miles
		latDiff := deliveryLat.Float64 - restaurantLat.Float64
		lngDiff := deliveryLng.Float64 - restaurantLng.Float64

		// Pythagorean theorem for approximate distance
		// Note: This is simplified and assumes flat earth (good enough for short distances)
		distanceDegrees := latDiff*latDiff + lngDiff*lngDiff
		
		// Convert to miles (rough approximation)
		// For small distances, we can estimate sqrt(x) ≈ x/2 when x is small
		var distanceMiles float64
		if distanceDegrees < 0.01 {
			distanceMiles = 69.0 * distanceDegrees * 0.7 // rough sqrt approximation
		} else {
			// For larger distances, use a better approximation
			// This is still simplified but more accurate
			distanceMiles = 69.0 * distanceDegrees
		}

		// Estimate drive time: 30 mph = 0.5 miles per minute
		// Add 5 minutes buffer for traffic/stops
		driveTimeMinutes := int(distanceMiles*2) + 5
		if driveTimeMinutes < 1 {
			driveTimeMinutes = 1 // minimum 1 minute
		}
		if driveTimeMinutes > 120 {
			driveTimeMinutes = 120 // cap at 2 hours
		}
		response.EstimatedDriveTime = &driveTimeMinutes
	}

	return &response, nil
}
