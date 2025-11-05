# Vendor Restaurant Settings OpenAPI Documentation

**Status**: ✅ Complete
**Date**: 2025-10-30
**Task**: Document vendor restaurant settings endpoints in OpenAPI specification

---

## Summary

Successfully created comprehensive OpenAPI documentation for the vendor restaurant settings endpoints. All three endpoints are now fully documented with complete request/response schemas, validation rules, examples, and error responses.

---

## Files Created

### 1. `/backend/openapi/paths/vendor_settings.yaml`
**New file** - Comprehensive path documentation for vendor settings endpoints

**Endpoints documented**:
- `GET /api/vendor/restaurant/{restaurantId}/settings` - Get restaurant settings
- `PUT /api/vendor/restaurant/{restaurantId}/settings` - Update restaurant settings
- `PATCH /api/vendor/restaurant/{restaurantId}/prep-time` - Quick prep time update

**Features**:
- Full request/response schemas with examples
- Multiple response examples (with/without hours configured)
- Detailed validation error examples
- Authorization requirements documented
- Business logic explained in descriptions

### 2. `/backend/openapi/schemas/vendor.yaml`
**New file** - Vendor-specific schema definitions

**Schemas defined**:
- `DaySchedule` - Operating hours for a single day
- `HoursOfOperation` - Weekly operating hours (all 7 days)
- `VendorSettings` - Complete vendor settings response
- `UpdateVendorSettingsRequest` - Update settings request (partial updates)
- `UpdatePrepTimeRequest` - Quick prep time update request

**Features**:
- Pattern validation for time format: `^([0-1][0-9]|2[0-3]):[0-5][0-9]$`
- Min/max constraints (1-300 minutes for prep time)
- Required fields clearly marked
- Comprehensive examples and descriptions

---

## Files Modified

### 3. `/backend/openapi.yaml`
**Updated** - Main OpenAPI specification file

**Changes**:
1. Added new tag `Vendor` for vendor-specific operations (line 39-40)
2. Added path references for vendor settings endpoints (lines 106-109):
   - `/api/vendor/restaurant/{restaurantId}/settings`
   - `/api/vendor/restaurant/{restaurantId}/prep-time`
3. Added schema references in components section (lines 366-376):
   - `DaySchedule`
   - `HoursOfOperation`
   - `VendorSettings`
   - `UpdateVendorSettingsRequest`
   - `UpdatePrepTimeRequest`

### 4. `/backend/openapi/schemas/restaurant.yaml`
**Updated** - Restaurant schema to include prep time field

**Changes**:
- Added `average_prep_time_minutes` to `Restaurant` schema (lines 57-63)
- Added `average_prep_time_minutes` to `CreateRestaurantRequest` (lines 159-165)
- Added `average_prep_time_minutes` to `UpdateRestaurantRequest` (lines 221-227)

**Field specification**:
```yaml
average_prep_time_minutes:
  type: integer
  nullable: true
  minimum: 1
  maximum: 300
  description: Average time to prepare an order in minutes
  example: 30
```

### 5. `/backend/openapi/schemas/order.yaml`
**Updated** - Enhanced order status update documentation

**Changes**:
- Enhanced `UpdateOrderStatusRequest.estimated_preparation_time` description (lines 266-277)
- Added detailed explanation of when and how to use this parameter
- Clarified relationship with restaurant's default prep time
- Added validation constraints (1-300 minutes, nullable)

**Enhanced description**:
```yaml
estimated_preparation_time:
  type: integer
  minimum: 1
  maximum: 300
  nullable: true
  description: |
    **Optional**: Estimated preparation time in minutes.
    - When confirming an order (status: 'confirmed'), this overrides the restaurant's default average prep time
    - If not provided, the restaurant's default average_prep_time_minutes is used
    - Must be between 1 and 300 minutes
    - Used to calculate estimated_ready_time for the order
  example: 25
```

### 6. `/backend/openapi/paths/orders.yaml`
**Updated** - Enhanced vendor order status update endpoint description

**Changes**:
- Updated `PUT /api/vendor/orders/{id}` description (lines 534-548)
- Added section explaining order confirmation behavior
- Clarified relationship between prep time parameter and restaurant default

