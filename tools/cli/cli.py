#!/usr/bin/env python3
"""
Database Migration CLI for Delivery App
Connects to PostgreSQL and manages database schema migrations
"""

import os
import sys
import argparse
import psycopg2
from psycopg2 import sql
from datetime import datetime
import bcrypt


class DatabaseCLI:
    def __init__(self, db_url=None):
        """Initialize database connection"""
        self.db_url = db_url or os.getenv('DATABASE_URL')
        if not self.db_url:
            raise ValueError("DATABASE_URL environment variable is required")
        self.conn = None
        self.cursor = None

    def connect(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(self.db_url)
            self.cursor = self.conn.cursor()
            print("✓ Connected to database successfully")
            return True
        except Exception as e:
            print(f"✗ Database connection failed: {e}")
            return False

    def disconnect(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        print("✓ Database connection closed")

    def execute_sql_file(self, filepath):
        """Execute SQL from a file"""
        try:
            with open(filepath, 'r') as f:
                sql_content = f.read()

            self.cursor.execute(sql_content)
            self.conn.commit()
            print(f"✓ Successfully executed SQL file: {filepath}")
            return True
        except Exception as e:
            self.conn.rollback()
            print(f"✗ Error executing SQL file: {e}")
            return False

    def migrate(self, schema_path='backend/sql/schema.sql'):
        """Run database migrations"""
        print("\n=== Running Database Migrations ===")

        # Convert to absolute path if relative
        if not os.path.isabs(schema_path):
            # Get the project root (two levels up from tools/cli)
            script_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(script_dir))
            schema_path = os.path.join(project_root, schema_path)

        if not os.path.exists(schema_path):
            print(f"✗ Schema file not found: {schema_path}")
            return False

        # Get drop_all.sql path (same directory as schema)
        schema_dir = os.path.dirname(schema_path)
        drop_all_path = os.path.join(schema_dir, 'drop_all.sql')

        if not self.connect():
            return False

        try:
            # Execute drop_all.sql first if it exists
            if os.path.exists(drop_all_path):
                print("\nStep 1: Dropping all existing tables and objects...")
                drop_success = self.execute_sql_file(drop_all_path)
                if not drop_success:
                    print("\n✗ Failed to drop existing tables")
                    return False
            else:
                print(f"\nℹ Drop script not found at {drop_all_path}, skipping drop step")

            # Execute schema
            print("\nStep 2: Creating tables and objects from schema...")
            success = self.execute_sql_file(schema_path)

            if success:
                print("\n✓ Migration completed successfully")
            else:
                print("\n✗ Migration failed")

            return success
        finally:
            self.disconnect()

    def reset(self):
        """Drop all tables and reset database"""
        print("\n=== Resetting Database ===")

        if not self.connect():
            return False

        try:
            # Get all tables
            self.cursor.execute("""
                SELECT tablename FROM pg_tables
                WHERE schemaname = 'public'
            """)
            tables = self.cursor.fetchall()

            if not tables:
                print("No tables to drop")
                return True

            # Drop all tables
            print(f"Dropping {len(tables)} tables...")
            for table in tables:
                self.cursor.execute(sql.SQL("DROP TABLE IF EXISTS {} CASCADE").format(
                    sql.Identifier(table[0])
                ))
                print(f"  ✓ Dropped table: {table[0]}")

            # Drop custom types
            self.cursor.execute("""
                SELECT typname FROM pg_type
                WHERE typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
                AND typtype = 'e'
            """)
            types = self.cursor.fetchall()

            for type_name in types:
                self.cursor.execute(sql.SQL("DROP TYPE IF EXISTS {} CASCADE").format(
                    sql.Identifier(type_name[0])
                ))
                print(f"  ✓ Dropped type: {type_name[0]}")

            self.conn.commit()
            print("\n✓ Database reset successfully")
            return True
        except Exception as e:
            self.conn.rollback()
            print(f"✗ Error resetting database: {e}")
            return False
        finally:
            self.disconnect()

    def status(self):
        """Check database status and list tables"""
        print("\n=== Database Status ===")

        if not self.connect():
            return False

        try:
            # Get database info
            self.cursor.execute("SELECT version()")
            version = self.cursor.fetchone()[0]
            print(f"\nPostgreSQL Version:\n  {version}")

            # List all tables
            self.cursor.execute("""
                SELECT tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
                FROM pg_tables
                WHERE schemaname = 'public'
                ORDER BY tablename
            """)
            tables = self.cursor.fetchall()

            if tables:
                print(f"\nTables ({len(tables)}):")
                for table, size in tables:
                    # Get row count
                    self.cursor.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(
                        sql.Identifier(table)
                    ))
                    count = self.cursor.fetchone()[0]
                    print(f"  • {table:30} {count:6} rows  {size}")
            else:
                print("\nNo tables found")

            # List custom types
            self.cursor.execute("""
                SELECT typname FROM pg_type
                WHERE typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
                AND typtype = 'e'
            """)
            types = self.cursor.fetchall()

            if types:
                print(f"\nCustom Types ({len(types)}):")
                for type_name in types:
                    print(f"  • {type_name[0]}")

            return True
        except Exception as e:
            print(f"✗ Error checking database status: {e}")
            return False
        finally:
            self.disconnect()

    def seed(self):
        """Seed database with sample data"""
        print("\n=== Seeding Database ===")

        if not self.connect():
            return False

        try:
            # Sample users
            sample_users = [
                ('customer1', 'customer1@example.com', 'password123', 'customer'),
                ('vendor1', 'vendor1@example.com', 'password123', 'vendor'),
                ('driver1', 'driver1@example.com', 'password123', 'driver'),
                ('admin1', 'admin1@example.com', 'password123', 'admin'),
            ]

            print("\nCreating sample users...")
            for username, email, password, user_type in sample_users:
                # Hash the password using bcrypt (same as Go backend)
                password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

                self.cursor.execute("""
                    INSERT INTO users (username, email, password_hash, user_type)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (username) DO NOTHING
                    RETURNING id
                """, (username, email, password_hash, user_type))

                result = self.cursor.fetchone()
                if result:
                    user_id = result[0]
                    print(f"  ✓ Created user: {username} ({user_type})")

                    # Create corresponding profile table entry
                    if user_type == 'customer':
                        self.cursor.execute("""
                            INSERT INTO customers (user_id, full_name, phone)
                            VALUES (%s, %s, %s)
                        """, (user_id, f"Customer {username}", "+1234567890"))

                    elif user_type == 'vendor':
                        self.cursor.execute("""
                            INSERT INTO vendors (user_id, business_name, phone, city)
                            VALUES (%s, %s, %s, %s)
                        """, (user_id, f"Business {username}", "+1234567890", "New York"))

                    elif user_type == 'driver':
                        self.cursor.execute("""
                            INSERT INTO drivers (user_id, full_name, phone, vehicle_type)
                            VALUES (%s, %s, %s, %s)
                        """, (user_id, f"Driver {username}", "+1234567890", "Car"))

                    elif user_type == 'admin':
                        self.cursor.execute("""
                            INSERT INTO admins (user_id, full_name, role)
                            VALUES (%s, %s, %s)
                        """, (user_id, f"Admin {username}", "System Administrator"))

            self.conn.commit()
            print("\n✓ Database seeded successfully")
            print("\nSample credentials:")
            print("  Username: customer1, Password: password123 (Customer)")
            print("  Username: vendor1,   Password: password123 (Vendor)")
            print("  Username: driver1,   Password: password123 (Driver)")
            print("  Username: admin1,    Password: password123 (Admin)")
            return True
        except Exception as e:
            self.conn.rollback()
            print(f"✗ Error seeding database: {e}")
            return False
        finally:
            self.disconnect()

    def cleanup_orphaned_menus(self, dry_run=True):
        """Clean up orphaned menus that have no restaurant associations"""
        print("\n=== Cleaning Up Orphaned Menus ===")

        if not self.connect():
            return False

        try:
            # First, identify orphaned menus
            self.cursor.execute("""
                SELECT
                    m.id,
                    m.name,
                    m.vendor_id,
                    v.business_name AS vendor_name,
                    m.created_at
                FROM menus m
                LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
                LEFT JOIN vendors v ON m.vendor_id = v.id
                WHERE rm.menu_id IS NULL
                ORDER BY m.created_at DESC
            """)
            orphaned_menus = self.cursor.fetchall()

            if not orphaned_menus:
                print("\n✓ No orphaned menus found. Database is clean!")
                return True

            print(f"\nFound {len(orphaned_menus)} orphaned menu(s):")
            print("-" * 80)
            for menu_id, name, vendor_id, vendor_name, created_at in orphaned_menus:
                vendor_display = vendor_name if vendor_name else "NO VENDOR (System Menu)"
                print(f"  • ID: {menu_id:3} | {name:30} | {vendor_display:25} | Created: {created_at}")
            print("-" * 80)

            if dry_run:
                print("\n⚠ DRY RUN MODE: No changes will be made")
                print("  To actually delete orphaned menus, run with --execute flag:")
                print("  python cli.py cleanup-orphaned-menus --execute")
                return True

            # If not dry run, ask for confirmation
            print("\n⚠ WARNING: This will permanently delete the above menus!")
            response = input("Are you sure you want to continue? (yes/no): ")

            if response.lower() != 'yes':
                print("\n✗ Cleanup cancelled by user")
                return False

            # Execute deletion
            self.cursor.execute("""
                DELETE FROM menus
                WHERE id IN (
                    SELECT m.id
                    FROM menus m
                    LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
                    WHERE rm.menu_id IS NULL
                )
            """)

            deleted_count = self.cursor.rowcount
            self.conn.commit()

            print(f"\n✓ Successfully deleted {deleted_count} orphaned menu(s)")

            # Verify cleanup
            self.cursor.execute("""
                SELECT COUNT(*)
                FROM menus m
                LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
                WHERE rm.menu_id IS NULL
            """)
            remaining = self.cursor.fetchone()[0]

            if remaining == 0:
                print("✓ All orphaned menus have been removed")
            else:
                print(f"⚠ Warning: {remaining} orphaned menu(s) still exist")

            # Show final statistics
            self.cursor.execute("""
                SELECT
                    (SELECT COUNT(*) FROM menus) AS total_menus,
                    (SELECT COUNT(*) FROM restaurant_menus) AS total_assignments,
                    (SELECT COUNT(DISTINCT menu_id) FROM restaurant_menus) AS menus_with_restaurants
            """)
            stats = self.cursor.fetchone()
            print(f"\nFinal Statistics:")
            print(f"  Total menus:             {stats[0]}")
            print(f"  Menus with restaurants:  {stats[2]}")
            print(f"  Menu assignments:        {stats[1]}")

            return True
        except Exception as e:
            self.conn.rollback()
            print(f"✗ Error cleaning up orphaned menus: {e}")
            return False
        finally:
            self.disconnect()


def main():
    parser = argparse.ArgumentParser(description='Database Migration CLI for Delivery App')
    parser.add_argument('command', choices=['migrate', 'reset', 'status', 'seed', 'cleanup-orphaned-menus'],
                        help='Command to execute')
    parser.add_argument('--db-url', help='Database URL (or set DATABASE_URL env var)')
    parser.add_argument('--schema', default='backend/sql/schema.sql',
                        help='Path to schema file (default: backend/sql/schema.sql)')
    parser.add_argument('--execute', action='store_true',
                        help='Execute cleanup (default is dry-run mode)')

    args = parser.parse_args()

    try:
        cli = DatabaseCLI(db_url=args.db_url)

        if args.command == 'migrate':
            success = cli.migrate(schema_path=args.schema)
        elif args.command == 'reset':
            success = cli.reset()
        elif args.command == 'status':
            success = cli.status()
        elif args.command == 'seed':
            success = cli.seed()
        elif args.command == 'cleanup-orphaned-menus':
            success = cli.cleanup_orphaned_menus(dry_run=not args.execute)
        else:
            print(f"Unknown command: {args.command}")
            success = False

        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"✗ Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
