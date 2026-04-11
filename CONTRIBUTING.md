# Contributing to HealthExport

Thanks for your interest in contributing! This guide covers the basics.

## Development Setup

### Prerequisites

- **Xcode 16.0+** (for iOS app)
- **XcodeGen** — `brew install xcodegen`
- **Python 3.12+** (for server, optional)
- **ruff** — `pip install ruff` (for server linting)

### iOS App

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Open in Xcode
open HealthExport.xcodeproj

# Build for simulator
xcodebuild build \
  -scheme HealthExport \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Server

```bash
cd server
python server.py --port 8080
```

## Project Structure

```
HealthExport/
├── HealthExport/          # iOS app source
│   ├── Models/            # Data models
│   ├── Services/          # HealthKit, Export services
│   ├── ViewModels/        # MVVM view models
│   ├── Views/             # SwiftUI views
│   ├── Extensions/        # Swift extensions
│   └── Resources/         # Assets
├── server/                # Webhook receiver (Python)
│   └── server.py
├── project.yml            # XcodeGen project spec
└── .github/workflows/     # CI/CD
```

## Making Changes

### Branch naming

- `fix/<short-desc>` — bug fixes
- `feat/<short-desc>` — new features
- `chore/<short-desc>` — maintenance

### Commit style

Use conventional commits:

```
fix: correct sleep stage parsing for core sleep
feat: add heart rate trend chart
chore: update dependencies
```

### Before submitting a PR

1. **iOS**: Ensure `xcodebuild build` succeeds
2. **Server**: Run `ruff check server.py && ruff format --check server.py`
3. **Test on a real device** for HealthKit features (simulator has limited support)
4. Update docs if you changed behavior or added settings

## Code Style

### Swift
- **SwiftUI only** — no UIKit
- **MVVM** architecture — keep views thin, logic in ViewModels
- Follow Swift API Design Guidelines
- Use `@StateObject` / `@ObservedObject` for state management

### Python (server)
- Follow `ruff` defaults (PEP 8 + isort)
- Type hints preferred
- Keep `server.py` lightweight — stdlib only, no external deps

## HealthKit Notes

- HealthKit **requires a physical device** for full functionality
- Simulator has limited/mock HealthKit data
- Test permission flows on a real device before merging
- Never log or expose actual health data

## Reporting Issues

When filing a bug report, please include:

1. **iOS version** and **device model**
2. **Steps to reproduce**
3. **Expected vs actual behavior**
4. **Screenshots** if applicable
5. **Console logs** (Xcode debug output)

## License

By contributing, you agree that your code will be licensed under the same license as the project.
