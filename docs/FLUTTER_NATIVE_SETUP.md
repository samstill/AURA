# Flutter Native Configuration Guide

After running `flutter create .` in the project root, apply these configurations:

## Android Setup

### File: `android/app/build.gradle`

In `defaultConfig` block, add:

```gradle
defaultConfig {
    applicationId "com.project.aura"
    minSdkVersion 21
    targetSdkVersion flutter.targetSdkVersion
    versionCode flutterVersionCode.toInteger()
    versionName flutterVersionName
    
    // OAuth2 redirect scheme for flutter_appauth
    manifestPlaceholders = [
        'appAuthRedirectScheme': 'com.project.aura'
    ]
}
```

---

## iOS Setup

### File: `ios/Runner/Info.plist`

Add inside the `<dict>` element:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.project.aura</string>
        </array>
    </dict>
</array>
```

---

## Authentik Configuration

Create a new OAuth2 Provider in Authentik:

| Setting | Value |
|---------|-------|
| Name | Aura Mobile App |
| Client ID | `aura-mobile-app` |
| Client Type | Public |
| Redirect URIs | `com.project.aura://login-callback` |
| Signing Key | authentik Self-signed Certificate |

Then create an Application linked to this provider with slug: `aura`

---

## Test Commands

```bash
# Initialize Flutter (if not done)
flutter create .

# Get dependencies
flutter pub get

# Run on Android emulator
flutter run

# Run on iOS simulator
flutter run -d ios
```
