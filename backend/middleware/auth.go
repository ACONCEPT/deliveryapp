package middleware

import (
	"delivery_app/backend/models"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

// JWTClaims represents the JWT claims structure
type JWTClaims struct {
	UserID   int             `json:"user_id"`
	Username string          `json:"username"`
	UserType models.UserType `json:"user_type"`
	jwt.RegisteredClaims
}

// AuthMiddleware validates JWT tokens and adds user info to context
func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Extract token from Authorization header
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				http.Error(w, `{"error":"Authorization header required"}`, http.StatusUnauthorized)
				return
			}

			// Expected format: "Bearer <token>"
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || parts[0] != "Bearer" {
				http.Error(w, `{"error":"Invalid authorization header format"}`, http.StatusUnauthorized)
				return
			}

			tokenString := parts[1]

			// Parse and validate token
			token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
				// Verify signing method
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					log.Printf("[AUTH] ❌ Invalid signing method: %v (expected HMAC)", token.Header["alg"])
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}
				return []byte(jwtSecret), nil
			})

			if err != nil {
				// Classify error type for better debugging
				var errorType string
				var errorMsg string

				switch {
				case strings.Contains(err.Error(), "signature is invalid"):
					errorType = "SIGNATURE_MISMATCH"
					errorMsg = "Token signature invalid - JWT_SECRET mismatch"
					log.Printf("[AUTH] ❌ JWT signature mismatch for token: %s... (secret length: %d)",
						tokenString[:min(20, len(tokenString))], len(jwtSecret))
				case strings.Contains(err.Error(), "token is expired"):
					errorType = "TOKEN_EXPIRED"
					errorMsg = "Token has expired"
					log.Printf("[AUTH] ⏰ Expired token: %s...", tokenString[:min(20, len(tokenString))])
				case strings.Contains(err.Error(), "token is malformed"):
					errorType = "MALFORMED_TOKEN"
					errorMsg = "Token format is invalid"
					log.Printf("[AUTH] ⚠️  Malformed token: %s...", tokenString[:min(20, len(tokenString))])
				default:
					errorType = "VALIDATION_ERROR"
					errorMsg = fmt.Sprintf("Token validation failed: %v", err)
					log.Printf("[AUTH] ❌ Token validation error: %v", err)
				}

				http.Error(w, fmt.Sprintf(`{"error":"%s","error_type":"%s"}`, errorMsg, errorType), http.StatusUnauthorized)
				return
			}

			// Extract claims
			claims, ok := token.Claims.(*JWTClaims)
			if !ok || !token.Valid {
				log.Printf("[AUTH] ❌ Invalid token claims or token not valid")
				http.Error(w, `{"error":"Invalid token claims"}`, http.StatusUnauthorized)
				return
			}

			log.Printf("[AUTH] ✅ Token validated for user %s (ID: %d, type: %s)",
				claims.Username, claims.UserID, claims.UserType)

			// Create authenticated user and add to context
			authUser := &AuthenticatedUser{
				UserID:   claims.UserID,
				Username: claims.Username,
				UserType: claims.UserType,
			}

			// Add user to request context
			ctx := SetUserInContext(r.Context(), authUser)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// OptionalAuthMiddleware is like AuthMiddleware but doesn't require authentication
// If a valid token is provided, it adds user info to context
// If no token or invalid token, it continues without user info
func OptionalAuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				next.ServeHTTP(w, r)
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || parts[0] != "Bearer" {
				next.ServeHTTP(w, r)
				return
			}

			tokenString := parts[1]
			token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}
				return []byte(jwtSecret), nil
			})

			if err == nil && token.Valid {
				if claims, ok := token.Claims.(*JWTClaims); ok {
					authUser := &AuthenticatedUser{
						UserID:   claims.UserID,
						Username: claims.Username,
						UserType: claims.UserType,
					}
					ctx := SetUserInContext(r.Context(), authUser)
					next.ServeHTTP(w, r.WithContext(ctx))
					return
				}
			}

			next.ServeHTTP(w, r)
		})
	}
}

// RequireUserType middleware ensures the authenticated user has a specific user type
func RequireUserType(userTypes ...models.UserType) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			user, ok := GetUserFromContext(r.Context())
			if !ok {
				http.Error(w, `{"error":"Authentication required"}`, http.StatusUnauthorized)
				return
			}

			// Check if user type matches any of the allowed types
			allowed := false
			for _, ut := range userTypes {
				if user.UserType == ut {
					allowed = true
					break
				}
			}

			if !allowed {
				http.Error(w, `{"error":"Insufficient permissions"}`, http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
