# Quick Start: Connect to Supabase

## 🚀 4-Step Setup

### 1. Get Supabase Credentials (2 minutes)

1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL**
   - **anon public key**

### 2. Update Config File (30 seconds)

Open `lib/core/config/supabase_config.dart` and replace:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

With your actual values:

```dart
static const String supabaseUrl = 'https://xxxxx.supabase.co';
static const String supabaseAnonKey = 'eyJhbGci...';
```

### 3. Create Database Tables (30 seconds)

1. In Supabase dashboard, go to **SQL Editor**
2. Click **New Query**
3. Copy all content from `supabase_schema.sql`
4. Paste and click **Run**

### 4. Seed Initial Users (30 seconds)

1. In Supabase SQL Editor, click **New Query**
2. Copy all content from `seed_users.sql`
3. Paste and click **Run**

This creates:
- Super Admin: `ultraman` / `hirayamanawari`
- Regular User: `johndoe@gmail.com` / `johndoe2026`

### 5. Run the App

```bash
flutter run
```

## ✅ That's It!

Your app is now connected to Supabase!

- Users are stored in Supabase database
- Login fetches from Supabase first, then caches locally
- All tables created automatically

## 📚 Next Steps

- Read `SUPABASE_SETUP.md` for detailed documentation
- Implement sync logic using remote repositories
- Customize RLS policies for security

## 🔑 Test Accounts (Now in Supabase!)

**Super Admin:**
- Email: `ultraman`
- Password: `hirayamanawari`
- View: Admin Approval Page

**Regular User:**
- Email: `johndoe@gmail.com`
- Password: `johndoe2026`
- View: Main Page

## 🔄 How It Works

1. Login attempts fetch user from Supabase
2. User data is cached locally for offline access
3. Password verification happens locally using bcrypt
4. Role-based navigation to appropriate pages
