import Intents
import SwiftUI

// MARK: - Shortcuts Provider
class ShortcutsProvider: NSObject {
    
    static let shared = ShortcutsProvider()
    
    private override init() {
        super.init()
        setupShortcuts()
    }
    
    private func setupShortcuts() {
        if #available(iOS 12.0, watchOS 5.0, *) {
            // Create a user activity for Siri shortcuts
            let activity = NSUserActivity(activityType: "com.plungetimer.start")
            activity.title = "Start Cold Plunge"
            activity.suggestedInvocationPhrase = "Start my cold plunge"
            activity.isEligibleForPrediction = true
            activity.isEligibleForSearch = true
            activity.persistentIdentifier = "start-plunge-timer"
            
            // Donate the activity
            activity.becomeCurrent()
        }
    }
    
    @available(iOS 12.0, watchOS 5.0, *)
    func donateQuickStartActivity(duration: Int, breathingEnabled: Bool) {
        let activity = NSUserActivity(activityType: "com.plungetimer.start")
        activity.title = "Start Cold Plunge Timer"
        activity.userInfo = [
            "duration": duration,
            "enableBreathing": breathingEnabled
        ]
        activity.suggestedInvocationPhrase = "Start my cold plunge"
        activity.isEligibleForPrediction = true
        activity.isEligibleForSearch = true
        
        activity.becomeCurrent()
    }
}