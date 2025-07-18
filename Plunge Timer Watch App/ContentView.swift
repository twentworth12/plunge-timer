//
//  ContentView.swift
//  Plunge Timer Watch App
//
//  Created by Tom Wentworth on 7/14/25.
//

import SwiftUI
import WatchKit
import HealthKit
import CoreMotion
import Intents
import ClockKit

enum TherapyMode: String, CaseIterable {
    case coldPlunge = "cold"
    case sauna = "sauna"
    
    var emoji: String {
        switch self {
        case .coldPlunge: return "❄️"
        case .sauna: return "🔥"
        }
    }
    
    var name: String {
        switch self {
        case .coldPlunge: return "Cold Plunge"
        case .sauna: return "Sauna"
        }
    }
    
    var workoutType: HKWorkoutActivityType {
        switch self {
        case .coldPlunge: return .swimming
        case .sauna: return .other
        }
    }
    
    var encouragementText: String {
        switch self {
        case .coldPlunge: return "🧊 Stay Strong!"
        case .sauna: return "🌡️ Embrace the Heat!"
        }
    }
    
    var buttonColor: Color {
        switch self {
        case .coldPlunge: return .cyan
        case .sauna: return .orange
        }
    }
}

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, CMWaterSubmersionManagerDelegate, WKExtendedRuntimeSessionDelegate {
    @Published var isWorkoutActive = false
    @Published var currentHeartRate: Double = 0.0
    @Published var isWaterDetectionAvailable = false
    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var onWorkoutStart: (() -> Void)?
    private var waterSubmersionManager: CMWaterSubmersionManager?
    private var builder: HKLiveWorkoutBuilder?
    private var startTime: Date?
    private var extendedRuntimeSession: WKExtendedRuntimeSession?
    
    func setupWorkoutSession(onStart: @escaping () -> Void) {
        self.onWorkoutStart = onStart
        
        let typesToWrite: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if success {
                print("HealthKit authorization granted")
            }
        }
    }
    
    func setupWaterDetection() {
        // Water detection requires Apple Watch Ultra with watchOS 9.0+
        print("Water detection checking availability...")
        
        // Check if CMWaterSubmersionManager is available
        if #available(watchOS 9.0, *) {
            // Initialize water submersion manager
            let manager = CMWaterSubmersionManager()
            manager.delegate = self
            self.waterSubmersionManager = manager
            
            // Check authorization status
            let authStatus = CMWaterSubmersionManager.authorizationStatus
            print("Water detection authorization status: \(authStatus.rawValue)")
            
            switch authStatus {
            case .authorized:
                print("✅ Water detection authorized and available")
                DispatchQueue.main.async {
                    self.isWaterDetectionAvailable = true
                }
            case .notDetermined:
                print("⚠️ Water detection authorization not determined, requesting...")
                // Authorization will be handled automatically when manager is used
                DispatchQueue.main.async {
                    self.isWaterDetectionAvailable = true
                }
            case .denied:
                print("❌ Water detection authorization denied")
                DispatchQueue.main.async {
                    self.isWaterDetectionAvailable = false
                }
            case .restricted:
                print("❌ Water detection authorization restricted")
                DispatchQueue.main.async {
                    self.isWaterDetectionAvailable = false
                }
            @unknown default:
                print("❓ Unknown water detection authorization status")
                DispatchQueue.main.async {
                    self.isWaterDetectionAvailable = false
                }
            }
        } else {
            print("❌ Water detection requires watchOS 9.0 or later")
            DispatchQueue.main.async {
                self.isWaterDetectionAvailable = false
            }
        }
    }
    
    func startWorkout(for mode: TherapyMode) {
        // Prevent multiple workout sessions
        guard !isWorkoutActive else {
            print("ℹ️ Workout already active, skipping duplicate start")
            return
        }
        
        // Try to start extended runtime session (optional for development)
        startExtendedRuntimeSession()
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = mode.workoutType
        configuration.locationType = .outdoor
        if mode == .coldPlunge {
            configuration.swimmingLocationType = .openWater
        }
        
        do {
            // HKWorkoutSession provides background execution even if extended runtime fails
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            
            builder = workoutSession?.associatedWorkoutBuilder()
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            startTime = Date()
            workoutSession?.startActivity(with: startTime!)
            builder?.beginCollection(withStart: startTime!) { success, error in
                if success {
                    print("✅ Workout data collection started")
                } else {
                    print("❌ Failed to start workout data collection: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
            
            isWorkoutActive = true
            print("🏋️‍♂️ \(mode.name) workout session active")
        } catch {
            print("❌ Failed to start workout session: \(error)")
        }
    }
    
    private func startExtendedRuntimeSession() {
        // Don't start if we already have an active session
        guard extendedRuntimeSession == nil else {
            print("ℹ️ Extended runtime session already exists")
            return
        }
        
        // Extended runtime sessions require special entitlements and may not work in development
        print("ℹ️ Extended runtime session disabled for development compatibility")
        print("🏊‍♂️ Using HealthKit workout session for background execution")
        
        // Note: To enable extended runtime sessions in production:
        // 1. Add com.apple.developer.watchkit.extended-runtime entitlement
        // 2. Request special approval from Apple
        // 3. Uncomment the code below
        
        /*
        extendedRuntimeSession = WKExtendedRuntimeSession()
        extendedRuntimeSession?.delegate = self
        extendedRuntimeSession?.start()
        */
    }
    
    private func stopExtendedRuntimeSession() {
        guard let session = extendedRuntimeSession else {
            print("ℹ️ No extended runtime session to stop")
            return
        }
        
        print("🛑 Stopping extended runtime session...")
        session.invalidate()
        extendedRuntimeSession = nil
        print("✅ Extended runtime session stopped")
    }
    
    func endWorkout() {
        guard let startTime = startTime else { return }
        let endTime = Date()
        
        builder?.endCollection(withEnd: endTime) { success, error in
            if success {
                print("Workout data collection ended")
                self.builder?.finishWorkout { workout, error in
                    if let workout = workout {
                        print("Workout saved successfully: \(workout)")
                        self.saveWorkoutToHealthKit(workout: workout, startTime: startTime, endTime: endTime)
                    } else {
                        print("Failed to finish workout: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            } else {
                print("Failed to end workout data collection: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        workoutSession?.end()
        workoutSession = nil
        builder = nil
        isWorkoutActive = false
        self.startTime = nil
        
        // Stop extended runtime session
        stopExtendedRuntimeSession()
        
        // Reset heart rate
        DispatchQueue.main.async {
            self.currentHeartRate = 0.0
        }
    }
    
    private func saveWorkoutToHealthKit(workout: HKWorkout, startTime: Date, endTime: Date) {
        healthStore.save(workout) { success, error in
            if success {
                print("Therapy workout saved to HealthKit")
            } else {
                print("Failed to save workout to HealthKit: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.onWorkoutStart?()
                print("Workout session started")
            case .ended:
                self.isWorkoutActive = false
                print("Workout session ended")
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
    
    // MARK: - CMWaterSubmersionManagerDelegate
    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        DispatchQueue.main.async {
            switch event.state {
            case .submerged:
                print("🌊 Water detected - starting timer automatically")
                WKInterfaceDevice.current().play(.success)
                self.onWorkoutStart?()
            case .notSubmerged:
                print("🏖️ Water no longer detected")
            default:
                print("🌊 Water detection state: \(event.state.rawValue)")
                break
            }
        }
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        // Handle water submersion measurements if needed
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterTemperature) {
        // Handle water temperature measurements if needed
    }
    
    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) {
        let cmError = error as NSError
        switch cmError.code {
        case 109: // Feature not available
            print("Water detection not available on this device (requires Apple Watch Ultra)")
            DispatchQueue.main.async {
                self.isWaterDetectionAvailable = false
            }
        case 103: // Not authorized
            print("Water detection not authorized")
            DispatchQueue.main.async {
                self.isWaterDetectionAvailable = false
            }
        default:
            print("Water detection error: \(error)")
        }
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let statistics = workoutBuilder.statistics(for: quantityType)
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                
                DispatchQueue.main.async {
                    self.currentHeartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0.0
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events
    }
    
    // MARK: - WKExtendedRuntimeSessionDelegate
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("✅ Extended runtime session started successfully")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("⏰ Extended runtime session will expire")
        // Optionally extend the session or handle expiration
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        // Clear our reference since the session is now invalid
        self.extendedRuntimeSession = nil
        
        if let error = error {
            let nsError = error as NSError
            switch nsError.code {
            case 8: // "client not approved"
                print("⚠️ Extended runtime session not approved (normal in simulator/development)")
            default:
                print("❌ Extended runtime session error: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ Extended runtime session ended normally (reason: \(reason.rawValue))")
        }
        
        print("🏊‍♂️ Relying on HealthKit workout session for background execution")
    }
}

struct TimePickers: View {
    @Binding var selectedMinutes: Int
    @Binding var selectedSeconds: Int
    
    private let minutes = Array(0...10)
    private let seconds = Array(0...59)
    
    var body: some View {
        HStack(spacing: 2) {
            Picker("Minutes", selection: $selectedMinutes) {
                ForEach(minutes, id: \.self) { minute in
                    Text("\(minute)m").tag(minute)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 70)
            
            Picker("Seconds", selection: $selectedSeconds) {
                ForEach(seconds, id: \.self) { second in
                    Text("\(second)s").tag(second)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 70)
        }
    }
}

struct ContentView: View {
    @State private var selectedMinutes = 2
    @State private var selectedSeconds = 0
    @State private var isTimerRunning = false
    @State private var timeRemaining = 0
    @State private var timer: Timer?
    @State private var showingModeSelection = true
    @State private var showingTimePicker = false
    @State private var progress: Double = 0.0
    @State private var totalTime = 0
    @State private var showingCompletion = false
    @State private var autoStartEnabled = false
    @State private var crownValue: Double = 0.0
    @State private var selectedMode: TherapyMode = .coldPlunge
    @FocusState private var isCrownFocused: Bool
    @StateObject private var workoutManager = WorkoutManager()
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                if showingCompletion {
                    completionView
                } else if showingModeSelection {
                    modeSelectionView
                } else if showingTimePicker {
                    timePickerView
                } else {
                    timerView
                }
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartPlungeTimer"))) { notification in
                handleSiriShortcut(notification)
            }
        }
    }
    
    private var modeSelectionView: some View {
        VStack(spacing: 8) {
            Text("Choose Therapy")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(TherapyMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedMode = mode
                        showingModeSelection = false
                        showingTimePicker = true
                    }) {
                        HStack {
                            Text(mode.emoji)
                                .font(.title2)
                            Text(mode.name)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(mode.buttonColor)
                }
            }
        }
    }
    
    private var timePickerView: some View {
        VStack(spacing: 6) {
            Button(action: {
                showingModeSelection = true
                showingTimePicker = false
            }) {
                Text(selectedMode.emoji)
                    .font(.title)
            }
            .buttonStyle(.plain)
            
            Text("Set Goal")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            TimePickers(selectedMinutes: $selectedMinutes, selectedSeconds: $selectedSeconds)
                .frame(height: 70)
            
            if selectedMode == .coldPlunge {
                if workoutManager.isWaterDetectionAvailable {
                    VStack(spacing: 4) {
                        Toggle("Auto-start on water entry", isOn: $autoStartEnabled)
                            .font(.caption2)
                            .toggleStyle(.switch)
                            .tint(.cyan)
                        
                        if autoStartEnabled {
                            Text("🏊‍♂️ Ready for water detection")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                                .opacity(0.8)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("Water detection unavailable")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            
            Button("Start") {
                startTimer()
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedMode.buttonColor)
            .font(.caption)
            .disabled(selectedMinutes == 0 && selectedSeconds == 0)
        }
        .onAppear {
            // Always check water detection availability first
            workoutManager.setupWaterDetection()
            
            // Setup workout session for auto-start if enabled (only for cold plunge)
            if autoStartEnabled && selectedMode == .coldPlunge {
                workoutManager.setupWorkoutSession {
                    startTimer()
                }
            }
        }
        .onChange(of: autoStartEnabled) { oldValue, newValue in
            // Setup or tear down auto-start functionality when toggle changes
            if newValue && selectedMode == .coldPlunge && workoutManager.isWaterDetectionAvailable {
                workoutManager.setupWorkoutSession {
                    startTimer()
                }
            }
        }
    }
    
    private var timerView: some View {
        VStack(spacing: 6) {
            // Condensed header with essential info only
            VStack(spacing: 1) {
                Text(selectedMode.encouragementText)
                    .font(.caption2)
                    .foregroundColor(selectedMode.buttonColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if isCrownFocused && !isTimerRunning {
                    Text("👑 Digital Crown")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .opacity(0.8)
                        .lineLimit(1)
                } else if isTimerRunning && workoutManager.currentHeartRate > 0 {
                    Text("❤️ \(Int(workoutManager.currentHeartRate)) BPM")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .frame(maxHeight: 32) // Limit header height
            
            ZStack {
                Circle()
                    .stroke(selectedMode.buttonColor.opacity(0.3), lineWidth: 5)
                    .frame(width: 90, height: 90)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(selectedMode.buttonColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: progress)
                
                // Crown focus indicator (only when paused)
                if isCrownFocused && !isTimerRunning {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(isCrownFocused ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isCrownFocused)
                }
                
                VStack(spacing: 0) {
                    Text(timeString(from: timeRemaining))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    
                    Text("left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .focused($isCrownFocused)
            .digitalCrownRotation(
                $crownValue, 
                from: 0, 
                through: 600, 
                by: 5, 
                sensitivity: .medium, 
                isContinuous: false, 
                isHapticFeedbackEnabled: true
            )
            .disabled(isTimerRunning) // Disable crown during timer
            .onChange(of: crownValue) { oldValue, newValue in
                // Only allow crown adjustment when timer is paused
                if !isTimerRunning {
                    adjustTimerWithCrown(newValue)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    if isTimerRunning {
                        pauseTimer()
                    } else {
                        resumeTimer()
                    }
                }) {
                    Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(isTimerRunning ? .orange : .green)
                
                Button(action: resetTimer) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(selectedMode.buttonColor)
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.title)
            
            Text("Champion!")
                .font(.headline)
                .foregroundColor(selectedMode.buttonColor)
                .multilineTextAlignment(.center)
            
            Text("You did it!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 4) {
                Text("Completed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(timeString(from: totalTime))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(selectedMode.buttonColor)
            }
            
            Button("New Session") {
                resetToNewSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedMode.buttonColor)
            .font(.caption)
        }
    }
    
    private func startTimer() {
        // Stop any existing timer first
        timer?.invalidate()
        timer = nil
        
        // Set up timer values
        totalTime = selectedMinutes * 60 + selectedSeconds
        timeRemaining = totalTime
        progress = 0.0
        showingTimePicker = false
        isTimerRunning = true
        
        // Set initial crown value to match timer
        crownValue = Double(timeRemaining)
        
        
        // Donate to Siri Shortcuts
        if #available(iOS 12.0, watchOS 5.0, *) {
            ShortcutsProvider.shared.donateQuickStartActivity(
                duration: totalTime,
                breathingEnabled: false
            )
        }
        
        // Start workout session to keep app active
        workoutManager.startWorkout(for: selectedMode)
        
        // Enable water lock only for cold plunge sessions
        if selectedMode == .coldPlunge {
            WKInterfaceDevice.current().enableWaterLock()
        }
        
        // Start the countdown timer with a slight delay to ensure all setup is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startCountdownTimer()
        }
    }
    
    private func startCountdownTimer() {
        timer?.invalidate() // Ensure no duplicate timers
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timerInstance in
            DispatchQueue.main.async {
                // Only proceed if timer is still running and time remains
                guard isTimerRunning && timeRemaining > 0 else {
                    if isTimerRunning && timeRemaining <= 0 {
                        timerCompleted()
                    }
                    timerInstance.invalidate()
                    return
                }
                
                // Decrement time and update progress
                timeRemaining -= 1
                progress = Double(totalTime - timeRemaining) / Double(totalTime)
            }
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        // Sync crown value to current time for adjustment
        DispatchQueue.main.async {
            self.crownValue = Double(self.timeRemaining)
        }
    }
    
    private func resumeTimer() {
        guard timeRemaining > 0 else { return }
        
        isTimerRunning = true
        startCountdownTimer()
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        showingModeSelection = true
        showingTimePicker = false
        showingCompletion = false
        progress = 0.0
        timeRemaining = 0
        crownValue = 0.0
    }
    
    private func resetToNewSession() {
        // Ensure timer is completely stopped
        timer?.invalidate()
        timer = nil
        
        // Reset all state variables
        isTimerRunning = false
        showingCompletion = false
        showingModeSelection = true
        showingTimePicker = false
        progress = 0.0
        timeRemaining = 0
        totalTime = 0
        crownValue = 0.0
        
        // Ensure workout is ended
        if workoutManager.isWorkoutActive {
            workoutManager.endWorkout()
        }
    }
    
    private func adjustTimerWithCrown(_ newValue: Double) {
        // Only allow adjustment when timer is paused for safety
        guard !isTimerRunning else { return }
        
        let newTimeRemaining = max(0, Int(newValue))
        
        // Update timer values
        timeRemaining = newTimeRemaining
        totalTime = max(totalTime, newTimeRemaining) // Ensure totalTime is never less than remaining
        
        // Recalculate progress
        if totalTime > 0 {
            progress = Double(totalTime - timeRemaining) / Double(totalTime)
        } else {
            progress = 0.0
        }
        
        // Provide haptic feedback for significant changes
        if abs(Double(timeRemaining) - newValue) > 5 {
            WKInterfaceDevice.current().play(.click)
        }
    }
    
    // MARK: - Siri Shortcuts
    private func handleSiriShortcut(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo["duration"] as? Int else { return }
        
        // Set timer values from Siri command
        selectedMinutes = duration / 60
        selectedSeconds = duration % 60
        
        // Start the timer automatically
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startTimer()
        }
    }
    
    private func timerCompleted() {
        // Prevent multiple completion triggers
        guard isTimerRunning else { return }
        
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        progress = 1.0
        timeRemaining = 0
        
        // End workout session if running
        workoutManager.endWorkout()
        
        // Single haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        // Update complications
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { complication in
            server.reloadTimeline(for: complication)
        }
        
        // Show completion celebration immediately
        showingCompletion = true
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
}

#Preview {
    ContentView()
}
