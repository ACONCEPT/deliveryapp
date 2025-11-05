package repositories

import (
	"database/sql"
	"delivery_app/backend/models"
	"fmt"

	"github.com/jmoiron/sqlx"
)

// MessageRepository defines the interface for message data access
type MessageRepository interface {
	// Core CRUD operations
	Create(message *models.Message) error
	GetByID(id int) (*models.Message, error)
	MarkAsRead(messageID int) error

	// Conversation operations
	GetMessagesBetweenUsers(userID1, userID2 int, limit, offset int) ([]models.MessageWithUserInfo, int, error)
	GetConversations(userID int) ([]models.Conversation, error)

	// Validation
	CanUsersSendMessages(senderID, recipientID int) (bool, error)
}

// messageRepository implements the MessageRepository interface
type messageRepository struct {
	DB *sqlx.DB
}

// NewMessageRepository creates a new instance of MessageRepository
func NewMessageRepository(db *sqlx.DB) MessageRepository {
	return &messageRepository{DB: db}
}

// Create inserts a new message into the database
func (r *messageRepository) Create(message *models.Message) error {
	query := r.DB.Rebind(`
		INSERT INTO messages (sender_id, recipient_id, content)
		VALUES (?, ?, ?)
		RETURNING id, sender_id, recipient_id, content, read_at, created_at, updated_at
	`)

	args := []interface{}{
		message.SenderID,
		message.RecipientID,
		message.Content,
	}

	return GetData(r.DB, query, message, args)
}

// GetByID retrieves a message by its ID
func (r *messageRepository) GetByID(id int) (*models.Message, error) {
	var message models.Message
	query := r.DB.Rebind(`SELECT * FROM messages WHERE id = ?`)

	err := r.DB.QueryRowx(query, id).StructScan(&message)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("message not found")
		}
		return nil, fmt.Errorf("failed to get message: %w", err)
	}

	return &message, nil
}

// MarkAsRead marks a message as read
func (r *messageRepository) MarkAsRead(messageID int) error {
	query := r.DB.Rebind(`
		UPDATE messages
		SET read_at = CURRENT_TIMESTAMP
		WHERE id = ? AND read_at IS NULL
	`)

	_, err := r.DB.Exec(query, messageID)
	if err != nil {
		return fmt.Errorf("failed to mark message as read: %w", err)
	}

	return nil
}

// GetMessagesBetweenUsers retrieves messages between two users with pagination
// Returns messages sorted by most recent first (descending by created_at)
func (r *messageRepository) GetMessagesBetweenUsers(userID1, userID2 int, limit, offset int) ([]models.MessageWithUserInfo, int, error) {
	// Get total count
	countQuery := r.DB.Rebind(`
		SELECT COUNT(*)
		FROM messages
		WHERE (sender_id = ? AND recipient_id = ?)
		   OR (sender_id = ? AND recipient_id = ?)
	`)

	var total int
	err := r.DB.Get(&total, countQuery, userID1, userID2, userID2, userID1)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count messages: %w", err)
	}

	// Get messages with user info
	query := r.DB.Rebind(`
		SELECT
			m.id,
			m.sender_id,
			m.recipient_id,
			m.content,
			m.read_at,
			m.created_at,
			m.updated_at,
			sender.username AS sender_username,
			sender.user_type AS sender_type,
			recipient.username AS recipient_username,
			recipient.user_type AS recipient_type
		FROM messages m
		JOIN users sender ON m.sender_id = sender.id
		JOIN users recipient ON m.recipient_id = recipient.id
		WHERE (m.sender_id = ? AND m.recipient_id = ?)
		   OR (m.sender_id = ? AND m.recipient_id = ?)
		ORDER BY m.created_at DESC
		LIMIT ? OFFSET ?
	`)

	var messages []models.MessageWithUserInfo
	args := []interface{}{userID1, userID2, userID2, userID1, limit, offset}

	err = SelectData(r.DB, query, &messages, args)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get messages: %w", err)
	}

	return messages, total, nil
}