**Added documentation**:
```yaml
**Order Confirmation (pending -> confirmed)**:
When confirming an order, you can optionally provide `estimated_preparation_time` to override the restaurant's default average prep time.
If not provided, the system uses the restaurant's configured average_prep_time_minutes.
The estimated ready time will be calculated as: confirmed_at + prep_time_minutes
```

---

## Endpoint Documentation Details

### GET /api/vendor/restaurant/{restaurantId}/settings

**Purpose**: Retrieve restaurant settings for authenticated vendor

**Authorization**:
- Requires authentication (Bearer token)
- User must be a vendor
- Vendor must own the restaurant

**Response Examples**:

1. **With hours configured**:
```json
{
  "success": true,
  "data": {
    "restaurant_id": 1,
    "restaurant_name": "Pizza Palace",
    "average_prep_time_minutes": 30,
    "hours_of_operation": {
      "monday": {"open": "09:00", "close": "22:00", "closed": false},
      "tuesday": {"open": "09:00", "close": "22:00", "closed": false},
      "wednesday": {"open": "09:00", "close": "22:00", "closed": false},
      "thursday": {"open": "09:00", "close": "22:00", "closed": false},
      "friday": {"open": "09:00", "close": "23:00", "closed": false},
      "saturday": {"open": "10:00", "close": "23:00", "closed": false},
      "sunday": {"open": "10:00", "close": "22:00", "closed": false}
    }
  }
}
```

2. **Without hours configured**:
```json
{
  "success": true,
  "data": {
    "restaurant_id": 1,
    "restaurant_name": "Pizza Palace",
    "average_prep_time_minutes": 30
  }
}
```

**Error Responses**:
- `400` - Invalid restaurant ID
- `401` - Authentication required
- `403` - Not a vendor OR not the owner
- `404` - Restaurant not found
- `500` - Internal server error

---

### PUT /api/vendor/restaurant/{restaurantId}/settings

**Purpose**: Update restaurant settings (hours and/or prep time)

**Authorization**: Same as GET endpoint

**Validation Rules**:
1. At least one field must be provided
2. `average_prep_time_minutes`: 1-300 (if provided)
3. Hours format: HH:MM in 24-hour format
4. Open time must be before close time (unless closed)
5. All 7 days must be specified if updating hours

**Request Examples**:

1. **Update both fields**:
```json
{
  "average_prep_time_minutes": 35,
  "hours_of_operation": {
    "monday": {"open": "09:00", "close": "22:00", "closed": false},
    "tuesday": {"open": "09:00", "close": "22:00", "closed": false},
    "wednesday": {"open": "09:00", "close": "22:00", "closed": false},
    "thursday": {"open": "09:00", "close": "22:00", "closed": false},
    "friday": {"open": "09:00", "close": "23:00", "closed": false},
    "saturday": {"open": "10:00", "close": "23:00", "closed": false},
    "sunday": {"open": "10:00", "close": "22:00", "closed": false}
  }
}
```

2. **Update only hours**:
```json
{
  "hours_of_operation": {
    "monday": {"open": "08:00", "close": "21:00", "closed": false},
    "tuesday": {"open": "08:00", "close": "21:00", "closed": false},
    "wednesday": {"open": "08:00", "close": "21:00", "closed": false},
    "thursday": {"open": "08:00", "close": "21:00", "closed": false},
    "friday": {"open": "08:00", "close": "22:00", "closed": false},
    "saturday": {"open": "09:00", "close": "22:00", "closed": false},
    "sunday": {"open": "", "close": "", "closed": true}
  }
}
```

3. **Update only prep time** (use PATCH for simpler request):
```json
{
  "average_prep_time_minutes": 25
}
```

**Error Response Examples**:
- `400` - No fields provided: `{"success": false, "message": "At least one field must be provided"}`
- `400` - Invalid prep time: `{"success": false, "message": "Average prep time must be between 1 and 300 minutes"}`
- `400` - Invalid time format: `{"success": false, "message": "Invalid hours of operation: Monday open time: invalid time format, must be HH:MM (24-hour)"}`
- `400` - Open after close: `{"success": false, "message": "Invalid hours of operation: Monday: open time must be before close time"}`

