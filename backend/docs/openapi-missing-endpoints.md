# Missing OpenAPI Endpoints - Audit Report

**Generated:** 2025-10-26
**Status:** Review needed before adding to OpenAPI spec

## Summary

After reviewing the refactored OpenAPI specification structure against the implemented routes in `main.go`, the following endpoints are implemented in code but **missing from the OpenAPI documentation**:

---

## ✅ Driver Order Endpoints - FIXED

These were previously added to `openapi/paths/orders.yaml` and now referenced in main `openapi.yaml`:

- `GET /api/driver/orders/available`
- `GET /api/driver/orders`
- `GET /api/driver/orders/{id}`
- `POST /api/driver/orders/{id}/assign`
- `PUT /api/driver/orders/{id}/status`

**Status:** ✅ Complete - All driver endpoints now documented

---

## ❌ Approval System Endpoints - MISSING

The following approval-related endpoints are implemented but not in OpenAPI spec:

### Admin Approval Endpoints

**File to create:** `openapi/paths/approvals.yaml`

1. **`GET /api/admin/approvals/vendors`**
   - Summary: Get pending vendor approvals
   - Description: Retrieve list of vendors awaiting approval
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.GetPendingVendors`

2. **`GET /api/admin/approvals/restaurants`**
   - Summary: Get pending restaurant approvals
   - Description: Retrieve list of restaurants awaiting approval
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.GetPendingRestaurants`

3. **`GET /api/admin/approvals/dashboard`**
   - Summary: Get approval dashboard
   - Description: Get overview of all pending approvals
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.GetApprovalDashboard`

4. **`PUT /api/admin/vendors/{id}/approve`**
   - Summary: Approve vendor
   - Description: Approve a vendor application
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.ApproveVendor`

5. **`PUT /api/admin/vendors/{id}/reject`**
   - Summary: Reject vendor
   - Description: Reject a vendor application
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.RejectVendor`

6. **`PUT /api/admin/restaurants/{id}/approve`**
   - Summary: Approve restaurant
   - Description: Approve a restaurant listing
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.ApproveRestaurant`

7. **`PUT /api/admin/restaurants/{id}/reject`**
   - Summary: Reject restaurant
   - Description: Reject a restaurant listing
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.RejectRestaurant`

8. **`GET /api/admin/approvals/history`**
   - Summary: Get approval history
   - Description: Retrieve history of all approval/rejection decisions
   - Tags: Approvals
   - Security: Admin only
   - Handler: `h.GetApprovalHistory`

### Vendor Approval Status Endpoint

9. **`GET /api/vendor/approval-status`**
   - Summary: Get vendor approval status
   - Description: Check the approval status of the authenticated vendor
   - Tags: Approvals
   - Security: Vendor only
   - Handler: `h.GetVendorApprovalStatus`

---

## ❌ Image Upload Endpoints - MISSING

**File to create:** `openapi/paths/uploads.yaml`

1. **`POST /api/vendor/upload-image`**
   - Summary: Upload menu item image
   - Description: Upload an image for menu items
   - Tags: Media
   - Security: Vendor only
   - Content-Type: multipart/form-data
   - Handler: `h.UploadImage`
   - Request Body:
     - `file`: binary (image file)
     - `category`: string (optional - menu_item, restaurant_logo, etc.)
   - Response:
     - `image_url`: string (URL to uploaded image)
     - `filename`: string

2. **`DELETE /api/vendor/images/{filename}`**
   - Summary: Delete uploaded image
   - Description: Delete an image by filename
   - Tags: Media
   - Security: Vendor only
   - Handler: `h.DeleteImage`

---

## Missing OpenAPI Tags

The following tags need to be added to the main `openapi.yaml` file:

```yaml
- name: Approvals
  description: Vendor and restaurant approval workflow management
- name: Media
  description: Image upload and management for menu items and restaurants
```

---

## Implementation Checklist

### Priority 1: Approval Endpoints (High Priority)

- [ ] Create `openapi/paths/approvals.yaml`
- [ ] Define approval request/response schemas in `openapi/schemas/approval.yaml`
- [ ] Add Approvals tag to main `openapi.yaml`
- [ ] Reference all approval paths in main `openapi.yaml`
- [ ] Document approval workflow states (pending, approved, rejected)
- [ ] Document admin permissions requirements

### Priority 2: Image Upload Endpoints (Medium Priority)

- [ ] Create `openapi/paths/uploads.yaml`
- [ ] Define multipart/form-data request schema
- [ ] Add Media tag to main `openapi.yaml`
- [ ] Reference upload paths in main `openapi.yaml`
- [ ] Document supported image formats
- [ ] Document file size limits
- [ ] Document storage location (/uploads/)

### Priority 3: Schema Additions

**Approval Schemas** (`openapi/schemas/approval.yaml`):
- `ApprovalStatus` (enum: pending, approved, rejected)
- `VendorApproval` (vendor with approval metadata)
- `RestaurantApproval` (restaurant with approval metadata)
- `ApprovalDashboard` (counts and lists)
- `ApprovalHistoryEntry` (audit log entry)
- `ApproveRequest` (optional notes)
- `RejectRequest` (required reason)

**Upload Schemas** (`openapi/schemas/upload.yaml`):
- `UploadImageResponse` (url, filename, size)
- `ImageMetadata` (width, height, format)

---

## Verification Script

```bash
#!/bin/bash
# Run this to verify all routes are documented

echo "Routes in main.go:"
grep "HandleFunc" backend/main.go | \
  sed 's/.*HandleFunc("//' | \
  sed 's/".*//' | \
  grep -E "^/api/" | \
  sort > /tmp/routes_main.txt

echo "Routes in openapi.yaml:"
grep "ref:.*paths" backend/openapi.yaml | \
  sed "s/.*#\///" | \
  sed "s/'$//" | \
  sed 's/~1/\//g' | \
  sort > /tmp/routes_openapi.txt

echo ""
echo "Missing from OpenAPI:"
comm -23 /tmp/routes_main.txt /tmp/routes_openapi.txt

echo ""
echo "Extra in OpenAPI (not in code):"
comm -13 /tmp/routes_main.txt /tmp/routes_openapi.txt
```

---

## Next Steps

1. **Create approval endpoints documentation** - This is high priority as it's a core feature
2. **Create image upload documentation** - Medium priority for vendor menu management
3. **Run verification script** to ensure no other endpoints are missing
4. **Update main openapi.yaml** to reference new path files
5. **Test OpenAPI spec** with validator or Swagger UI
6. **Generate API client libraries** (optional) from complete spec

---

## Additional Notes

### Approval System Flow

The approval system workflow should be documented:

```
Vendor Registration → pending → approved/rejected
Restaurant Creation → pending → approved/rejected
```

Only approved vendors can create restaurants.
Only approved restaurants appear in customer/driver views.

### Image Upload Considerations

- Current implementation uses local filesystem (`/uploads/`)
- Production should use S3 or similar object storage
- Need to document:
  - Maximum file size (e.g., 5MB)
  - Allowed formats (JPG, PNG, WebP)
  - Image optimization/resizing
  - URL format and CDN usage

### Security Considerations

All endpoints require:
- JWT authentication via BearerAuth
- Role-based authorization (admin, vendor)
- Input validation
- File upload safety checks (MIME type, virus scanning)

---

*Last Updated: 2025-10-26*
*Next Review: After approval/upload endpoints are added to OpenAPI spec*
