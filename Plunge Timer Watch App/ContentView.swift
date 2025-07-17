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

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, CMWaterSubmersionManagerDelegate {
    @Published var isWorkoutActive = false
    @Published var currentHeartRate: Double = 0.0
    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var onWorkoutStart: (() -> Void)?
    private var waterSubmersionManager: CMWaterSubmersionManager?
    private var builder: HKLiveWorkoutBuilder?
    private var startTime: Date?
    
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
        waterSubmersionManager = CMWaterSubmersionManager()
        waterSubmersionManager?.delegate = self
        print("Water detection enabled")
    }
    
    func startWaterWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .swimming
        configuration.locationType = .outdoor
        configuration.swimmingLocationType = .openWater
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            
            builder = workoutSession?.associatedWorkoutBuilder()
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            startTime = Date()
            workoutSession?.startActivity(with: startTime!)
            builder?.beginCollection(withStart: startTime!) { success, error in
                if success {
                    print("Workout data collection started")
                } else {
                    print("Failed to start workout data collection: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
            
            isWorkoutActive = true
        } catch {
            print("Failed to start workout session: \(error)")
        }
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
        
        // Reset heart rate
        DispatchQueue.main.async {
            self.currentHeartRate = 0.0
        }
    }
    
    private func saveWorkoutToHealthKit(workout: HKWorkout, startTime: Date, endTime: Date) {
        healthStore.save(workout) { success, error in
            if success {
                print("Cold plunge workout saved to HealthKit")
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
                print("Water detected - starting timer")
                self.onWorkoutStart?()
            case .notSubmerged:
                print("Water no longer detected")
            default:
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
        print("Water detection error: \(error)")
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
}

struct TimePickers: View {
    @Binding var selectedMinutes: Int
    @Binding var selectedSeconds: Int
    
    private let minutes = Array(0...10)
    private let seconds = Array(0...59)
    
    var body: some View {
        HStack(spacing: 5) {
            Picker("Minutes", selection: $selectedMinutes) {
                ForEach(minutes, id: \.self) { minute in
                    Text("\(minute)m").tag(minute)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 50)
            
            Picker("Seconds", selection: $selectedSeconds) {
                ForEach(seconds, id: \.self) { second in
                    Text("\(second)s").tag(second)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 50)
        }
    }
}

struct ContentView: View {
    @State private var selectedMinutes = 2
    @State private var selectedSeconds = 0
    @State private var isTimerRunning = false
    @State private var timeRemaining = 0
    @State private var timer: Timer?
    @State private var showingTimePicker = true
    @State private var progress: Double = 0.0
    @State private var totalTime = 0
    @State private var showingCompletion = false
    @State private var autoStartEnabled = true
    @State private var crownValue: Double = 0.0
    @FocusState private var isCrownFocused: Bool
    @StateObject private var workoutManager = WorkoutManager()
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                if showingCompletion {
                    completionView
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
    
    private var timePickerView: some View {
        VStack(spacing: 6) {
            Text("❄️")
                .font(.title)
            
            Text("Set Goal")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            TimePickers(selectedMinutes: $selectedMinutes, selectedSeconds: $selectedSeconds)
                .frame(height: 70)
            
            Toggle("Auto-start on water entry", isOn: $autoStartEnabled)
                .font(.caption2)
                .toggleStyle(.switch)
                .tint(.cyan)
            
            
            Button("Start") {
                startTimer()
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .font(.caption)
            .disabled(selectedMinutes == 0 && selectedSeconds == 0)
        }
        .onAppear {
            if autoStartEnabled {
                workoutManager.setupWorkoutSession {
                    startTimer()
                }
                workoutManager.setupWaterDetection()
            }
        }
    }
    
    private var timerView: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("🧊 Stay Strong!")
                    .font(.caption)
                    .foregroundColor(.cyan)
                
                if isCrownFocused {
                    Text("👑 Adjust with Digital Crown")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .opacity(0.8)
                }
                
                
                if isTimerRunning && workoutManager.currentHeartRate > 0 {
                    Text("❤️ \(Int(workoutManager.currentHeartRate)) BPM")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
            
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: progress)
                
                // Crown focus indicator
                if isCrownFocused {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                        .frame(width: 110, height: 110)
                        .scaleEffect(isCrownFocused ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isCrownFocused)
                }
                
                VStack(spacing: 1) {
                    Text(timeString(from: timeRemaining))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    Text("left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .focused($isCrownFocused)
            .digitalCrownRotation($crownValue, from: 0, through: 600, by: 5, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crownValue) { oldValue, newValue in
                adjustTimerWithCrown(newValue)
            }
            
            HStack(spacing: 15) {
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
                .tint(.cyan)
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 8) {
            Text("🎉")
                .font(.title)
            
            Text("Champion!")
                .font(.headline)
                .foregroundColor(.cyan)
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
                    .foregroundColor(.cyan)
            }
            
            Button("New Session") {
                showingCompletion = false
                showingTimePicker = true
                progress = 0.0
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .font(.caption)
        }
    }
    
    private func startTimer() {
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
        workoutManager.startWaterWorkout()
        
        
        // Keep screen awake during timer
        WKInterfaceDevice.current().enableWaterLock()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                crownValue = Double(timeRemaining)
                progress = Double(totalTime - timeRemaining) / Double(totalTime)
            } else {
                timerCompleted()
            }
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        // Update crown value to current time for adjustment
        crownValue = Double(timeRemaining)
        
    }
    
    private func resumeTimer() {
        guard timeRemaining > 0 else { return }
        
        isTimerRunning = true
        
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                crownValue = Double(timeRemaining)
                progress = Double(totalTime - timeRemaining) / Double(totalTime)
            } else {
                timerCompleted()
            }
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        showingTimePicker = true
        showingCompletion = false
        progress = 0.0
        timeRemaining = 0
        crownValue = 0.0
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
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        progress = 1.0
        
        // End workout session if running
        workoutManager.endWorkout()
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        // Update complications
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { complication in
            server.reloadTimeline(for: complication)
        }
        
        // Show completion celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingCompletion = true
        }
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
