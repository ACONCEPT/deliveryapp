package handlers

import (
	"crypto/rand"
	"delivery_app/backend/middleware"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gorilla/mux"
)

const (
	maxUploadSize = 5 * 1024 * 1024 // 5MB
	uploadsDir    = "uploads/menu-items"
)

var allowedImageTypes = map[string]bool{
	"image/jpeg": true,
	"image/jpg":  true,
	"image/png":  true,
	"image/webp": true,
	"image/gif":  true,
}

var allowedExtensions = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".webp": true,
	".gif":  true,
}

// UploadImage handles image file uploads for menu items
// POST /api/vendor/upload-image
// Requires: vendor authentication
// Accepts: multipart/form-data with 'image' field
// Returns: JSON with image URL
func (h *Handler) UploadImage(w http.ResponseWriter, r *http.Request) {
	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

	// Parse multipart form
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		sendError(w, http.StatusBadRequest, "File too large (max 5MB)")
		return
	}

	// Get file from form
	file, header, err := r.FormFile("image")
	if err != nil {
		sendError(w, http.StatusBadRequest, "No image file provided")
		return
	}
	defer file.Close()

	// Validate file size
	if header.Size > maxUploadSize {
		sendError(w, http.StatusBadRequest, "File too large (max 5MB)")
		return
	}

	// Validate content type
	contentType := header.Header.Get("Content-Type")
	if !allowedImageTypes[contentType] {
		sendError(w, http.StatusBadRequest, fmt.Sprintf(
			"Invalid file type. Allowed: jpeg, png, webp, gif. Got: %s", contentType))
		return
	}

	// Validate file extension
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !allowedExtensions[ext] {
		sendError(w, http.StatusBadRequest, fmt.Sprintf(
			"Invalid file extension. Allowed: .jpg, .png, .webp, .gif. Got: %s", ext))
		return
	}

	// Get authenticated user from context
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor ID from user
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor information", err)
		return
	}

	// Create vendor-specific directory
	vendorDir := filepath.Join(uploadsDir, fmt.Sprintf("vendor_%d", vendor.ID))
	if err := os.MkdirAll(vendorDir, 0755); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create upload directory", err)
		return
	}

	// Generate secure filename
	secureFilename, err := generateSecureFilename(ext)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to generate filename", err)
		return
	}

	// Full file path
	filePath := filepath.Join(vendorDir, secureFilename)

	// Create destination file
	dst, err := os.Create(filePath)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to save file", err)
		return
	}
	defer dst.Close()

	// Copy uploaded file to destination
	if _, err := io.Copy(dst, file); err != nil {
		// Clean up failed upload
		os.Remove(filePath)
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to save file", err)
		return
	}

	// Generate public URL
	// Format: http://localhost:8080/uploads/menu-items/vendor_1/abc123.jpg
	serverURL := getServerURL(r)
	imageURL := fmt.Sprintf("%s/%s", serverURL, filePath)

	sendSuccess(w, http.StatusOK, "Image uploaded successfully", map[string]interface{}{
		"url":          imageURL,
		"filename":     secureFilename,
		"size":         header.Size,
		"content_type": contentType,
	})
}

// DeleteImage deletes an uploaded image
// DELETE /api/vendor/images/{filename}
// Requires: vendor authentication
func (h *Handler) DeleteImage(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	filename := vars["filename"]

	// Get authenticated user
	user := middleware.MustGetUserFromContext(r.Context())

	// Get vendor ID
	vendor, err := h.App.Deps.Users.GetVendorByUserID(user.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor information", err)
		return
	}

	// Construct file path (vendor can only delete their own files)
	filePath := filepath.Join(uploadsDir, fmt.Sprintf("vendor_%d", vendor.ID), filename)

	// Security check: ensure path doesn't escape uploads directory
	absPath, err := filepath.Abs(filePath)
	if err != nil || !strings.HasPrefix(absPath, filepath.Join(uploadsDir)) {
		sendError(w, http.StatusForbidden, "Invalid file path")
		return
	}

	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		sendError(w, http.StatusNotFound, "Image not found")
		return
	}

	// Delete file
	if err := os.Remove(filePath); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to delete image", err)
		return
	}

	sendSuccess(w, http.StatusOK, "Image deleted successfully", nil)
}

// Helper: Generate secure random filename
func generateSecureFilename(ext string) (string, error) {
	// Generate 16 random bytes
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}

	// Convert to hex string
	filename := hex.EncodeToString(bytes) + ext
	return filename, nil
}

// Helper: Get server base URL from request
func getServerURL(r *http.Request) string {
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}

	host := r.Host
	if host == "" {
		host = "localhost:8080"
	}

	return fmt.Sprintf("%s://%s", scheme, host)
}
