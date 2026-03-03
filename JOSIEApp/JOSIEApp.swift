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
                // Prevent extreme accessibility scaling from breaking layout
                .dynamicTypeSize(.large ... .accessibility3)
        }
    }
    
    // MARK: - Audio Configuration
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [
                    .defaultToSpeaker,
                    .allowBluetoothHFP
                ]
            )
            
            try session.setActive(true)
            print("🔊 JOSIE Audio Session Online")
            
        } catch {
            print("❌ Failed to set up JOSIE Audio Session: \(error)")
        }
    }
}
