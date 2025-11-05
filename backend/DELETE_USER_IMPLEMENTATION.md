# Admin Delete User Endpoint Implementation

## Overview

This document describes the implementation of the admin-only user deletion endpoint in the delivery app API.

## Endpoint Details

**Path:** `DELETE /api/admin/users/{id}`
**Authentication:** Required (JWT Bearer token)
**Authorization:** Admin only
**Implementation Date:** 2025-10-28

## API Specification

### Request

```http
DELETE /api/admin/users/{id}
Authorization: Bearer <admin_jwt_token>
```

**Path Parameters:**
- `id` (integer, required): The user ID to delete

### Response

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "User 'customer1' deleted successfully",
  "data": null
}
```

**Error Responses:**

| Status Code | Scenario | Response |
|-------------|----------|----------|
| 400 Bad Request | Admin tries to delete themselves | `{"success": false, "message": "Cannot delete your own account"}` |
| 400 Bad Request | Trying to delete last admin | `{"success": false, "message": "Cannot delete the last admin user"}` |
| 400 Bad Request | Invalid user ID format | `{"success": false, "message": "Invalid user ID"}` |
| 401 Unauthorized | No authentication token | `{"success": false, "message": "Authentication required"}` |
| 403 Forbidden | Non-admin user | `{"success": false, "message": "Forbidden: admin access required"}` |
| 404 Not Found | User doesn't exist | `{"success": false, "message": "User not found"}` |
| 500 Internal Server Error | Database error | `{"success": false, "message": "Failed to delete user"}` |

## Implementation Architecture

### 1. Repository Layer

**File:** `/backend/repositories/user_repository.go`

**New Interface Methods:**
```go
// UserRepository interface additions
DeleteUser(userID int) error
CountAdminUsers() (int, error)
```

**Implementation:**

```go
// DeleteUser deletes a user and all associated profile data (cascades to profile tables)
func (r *userRepository) DeleteUser(userID int) error {
	query := r.DB.Rebind(`DELETE FROM users WHERE id = ?`)

	result, err := ExecuteStatement(r.DB, query, []interface{}{userID})
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}

// CountAdminUsers returns the total number of admin users in the system
func (r *userRepository) CountAdminUsers() (int, error) {
	var count int
	query := `
		SELECT COUNT(*)
		FROM users
		WHERE user_type = 'admin'
	`

	err := r.DB.QueryRow(query).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to count admin users: %w", err)
	}

	return count, nil
}
```

### 2. Handler Layer

**File:** `/backend/handlers/admin_user.go` (new file)

**Handler Method:**
```go
func (h *Handler) DeleteUser(w http.ResponseWriter, r *http.Request)
```

**Business Logic:**
1. Extract authenticated admin user from context
2. Parse user ID from URL path parameter
3. **Safety Check #1:** Prevent admin from deleting themselves
4. Fetch target user to verify existence and get user type
5. **Safety Check #2:** If deleting admin, ensure it's not the last admin
6. Execute deletion via repository
7. Log deletion action for audit trail
8. Return success response

### 3. Route Configuration

**File:** `/backend/main.go`

**Route Registration:**
```go
// Admin user management routes
adminRoutes.HandleFunc("/users/{id}", h.DeleteUser).Methods("DELETE", "OPTIONS")
```

**Middleware Stack:**
- `AuthMiddleware(jwtSecret)` - Validates JWT token
- `RequireUserType("admin")` - Ensures user is admin

### 4. OpenAPI Documentation

**File:** `/backend/openapi/paths/users.yaml` (new file)

Comprehensive API documentation including:
- Endpoint description
- Safety checks explanation
- What data gets deleted (CASCADE behavior)
- All request/response schemas
- Multiple response examples for each scenario

**File:** `/backend/openapi.yaml`

Added:
- New tag: "Admin User Management"
- Path reference to `/api/admin/users/{id}`

## Safety Features

### 1. Prevent Self-Deletion

Admins cannot delete their own account to prevent accidental lockout.

```go
if authUser.UserID == userID {
    sendError(w, http.StatusBadRequest, "Cannot delete your own account")
    return
}
```

### 2. Prevent Deleting Last Admin

The system ensures at least one admin user exists at all times.

```go
if targetUser.UserType == models.UserTypeAdmin {
    adminCount, err := h.App.Deps.Users.CountAdminUsers()
    if err != nil {
        // Handle error
    }

    if adminCount <= 1 {
        sendError(w, http.StatusBadRequest, "Cannot delete the last admin user")
        return
    }
}
```

### 3. Audit Logging

All user deletions are logged with complete details:

```go
log.Printf("User deleted - ID: %d, Type: %s, Username: %s (deleted by admin: %s)",
    userID, targetUser.UserType, targetUser.Username, authUser.Username)
```

### 4. Database Cascade Deletes

The database schema uses `ON DELETE CASCADE` to automatically clean up related data:

**Tables with CASCADE behavior:**
- `customers.user_id` → CASCADE
- `vendors.user_id` → CASCADE
- `drivers.user_id` → CASCADE
- `admins.user_id` → CASCADE
- `customer_addresses.customer_id` → CASCADE
- `vendor_restaurants.vendor_id` → CASCADE
- All other related foreign keys

**Example from schema.sql:**
```sql
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- ...
);
```

## What Gets Deleted

When a user is deleted, the following data is automatically removed via CASCADE:

### For Customer Users:
- User account (users table)
- Customer profile (customers table)
- All customer addresses (customer_addresses table)
- All orders as customer (handled by foreign key constraints)

### For Vendor Users:
- User account (users table)
- Vendor profile (vendors table)
- Vendor-restaurant relationships (vendor_restaurants table)
- Associated restaurants (if CASCADE configured)
- All menus (if CASCADE configured)

### For Driver Users:
- User account (users table)
- Driver profile (drivers table)
- Driver order assignments (orders.driver_id set to NULL)

### For Admin Users:
- User account (users table)
- Admin profile (admins table)
- Approval history (approved_by_admin_id set to NULL)

## Testing

### Manual Testing with curl

**1. Delete a customer user:**
```bash
# Login as admin
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin1", "password": "password123"}' | \
  jq -r '.data.token')

