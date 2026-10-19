# Google Play listing — KnowMates

## Store copy

- **Title:** KnowMates
- **Short description:** Learn from people. Grow together.
- **Full description:** KnowMates is a community where everyone has something to teach and something to learn. Find a person for coding, languages, design, cooking, photography, music, and more. Teach to earn time credits, then use them to learn from someone else. Join the session in the app, with video and screen share.
- **Category:** Education
- **Ads:** No

## Content rating (IARC questionnaire)

- User interaction: **Yes**
- Users can interact: **Yes**
- Sexual content: **No**
- Gambling: **No**
- **Age gate:** 18+ in store listing and in-app (under-18 sign-up rejected)

## Data safety (align with `docs/privacy-policy.html`)

| Data | Collected | Shared | Purpose | Retention |
| --- | --- | --- | --- | --- |
| Account email, profile, skills, availability | Yes | No | Run exchanges | Until account deletion |
| Avatar (JPEG) | Yes | No | Profile | Until account deletion |
| Session times, optional backup meeting link | Yes | No | Scheduling | Until account deletion |
| Session chat text | Yes | No | In-call messaging | Until sender deletes account |
| Wallet / credit ledger | Yes | No | Time credits | Until account deletion |
| Device push token (FCM) | Yes | No | Session notifications | Until token refresh or account deletion |
| Camera & microphone (call) | Yes (not stored) | No | Live session call | Not stored on servers |
| Reports | Yes | No | Safety | As needed for moderation |

- No advertising SDK. No sale of data.
- Privacy policy URL: `https://api.<domain>/privacy`

## Screenshots (1080×1920 minimum, phone)

Capture on emulator or device — product UI only (not mock/Dribbble art):

1. Welcome
2. Discover
3. Home
4. Sessions (scheduled session)
5. In-call screen

## Release build

```bash
cd apps/mobile
flutter build appbundle --release --dart-define=API_BASE=https://<host>
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Upload to **Internal testing**, add tester Google accounts, install via Play opt-in link.

## Signing (local, not committed)

1. Create upload keystore (once):  
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Copy `apps/mobile/android/key.properties.example` → `apps/mobile/android/key.properties` and fill paths/passwords.
3. Play Console: enable **Play App Signing**; upload uses the upload key, Google holds the app signing key.

## Firebase (Spark / free)

- Enable **Cloud Messaging** only. Do not enable Auth, Firestore, or Functions; do not upgrade to Blaze.
- App: add `google-services.json` locally (gitignored). Server: service-account JSON path in `FCM_CREDENTIALS_FILE` (gitignored).
