# Authentik Setup Guide

Complete guide for setting up local Authentik IDP with Project Aura.

---

## Prerequisites

- Minikube running with sufficient memory (3.5GB+)
- kubectl configured
- Aura backend deployed via Skaffold

---

## Part 1: Deploy Authentik

### Deploy to Kubernetes

```bash
# Apply all Authentik resources
kubectl apply -f k8s/auth/namespace.yaml
kubectl apply -f k8s/auth/secrets.yaml
kubectl apply -f k8s/auth/postgres.yaml
kubectl apply -f k8s/auth/redis.yaml
kubectl apply -f k8s/auth/authentik.yaml

# Or use the script
./scripts/deploy-authentik.sh
```

### Access Authentik

Authentik is exposed via NodePort at **http://localhost:30080**

No `kubectl port-forward` needed! The NodePort service handles this.

> **Note**: Authentik takes 2-3 minutes to fully start on first boot (database migrations).

### Verify Pods Are Running

```bash
kubectl get pods -n aura-auth
# Expected: All pods showing 1/1 Running
```

---

## Part 2: Initial Setup

### Access Setup Wizard

Open: **http://localhost:30080/if/flow/initial-setup/**

### Create Admin Account

| Field | Value |
|-------|-------|
| Email | your-email@example.com |
| Password | (choose a secure password) |

Click **Create Account**.

---

## Part 3: Create OAuth2 Provider

### Navigate to Providers

1. Click **Admin Interface** (gear icon in sidebar)
2. Go to **Applications** → **Providers**
3. Click **Create**

### Configure Provider

| Field | Value |
|-------|-------|
| **Name** | `Aura Backend` |
| **Authorization flow** | `default-provider-authorization-explicit-consent` |
| **Client type** | `Confidential` |
| **Redirect URIs** | `http://localhost:30000/api/v1/auth/callback` |

### Copy Credentials