// GetConversations retrieves all conversations for a user
// Returns a list of users the current user has messaged with, sorted by most recent activity
func (r *messageRepository) GetConversations(userID int) ([]models.Conversation, error) {
	query := r.DB.Rebind(`
		WITH conversation_messages AS (
			SELECT
				CASE
					WHEN m.sender_id = ? THEN m.recipient_id
					ELSE m.sender_id
				END AS other_user_id,
				m.content AS last_message_content,
				m.created_at AS last_message_time,
				m.sender_id = ? AS is_sender,
				ROW_NUMBER() OVER (
					PARTITION BY CASE
						WHEN m.sender_id = ? THEN m.recipient_id
						ELSE m.sender_id
					END
					ORDER BY m.created_at DESC
				) AS rn
			FROM messages m
			WHERE m.sender_id = ? OR m.recipient_id = ?
		),
		latest_messages AS (
			SELECT
				other_user_id,
				last_message_content,
				last_message_time,
				is_sender
			FROM conversation_messages
			WHERE rn = 1
		),
		unread_counts AS (
			SELECT
				sender_id AS other_user_id,
				COUNT(*) AS unread_count
			FROM messages
			WHERE recipient_id = ? AND read_at IS NULL
			GROUP BY sender_id
		)
		SELECT
			u.id AS user_id,
			u.username,
			u.user_type,
			lm.last_message_content,
			lm.last_message_time,
			COALESCE(uc.unread_count, 0) AS unread_count,
			lm.is_sender
		FROM latest_messages lm
		JOIN users u ON lm.other_user_id = u.id
		LEFT JOIN unread_counts uc ON lm.other_user_id = uc.other_user_id
		ORDER BY lm.last_message_time DESC
	`)

	var conversations []models.Conversation
	args := []interface{}{userID, userID, userID, userID, userID, userID}

	err := SelectData(r.DB, query, &conversations, args)
	if err != nil {
		return nil, fmt.Errorf("failed to get conversations: %w", err)
	}

	return conversations, nil
}

// CanUsersSendMessages validates if two users are allowed to send messages to each other
// Business rules:
// - Customers can message Vendors and Admins
// - Vendors can message Customers and Admins
// - Admins can message Customers and Vendors
// - Drivers cannot message anyone
// - Users cannot message themselves
// - Users of the same type (except admin) cannot message each other
func (r *messageRepository) CanUsersSendMessages(senderID, recipientID int) (bool, error) {
	// Users cannot message themselves
	if senderID == recipientID {
		return false, nil
	}

	// Get user types
	query := r.DB.Rebind(`
		SELECT id, user_type
		FROM users
		WHERE id IN (?, ?)
	`)

	var users []struct {
		ID       int             `db:"id"`
		UserType models.UserType `db:"user_type"`
	}

	err := r.DB.Select(&users, query, senderID, recipientID)
	if err != nil {
		return false, fmt.Errorf("failed to get user types: %w", err)
	}

	if len(users) != 2 {
		return false, fmt.Errorf("one or both users not found")
	}

	var senderType, recipientType models.UserType
	for _, user := range users {
		if user.ID == senderID {
			senderType = user.UserType
		} else {
			recipientType = user.UserType
		}
	}

	// Drivers cannot message anyone
	if senderType == models.UserTypeDriver || recipientType == models.UserTypeDriver {
		return false, nil
	}

	// Customers can only message Vendors and Admins
	if senderType == models.UserTypeCustomer {
		if recipientType != models.UserTypeVendor && recipientType != models.UserTypeAdmin {
			return false, nil
		}
	}

	// Vendors can only message Customers and Admins
	if senderType == models.UserTypeVendor {
		if recipientType != models.UserTypeCustomer && recipientType != models.UserTypeAdmin {
			return false, nil
		}
	}

	// Admins can message Customers and Vendors
	if senderType == models.UserTypeAdmin {
		if recipientType != models.UserTypeCustomer && recipientType != models.UserTypeVendor {
			return false, nil
		}
	}

	return true, nil
}