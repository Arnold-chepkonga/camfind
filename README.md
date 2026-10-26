# CampusFind

A campus lost-and-found mobile app that helps students report lost items, report found items, and reconnect belongings with their owners.

## Features

- Student sign-up and login (Firebase Authentication, email and password)
- Report a lost item or a found item
- Live list of all reports (Cloud Firestore)
- Search by item name, description, or location
- Filter by All, Lost, or Found
- Item details page with contact information
- Safe-return tip for meeting the owner or finder
- Mark an item as returned, or delete your own report

## Tech stack

- Flutter and Dart (Android)
- Firebase Authentication
- Cloud Firestore, with security rules so only signed-in users can read reports and only the author can edit or delete them
- GitHub Actions for building the release APK

## Project structure

- `lib/main.dart` contains the whole app (login, home, report, and details screens)
- `pubspec.yaml` holds the project configuration
- `.github/workflows/build.yml` builds the APK in the cloud

## How the APK is built

On every push, GitHub Actions creates the Android project files, adds the Firebase packages, and builds `app-release.apk`. Download it from the **Actions** tab: open the latest successful run and download the **campusfind-apk** artifact.

## Author

Arnold Kipkemei Chepkonga