After saving, copy these values (you'll need them):
- **Client ID**: e.g., `MHOzcOZ8ofKSPtuFdP4tylCVYS5eBoOHZmXhZZIm`
- **Client Secret**: e.g., `9cx9PL5PYi2DwLm...` (long string)

---

## Part 4: Create Application

### Navigate to Applications

1. Go to **Applications** → **Applications**
2. Click **Create**

### Configure Application

| Field | Value |
|-------|-------|
| **Name** | `Project Aura` |
| **Slug** | `aura` ← **Critical! Must be exactly "aura"** |
| **Provider** | Select `Aura Backend` provider |

Click **Create**.

---

## Part 5: Update Backend Secrets

### Delete Old Secret

```bash
kubectl delete secret aura-secrets --ignore-not-found
```

### Create New Secret

```bash
kubectl create secret generic aura-secrets \
  --from-literal=AUTHENTIK_CLIENT_ID="YOUR_CLIENT_ID" \
  --from-literal=AUTHENTIK_CLIENT_SECRET="YOUR_CLIENT_SECRET" \
  --from-literal=AUTHENTIK_URL="http://localhost:30080"
```

> **Replace** `YOUR_CLIENT_ID` and `YOUR_CLIENT_SECRET` with values from Part 3.

### Restart Backend

```bash
kubectl rollout restart deployment/aura-backend
```

---

## Part 6: Verify Integration

### Test Login Flow

1. Open: **http://localhost:30000/api/v1/auth/login**
2. Should redirect to Authentik login page
3. Login with admin credentials
4. Click "Approve" on consent screen
5. Should redirect back to callback URL

### Check Auth Status

```bash
curl http://localhost:30000/api/v1/auth/status
# Expected: {"authenticated": true, "user": {...}}
```

---

## Troubleshooting

### Authentik Not Starting

```bash
# Check pod status
kubectl get pods -n aura-auth

# Check logs
kubectl logs -n aura-auth -l app.kubernetes.io/name=authentik-server --tail=50

# If crash-looping, may need more time or memory
kubectl describe pod -n aura-auth -l app.kubernetes.io/name=authentik-server
```

### "client_id is empty" Error

Backend didn't pick up secrets. Restart it:
```bash
kubectl rollout restart deployment/aura-backend
```

### "invalid_redirect_uri" Error

Redirect URI in Authentik doesn't match. Must be exactly:
```
http://localhost:30000/api/v1/auth/callback
```

### Services Not Accessible

Check if services are running:
```bash
# Check Authentik pods
kubectl get pods -n aura-auth

# Check aura-backend (should be running via skaffold dev)
kubectl get pods -n default
```

Authentik uses NodePort 30080, aura-backend uses Skaffold port-forward to 30000.

---

## Clean Restart (Nuclear Option)

If everything is broken, delete and recreate:

```bash
# Delete Authentik completely
kubectl delete namespace aura-auth

# Wait for deletion
kubectl get ns aura-auth  # Should say "not found"

# Redeploy
kubectl apply -f k8s/auth/namespace.yaml
kubectl apply -f k8s/auth/secrets.yaml
kubectl apply -f k8s/auth/postgres.yaml
kubectl apply -f k8s/auth/redis.yaml
kubectl apply -f k8s/auth/

# Wait 3 minutes for Authentik to start
kubectl get pods -n aura-auth
```

> **Warning**: This deletes all Authentik data. You'll need to redo initial setup.

---

## Quick Reference

| Resource | URL |
|----------|-----|
| Authentik UI | http://localhost:30080 |
| Authentik Admin | http://localhost:30080/if/admin/ |
| Initial Setup | http://localhost:30080/if/flow/initial-setup/ |
| Aura Login | http://localhost:30000/api/v1/auth/login |
| Aura Swagger | http://localhost:30000/docs |

---

# Flutter Application Setup

Complete guide for setting up the Flutter mobile app with Authentik OAuth2.

---

## Part 7: Flutter Prerequisites

### Required Tools

- Flutter SDK 3.0+
- Android Studio or Xcode
- An Android emulator or iOS simulator

### Directory Structure

Flutter code is in the `flutter/` directory:
```
flutter/
├── lib/
│   ├── core/
│   │   └── auth_config.dart      # OAuth configuration
│   ├── services/
│   │   ├── auth_service.dart     # PKCE auth flow
│   │   └── api_client.dart       # Dio HTTP client
│   └── ui/
│       └── login_screen.dart     # Login UI
├── android/                       # Android native
├── ios/                           # iOS native
└── pubspec.yaml                   # Dependencies
```

---

## Part 8: Configure Flutter Dependencies

### Install Packages

```bash
cd flutter
flutter pub get
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_appauth` | OAuth2/OIDC with PKCE |
| `flutter_secure_storage` | Encrypted token storage |
| `dio` | HTTP client with interceptors |

---

## Part 9: Android Configuration

### Edit build.gradle

File: `flutter/android/app/build.gradle`

Find the `defaultConfig` block and add `manifestPlaceholders`:

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

> **Critical**: The scheme `com.project.aura` must match exactly.

---

## Part 10: iOS Configuration

### Edit Info.plist

File: `flutter/ios/Runner/Info.plist`

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

## Part 11: Create Mobile OAuth2 Provider in Authentik

Mobile apps use **PKCE** (no client secret), so create a separate **Public** provider.

### Navigate to Providers

1. Go to Authentik Admin → **Applications** → **Providers**
2. Click **Create**
3. Select **OAuth2/OpenID Provider**

### Configure Mobile Provider

| Field | Value |
|-------|-------|
| **Name** | `Aura Mobile App` |
| **Authorization flow** | `default-provider-authorization-implicit-consent` |
| **Client type** | `Public` ← **Not Confidential!** |
| **Client ID** | `aura-mobile-app` ← **Must match Flutter config** |
| **Redirect URIs** | `com.project.aura://login-callback` |
| **Signing Key** | `authentik Self-signed Certificate` |

### Scopes

Ensure these scopes are enabled:
- `openid`
- `profile`
- `email`

---

## Part 12: Link Mobile Provider to Application

### Option A: Add to Existing Application

1. Go to **Applications** → **Project Aura**
2. Edit the application
3. Under **Backchannel providers**, add the mobile provider

### Option B: Create Separate Application

1. Create new application with name `Aura Mobile`
2. Set **Slug** to `aura` (same as backend)
3. Select `Aura Mobile App` provider

---

## Part 13: Run Flutter App

### Start Backend (if not running)

Authentik should already be running via NodePort. For the backend:
```bash
# Start aura-backend with hot-reload
skaffold dev
```

### Run on Android Emulator

```bash
cd flutter
flutter run
```

### Run on iOS Simulator

```bash
cd flutter
flutter run -d ios
```

---

## Part 14: Test Mobile Authentication

### Expected Flow

1. App opens to Login Screen
2. Tap **"Login with Aura ID"**
3. System browser opens to Authentik
4. Login with admin credentials
5. Approve consent
6. Browser redirects back to app
7. App shows "Success!" and navigates to home

### Network Mapping

| Platform | Authentik URL | Backend URL |
|----------|---------------|-------------|
| Android Emulator | `10.0.2.2:30080` | `10.0.2.2:30000` |
| iOS Simulator | `localhost:30080` | `localhost:30000` |
| Physical Device | `<your-ip>:30080` | `<your-ip>:30000` |

> The app automatically handles this via `auth_config.dart`.

---

## Flutter Troubleshooting

### "Discovery document not found" Error

Authentik isn't reachable. Check:
```bash
# Check if Authentik is running
kubectl get pods -n aura-auth

# Test from your machine
curl http://localhost:30080/application/o/aura/.well-known/openid-configuration
```

If this fails, Authentik pods might still be starting.

### "invalid_redirect_uri" Error

Redirect URI doesn't match. In Authentik, set exactly:
```
com.project.aura://login-callback
```

### "invalid_client" Error

Client ID mismatch. The Flutter app expects:
```dart
static const String clientId = 'aura-mobile-app';
```

Make sure the Authentik provider has the same Client ID.

### App Crashes on Redirect

Deep linking not configured. Verify:
- Android: `manifestPlaceholders` in `build.gradle`
- iOS: `CFBundleURLSchemes` in `Info.plist`

### API Returns 401 Unauthorized

Token not being sent. Check:
1. Is token stored? (Check secure storage)
2. Is Authorization header being set?

Debug with:
```dart
debugPrint('Token: ${await authService.getAccessToken()}');
```

---

## Flutter Quick Reference

| Action | Command |
|--------|---------|
| Install deps | `cd flutter && flutter pub get` |
| Run Android | `flutter run` |
| Run iOS | `flutter run -d ios` |
| Clean build | `flutter clean && flutter pub get` |

| File | Purpose |
|------|---------|
| `lib/core/auth_config.dart` | OAuth URLs, Client ID |
| `lib/services/auth_service.dart` | Login/logout/refresh |
| `lib/services/api_client.dart` | Authenticated HTTP requests |
| `lib/ui/login_screen.dart` | Login button and status |

