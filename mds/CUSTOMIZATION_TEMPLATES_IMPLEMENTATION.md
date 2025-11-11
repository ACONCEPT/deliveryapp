# Menu Customization Templates API - Implementation Summary

## Overview
Implemented a complete API for reusable menu customization templates that vendors and admins can create, manage, and compose into menus. The customization_config field is intentionally flexible (JSONB) to allow the frontend to define any structure needed.

## Database Schema

### New Table: `menu_customization_templates`

```sql
CREATE TABLE IF NOT EXISTS menu_customization_templates (
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
```

**Key Features:**
- `vendor_id` is nullable - NULL means system-wide template (admin-created)
- `customization_config` is JSONB for flexible frontend-defined structure
- Unique constraint on (vendor_id, name) prevents duplicate names per vendor
- System-wide templates (vendor_id=NULL) can have duplicate names across vendors

**Indexes Created:**
```sql
CREATE INDEX idx_menu_customization_templates_vendor_id ON menu_customization_templates(vendor_id);
CREATE INDEX idx_menu_customization_templates_is_active ON menu_customization_templates(is_active);
CREATE INDEX idx_menu_customization_templates_name ON menu_customization_templates(name);
```

**Trigger:**
```sql
CREATE TRIGGER update_menu_customization_templates_updated_at
  BEFORE UPDATE ON menu_customization_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

## Files Created

### 1. Models (`backend/models/customization_template.go`)
- `MenuCustomizationTemplate` - Main entity struct
- `CreateCustomizationTemplateRequest` - Create request DTO
- `UpdateCustomizationTemplateRequest` - Update request DTO (all fields optional)
- `CustomizationTemplateResponse` - Single template response
- `CustomizationTemplatesResponse` - List response

### 2. Repository (`backend/repositories/customization_template_repository.go`)

**Interface Methods:**
```go
Create(template *MenuCustomizationTemplate) error
GetByID(id int) (*MenuCustomizationTemplate, error)
GetByVendorID(vendorID int) ([]MenuCustomizationTemplate, error)  // Includes system-wide templates
GetAll() ([]MenuCustomizationTemplate, error)  // Admin only
GetSystemWide() ([]MenuCustomizationTemplate, error)
Update(template *MenuCustomizationTemplate) error
Delete(id int) error
VerifyVendorOwnership(templateID, vendorID int) error
```

**Key Repository Logic:**
- `GetByVendorID()` returns vendor's templates + system-wide templates (vendor_id IS NULL)
- `VerifyVendorOwnership()` ensures vendors can only modify their own templates
- All queries use prepared statements to prevent SQL injection

### 3. Handlers (`backend/handlers/customization_template.go`)

**Vendor Endpoints:**
- `CreateCustomizationTemplate` - POST /api/vendor/customization-templates
- `GetCustomizationTemplates` - GET /api/vendor/customization-templates
- `GetCustomizationTemplate` - GET /api/vendor/customization-templates/{id}
- `UpdateCustomizationTemplate` - PUT /api/vendor/customization-templates/{id}
- `DeleteCustomizationTemplate` - DELETE /api/vendor/customization-templates/{id}

**Admin Endpoints:**
- `CreateSystemWideCustomizationTemplate` - POST /api/admin/customization-templates
- `GetAllCustomizationTemplates` - GET /api/admin/customization-templates
- `UpdateSystemWideCustomizationTemplate` - PUT /api/admin/customization-templates/{id}
- `DeleteSystemWideCustomizationTemplate` - DELETE /api/admin/customization-templates/{id}

**Validation:**
- Name: Required, non-empty, max 255 chars
- customization_config: Must be valid JSON, max 100KB
- Ownership checks for vendor operations
- JSON size limits to prevent abuse

### 4. Routes (`backend/main.go`)

**Vendor Routes (lines 189-194):**
```go
vendorRoutes.HandleFunc("/customization-templates", h.CreateCustomizationTemplate).Methods("POST", "OPTIONS")
vendorRoutes.HandleFunc("/customization-templates", h.GetCustomizationTemplates).Methods("GET", "OPTIONS")
vendorRoutes.HandleFunc("/customization-templates/{id}", h.GetCustomizationTemplate).Methods("GET", "OPTIONS")
vendorRoutes.HandleFunc("/customization-templates/{id}", h.UpdateCustomizationTemplate).Methods("PUT", "OPTIONS")
vendorRoutes.HandleFunc("/customization-templates/{id}", h.DeleteCustomizationTemplate).Methods("DELETE", "OPTIONS")
```

**Admin Routes (lines 117-120):**
```go
adminRoutes.HandleFunc("/customization-templates", h.GetAllCustomizationTemplates).Methods("GET", "OPTIONS")
adminRoutes.HandleFunc("/customization-templates", h.CreateSystemWideCustomizationTemplate).Methods("POST", "OPTIONS")
adminRoutes.HandleFunc("/customization-templates/{id}", h.UpdateSystemWideCustomizationTemplate).Methods("PUT", "OPTIONS")
adminRoutes.HandleFunc("/customization-templates/{id}", h.DeleteSystemWideCustomizationTemplate).Methods("DELETE", "OPTIONS")
```

### 5. Database Initialization (`backend/database/database.go`)

Added `CustomizationTemplates` to Dependencies struct and initialized in CreateApp():
```go
CustomizationTemplates: repositories.NewCustomizationTemplateRepository(db)
```

### 6. OpenAPI Documentation

**Main File:** `backend/openapi.yaml`
- Added "Customization Templates" tag
- Added path references for all endpoints
- Added schema references

**Schema File:** `backend/openapi/schemas/customization_template.yaml`
- `MenuCustomizationTemplate` - Full entity schema with examples
- `CreateCustomizationTemplateRequest` - Create request schema
- `UpdateCustomizationTemplateRequest` - Update request schema

**Paths File:** `backend/openapi/paths/customization_templates.yaml`
- Complete documentation for all 9 endpoints
- Multiple examples (Spice Level, Pizza Toppings, Size Options)
- Request/response schemas
- Error responses (400, 401, 403, 404, 500)

## Files Updated

1. **backend/sql/schema.sql**
   - Added menu_customization_templates table (lines 324-340)
   - Added indexes (lines 846-848)
   - Added updated_at trigger (lines 989-991)

2. **backend/sql/drop_all.sql**
   - Added DROP TABLE statement (line 34)
   - Updated completion message (line 87)

3. **backend/database/database.go**
   - Added CustomizationTemplates field to Dependencies struct
   - Initialized repository in CreateApp()

4. **backend/main.go**
   - Added vendor routes (lines 189-194)
   - Added admin routes (lines 117-120)

5. **backend/openapi.yaml**
   - Added tag (line 39-40)
   - Added path references (lines 129-137)
   - Added schema references (lines 288-294)

## Authorization & Access Control

### Vendor Permissions:
- **Can Create:** Own templates (vendor_id = their vendor ID)
- **Can View:** Own templates + system-wide templates (vendor_id IS NULL)
- **Can Update:** Only their own templates
- **Can Delete:** Only their own templates

### Admin Permissions:
- **Can Create:** System-wide templates (vendor_id = NULL)
- **Can View:** All templates (vendor-specific and system-wide)
- **Can Update:** Any template
- **Can Delete:** Any template

### Implementation:
- Vendor ownership verified via `VerifyVendorOwnership()` method
- Access control enforced in handlers before repository calls
- System-wide templates are read-only for vendors

## Example Customization Configs

### 1. Single Select (Spice Level)
```json
{
  "type": "select",
  "options": [
    {"label": "Mild", "value": "mild", "price": 0},
    {"label": "Medium", "value": "medium", "price": 0},
    {"label": "Hot", "value": "hot", "price": 0},
    {"label": "Extra Hot", "value": "extra_hot", "price": 1.00}
  ]
}
```

### 2. Multi-Select (Pizza Toppings)
```json
{
  "type": "multi-select",
  "max_selections": 5,
  "options": [
    {"label": "Pepperoni", "value": "pepperoni", "price": 2.00},
    {"label": "Mushrooms", "value": "mushrooms", "price": 1.50},
    {"label": "Extra Cheese", "value": "extra_cheese", "price": 1.00}
  ]
}
```

### 3. Size Options (System-wide)
```json
{
  "type": "select",
  "options": [
    {"label": "Small", "value": "small", "price": 0},
    {"label": "Medium", "value": "medium", "price": 3.00},
    {"label": "Large", "value": "large", "price": 5.00}
  ]
}
```

**Note:** The frontend can define any structure for customization_config - these are just examples.

## Testing

### Test Script: `backend/test_customization_templates.sh`

**Tests Included:**
1. Vendor login
2. Admin login
3. Vendor creates template (Spice Level)
4. Vendor gets all templates
5. Vendor gets specific template by ID
6. Vendor updates template
7. Admin creates system-wide template (Size Options)
8. Admin gets all templates
9. Vendor sees system-wide template in their list
10. Vendor creates another template (Pizza Toppings)
11. Vendor deletes template
12. Admin deletes system-wide template
13. Final verification of remaining templates

**Run Tests:**
```bash
# Make sure backend is running on http://localhost:8080
cd backend
chmod +x test_customization_templates.sh
./test_customization_templates.sh
```

## Database Migration

To apply the schema changes:

```bash
# Option 1: Full reset (development)
./tools/sh/setup-database.sh

