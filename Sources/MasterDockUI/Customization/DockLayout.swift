import SwiftUI

// MARK: - Widgets

/// Every card that can appear in the dock.
public enum DockWidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case ai, media, calendar, clipboard, checklist
    case notes, timer, calculator, worldClock
    case apps, wallpapers, system

    public var id: String { rawValue }

    /// The card's built-in title (what a rename replaces).
    public var defaultTitle: String {
        switch self {
        case .ai: return "Apple Intelligence"
        case .media: return "Music"
        case .calendar: return "Todays Events"
        case .clipboard: return "Clipboard History"
        case .checklist: return "Daily Checklist"
        case .notes: return "Quick Notes"
        case .timer: return "Focus Timer"
        case .calculator: return "Calculator"
        case .worldClock: return "World Clock"
        case .apps: return "Favorite Apps"
        case .wallpapers: return "macOS Desktop Wallpapers"
        case .system: return "Widget Drawer & Health"
        }
    }

    /// Name shown in edit lists (always the built-in name, so renamed cards stay recognizable).
    public var catalogName: String {
        switch self {
        case .media: return "Music (Spotify / Apple Music)"
        case .wallpapers: return "Wallpapers"
        case .system: return "System & Weather"
        default: return defaultTitle
        }
    }

    public var iconName: String {
        switch self {
        case .ai: return "apple.intelligence"
        case .media: return "music.note"
        case .calendar: return "calendar"
        case .clipboard: return "doc.on.clipboard"
        case .checklist: return "checklist"
        case .notes: return "note.text"
        case .timer: return "timer"
        case .calculator: return "plus.forwardslash.minus"
        case .worldClock: return "globe"
        case .apps: return "square.grid.2x2"
        case .wallpapers: return "photo.on.rectangle"
        case .system: return "gauge.with.dots.needle.50percent"
        }
    }

    public var summary: String {
        switch self {
        case .ai: return "Chat with AI and quick actions"
        case .media: return "Now playing and playback controls"
        case .calendar: return "Today's events from all your calendars"
        case .clipboard: return "Everything you've copied, with pins"
        case .checklist: return "Today's to-do list"
        case .notes: return "A scratchpad that's always one swipe away"
        case .timer: return "Focus sessions and countdowns"
        case .calculator: return "Type math, get answers"
        case .worldClock: return "Times in other cities"
        case .apps: return "Your favorite apps and folders"
        case .wallpapers: return "Change your desktop picture"
        case .system: return "Battery, CPU, storage and weather"
        }
    }

    /// Which tab of the dock the card belongs to (besides All).
    public var tab: MasterDockRootView.DockTab {
        switch self {
        case .ai: return .ai
        case .clipboard: return .clipboard
        case .media, .calendar, .checklist, .notes, .timer: return .agenda
        case .apps: return .apps
        case .calculator, .worldClock, .wallpapers, .system: return .widgets
        }
    }

    /// Built-in order, most used first. New utilities start hidden so the dock stays tidy.
    static let defaultLayout: [DockWidgetConfig] = [
        .init(kind: .ai), .init(kind: .media), .init(kind: .calendar), .init(kind: .clipboard),
        .init(kind: .checklist), .init(kind: .apps), .init(kind: .wallpapers), .init(kind: .system),
        .init(kind: .notes, isVisible: false), .init(kind: .timer, isVisible: false),
        .init(kind: .calculator, isVisible: false), .init(kind: .worldClock, isVisible: false)
    ]
}

public struct DockWidgetConfig: Codable, Identifiable, Equatable, Sendable {
    public var kind: DockWidgetKind
    public var isVisible: Bool
    public var customTitle: String?
    public var id: String { kind.rawValue }

    public init(kind: DockWidgetKind, isVisible: Bool = true, customTitle: String? = nil) {
        self.kind = kind
        self.isVisible = isVisible
        self.customTitle = customTitle
    }
}

// MARK: - Store

/// The user's dock layout: card order, which cards are shown, and custom card names.
public final class DockLayoutStore: ObservableObject {
    public static let shared = DockLayoutStore()

    @Published public private(set) var widgets: [DockWidgetConfig]
    /// True while the dock is in "Edit Widgets" mode.
    @Published public var isEditing = false

    private let storageKey: String
    private let defaults: UserDefaults

    public init(storageKey: String = "dock_layout_v1", defaults: UserDefaults = .standard) {
        self.storageKey = storageKey
        self.defaults = defaults
        var loaded = DockWidgetKind.defaultLayout
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([DockWidgetConfig].self, from: data) {
            loaded = saved
        }
        self.widgets = Self.merged(loaded)
    }

    /// Keeps saved layouts working when new widget types are added in an update.
    private static func merged(_ saved: [DockWidgetConfig]) -> [DockWidgetConfig] {
        var result: [DockWidgetConfig] = []
        for config in saved where !result.contains(where: { $0.kind == config.kind }) {
            result.append(config)
        }
        for config in DockWidgetKind.defaultLayout where !result.contains(where: { $0.kind == config.kind }) {
            result.append(DockWidgetConfig(kind: config.kind, isVisible: false))
        }
        return result
    }

