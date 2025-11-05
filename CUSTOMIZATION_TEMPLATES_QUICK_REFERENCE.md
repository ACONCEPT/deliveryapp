# Customization Templates API - Quick Reference

## Overview
Reusable menu customization templates that vendors and admins can create and compose into menus. Templates can be vendor-specific or system-wide (accessible to all vendors).

## Endpoints

### Vendor Endpoints

#### Create Template
```
POST /api/vendor/customization-templates
Authorization: Bearer {vendor_token}
```

**Request:**
```json
{
  "name": "Spice Level",
  "description": "Choose your preferred spice level",
  "customization_config": {
    "type": "select",
    "options": [
      {"label": "Mild", "value": "mild", "price": 0},
      {"label": "Hot", "value": "hot", "price": 1.00}
    ]
  },
  "is_active": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Customization template created successfully",
  "data": {
    "id": 1,
    "name": "Spice Level",
    "vendor_id": 1,
    ...
  }
}
```

#### Get All Templates (vendor's + system-wide)
```
GET /api/vendor/customization-templates
Authorization: Bearer {vendor_token}
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Spice Level",
      "vendor_id": 1,
      ...
    },
    {
      "id": 2,
      "name": "Size Options",
      "vendor_id": null,  // System-wide
      ...
    }
  ]
}
```

#### Get Template by ID
```
GET /api/vendor/customization-templates/{id}
Authorization: Bearer {vendor_token}
```

#### Update Template (partial)
```
PUT /api/vendor/customization-templates/{id}
Authorization: Bearer {vendor_token}
```

**Request (all fields optional):**
```json
{
  "description": "Updated description",
  "is_active": false
}
```

#### Delete Template
```
DELETE /api/vendor/customization-templates/{id}
Authorization: Bearer {vendor_token}
```

---

### Admin Endpoints

#### Create System-Wide Template
```
POST /api/admin/customization-templates
Authorization: Bearer {admin_token}
```

**Request:**
```json
{
  "name": "Size Options",
  "description": "Choose your preferred size",
  "customization_config": {
    "type": "select",
    "options": [
      {"label": "Small", "value": "small", "price": 0},
      {"label": "Large", "value": "large", "price": 5.00}
    ]
  },
  "is_active": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "System-wide customization template created successfully",
  "data": {
    "id": 2,
    "name": "Size Options",
    "vendor_id": null,  // System-wide
    ...
  }
}
```

#### Get All Templates (all vendors + system-wide)
```
GET /api/admin/customization-templates
Authorization: Bearer {admin_token}
```

#### Update Any Template
```
PUT /api/admin/customization-templates/{id}
Authorization: Bearer {admin_token}
```

#### Delete Any Template
```
DELETE /api/admin/customization-templates/{id}
Authorization: Bearer {admin_token}
```

---

## Field Reference

### MenuCustomizationTemplate
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | Read-only | Auto-generated ID |
| `name` | string | Yes | Template name (max 255 chars, unique per vendor) |
| `description` | string | No | Optional description |
| `customization_config` | object | Yes | Flexible JSON config (max 100KB) |
| `vendor_id` | integer/null | Auto | Vendor owner (NULL = system-wide) |
| `is_active` | boolean | Yes | Active status (default: true) |
| `created_at` | timestamp | Read-only | Creation timestamp |
| `updated_at` | timestamp | Read-only | Last update timestamp |

### CreateCustomizationTemplateRequest
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Template name (1-255 chars) |
| `description` | string | No | Optional description |
| `customization_config` | object | Yes | JSON config (max 100KB) |
| `is_active` | boolean | No | Active status (default: true) |

### UpdateCustomizationTemplateRequest
All fields are optional for partial updates:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Updated name (1-255 chars) |
| `description` | string | No | Updated description |
| `customization_config` | object | No | Updated JSON config (max 100KB) |
| `is_active` | boolean | No | Updated active status |

---

## Customization Config Examples

### Single Select (Radio Buttons)
```json
{
  "type": "select",
  "options": [
    {"label": "Mild", "value": "mild", "price": 0},
    {"label": "Medium", "value": "medium", "price": 0},
    {"label": "Hot", "value": "hot", "price": 0.50},
    {"label": "Extra Hot", "value": "extra_hot", "price": 1.00}
  ]
}
```

### Multi-Select (Checkboxes)
```json
{
  "type": "multi-select",
  "max_selections": 5,
  "options": [
    {"label": "Pepperoni", "value": "pepperoni", "price": 2.00},
    {"label": "Mushrooms", "value": "mushrooms", "price": 1.50},
    {"label": "Onions", "value": "onions", "price": 1.00},
    {"label": "Extra Cheese", "value": "extra_cheese", "price": 1.00}
  ]
}
```

### Size Options
```json
{
  "type": "select",
  "required": true,
  "options": [
    {"label": "Small (12\")", "value": "small", "price": 0},
    {"label": "Medium (14\")", "value": "medium", "price": 3.00},
    {"label": "Large (16\")", "value": "large", "price": 5.00},
    {"label": "Extra Large (18\")", "value": "xl", "price": 7.00}
  ]
}
```

### Drink Size
```json
{
  "type": "select",
  "options": [
    {"label": "Small (12 oz)", "value": "s", "price": 0},
    {"label": "Medium (16 oz)", "value": "m", "price": 0.50},
    {"label": "Large (20 oz)", "value": "l", "price": 1.00},
    {"label": "Extra Large (32 oz)", "value": "xl", "price": 1.50}
  ]
}
```

