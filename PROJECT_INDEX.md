# Project Index: HealthExport

Generated: 2026-04-11

## Project Summary

iOS app that reads health data from Apple HealthKit, displays it in a modern dark-theme dashboard, and exports data as JSON to local storage or custom directories (including iCloud Drive).

- **Platform**: iOS 17+, SwiftUI only
- **Bundle ID**: `com.jingyi.healthexport`
- **Build System**: XcodeGen (`project.yml`) + Xcode 16
- **Architecture**: MVVM-lite (Views + Services + Models, no dedicated ViewModel layer)
- **Version**: 1.1.0

## Directory Structure

```
HealthExport/
├── HealthExportApp.swift          # @main entry point
├── ContentView.swift             # Root view (authorization gate → DashboardView)
├── Info.plist
├── HealthExport.entitlements      # HealthKit capability
├── Extensions/
│   └── Color+Theme.swift         # Color palette & gradient helpers
├── Models/
│   ├── HealthData.swift          # All data models (sleep, HR, steps, O2, etc.)
│   └── Settings.swift            # AppSettings + SettingsManager (UserDefaults)
├── Services/
│   ├── HealthKitService.swift    # HealthKit queries, authorization, auto-export observers
│   └── ExportService.swift       # JSON export, file management, bookmark-based directory
└── Views/
    ├── DashboardView.swift       # Main dashboard (date picker, cards, export sheet)
    ├── SleepDetailView.swift     # Sleep stage timeline + breakdown
    ├── SettingsView.swift        # Toggles, export path, manual export
    └── Components/
        ├── CardComponents.swift  # Reusable: HealthCard, ProgressRing, AnimatedNumber, etc.
        ├── HeartRateCard.swift   # Heart rate card + HeartRateGraphView
        ├── SleepCardView.swift   # Sleep summary card with stage pills
        ├── SleepStagePill.swift  # Individual sleep stage row
        └── StepsCard.swift       # Steps card + ActiveEnergyCard
```

## Entry Points

- **App**: `HealthExportApp.swift` → `@main`, injects `HealthKitService` & `SettingsManager` as environment objects
- **Root View**: `ContentView.swift` → routes to `DashboardView` or `UnavailableView`
- **Dashboard**: `DashboardView.swift` → main screen with date navigation, health cards, export/settings sheets

## Core Modules

### HealthKitService (`Services/HealthKitService.swift`)
- **Authorization**: `requestAuthorization()` → async/await HealthKit permission flow
- **Observers**: `setupObservers()` → background delivery + HKObserverQuery for 7 key types + sleep
- **Fetchers**: Generic `fetchSum`/`fetchAverage`/`fetchSamples` + typed fetchers for each metric
- **Data types**: Sleep, Heart Rate, Steps, Active Energy, O2 Saturation, Respiratory Rate, Resting HR, Walking HR, HRV, Distance, Exercise Minutes, Stand Hours
- **Auto-export**: `fetchAndAutoExport()` → fetches all data + triggers `ExportService.exportIncremental()`

### ExportService (`Services/ExportService.swift`)
- **JSON encoding**: `exportToJSON()` → pretty-printed, sorted keys, ISO8601 dates
- **Incremental export**: `exportIncremental()` → saves to `date/YYYY-MM-DD/HH-mm-ss.json`
- **Directory management**: Security-scoped bookmarks for custom export paths (iCloud Drive support)
- **File listing**: `listAllExportedFiles()`, `listDatesWithFileCount()`
- **Share sheet**: `createShareFile()` → temp file for UIActivityViewController

### Models (`Models/`)
- `HealthData`: Top-level container (date + optional metric structs)
- `SleepData` / `SleepStage` / `SleepStageType`: Sleep with stage breakdown, efficiency
- `HeartRateData` / `HeartRateSample`: Current/min/max BPM + time-series samples
- `StepsData`, `ActiveEnergyData`, `ExerciseMinutesData`, `StandMinutesData`: Progress-based metrics
- `OxygenSaturationData`, `RespiratoryRateData`, `WristTemperatureData`: Vitals
- `HeartRateVariabilityData`, `WalkingHeartRateAverageData`: Advanced HR metrics
- `ExportPayload`: Device ID + timestamp wrapper for server push format
- `AppSettings` / `SettingsManager`: 12 sync toggles + auto-sync config + export directory bookmark

### Views (`Views/`)
- **DashboardView**: Date navigation, authorization card, loading/empty states, health cards
- **SleepDetailView**: Full sleep analysis with timeline visualization (`SleepTimelineView`), stage breakdown, stats
- **SettingsView**: Data type toggles, export path picker, manual export, exported files list
- **Components**: `HealthCard` (base card), `ProgressRing`, `AnimatedNumber`, `MetricRow`, `ShimmerEffect`

### Theme (`Extensions/Color+Theme.swift`)
- Palette: `.sleep` (purple), `.heartRate` (red/pink), `.steps` (green), `.activeEnergy` (orange)
- Background: `.deepNavy`, `.cardBackground`, `.cardBackgroundSecondary`
- Helpers: `Color.gradient()`, `Color.gradient(from:to:)`

## Configuration

- `project.yml`: XcodeGen spec — iOS 17, Swift 5.9, bundle ID `com.jingyi.healthexport`
- `Info.plist`: Standard iOS app config
- `HealthExport.entitlements`: HealthKit access (`com.apple.developer.healthkit: true`)

## Key Design Patterns

- **Environment Objects**: `HealthKitService` and `SettingsManager` injected via `@EnvironmentObject`
- **Async/Await**: HealthKit callbacks wrapped in `withCheckedThrowingContinuation`
- **Concurrent Fetching**: `async let` for parallel data fetching in `fetchAllData()`
- **Security-Scoped Bookmarks**: `URL.bookmarkData()` for persistent folder access
- **UIKit Bridge**: `DocumentPickerView`, `ShareSheet` via `UIViewControllerRepresentable`

## Data Flow

```
HealthKitService.fetchAllData()
  └─ async let [sleep, heartRate, steps, ...] (parallel)
      └─ HealthData struct
          ├─→ DashboardView (display)
          ├─→ ExportService.exportIncremental() (save JSON)
          └─→ ExportSheetView (preview/copy/share)
```

## Deleted Files (git tracked removal)

- `ViewModels/DashboardViewModel.swift`
- `ViewModels/SleepViewModel.swift`
(Logic moved into views + HealthKitService directly)