    public var visibleWidgets: [DockWidgetConfig] { widgets.filter(\.isVisible) }
    public var hiddenWidgets: [DockWidgetConfig] { widgets.filter { !$0.isVisible } }

    public func title(for kind: DockWidgetKind) -> String? {
        guard let custom = widgets.first(where: { $0.kind == kind })?.customTitle,
              !custom.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return custom
    }

    public func rename(_ kind: DockWidgetKind, to title: String) {
        update(kind) {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.customTitle = (trimmed.isEmpty || trimmed == kind.defaultTitle) ? nil : trimmed
        }
    }

    public func resetTitle(_ kind: DockWidgetKind) {
        update(kind) { $0.customTitle = nil }
    }

    /// `reposition` moves a newly shown widget to the end of the dock and a hidden one to the
    /// bottom of the list (used by the dock's edit mode). Settings keeps rows where they are.
    public func setVisible(_ kind: DockWidgetKind, _ visible: Bool, reposition: Bool = true) {
        guard let index = widgets.firstIndex(where: { $0.kind == kind }) else { return }
        if !reposition {
            widgets[index].isVisible = visible
            save()
            return
        }
        var config = widgets.remove(at: index)
        config.isVisible = visible
        if visible {
            // Newly shown widgets go to the end of the visible cards.
            let lastVisible = widgets.lastIndex(where: \.isVisible) ?? -1
            widgets.insert(config, at: lastVisible + 1)
        } else {
            widgets.append(config)
        }
        save()
    }

    /// Moves a card one step up (-1) or down (+1) among the visible cards.
    public func move(_ kind: DockWidgetKind, by offset: Int) {
        let visible = visibleWidgets
        guard let from = visible.firstIndex(where: { $0.kind == kind }) else { return }
        let to = from + offset
        guard visible.indices.contains(to) else { return }
        move(kind, before: offset < 0 ? visible[to].kind : nil, after: offset > 0 ? visible[to].kind : nil)
    }

    /// Drag and drop: place `kind` right before `target`.
    public func move(_ kind: DockWidgetKind, before target: DockWidgetKind) {
        move(kind, before: target, after: nil)
    }

    private func move(_ kind: DockWidgetKind, before: DockWidgetKind?, after: DockWidgetKind?) {
        guard kind != before, kind != after,
              let index = widgets.firstIndex(where: { $0.kind == kind }) else { return }
        let config = widgets.remove(at: index)
        if let before = before, let target = widgets.firstIndex(where: { $0.kind == before }) {
            widgets.insert(config, at: target)
        } else if let after = after, let target = widgets.firstIndex(where: { $0.kind == after }) {
            widgets.insert(config, at: target + 1)
        } else {
            widgets.insert(config, at: index)
        }
        save()
    }

    /// List-style reorder (Settings), indices into `widgets`.
    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        save()
    }

    public func resetToDefault() {
        widgets = DockWidgetKind.defaultLayout
        save()
    }

    private func update(_ kind: DockWidgetKind, _ change: (inout DockWidgetConfig) -> Void) {
        guard let index = widgets.firstIndex(where: { $0.kind == kind }) else { return }
        change(&widgets[index])
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(widgets) {
            defaults.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Renameable card titles

private struct DockCardKindKey: EnvironmentKey {
    static let defaultValue: DockWidgetKind? = nil
}

public extension EnvironmentValues {
    /// The dock card a view lives in (lets its title be renamed).
    var dockCardKind: DockWidgetKind? {
        get { self[DockCardKindKey.self] }
        set { self[DockCardKindKey.self] = newValue }
    }
}

/// A card's title. Shows the user's custom name, and double-clicking it renames the card in place.
public struct DockCardTitle: View {
    private let defaultTitle: String
    private let font: Font

    @Environment(\.dockCardKind) private var kind
    @ObservedObject private var layout = DockLayoutStore.shared
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    public init(_ defaultTitle: String, font: Font = AppTypography.titleMedium) {
        self.defaultTitle = defaultTitle
        self.font = font
    }

    private var shownTitle: String {
        guard let kind = kind else { return defaultTitle }
        return layout.title(for: kind) ?? defaultTitle
    }

    public var body: some View {
        if isEditing, let kind = kind {
            TextField(defaultTitle, text: $draft)
                .textFieldStyle(.plain)
                .font(font)
                .foregroundColor(.white)
                .focused($focused)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.10)))
                .onSubmit { commit(kind) }
                .onExitCommand { isEditing = false }
                .onChange(of: focused) { _, isFocused in if !isFocused { commit(kind) } }
                .onAppear { DispatchQueue.main.async { focused = true } }
        } else {
            Text(shownTitle)
                .font(font)
                .foregroundColor(.white)
                .lineLimit(1)
                .onTapGesture(count: 2) { startEditing() }
                .help(kind == nil ? "" : "Double-click to rename")
        }
    }

    private func startEditing() {
        guard kind != nil else { return }
        draft = shownTitle
        isEditing = true
    }

    private func commit(_ kind: DockWidgetKind) {
        guard isEditing else { return }
        layout.rename(kind, to: draft.isEmpty ? defaultTitle : draft)
        isEditing = false
    }
}
