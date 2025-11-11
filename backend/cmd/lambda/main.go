package main

import (
	"context"
	"delivery_app/backend/config"
	"delivery_app/backend/database"
	"delivery_app/backend/handlers"
	"delivery_app/backend/middleware"
	"log"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/awslabs/aws-lambda-go-api-proxy/httpadapter"
	"github.com/gorilla/mux"
)

// Global router initialization (happens outside handler for reuse across invocations)
var httpLambda *httpadapter.HandlerAdapter

func init() {
	// Load configuration
	conf, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize database connection
	app, err := database.CreateApp(conf.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	// Create handler with dependencies
	h := handlers.NewHandler(app, conf.JWTSecret)

	// Setup router with all routes
	router := mux.NewRouter()

	// Apply middleware
	router.Use(middleware.CORSMiddleware)
	router.Use(middleware.RecoveryMiddleware)
	router.Use(middleware.LoggingMiddleware)

	// Health check (public)
	router.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy"}`))
	}).Methods("GET", "OPTIONS")

	// Public routes
	router.HandleFunc("/api/login", h.Login).Methods("POST", "OPTIONS")
	router.HandleFunc("/api/signup", h.Signup).Methods("POST", "OPTIONS")

	// Protected routes (require authentication)
	api := router.PathPrefix("/api").Subrouter()
	api.Use(middleware.AuthMiddleware(conf.JWTSecret))

	// User profile
	api.HandleFunc("/profile", h.GetProfile).Methods("GET", "OPTIONS")

	// Addresses (read operations)
	api.HandleFunc("/addresses", h.GetAddresses).Methods("GET", "OPTIONS")
	api.HandleFunc("/addresses/{id}", h.GetAddress).Methods("GET", "OPTIONS")

	// Restaurants (read operations)
	api.HandleFunc("/restaurants", h.GetRestaurants).Methods("GET", "OPTIONS")
	api.HandleFunc("/restaurants/{id}", h.GetRestaurant).Methods("GET", "OPTIONS")
	api.HandleFunc("/restaurants/{restaurant_id}/owner", h.GetRestaurantOwner).Methods("GET", "OPTIONS")

	// Admin-only routes
	admin := api.PathPrefix("/admin").Subrouter()
	admin.Use(middleware.RequireUserType("admin"))
	admin.HandleFunc("/vendor-restaurants", h.GetVendorRestaurants).Methods("GET", "OPTIONS")
	admin.HandleFunc("/vendor-restaurants/{id}", h.GetVendorRestaurant).Methods("GET", "OPTIONS")
	admin.HandleFunc("/vendor-restaurants/{id}", h.DeleteVendorRestaurant).Methods("DELETE", "OPTIONS")
	admin.HandleFunc("/restaurants/{restaurant_id}/transfer", h.TransferRestaurantOwnership).Methods("PUT", "OPTIONS")

	// Vendor-only routes
	vendor := api.PathPrefix("/vendor").Subrouter()
	vendor.Use(middleware.RequireUserType("vendor"))
	vendor.HandleFunc("/restaurants", h.CreateRestaurant).Methods("POST", "OPTIONS")
	vendor.HandleFunc("/restaurants/{id}", h.UpdateRestaurant).Methods("PUT", "OPTIONS")
	vendor.HandleFunc("/restaurants/{id}", h.DeleteRestaurant).Methods("DELETE", "OPTIONS")

	// Customer-only routes
	customer := api.PathPrefix("/customer").Subrouter()
	customer.Use(middleware.RequireUserType("customer"))
	customer.HandleFunc("/addresses", h.CreateAddress).Methods("POST", "OPTIONS")
	customer.HandleFunc("/addresses/{id}", h.UpdateAddress).Methods("PUT", "OPTIONS")
	customer.HandleFunc("/addresses/{id}", h.DeleteAddress).Methods("DELETE", "OPTIONS")
	customer.HandleFunc("/addresses/{id}/set-default", h.SetDefaultAddress).Methods("PUT", "OPTIONS")

	// Initialize Lambda adapter with the router
	httpLambda = httpadapter.New(router)
}

// Handler is the Lambda function handler
func Handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// Use the pre-initialized adapter
	return httpLambda.ProxyWithContext(ctx, req)
}

func main() {
	lambda.Start(Handler)
}
