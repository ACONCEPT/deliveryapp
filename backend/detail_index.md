# Detailed Index - Backend Source Code Files
# Detailed summaries with structures, function signatures, and line numbers

================================================================================
FILE: main.go
================================================================================
PURPOSE: Main application entry point with route configuration and server startup.
LANGUAGE: Go
DEPENDENCIES: gorilla/mux, godotenv/autoload

FUNCTION: main() [line 15]
  - Loads configuration from environment variables
  - Initializes database connection and repositories
  - Creates handler instance with JWT secret
  - Configures all HTTP routes and middleware
  - Starts HTTP server on configured port

ROUTE CONFIGURATION:
  Public routes:
    - POST /api/login [line 49]
    - POST /api/signup [line 50]

  Protected routes (requires authentication):
    - GET /api/profile [line 57]
    - GET /api/addresses [line 60]
    - GET /api/addresses/{id} [line 61]
    - GET /api/restaurants [line 64]
    - GET /api/restaurants/{id} [line 65]
    - GET /api/restaurants/{restaurant_id}/owner [line 66]

  Admin-only routes (/api/admin/*):
    - GET /api/admin/vendor-restaurants [line 74]
    - GET /api/admin/vendor-restaurants/{id} [line 75]
    - DELETE /api/admin/vendor-restaurants/{id} [line 76]
    - PUT /api/admin/restaurants/{restaurant_id}/transfer [line 77]

  Vendor-only routes (/api/vendor/*):
    - POST /api/vendor/restaurants [line 85]
    - PUT /api/vendor/restaurants/{id} [line 86]
    - DELETE /api/vendor/restaurants/{id} [line 87]

  Customer-only routes (/api/customer/*):
    - POST /api/customer/addresses [line 95]
    - PUT /api/customer/addresses/{id} [line 96]
    - DELETE /api/customer/addresses/{id} [line 97]
    - PUT /api/customer/addresses/{id}/set-default [line 98]

MIDDLEWARE STACK:
  - CORSMiddleware [line 107] - handles preflight requests
  - RecoveryMiddleware [line 108] - panic recovery
  - LoggingMiddleware [line 109] - request logging


================================================================================
FILE: middleware.go
================================================================================
PURPOSE: HTTP middleware functions for CORS, logging, and error recovery.
LANGUAGE: Go
DEPENDENCIES: net/http, time

FUNCTION: CORSMiddleware(next http.Handler) http.Handler [line 11]
  - Adds permissive CORS headers for development use
  - Allows all origins, credentials, common methods and headers
  - Handles OPTIONS preflight requests
  - Returns 204 No Content for OPTIONS

FUNCTION: LoggingMiddleware(next http.Handler) http.Handler [line 46]
  - Logs incoming HTTP requests with method, path, and remote address
  - Tracks request duration and logs completion time
  - Uses log.Printf for structured output

FUNCTION: RecoveryMiddleware(next http.Handler) http.Handler [line 62]
  - Recovers from panics in HTTP handlers
  - Logs panic details to console
  - Returns 500 Internal Server Error to client
  - Prevents server crashes from handler errors


================================================================================
FILE: config/config.go
================================================================================
PURPOSE: Application configuration management from environment variables.
LANGUAGE: Go
DEPENDENCIES: os, strconv

STRUCT: Config [lines 10-16]
  Fields:
    - DatabaseURL string
    - ServerPort string
    - JWTSecret string
    - TokenDuration int (in hours)
    - Environment string

FUNCTION: Load() (*Config, error) [line 19]
  - Reads environment variables for configuration
  - Sets defaults: ServerPort=8080, TokenDuration=72, Environment=development
  - Validates required fields: DATABASE_URL and JWT_SECRET
  - Returns error if required fields are missing

FUNCTION: getEnv(key, defaultValue string) string [line 41]
  - Helper to retrieve environment variable with fallback
  - Returns defaultValue if environment variable is empty

FUNCTION: getEnvAsInt(key string, defaultValue int) int [line 50]
  - Helper to retrieve environment variable as integer
  - Returns defaultValue if not set or conversion fails
  - Uses strconv.Atoi for conversion


================================================================================
FILE: database/database.go
================================================================================
PURPOSE: Database connection initialization and dependency injection container.
LANGUAGE: Go
DEPENDENCIES: jmoiron/sqlx, lib/pq

STRUCT: App [lines 13-16]
  Fields:
    - DB *sqlx.DB - database connection
    - Deps *Dependencies - repository container

STRUCT: Dependencies [lines 19-24]
  Fields:
    - Users repositories.UserRepository
    - Addresses repositories.CustomerAddressRepository
    - Restaurants repositories.RestaurantRepository
    - VendorRestaurants repositories.VendorRestaurantRepository

FUNCTION: CreateApp(databaseURL string) (*App, error) [line 27]
  - Connects to PostgreSQL using sqlx
  - Pings database to verify connection
  - Initializes all repository instances
  - Returns App with DB and Dependencies
  - Logs success message on connection

METHOD: Close() error [line 56]
  - Closes database connection gracefully
  - Logs closure message
  - Returns error if close fails


================================================================================
FILE: models/user.go
================================================================================
PURPOSE: Data models for users, profiles, authentication, and addresses.
LANGUAGE: Go
DEPENDENCIES: time

TYPE: UserType string [line 6]
  Constants:
    - UserTypeCustomer = "customer" [line 9]
    - UserTypeVendor = "vendor" [line 10]
    - UserTypeDriver = "driver" [line 11]
    - UserTypeAdmin = "admin" [line 12]

TYPE: UserStatus string [line 16]
  Constants:
    - UserStatusActive = "active" [line 19]
    - UserStatusInactive = "inactive" [line 20]
    - UserStatusSuspended = "suspended" [line 21]

STRUCT: User [lines 25-34]
  - Main user entity with authentication fields
  - PasswordHash excluded from JSON serialization

STRUCT: Customer [lines 37-45]
  - Customer profile with full name, phone, default address

STRUCT: Vendor [lines 48-67]
  - Vendor/business profile with location, rating, metrics

STRUCT: Driver [lines 70-85]
  - Driver profile with vehicle info, location, ratings

STRUCT: Admin [lines 88-97]
  - Admin profile with role and permissions (JSONB)

STRUCT: LoginRequest [lines 100-103]
  - Username and password with validation tags

STRUCT: SignupRequest [lines 106-122]
  - User registration with type-specific optional fields
  - Includes validation tags for email, password length

STRUCT: LoginResponse [lines 125-131]
  - Success flag, message, JWT token, user, and profile

STRUCT: SignupResponse [lines 134-138]
  - Success flag, message, and created user ID

STRUCT: ErrorResponse [lines 141-145]
  - Standard error response format

STRUCT: CustomerAddress [lines 148-162]
  - Address with geolocation and default flag

STRUCT: CreateAddressRequest [lines 165-175]
  - Address creation with required/optional fields

STRUCT: UpdateAddressRequest [lines 178-188]
  - All fields optional for partial updates


================================================================================
FILE: models/restaurant.go
================================================================================
PURPOSE: Data models for restaurants and vendor-restaurant relationships.
LANGUAGE: Go
DEPENDENCIES: time

STRUCT: Restaurant [lines 6-24]
  - Restaurant entity with location, contact, rating, order metrics
  - Supports geocoding with latitude/longitude

STRUCT: VendorRestaurant [lines 27-33]
  - Junction table model for vendor-restaurant ownership
  - Links vendor_id to restaurant_id

STRUCT: RestaurantWithVendor [lines 36-40]
  - Combined view with restaurant and vendor information
  - Embeds Restaurant struct and adds vendor fields

STRUCT: CreateRestaurantRequest [lines 43-55]
  - Restaurant creation with name (required) and optional details

STRUCT: UpdateRestaurantRequest [lines 58-71]
  - All fields optional for partial restaurant updates
  - Includes is_active for enabling/disabling


================================================================================
FILE: repositories/common.go
================================================================================
PURPOSE: Shared database query helpers for repository layer.
LANGUAGE: Go
DEPENDENCIES: database/sql, jmoiron/sqlx

FUNCTION: ExecuteStatement(db *sqlx.DB, query string, args []interface{}) (sql.Result, error) [line 11]
  - Executes INSERT, UPDATE, DELETE statements
  - Returns sql.Result with affected rows info
  - Wraps errors with context message

FUNCTION: GetData(db *sqlx.DB, query string, dest interface{}, args []interface{}) error [line 20]
  - Executes query expecting single row (typically with RETURNING)
  - Uses StructScan to populate dest struct
  - Returns error if no rows or query fails

FUNCTION: SelectData(db *sqlx.DB, query string, dest interface{}, args []interface{}) error [line 32]
  - Executes query expecting multiple rows
  - Populates dest slice with results
  - Returns nil (not error) if no rows found

FUNCTION: QueryRow(db *sqlx.DB, query string, args []interface{}) *sqlx.Row [line 44]
  - Raw query for single row
  - Returns sqlx.Row for manual scanning

FUNCTION: Query(db *sqlx.DB, query string, args []interface{}) (*sqlx.Rows, error) [line 49]
  - Raw query for multiple rows
  - Returns sqlx.Rows for iteration


================================================================================
FILE: repositories/user_repository.go
================================================================================
PURPOSE: User and user profile data access with authentication.
LANGUAGE: Go
DEPENDENCIES: database/sql, jmoiron/sqlx, golang.org/x/crypto/bcrypt

INTERFACE: UserRepository [lines 13-28]
  Methods:
    - Create(user *models.User) error
    - GetByUsername(username string) (*models.User, error)
    - GetByEmail(email string) (*models.User, error)
    - GetByID(id int) (*models.User, error)
    - UserExists(username, email string) (bool, error)
    - ValidateCredentials(username, password string) (*models.User, error)
    - CreateCustomerProfile(userID int, customer *models.Customer) error
    - CreateVendorProfile(userID int, vendor *models.Vendor) error
    - CreateDriverProfile(userID int, driver *models.Driver) error
    - CreateAdminProfile(userID int, admin *models.Admin) error
    - GetCustomerByUserID(userID int) (*models.Customer, error)
    - GetVendorByUserID(userID int) (*models.Vendor, error)
    - GetDriverByUserID(userID int) (*models.Driver, error)
    - GetAdminByUserID(userID int) (*models.Admin, error)

STRUCT: userRepository [lines 31-33]
  - Private implementation of UserRepository
  - Holds *sqlx.DB connection

FUNCTION: NewUserRepository(db *sqlx.DB) UserRepository [line 36]
  - Factory function returning UserRepository interface

METHOD: Create(user *models.User) error [line 41]
  - Hashes password with bcrypt.DefaultCost
  - Inserts user with RETURNING clause
  - Sets status to active by default

METHOD: GetByUsername(username string) (*models.User, error) [line 66]
  - Retrieves user by username
  - Returns "user not found" error if no match

METHOD: GetByEmail(email string) (*models.User, error) [line 82]
  - Retrieves user by email
  - Returns "user not found" error if no match

METHOD: GetByID(id int) (*models.User, error) [line 98]
  - Retrieves user by primary key
  - Returns "user not found" error if no match

METHOD: UserExists(username, email string) (bool, error) [line 114]
  - Checks if username OR email already exists
  - Uses COUNT(*) query for efficiency
  - Returns true if count > 0

METHOD: ValidateCredentials(username, password string) (*models.User, error) [line 127]
  - Fetches user by username
  - Compares password hash using bcrypt
  - Checks user status is active
  - Returns error if credentials invalid or user inactive

METHOD: CreateCustomerProfile(userID int, customer *models.Customer) error [line 148]
  - Inserts customer profile with RETURNING clause
  - Links to user_id foreign key

METHOD: CreateVendorProfile(userID int, vendor *models.Vendor) error [line 165]
  - Inserts vendor profile with business details
  - Returns all vendor fields including defaults

METHOD: CreateDriverProfile(userID int, driver *models.Driver) error [line 185]
  - Inserts driver profile with vehicle information
  - Returns driver with availability and rating defaults

METHOD: CreateAdminProfile(userID int, admin *models.Admin) error [line 207]
  - Inserts admin profile with role and permissions
  - Permissions stored as JSONB

METHOD: GetCustomerByUserID(userID int) (*models.Customer, error) [line 225]
  - Fetches customer profile by user ID
  - Returns error if not found

METHOD: GetVendorByUserID(userID int) (*models.Vendor, error) [line 241]
  - Fetches vendor profile by user ID
  - Returns error if not found

METHOD: GetDriverByUserID(userID int) (*models.Driver, error) [line 257]
  - Fetches driver profile by user ID
  - Returns error if not found

METHOD: GetAdminByUserID(userID int) (*models.Admin, error) [line 273]
  - Fetches admin profile by user ID
  - Returns error if not found


================================================================================
FILE: repositories/customer_address_repository.go
================================================================================
PURPOSE: Customer address CRUD operations with default address management.
LANGUAGE: Go
DEPENDENCIES: database/sql, jmoiron/sqlx

INTERFACE: CustomerAddressRepository [lines 12-20]
  Methods:
    - Create(address *models.CustomerAddress) error
    - GetByID(id int) (*models.CustomerAddress, error)
    - GetByCustomerID(customerID int) ([]*models.CustomerAddress, error)
    - Update(address *models.CustomerAddress) error
    - Delete(id int) error
    - SetDefault(customerID, addressID int) error
    - GetDefaultByCustomerID(customerID int) (*models.CustomerAddress, error)

STRUCT: customerAddressRepository [lines 23-25]
  - Private implementation holding *sqlx.DB

FUNCTION: NewCustomerAddressRepository(db *sqlx.DB) CustomerAddressRepository [line 28]
  - Factory function returning interface

METHOD: Create(address *models.CustomerAddress) error [line 33]
  - Inserts address with all fields
  - Returns created address with RETURNING clause

METHOD: GetByID(id int) (*models.CustomerAddress, error) [line 61]
  - Fetches single address by primary key
  - Returns "address not found" if no match

METHOD: GetByCustomerID(customerID int) ([]*models.CustomerAddress, error) [line 77]
  - Fetches all addresses for a customer
  - Orders by is_default DESC, created_at DESC
  - Returns empty slice (not nil) if no addresses

METHOD: Update(address *models.CustomerAddress) error [line 95]
  - Updates all address fields by ID
  - Sets updated_at to CURRENT_TIMESTAMP
  - Returns updated address with RETURNING

METHOD: Delete(id int) error [line 123]
  - Deletes address by ID
  - Checks rows affected to verify deletion
  - Returns error if address not found

METHOD: SetDefault(customerID, addressID int) error [line 144]
  - Uses transaction to ensure atomicity
  - Unsets all defaults for customer
  - Sets specified address as default
  - Verifies address belongs to customer
  - Commits or rolls back transaction

METHOD: GetDefaultByCustomerID(customerID int) (*models.CustomerAddress, error) [line 186]
  - Fetches default address for customer
  - Returns error if no default set


================================================================================
FILE: repositories/restaurant_repository.go
================================================================================
PURPOSE: Restaurant CRUD operations with vendor-specific queries.
LANGUAGE: Go
DEPENDENCIES: database/sql, jmoiron/sqlx

INTERFACE: RestaurantRepository [lines 12-20]
  Methods:
    - Create(restaurant *models.Restaurant) error
    - GetByID(id int) (*models.Restaurant, error)
    - GetAll() ([]models.Restaurant, error)
    - GetByVendorID(vendorID int) ([]models.Restaurant, error)
    - GetWithVendorInfo() ([]models.RestaurantWithVendor, error)
    - Update(restaurant *models.Restaurant) error
    - Delete(id int) error

STRUCT: restaurantRepository [lines 23-25]
  - Private implementation holding *sqlx.DB

FUNCTION: NewRestaurantRepository(db *sqlx.DB) RestaurantRepository [line 28]
  - Factory function returning interface

METHOD: Create(restaurant *models.Restaurant) error [line 33]
  - Inserts restaurant with is_active=true default
  - Returns all fields including auto-set rating and total_orders

METHOD: GetByID(id int) (*models.Restaurant, error) [line 62]
  - Fetches restaurant by primary key
  - Returns "restaurant not found" if no match

METHOD: GetAll() ([]models.Restaurant, error) [line 78]
  - Fetches all restaurants ordered by name ASC
  - Returns empty slice if none found

METHOD: GetByVendorID(vendorID int) ([]models.Restaurant, error) [line 91]
  - Joins restaurants with vendor_restaurants table
  - Filters by vendor_id
  - Orders by name ASC

METHOD: GetWithVendorInfo() ([]models.RestaurantWithVendor, error) [line 110]
  - LEFT JOINs restaurants with vendor_restaurants and vendors
  - Returns combined restaurant and vendor data
  - Includes restaurants without vendors (orphans)

METHOD: Update(restaurant *models.Restaurant) error [line 129]
  - Updates all restaurant fields by ID
  - Sets updated_at to CURRENT_TIMESTAMP
  - Returns updated restaurant with RETURNING

METHOD: Delete(id int) error [line 161]
  - Deletes restaurant by ID
  - Cascade deletes vendor_restaurants entries
  - Checks rows affected to confirm deletion


================================================================================
FILE: repositories/vendor_restaurant_repository.go
================================================================================
PURPOSE: Vendor-restaurant relationship management and ownership transfers.
LANGUAGE: Go
DEPENDENCIES: database/sql, jmoiron/sqlx

INTERFACE: VendorRestaurantRepository [lines 12-21]
  Methods:
    - Create(vendorRestaurant *models.VendorRestaurant) error
    - GetByID(id int) (*models.VendorRestaurant, error)
    - GetByRestaurantID(restaurantID int) (*models.VendorRestaurant, error)
    - GetByVendorID(vendorID int) ([]models.VendorRestaurant, error)
    - GetAll() ([]models.VendorRestaurant, error)
    - Delete(id int) error
    - DeleteByRestaurantID(restaurantID int) error
    - TransferOwnership(restaurantID, newVendorID int) error

STRUCT: vendorRestaurantRepository [lines 24-26]
  - Private implementation holding *sqlx.DB

FUNCTION: NewVendorRestaurantRepository(db *sqlx.DB) VendorRestaurantRepository [line 29]
  - Factory function returning interface

METHOD: Create(vendorRestaurant *models.VendorRestaurant) error [line 34]
  - Creates vendor-restaurant link
  - Returns created record with timestamps

METHOD: GetByID(id int) (*models.VendorRestaurant, error) [line 50]
  - Fetches relationship by primary key
  - Returns error if not found

METHOD: GetByRestaurantID(restaurantID int) (*models.VendorRestaurant, error) [line 66]
  - Fetches relationship by restaurant ID
  - Returns "no vendor found" if restaurant is orphaned

METHOD: GetByVendorID(vendorID int) ([]models.VendorRestaurant, error) [line 82]
  - Fetches all restaurants owned by vendor
  - Orders by created_at DESC

METHOD: GetAll() ([]models.VendorRestaurant, error) [line 99]
  - Fetches all vendor-restaurant relationships
  - Orders by created_at DESC

METHOD: Delete(id int) error [line 112]
  - Deletes relationship by primary key
  - Checks rows affected to verify deletion

METHOD: DeleteByRestaurantID(restaurantID int) error [line 134]
  - Deletes relationship by restaurant ID
  - Orphans the restaurant (no vendor ownership)
  - Checks rows affected

METHOD: TransferOwnership(restaurantID, newVendorID int) error [line 156]
  - Updates vendor_id for restaurant
  - Sets updated_at to CURRENT_TIMESTAMP
  - Returns error if restaurant has no existing ownership


================================================================================
FILE: handlers/handler.go
================================================================================
PURPOSE: Base handler struct and JSON response utilities.
LANGUAGE: Go
DEPENDENCIES: encoding/json, net/http

STRUCT: Handler [lines 10-13]
  Fields:
    - App *database.App - database and repositories
    - JWTSecret string - for token generation

FUNCTION: NewHandler(app *database.App, jwtSecret string) *Handler [line 16]
  - Factory function creating Handler instance
  - Called from main.go with database app and config

FUNCTION: sendJSON(w http.ResponseWriter, status int, data interface{}) [line 24]
  - Sets Content-Type to application/json
  - Writes status code and encodes data as JSON

FUNCTION: sendError(w http.ResponseWriter, status int, message string) [line 31]
  - Sends standardized error response
  - Sets success=false and includes message

FUNCTION: sendSuccess(w http.ResponseWriter, status int, message string, data interface{}) [line 39]
  - Sends standardized success response
  - Sets success=true, message, and data


================================================================================
FILE: handlers/auth.go
================================================================================
PURPOSE: Authentication handlers for login and signup with JWT tokens.
LANGUAGE: Go
DEPENDENCIES: encoding/json, net/http, time, golang-jwt/jwt/v5

STRUCT: JWTClaims [lines 13-18]
  - Custom JWT claims with UserID, Username, UserType
  - Embeds jwt.RegisteredClaims for standard fields

METHOD: generateToken(user *models.User, duration int) (string, error) [line 21]
  - Creates JWT with user claims and expiration
  - Sets issuer to "delivery_app"
  - Signs with HS256 and JWTSecret
  - Duration specified in hours

METHOD: Login(w http.ResponseWriter, r *http.Request) [line 40]
  - Decodes LoginRequest from body
  - Validates credentials via repository
  - Generates JWT token (72 hours default)
  - Fetches user profile based on user_type
  - Returns LoginResponse with token and profile

METHOD: Signup(w http.ResponseWriter, r *http.Request) [line 89]
  - Decodes SignupRequest from body
  - Validates user_type against allowed types
  - Checks if username/email already exists
  - Creates user with hashed password
  - Creates type-specific profile (customer/vendor/driver/admin)
  - Returns SignupResponse with user ID

FUNCTION: stringPtr(s string) *string [line 195]
  - Converts string to pointer
  - Returns nil if string is empty
  - Used for optional fields in signup


================================================================================
FILE: handlers/profile.go
================================================================================
PURPOSE: User profile retrieval for authenticated users.
LANGUAGE: Go
DEPENDENCIES: net/http, middleware

METHOD: GetProfile(w http.ResponseWriter, r *http.Request) [line 9]
  - Extracts authenticated user from context
  - Fetches user from database by ID
  - Retrieves type-specific profile (customer/vendor/driver/admin)
  - Returns combined user, profile, and auth_info response


================================================================================
FILE: handlers/customer_address.go
================================================================================
PURPOSE: Customer address CRUD handlers with ownership validation.
LANGUAGE: Go
DEPENDENCIES: encoding/json, net/http, strconv, gorilla/mux, middleware

METHOD: getCustomerIDFromUser(userID int) (int, error) [line 14]
  - Helper to retrieve customer ID from user ID
  - Used to verify customer ownership

METHOD: CreateAddress(w http.ResponseWriter, r *http.Request) [line 23]
  - Gets authenticated user from context
  - Retrieves customer ID for user
  - Decodes CreateAddressRequest
  - Handles default address logic (unsets others if default)
  - Creates address and optionally sets as default
  - Returns created address

METHOD: GetAddresses(w http.ResponseWriter, r *http.Request) [line 90]
  - Customers retrieve their own addresses
  - Vendors/drivers/admins specify customer_id query param
  - Fetches addresses ordered by default and created_at
  - Returns addresses array

METHOD: GetAddress(w http.ResponseWriter, r *http.Request) [line 138]
  - Extracts address ID from URL path
  - Fetches address by ID
  - Verifies customer ownership for customer users
  - Vendors/drivers/admins can view any address
  - Returns single address

METHOD: UpdateAddress(w http.ResponseWriter, r *http.Request) [line 183]
  - Extracts address ID from URL
  - Verifies customer ownership
  - Decodes UpdateAddressRequest (all fields optional)
  - Handles set-as-default logic if requested
  - Updates address and returns updated record

METHOD: DeleteAddress(w http.ResponseWriter, r *http.Request) [line 271]
  - Extracts address ID from URL
  - Verifies customer ownership
  - Deletes address from database
  - Returns success message

METHOD: SetDefaultAddress(w http.ResponseWriter, r *http.Request) [line 317]
  - Extracts address ID from URL
  - Verifies address belongs to customer
  - Calls SetDefault repository method (transaction-based)
  - Returns success message


================================================================================
FILE: handlers/restaurant.go
================================================================================
PURPOSE: Restaurant CRUD handlers with role-based access control.
LANGUAGE: Go
DEPENDENCIES: encoding/json, net/http, strconv, gorilla/mux, middleware

METHOD: CreateRestaurant(w http.ResponseWriter, r *http.Request) [line 15]
  - Vendor-only endpoint
  - Decodes CreateRestaurantRequest
  - Creates restaurant with is_active=true
  - Creates vendor-restaurant relationship
  - Rolls back restaurant if relationship creation fails
  - Returns created restaurant

METHOD: GetRestaurants(w http.ResponseWriter, r *http.Request) [line 80]
  - Vendors see only their own restaurants
  - Admins see all restaurants
  - Customers/drivers see only active restaurants
  - Returns filtered restaurant list

METHOD: GetRestaurant(w http.ResponseWriter, r *http.Request) [line 134]
  - Extracts restaurant ID from URL
  - Vendors can only view their own restaurants
  - Customers/drivers can only view active restaurants
  - Admins can view any restaurant
  - Returns single restaurant

METHOD: UpdateRestaurant(w http.ResponseWriter, r *http.Request) [line 184]
  - Vendors can update their own restaurants
  - Admins can update any restaurant
  - Decodes UpdateRestaurantRequest (all fields optional)
  - Applies partial updates to existing restaurant
  - Returns updated restaurant

METHOD: DeleteRestaurant(w http.ResponseWriter, r *http.Request) [line 281]
  - Vendors can delete their own restaurants
  - Admins can delete any restaurant
  - Verifies ownership for vendors
  - Cascade deletes vendor_restaurants entries
  - Returns success message


================================================================================
FILE: handlers/vendor_restaurant.go
================================================================================
PURPOSE: Vendor-restaurant relationship management for admins and ownership transfers.
LANGUAGE: Go
DEPENDENCIES: encoding/json, net/http, strconv, gorilla/mux, middleware

METHOD: GetVendorRestaurants(w http.ResponseWriter, r *http.Request) [line 15]
  - Admin-only endpoint
  - Fetches all vendor-restaurant relationships
  - Returns complete list

METHOD: GetVendorRestaurant(w http.ResponseWriter, r *http.Request) [line 30]
  - Admins can view any relationship
  - Vendors can view their own relationships
  - Extracts vendor-restaurant ID from URL
  - Verifies ownership for vendors
  - Returns single relationship

METHOD: GetRestaurantOwner(w http.ResponseWriter, r *http.Request) [line 72]
  - Public endpoint (authenticated users)
  - Extracts restaurant ID from URL
  - Fetches vendor-restaurant relationship
  - Fetches vendor profile details
  - Returns relationship and vendor info

METHOD: TransferRestaurantOwnership(w http.ResponseWriter, r *http.Request) [line 104]
  - Admin-only endpoint
  - Decodes new_vendor_id from request body
  - Verifies restaurant exists
  - Verifies new vendor exists
  - Calls TransferOwnership repository method
  - Returns success message

METHOD: DeleteVendorRestaurant(w http.ResponseWriter, r *http.Request) [line 156]
  - Admin-only endpoint
  - Deletes vendor-restaurant relationship by ID
  - WARNING: Orphans the restaurant (no vendor ownership)
  - Returns success message


================================================================================
FILE: middleware/auth.go
================================================================================
PURPOSE: JWT authentication and authorization middleware.
LANGUAGE: Go
DEPENDENCIES: net/http, strings, golang-jwt/jwt/v5

STRUCT: JWTClaims [lines 13-18]
  - JWT claims matching handler claims
  - UserID, Username, UserType, RegisteredClaims

FUNCTION: AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler [line 21]
  - Returns middleware function for required authentication
  - Extracts Authorization header (Bearer token format)
  - Parses and validates JWT with HMAC signing method
  - Extracts claims and adds AuthenticatedUser to context
  - Returns 401 if token missing, invalid, or expired

FUNCTION: OptionalAuthMiddleware(jwtSecret string) func(http.Handler) http.Handler [line 78]
  - Like AuthMiddleware but doesn't require token
  - Adds user to context if valid token provided
  - Continues without user if no token or invalid
  - Used for endpoints accessible with/without auth

FUNCTION: RequireUserType(userTypes ...models.UserType) func(http.Handler) http.Handler [line 120]
  - Authorization guard requiring specific user types
  - Checks authenticated user's type against allowed list
  - Returns 401 if not authenticated
  - Returns 403 if user type not allowed
  - Supports multiple allowed types (admin OR vendor)


================================================================================
FILE: middleware/auth_context.go
================================================================================
PURPOSE: Context utilities for authenticated user storage and retrieval.
LANGUAGE: Go
DEPENDENCIES: context

TYPE: ContextKey string [line 9]
  - Custom type to avoid context key collisions

CONST: UserContextKey ContextKey = "user" [line 13]
  - Key for storing user in request context

STRUCT: AuthenticatedUser [lines 17-21]
  Fields:
    - UserID int
    - Username string
    - UserType models.UserType

FUNCTION: SetUserInContext(ctx context.Context, user *AuthenticatedUser) context.Context [line 24]
  - Adds AuthenticatedUser to context
  - Returns new context with user value

FUNCTION: GetUserFromContext(ctx context.Context) (*AuthenticatedUser, bool) [line 29]
  - Retrieves AuthenticatedUser from context
  - Returns (user, true) if found, (nil, false) if not

FUNCTION: MustGetUserFromContext(ctx context.Context) *AuthenticatedUser [line 36]
  - Retrieves user from context with panic on failure
  - Should only be used after auth middleware
  - Panics with descriptive message if user not in context


================================================================================
FILE: sql/schema.sql
================================================================================
PURPOSE: Complete PostgreSQL database schema for delivery application.
LANGUAGE: SQL (PostgreSQL)
DEPENDENCIES: uuid-ossp extension

KEY ENUMS:
  - user_type: customer, vendor, admin, driver [lines 8-12]
  - user_status: active, inactive, suspended [lines 15-19]
  - order_status: pending, confirmed, preparing, ready, picked_up, in_transit, delivered, cancelled [lines 22-26]

TABLES:
  - users: Main authentication table [lines 29-39]
  - customers: Customer profiles [lines 79-87]
  - customer_addresses: Delivery addresses [lines 90-104]
  - vendors: Vendor/business profiles [lines 123-142]
  - restaurants: Restaurant entities [lines 150-168]
  - menus: Menu templates with JSONB config [lines 175-183]
  - restaurant_menus: Restaurant-menu junction [lines 189-198]
  - vendor_restaurants: Vendor-restaurant ownership [lines 205-211]
  - vendor_users: Multi-user vendor access [lines 250-260]
  - drivers: Driver profiles [lines 263-278]
  - admins: Admin profiles [lines 286-295]
  - dashboard_widgets: Dashboard widget definitions [lines 303-314]
  - user_role_widgets: Role-widget permissions [lines 317-326]

FUNCTIONS:
  - set_user_role(): Sets user_role to user_type if null [lines 51-59]
  - update_updated_at_column(): Auto-updates updated_at on row changes [lines 395-401]

TRIGGERS:
  - trigger_set_user_role: Auto-sets user_role on users insert/update [lines 62-66]
  - Multiple update_*_updated_at triggers for all tables [lines 404-454]

SEED DATA:
  - Test users (customer1, vendor1, driver1, admin1) with bcrypt hashes [lines 71-76]
  - Test profiles for each user type [lines 118-120, 145-147, 281-283, 298-300]
  - Test restaurants (Pizza Palace, Burger Haven) [lines 216-219]
  - Test menus with JSONB configurations [lines 222-229]
  - Restaurant-menu links [lines 232-239]
  - Vendor-restaurant ownership [lines 242-247]
  - Dashboard widgets for each role [lines 329-366]

INDEXES:
  - User indexes on email, username, user_type, user_role [lines 369-372]
  - Foreign key indexes on all profile tables [lines 373-378]
  - Address indexes [line 379]
  - Restaurant and menu indexes [lines 383-392]
  - Composite indexes for dashboard widgets [lines 380-382]

COMMENTS:
  - Table and column comments documenting business logic [lines 170-202, 213]


================================================================================
FILE: sql/drop_all.sql
================================================================================
PURPOSE: Database cleanup script for complete schema reset.
LANGUAGE: SQL (PostgreSQL)
DEPENDENCIES: None

DROP SEQUENCE (lines 6-18):
  - user_role_widgets, dashboard_widgets
  - restaurant_menus, vendor_restaurants, menus, restaurants
  - vendor_users, customer_addresses
  - admins, drivers, customers, vendors, users
  - Ordered to respect foreign key dependencies

DROP TYPES (lines 21-23):
  - order_status, user_status, user_type enums

DROP FUNCTIONS (lines 26-27):
  - update_updated_at_column(), set_user_role()

COMPLETION MESSAGE:
  - RAISE NOTICE with success confirmation [lines 33-36]

USAGE NOTE:
  - CAUTION: Deletes ALL data permanently
  - Typically used before running schema.sql for fresh setup
  - Optional extension cleanup commented out [line 30]