---

### PATCH /api/vendor/restaurant/{restaurantId}/prep-time

**Purpose**: Quick update for average prep time only

**Authorization**: Same as GET endpoint

**When to use**:
- Simple prep time adjustments (e.g., during busy hours)
- Don't need to update hours
- Simpler API call than PUT

**Validation**:
- `average_prep_time_minutes` is required
- Must be 1-300 minutes

**Request Example**:
```json
{
  "average_prep_time_minutes": 25
}
```

**Response Example**:
```json
{
  "success": true,
  "message": "Average prep time updated successfully",
  "data": {
    "restaurant_id": 1,
    "average_prep_time_minutes": 25
  }
}
```

**Use Cases**:
1. **Quick update during busy hours**: Increase from 30 to 45 minutes
2. **Slow kitchen day**: Temporarily increase prep time
3. **Normal operations**: Reset to standard 30 minutes

---

## Schemas Documentation

### DaySchedule
```yaml
type: object
required: [open, close, closed]
properties:
  open:
    type: string
    pattern: '^([0-1][0-9]|2[0-3]):[0-5][0-9]$'
    example: "09:00"
  close:
    type: string
    pattern: '^([0-1][0-9]|2[0-3]):[0-5][0-9]$'
    example: "22:00"
  closed:
    type: boolean
    example: false
```

**Validation**:
- Time format: HH:MM (24-hour)
- Valid hours: 00-23
- Valid minutes: 00-59
- If `closed` is true, `open` and `close` can be empty strings

### HoursOfOperation
```yaml
type: object
required: [monday, tuesday, wednesday, thursday, friday, saturday, sunday]
properties:
  monday: { $ref: '#/DaySchedule' }
  tuesday: { $ref: '#/DaySchedule' }
  wednesday: { $ref: '#/DaySchedule' }
  thursday: { $ref: '#/DaySchedule' }
  friday: { $ref: '#/DaySchedule' }
  saturday: { $ref: '#/DaySchedule' }
  sunday: { $ref: '#/DaySchedule' }
```

**Requirements**:
- All seven days must be specified
- Each day follows DaySchedule schema

### VendorSettings
```yaml
type: object
required: [restaurant_id, restaurant_name, average_prep_time_minutes]
properties:
  restaurant_id:
    type: integer
    example: 1
  restaurant_name:
    type: string
    example: "Pizza Palace"
  average_prep_time_minutes:
    type: integer
    minimum: 1
    maximum: 300
    example: 30
  hours_of_operation:
    allOf: [{ $ref: '#/HoursOfOperation' }]
    nullable: true
```

**Notes**:
- `hours_of_operation` is nullable (may not be configured)
- Prep time is always required (has database default)

### UpdateVendorSettingsRequest
```yaml
type: object
minProperties: 1
properties:
  average_prep_time_minutes:
    type: integer
    minimum: 1
    maximum: 300
    nullable: true
  hours_of_operation:
    allOf: [{ $ref: '#/HoursOfOperation' }]
    nullable: true
```

**Validation**:
- At least one field must be provided (`minProperties: 1`)
- Both fields are optional
- Can update one or both fields in single request

### UpdatePrepTimeRequest
```yaml
type: object
required: [average_prep_time_minutes]
properties:
  average_prep_time_minutes:
    type: integer
    minimum: 1
    maximum: 300
    example: 25
```

**Usage**:
- Simpler than UpdateVendorSettingsRequest
- Only for prep time updates
- Field is required (not optional)

---

## Integration with Order Confirmation

### Order Confirmation Flow

When a vendor confirms an order (`pending` → `confirmed`), they can optionally override the restaurant's default prep time:

**Endpoint**: `PUT /api/vendor/orders/{id}`

**Request with custom prep time**:
```json
{
  "status": "confirmed",
  "estimated_preparation_time": 40,
  "notes": "Busy hour, will take longer than usual"
}
```

**Request using default prep time**:
```json
{
  "status": "confirmed",
  "notes": "Order confirmed"
}
```

