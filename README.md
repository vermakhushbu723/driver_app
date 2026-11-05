# ICECLUB Rider App

Flutter app for ICECLUB riders and drivers: accept orders, load at the factory, deliver with proof and collect
payment. It is a separate project from the Dealer App, and builds for Android and iOS.

## Run

```
flutter pub get
flutter run
```

Demo account: mobile `9000000001`, OTP `123456`, password `Rider@1234`. Riders can't register themselves, because the
admin adds them, so other numbers are refused.

## The job flow

Assigned -> Accepted -> Picked up (loading confirmed with quantity and photos) -> Out for delivery ->
Delivered (quantity, OTP, photo, payment) or Failed (reason, optional photos).

Each step is only allowed from the step before it. GPS is recorded at loading, delivery and failure when it is
available, but a rider with no signal can still finish the job.

## Folder structure

```
lib/
  main.dart               entry point
  app/                    app widget, routes, router, bottom navigation
  core/                   constants, errors, location, storage, theme, utils, shared widgets
  features/<feature>/
    domain/               entities and repository interfaces
    data/                 repository implementations
    presentation/         providers and screens
```

## Menu to feature map

| Menu section | Feature folder |
| --- | --- |
| Dashboard | `dashboard` |
| My Orders, Delivery Management, My History (deliveries) | `orders` |
| Pickup Management | `pickup` |
| Live Tracking | `tracking` |
| Payment Collection, My History (collections) | `collection` |
| Return and Damage | `returns` |
| Attendance and Earnings | `attendance` |
| Notifications | `notifications` |
| Help and Support | `support` |
| My Profile and Settings | `profile` |

## Connecting a real backend

There is no server yet. Every `data/fake_*_repository.dart` keeps its data on the device, so this app and the Dealer
App don't share anything. An order placed in the Dealer App doesn't reach this app until both use the same server.

| Simulated in the app | Needed in production |
| --- | --- |
| Three sample orders appear each day | Admin Panel assigns orders |
| Only the demo rider can sign in | Admin Panel adds riders, server login |
| OTP is always `123456` | SMS provider |
| Delivery OTP is shown on screen | Server checks the OTP from the Dealer App |
| Collections and deposits stay on the device | Server ledger and accounts team confirmation |
| Notifications are in the app only | Firebase Cloud Messaging |
| Going off duty changes nothing else | Server stops assigning orders |
| Salary and incentives are sample figures | Admin Panel holds each rider's pay |
| Attendance and return reports stay on the device | Server and Admin Panel |

Not built yet, because they need the server:

- Sending the rider's location to the company. The app records it only while open and keeps it on the phone. Tracking
  with the app closed needs background location permission and Play Store approval.
- Uploading proof photos, and offline sync. Photos stay on the phone for now.

Maps use public OpenStreetMap tiles, which are fine for development. Production needs a paid provider.

## Before going live

- Real factory details: `features/pickup/data/fake_factory_repository.dart`
- Company phone and WhatsApp: `core/constants/app_constants.dart`
- Salary and incentive rules: `features/attendance/data/fake_attendance_repository.dart`
- Application ID `in.iceclubstore.driver_app`

## Theme

Same as the Dealer App: blue and white colours, Sora and Manrope with achivora.com's phone text sizes, and the
`growork-user-app` design for cards, fields, buttons, bottom bar and spacing.

## Tests

```
flutter test
```
