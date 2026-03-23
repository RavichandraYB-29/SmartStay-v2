# SmartStay 🏨

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth-FFCA28?logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green)

> **Open-source PG and hostel management system** built with Flutter & Firebase.  
> Separate dashboards for admins and residents — room allocation, rent payments, complaints, notices, and more.

---

## ✨ Features

### 🔑 Admin

- Multi-hostel / PG / floor / room hierarchy management
- Bed-level allocation & reallocation with visual bed grid
- Dynamic KPI dashboard — occupancy, pending dues, recent activity
- Payment tracking with paid / pending / overdue status
- Complaint management with priority, category & status workflow
- Notice broadcasting to residents
- Invite residents via email with auto-generated credentials

### 👤 Resident

- Personal dashboard with room, payment & roommate info
- Online rent payments via PayU gateway
- Raise & track complaints with real-time status updates
- View notices posted by admin
- Password management & profile settings

---

## 🛠 Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** (Dart) | Cross-platform UI (Web, Android, macOS) |
| **Cloud Firestore** | Real-time NoSQL database |
| **Firebase Auth** | Email/Password + Google Sign-In |
| **PayU** | Payment gateway integration |
| **fl_chart** | Interactive charts & graphs |
| **pdf / printing** | PDF generation & printing |
| **Inter** (Google Fonts) | Typography |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `^3.10.4`
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

### Step 1 — Clone & install

```bash
git clone https://github.com/YOUR_USERNAME/SmartStay-v2.git
cd SmartStay-v2
flutter pub get
```

### Step 2 — Firebase setup

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** → Email/Password + Google Sign-In
3. Enable **Cloud Firestore**
4. Generate your config:

```bash
flutterfire configure
```

This creates `lib/firebase_options.dart` (git-ignored).

> See [SETUP.md](SETUP.md) for detailed Firebase setup instructions.

### Step 3 — PayU credentials

```bash
cp lib/config/env.dart.example lib/config/env.dart
```

Edit `lib/config/env.dart` and fill in your PayU merchant key & salt.

### Step 4 — Deploy Firestore rules & indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

> `firestore.rules` and `firestore.indexes.json` are included in the repo.

### Step 5 — Run

```bash
flutter run -d chrome        # Web
flutter run -d android       # Android
flutter run -d macos         # macOS
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # 🔒 Git-ignored
├── theme.dart                         # App-wide ThemeData
│
├── config/
│   ├── env.dart                       # 🔒 Git-ignored (PayU credentials)
│   └── env.dart.example               # Template for env.dart
│
├── screens/
│   ├── login_screen.dart              # Email + Google Sign-In
│   ├── set_password_screen.dart       # First-time password setup
│   ├── admin_dashboard.dart           # Admin home with KPIs
│   ├── admin_payments_screen.dart     # Payment history & filtering
│   ├── hostel_management_screen.dart  # CRUD hostels
│   ├── floor_management_screen.dart   # Floor management
│   ├── room_management_screen.dart    # Room management
│   ├── add_hostel_dialog.dart         # Add hostel
│   ├── edit_hostel_dialog.dart        # Edit hostel
│   ├── add_floor_dialog.dart          # Add floor
│   ├── add_room_dialog.dart           # Add room
│   ├── add_resident_screen.dart       # Invite residents
│   ├── allocate_resident_screen.dart  # Allocate / reallocate
│   ├── resident_dashboard.dart        # Resident home
│   ├── rent_payments_screen.dart      # Resident payment flow
│   ├── payment_waiting_screen.dart    # Payment processing
│   ├── payment_status_screen.dart     # Payment result
│   ├── raise_complaint_screen.dart    # Complaints
│   └── resident_notices_screen.dart   # Notices
│
├── services/
│   ├── allocation_service.dart        # Allocation logic
│   ├── payu_service.dart              # PayU gateway
│   └── room_service.dart              # Room helpers
│
├── utils/
│   └── admin_design_system.dart       # Colors, gradients, shadows
│
├── widgets/
│   ├── admin_widgets.dart             # Reusable admin components
│   ├── custom_textfield.dart          # Styled text fields
│   ├── dashboard_widgets.dart         # Dashboard cards
│   ├── forgot_password_dialog.dart    # Password reset
│   ├── gradient_button.dart           # Gradient button
│   ├── loading_overlay.dart           # Loading overlay
│   ├── revenue_chart.dart             # Revenue chart
│   └── success_dialog.dart            # Success dialog
│
└── theme/
    ├── app_colors.dart                # Color constants
    ├── app_text_styles.dart           # Text styles
    └── theme_controller.dart          # Light / dark mode
```

---

## 🗄 Firestore Data Structure

```
users/{uid}                            # role, name, email
residents/{id}                         # fullName, email, adminId, allocationDetails
hostels/{id}                           # name, ownerId
  └── pgs/{id}                         # name, totalBeds, availableBeds
       └── floors/{id}                 # floorName, floorIndex
            └── rooms/{id}             # roomNumber, totalBeds, rentPerBed
                 └── beds/{id}         # bedNumber, isOccupied, residentId
payments/{id}                          # residentId, adminId, amount, status, paidAt
complaints/{id}                        # residentId, adminId, title, status, priority
notices/{id}                           # title, body, createdByAdminId
```

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
