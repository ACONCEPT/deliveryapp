package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

// CreateCustomizationTemplate handles POST /api/vendor/customization-templates
func (h *Handler) CreateCustomizationTemplate(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Decode request
	var req models.CreateCustomizationTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate name is not empty
	if strings.TrimSpace(req.Name) == "" {
		sendError(w, http.StatusBadRequest, "Template name is required")
		return
	}

	// Validate customization_config is valid JSON
	var configTest map[string]interface{}
	if err := json.Unmarshal([]byte(req.CustomizationConfig), &configTest); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid customization_config JSON")
		return
	}

	// Validate customization_config size (max 100KB)
	const maxConfigSize = 100 * 1024 // 100KB
	if len(req.CustomizationConfig) > maxConfigSize {
		sendError(w, http.StatusBadRequest,
			"Customization config too large: "+strconv.Itoa(len(req.CustomizationConfig)/1024)+"KB (max 100KB)")
		return
	}

	// Create template with vendor ownership
	description := req.Description
	template := &models.MenuCustomizationTemplate{
		Name:                req.Name,
		Description:         &description,
		CustomizationConfig: req.CustomizationConfig,
		VendorID:            &vendor.ID,
		IsActive:            req.IsActive,
	}

	if err := h.App.Deps.CustomizationTemplates.Create(template); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create customization template", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "Customization template created successfully",
		"data":    template,
	}
	sendJSON(w, http.StatusCreated, response)
}

// CreateSystemWideCustomizationTemplate handles POST /api/admin/customization-templates
func (h *Handler) CreateSystemWideCustomizationTemplate(w http.ResponseWriter, r *http.Request) {
	// Decode request
	var req models.CreateCustomizationTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate name is not empty
	if strings.TrimSpace(req.Name) == "" {
		sendError(w, http.StatusBadRequest, "Template name is required")
		return
	}

	// Validate customization_config is valid JSON
	var configTest map[string]interface{}
	if err := json.Unmarshal([]byte(req.CustomizationConfig), &configTest); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid customization_config JSON")
		return
	}

	// Validate customization_config size (max 100KB)
	const maxConfigSize = 100 * 1024 // 100KB
	if len(req.CustomizationConfig) > maxConfigSize {
		sendError(w, http.StatusBadRequest,
			"Customization config too large: "+strconv.Itoa(len(req.CustomizationConfig)/1024)+"KB (max 100KB)")
		return
	}

	// Create system-wide template (vendor_id = NULL)
	description := req.Description
	template := &models.MenuCustomizationTemplate{
		Name:                req.Name,
		Description:         &description,
		CustomizationConfig: req.CustomizationConfig,
		VendorID:            nil, // System-wide template
		IsActive:            req.IsActive,
	}

	if err := h.App.Deps.CustomizationTemplates.Create(template); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to create system-wide customization template", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "System-wide customization template created successfully",
		"data":    template,
	}
	sendJSON(w, http.StatusCreated, response)
}

// GetCustomizationTemplates handles GET /api/vendor/customization-templates
func (h *Handler) GetCustomizationTemplates(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Get templates for vendor (includes vendor's own templates + system-wide templates)
	templates, err := h.App.Deps.CustomizationTemplates.GetByVendorID(vendor.ID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to fetch customization templates", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"data":    templates,
	}
	sendJSON(w, http.StatusOK, response)
}

// GetAllCustomizationTemplates handles GET /api/admin/customization-templates
func (h *Handler) GetAllCustomizationTemplates(w http.ResponseWriter, r *http.Request) {
	// Get all templates (admin can see everything)
	templates, err := h.App.Deps.CustomizationTemplates.GetAll()
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to fetch customization templates", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"data":    templates,
	}
	sendJSON(w, http.StatusOK, response)
}

// GetCustomizationTemplate handles GET /api/vendor/customization-templates/{id}
func (h *Handler) GetCustomizationTemplate(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get template ID from URL
	vars := mux.Vars(r)
	templateID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid template ID")
		return
	}

	// Get template
	template, err := h.App.Deps.CustomizationTemplates.GetByID(templateID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusNotFound, "Customization template not found", err)
		return
	}

	// Verify vendor can access this template (owns it or it's system-wide)
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Check if vendor owns template or if it's system-wide (vendor_id IS NULL)
	if template.VendorID != nil && *template.VendorID != vendor.ID {
		sendError(w, http.StatusForbidden, "Access denied to this customization template")
		return
	}

	response := map[string]interface{}{
		"success": true,
		"data":    template,
	}
	sendJSON(w, http.StatusOK, response)
}

