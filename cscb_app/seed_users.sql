-- Seed Initial Users for CSCB App
-- Run this script in Supabase SQL Editor AFTER running supabase_schema.sql

-- Note: These password hashes are generated using bcrypt
-- Super Admin: ultraman / hirayamanawari
-- Regular User: johndoe@gmail.com / johndoe2026

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
    'ultraman',
    '$2a$10$lmw6S86wCaJIbShwZNRyQ.XzDNvBZcojodHfM97mBC3IuG23Ab8wa',
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
    'johndoe@gmail.com',
    '$2a$10$UUS2TcfNpyKRCrsvstVc7.Z0o1.TVRN1/gb3ihU02XY0j28LFgCF6',
    'member',
    true,
    false,
    NOW(),
    NOW()
) ON CONFLICT (email) DO NOTHING;

-- Verify users were created
SELECT id, name, email, role FROM users WHERE deleted = false;
