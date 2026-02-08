# Google OAuth Setup Guide

## Overview
This guide will help you set up Google OAuth authentication for your CSCB app using Supabase Auth.

## Prerequisites
- Supabase project set up
- Google Cloud Console account

## Step 1: Configure Google Cloud Console

### 1.1 Create OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Go to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Configure consent screen if prompted:
   - User Type: External
   - App name: CSCB App
   - User support email: your email
   - Developer contact: your email
6. Application type: **Web application**
7. Name: CSCB App
8. Authorized redirect URIs:
   ```
   https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback
   ```
   Replace `YOUR_SUPABASE_PROJECT_REF` with your actual Supabase project reference
   (found in your Supabase project URL)

9. Click **Create**
10. Copy the **Client ID** and **Client Secret**

### 1.2 Enable Google Sign-In API

1. In Google Cloud Console, go to **APIs & Services** → **Library**
2. Search for "Google+ API" or "Google Sign-In API"
3. Click **Enable**

## Step 2: Configure Supabase

### 2.1 Enable Google Provider

1. Go to your Supabase Dashboard
2. Navigate to **Authentication** → **Providers**
3. Find **Google** in the list
4. Toggle it to **Enabled**
5. Paste your **Client ID** from Google Cloud Console
6. Paste your **Client Secret** from Google Cloud Console
7. Click **Save**

### 2.2 Configure Redirect URLs

1. In Supabase Dashboard, go to **Authentication** → **URL Configuration**
2. Add your app's redirect URLs:
   - For development: `http://localhost:3000/auth/callback`
   - For production: `https://your-app-domain.com/auth/callback`
3. For mobile deep linking, add:
   ```
   com.cscb.cscb_app://login-callback
   ```

## Step 3: Update Flutter App

The code has been updated to support Google OAuth. Here's what was added:

### 3.1 Dependencies
- `google_sign_in` package for Google authentication
- Supabase Auth integration

### 3.2 Features Added
- Google Sign-In button on login page
- Automatic user creation in database after Google sign-in
- Profile picture support from Google account
- Email verification from Google

## Step 4: Configure Android

### 4.1 Update AndroidManifest.xml

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    android:exported="true">
    <intent-filter android:label="flutter_web_auth_2">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.cscb.cscb_app" />
    </intent-filter>
</activity>
```

### 4.2 Add SHA-1 Fingerprint

1. Get your SHA-1 fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```

2. Copy the SHA-1 fingerprint for debug/release

3. Go to Google Cloud Console → Credentials
4. Edit your OAuth client ID
5. Add the SHA-1 fingerprint

## Step 5: Configure iOS

### 5.1 Update Info.plist

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.cscb.cscb_app</string>
        </array>
    </dict>
</array>
```

### 5.2 Add Google Sign-In URL Scheme

Add your reversed client ID:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_CLIENT_ID` with your Google Client ID (reversed).

## Step 6: Test Google OAuth

1. Run the app: `flutter run`
2. Click "Sign in with Google" button
3. Select your Google account
4. Grant permissions
5. You should be logged in and redirected to the main page

## Troubleshooting

### Error: "redirect_uri_mismatch"
- Check that your redirect URI in Google Cloud Console matches exactly
- Format: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`

### Error: "invalid_client"
- Verify Client ID and Client Secret in Supabase
- Make sure Google Sign-In API is enabled

### Error: "access_denied"
- Check OAuth consent screen configuration
- Make sure your email is added as a test user (if in testing mode)

### App doesn't redirect back
- Verify deep link configuration in AndroidManifest.xml / Info.plist
- Check URL scheme matches: `com.cscb.cscb_app`

## Security Notes

1. **Never commit credentials**: Keep Client ID and Secret secure
2. **Use environment variables**: Store sensitive data in `.env` files
3. **Restrict OAuth scopes**: Only request necessary permissions
4. **Validate tokens**: Always verify tokens on the backend

## User Flow

1. User clicks "Sign in with Google"
2. Redirected to Google sign-in page
3. User selects account and grants permissions
4. Google redirects back to app with auth code
5. Supabase exchanges code for tokens
6. User profile is created/updated in database
7. User is logged in and redirected to main page

## Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Google OAuth Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Flutter Google Sign-In](https://pub.dev/packages/google_sign_in)
