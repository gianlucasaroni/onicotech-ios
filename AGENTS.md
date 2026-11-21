# Onicotech iOS

## Stack
- **Xcode 15**
- **Swift 5.9**
- **SwiftUI** (UI layer)
- **Combine** (state, networking)
- **Kingfisher** – image caching (see Package.resolved)
- **LocalAuthentication** – biometrics
- **WatchConnectivity** – sync with Watch app
- **Keychain** – secure storage

## Project structure
- `Onicotech/` – main iOS app
- `OnicotechWatch/` – Apple‑watch extension
- `Onicotech.xcodeproj` – Xcode workspace & schemes

## Build / Run
```bash
# Build & run simulator
xcodebuild -scheme Onicotech -destination 'platform=iOS Simulator,name=iPhone 16'

# Build & run watch simulator
xcodebuild -scheme OnicotechWatch -destination 'platform=watchOS Simulator,OS=10.2,name=Apple Watch Series 9'
```

## Tests
```bash
xcodebuild test -scheme Onicotech -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Development notes
- API base URL is in `APIClient.shared.baseServerURL` – change it in code during dev.
- SwiftUI previews are enabled in `.xcodeproj`.
- Localised strings are in `.lproj` folders (not yet committed).
- Watch sync token updates via `WatchConnectivityManager`.
- All secrets are stored in `KeychainHelper` or `UserDefaults`.
- CI uses `Fastlane` (not shown).
