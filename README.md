# flutter_application_1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# SmartStay 🏨  
### Digital PG & Hostel Management System

SmartStay is a modern **Flutter-based hostel and PG management application** designed to digitize resident onboarding, room allocation, and administrative operations.

It replaces manual registers and spreadsheets with a **role-based, scalable, Firebase-powered system**.

---

## 🚀 Project Overview

SmartStay focuses on solving real-world problems faced by PG and hostel owners:

- Resident self-registration
- Centralized hostel, floor, and room management
- Controlled room & bed allocation by admin
- Clear visibility of occupancy and vacancies
- Clean, modular UI ready for future scaling

---

## 👥 User Roles

### 👤 Admin
- Manage hostels, floors, rooms, and beds
- View registered (unallocated) residents
- Allocate residents to hostel → floor → room → bed
- Track occupancy and vacancies
- View revenue insights (UI ready)

### 🧑‍🎓 Resident
- Self-register using Email/Password or Google Sign-In
- View allocated hostel, room, and bed
- Access personal dashboard (future scope)

---

## 🧩 Initial Module Plan

1. Authentication System  
2. Admin Dashboard  
3. Hostel Management  
4. Floor Management  
5. Room Management  
6. Resident Management  
7. Allocation Logic  
8. Revenue & Analytics  
9. Notifications & Utilities  

---

## 🔄 Changes During Development

The architecture evolved based on real hostel workflows:

- ✅ **Resident self-registration introduced**
- ✅ Admin no longer manually creates residents
- ✅ Residents appear as **unallocated** until assigned
- ✅ Two-step flow:
  1. Resident registers
  2. Admin allocates hostel / floor / room / bed

- ✅ Room logic enhanced:
  - Sharing type (1 / 2 / 3 / 4 sharing)
  - Auto-calculated total beds
  - Occupied & vacant bed tracking
  - Over-allocation prevention

- ✅ UI finalized before full database binding

---

## 📦 Current Modules

### 1️⃣ Authentication
- Email & Password login
- Google Sign-In
- Forgot Password dialog
- Loading overlays & success dialogs
- Role-based routing (Admin / Resident)

---

### 2️⃣ Admin Dashboard
- Summary cards:
  - Hostels
  - Floors
  - Rooms
  - Residents
- Quick actions:
  - Add Hostel
  - Add Floor
  - Add Room
  - Add / Allocate Resident
- Revenue chart (UI stage)

---

### 3️⃣ Hostel Management
- Multiple hostels support
- Structured hierarchy
- Future-ready for hostel chains

---

### 4️⃣ Floor Management
- Floors mapped to hostels
- Floor-wise room organization

---

### 5️⃣ Room Management
- Room number
- Sharing type
- Total beds (auto-derived)
- Occupied beds
- Vacant beds
- Visual status indicators

---

### 6️⃣ Resident Management
- Self-registration
- Gender & basic profile info
- Active / inactive status
- Appears unallocated until assigned

---

### 7️⃣ Allocation System (Core Logic)
- Admin selects:
  - Resident → Hostel → Floor → Room → Bed
- Validates:
  - Room capacity
  - Bed availability
- Updates occupancy in real time

---

### 8️⃣ Revenue & Analytics (Planned)
- Monthly revenue chart
- Occupancy-based calculations
- Extendable for rent & dues

---

### 9️⃣ Reusable UI Components
- Gradient buttons
- Custom text fields
- Success dialogs
- Loading overlays
- Centralized theme & colors

---

## 🛠️ Tech Stack

- **Frontend:** Flutter (Material UI)
- **Backend:** Firebase
  - Authentication
  - Cloud Firestore
- **Architecture:** Modular & scalable

---

## 📌 Current Status

- ✔ UI & UX finalized  
- ✔ Core logic implemented  
- ✔ Allocation flow defined  
- 🔄 Firestore integration in progress  
- 🔜 Payments, complaints, notifications (future)

---

## 🔮 Future Enhancements

- Online rent payments
- Maintenance / complaint system
- Advanced admin analytics
- Staff roles
- Web & mobile builds

---

## 🧠 Why SmartStay?

SmartStay is designed around **real hostel operations**, not just CRUD screens.  
Its **allocation-first design** and **scalable structure** make it ideal for:

- PG owners
- Hostel chains
- Student accommodations
- Co-living spaces



