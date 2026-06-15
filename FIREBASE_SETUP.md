# Firebase setup checklist (Sound Axis)

If authentication or profile/avatar updates fail with "network error" or
"permission denied", it is almost always one of the items below. The app code
now surfaces the *real* error code, so check the message against this list.

## 1. Credentials are real (not placeholders)
The repo ships placeholder config on purpose:
- `lib/firebase_options.dart` → values are `REPLACE_ME`
- `android/app/google-services.json` → gitignored

CI injects the real values from GitHub secrets at build time:
- `FIREBASE_OPTIONS_DART` — base64 of the real `lib/firebase_options.dart`
- `GOOGLE_SERVICES_JSON` — base64 of the real `android/app/google-services.json`

If these secrets contain placeholder/old values, every Firebase call fails.
On launch the app logs a warning when it detects placeholder credentials.

Generate the values with `flutterfire configure`, then:
```bash
base64 -w0 lib/firebase_options.dart            # -> FIREBASE_OPTIONS_DART
base64 -w0 android/app/google-services.json     # -> GOOGLE_SERVICES_JSON
```

## 2. Enable Email/Password sign-in
Firebase Console → Authentication → Sign-in method → enable **Email/Password**.
(If you use "Continue as Guest", also enable **Anonymous**.)
Symptom if missing: `operation-not-allowed`.

## 3. Create the Cloud Firestore database
Firebase Console → Firestore Database → Create database.
Symptom if missing: `unavailable` / `not-found`.

## 4. Deploy security rules (this repo includes them)
A new project's default rules deny all access.
Symptom if not deployed: `permission-denied` on profile/avatar writes.
```bash
firebase deploy --only firestore:rules,storage
```
See `firestore.rules` and `storage.rules`.

## 5. Enable Cloud Storage
Firebase Console → Storage → Get started (needed for avatar uploads).

---
The bundle id / package name is `com.codetivelab.soundAxis` — the Firebase
Android app and iOS app must be registered with this exact id.
