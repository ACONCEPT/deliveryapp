package main

import (
	"context"
	"delivery_app/backend/config"
	"delivery_app/backend/database"
	"delivery_app/backend/jobs"
	"log"

	"github.com/aws/aws-lambda-go/lambda"
)

// Handler is the Lambda function handler for updating driver availability
func Handler(ctx context.Context) error {
	// Load configuration
	conf, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
		return err
	}

	// Initialize database connection
	app, err := database.CreateApp(conf.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
		return err
	}
	defer app.Close()

	// Run the job
	return jobs.UpdateDriverAvailability(app.DB)
}

func main() {
	lambda.Start(Handler)
}