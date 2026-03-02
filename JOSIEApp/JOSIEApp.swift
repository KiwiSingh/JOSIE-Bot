import SwiftUI
import AVFoundation

@main
struct JOSIEApp: App {
    init() {
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 2026 FIX: Updated .allowBluetooth to .allowBluetoothHFP to resolve deprecation
            try session.setCategory(
                .playAndRecord, 
                mode: .voiceChat, 
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true)
            print("🔊 JOSIE Audio Session Online")
        } catch {
            print("❌ Failed to set up JOSIE Audio Session: \(error)")
        }
    }
}
