//
//  ContentView.swift
//  Plunge Timer Watch App
//
//  Created by Tom Wentworth on 7/14/25.
//

import SwiftUI
import WatchKit
import HealthKit

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate {
    @Published var isWorkoutActive = false
    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var onWorkoutStart: (() -> Void)?
    
    func setupWorkoutSession(onStart: @escaping () -> Void) {
        self.onWorkoutStart = onStart
        
        let typesToWrite: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [HKObjectType.workoutType()]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if success {
                print("HealthKit authorization granted")
            }
        }
    }
    
    func startWaterWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .swimming
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            workoutSession?.startActivity(with: Date())
            isWorkoutActive = true
        } catch {
            print("Failed to start workout session: \(error)")
        }
    }
    
    func endWorkout() {
        workoutSession?.end()
        workoutSession = nil
        isWorkoutActive = false
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
            }
        }
    }
    
    private var timerView: some View {
        VStack(spacing: 10) {
            Text("🧊 Stay Strong!")
                .font(.caption)
                .foregroundColor(.cyan)
            
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
                
                VStack(spacing: 2) {
                    Text(timeString(from: timeRemaining))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
        
        // Enable water lock for cold plunge
        if WKInterfaceDevice.current().waterResistanceRating == .wr50 {
            WKInterfaceDevice.current().enableWaterLock()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
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
    }
    
    private func resumeTimer() {
        guard timeRemaining > 0 else { return }
        
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
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
