import SwiftUI
import AppKit

// MARK: - Quick Notes

/// A scratchpad that saves as you type.
public struct QuickNotesWidget: View {
    @AppStorage("quick_notes_text") private var text: String = ""
    @FocusState private var focused: Bool

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            UtilityHeader(kind: .notes, trailing: text.isEmpty ? nil : AnyView(
                Button("Clear") { text = "" }
                    .buttonStyle(.pressable)
                    .font(AppTypography.captionBold)
                    .foregroundColor(GlassTheme.accentCyan)
            ))
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Jot something down…")
                        .font(AppTypography.body)
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
            }
            .frame(height: 96)
            .padding(6)
            .liquidPillStyle(cornerRadius: 12, isHovered: focused)
            Text("\(text.count) characters • saved automatically")
                .font(AppTypography.micro)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Focus Timer

/// Keeps counting while the dock is closed.
public final class FocusTimerModel: ObservableObject {
    public static let shared = FocusTimerModel()

    @Published public private(set) var duration: TimeInterval = 25 * 60
    @Published public private(set) var remaining: TimeInterval = 25 * 60
    @Published public private(set) var isRunning = false

    private var endDate: Date?
    private var ticker: Timer?

    public func select(minutes: Int) {
        stop()
        duration = TimeInterval(minutes * 60)
        remaining = duration
    }

    public func toggle() { isRunning ? pause() : start() }

    public func start() {
        guard remaining > 0 else { return }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    public func pause() {
        tick()
        stop()
    }

    public func reset() {
        stop()
        remaining = duration
    }

    private func stop() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
    }

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            stop()
            NSSound(named: "Glass")?.play()
        }
    }

    public var progress: Double { duration > 0 ? 1 - remaining / duration : 0 }

    public var formatted: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

public struct FocusTimerWidget: View {
    @ObservedObject private var model = FocusTimerModel.shared
    private let presets = [5, 15, 25, 50]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UtilityHeader(kind: .timer, trailing: nil)
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: model.progress)
                        .stroke(GlassTheme.accentCyan, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: model.progress)
                    Text(model.formatted)
                        .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(presets, id: \.self) { minutes in
                            Button("\(minutes)m") { model.select(minutes: minutes) }
                                .buttonStyle(.pressable)
                                .font(AppTypography.captionBold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Int(model.duration / 60) == minutes ? GlassTheme.accentBlue.opacity(0.85) : Color.white.opacity(0.08)))
                        }
                    }
                    HStack(spacing: 8) {
                        Button(action: model.toggle) {
                            Label(model.isRunning ? "Pause" : "Start", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                                .font(AppTypography.captionBold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(GlassTheme.accentBlue))
                        }
                        .buttonStyle(.pressable)
                        Button(action: model.reset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.pressable)
                        .help("Reset")
                    }
                }
            }
        }
    }
}

// MARK: - Calculator

/// Safe math evaluator for the calculator widget (no code execution, never crashes on bad input).
public enum MathEvaluator {
    public static func evaluate(_ input: String) -> Double? {
        var parser = Parser(tokens: tokenize(input))
        guard let value = parser.parseExpression(), parser.isAtEnd, value.isFinite else { return nil }
        return value
    }

