import SwiftUI
import MasterDockUI

@main
struct MasterDockMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsWindowView()
        }
    }
}
