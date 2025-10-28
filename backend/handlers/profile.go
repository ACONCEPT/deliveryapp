package handlers

import (
	"delivery_app/backend/middleware"
	"net/http"
)

// GetProfile returns the authenticated user's profile
func (h *Handler) GetProfile(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user from context
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		sendError(w, http.StatusUnauthorized, "Authentication required")
		return
	}

	// Fetch user details from database
	dbUser, err := h.App.Deps.Users.GetByID(user.UserID)
	if err != nil {
		sendError(w, http.StatusNotFound, "User not found")
		return
	}

	// Fetch profile based on user type using the consolidated repository method
	profile, err := h.App.Deps.Users.GetUserProfile(user.UserID, user.UserType)
	if err != nil {
		sendError(w, http.StatusNotFound, "Profile not found")
		return
	}

	// Send response
	response := map[string]interface{}{
		"success":   true,
		"user":      dbUser,
		"profile":   profile,
		"auth_info": map[string]interface{}{
			"user_id":   user.UserID,
			"username":  user.Username,
			"user_type": user.UserType,
		},
	}

	sendJSON(w, http.StatusOK, response)
}
