package models

import "time"

// Message represents a message between two users
type Message struct {
	ID          int       `json:"id" db:"id"`
	SenderID    int       `json:"sender_id" db:"sender_id"`
	RecipientID int       `json:"recipient_id" db:"recipient_id"`
	Content     string    `json:"content" db:"content"`
	ReadAt      *time.Time `json:"read_at,omitempty" db:"read_at"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// MessageWithUserInfo represents a message with sender/recipient details
type MessageWithUserInfo struct {
	Message
	SenderUsername   string   `json:"sender_username" db:"sender_username"`
	SenderType       UserType `json:"sender_type" db:"sender_type"`
	RecipientUsername string   `json:"recipient_username" db:"recipient_username"`
	RecipientType     UserType `json:"recipient_type" db:"recipient_type"`
}

// SendMessageRequest represents the request to send a message
type SendMessageRequest struct {
	RecipientID int    `json:"recipient_id" validate:"required,gt=0"`
	Content     string `json:"content" validate:"required,min=1,max=5000"`
}

// SendMessageResponse represents the response after sending a message
type SendMessageResponse struct {
	Success bool     `json:"success"`
	Message string   `json:"message"`
	Data    *Message `json:"data,omitempty"`
}

// GetMessagesResponse represents the response with a list of messages
type GetMessagesResponse struct {
	Success  bool                   `json:"success"`
	Message  string                 `json:"message"`
	Data     []MessageWithUserInfo  `json:"data"`
	Total    int                    `json:"total"`
	Page     int                    `json:"page,omitempty"`
	Limit    int                    `json:"limit,omitempty"`
}

// Conversation represents a conversation summary with another user
type Conversation struct {
	UserID             int       `json:"user_id" db:"user_id"`
	Username           string    `json:"username" db:"username"`
	UserType           UserType  `json:"user_type" db:"user_type"`
	LastMessageContent string    `json:"last_message_content" db:"last_message_content"`
	LastMessageTime    time.Time `json:"last_message_time" db:"last_message_time"`
	UnreadCount        int       `json:"unread_count" db:"unread_count"`
	IsSender           bool      `json:"is_sender" db:"is_sender"`
}

// GetConversationsResponse represents the response with a list of conversations
type GetConversationsResponse struct {
	Success bool           `json:"success"`
	Message string         `json:"message"`
	Data    []Conversation `json:"data"`
}