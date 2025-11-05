# Admin Restaurant Settings Access - Implementation Summary

## Overview
Added admin authentication and authorization to the restaurant settings API endpoints, allowing admins to access and modify settings for ANY restaurant (not just their own).

## Changes Made

### 1. Handler Authorization Logic (`/Users/josephsadaka/Repos/delivery_app/backend/handlers/vendor_settings.go`)

Updated all three handler functions to allow both vendors and admins:

#### `GetRestaurantSettings` (lines 16-85)
**Before**: Only vendors could access their own restaurant settings
**After**:
- Admins can access ANY restaurant's settings
- Vendors can only access their own restaurant's settings
- Other user types are denied access

**Authorization Flow**:
```go
if user.UserType == models.UserTypeAdmin {
    // Admin can access any restaurant
    restaurant, err = h.App.Deps.Restaurants.GetByID(restaurantID)
} else if user.UserType == models.UserTypeVendor {
    // Vendor can only access their own restaurants
    vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
    restaurant, err = h.App.Deps.Restaurants.GetByIDWithOwnershipCheck(restaurantID, vendorID)
} else {
    sendError(w, 403, "Only vendors and admins can access restaurant settings")
}
```

#### `UpdateRestaurantSettings` (lines 87-208)
**Before**: Only vendors could update their own restaurant settings
**After**:
- Admins can update ANY restaurant's settings
- Vendors can only update their own restaurant's settings
- Other user types are denied access

**Authorization Flow**:
```go
if user.UserType == models.UserTypeAdmin {
    // Admin can modify any restaurant - verify it exists
    _, err := h.App.Deps.Restaurants.GetByID(restaurantID)
} else if user.UserType == models.UserTypeVendor {
    // Vendor can only modify their own restaurants
    vendorID, err := h.App.Deps.Users.GetVendorIDByUserID(user.UserID)
    err := h.App.Deps.Restaurants.VerifyVendorOwnership(restaurantID, vendorID)
} else {
    sendError(w, 403, "Only vendors and admins can modify restaurant settings")
}
```

#### `UpdateRestaurantPrepTime` (lines 210-293)
**Before**: Only vendors could update their own restaurant prep time
**After**:
- Admins can update ANY restaurant's prep time
- Vendors can only update their own restaurant's prep time
- Other user types are denied access

**Authorization Flow**: Same as `UpdateRestaurantSettings`

### 2. Route Configuration (`/Users/josephsadaka/Repos/delivery_app/backend/main.go`)

Added admin-specific routes (lines 150-153):
```go
// Admin restaurant settings management (access any restaurant's settings)
adminRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.GetRestaurantSettings).Methods("GET", "OPTIONS")
adminRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.UpdateRestaurantSettings).Methods("PUT", "OPTIONS")
adminRoutes.HandleFunc("/restaurant/{restaurantId}/prep-time", h.UpdateRestaurantPrepTime).Methods("PATCH", "OPTIONS")
```

**Existing vendor routes remain unchanged** (lines 161-163):
```go
// Restaurant settings (hours of operation, prep time)
vendorRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.GetRestaurantSettings).Methods("GET", "OPTIONS")
vendorRoutes.HandleFunc("/restaurant/{restaurantId}/settings", h.UpdateRestaurantSettings).Methods("PUT", "OPTIONS")
vendorRoutes.HandleFunc("/restaurant/{restaurantId}/prep-time", h.UpdateRestaurantPrepTime).Methods("PATCH", "OPTIONS")
```

### 3. OpenAPI Documentation (`/Users/josephsadaka/Repos/delivery_app/backend/openapi/paths/vendor_settings.yaml`)

Updated all three endpoint descriptions to reflect admin access:

#### GET `/api/vendor/restaurant/{restaurantId}/settings` (lines 4-16)
```yaml
description: |
  Retrieve restaurant settings including hours of operation and average prep time.

  **Authorization**:
  - **Vendors**: Can only access settings for restaurants they own
  - **Admins**: Can access settings for ANY restaurant
```

