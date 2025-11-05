package handlers

import (
	"delivery_app/backend/middleware"
	"delivery_app/backend/models"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// SendMessage handles sending a message from one user to another
func (h *Handler) SendMessage(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user from context
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Decode request body
	var req models.SendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate that content is not empty or just whitespace
	if len(req.Content) == 0 || len(req.Content) > 5000 {
		sendError(w, http.StatusBadRequest, "Message content must be between 1 and 5000 characters")
		return
	}

	// Validate that users can send messages to each other
	canSend, err := h.App.Deps.Messages.CanUsersSendMessages(authUser.UserID, req.RecipientID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to validate messaging permissions", err)
		return
	}

	if !canSend {
		sendError(w, http.StatusForbidden, "You are not allowed to send messages to this user")
		return
	}

	// Create the message
	message := &models.Message{
		SenderID:    authUser.UserID,
		RecipientID: req.RecipientID,
		Content:     req.Content,
	}

	if err := h.App.Deps.Messages.Create(message); err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to send message", err)
		return
	}

	// Send success response
	response := models.SendMessageResponse{
		Success: true,
		Message: "Message sent successfully",
		Data:    message,
	}

	sendJSON(w, http.StatusCreated, response)
}

// GetMessages retrieves messages between the authenticated user and another user
func (h *Handler) GetMessages(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user from context
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get other user ID from query parameters
	otherUserIDStr := r.URL.Query().Get("user_id")
	if otherUserIDStr == "" {
		sendError(w, http.StatusBadRequest, "user_id query parameter is required")
		return
	}

	otherUserID, err := strconv.Atoi(otherUserIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid user_id parameter")
		return
	}

	// Get pagination parameters
	limitStr := r.URL.Query().Get("limit")
	offsetStr := r.URL.Query().Get("offset")

	limit := 50 // Default limit
	offset := 0 // Default offset

	if limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
			if limit > 100 {
				limit = 100 // Max limit
			}
		}
	}

	if offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	// Calculate page number for response (1-indexed)
	page := (offset / limit) + 1

	// Validate that users can message each other
	canMessage, err := h.App.Deps.Messages.CanUsersSendMessages(authUser.UserID, otherUserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to validate messaging permissions", err)
		return
	}

	if !canMessage {
		sendError(w, http.StatusForbidden, "You are not allowed to view messages with this user")
		return
	}

	// Get messages
	messages, total, err := h.App.Deps.Messages.GetMessagesBetweenUsers(authUser.UserID, otherUserID, limit, offset)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve messages", err)
		return
	}

	// Mark unread messages as read (messages sent TO the authenticated user)
	for _, msg := range messages {
		if msg.RecipientID == authUser.UserID && msg.ReadAt == nil {
			_ = h.App.Deps.Messages.MarkAsRead(msg.ID)
		}
	}

	// Send response
	response := models.GetMessagesResponse{
		Success: true,
		Message: fmt.Sprintf("Retrieved %d messages", len(messages)),
		Data:    messages,
		Total:   total,
		Page:    page,
		Limit:   limit,
	}

	sendJSON(w, http.StatusOK, response)
}

// GetConversations retrieves all conversations for the authenticated user
func (h *Handler) GetConversations(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user from context
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get conversations
	conversations, err := h.App.Deps.Messages.GetConversations(authUser.UserID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusInternalServerError, "Failed to retrieve conversations", err)
		return
	}

	// Send response
	response := models.GetConversationsResponse{
		Success: true,
		Message: fmt.Sprintf("Retrieved %d conversations", len(conversations)),
		Data:    conversations,
	}

	sendJSON(w, http.StatusOK, response)
}

// GetMessageByID retrieves a single message by ID (for debugging/admin purposes)
func (h *Handler) GetMessageByID(w http.ResponseWriter, r *http.Request) {
	// Get authenticated user from context
	authUser := middleware.MustGetUserFromContext(r.Context())

	// Get message ID from URL
	vars := mux.Vars(r)
	messageIDStr := vars["id"]
	messageID, err := strconv.Atoi(messageIDStr)
	if err != nil {
		sendError(w, http.StatusBadRequest, "Invalid message ID")
		return
	}

	// Get message
	message, err := h.App.Deps.Messages.GetByID(messageID)
	if err != nil {
		sendErrorWithContext(w, r, http.StatusNotFound, "Message not found", err)
		return
	}

	// Verify user is either sender or recipient (unless admin)
	if authUser.UserType != models.UserTypeAdmin {
		if message.SenderID != authUser.UserID && message.RecipientID != authUser.UserID {
			sendError(w, http.StatusForbidden, "You are not authorized to view this message")
			return
		}
	}

	// Send response
	sendSuccess(w, http.StatusOK, "Message retrieved successfully", message)
}