# Quick Database Re-seed Guide

## When to Re-seed

Re-seed the database when:
- Testing requires fresh data
- Database schema has been updated
- Restaurant/menu data needs to be reset

## Quick Re-seed (One Command)

```bash
cd /Users/josephsadaka/Repos/delivery_app/tools/cli && \
source venv/bin/activate && \
export DATABASE_URL="postgres://delivery_user:delivery_pass@localhost:5433/delivery_app?sslmode=disable" && \
python cli.py migrate && \
python cli.py seed
```

## What Gets Created

### Users (6 total)
- `customer1` / password123 (Customer)
- `vendor1` / password123 (Vendor - owns China Garden, Pizza Paradise)
- `vendor2` / password123 (Vendor - owns Burger Haven)
- `vendor3` / password123 (Vendor - owns Sushi Express)
- `driver1` / password123 (Driver)
- `admin1` / password123 (Admin)

### Restaurants (4 total)

1. **China Garden** (vendor1)
   - Hours: 11:00 AM - 10:00 PM (Mon-Sun)
   - Menu: 7 items (Chinese cuisine)

2. **Pizza Paradise** (vendor1)
   - Hours: 11:00 AM - 11:00 PM (Mon-Thu), til Midnight (Fri-Sat), 12:00 PM - 10:00 PM (Sun)
   - Menu: 10 items (Italian - Pizzas, Pasta, Appetizers)

3. **Burger Haven** (vendor2)
   - Hours: 10:00 AM - 10:00 PM (Mon-Thu), til 11:00 PM (Fri-Sat), 10:00 AM - 9:00 PM (Sun)
   - Menu: 10 items (American - Burgers, Sides, Drinks)

4. **Sushi Express** (vendor3) - **24/7 TESTING RESTAURANT**
   - Hours: **Always Open (00:00 - 23:59 Every Day)**
   - Menu: 11 items (Japanese - Sushi Rolls, Sashimi, Hot Dishes)

### Total Menu Items: 38

## Test APIs

```bash
# Login as customer
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "customer1", "password": "password123"}'

# Get restaurants (will only show open restaurants for customers)
curl -X GET http://localhost:8080/api/restaurants \
  -H "Authorization: Bearer YOUR_TOKEN"

# Get menu for Sushi Express (ID: 4)
curl -X GET http://localhost:8080/api/restaurants/4/menu \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Important Notes

- **Sushi Express (24/7)** ensures at least 1 restaurant is always visible for testing
- Customers/Drivers only see **open** restaurants (filtered by hours)
- Admins see **all** restaurants regardless of hours
- Vendors see only **their own** restaurants
- All vendors are auto-approved during seeding
- All restaurants are active and approved

## Troubleshooting

**No restaurants visible?**
- Current time might be outside all restaurant hours (except Sushi Express)
- Login as admin to see all restaurants regardless of hours
- Check: `psql "postgres://delivery_user:delivery_pass@localhost:5433/delivery_app" -c "SELECT name, is_active, approval_status FROM restaurants;"`

**Menu not loading?**
- Verify restaurant has menu: `SELECT * FROM restaurant_menus WHERE restaurant_id = X;`
- Check menu_config is valid JSON: `SELECT menu_config FROM menus WHERE id = X;`

**Need to see closed restaurants as customer?**
- Frontend feature request: Add toggle to show closed restaurants (grayed out)
- Backend already has the data, just filters by hours
