# HealthExport

An iOS app for exporting and visualizing your HealthKit data.

## Requirements

- Xcode 16.0+
- iOS 17.0+
- Swift 5.9+

## Opening the Project

1. Open `HealthExport.xcodeproj` in Xcode:
   ```bash
   open HealthExport.xcodeproj
   ```

2. Select your development team:
   - Click on the "HealthExport" project in the navigator
   - Select the "HealthExport" target
   - Go to "Signing & Capabilities" tab
   - Select your Team from the dropdown

3. Enable HealthKit capability:
   - The HealthKit capability should already be added
   - If needed, click "+ Capability" and add "HealthKit"

## Project Structure

```
HealthExport/
├── HealthExportApp.swift      # App entry point
├── ContentView.swift          # Main content view
├── Info.plist                 # App configuration with HealthKit permissions
├── HealthExport.entitlements  # HealthKit entitlements
├── Models/
│   ├── HealthData.swift       # Health data models
│   └── Settings.swift         # App settings
├── Services/
│   ├── HealthKitService.swift # HealthKit integration
│   └── ExportService.swift    # Data export functionality
├── ViewModels/
│   ├── DashboardViewModel.swift
│   └── SleepViewModel.swift
├── Views/
│   ├── DashboardView.swift
│   ├── SleepDetailView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── CardComponents.swift
│       ├── SleepCardView.swift
│       ├── HeartRateCard.swift
│       ├── StepsCard.swift
│       └── SleepStagePill.swift
├── Extensions/
│   └── Color+Theme.swift      # Theme colors
└── Resources/
    └── Assets.xcassets/       # App assets
```

## HealthKit Permissions

The app requires the following HealthKit permissions:
- **Read**: Health data (steps, heart rate, sleep, etc.)
- **Write**: Optional health data updates

Permission descriptions are configured in `Info.plist`:
- `NSHealthShareUsageDescription`: "HealthExport needs access to read your health data to display and export it."
- `NSHealthUpdateUsageDescription`: "HealthExport may write health data to your HealthKit store."

## Building & Running

1. Select your target device (simulator or physical device)
2. Press `Cmd+R` to build and run

**Note**: HealthKit requires a physical device for full functionality. The simulator has limited HealthKit support.

## Troubleshooting

### "No signing certificate" error
- Open Xcode Preferences > Accounts
- Add your Apple ID
- Select your team in project settings

### HealthKit not working on simulator
- HealthKit has limited support on simulator
- Use a physical device for testing HealthKit features

### Build errors
- Clean build folder: `Cmd+Shift+K`
- Delete derived data: `~/Library/Developer/Xcode/DerivedData`
- Restart Xcode
