# My Billu Control 🎛️

Admin panel Android app for managing **My Billu** client subscriptions.

## Features
- 🔐 Master password protected admin access
- 📊 Dashboard with real-time stats (Active, Trial, Expired, Revoked)
- 🔍 Search & filter clients by email, name, device
- ✅ Activate subscriptions with expiry date
- ❌ Revoke access instantly
- 📅 Extend/change expiry dates
- 📱 Device migration (unbind old device for new registration)
- 📝 Admin notes per client
- 🗑️ Delete client records
- ⬇️ Pull-to-refresh

## Setup

### 1. Create GitHub repo
Create a repo called `My-Billu-Control` on GitHub, then:
```bash
git remote add origin https://github.com/gurubhat21/My-Billu-Control.git
git push -u origin main
```

### 2. Firebase Setup
The app uses the same Firebase project (`my-billu`) as the main app.

**IMPORTANT:** You need to register this app in Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com/project/my-billu)
2. Click "Add app" → Android
3. Package name: `com.mybillu.my_billu_control`
4. Download the new `google-services.json`
5. Replace `android/app/google-services.json` with the downloaded file

### 3. Build APK
```bash
flutter pub get
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Login
Master Password: `9449831316@guru`

## Tech Stack
- Flutter (Android only)
- Firebase Firestore (subscriptions collection)
- Google Fonts (Inter)
- Material 3 Dark Theme
