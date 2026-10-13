# HealthExport - iOS Health Data Export App

## Overview
A beautiful iOS app that reads health data from Apple HealthKit and displays it in a clean dashboard, with the ability to push data to a custom server.

## Requirements

### Core Features
1. **HealthKit Integration**: Read sleep, heart rate, steps, active energy from HealthKit
2. **Beautiful Dashboard**: Modern SwiftUI interface showing today's health data
3. **Data Export**: JSON export of health data
4. **Server Push**: HTTP POST health data to a configurable endpoint

### UI Design
- **Style**: Modern, clean, Apple Health-inspired but more personal
- **Colors**: Deep navy/dark theme with accent colors per data type
  - Sleep: Purple/Indigo
  - Heart Rate: Red/Pink
  - Steps: Green
  - Active Energy: Orange
- **Cards**: Rounded corners, subtle gradients, blur effects
- **Animations**: Smooth transitions, satisfying number counters
- **Fonts**: SF Pro, large bold numbers for key metrics

### Screens
1. **Dashboard (Main)**: Today's summary with animated cards
   - Sleep duration (with stage breakdown like Apple Watch)
   - Heart rate (current + range)
   - Steps count (with ring progress)
   - Active energy burned
2. **Sleep Detail**: Detailed sleep stage timeline (like the Apple Watch screenshot the user showed)
3. **Settings**: Server endpoint configuration, data types to sync

### Technical
- SwiftUI only (no UIKit)
- iOS 17+ target
- HealthKit permissions request on first launch
- Background fetch capability (optional for v1)
- MVVM architecture

### Data Model
```swift
struct HealthData: Codable {
    let date: String
    let sleep: SleepData?
    let heartRate: HeartRateData?
    let steps: StepsData?
    let activeEnergy: ActiveEnergyData?
}

struct SleepData: Codable {
    let totalDuration: TimeInterval
    let stages: [SleepStage]
}

struct SleepStage: Codable {
    let type: String // awake, rem, core, deep
    let startDate: Date
    let endDate: Date
}
```

### Server Push Format
POST to configurable endpoint with JSON body:
```json
{
  "device_id": "device-uuid",
  "timestamp": "2026-03-29T12:00:00Z",
  "data": {
    "sleep": { ... },
    "heart_rate": { ... },
    "steps": { ... },
    "active_energy": { ... }
  }
}
```

## Out of Scope (v1)
- WatchOS companion app
- Historical data browsing (beyond today/last 7 days)
- Authentication with server
- Background sync