#### PUT `/api/vendor/restaurant/{restaurantId}/settings` (lines 144-160)
```yaml
description: |
  Update hours of operation and/or average prep time for the restaurant.

  **Authorization**:
  - **Vendors**: Can only modify settings for restaurants they own
  - **Admins**: Can modify settings for ANY restaurant
```

#### PATCH `/api/vendor/restaurant/{restaurantId}/prep-time` (lines 392-407)
```yaml
description: |
  Quick update for just the average preparation time in minutes.

  **Authorization**:
  - **Vendors**: Can only modify settings for restaurants they own
  - **Admins**: Can modify settings for ANY restaurant
```

Updated 403 error examples for all endpoints to include the new error message:
```yaml
not_authorized_type:
  summary: User is not a vendor or admin
  value:
    success: false
    message: Only vendors and admins can access/modify restaurant settings
```

## API Endpoints

### For Admins
- `GET /api/admin/restaurant/{restaurantId}/settings` - View any restaurant's settings
- `PUT /api/admin/restaurant/{restaurantId}/settings` - Update any restaurant's settings
- `PATCH /api/admin/restaurant/{restaurantId}/prep-time` - Update any restaurant's prep time

### For Vendors (unchanged)
- `GET /api/vendor/restaurant/{restaurantId}/settings` - View own restaurant's settings
- `PUT /api/vendor/restaurant/{restaurantId}/settings` - Update own restaurant's settings
- `PATCH /api/vendor/restaurant/{restaurantId}/prep-time` - Update own restaurant's prep time

## Testing

### Test Script
Created comprehensive test script: `/Users/josephsadaka/Repos/delivery_app/backend/test_admin_restaurant_settings.sh`

The script verifies:
1. ✅ Admin can GET restaurant settings for any restaurant
2. ✅ Admin can PATCH restaurant prep time for any restaurant
3. ✅ Admin can PUT restaurant settings (full update) for any restaurant
4. ✅ Vendor can still access their own restaurant settings
5. ✅ Vendor is denied access to restaurants they don't own

### Manual Testing with curl

#### 1. Login as Admin
```bash
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin1",
    "password": "password123"
  }'
```

#### 2. Admin GET Restaurant Settings
```bash
curl -X GET http://localhost:8080/api/admin/restaurant/1/settings \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

**Expected Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "restaurant_id": 1,
    "restaurant_name": "China Garden",
    "average_prep_time_minutes": 30,
    "hours_of_operation": {
      "monday": { "open": "11:00", "close": "21:00", "closed": false },
      ...
    }
  }
}
```

#### 3. Admin UPDATE Prep Time (PATCH)
```bash
curl -X PATCH http://localhost:8080/api/admin/restaurant/1/prep-time \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 45
  }'
```

**Expected Response (200 OK)**:
```json
{
  "success": true,
  "message": "Average prep time updated successfully",
  "data": {
    "restaurant_id": 1,
    "average_prep_time_minutes": 45
  }
}
```

#### 4. Admin UPDATE Full Settings (PUT)
```bash
curl -X PUT http://localhost:8080/api/admin/restaurant/1/settings \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "average_prep_time_minutes": 35,
    "hours_of_operation": {
      "monday": { "open": "10:00", "close": "22:00", "closed": false },
      "tuesday": { "open": "10:00", "close": "22:00", "closed": false },
      "wednesday": { "open": "10:00", "close": "22:00", "closed": false },
      "thursday": { "open": "10:00", "close": "22:00", "closed": false },
      "friday": { "open": "10:00", "close": "23:00", "closed": false },
      "saturday": { "open": "11:00", "close": "23:00", "closed": false },
      "sunday": { "open": "", "close": "", "closed": true }
    }
  }'
```

**Expected Response (200 OK)**:
```json
{
  "success": true,
  "message": "Restaurant settings updated successfully",
  "data": {
    "restaurant_id": 1,
    "restaurant_name": "China Garden",
    "average_prep_time_minutes": 35,
    "hours_of_operation": {
      "monday": { "open": "10:00", "close": "22:00", "closed": false },
      ...
    }
  }
}
```

