-- Migration script to add dashboard and permissions tables
-- Run this if you already have existing tables and need to add the new ones

-- Step 1: Create officer_titles table if it doesn't exist
CREATE TABLE IF NOT EXISTS officer_titles (
    id TEXT PRIMARY KEY,
    org_id TEXT REFERENCES organizations(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Drop existing events table if it has wrong schema, then recreate
-- WARNING: This will delete existing event data. Comment out if you need to preserve data.
DROP TABLE IF EXISTS events CASCADE;

CREATE TABLE events (
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

-- Step 3: Create organization_permissions table if it doesn't exist
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

-- Step 4: Create member_permissions table if it doesn't exist
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

-- Step 5: Add officer_title_id column to memberships if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'memberships' AND column_name = 'officer_title_id'
    ) THEN
        ALTER TABLE memberships ADD COLUMN officer_title_id TEXT;
    END IF;
END $$;

-- Step 6: Add foreign key constraint for officer_title_id
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

-- Step 7: Create indexes
CREATE INDEX IF NOT EXISTS idx_events_org_id ON events(org_id);
CREATE INDEX IF NOT EXISTS idx_events_event_date ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_officer_titles_org_id ON officer_titles(org_id);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_org_id ON organization_permissions(org_id);
CREATE INDEX IF NOT EXISTS idx_member_permissions_membership_id ON member_permissions(membership_id);
CREATE INDEX IF NOT EXISTS idx_memberships_officer_title_id ON memberships(officer_title_id);

-- Step 8: Enable RLS on new tables
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE officer_titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_permissions ENABLE ROW LEVEL SECURITY;

-- Step 9: Create RLS policies for events
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'events' AND policyname = 'Events are viewable by everyone'
    ) THEN
        CREATE POLICY "Events are viewable by everyone" ON events FOR SELECT USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'events' AND policyname = 'Events can be created by anyone'
    ) THEN
        CREATE POLICY "Events can be created by anyone" ON events FOR INSERT WITH CHECK (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'events' AND policyname = 'Events can be updated by anyone'
    ) THEN
        CREATE POLICY "Events can be updated by anyone" ON events FOR UPDATE USING (true);
    END IF;
END $$;

-- Step 10: Create RLS policies for officer_titles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'officer_titles' AND policyname = 'Officer titles are viewable by everyone'
    ) THEN
        CREATE POLICY "Officer titles are viewable by everyone" ON officer_titles FOR SELECT USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'officer_titles' AND policyname = 'Officer titles can be created by anyone'
    ) THEN
        CREATE POLICY "Officer titles can be created by anyone" ON officer_titles FOR INSERT WITH CHECK (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'officer_titles' AND policyname = 'Officer titles can be updated by anyone'
    ) THEN
        CREATE POLICY "Officer titles can be updated by anyone" ON officer_titles FOR UPDATE USING (true);
    END IF;
END $$;

-- Step 11: Create RLS policies for organization_permissions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'organization_permissions' AND policyname = 'Organization permissions are viewable by everyone'
    ) THEN
        CREATE POLICY "Organization permissions are viewable by everyone" ON organization_permissions FOR SELECT USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'organization_permissions' AND policyname = 'Organization permissions can be created by anyone'
    ) THEN
        CREATE POLICY "Organization permissions can be created by anyone" ON organization_permissions FOR INSERT WITH CHECK (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'organization_permissions' AND policyname = 'Organization permissions can be updated by anyone'
    ) THEN
        CREATE POLICY "Organization permissions can be updated by anyone" ON organization_permissions FOR UPDATE USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'organization_permissions' AND policyname = 'Organization permissions can be deleted by anyone'
    ) THEN
        CREATE POLICY "Organization permissions can be deleted by anyone" ON organization_permissions FOR DELETE USING (true);
    END IF;
END $$;

-- Step 12: Create RLS policies for member_permissions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'member_permissions' AND policyname = 'Member permissions are viewable by everyone'
    ) THEN
        CREATE POLICY "Member permissions are viewable by everyone" ON member_permissions FOR SELECT USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'member_permissions' AND policyname = 'Member permissions can be created by anyone'
    ) THEN
        CREATE POLICY "Member permissions can be created by anyone" ON member_permissions FOR INSERT WITH CHECK (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'member_permissions' AND policyname = 'Member permissions can be updated by anyone'
    ) THEN
        CREATE POLICY "Member permissions can be updated by anyone" ON member_permissions FOR UPDATE USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'member_permissions' AND policyname = 'Member permissions can be deleted by anyone'
    ) THEN
        CREATE POLICY "Member permissions can be deleted by anyone" ON member_permissions FOR DELETE USING (true);
    END IF;
END $$;

-- Step 13: Create triggers for updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_events_updated_at'
    ) THEN
        CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_officer_titles_updated_at'
    ) THEN
        CREATE TRIGGER update_officer_titles_updated_at BEFORE UPDATE ON officer_titles
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_organization_permissions_updated_at'
    ) THEN
        CREATE TRIGGER update_organization_permissions_updated_at BEFORE UPDATE ON organization_permissions
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_member_permissions_updated_at'
    ) THEN
        CREATE TRIGGER update_member_permissions_updated_at BEFORE UPDATE ON member_permissions
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;
