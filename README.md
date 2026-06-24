# NearFind

NearFind is a hyperlocal delivery mobile application built with Flutter and Firebase that connects customers with nearby retailers. The application facilitates real-time product discovery, instant order placement with automatic stock adjustments, and a multi-role workflow that coordinates customers, retailers, delivery partners, and administrators. Users can browse products, track orders through structured stages, accept delivery assignments, and monitor overall system health in real-time.

## Tech Stack

*   **Framework:** Flutter (Dart)
*   **Database:** Firebase Cloud Firestore (real-time stream synchronization)
*   **Authentication:** Firebase Auth (anonymous authentication for instant onboarding)
*   **State Management:** Provider pattern for role-based session and application states

## Installation Guide (APK)

To run the application on an Android device:

1.  **Download the APK:** Navigate to the [Releases](https://github.com/your-username/nearfind/releases) section of this GitHub repository and download the latest `.apk` asset.
2.  **Enable Unknown Sources:** Go to your Android device's **Settings** > **Security** (or **Apps & Notifications** > **Special App Access**), and toggle on **Install Unknown Apps** for your web browser or file manager.
3.  **Install the App:** Open your device's downloads folder, tap the downloaded APK, and follow the system prompts to complete installation.

## App Usage & Architecture

### Switching Roles
For ease of testing and demonstration, you can switch between the four available roles (Customer, Retailer, Delivery Partner, and Admin) at any time. Simply tap the system or on-screen **Back** button from any main screen to return to the startup role selection interface.

### Key Assumptions
*   **Single-Retailer Scope:** In this iteration, multi-retailer registration, onboarding, and mapping are omitted. The application scopes all inventory management and customer orders to a single hardcoded retailer instance, **"Sharma Kirana Store"**.
*   **Seeded Products:** The database is pre-populated with a standard set of goods:
    *   Maggi Noodles
    *   Tata Salt
    *   Parle-G Biscuits
    *   Aashirvaad Atta
    *   Amul Butter
*   **Automated Lifecycle Timers:**
    *   **Retailer Acceptance:** The retailer has **2 minutes** to accept an order once placed, after which it automatically transitions to a cancelled state.
    *   **Delivery Assignment:** Once marked ready for pickup, the order enters the delivery partner pool with a **3-minute** acceptance window before automatic cancellation.

## Folder Structure

The codebase is organized logically into clean architectural layers within the `lib/` directory:

```text
lib/
├── models/         # Data classes mapping Firestore documents (Product, NearFindOrder)
├── services/       # Services managing backend logic (FirestoreService, OrderTimerService)
├── providers/      # Providers managing global state and authentication
├── screens/        # Screen files grouped by user role
│   ├── customer/   # Customer home, product search, and tracking views
│   ├── retailer/   # Retailer order queue and inventory dashboards
│   ├── delivery/   # Delivery partner dispatch board and delivery progress views
│   ├── admin/      # Admin order monitoring and metrics console
│   └── role_select_screen.dart
└── widgets/        # Reusable component widgets (banners, buttons, timers)
```