# Option 2: Manual apply (if you have data to preserve)
psql $DATABASE_URL -f backend/sql/schema.sql

# Verify table was created
psql $DATABASE_URL -c "\d menu_customization_templates"
```

## API Usage Examples

### Vendor Creates Template
```bash
curl -X POST http://localhost:8080/api/vendor/customization-templates \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
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
  }'
```

### Vendor Gets All Templates (including system-wide)
```bash
curl -X GET http://localhost:8080/api/vendor/customization-templates \
  -H "Authorization: Bearer $VENDOR_TOKEN"
```

### Admin Creates System-Wide Template
```bash
curl -X POST http://localhost:8080/api/admin/customization-templates \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
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
  }'
```

### Vendor Updates Template
```bash
curl -X PUT http://localhost:8080/api/vendor/customization-templates/1 \
  -H "Authorization: Bearer $VENDOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "UPDATED description",
    "is_active": false
  }'
```

### Vendor Deletes Template
```bash
curl -X DELETE http://localhost:8080/api/vendor/customization-templates/1 \
  -H "Authorization: Bearer $VENDOR_TOKEN"
```

## Response Format

### Success Response (Single Template)
```json
{
  "success": true,
  "message": "Customization template created successfully",
  "data": {
    "id": 1,
    "name": "Spice Level",
    "description": "Choose your preferred spice level",
    "customization_config": "{\"type\":\"select\",\"options\":[...]}",
    "vendor_id": 1,
    "is_active": true,
    "created_at": "2025-01-15T10:30:00Z",
    "updated_at": "2025-01-15T10:30:00Z"
  }
}
```

### Success Response (List)
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
      "vendor_id": null,  // System-wide template
      ...
    }
  ]
}
```

