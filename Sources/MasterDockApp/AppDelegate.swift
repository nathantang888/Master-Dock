import Cocoa
import SwiftUI
import MasterDockCore
import MasterDockServices
import MasterDockAI
import MasterDockUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as regular application visible in macOS Dock
        NSApp.setActivationPolicy(.regular)
        
        let viewModel = DockViewModel.shared
        
        // The host re-draws the dock whenever the view model changes (voice mode, chat, pin).
        let rootView = DockRootHost(
            viewModel: viewModel,
            windowController: viewModel.windowController,
            openSettings: { [weak self] in self?.openSettingsWindow() }
        )
        
        viewModel.windowController.setup(with: rootView)
        viewModel.start()
        setupStatusItem()
        
        if UserDefaults.standard.bool(forKey: WelcomeView.seenKey) {
            viewModel.windowController.present(mode: .standardDock, animated: true)
        } else {
            showWelcome()
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let controller = DockViewModel.shared.windowController
        if !controller.isVisible {
            controller.present(mode: .standardDock, animated: true)
        }
        return true
    }
    
    public func applicationDidBecomeActive(_ notification: Notification) {
        // While the welcome screen is up, don't slide the dock over it.
        if welcomeWindow?.isVisible == true { return }
        // The dock activates the app itself when it opens. Only open it here if it is hidden,
        // otherwise this would restart the slide (or shrink voice mode back to the standard dock).
        let controller = DockViewModel.shared.windowController
        if !controller.isVisible {
            controller.present(mode: .standardDock, animated: true)
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Master Dock")
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Toggle Master Dock (\(GlobalHotKeys.toggleDock.display))", action: #selector(toggleDock), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let pinItem = NSMenuItem(title: "Pin Dock (Keep Visible)", action: #selector(togglePin), keyEquivalent: "p")
        pinItem.target = self
        menu.addItem(pinItem)
        
        let voiceItem = NSMenuItem(title: "Open AI Voice Mode (\(GlobalHotKeys.voiceMode.display))", action: #selector(openVoiceMode), keyEquivalent: "")
        voiceItem.target = self
        menu.addItem(voiceItem)
        
        let shortcutItem = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(toggleShortcuts(_:)), keyEquivalent: "")
        shortcutItem.target = self
        shortcutItem.state = MultitouchManager.shortcutsEnabled ? .on : .off
        menu.addItem(shortcutItem)
        
        let welcomeItem = NSMenuItem(title: "Show Welcome Screen", action: #selector(openWelcome), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Preferences & Permissions...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Master Dock", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.statusMenu = menu
    }
    
    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else {
            toggleDock()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            if let menu = statusMenu {
                statusItem?.menu = menu
                statusItem?.button?.performClick(nil)
                statusItem?.menu = nil
            }
        } else {
            toggleDock()
        }
    }
    
    @objc private func toggleDock() {
        DockViewModel.shared.toggleStandardDock()
    }
    
    @objc private func togglePin() {
        DockViewModel.shared.windowController.isPinned.toggle()
    }
    
    @objc private func openVoiceMode() {
        DockViewModel.shared.toggleVoiceMode()
    }
    
    @objc private func openSettings() {
        openSettingsWindow()
    }
    
    @objc private func toggleShortcuts(_ sender: NSMenuItem) {
        let enabled = !MultitouchManager.shortcutsEnabled
        UserDefaults.standard.set(enabled, forKey: MultitouchManager.shortcutsEnabledKey)
        sender.state = enabled ? .on : .off
        DockViewModel.shared.multitouchManager.setupHotkeyFallbacks()
    }
    
    @objc private func openWelcome() {
        showWelcome()
    }
    
    /// The first-launch welcome window.
    public func showWelcome() {
        if let existing = welcomeWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 470),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.title = "Welcome to Master Dock"
        window.contentView = NSHostingView(rootView: WelcomeView(onFinish: { [weak self] in
            self?.welcomeWindow?.close()
            self?.welcomeWindow = nil
            DockViewModel.shared.windowController.present(mode: .standardDock, animated: true)
        }))
        window.center()
        // Closing it with the red button counts as done too, so it doesn't come back every launch.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            UserDefaults.standard.set(true, forKey: WelcomeView.seenKey)
            MainActor.assumeIsolated { self?.welcomeWindow = nil }
        }
        welcomeWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    public func openSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Master Dock Preferences"
        window.contentView = NSHostingView(rootView: SettingsWindowView())
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Watches the view model and window controller so the dock updates when they change.
/// (The dock's root view itself only hands services down to the cards.)
struct DockRootHost: View {
    @ObservedObject var viewModel: DockViewModel
    @ObservedObject var windowController: GlassWindowController
    let openSettings: () -> Void

    var body: some View {
    MasterDockRootView(
                clipboardService: viewModel.clipboardService,
                mediaService: viewModel.mediaService,
                calendarService: viewModel.calendarService,
                wallpaperService: viewModel.wallpaperService,
                appLauncher: viewModel.appLauncher,
                folderService: viewModel.folderService,
                statsService: viewModel.statsService,
                weatherService: viewModel.weatherService,
                checklistService: viewModel.checklistService,
                promptService: viewModel.promptService,
                audioPipeline: viewModel.audioPipeline,
                isVoiceModeActive: Binding(
                    get: { viewModel.isVoiceModeActive },
                    set: { viewModel.isVoiceModeActive = $0 }
                ),
                liveVoiceTranscript: Binding(
                    get: { viewModel.liveVoiceTranscript },
                    set: { viewModel.liveVoiceTranscript = $0 }
                ),
                aiPromptInput: Binding(
                    get: { viewModel.aiPromptInput },
                    set: { viewModel.aiPromptInput = $0 }
                ),
                conversationHistory: Binding(
                    get: { viewModel.conversationHistory },
                    set: { viewModel.conversationHistory = $0 }
                ),
                isAIStreaming: Binding(
                    get: { viewModel.isAIStreaming },
                    set: { viewModel.isAIStreaming = $0 }
                ),
                isPinned: Binding(
                    get: { viewModel.windowController.isPinned },
                    set: { viewModel.windowController.isPinned = $0 }
                ),
                onSendMessage: { text in
                    viewModel.sendAIMessage(text)
                },
                onClearChat: {
                    viewModel.clearConversation()
                },
                onVoiceDone: {
                    viewModel.stopVoiceRecordingAndSend()
                },
                onStartVoice: {
                    viewModel.startVoiceRecording()
                },
                onOpenSettings: openSettings,
                onDismiss: {
                    viewModel.windowController.dismiss()
                },
                onExitVoice: {
                    viewModel.exitVoiceMode()
                }
            )
    }
}
