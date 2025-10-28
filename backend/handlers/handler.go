package handlers

import (
	"delivery_app/backend/database"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// Handler holds the application dependencies
type Handler struct {
	App       *database.App
	JWTSecret string
}

// PaginationParams holds pagination parameters
type PaginationParams struct {
	Page    int
	PerPage int
	Offset  int
}

// NewHandler creates a new Handler instance
func NewHandler(app *database.App, jwtSecret string) *Handler {
	return &Handler{
		App:       app,
		JWTSecret: jwtSecret,
	}
}

// sendJSON sends a JSON response
func sendJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// sendError sends an error response
func sendError(w http.ResponseWriter, status int, message string) {
	sendJSON(w, status, map[string]interface{}{
		"success": false,
		"message": message,
	})
}

// sendErrorWithContext sends an error response with logging for 500 errors
func sendErrorWithContext(w http.ResponseWriter, r *http.Request, status int, message string, err error) {
	// Log internal server errors with full context
	if status == http.StatusInternalServerError {
		log.Printf("[ERROR] 500 Internal Server Error\n"+
			"  Message: %s\n"+
			"  Path: %s %s\n"+
			"  Remote: %s\n"+
			"  Error: %v",
			message,
			r.Method,
			r.URL.Path,
			r.RemoteAddr,
			err,
		)
	}

	sendJSON(w, status, map[string]interface{}{
		"success": false,
		"message": message,
	})
}

// sendSuccess sends a success response
func sendSuccess(w http.ResponseWriter, status int, message string, data interface{}) {
	sendJSON(w, status, map[string]interface{}{
		"success": true,
		"message": message,
		"data":    data,
	})
}

// sendSuccessWithDebug sends a success response with full response body logging (TEMPORARY - for debugging)
func sendSuccessWithDebug(w http.ResponseWriter, r *http.Request, status int, message string, data interface{}) {
	response := map[string]interface{}{
		"success": true,
		"message": message,
		"data":    data,
	}

	// Log the full response body for debugging
	responseJSON, _ := json.MarshalIndent(response, "", "  ")
	log.Printf("[DEBUG] Successful Response\n"+
		"  Path: %s %s\n"+
		"  Status: %d\n"+
		"  Response Body:\n%s",
		r.Method,
		r.URL.Path,
		status,
		string(responseJSON),
	)

	sendJSON(w, status, response)
}

// GetIntParam extracts and validates an integer parameter from URL
func (h *Handler) GetIntParam(r *http.Request, paramName string) (int, error) {
	vars := mux.Vars(r)
	valueStr, ok := vars[paramName]
	if !ok {
		return 0, fmt.Errorf("missing parameter: %s", paramName)
	}

	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: must be a number", paramName)
	}

	return value, nil
}

// ParsePagination extracts pagination parameters from request
func (h *Handler) ParsePagination(r *http.Request) PaginationParams {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}

	perPage, _ := strconv.Atoi(r.URL.Query().Get("per_page"))
	if perPage < 1 || perPage > 100 {
		perPage = 20
	}

	offset := (page - 1) * perPage

	return PaginationParams{
		Page:    page,
		PerPage: perPage,
		Offset:  offset,
	}
}