**Backend Behavior**:
1. If `estimated_preparation_time` provided: Use that value
2. If not provided: Use restaurant's `average_prep_time_minutes`
3. Calculate `estimated_ready_time` = `confirmed_at` + prep time minutes
4. Store in order record

**Example**:
- Restaurant default prep time: 30 minutes
- Order confirmed at: 2024-01-15 10:00:00
- Custom prep time provided: 40 minutes
- **Result**: `estimated_ready_time` = 2024-01-15 10:40:00

---

## Validation Summary

### Prep Time Validation
- **Range**: 1-300 minutes
- **Type**: Integer
- **Required**: Yes for PATCH endpoint, optional for PUT endpoint
- **Default**: Uses restaurant's configured value if not provided during order confirmation

### Hours of Operation Validation
- **Time Format**: HH:MM (24-hour)
- **Pattern**: `^([0-1][0-9]|2[0-3]):[0-5][0-9]$`
- **Business Rule**: Open time must be before close time
- **Exception**: If `closed` is true, times are ignored
- **Completeness**: All 7 days must be provided when updating

### Authorization Checks
1. User must be authenticated (valid JWT token)
2. User type must be "vendor"
3. Vendor must own the restaurant (verified via vendor_restaurants table)

---

## Error Handling

### HTTP Status Codes

| Code | Meaning | When It Occurs |
|------|---------|----------------|
| 200 | Success | Settings retrieved/updated successfully |
| 400 | Bad Request | Invalid input (restaurant ID, prep time, time format) |
| 401 | Unauthorized | Missing or invalid authentication token |
| 403 | Forbidden | Not a vendor OR doesn't own this restaurant |
| 404 | Not Found | Restaurant doesn't exist |
| 500 | Server Error | Database error, JSON parsing error |

### Error Response Format
```json
{
  "success": false,
  "message": "Human-readable error description"
}
```

### Common Error Messages

**Authentication/Authorization**:
- `"Authentication required"`
- `"Vendor profile not found"` (not a vendor)
- `"You do not have permission to access this restaurant"` (not owner)
- `"You do not have permission to modify this restaurant"` (not owner)

**Validation Errors**:
- `"Invalid restaurant ID"`
- `"At least one field must be provided"`
- `"Average prep time must be between 1 and 300 minutes"`
- `"Invalid hours of operation: Monday open time: invalid time format, must be HH:MM (24-hour)"`
- `"Invalid hours of operation: Monday: open time must be before close time"`

**System Errors**:
- `"Restaurant not found"`
- `"Failed to update restaurant settings"`
- `"Failed to process hours of operation"`
- `"Failed to retrieve updated restaurant"`
- `"Failed to update prep time"`

---

## Testing Checklist

### GET /api/vendor/restaurant/{restaurantId}/settings
- [ ] Authenticated vendor can retrieve their restaurant settings
- [ ] Returns settings with hours if configured
- [ ] Returns settings without hours if not configured
- [ ] Returns 403 if vendor doesn't own restaurant
- [ ] Returns 404 if restaurant doesn't exist
- [ ] Returns 400 for invalid restaurant ID
- [ ] Returns 401 without authentication

### PUT /api/vendor/restaurant/{restaurantId}/settings
- [ ] Can update both prep time and hours
- [ ] Can update only prep time
- [ ] Can update only hours
- [ ] Returns 400 if no fields provided
- [ ] Returns 400 if prep time < 1 or > 300
- [ ] Returns 400 for invalid time format (not HH:MM)
- [ ] Returns 400 if open time >= close time
- [ ] Returns 400 if not all 7 days provided (when updating hours)
- [ ] Accepts closed days with empty time strings
- [ ] Returns updated settings in response
- [ ] Returns 403 if vendor doesn't own restaurant

### PATCH /api/vendor/restaurant/{restaurantId}/prep-time
- [ ] Can update prep time successfully
- [ ] Returns 400 if prep time missing
- [ ] Returns 400 if prep time < 1 or > 300
- [ ] Returns 400 for invalid JSON
- [ ] Returns updated prep time in response
- [ ] Returns 403 if vendor doesn't own restaurant

### Order Confirmation Integration
- [ ] Order confirmation uses restaurant default if no override
- [ ] Order confirmation uses provided override
- [ ] Estimated ready time calculated correctly
- [ ] Override validation (1-300 minutes)

