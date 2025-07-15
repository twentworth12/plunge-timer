# Plunge Timer ❄️

An Apple Watch app for cold plunge and ice bath timing, built with SwiftUI and HealthKit integration.

## Features

- **Intuitive Timer Controls**: Set your goal time with wheel pickers (0-10 minutes)
- **Visual Progress Tracking**: Beautiful circular progress indicator with motivational messages
- **HealthKit Integration**: Track your cold exposure workouts with automatic session recording
- **Auto-Start Option**: Automatically begin timing when water is detected
- **Water Lock Support**: Safe underwater use with Apple Watch water lock
- **Haptic Feedback**: Success notification when your session is complete

## Requirements

- Apple Watch running watchOS 11.5 or later
- Xcode 15.0 or later for development
- iOS/watchOS development environment

## Installation

1. Clone this repository
2. Open `Plunge Timer.xcodeproj` in Xcode
3. Select your Apple Watch as the target device
4. Build and run the project

## Usage

1. Set your desired time using the minute and second pickers
2. Toggle "Auto-start on water entry" if desired
3. Tap "Start" to begin your cold plunge session
4. The app will track your progress and provide haptic feedback when complete

## HealthKit Integration

The app integrates with HealthKit to:
- Track swimming/cold exposure workouts
- Record session duration and timing
- Provide automatic workout session management

**Note**: HealthKit permissions are required for full functionality.

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **HealthKit**: Workout and health data integration
- **WatchKit**: Apple Watch specific functionality
- **Swift Testing**: Unit testing framework

## Development

### Build Commands

```bash
# Build for Apple Watch Simulator
xcodebuild -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" build

# Run tests
xcodebuild test -project "Plunge Timer.xcodeproj" -scheme "Plunge Timer Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)"
```

### Project Structure

```
Plunge Timer/
├── Plunge Timer Watch App/
│   ├── ContentView.swift          # Main UI and timer logic
│   ├── Plunge_TimerApp.swift      # App entry point
│   ├── Assets.xcassets/           # App icons and assets
│   └── Plunge Timer Watch App.entitlements
├── Plunge Timer Watch AppTests/
└── Plunge Timer Watch AppUITests/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is available under the MIT License.

## Disclaimer

This app is designed for Apple Watch only. Always consult with a healthcare professional before beginning any cold exposure routine. Cold water exposure can be dangerous and should be approached with proper safety precautions.

---

Perfect for Wim Hof method practitioners, athletes, and anyone exploring the benefits of cold therapy. Stay focused, stay strong, and conquer the cold! ❄️