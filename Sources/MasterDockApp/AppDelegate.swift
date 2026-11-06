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
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as regular application visible in macOS Dock
        NSApp.setActivationPolicy(.regular)
        
        let viewModel = DockViewModel.shared
        
        // Root View binding
        let rootView = MasterDockRootView(
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
            onSendMessage: { [weak viewModel] text in
                viewModel?.sendAIMessage(text)
            },
            onClearChat: { [weak viewModel] in
                viewModel?.clearConversation()
            },
            onVoiceDone: { [weak viewModel] in
                viewModel?.stopVoiceRecordingAndSend()
            },
            onStartVoice: { [weak viewModel] in
                viewModel?.startVoiceRecording()
            },
            onOpenSettings: { [weak self] in
                self?.openSettingsWindow()
            },
            onDismiss: { [weak viewModel] in
                viewModel?.windowController.dismiss()
            }
        )
        
        viewModel.windowController.setup(with: rootView)
        viewModel.start()
        viewModel.windowController.present(mode: .standardDock, animated: true)
        
        setupStatusItem()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let controller = DockViewModel.shared.windowController
        if !controller.isVisible {
            controller.present(mode: .standardDock, animated: true)
        }
        return true
    }
    
    public func applicationDidBecomeActive(_ notification: Notification) {
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
        
        let toggleItem = NSMenuItem(title: "Toggle Master Dock (⌥ Space)", action: #selector(toggleDock), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let pinItem = NSMenuItem(title: "Pin Dock (Keep Visible)", action: #selector(togglePin), keyEquivalent: "p")
        pinItem.target = self
        menu.addItem(pinItem)
        
        let voiceItem = NSMenuItem(title: "Open AI Voice Mode (⌥ ⇧ Space)", action: #selector(openVoiceMode), keyEquivalent: "")
        voiceItem.target = self
        menu.addItem(voiceItem)
        
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