---

## OpenAPI Specification Validation

**Tool Used**: Ruby YAML parser
**Status**: ✅ All files validated successfully

**Files Validated**:
1. `/backend/openapi.yaml` - ✅ Valid YAML
2. `/backend/openapi/paths/vendor_settings.yaml` - ✅ Valid YAML
3. `/backend/openapi/schemas/vendor.yaml` - ✅ Valid YAML

**Validation Output**:
```
✓ openapi.yaml - Valid YAML
✓ openapi/paths/vendor_settings.yaml - Valid YAML
✓ openapi/schemas/vendor.yaml - Valid YAML

✓ All OpenAPI files are syntactically valid!
```

---

## Implementation Status

### Backend Implementation
- ✅ Handlers implemented (`/backend/handlers/vendor_settings.go`)
- ✅ Models defined (`/backend/models/vendor_settings.go`)
- ✅ Routes configured (`/backend/main.go` lines 161-163)
- ✅ Repository methods implemented
- ✅ Validation logic in handlers
- ✅ Authorization checks in place

### OpenAPI Documentation
- ✅ Path documentation created (`vendor_settings.yaml`)
- ✅ Schema definitions created (`vendor.yaml`)
- ✅ Main spec updated with references
- ✅ Tags added for organization
- ✅ Order schema enhanced with prep time docs
- ✅ Restaurant schema updated with prep time field
- ✅ All examples provided
- ✅ All error responses documented
- ✅ Validation rules documented
- ✅ YAML syntax validated

### Documentation Coverage
- ✅ Request/response schemas complete
- ✅ Authentication requirements specified
- ✅ Validation rules documented
- ✅ Example requests and responses provided
- ✅ Error responses documented (400, 401, 403, 404, 500)
- ✅ Business logic explained
- ✅ Integration with orders documented
- ✅ Tags consistent with existing patterns

---

## API Routes Reference

| Method | Path | Handler | Purpose |
|--------|------|---------|---------|
| GET | `/api/vendor/restaurant/{restaurantId}/settings` | `GetRestaurantSettings` | Get restaurant settings |
| PUT | `/api/vendor/restaurant/{restaurantId}/settings` | `UpdateRestaurantSettings` | Update settings (hours/prep) |
| PATCH | `/api/vendor/restaurant/{restaurantId}/prep-time` | `UpdateRestaurantPrepTime` | Quick prep time update |

**Authentication**: All endpoints require vendor authentication
**Middleware**: `AuthMiddleware` + `RequireUserType("vendor")`
**Base URL**: `http://localhost:8080` (development)

---

## Next Steps (Optional Enhancements)

### Potential Improvements
1. **Bulk Update**: Allow updating settings for multiple restaurants
2. **History Tracking**: Log changes to settings with timestamps
3. **Default Hours Templates**: Provide common hour templates (9-5, 24/7, etc.)
4. **Timezone Support**: Store timezone with hours
5. **Holiday Exceptions**: Special hours for holidays
6. **Temporary Closures**: Mark restaurant as temporarily closed
7. **Analytics**: Track how often vendors adjust prep times
8. **Notifications**: Alert customers when hours change

### Documentation Enhancements
1. **Swagger UI**: Deploy interactive API documentation
2. **Code Examples**: Add cURL examples for all endpoints
3. **Postman Collection**: Export OpenAPI to Postman format
4. **Client SDKs**: Generate TypeScript/Dart clients from spec

---

## Conclusion

All vendor restaurant settings endpoints are now comprehensively documented in the OpenAPI specification. The documentation includes:

1. **Complete endpoint definitions** with request/response schemas
2. **Detailed validation rules** and constraints
3. **Comprehensive examples** for success and error cases
4. **Integration documentation** showing how settings affect order confirmation
5. **Schema definitions** for all data structures
6. **Valid YAML** confirmed by syntax checker

The OpenAPI specification now serves as a complete contract for:
- Frontend developers building vendor UI
- API consumers understanding the endpoints
- Testing teams validating behavior
- Future maintainers understanding the system

**Status**: ✅ Task Complete - Ready for use