# Delete user ID 5
curl -X DELETE http://localhost:8080/api/admin/users/5 \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

**2. Try to delete yourself (should fail):**
```bash
# Get your own user ID from token info
MY_ID=$(curl -s -X GET http://localhost:8080/api/debug/token-info \
  -H "Authorization: Bearer $ADMIN_TOKEN" | \
  jq -r '.user_id')

# Try to delete self (will fail)
curl -X DELETE http://localhost:8080/api/admin/users/$MY_ID \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

**3. Non-admin tries to delete (should fail):**
```bash
# Login as customer
CUSTOMER_TOKEN=$(curl -s -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "customer1", "password": "password123"}' | \
  jq -r '.data.token')

# Try to delete user (will fail with 403)
curl -X DELETE http://localhost:8080/api/admin/users/5 \
  -H "Authorization: Bearer $CUSTOMER_TOKEN"
```

### Automated Test Script

Run the comprehensive test script:

```bash
# Ensure backend is running
cd backend
./delivery_app

# In another terminal, run tests
./test_delete_user.sh
```

The test script verifies:
- Admin can delete users
- Non-admin cannot delete users (403)
- No auth = denied (401)
- Cannot delete self (400)
- Invalid user ID rejected (400)
- Non-existent user returns 404
- Successful deletion returns 200
- Cascade delete works (user cannot login after deletion)

## Security Considerations

### 1. Authorization
- Endpoint is protected by `RequireUserType("admin")` middleware
- Only authenticated admin users can access this endpoint

### 2. Authentication
- JWT token required in Authorization header
- Token validated by `AuthMiddleware`

### 3. Data Integrity
- Soft delete NOT implemented (hard delete for simplicity)
- CASCADE deletes ensure referential integrity
- Last admin protection prevents system lockout

### 4. Audit Trail
- All deletions logged with:
  - Deleted user ID, type, and username
  - Admin who performed the deletion
  - Timestamp (via log timestamps)

### 5. Future Improvements

Consider implementing:
- **Soft Delete:** Add `deleted_at` timestamp instead of hard delete
- **Deletion Recovery:** Allow restoring deleted users within time window
- **Database Audit Log:** Store deletion events in dedicated audit_log table
- **Bulk Delete:** Delete multiple users in one request
- **Delete with Reason:** Require admin to provide deletion reason
- **Email Notification:** Notify user before/after deletion
- **Cascade Control:** Allow admin to choose what data to keep
- **List Users Endpoint:** Add GET /api/admin/users for user management UI

## Files Modified/Created

### New Files:
1. `/backend/handlers/admin_user.go` - Delete user handler
2. `/backend/openapi/paths/users.yaml` - OpenAPI endpoint documentation
3. `/backend/test_delete_user.sh` - Automated test script
4. `/backend/DELETE_USER_IMPLEMENTATION.md` - This documentation

### Modified Files:
1. `/backend/repositories/user_repository.go` - Added DeleteUser and CountAdminUsers methods
2. `/backend/main.go` - Registered DELETE /api/admin/users/{id} route
3. `/backend/openapi.yaml` - Added Admin User Management tag and path reference

## Database Impact

### Performance Considerations:
- Single DELETE query (efficient)
- CASCADE deletes handled by PostgreSQL (atomic)
- No transaction required (single operation)
- Indexed foreign keys ensure fast CASCADE

### Row Deletion Estimates:
For a typical user deletion:
- 1 row from `users`
- 1 row from profile table (`customers`, `vendors`, `drivers`, or `admins`)
- 0-N rows from related tables (addresses, restaurants, orders, etc.)

### Potential Bottlenecks:
- Deleting a vendor with many restaurants and menus could be slow
- Deleting a customer with thousands of orders might take time
- Consider adding deletion progress/status for heavy deletions

## Error Handling

All errors are logged and return appropriate HTTP status codes:

| Error Type | HTTP Status | Log Level |
|------------|-------------|-----------|
| Invalid user ID format | 400 | Info |
| Self-deletion attempt | 400 | Warning |
| Last admin deletion | 400 | Warning |
| User not found | 404 | Info |
| Auth failure | 401 | Warning |
| Forbidden (non-admin) | 403 | Warning |
| Database error | 500 | Error |

## Example Usage

### Delete a test customer:
```bash
curl -X DELETE http://localhost:8080/api/admin/users/5 \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "success": true,
  "message": "User 'testcustomer' deleted successfully",
  "data": null
}
```

### Error Example (try to delete self):
```bash
curl -X DELETE http://localhost:8080/api/admin/users/1 \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "success": false,
  "message": "Cannot delete your own account"
}
```

## Summary

The delete user endpoint is now fully implemented with:

- Complete CRUD operation in repository layer
- Admin-only access control via middleware
- Multiple safety checks (self-delete, last admin)
- Comprehensive error handling
- Audit logging for compliance
- Full OpenAPI documentation
- Automated test script
- Database CASCADE for data integrity

The implementation follows the clean architecture pattern and maintains consistency with the existing codebase.