### Sauce Options
```json
{
  "type": "multi-select",
  "max_selections": 3,
  "options": [
    {"label": "Marinara", "value": "marinara", "price": 0},
    {"label": "Ranch", "value": "ranch", "price": 0.50},
    {"label": "Buffalo", "value": "buffalo", "price": 0.50},
    {"label": "BBQ", "value": "bbq", "price": 0.50},
    {"label": "Garlic Aioli", "value": "garlic_aioli", "price": 0.75}
  ]
}
```

### Cooking Preferences
```json
{
  "type": "select",
  "options": [
    {"label": "Rare", "value": "rare", "price": 0},
    {"label": "Medium Rare", "value": "medium_rare", "price": 0},
    {"label": "Medium", "value": "medium", "price": 0},
    {"label": "Medium Well", "value": "medium_well", "price": 0},
    {"label": "Well Done", "value": "well_done", "price": 0}
  ]
}
```

**Note:** The `customization_config` structure is intentionally flexible. The frontend can define any JSON structure needed.

---

## Access Control

### Vendor Permissions
- ✅ Create templates (become owner)
- ✅ View own templates + system-wide templates
- ✅ Update own templates only
- ✅ Delete own templates only
- ❌ Cannot modify system-wide templates

### Admin Permissions
- ✅ Create system-wide templates (vendor_id = NULL)
- ✅ View all templates (vendor-specific and system-wide)
- ✅ Update any template
- ✅ Delete any template

---

## Common Use Cases

### 1. Vendor Creates Template for Their Restaurants
```bash
curl -X POST http://localhost:8080/api/vendor/customization-templates \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Pizza Toppings",
    "description": "Add your favorite toppings",
    "customization_config": {
      "type": "multi-select",
      "max_selections": 5,
      "options": [
        {"label": "Pepperoni", "value": "pepperoni", "price": 2.00},
        {"label": "Mushrooms", "value": "mushrooms", "price": 1.50}
      ]
    },
    "is_active": true
  }'
```

### 2. Vendor Views Available Templates
```bash
# Returns vendor's templates + system-wide templates
curl -X GET http://localhost:8080/api/vendor/customization-templates \
  -H "Authorization: Bearer $VENDOR_TOKEN"
```

### 3. Admin Creates System-Wide Template
```bash
curl -X POST http://localhost:8080/api/admin/customization-templates \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Size Options",
    "description": "Standard size options for all vendors",
    "customization_config": {
      "type": "select",
      "options": [
        {"label": "Small", "value": "small", "price": 0},
        {"label": "Large", "value": "large", "price": 5.00}
      ]
    },
    "is_active": true
  }'
```

### 4. Vendor Updates Template
```bash
curl -X PUT http://localhost:8080/api/vendor/customization-templates/1 \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "is_active": false
  }'
```

### 5. Vendor Deactivates Template
```bash
curl -X PUT http://localhost:8080/api/vendor/customization-templates/1 \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"is_active": false}'
```

### 6. Admin Deletes System-Wide Template
```bash
curl -X DELETE http://localhost:8080/api/admin/customization-templates/2 \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "message": "Invalid customization_config JSON"
}
```

### 401 Unauthorized
```json
{
  "success": false,
  "message": "Unauthorized"
}
```

### 403 Forbidden
```json
{
  "success": false,
  "message": "Access denied to this customization template"
}
```

### 404 Not Found
```json
{
  "success": false,
  "message": "Customization template not found"
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "message": "Failed to create customization template"
}
```

---

## Testing

### Run Test Script
```bash
cd backend
./test_customization_templates.sh
```

### Test Coverage
- Vendor CRUD operations
- Admin CRUD operations
- System-wide template visibility
- Access control verification
- Ownership checks

---

## Database Schema

```sql
CREATE TABLE menu_customization_templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    customization_config JSONB NOT NULL,
    vendor_id INTEGER REFERENCES vendors(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(vendor_id, name)
);

-- Indexes
CREATE INDEX idx_menu_customization_templates_vendor_id ON menu_customization_templates(vendor_id);
CREATE INDEX idx_menu_customization_templates_is_active ON menu_customization_templates(is_active);
CREATE INDEX idx_menu_customization_templates_name ON menu_customization_templates(name);
```

---

## Integration Notes

### Frontend Integration
1. Create Dart model for MenuCustomizationTemplate
2. Create service with API methods
3. Build UI for template management
4. Reference templates in menu composition

### Menu Composition
- Templates can be referenced by ID in menu items
- Or template config can be embedded directly
- Frontend decides composition strategy

### System-Wide Templates
- Created by admins with vendor_id = NULL
- Visible to all vendors (read-only)
- Good for standardized options (sizes, common toppings, etc.)

---

## Quick Commands

```bash
# Login as vendor
VENDOR_TOKEN=$(curl -s -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"vendor1","password":"password123"}' | \
  grep -o '"token":"[^"]*' | sed 's/"token":"//')

# Login as admin
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin1","password":"password123"}' | \
  grep -o '"token":"[^"]*' | sed 's/"token":"//')

# Create template
curl -X POST http://localhost:8080/api/vendor/customization-templates \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","customization_config":{"type":"select","options":[]},"is_active":true}'

# Get all templates
curl -X GET http://localhost:8080/api/vendor/customization-templates \
  -H "Authorization: Bearer $VENDOR_TOKEN" | jq '.'
```
