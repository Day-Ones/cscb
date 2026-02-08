-- Migration: Add User Profiles Table
-- Run this script in your Supabase SQL Editor to add the user_profiles table

-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    program TEXT NOT NULL,
    year_level TEXT NOT NULL,
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_deleted ON user_profiles(deleted);

-- Enable Row Level Security (RLS)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for User Profiles
CREATE POLICY "User profiles are viewable by everyone" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "User profiles can be created by anyone" ON user_profiles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "User profiles can be updated by anyone" ON user_profiles
    FOR UPDATE USING (true);

-- Trigger to automatically update updated_at
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
