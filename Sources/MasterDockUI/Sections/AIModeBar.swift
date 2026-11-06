import SwiftUI
import MasterDockAI

/// Mode switcher and memory switch shown under the AI card's title.
struct AIModeBar: View {
    @ObservedObject private var settings = AIAssistantSettings.shared
    @ObservedObject private var memory = AIMemoryStore.shared

    private enum Sheet: Identifiable {
        case personal, computer, memory
        var id: Int { hashValue }
    }
    @State private var sheet: Sheet?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AIAssistantMode.allCases) { mode in
                Button(action: { select(mode) }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 10, weight: .semibold))
                        if settings.mode == mode {
                            Text(mode.title)
                                .lineLimit(1)
                                .fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                        }
                    }
                    .frame(minWidth: 16)
                    .font(AppTypography.captionBold)
                    .foregroundColor(settings.mode == mode ? .white : .white.opacity(0.75))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(settings.mode == mode ? GlassTheme.accentBlue.opacity(0.85) : Color.white.opacity(0.07)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.pressable)
                .help(mode.summary)
            }

            Spacer(minLength: 4)

            if settings.mode != .generic {
                iconButton("slider.horizontal.3", active: false, help: settings.mode == .personal ? "Personalize" : "Choose what the AI can see") {
                    sheet = settings.mode == .personal ? .personal : .computer
                }
            }
            iconButton(settings.memoryEnabled ? "brain.head.profile.fill" : "brain.head.profile",
                       active: settings.memoryEnabled,
                       help: settings.memoryEnabled ? "Memory is on" : "Memory is off") {
                sheet = .memory
            }
        }
        .sheet(item: $sheet) { which in
            Group {
                switch which {
                case .personal: AIPersonalSheet(settings: settings, close: { sheet = nil })
                case .computer: AIComputerSheet(settings: settings, close: { sheet = nil })
                case .memory: AIMemorySheet(settings: settings, memory: memory, close: { sheet = nil })
                }
            }
            .frame(width: AISheetMetrics.width)
        }
    }

    private func select(_ mode: AIAssistantMode) {
        withAnimation(.spring(response: 0.3, dampingFraction: 1)) { settings.mode = mode }
        // First time in a mode: show its setup so nothing happens without the user knowing.
        if mode == .computer && !settings.computerConsentAnswered { sheet = .computer }
        if mode == .personal && settings.preferredName.isEmpty && settings.aboutMe.isEmpty { sheet = .personal }
    }

    private func iconButton(_ icon: String, active: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(active ? GlassTheme.accentCyan : .white.opacity(0.8))
                .frame(width: 26, height: 26)
                .background(Circle().fill(active ? GlassTheme.accentCyan.opacity(0.18) : Color.white.opacity(0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .help(help)
    }
}

enum AISheetMetrics {
    /// Sheets open inside the dock, so they can't be wider than it.
    static var width: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "dock_width")
        let dockWidth = (saved >= 240 && saved <= 600) ? CGFloat(saved) : 340
        return min(400, dockWidth - 12)
    }
}

// MARK: - Personal

private struct AIPersonalSheet: View {
    @ObservedObject var settings: AIAssistantSettings
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(icon: "person.crop.circle", title: "Personalize your AI", close: close)
            Text("Personal mode uses this to tailor its answers. It stays on this Mac.")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
            field("What should it call you?", text: $settings.preferredName, prompt: "e.g. Nathan")
            VStack(alignment: .leading, spacing: 4) {
                Text("About you").font(AppTypography.captionBold)
                TextEditor(text: $settings.aboutMe)
                    .font(AppTypography.body)
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                Text("e.g. \"Student in San Jose, taking calculus and Java.\"")
                    .font(AppTypography.micro).foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Answer style").font(AppTypography.captionBold)
                Picker("", selection: $settings.responseStyle) {
                    ForEach(AIResponseStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Anything else it should always do?").font(AppTypography.captionBold)
                TextEditor(text: $settings.customInstructions)
                    .font(AppTypography.body)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                Text("e.g. \"Explain math step by step.\"")
                    .font(AppTypography.micro).foregroundColor(.secondary)
            }
            HStack { Spacer(); Button("Done", action: close).buttonStyle(.borderedProminent) }
        }
        .padding(16)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(AppTypography.captionBold)
            TextField(prompt, text: text).textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Computer (permissions)

private struct AIComputerSheet: View {
    @ObservedObject var settings: AIAssistantSettings
    let close: () -> Void
    @State private var refresh = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(icon: "desktopcomputer", title: "What can the AI see?", close: finish)
            Text("Computer mode only reads what you switch on here, and only when you send a message. Nothing leaves your Mac unless you've chosen an online AI provider in Settings.")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(AIComputerSource.allCases) { source in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title).font(AppTypography.bodyBold)
                        Text(source.detail)
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if source == .selectedText && settings.isAllowed(.selectedText) && !AIAssistantSettings.hasAccessibilityPermission {
                            Button("Open Accessibility Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .font(AppTypography.caption)
                            .buttonStyle(.link)
                        }
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.isAllowed(source) },
                        set: { settings.setAllowed(source, $0); refresh.toggle() }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            }
            HStack {
                Spacer()
                Button("Done", action: finish).buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }

    private func finish() {
        settings.computerConsentAnswered = true
        close()
    }
}

// MARK: - Memory

private struct AIMemorySheet: View {
    @ObservedObject var settings: AIAssistantSettings
    @ObservedObject var memory: AIMemoryStore
    let close: () -> Void
    @State private var confirmForget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(icon: "brain.head.profile", title: "AI Memory", close: close)
            Text("With memory on, the AI saves your chats (what you asked and what it answered) on this Mac, so it can bring them back later. For example, ask about a house price today and \"how much was that house?\" next week.")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: Binding(
                get: { settings.memoryEnabled && settings.memoryConsentGiven },
                set: { on in
                    if on { settings.memoryConsentGiven = true }
                    settings.memoryEnabled = on
                }
            )) {
                Text("Remember my conversations").font(AppTypography.bodyBold)
            }
            .toggleStyle(.switch)

            HStack {
                Text("\(memory.exchanges.count) saved \(memory.exchanges.count == 1 ? "conversation" : "conversations")")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Forget Everything", role: .destructive) { confirmForget = true }
                    .disabled(memory.exchanges.isEmpty)
            }
            Text("Turning memory off stops saving new chats. Forget Everything deletes what's saved.")
                .font(AppTypography.micro)
                .foregroundColor(.secondary)
            HStack { Spacer(); Button("Done", action: close).buttonStyle(.borderedProminent) }
        }
        .padding(16)
        .confirmationDialog("Delete all saved conversations?", isPresented: $confirmForget) {
            Button("Forget Everything", role: .destructive) { memory.forgetAll() }
        } message: {
            Text("The AI won't remember anything from before. This can't be undone.")
        }
    }
}

private struct SheetHeader: View {
    let icon: String
    let title: String
    let close: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(GlassTheme.accentCyan)
            Text(title).font(AppTypography.titleMedium)
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