#### 5. Vendor Access (should still work)
```bash
# Login as vendor
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vendor1",
    "password": "password123"
  }'

# Vendor accessing their own restaurant
curl -X GET http://localhost:8080/api/vendor/restaurant/1/settings \
  -H "Authorization: Bearer YOUR_VENDOR_TOKEN"
```

**Expected Response (200 OK)**: Same structure as admin GET

#### 6. Vendor Accessing Other Restaurant (should fail)
```bash
curl -X GET http://localhost:8080/api/vendor/restaurant/999/settings \
  -H "Authorization: Bearer YOUR_VENDOR_TOKEN"
```

**Expected Response (403 Forbidden)**:
```json
{
  "success": false,
  "message": "You do not have permission to access this restaurant"
}
```

#### 7. Customer/Driver Attempting Access (should fail)
```bash
curl -X GET http://localhost:8080/api/vendor/restaurant/1/settings \
  -H "Authorization: Bearer YOUR_CUSTOMER_TOKEN"
```

**Expected Response (403 Forbidden)**:
```json
{
  "success": false,
  "message": "Insufficient permissions"
}
```

(Because customer routes don't include `/vendor/*` endpoints due to middleware restrictions)

## Authorization Rules Summary

| User Type | Access to Own Restaurant | Access to Other Restaurants | HTTP Status if Denied |
|-----------|-------------------------|----------------------------|----------------------|
| **Admin** | ✅ Full access | ✅ Full access | N/A |
| **Vendor** | ✅ Full access | ❌ Denied | 403 Forbidden |
| **Customer** | N/A | ❌ Denied | 403 Forbidden |
| **Driver** | N/A | ❌ Denied | 403 Forbidden |

## Error Responses

### 400 Bad Request
- Invalid restaurant ID format
- Invalid request body
- Validation errors (prep time out of range, invalid time format, etc.)

### 401 Unauthorized
- Missing authentication token
- Invalid or expired token

### 403 Forbidden
- User type not allowed (customer/driver attempting access)
- Vendor attempting to access restaurant they don't own

### 404 Not Found
- Restaurant not found in database

### 500 Internal Server Error
- Database errors
- JSON parsing errors

## Implementation Notes

1. **No Breaking Changes**: Existing vendor routes and functionality remain unchanged
2. **Consistent Pattern**: Follows the same authorization pattern used in `/backend/handlers/restaurant.go` for UpdateRestaurant and DeleteRestaurant
3. **DRY Principle**: Same handlers serve both admin and vendor routes, with authorization logic inside the handler
4. **Clear Error Messages**: Distinct error messages for different authorization failures
5. **Audit Trail**: Consider adding logging for admin actions (not implemented in this PR)

## Files Modified

1. `/Users/josephsadaka/Repos/delivery_app/backend/handlers/vendor_settings.go` - Updated authorization logic
2. `/Users/josephsadaka/Repos/delivery_app/backend/main.go` - Added admin routes
3. `/Users/josephsadaka/Repos/delivery_app/backend/openapi/paths/vendor_settings.yaml` - Updated documentation

## Files Created

1. `/Users/josephsadaka/Repos/delivery_app/backend/test_admin_restaurant_settings.sh` - Test script
2. `/Users/josephsadaka/Repos/delivery_app/backend/ADMIN_RESTAURANT_SETTINGS_SUMMARY.md` - This file

## Next Steps (Optional Enhancements)

1. **Audit Logging**: Log admin modifications to restaurant settings for compliance
2. **Notifications**: Notify restaurant owners when admin modifies their settings
3. **Bulk Operations**: Add endpoints for admin to update multiple restaurants at once
4. **History Tracking**: Track changes to restaurant settings over time
5. **Frontend Integration**: Update admin dashboard to include restaurant settings management

## Conclusion

Admin authentication and authorization for restaurant settings API endpoints has been successfully implemented. Admins can now access and modify settings for any restaurant, while vendors retain their existing access to only their own restaurants.
