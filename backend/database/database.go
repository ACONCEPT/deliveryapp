package database

import (
	"delivery_app/backend/repositories"
	"fmt"
	"log"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

// App holds the database connection and all repositories
type App struct {
	DB   *sqlx.DB
	Deps *Dependencies
}

// Dependencies holds all repository interfaces
type Dependencies struct {
	Users              repositories.UserRepository
	Addresses          repositories.CustomerAddressRepository
	Restaurants        repositories.RestaurantRepository
	VendorRestaurants  repositories.VendorRestaurantRepository
	Menus              repositories.MenuRepository
	Approvals          repositories.ApprovalRepository
	Orders             repositories.OrderRepository
	Config             repositories.ConfigRepository
	SystemSettings     repositories.SystemSettingsRepository
}

// CreateApp initializes the database connection and creates all repositories
func CreateApp(databaseURL string) (*App, error) {
	// Connect to database
	db, err := sqlx.Connect("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	log.Println("✓ Database connection established")

	// Initialize repositories
	deps := &Dependencies{
		Users:             repositories.NewUserRepository(db),
		Addresses:         repositories.NewCustomerAddressRepository(db),
		Restaurants:       repositories.NewRestaurantRepository(db),
		VendorRestaurants: repositories.NewVendorRestaurantRepository(db),
		Menus:             repositories.NewMenuRepository(db),
		Approvals:         repositories.NewApprovalRepository(db),
		Orders:            repositories.NewOrderRepository(db),
		Config:            repositories.NewConfigRepository(db),
		SystemSettings:    repositories.NewSystemSettingsRepository(db),
	}

	return &App{
		DB:   db,
		Deps: deps,
	}, nil
}

// Close closes the database connection
func (a *App) Close() error {
	if a.DB != nil {
		log.Println("Closing database connection")
		return a.DB.Close()
	}
	return nil
}
