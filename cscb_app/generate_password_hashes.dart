// Run this script to generate bcrypt password hashes for Supabase
// Usage: dart run generate_password_hashes.dart

import 'package:bcrypt/bcrypt.dart';

void main() {
  print('=== Password Hash Generator for CSCB App ===\n');
  
  // Super Admin credentials
  const superAdminEmail = 'ultraman';
  const superAdminPassword = 'hirayamanawari';
  final superAdminHash = BCrypt.hashpw(superAdminPassword, BCrypt.gensalt());
  
  // Regular user credentials
  const regularUserEmail = 'johndoe@gmail.com';
  const regularUserPassword = 'johndoe2026';
  final regularUserHash = BCrypt.hashpw(regularUserPassword, BCrypt.gensalt());
  
  print('Super Admin:');
  print('  Email: $superAdminEmail');
  print('  Password: $superAdminPassword');
  print('  Hash: $superAdminHash');
  print('');
  
  print('Regular User:');
  print('  Email: $regularUserEmail');
  print('  Password: $regularUserPassword');
  print('  Hash: $regularUserHash');
  print('');
  
  print('=== SQL Script ===\n');
  print('Copy and paste this into Supabase SQL Editor:\n');
  
  print('''
-- Seed Initial Users for CSCB App

-- Insert Super Admin User
INSERT INTO users (
    id,
    name,
    email,
    password_hash,
    role,
    is_synced,
    deleted,
    created_at,
    updated_at
) VALUES (
    'super-admin-001',
    'Super Admin',
    '$superAdminEmail',
    '$superAdminHash',
    'super_admin',
    true,
    false,
    NOW(),
    NOW()
) ON CONFLICT (email) DO NOTHING;

-- Insert Regular Test User
INSERT INTO users (
    id,
    name,
    email,
    password_hash,
    role,
    is_synced,
    deleted,
    created_at,
    updated_at
) VALUES (
    'user-test-001',
    'John Doe',
    '$regularUserEmail',
    '$regularUserHash',
    'member',
    true,
    false,
    NOW(),
    NOW()
) ON CONFLICT (email) DO NOTHING;

-- Verify users were created
SELECT id, name, email, role FROM users WHERE deleted = false;
''');
}