    public static func format(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int64(value))
        }
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private enum Token: Equatable { case number(Double), op(Character), open, close }

    private static func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        var number = ""
        func flush() {
            if !number.isEmpty, let value = Double(number) { tokens.append(.number(value)) }
            number = ""
        }
        for char in input.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: ",", with: "") {
            if char.isNumber || char == "." {
                number.append(char)
            } else {
                flush()
                switch char {
                case "+", "-", "*", "/", "^", "%": tokens.append(.op(char))
                case "(": tokens.append(.open)
                case ")": tokens.append(.close)
                case " ": continue
                default: return []   // anything else (letters, etc.) is not math
                }
            }
        }
        flush()
        return tokens
    }

    private struct Parser {
        let tokens: [Token]
        var index = 0
        var isAtEnd: Bool { index >= tokens.count }

        init(tokens: [Token]) { self.tokens = tokens }

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while !isAtEnd, case .op(let op) = tokens[index], op == "+" || op == "-" {
                index += 1
                guard let rhs = parseTerm() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func parseTerm() -> Double? {
            guard var value = parsePower() else { return nil }
            while !isAtEnd, case .op(let op) = tokens[index], op == "*" || op == "/" || op == "%" {
                index += 1
                guard let rhs = parsePower() else { return nil }
                switch op {
                case "*": value *= rhs
                case "/": guard rhs != 0 else { return nil }; value /= rhs
                default: guard rhs != 0 else { return nil }; value = value.truncatingRemainder(dividingBy: rhs)
                }
            }
            return value
        }

        mutating func parsePower() -> Double? {
            guard let base = parseUnary() else { return nil }
            if !isAtEnd, case .op("^") = tokens[index] {
                index += 1
                guard let exponent = parsePower() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        mutating func parseUnary() -> Double? {
            if !isAtEnd, case .op("-") = tokens[index] {
                index += 1
                return parseUnary().map { -$0 }
            }
            if !isAtEnd, case .op("+") = tokens[index] {
                index += 1
                return parseUnary()
            }
            return parsePrimary()
        }

        mutating func parsePrimary() -> Double? {
            guard !isAtEnd else { return nil }
            switch tokens[index] {
            case .number(let value):
                index += 1
                return value
            case .open:
                index += 1
                guard let value = parseExpression(), !isAtEnd, tokens[index] == .close else { return nil }
                index += 1
                return value
            default:
                return nil
            }
        }
    }
}

public struct CalculatorWidget: View {
    @State private var input = ""
    @AppStorage("calculator_history") private var historyStorage: String = ""
    @State private var copied: String?

    public init() {}

    private var history: [String] {
        historyStorage.split(separator: "\n").map(String.init)
    }

    private var liveResult: String? {
        MathEvaluator.evaluate(input).map(MathEvaluator.format)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            UtilityHeader(kind: .calculator, trailing: history.isEmpty ? nil : AnyView(
                Button("Clear") { historyStorage = "" }
                    .buttonStyle(.pressable)
                    .font(AppTypography.captionBold)
                    .foregroundColor(GlassTheme.accentCyan)
            ))
            HStack(spacing: 8) {
                TextField("Type math, like 12.5 * (3 + 4)", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .onSubmit(commit)
                if let result = liveResult {
                    Text("= \(result)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(GlassTheme.accentCyan)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidPillStyle(cornerRadius: 12)

            if !history.isEmpty {
                VStack(spacing: 4) {
                    ForEach(history.prefix(3), id: \.self) { line in
                        Button(action: { copyResult(of: line) }) {
                            HStack {
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: copied == line ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(copied == line ? GlassTheme.accentEmerald : .white.opacity(0.5))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .help("Copy the answer")
                    }
                }
            }
        }
    }

    private func commit() {
        guard let result = liveResult else { return }
        let line = "\(input.trimmingCharacters(in: .whitespaces)) = \(result)"
        historyStorage = ([line] + history.filter { $0 != line }).prefix(10).joined(separator: "\n")
        input = result
    }

    private func copyResult(of line: String) {
        let answer = line.components(separatedBy: " = ").last ?? line
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(answer, forType: .string)
        copied = line
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { if copied == line { copied = nil } }
    }
}

// MARK: - World Clock

public struct WorldClockWidget: View {
    @AppStorage("world_clock_zones") private var zonesStorage: String = "America/New_York,Europe/London,Asia/Tokyo"

    private struct City: Identifiable {
        let name: String
        let id: String
    }
    
    private static let choices: [City] = [
        City(name: "Los Angeles", id: "America/Los_Angeles"), City(name: "Denver", id: "America/Denver"),
        City(name: "Chicago", id: "America/Chicago"), City(name: "New York", id: "America/New_York"),
        City(name: "São Paulo", id: "America/Sao_Paulo"), City(name: "London", id: "Europe/London"),
        City(name: "Paris", id: "Europe/Paris"), City(name: "Berlin", id: "Europe/Berlin"),
        City(name: "Dubai", id: "Asia/Dubai"), City(name: "Mumbai", id: "Asia/Kolkata"),
        City(name: "Ho Chi Minh City", id: "Asia/Ho_Chi_Minh"), City(name: "Singapore", id: "Asia/Singapore"),
        City(name: "Seoul", id: "Asia/Seoul"), City(name: "Tokyo", id: "Asia/Tokyo"),
        City(name: "Sydney", id: "Australia/Sydney"), City(name: "Honolulu", id: "Pacific/Honolulu")
    ]

    public init() {}

    private var zones: [String] {
        zonesStorage.split(separator: ",").map(String.init).filter { TimeZone(identifier: $0) != nil }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            UtilityHeader(kind: .worldClock, trailing: AnyView(addMenu))
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(spacing: 6) {
                    ForEach(zones, id: \.self) { id in
                        row(for: id, now: context.date)
                    }
                }
            }
        }
    }

    private var addMenu: some View {
        Menu {
            ForEach(Self.choices.filter { !zones.contains($0.id) }) { city in
                Button(city.name) { zonesStorage = (zones + [city.id]).joined(separator: ",") }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(GlassTheme.accentCyan)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add a city")
    }

    private func row(for id: String, now: Date) -> some View {
        let zone = TimeZone(identifier: id) ?? .current
        let time = DateFormatter()
        time.timeZone = zone
        time.dateFormat = "h:mm a"
        let name = Self.choices.first { $0.id == id }?.name ?? id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
        let hoursAhead = Double(zone.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)) / 3600
        let offset = hoursAhead == 0 ? "Same time" : String(format: "%@%g hr", hoursAhead > 0 ? "+" : "", hoursAhead)
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
                Text(offset)
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            Text(time.string(from: now))
                .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundColor(.white)
            Button(action: { zonesStorage = zones.filter { $0 != id }.joined(separator: ",") }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.pressable)
            .help("Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .liquidPillStyle(cornerRadius: 12)
    }
}

// MARK: - Shared header

/// Header used by the utility cards: icon + renameable title + optional trailing control.
struct UtilityHeader: View {
    let kind: DockWidgetKind
    let trailing: AnyView?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: kind.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GlassTheme.accentCyan)
            DockCardTitle(kind.defaultTitle, font: AppTypography.bodyBold)
            Spacer()
            if let trailing = trailing { trailing }
        }
    }
}
