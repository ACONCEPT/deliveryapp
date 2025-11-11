package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

// MigrationRequest represents the input for migration
type MigrationRequest struct {
	Action string `json:"action"` // "migrate", "status", "drop", or "seed"
}

// MigrationResponse represents the output of migration
type MigrationResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Details string `json:"details,omitempty"`
}

// DBCredentials represents the structure of credentials in Secrets Manager
type DBCredentials struct {
	Username    string `json:"username"`
	Password    string `json:"password"`
	Host        string `json:"host"`
	Port        int    `json:"port"`
	DBName      string `json:"dbname"`
	DatabaseURL string `json:"database_url"`
}

// Global database connection
var db *sqlx.DB

func init() {
	// Get database URL from Secrets Manager or environment variable
	databaseURL, err := getDatabaseURL()
	if err != nil {
		log.Fatalf("Failed to get database URL: %v", err)
	}

	// Connect to database
	db, err = sqlx.Connect("postgres", databaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Test connection
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	// Set timezone to UTC
	_, err = db.Exec("SET TIME ZONE 'UTC'")
	if err != nil {
		log.Printf("[WARNING] Failed to set database timezone to UTC: %v", err)
	}

	log.Println("✓ Database connection established")
}

// getDatabaseURL retrieves the database URL from AWS Secrets Manager or falls back to env var
func getDatabaseURL() (string, error) {
	// Check if SECRET_ARN is provided (preferred method)
	secretARN := os.Getenv("SECRET_ARN")
	if secretARN != "" {
		log.Printf("Fetching database credentials from Secrets Manager: %s", secretARN)
		return getDatabaseURLFromSecretsManager(secretARN)
	}

	// Fallback to DATABASE_URL environment variable
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL != "" {
		log.Println("Using DATABASE_URL from environment variable")
		return databaseURL, nil
	}

	return "", fmt.Errorf("neither SECRET_ARN nor DATABASE_URL environment variable is set")
}

// getDatabaseURLFromSecretsManager fetches credentials from AWS Secrets Manager
func getDatabaseURLFromSecretsManager(secretARN string) (string, error) {
	// Load AWS config
	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return "", fmt.Errorf("unable to load AWS SDK config: %w", err)
	}

	// Create Secrets Manager client
	client := secretsmanager.NewFromConfig(cfg)

	// Retrieve the secret
	result, err := client.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
		SecretId: &secretARN,
	})
	if err != nil {
		return "", fmt.Errorf("failed to retrieve secret: %w", err)
	}

	// Parse the secret JSON
	var creds DBCredentials
	if err := json.Unmarshal([]byte(*result.SecretString), &creds); err != nil {
		return "", fmt.Errorf("failed to parse secret JSON: %w", err)
	}

	// Always construct database URL from individual fields with proper URL encoding
	// This avoids issues with special characters in passwords

	// URL-encode the password to handle special characters
	encodedPassword := url.QueryEscape(creds.Password)

	databaseURL := fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=require",
		creds.Username, encodedPassword, creds.Host, creds.Port, creds.DBName)

	log.Println("✓ Constructed database URL from Secrets Manager credentials with URL-encoded password")
	return databaseURL, nil
}

// HandleRequest handles the Lambda invocation
func HandleRequest(ctx context.Context, request MigrationRequest) (MigrationResponse, error) {
	action := request.Action
	if action == "" {
		action = "migrate" // Default action
	}

	log.Printf("Running migration action: %s", action)

	switch action {
	case "migrate":
		return runMigration(ctx)
	case "status":
		return checkStatus(ctx)
	case "drop":
		return dropAll(ctx)
	case "seed":
		return seedData(ctx)
	default:
		return MigrationResponse{
			Success: false,
			Message: fmt.Sprintf("Unknown action: %s", action),
		}, nil
	}
}

// runMigration runs the complete schema migration
func runMigration(ctx context.Context) (MigrationResponse, error) {
	log.Println("Starting database migration...")

	// First drop all existing objects
	log.Println("Dropping all existing database objects...")
	if err := executeSQLFile(dropAllSQL); err != nil {
		log.Printf("Warning: Drop all failed (might be first run): %v", err)
	}

	// Run schema migration
	log.Println("Running schema migration...")
	if err := executeSQLFile(schemaSQL); err != nil {
		return MigrationResponse{
			Success: false,
			Message: "Migration failed",
			Details: err.Error(),
		}, fmt.Errorf("migration failed: %w", err)
	}

	// Get table count
	tableCount, err := getTableCount()
	if err != nil {
		log.Printf("Warning: Failed to get table count: %v", err)
		tableCount = -1
	}

	message := fmt.Sprintf("Migration completed successfully. Tables created: %d", tableCount)
	log.Println(message)

	return MigrationResponse{
		Success: true,
		Message: message,
		Details: getTableList(),
	}, nil
}

// checkStatus checks the database status
func checkStatus(ctx context.Context) (MigrationResponse, error) {
	log.Println("Checking database status...")

	tableCount, err := getTableCount()
	if err != nil {
		return MigrationResponse{
			Success: false,
			Message: "Failed to check status",
			Details: err.Error(),
		}, err
	}

	tableList := getTableList()

	return MigrationResponse{
		Success: true,
		Message: fmt.Sprintf("Database has %d tables", tableCount),
		Details: tableList,
	}, nil
}

// dropAll drops all database objects
func dropAll(ctx context.Context) (MigrationResponse, error) {
	log.Println("Dropping all database objects...")

	if err := executeSQLFile(dropAllSQL); err != nil {
		return MigrationResponse{
			Success: false,
			Message: "Drop all failed",
			Details: err.Error(),
		}, err
	}

	return MigrationResponse{
		Success: true,
		Message: "All database objects dropped successfully",
	}, nil
}

// seedData seeds initial test data
func seedData(ctx context.Context) (MigrationResponse, error) {
	log.Println("Seeding test data...")

	// The schema.sql already includes seed data
	// This is a placeholder for additional seeding if needed

	return MigrationResponse{
		Success: true,
		Message: "Test data already seeded via schema.sql",
	}, nil
}

// executeSQLFile executes SQL from embedded string
func executeSQLFile(sqlContent string) error {
	_, err := db.Exec(sqlContent)
	return err
}

// getTableCount returns the number of tables in the public schema
func getTableCount() (int, error) {
	var count int
	err := db.Get(&count, `
		SELECT COUNT(*)
		FROM information_schema.tables
		WHERE table_schema = 'public'
		AND table_type = 'BASE TABLE'
	`)
	return count, err
}

// getTableList returns a list of all tables
func getTableList() string {
	rows, err := db.Query(`
		SELECT tablename
		FROM pg_tables
		WHERE schemaname = 'public'
		ORDER BY tablename
	`)
	if err != nil {
		return fmt.Sprintf("Error getting table list: %v", err)
	}
	defer rows.Close()

	var tables []string
	for rows.Next() {
		var table string
		if err := rows.Scan(&table); err != nil {
			continue
		}
		tables = append(tables, table)
	}

	if len(tables) == 0 {
		return "No tables found"
	}

	result := "Tables:\n"
	for _, table := range tables {
		result += fmt.Sprintf("  - %s\n", table)
	}
	return result
}

func main() {
	lambda.Start(HandleRequest)
}