// UpdateCustomizationTemplate handles PUT /api/vendor/customization-templates/{id}
func (h *Handler) UpdateCustomizationTemplate(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get template ID from URL
	vars := mux.Vars(r)
	templateID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid template ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Get existing template
	template, err := h.App.Deps.CustomizationTemplates.GetByID(templateID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusNotFound, "Customization template not found", err)
		return
	}

	// Verify vendor ownership
	if err := h.App.Deps.CustomizationTemplates.VerifyVendorOwnership(templateID, vendor.ID); err != nil {
		sendError(w, http.StatusForbidden, "Access denied to this customization template")
		return
	}

	// Decode update request
	var req models.UpdateCustomizationTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Apply partial updates
	if req.Name != nil {
		if strings.TrimSpace(*req.Name) == "" {
			sendError(w, http.StatusBadRequest, "Template name cannot be empty")
			return
		}
		template.Name = *req.Name
	}

	if req.Description != nil {
		template.Description = req.Description
	}

	if req.CustomizationConfig != nil {
		// Validate JSON
		var configTest map[string]interface{}
		if err := json.Unmarshal([]byte(*req.CustomizationConfig), &configTest); err != nil {
			sendError(w, http.StatusBadRequest, "Invalid customization_config JSON")
			return
		}

		// Validate size
		const maxConfigSize = 100 * 1024 // 100KB
		if len(*req.CustomizationConfig) > maxConfigSize {
			sendError(w, http.StatusBadRequest,
				"Customization config too large: "+strconv.Itoa(len(*req.CustomizationConfig)/1024)+"KB (max 100KB)")
			return
		}

		template.CustomizationConfig = *req.CustomizationConfig
	}

	if req.IsActive != nil {
		template.IsActive = *req.IsActive
	}

	// Update template
	if err := h.App.Deps.CustomizationTemplates.Update(template); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update customization template", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "Customization template updated successfully",
		"data":    template,
	}
	sendJSON(w, http.StatusOK, response)
}

// UpdateSystemWideCustomizationTemplate handles PUT /api/admin/customization-templates/{id}
func (h *Handler) UpdateSystemWideCustomizationTemplate(w http.ResponseWriter, r *http.Request) {
	// Get template ID from URL
	vars := mux.Vars(r)
	templateID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid template ID")
		return
	}

	// Get existing template
	template, err := h.App.Deps.CustomizationTemplates.GetByID(templateID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusNotFound, "Customization template not found", err)
		return
	}

	// Decode update request
	var req models.UpdateCustomizationTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Apply partial updates
	if req.Name != nil {
		if strings.TrimSpace(*req.Name) == "" {
			sendError(w, http.StatusBadRequest, "Template name cannot be empty")
			return
		}
		template.Name = *req.Name
	}

	if req.Description != nil {
		template.Description = req.Description
	}

	if req.CustomizationConfig != nil {
		// Validate JSON
		var configTest map[string]interface{}
		if err := json.Unmarshal([]byte(*req.CustomizationConfig), &configTest); err != nil {
			sendError(w, http.StatusBadRequest, "Invalid customization_config JSON")
			return
		}

		// Validate size
		const maxConfigSize = 100 * 1024 // 100KB
		if len(*req.CustomizationConfig) > maxConfigSize {
			sendError(w, http.StatusBadRequest,
				"Customization config too large: "+strconv.Itoa(len(*req.CustomizationConfig)/1024)+"KB (max 100KB)")
			return
		}

		template.CustomizationConfig = *req.CustomizationConfig
	}

	if req.IsActive != nil {
		template.IsActive = *req.IsActive
	}

	// Update template (admin can update any template)
	if err := h.App.Deps.CustomizationTemplates.Update(template); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to update customization template", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "Customization template updated successfully",
		"data":    template,
	}
	sendJSON(w, http.StatusOK, response)
}

// DeleteCustomizationTemplate handles DELETE /api/vendor/customization-templates/{id}
func (h *Handler) DeleteCustomizationTemplate(w http.ResponseWriter, r *http.Request) {
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get template ID from URL
	vars := mux.Vars(r)
	templateID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid template ID")
		return
	}

	// Get vendor profile
	vendor, err := h.App.Deps.Users.GetVendorByUserID(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to get vendor profile", err)
		return
	}

	// Verify vendor ownership
	if err := h.App.Deps.CustomizationTemplates.VerifyVendorOwnership(templateID, vendor.ID); err != nil {
		sendError(w, http.StatusForbidden, "Access denied to this customization template")
		return
	}

	// Delete template
	if err := h.App.Deps.CustomizationTemplates.Delete(templateID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to delete customization template", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "Customization template deleted successfully",
	}
	sendJSON(w, http.StatusOK, response)
}

// DeleteSystemWideCustomizationTemplate handles DELETE /api/admin/customization-templates/{id}
func (h *Handler) DeleteSystemWideCustomizationTemplate(w http.ResponseWriter, r *http.Request) {
	// Get template ID from URL
	vars := mux.Vars(r)
	templateID, err := strconv.Atoi(vars["id"])
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid template ID")
		return
	}

	// Delete template (admin can delete any template)
	if err := h.App.Deps.CustomizationTemplates.Delete(templateID); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to delete customization template", err)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"message": "Customization template deleted successfully",
	}
	sendJSON(w, http.StatusOK, response)
}
