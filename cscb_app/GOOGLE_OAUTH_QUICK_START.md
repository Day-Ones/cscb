# Google OAuth Quick Start

## ✅ What's Been Added

- Google Sign-In button on login page
- Google Auth service using Supabase Auth
- Deep link configuration for Android
- Automatic user creation after Google sign-in

## 🚀 Setup Steps (5 minutes)

### 1. Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create/select project
3. Go to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Configure consent screen (if needed)
6. Application type: **Web application**
7. Add Authorized redirect URI:
   ```
   https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback
   ```
8. Copy **Client ID** and **Client Secret**

### 2. Supabase Configuration

1. Go to Supabase Dashboard → **Authentication** → **Providers**
2. Enable **Google**
3. Paste Client ID and Client Secret
4. Click **Save**

### 3. Get SHA-1 Fingerprint (Android)

```bash
cd android
./gradlew signingReport
```

Copy the SHA-1 fingerprint and add it to your Google Cloud Console OAuth client.

### 4. Test It!

```bash
flutter run
```

Click "Sign in with Google" button!

## 📱 How It Works

1. User clicks "Sign in with Google"
2. Opens Google sign-in page in browser
3. User selects account and grants permissions
4. Redirects back to app via deep link
5. Supabase handles authentication
6. User is logged in and redirected to main page

## 🔧 Configuration Files Updated

- ✅ `pubspec.yaml` - Added google_sign_in package
- ✅ `lib/screens/login_page.dart` - Added Google Sign-In button
- ✅ `lib/data/remote/services/google_auth_service.dart` - New service
- ✅ `android/app/src/main/AndroidManifest.xml` - Deep link config

## 🎯 Features

- ✅ One-tap Google Sign-In
- ✅ Automatic user profile creation
- ✅ Email verification from Google
- ✅ Profile picture support
- ✅ Secure OAuth 2.0 flow
- ✅ Works with existing email/password login

## 📝 Notes

- Google users are created as regular users (role: "member")
- Super admin login still uses email/password
- Users can use either Google OR email/password (not both for same account)
- First-time Google users are automatically registered

## 🔐 Security

- OAuth tokens handled by Supabase
- No passwords stored for Google users
- Secure deep link redirect
- HTTPS only in production

## 📚 Full Documentation

See `GOOGLE_OAUTH_SETUP.md` for complete setup guide including:
- iOS configuration
- Troubleshooting
- Security best practices
- Advanced configuration

## ⚠️ Important

Make sure to:
1. Add your SHA-1 fingerprint to Google Cloud Console
2. Configure redirect URI in Supabase exactly as shown
3. Enable Google provider in Supabase Auth
4. Test on a real device (emulator may have issues with Google Sign-In)
