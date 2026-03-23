# SmartStay — Developer Setup Guide 🔧

Step-by-step guide to set up the SmartStay project on your local machine.

---

## 📋 Prerequisites

| Tool | Install Command |
|------|----------------|
| Flutter SDK `^3.10.4` | [flutter.dev/docs/get-started](https://flutter.dev/docs/get-started/install) |
| Firebase CLI | `npm install -g firebase-tools` |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` |
| Git | [git-scm.com](https://git-scm.com/) |

Verify installations:

```bash
flutter --version
firebase --version
flutterfire --version
```

---

## 1️⃣ Clone & Install Dependencies

```bash
git clone https://github.com/YOUR_USERNAME/SmartStay-v2.git
cd SmartStay-v2
flutter pub get
```

---

## 2️⃣ Create a Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **"Add project"** → name it (e.g., `SmartStay`)
3. Disable Google Analytics (optional)
4. Click **Create project**

---

## 3️⃣ Enable Firebase Services

### Authentication

1. In Firebase Console → **Authentication** → **Get started**
2. Enable **Email/Password** provider
3. Enable **Google** provider → set your support email → Save

### Cloud Firestore

1. In Firebase Console → **Firestore Database** → **Create database**
2. Start in **production mode** (we'll deploy rules next)
3. Choose a region close to your users

---

## 4️⃣ Generate Firebase Config

From the project root, run:

```bash
firebase login
flutterfire configure
```

This will:
- Register your Flutter app with Firebase
- Generate `lib/firebase_options.dart` (auto-gitignored)
- Generate `android/app/google-services.json` (auto-gitignored)

---

## 5️⃣ Deploy Firestore Rules & Indexes

The repo includes pre-configured security rules and composite indexes:

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

Or deploy both at once:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### What's deployed

| File | Purpose |
|------|---------|
| `firestore.rules` | Security rules — admin/resident data isolation |
| `firestore.indexes.json` | Composite indexes for multi-field queries |

---

## 6️⃣ Configure PayU Credentials

1. Copy the example file:

```bash
cp lib/config/env.dart.example lib/config/env.dart
```

2. Edit `lib/config/env.dart`:

```dart
class Env {
  Env._();
  static const String payuMerchantKey  = 'YOUR_REAL_KEY';
  static const String payuMerchantSalt = 'YOUR_REAL_SALT';
  static const bool   payuIsProduction = false;  // true for live payments
}
```

### Test vs Production

| Mode | `payuIsProduction` | PayU URL |
|------|--------------------|----------|
| **Test** | `false` | `https://test.payu.in/_payment` |
| **Production** | `true` | `https://secure.payu.in/_payment` |

Get test credentials from [PayU Dashboard](https://payu.in/business).

---

## 7️⃣ Run the App

```bash
# Web (recommended for development)
flutter run -d chrome

# Android
flutter run -d android

# macOS
flutter run -d macos
```

---

## 🔒 Git-Ignored Files

These files contain secrets and are **never committed**:

| File | Why |
|------|-----|
| `lib/firebase_options.dart` | Firebase API keys, project IDs, app IDs |
| `lib/config/env.dart` | PayU merchant key & salt |
| `android/app/google-services.json` | Android Firebase config |
| `ios/Runner/GoogleService-Info.plist` | iOS Firebase config |
| `macos/Runner/GoogleService-Info.plist` | macOS Firebase config |
| `.env` / `*.env` | Environment variables |
| `config.json` | Any runtime config |

If you accidentally commit any of these:

```bash
git rm --cached <file>
git commit -m "Remove tracked secret file"
```

---

## ❓ Troubleshooting

| Issue | Fix |
|-------|-----|
| `firebase_options.dart not found` | Run `flutterfire configure` |
| `env.dart not found` | Copy `env.dart.example` → `env.dart` |
| Firestore permission denied | Run `firebase deploy --only firestore:rules` |
| Composite index errors | Run `firebase deploy --only firestore:indexes` |
| Google Sign-In not working | Ensure Google provider is enabled in Firebase Auth |
