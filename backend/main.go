package main

import (
	"delivery_app/backend/config"
	"delivery_app/backend/database"
	"delivery_app/backend/handlers"
	"delivery_app/backend/jobs"
	"delivery_app/backend/middleware"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	_ "github.com/joho/godotenv/autoload"
	"github.com/spf13/cobra"
)

func main() {
	// Check if running in jobs mode (CLI commands)
	if len(os.Args) > 1 && os.Args[1] == "jobs" {
		runJobsCLI()
		return
	}

	// Otherwise, run the HTTP server
	runHTTPServer()
}

// runJobsCLI runs the CLI commands for scheduled jobs
func runJobsCLI() {
	// Load configuration for all jobs
	conf, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize database connection for all jobs
	app, err := database.CreateApp(conf.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer app.Close()

	var rootCmd = &cobra.Command{
		Use:   "delivery_app",
		Short: "Delivery App CLI",
	}

	var jobsCmd = &cobra.Command{
		Use:   "jobs",
		Short: "Run scheduled job tasks",
		Long:  "Execute scheduled maintenance and cleanup jobs for the delivery app",
	}

	// Cancel unconfirmed orders command
	var cancelUnconfirmedCmd = &cobra.Command{
		Use:   "cancel-unconfirmed-orders",
		Short: "Cancel orders not confirmed by vendors within 30 minutes",
		Run: func(cmd *cobra.Command, args []string) {
			if err := jobs.CancelUnconfirmedOrders(app.DB); err != nil {
				log.Fatalf("Job failed: %v", err)
			}
			fmt.Println("Job completed successfully")
		},
	}

	// Cleanup orphaned menus command
	var cleanupMenusCmd = &cobra.Command{
		Use:   "cleanup-orphaned-menus",
		Short: "Remove menus not linked to restaurants (older than 30 days)",
		Run: func(cmd *cobra.Command, args []string) {
			if err := jobs.CleanupOrphanedMenus(app.DB); err != nil {
				log.Fatalf("Job failed: %v", err)
			}
			fmt.Println("Job completed successfully")
		},
	}

	// Archive old orders command
	var archiveOrdersCmd = &cobra.Command{
		Use:   "archive-old-orders",
		Short: "Mark old delivered/cancelled orders as inactive (older than 90 days)",
		Run: func(cmd *cobra.Command, args []string) {
			if err := jobs.ArchiveOldOrders(app.DB); err != nil {
				log.Fatalf("Job failed: %v", err)
			}
			fmt.Println("Job completed successfully")
		},
	}

	// Update driver availability command
	var updateDriversCmd = &cobra.Command{
		Use:   "update-driver-availability",
		Short: "Mark inactive drivers as unavailable (no update in 30 minutes)",
		Run: func(cmd *cobra.Command, args []string) {
			if err := jobs.UpdateDriverAvailability(app.DB); err != nil {
				log.Fatalf("Job failed: %v", err)
			}
			fmt.Println("Job completed successfully")
		},
	}

	// Add job subcommands to jobs command
	jobsCmd.AddCommand(cancelUnconfirmedCmd)
	jobsCmd.AddCommand(cleanupMenusCmd)
	jobsCmd.AddCommand(archiveOrdersCmd)
	jobsCmd.AddCommand(updateDriversCmd)

	// Add jobs command to root
	rootCmd.AddCommand(jobsCmd)

	// Execute CLI (skip "jobs" from os.Args since we already checked it)
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// runHTTPServer starts the HTTP API server
func runHTTPServer() {
	// Load configuration
	conf, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	log.Printf("Starting Delivery App API Server...")
	log.Printf("Environment: %s", conf.Environment)
	log.Printf("Server Port: %s", conf.ServerPort)

	// Validate JWT configuration
	log.Printf("=== JWT Configuration ===")
	log.Printf("JWT Secret Length: %d characters", len(conf.JWTSecret))
	log.Printf("Token Duration: %d hours", conf.TokenDuration)
	log.Printf("Environment: %s", conf.Environment)
	if conf.Environment == "development" {
		log.Printf("⚠️  Using development JWT secret - DO NOT use in production!")
		log.Printf("Secret prefix: %s...", conf.JWTSecret[:min(8, len(conf.JWTSecret))])
	}
	if len(conf.JWTSecret) < 32 {
		log.Printf("⚠️  WARNING: JWT_SECRET is shorter than recommended (32+ chars)")
	}
	log.Printf("========================")

	// Initialize database and repositories
	app, err := database.CreateApp(conf.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer app.Close()

	// Initialize handlers
	h := handlers.NewHandler(app, conf.JWTSecret)
	distanceHandler := handlers.NewDistanceHandler(h, conf.MapboxAccessToken)

	// Setup router
	router := mux.NewRouter()

	// Health check
	router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"healthy","service":"delivery_app"}`))
	}).Methods("GET")

	// API routes
	api := router.PathPrefix("/api").Subrouter()

	// Public routes (no authentication required)
	api.HandleFunc("/login", h.Login).Methods("POST", "OPTIONS")
	api.HandleFunc("/signup", h.Signup).Methods("POST", "OPTIONS")

	// Debug endpoint (development only)
	if conf.Environment == "development" {
		api.HandleFunc("/debug/token-info", h.DebugTokenInfo).Methods("GET", "OPTIONS")
		log.Println("⚠️  Debug endpoint enabled: GET /api/debug/token-info")
	}

	// Protected routes (authentication required)
	protected := api.PathPrefix("/").Subrouter()
	protected.Use(middleware.AuthMiddleware(conf.JWTSecret))

	// User profile route (example)
	protected.HandleFunc("/profile", h.GetProfile).Methods("GET", "OPTIONS")

	// Distance calculation routes (accessible by all authenticated users)
	protected.HandleFunc("/distance/estimate", distanceHandler.EstimateDistance).Methods("POST", "OPTIONS")
	protected.HandleFunc("/distance/history", distanceHandler.GetUserDistanceHistory).Methods("GET", "OPTIONS")

	// Messaging routes (accessible by all authenticated users except drivers)
	protected.HandleFunc("/messages", h.SendMessage).Methods("POST", "OPTIONS")
	protected.HandleFunc("/messages", h.GetMessages).Methods("GET", "OPTIONS")
	protected.HandleFunc("/messages/{id}", h.GetMessageByID).Methods("GET", "OPTIONS")
	protected.HandleFunc("/conversations", h.GetConversations).Methods("GET", "OPTIONS")

	// Address GET routes (accessible by all authenticated users)
	protected.HandleFunc("/addresses", h.GetAddresses).Methods("GET", "OPTIONS")
	protected.HandleFunc("/addresses/{id}", h.GetAddress).Methods("GET", "OPTIONS")

	// Restaurant GET routes (accessible by all authenticated users)
	protected.HandleFunc("/restaurants", h.GetRestaurants).Methods("GET", "OPTIONS")
	protected.HandleFunc("/restaurants/{id}", h.GetRestaurant).Methods("GET", "OPTIONS")
	protected.HandleFunc("/restaurants/{restaurant_id}/owner", h.GetRestaurantOwner).Methods("GET", "OPTIONS")

	// Public menu endpoint (customers can view active menu for a restaurant)
	protected.HandleFunc("/restaurants/{restaurant_id}/menu", h.GetRestaurantMenu).Methods("GET", "OPTIONS")

	// Admin-only routes
	adminRoutes := api.PathPrefix("/admin").Subrouter()
	adminRoutes.Use(middleware.AuthMiddleware(conf.JWTSecret))
	adminRoutes.Use(middleware.RequireUserType("admin"))

	// Vendor-restaurant relationship management (admin only)
	adminRoutes.HandleFunc("/vendor-restaurants", h.GetVendorRestaurants).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/vendor-restaurants/{id}", h.GetVendorRestaurant).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/vendor-restaurants/{id}", h.DeleteVendorRestaurant).Methods("DELETE", "OPTIONS")
	adminRoutes.HandleFunc("/restaurants/{restaurant_id}/transfer", h.TransferRestaurantOwnership).Methods("PUT", "OPTIONS")

	// Admin menu management (view all menus in system)
	adminRoutes.HandleFunc("/menus", h.GetAllMenus).Methods("GET", "OPTIONS")

	// Admin customization template management (view/create/update/delete system-wide templates)
	adminRoutes.HandleFunc("/customization-templates", h.GetAllCustomizationTemplates).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/customization-templates", h.CreateSystemWideCustomizationTemplate).Methods("POST", "OPTIONS")
	adminRoutes.HandleFunc("/customization-templates/{id}", h.UpdateSystemWideCustomizationTemplate).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/customization-templates/{id}", h.DeleteSystemWideCustomizationTemplate).Methods("DELETE", "OPTIONS")

	// Admin approval routes
	adminRoutes.HandleFunc("/approvals/vendors", h.GetPendingVendors).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/approvals/restaurants", h.GetPendingRestaurants).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/approvals/drivers", h.GetPendingDrivers).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/approvals/dashboard", h.GetApprovalDashboard).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/vendors/{id}/approve", h.ApproveVendor).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/vendors/{id}/reject", h.RejectVendor).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/restaurants/{id}/approve", h.ApproveRestaurant).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/restaurants/{id}/reject", h.RejectRestaurant).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/drivers/{id}/approve", h.ApproveDriver).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/drivers/{id}/reject", h.RejectDriver).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/approvals/history", h.GetApprovalHistory).Methods("GET", "OPTIONS")

	// Admin order routes (Phase 1: Core Order System)
	adminRoutes.HandleFunc("/orders", h.GetAllOrders).Methods("GET", "OPTIONS")
	// IMPORTANT: Register specific routes BEFORE parameterized routes to avoid conflicts
	adminRoutes.HandleFunc("/orders/stats", h.GetOrderStats).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/orders/export", h.ExportOrders).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/orders/{id}", h.GetAdminOrderDetails).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/orders/{id}", h.UpdateAdminOrder).Methods("PUT", "OPTIONS")

	// Admin system settings routes
	adminRoutes.HandleFunc("/settings", h.GetSystemSettings).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/settings/categories", h.GetCategories).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/settings/{key}", h.GetSettingByKey).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/settings/{key}", h.UpdateSetting).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/settings", h.UpdateMultipleSettings).Methods("PUT", "OPTIONS")

	// Admin distance API monitoring routes
	adminRoutes.HandleFunc("/distance/usage", distanceHandler.GetAPIUsage).Methods("GET", "OPTIONS")

	// Admin user management routes
	adminRoutes.HandleFunc("/users", h.GetAllUsers).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/users/{id}", h.DeleteUser).Methods("DELETE", "OPTIONS")

	// Admin restaurant settings management (access any restaurant's settings)
	adminRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.GetRestaurantSettings).Methods("GET", "OPTIONS")
	adminRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.UpdateRestaurantSettings).Methods("PUT", "OPTIONS")
	adminRoutes.HandleFunc("/restaurant/{restaurantId}/prep-time", h.UpdateRestaurantPrepTime).Methods("PATCH", "OPTIONS")

	// Vendor routes (admins also have access for oversight)
	vendorRoutes := api.PathPrefix("/vendor").Subrouter()
	vendorRoutes.Use(middleware.AuthMiddleware(conf.JWTSecret))
	vendorRoutes.Use(middleware.RequireUserType("vendor", "admin"))

	// Restaurant management (vendors create, update, delete their own restaurants)
	vendorRoutes.HandleFunc("/restaurants", h.CreateRestaurant).Methods("POST", "OPTIONS")
	vendorRoutes.HandleFunc("/restaurants/{id}", h.UpdateRestaurant).Methods("PUT", "OPTIONS")
	vendorRoutes.HandleFunc("/restaurants/{id}", h.DeleteRestaurant).Methods("DELETE", "OPTIONS")

	// Restaurant settings (hours of operation, prep time)
	vendorRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.GetRestaurantSettings).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.UpdateRestaurantSettings).Methods("PUT", "OPTIONS")
	vendorRoutes.HandleFunc("/restaurant/{restaurantId}/prep-time", h.UpdateRestaurantPrepTime).Methods("PATCH", "OPTIONS")

	// Menu management (vendors manage their menus)
	vendorRoutes.HandleFunc("/menus", h.CreateMenu).Methods("POST", "OPTIONS")
	vendorRoutes.HandleFunc("/menus", h.GetVendorMenus).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/menus/{id}", h.GetMenu).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/menus/{id}", h.UpdateMenu).Methods("PUT", "OPTIONS")
	vendorRoutes.HandleFunc("/menus/{id}", h.DeleteMenu).Methods("DELETE", "OPTIONS")

	// Restaurant-menu assignment (vendors assign menus to their restaurants)
	vendorRoutes.HandleFunc("/restaurants/{restaurant_id}/menus/{menu_id}", h.AssignMenuToRestaurant).Methods("POST", "OPTIONS")
	vendorRoutes.HandleFunc("/restaurants/{restaurant_id}/menus/{menu_id}", h.UnassignMenuFromRestaurant).Methods("DELETE", "OPTIONS")
	vendorRoutes.HandleFunc("/restaurants/{restaurant_id}/active-menu", h.SetActiveMenu).Methods("PUT", "OPTIONS")

	// Customization template management (vendors manage their templates and view system-wide templates)
	vendorRoutes.HandleFunc("/customization-templates", h.CreateCustomizationTemplate).Methods("POST", "OPTIONS")
	vendorRoutes.HandleFunc("/customization-templates", h.GetCustomizationTemplates).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/customization-templates/{id}", h.GetCustomizationTemplate).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/customization-templates/{id}", h.UpdateCustomizationTemplate).Methods("PUT", "OPTIONS")
	vendorRoutes.HandleFunc("/customization-templates/{id}", h.DeleteCustomizationTemplate).Methods("DELETE", "OPTIONS")

	// Image upload (vendors upload menu item images)
	vendorRoutes.HandleFunc("/upload-image", h.UploadImage).Methods("POST", "OPTIONS")
	vendorRoutes.HandleFunc("/images/{filename}", h.DeleteImage).Methods("DELETE", "OPTIONS")

	// Vendor approval status check
	vendorRoutes.HandleFunc("/approval-status", h.GetVendorApprovalStatus).Methods("GET", "OPTIONS")

	// Vendor order routes (Phase 1: Core Order System)
	vendorRoutes.HandleFunc("/orders", h.GetVendorOrders).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/orders/by-status", h.GetVendorOrdersByStatus).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/orders/stats", h.GetVendorOrderStats).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/orders/{id}", h.GetVendorOrderDetails).Methods("GET", "OPTIONS")
	vendorRoutes.HandleFunc("/orders/{id}", h.UpdateOrderStatus).Methods("PUT", "OPTIONS")

	// Customer-only routes
	customerRoutes := api.PathPrefix("/customer").Subrouter()
	customerRoutes.Use(middleware.AuthMiddleware(conf.JWTSecret))
	customerRoutes.Use(middleware.RequireUserType("customer"))

	// Customer address mutation routes (create, update, delete)
	customerRoutes.HandleFunc("/addresses", h.CreateAddress).Methods("POST", "OPTIONS")
	customerRoutes.HandleFunc("/addresses/{id}", h.UpdateAddress).Methods("PUT", "OPTIONS")
	customerRoutes.HandleFunc("/addresses/{id}", h.DeleteAddress).Methods("DELETE", "OPTIONS")
	customerRoutes.HandleFunc("/addresses/{id}/set-default", h.SetDefaultAddress).Methods("PUT", "OPTIONS")

	// Customer order routes (Phase 1: Core Order System)
	customerRoutes.HandleFunc("/orders", h.CreateOrder).Methods("POST", "OPTIONS")
	customerRoutes.HandleFunc("/orders", h.GetCustomerOrders).Methods("GET", "OPTIONS")
	customerRoutes.HandleFunc("/orders/{id}", h.GetOrderDetails).Methods("GET", "OPTIONS")
	customerRoutes.HandleFunc("/orders/{id}/cancel", h.CancelOrder).Methods("PUT", "OPTIONS")

	// Driver-only routes
	driverRoutes := api.PathPrefix("/driver").Subrouter()
	driverRoutes.Use(middleware.AuthMiddleware(conf.JWTSecret))
	driverRoutes.Use(middleware.RequireUserType("driver"))

	// Driver approval status check
	driverRoutes.HandleFunc("/approval-status", h.GetDriverApprovalStatus).Methods("GET", "OPTIONS")

	// Driver order routes (Phase 1: Core Order System)
	driverRoutes.HandleFunc("/orders/available", h.GetAvailableOrders).Methods("GET", "OPTIONS")
	driverRoutes.HandleFunc("/orders", h.GetDriverOrders).Methods("GET", "OPTIONS")
	driverRoutes.HandleFunc("/orders/{id}", h.GetDriverOrderDetails).Methods("GET", "OPTIONS")
	driverRoutes.HandleFunc("/orders/{id}/info", h.GetDriverOrderInfo).Methods("GET", "OPTIONS")
	driverRoutes.HandleFunc("/orders/{id}/assign", h.AssignOrderToDriver).Methods("POST", "OPTIONS")
	driverRoutes.HandleFunc("/orders/{id}/status", h.UpdateDriverOrderStatus).Methods("PUT", "OPTIONS")

	// Static file serving for uploaded images
	// Serve from /uploads/ directory
	uploadsPath := "uploads"
	router.PathPrefix("/uploads/").Handler(http.StripPrefix("/uploads/", http.FileServer(http.Dir(uploadsPath))))

	// Apply middleware (order matters - CORS should be first)
	router.Use(middleware.CORSMiddleware)      // Must be first to handle preflight requests
	router.Use(middleware.RecoveryMiddleware)  // Catch panics
	router.Use(middleware.LoggingMiddleware)   // Log requests

	// Start server
	addr := ":" + conf.ServerPort
	log.Printf("Server listening on %s", addr)
	log.Printf("Health check: http://localhost%s/health", addr)
	log.Printf("API endpoints: http://localhost%s/api/*", addr)

	if err := http.ListenAndServe(addr, router); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
