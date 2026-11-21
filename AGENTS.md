# Onicotech iOS

## Stack
- **Xcode 16+** (`objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup`)
- **Swift 5.x** + **SwiftUI** (multi-platform: **iOS**, **macOS**, **watchOS 10+**)
- **Observation** (`@Observable`) & **Combine** (state, networking)
- **Kingfisher** – image caching (SPM, see `Package.resolved`)
- **LocalAuthentication** – biometrics
- **WatchConnectivity** – sync with Watch app
- **WidgetKit** – Watch schedule contract via App Group (`group.com.gsdev.Onicotech.watch`)
- **Keychain** – secure storage

## Project structure
- `Onicotech/` – main iOS + macOS app (auto-synced folder in Xcode target `Onicotech`)
- `OnicotechWatch/` – Apple Watch app (auto-synced folder in Xcode target `OnicotechWatch`)
- `OnicotechWatchWidget/`, `OnicotechWatchShared/`, `OnicotechWatchConfig/` – Watch WidgetKit extension sources & entitlements (ready to be wired as a Widget Extension target in Xcode)
- `Onicotech.xcodeproj` – Xcode project & schemes

## Build / Run
```bash
# Build & run iOS simulator
xcodebuild -scheme Onicotech -destination 'platform=iOS Simulator,name=iPhone 16'

# Build & run watch simulator
xcodebuild -scheme OnicotechWatch -destination 'platform=watchOS Simulator,OS=10.2,name=Apple Watch Series 9'
```

## Tests
```bash
xcodebuild test -scheme Onicotech -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Development notes
- Target `Onicotech` compila sia per **iOS** che per **macOS**: usare `Color.systemBackgroundCompat` (non `Color.systemBackground`) e racchiudere i modifier solo-iOS (es. `.textInputAutocapitalization`, `.keyboardType`, `.navigationBarTitleDisplayMode`) in `#if os(iOS)`.
- `APIClient.baseServerURL` è definito in `Onicotech/Networking/APIClient.swift`.
- `CommandPaletteState` (`⌘K` globale in `ContentView`) carica snapshot da `APIClient.shared` e sincronizza i dati dalle liste.
- `AppointmentSchedule` è presente in `Onicotech/Models/` e `OnicotechWatch/Models/` per condividere la schedule del prossimo appuntamento via `UserDefaults(suiteName: "group.com.gsdev.Onicotech.watch")` senza dipendere da un modulo separato finché il target widget non è aggiunto al `.xcodeproj`.
- `AppointmentFormView` esegue il prefill dall'ultimo appuntamento completato via `GET /clients/:id/last-appointment`; `DashboardViewModel` carica `GET /dashboard/next-free-slot` in modo isolato (`try?`).
- Watch sync token updates via `WatchConnectivityManager`.
- All secrets are stored in `KeychainHelper` or `UserDefaults`.