### Error Response
```json
{
  "success": false,
  "message": "Access denied to this customization template"
}
```

## Next Steps for Frontend Integration

1. **Create Dart Model** (`frontend/lib/models/customization_template.dart`):
   - MenuCustomizationTemplate class
   - fromJson/toJson methods
   - Handle nullable vendor_id for system-wide templates

2. **Create Service** (`frontend/lib/services/customization_template_service.dart`):
   - getTemplates() - GET /api/vendor/customization-templates
   - getTemplate(id) - GET /api/vendor/customization-templates/{id}
   - createTemplate(data) - POST /api/vendor/customization-templates
   - updateTemplate(id, data) - PUT /api/vendor/customization-templates/{id}
   - deleteTemplate(id) - DELETE /api/vendor/customization-templates/{id}

3. **Create UI Screens:**
   - Template list screen (show vendor's templates + system-wide)
   - Template create/edit form
   - Template selector widget for menu composition
   - Visual indicator for system-wide vs. vendor-owned templates

4. **Menu Composition:**
   - Allow vendors to reference templates by ID in menu_config
   - Or embed template config directly into menu items
   - Frontend decides how to structure this relationship

## Implementation Checklist

- [x] Database schema (table, indexes, triggers)
- [x] Drop script updated
- [x] Go models created
- [x] Repository interface and implementation
- [x] Handler methods (vendor and admin)
- [x] Routes added to main.go
- [x] Database dependencies updated
- [x] OpenAPI documentation (schema and paths)
- [x] Test script created
- [x] Backend compiles successfully
- [x] Implementation summary document

## Technical Notes

1. **JSONB Field:** customization_config is stored as JSONB in PostgreSQL but handled as string in Go for flexibility
2. **Unique Constraint:** (vendor_id, name) ensures no duplicate names per vendor, but allows different vendors to use the same name
3. **System-Wide Templates:** vendor_id=NULL means template is visible to all vendors (read-only for vendors)
4. **Size Limit:** customization_config is limited to 100KB to prevent abuse
5. **Validation:** JSON structure is validated on create/update but not enforced (frontend defines structure)
6. **Cascade Delete:** Deleting a vendor will cascade delete their templates (ON DELETE CASCADE)

## Architecture Decisions

1. **Flexible JSON Structure:** Chose not to enforce a strict schema for customization_config to allow frontend flexibility
2. **Ownership Model:** Vendor-owned vs. system-wide (NULL vendor_id) provides good balance of control and sharing
3. **Repository Pattern:** Consistent with existing codebase patterns (RestaurantRepository, MenuRepository, etc.)
4. **Authorization:** Enforced at handler level before repository calls (follows existing pattern)
5. **Separate Admin Endpoints:** Admin endpoints separate from vendor endpoints for clarity and future extensibility

## Performance Considerations

1. **Indexes Added:**
   - vendor_id index for fast vendor-specific queries
   - is_active index for filtering active templates
   - name index for name-based searches

2. **Query Optimization:**
   - GetByVendorID() uses single query with OR condition (vendor_id = ? OR vendor_id IS NULL)
   - NULLS FIRST in ORDER BY ensures system-wide templates appear first

3. **Size Limits:**
   - 100KB limit on customization_config prevents database bloat
   - Validation happens before database insert

## Security Considerations

1. **Authentication:** All endpoints require JWT authentication
2. **Authorization:** Vendor ownership verified before updates/deletes
3. **Input Validation:** Name, JSON structure, and size validated
4. **SQL Injection:** All queries use prepared statements
5. **CORS:** Handled by existing CORS middleware
