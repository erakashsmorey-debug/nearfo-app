# Nearfo - Play Store Submission Guide

## Step 1: Build Release APK

Run these commands on your local machine (where Flutter is installed):

```bash
cd nearfo-flutter-app
flutter clean
flutter pub get
flutter build apk --release --no-tree-shake-icons
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

**Important:** The keystore file (`android/app/nearfo-release.jks`) and key.properties (`android/key.properties`) are NOT in git for security. They were generated in the cloud session. You need to either:
- Copy them from your session, OR
- Generate new ones:
```bash
keytool -genkey -v -keystore android/app/nearfo-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nearfo -storepass nearfo2026secure -keypass nearfo2026secure -dname "CN=Akash Smorey, OU=Nearfo, O=Nearfo, L=India, S=India, C=IN"
```
Then create `android/key.properties`:
```
storePassword=nearfo2026secure
keyPassword=nearfo2026secure
keyAlias=nearfo
storeFile=app/nearfo-release.jks
```

## Step 2: Create Google Play Console Account

1. Go to https://play.google.com/console
2. Pay $25 one-time registration fee
3. Complete identity verification

## Step 3: Create App Listing

### App Details
- **App name:** Nearfo - Know Your Circle
- **Short description:** Connect with people nearby. Share vibes, chat live, and discover your circle.
- **Category:** Social
- **Content rating:** Complete the content rating questionnaire (select "Social/Communication")
- **Contact email:** er.akashsmorey@gmail.com

### Full Description
See `play-store-listing.txt` for the full description.

### Graphics
Upload these from the `store-assets/` folder:
- **Hi-res icon (512x512):** `play-store-icon-512.png`
- **Feature graphic (1024x500):** `feature-graphic.png`
- **Screenshots:** You need 2-8 phone screenshots. Take them from the app running on your phone/emulator:
  1. Login/OTP screen
  2. Home feed with posts
  3. Discover/nearby users screen
  4. Chat conversation
  5. Profile screen
  6. Create post screen

### Privacy Policy
- **URL:** https://api.nearfo.com/privacy

## Step 4: App Content & Declarations

### Data Safety
Declare the following data types:
- **Phone number** - collected for authentication
- **Approximate location** - collected for nearby content
- **Name, username, bio** - collected for profile
- **Photos** - collected for posts and avatar
- **Messages** - collected for chat functionality

### Permissions Justification
- **Location (fine + coarse):** Required to show nearby content and users
- **Camera:** For taking photos for posts and profile
- **Notifications:** For push notifications about messages and interactions

## Step 5: Upload APK & Release

1. Go to Production > Create new release
2. Upload `app-release.apk`
3. Add release notes: "Initial release of Nearfo - your local social network"
4. Review and roll out

## GitHub Actions (Optional)

To auto-build APKs on every push, add the workflow scope to your GitHub PAT:
1. Go to https://github.com/settings/tokens
2. Edit your PAT and add the `workflow` scope
3. Push the `.github/workflows/build-apk.yml` file

## Keystore Backup

**CRITICAL:** Back up your keystore file (`nearfo-release.jks`) and passwords securely. If you lose the keystore, you cannot update your app on Play Store.

Keystore details:
- File: `android/app/nearfo-release.jks`
- Alias: `nearfo`
- Store password: `nearfo2026secure`
- Key password: `nearfo2026secure`
- Validity: 10,000 days (~27 years)
