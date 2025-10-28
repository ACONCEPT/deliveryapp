package handlers

import (
	"delivery_app/backend/models"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// JWTClaims represents the JWT claims
type JWTClaims struct {
	UserID   int              `json:"user_id"`
	Username string           `json:"username"`
	UserType models.UserType  `json:"user_type"`
	jwt.RegisteredClaims
}

// generateToken generates a JWT token for a user
func (h *Handler) generateToken(user *models.User, duration int) (string, error) {
	expirationTime := time.Now().Add(time.Duration(duration) * time.Hour)

	claims := &JWTClaims{
		UserID:   user.ID,
		Username: user.Username,
		UserType: user.UserType,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "delivery_app",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(h.JWTSecret))

	if err != nil {
		log.Printf("[AUTH] ❌ Failed to sign token for user %s (ID: %d): %v",
			user.Username, user.ID, err)
		return "", err
	}

	log.Printf("[AUTH] ✅ Generated token for user %s (ID: %d, type: %s) - expires in %d hours",
		user.Username, user.ID, user.UserType, duration)

	return tokenString, nil
}

// Login handles user login
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req models.LoginRequest

	// Decode request body
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate credentials
	user, err := h.App.Deps.Users.ValidateCredentials(req.Username, req.Password)
	if err != nil {
		sendError(w, http.StatusUnauthorized, "Invalid username or password")
		return
	}

	// Generate token
	token, err := h.generateToken(user, 72) // 72 hours default
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to generate token", err)
		return
	}

	// Fetch user profile based on user type using the consolidated repository method
	profile, err := h.App.Deps.Users.GetUserProfile(user.ID, user.UserType)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to fetch profile", err)
		return
	}

	// Send response
	response := models.LoginResponse{
		Success: true,
		Message: "Login successful",
		Token:   token,
		User:    user,
		Profile: profile,
	}

	sendJSON(w, http.StatusOK, response)
}

// Signup handles user registration
func (h *Handler) Signup(w http.ResponseWriter, r *http.Request) {
	var req models.SignupRequest

	// Decode request body
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate user type
	validUserType := false
	validTypes := []models.UserType{
		models.UserTypeCustomer,
		models.UserTypeVendor,
		models.UserTypeDriver,
		models.UserTypeAdmin,
	}
	for _, t := range validTypes {
		if req.UserType == t {
			validUserType = true
			break
		}
	}
	if !validUserType {
		sendError(w, http.StatusBadRequest, "Invalid user type")
		return
	}

	// Check if user already exists
	exists, err := h.App.Deps.Users.UserExists(req.Username, req.Email)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to check user existence", err)
		return
	}
	if exists {
		sendError(w, http.StatusConflict, "Username or email already exists")
		return
	}

	// Create user
	user := &models.User{
		Username:     req.Username,
		Email:        req.Email,
		PasswordHash: req.Password, // Will be hashed in repository
		UserType:     req.UserType,
		Status:       models.UserStatusActive,
	}

	if err := h.App.Deps.Users.Create(user); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create user", err)
		return
	}

	// Create user profile based on type
	var profileErr error
	switch req.UserType {
	case models.UserTypeCustomer:
		customer := &models.Customer{
			FullName: req.FullName,
			Phone:    stringPtr(req.Phone),
		}
		profileErr = h.App.Deps.Users.CreateCustomerProfile(user.ID, customer)

	case models.UserTypeVendor:
		vendor := &models.Vendor{
			BusinessName: req.BusinessName,
			Description:  stringPtr(req.Description),
			Phone:        stringPtr(req.Phone),
		}
		profileErr = h.App.Deps.Users.CreateVendorProfile(user.ID, vendor)

	case models.UserTypeDriver:
		driver := &models.Driver{
			FullName:      req.FullName,
			Phone:         req.Phone,
			VehicleType:   stringPtr(req.VehicleType),
			VehiclePlate:  stringPtr(req.VehiclePlate),
			LicenseNumber: stringPtr(req.LicenseNumber),
		}
		profileErr = h.App.Deps.Users.CreateDriverProfile(user.ID, driver)

	case models.UserTypeAdmin:
		admin := &models.Admin{
			FullName: req.FullName,
			Phone:    stringPtr(req.Phone),
			Role:     stringPtr("User"),
		}
		profileErr = h.App.Deps.Users.CreateAdminProfile(user.ID, admin)
	}

	if profileErr != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "User created but failed to create profile", profileErr)
		return
	}

	// Send response
	response := models.SignupResponse{
		Success: true,
		Message: "User registered successfully",
		UserID:  user.ID,
	}

	sendJSON(w, http.StatusCreated, response)
}

// stringPtr converts a string to a pointer
func stringPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// DebugTokenInfo provides token information for debugging (development only)
func (h *Handler) DebugTokenInfo(w http.ResponseWriter, r *http.Request) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		sendError(w, http.StatusBadRequest, "No Authorization header provided")
		return
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || parts[0] != "Bearer" {
		sendError(w, http.StatusBadRequest, "Invalid Authorization header format")
		return
	}

	tokenString := parts[1]

	// Parse without validation to inspect claims
	token, _ := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(h.JWTSecret), nil
	})

	info := map[string]interface{}{
		"token_preview": tokenString[:min(30, len(tokenString))] + "...",
		"token_length":  len(tokenString),
		"secret_length": len(h.JWTSecret),
		"secret_preview": h.JWTSecret[:min(8, len(h.JWTSecret))] + "...",
	}

	if token != nil && token.Claims != nil {
		if claims, ok := token.Claims.(*JWTClaims); ok {
			info["claims"] = map[string]interface{}{
				"user_id":    claims.UserID,
				"username":   claims.Username,
				"user_type":  claims.UserType,
				"issuer":     claims.Issuer,
				"issued_at":  claims.IssuedAt,
				"expires_at": claims.ExpiresAt,
			}
		}
	}

	sendJSON(w, http.StatusOK, info)
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
