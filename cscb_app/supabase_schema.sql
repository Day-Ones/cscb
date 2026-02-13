-- CSCB App Database Schema for Supabase
-- Run this script in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('super_admin', 'president', 'member')),
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organizations Table
CREATE TABLE IF NOT EXISTS organizations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended')),
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Memberships Table
CREATE TABLE IF NOT EXISTS memberships (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Events Table
CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    location TEXT NOT NULL,
    max_attendees INTEGER,
    created_by TEXT REFERENCES users(id),
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Officer Titles Table
CREATE TABLE IF NOT EXISTS officer_titles (
    id TEXT PRIMARY KEY,
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organization Permissions Table
CREATE TABLE IF NOT EXISTS organization_permissions (
    id TEXT PRIMARY KEY,
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    permission_key TEXT NOT NULL,
    enabled_for_officers BOOLEAN DEFAULT FALSE,
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Member Permissions Table
CREATE TABLE IF NOT EXISTS member_permissions (
    id TEXT PRIMARY KEY,
    membership_id TEXT REFERENCES memberships(id) ON DELETE CASCADE,
    permission_key TEXT NOT NULL,
    is_granted BOOLEAN NOT NULL,
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add officer_title_id column to memberships table (after officer_titles exists)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'memberships' AND column_name = 'officer_title_id'
    ) THEN
        ALTER TABLE memberships ADD COLUMN officer_title_id TEXT;
    END IF;
END $$;

-- Add foreign key constraint for officer_title_id in memberships
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_memberships_officer_title'
    ) THEN
        ALTER TABLE memberships 
        ADD CONSTRAINT fk_memberships_officer_title 
        FOREIGN KEY (officer_title_id) 
        REFERENCES officer_titles(id) 
        ON DELETE SET NULL;
    END IF;
END $$;

-- Attendance Table
CREATE TABLE IF NOT EXISTS attendance (
    id TEXT PRIMARY KEY,
    event_id TEXT REFERENCES events(id) ON DELETE CASCADE,
    student_number TEXT NOT NULL,
    last_name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    program TEXT NOT NULL,
    year_level INTEGER NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'present' CHECK (status IN ('present', 'absent', 'late')),
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, student_number)
);

-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    google_id TEXT UNIQUE,
    student_number TEXT,
    first_name TEXT,
    last_name TEXT,
    full_name TEXT,
    program TEXT,
    year_level INTEGER,
    section TEXT,
    is_complete BOOLEAN DEFAULT FALSE,
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_deleted ON users(deleted);
CREATE INDEX IF NOT EXISTS idx_organizations_status ON organizations(status);
CREATE INDEX IF NOT EXISTS idx_organizations_deleted ON organizations(deleted);
CREATE INDEX IF NOT EXISTS idx_memberships_user_id ON memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_org_id ON memberships(org_id);
CREATE INDEX IF NOT EXISTS idx_memberships_officer_title_id ON memberships(officer_title_id);
CREATE INDEX IF NOT EXISTS idx_events_org_id ON events(org_id);
CREATE INDEX IF NOT EXISTS idx_events_event_date ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_officer_titles_org_id ON officer_titles(org_id);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_org_id ON organization_permissions(org_id);
CREATE INDEX IF NOT EXISTS idx_member_permissions_membership_id ON member_permissions(membership_id);
CREATE INDEX IF NOT EXISTS idx_attendance_event_id ON attendance(event_id);
CREATE INDEX IF NOT EXISTS idx_attendance_user_id ON attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_deleted ON user_profiles(deleted);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE officer_titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Users
CREATE POLICY "Users are viewable by everyone" ON users
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own data" ON users
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their own data" ON users
    FOR UPDATE USING (true);

-- RLS Policies for Organizations
CREATE POLICY "Organizations are viewable by everyone" ON organizations
    FOR SELECT USING (true);

CREATE POLICY "Organizations can be created by anyone" ON organizations
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Organizations can be updated by anyone" ON organizations
    FOR UPDATE USING (true);

-- RLS Policies for Memberships
CREATE POLICY "Memberships are viewable by everyone" ON memberships
    FOR SELECT USING (true);

CREATE POLICY "Memberships can be created by anyone" ON memberships
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Memberships can be updated by anyone" ON memberships
    FOR UPDATE USING (true);

-- RLS Policies for Events
CREATE POLICY "Events are viewable by everyone" ON events
    FOR SELECT USING (true);

CREATE POLICY "Events can be created by anyone" ON events
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Events can be updated by anyone" ON events
    FOR UPDATE USING (true);

-- RLS Policies for Attendance
CREATE POLICY "Attendance is viewable by everyone" ON attendance
    FOR SELECT USING (true);

CREATE POLICY "Attendance can be created by anyone" ON attendance
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Attendance can be updated by anyone" ON attendance
    FOR UPDATE USING (true);

-- RLS Policies for User Profiles
CREATE POLICY "User profiles are viewable by everyone" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "User profiles can be created by anyone" ON user_profiles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "User profiles can be updated by anyone" ON user_profiles
    FOR UPDATE USING (true);

-- RLS Policies for Officer Titles
CREATE POLICY "Officer titles are viewable by everyone" ON officer_titles
    FOR SELECT USING (true);

CREATE POLICY "Officer titles can be created by anyone" ON officer_titles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Officer titles can be updated by anyone" ON officer_titles
    FOR UPDATE USING (true);

-- RLS Policies for Organization Permissions
CREATE POLICY "Organization permissions are viewable by everyone" ON organization_permissions
    FOR SELECT USING (true);

CREATE POLICY "Organization permissions can be created by anyone" ON organization_permissions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Organization permissions can be updated by anyone" ON organization_permissions
    FOR UPDATE USING (true);

CREATE POLICY "Organization permissions can be deleted by anyone" ON organization_permissions
    FOR DELETE USING (true);

-- RLS Policies for Member Permissions
CREATE POLICY "Member permissions are viewable by everyone" ON member_permissions
    FOR SELECT USING (true);

CREATE POLICY "Member permissions can be created by anyone" ON member_permissions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Member permissions can be updated by anyone" ON member_permissions
    FOR UPDATE USING (true);

CREATE POLICY "Member permissions can be deleted by anyone" ON member_permissions
    FOR DELETE USING (true);
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to automatically update updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_memberships_updated_at BEFORE UPDATE ON memberships
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_officer_titles_updated_at BEFORE UPDATE ON officer_titles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_permissions_updated_at BEFORE UPDATE ON organization_permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_member_permissions_updated_at BEFORE UPDATE ON member_permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_updated_at BEFORE UPDATE ON attendance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
