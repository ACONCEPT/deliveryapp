package middleware

import (
	"context"
	"delivery_app/backend/models"
)

// ContextKey is a custom type for context keys to avoid collisions
type ContextKey string

const (
	// UserContextKey is the key for storing user info in context
	UserContextKey ContextKey = "user"
)

// AuthenticatedUser holds the authenticated user's information
type AuthenticatedUser struct {
	UserID   int
	Username string
	UserType models.UserType
}

// SetUserInContext adds the authenticated user to the context
func SetUserInContext(ctx context.Context, user *AuthenticatedUser) context.Context {
	return context.WithValue(ctx, UserContextKey, user)
}

// GetUserFromContext retrieves the authenticated user from the context
func GetUserFromContext(ctx context.Context) (*AuthenticatedUser, bool) {
	user, ok := ctx.Value(UserContextKey).(*AuthenticatedUser)
	return user, ok
}

// MustGetUserFromContext retrieves the authenticated user from context
// Panics if user is not found (should only be used after auth middleware)
func MustGetUserFromContext(ctx context.Context) *AuthenticatedUser {
	user, ok := GetUserFromContext(ctx)
	if !ok {
		panic("user not found in context - auth middleware may not be applied")
	}
	return user
}
