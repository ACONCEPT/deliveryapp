package repositories

import (
	"database/sql"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// ExecuteStatement executes a SQL statement that doesn't return rows (INSERT, UPDATE, DELETE)
func ExecuteStatement(db *sqlx.DB, query string, args []interface{}) (sql.Result, error) {
	result, err := db.Exec(query, args...)
	if err != nil {
		return nil, fmt.Errorf("execute statement failed: %w", err)
	}
	return result, nil
}

// GetData executes a query that returns a single row (typically with RETURNING clause)
func GetData(db *sqlx.DB, query string, dest interface{}, args []interface{}) error {
	err := db.QueryRowx(query, args...).StructScan(dest)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("no rows returned")
		}
		return fmt.Errorf("query failed: %w", err)
	}
	return nil
}

// SelectData executes a query that returns multiple rows
func SelectData(db *sqlx.DB, query string, dest interface{}, args []interface{}) error {
	err := db.Select(dest, query, args...)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil // Return empty slice instead of error
		}
		return fmt.Errorf("select query failed: %w", err)
	}
	return nil
}

// QueryRow executes a query that returns a single row (raw query)
func QueryRow(db *sqlx.DB, query string, args []interface{}) *sqlx.Row {
	return db.QueryRowx(query, args...)
}

// Query executes a query that returns multiple rows (raw query)
func Query(db *sqlx.DB, query string, args []interface{}) (*sqlx.Rows, error) {
	rows, err := db.Queryx(query, args...)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	return rows, nil
}

// WithTransaction executes a function within a database transaction
// Automatically commits on success, rolls back on error or panic
func WithTransaction(db *sqlx.DB, fn func(*sqlx.Tx) error) error {
	tx, err := db.Beginx()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	// Ensure rollback on panic
	defer func() {
		if p := recover(); p != nil {
			tx.Rollback()
			panic(p) // Re-throw panic after rollback
		}
	}()

	// Execute the provided function
	if err := fn(tx); err != nil {
		tx.Rollback()
		return err
	}

	// Commit the transaction
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

// CheckRowsAffected validates that a SQL operation affected at least one row
// Returns error if no rows were affected or if RowsAffected() fails
func CheckRowsAffected(result sql.Result, entityName string) error {
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("%s not found", entityName)
	}

	return nil
}
