#!/usr/bin/env python3
"""
Generate bcrypt password hashes for test users
Used to update the INSERT statements in schema.sql
"""

import bcrypt

def generate_hash(password):
    """Generate a bcrypt hash for a password"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

if __name__ == '__main__':
    password = 'password123'

    print("Generating bcrypt hashes for password: 'password123'")
    print("=" * 70)
    print()

    users = ['customer1', 'vendor1', 'driver1', 'admin1']

    for user in users:
        hash_value = generate_hash(password)
        print(f"-- {user}")
        print(f"'{hash_value}',")
        print()

    print("=" * 70)
    print("\nCopy these hashes to the INSERT statement in schema.sql")
    print("Note: Each hash is unique due to different salts")
