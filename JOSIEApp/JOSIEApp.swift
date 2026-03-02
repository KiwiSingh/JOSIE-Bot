import AVFoundation
import SwiftUI

@main
struct JOSIEApp: App {
  init() {
    // Initialize Audio Session for Speech & Mic
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
      try session.setActive(true)
    } catch {
      print("Failed to set up audio session: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
