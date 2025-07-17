# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a watchOS app called "Plunge Timer" built with SwiftUI and HealthKit integration. It's a complete cold plunge timer application with workout tracking, auto-start functionality, and water lock support.

## Architecture

The app follows a single-file SwiftUI architecture with three main components:

### Core Components
- **WorkoutManager**: ObservableObject that handles HealthKit integration and workout session management
- **TimePickers**: Custom SwiftUI component for minute/second selection using wheel pickers
- **ContentView**: Main view containing timer UI with three distinct states (time picker, active timer, completion)

### Key Architectural Patterns
- **State Management**: Uses `@State` and `@StateObject` for reactive UI updates
- **HealthKit Integration**: Swimming workout sessions with automatic start/stop
- **Timer Logic**: Foundation Timer with progress tracking and completion handling
- **WatchKit Integration**: Water lock, haptic feedback, and watch-specific UI patterns

## Development Commands

### Building
```bash
# Build for Apple Watch Simulator (preferred for development)
xcodebuild -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" build

# Build for device
xcodebuild -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -configuration Release build
```

### Testing
```bash
# Run all tests
xcodebuild test -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)"

# Run only UI tests
xcodebuild test -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" -only-testing:"Plunge Timer Watch AppUITests"
```

### Xcode Development
```bash
open "Plunge Timer.xcodeproj"
```

## Key Technical Details

- **Bundle Identifier**: `tomwentworth.Plunge-Timer.watchkitapp`
- **Development Team**: 4FV4P73BFT
- **Deployment Target**: watchOS 11.5
- **Swift Version**: 5.0
- **Test Framework**: Swift Testing (uses `@Test` and `#expect`)
- **Entitlements**: HealthKit integration required (`com.apple.developer.healthkit`)

## HealthKit Integration

The app requires HealthKit permissions for:
- Swimming workout tracking (activity type: `.swimming`, location: `.outdoor`)
- Automatic workout session management
- Auto-start functionality based on water detection

**Important**: HealthKit functionality is limited in simulator - physical Apple Watch required for full testing.

## Development Notes

- **watchOS-only app** (no iOS companion app)
- **Water lock support** enabled during timer sessions
- **Haptic feedback** uses `WKInterfaceDevice.current().play(.success)`
- **Asset catalog** includes properly formatted AppIcon (renamed from original to avoid build issues)
- **Performance warning**: WheelPickerStyle may generate ScrollView contentOffset warnings - this is expected and doesn't affect functionality