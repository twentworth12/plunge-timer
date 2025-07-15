# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a watchOS app called "Plunge Timer" built with SwiftUI. It's a minimal Apple Watch application designed for timing cold plunges or similar activities.

## Architecture

- **Main App**: `Plunge_TimerApp.swift` - Entry point using SwiftUI App protocol
- **UI**: `ContentView.swift` - Main view with basic "Hello, world!" placeholder
- **Testing**: Uses Swift Testing framework (not XCTest)
- **Deployment Target**: watchOS 11.5
- **Swift Version**: 5.0

## Development Commands

### Building
```bash
# Build the project
xcodebuild -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -configuration Debug

# Build for release
xcodebuild -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -configuration Release
```

### Testing
```bash
# Run unit tests
xcodebuild test -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)"

# Run UI tests
xcodebuild test -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)" -only-testing:"Plunge Timer Watch AppUITests"
```

### Opening in Xcode
```bash
open "Plunge Timer.xcodeproj"
```

## Key Technical Details

- **Bundle Identifier**: `tomwentworth.Plunge-Timer.watchkitapp`
- **Development Team**: 4FV4P73BFT
- **Test Framework**: Swift Testing (uses `@Test` and `#expect`)
- **SwiftUI Previews**: Enabled
- **Asset Catalog**: Includes AppIcon and AccentColor

## File Structure

- `Plunge Timer Watch App/` - Main watchOS app code
- `Plunge Timer Watch AppTests/` - Unit tests
- `Plunge Timer Watch AppUITests/` - UI tests
- `Plunge Timer.xcodeproj/` - Xcode project files

## Development Notes

- This is a watchOS-only app (no iOS companion app)
- Uses standard SwiftUI patterns for watchOS
- Currently contains placeholder content that needs to be replaced with actual timer functionality
- Test files are set up but contain minimal example tests