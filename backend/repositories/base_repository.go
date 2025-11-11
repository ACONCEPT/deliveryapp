package repositories

import (
	"database/sql"
	"fmt"
	"github.com/jmoiron/sqlx"
)

// BaseRepository provides common CRUD operations using Go generics
type BaseRepository[T any] struct {
	DB        *sqlx.DB
	TableName string
}

// NewBaseRepository creates a new base repository instance
func NewBaseRepository[T any](db *sqlx.DB, tableName string) *BaseRepository[T] {
	return &BaseRepository[T]{
		DB:        db,
		TableName: tableName,
	}
}

// GetByID retrieves a single entity by ID
func (r *BaseRepository[T]) GetByID(id int) (*T, error) {
	var entity T
	query := r.DB.Rebind(fmt.Sprintf("SELECT * FROM %s WHERE id = ?", r.TableName))

	err := r.DB.QueryRowx(query, id).StructScan(&entity)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("%s not found", r.TableName)
		}
		return nil, fmt.Errorf("failed to get %s: %w", r.TableName, err)
	}

	return &entity, nil
}

// GetByField retrieves a single entity by any field
func (r *BaseRepository[T]) GetByField(field string, value interface{}) (*T, error) {
	var entity T
	query := r.DB.Rebind(fmt.Sprintf("SELECT * FROM %s WHERE %s = ?", r.TableName, field))

	err := r.DB.QueryRowx(query, value).StructScan(&entity)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("%s not found", r.TableName)
		}
		return nil, fmt.Errorf("failed to get %s: %w", r.TableName, err)
	}

	return &entity, nil
}

// GetAll retrieves all entities with optional ordering
func (r *BaseRepository[T]) GetAll(orderBy string) ([]T, error) {
	entities := make([]T, 0)
	query := fmt.Sprintf("SELECT * FROM %s ORDER BY %s", r.TableName, orderBy)

	err := SelectData(r.DB, query, &entities, []interface{}{})
	if err != nil && err != sql.ErrNoRows {
		return entities, fmt.Errorf("failed to get %s: %w", r.TableName, err)
	}

	return entities, nil
}

// Delete deletes an entity by ID
func (r *BaseRepository[T]) Delete(id int) error {
	query := r.DB.Rebind(fmt.Sprintf("DELETE FROM %s WHERE id = ?", r.TableName))

	result, err := ExecuteStatement(r.DB, query, []interface{}{id})
	if err != nil {
		return fmt.Errorf("failed to delete %s: %w", r.TableName, err)
	}

	return CheckRowsAffected(result, r.TableName)
}

// Exists checks if a record exists by ID
func (r *BaseRepository[T]) Exists(id int) (bool, error) {
	var count int
	query := r.DB.Rebind(fmt.Sprintf("SELECT COUNT(*) FROM %s WHERE id = ?", r.TableName))

	err := r.DB.QueryRow(query, id).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("failed to check existence: %w", err)
	}

	return count > 0, nil
}
