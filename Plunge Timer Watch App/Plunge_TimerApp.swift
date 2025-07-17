//
//  Plunge_TimerApp.swift
//  Plunge Timer Watch App
//
//  Created by Tom Wentworth on 7/14/25.
//

import SwiftUI
import Intents

@main
struct Plunge_Timer_Watch_AppApp: App {
    
    init() {
        // Initialize shortcuts provider
        _ = ShortcutsProvider.shared
        
        // Register intent handler
        if #available(iOS 12.0, watchOS 5.0, *) {
            INPreferences.requestSiriAuthorization { status in
                print("Siri authorization status: \(status)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
